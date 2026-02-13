# WWAN Ping遅延に応じた 4G/5G 切替 Daemon 仕様（ドラフト）

## 目的

- `wwan0` の遅延悪化（スパイク）を検知したら、モデムの許可モードを切り替えて低遅延を優先する常駐 daemon を提供する。
- 主に「5G の電波が弱い/不安定なのに 5G (NR) を掴みに行く/外す」ことで発生する遅延スパイクを、`4g` 固定へ落とすことで緩和する。

## 前提（環境）

- Linux + ModemManager
- `mmcli` が利用可能であること。
- 対象 IF: `wwan0`（設定で変更可能）
- 対象 modem id: `0`（設定で変更可能）

注: `nmcli` は接続管理用であり、モデムの許可モード設定は `mmcli` を使用する。

## 影響範囲 / 注意点

- モード切替のたびにベアラ再確立が発生し、通信が数秒〜数十秒切れる可能性がある。
- そのためフラップ防止（クールダウン、回数制限）が必須。
- キャリア側が gateway への ICMP を返さない場合があり、`default via ...` の gateway ping は切り分け材料にならないことがある。

## 全体動作（概要）

- 定期的に `ping -I wwan0` を複数ターゲットに対して実行し、RTT/欠損率を観測する。
- 移動窓で集計し、状態機械で以下を切り替える。
  - `PREFER_5G`: 許可 `4g,5g`（可能なら preferred=`5g`）
  - `FORCE_LTE`: 許可 `4g`
- 切替後はクールダウン期間中は判断を停止する。

## 監視（計測）仕様

### ターゲット

デフォルト（例）:

- `1.1.1.1`（Cloudflare）
- `8.8.8.8`（Google）
- `110.163.0.5`（キャリア DNS。環境により異なるため設定可能）

狙い:

- anycast 偏りや経路変動で 1 箇所が不安定になっても判定できるようにする。

### 実行パラメータ

1 ターゲットあたりの計測:

```bash
ping -I wwan0 -c 5 -i 0.2 -W 1 <target>
```

スケジュール例:

- 10 秒ごとに計測（設定可能）

### 指標（ターゲット別）

- `median_rtt_ms`
- `p95_rtt_ms`（難しければ `max_rtt_ms` で代替）
- `loss_pct`

### 全体の合成（頑健化）

ターゲットごとにブレが大きい前提で、全体値は設定可能な合成方式を用いる。

例:

- RTT は「成功したターゲットの中央値の中央値（median of medians）」
- loss は「成功したターゲットの loss の最大」

## 状態機械

### 状態

- `PREFER_5G`
- `FORCE_LTE`

内部的に以下の制御状態を持ってもよい:

- `COOLDOWN`（切替直後）

### 遷移条件（デフォルト案）

観測窓:

- 劣化判定窓: 60 秒（設定可能）
- 回復判定窓: 10 分（設定可能）

`PREFER_5G -> FORCE_LTE`（劣化）:

- 窓内で下記のいずれかが `N` 回以上（例: `N=3`）
  - `median_rtt_ms > 120` または `p95_rtt_ms > 300`
  - `loss_pct > 2%`

`FORCE_LTE -> PREFER_5G`（回復）:

- 回復窓の間、下記を満たし続ける
  - `median_rtt_ms < 70` かつ `p95_rtt_ms < 150` かつ `loss_pct < 1%`
- 任意で「時間帯条件」を追加（深夜だけ 5G を試す等）

### フラップ防止

- `cooldown_after_switch`: 5 分
- `min_time_in_state`: 10 分
- `max_switches_per_hour`: 2 回

## 切替アクション

### LTE固定

```bash
mmcli -m <id> --set-allowed-modes='4g'
```

### 5G許可へ戻す

可能なら:

```bash
mmcli -m <id> --set-allowed-modes='4g,5g' --set-preferred-mode='5g'
```

端末/キャリアで preferred が効かない場合のフォールバック:

```bash
mmcli -m <id> --set-allowed-modes='4g,5g'
```

### 切替後のヘルスチェック

- `mmcli -m <id>` の `state=connected` を待つ（タイムアウト付き）
- `ip route show dev wwan0` に default が出ることを確認（ベストエフォート）
- 失敗時は 1 回だけリトライ、以降は現状維持でエラーを記録

## 設定

### 設定ファイル

例: `/etc/wwan-latency-switcher/config.toml`

主なキー（例）:

- `modem_id`（例: `0`）
- `iface`（例: `wwan0`）
- `targets`（配列）
- `period_ms`
- `sample.count`, `sample.interval_ms`, `sample.timeout_ms`
- `windows.degrade_ms`, `windows.recover_ms`
- `thresholds.degrade.*`, `thresholds.recover.*`
- `cooldown_ms`, `min_state_ms`, `max_switches_per_hour`
- `commands.force_lte`, `commands.prefer_5g`（環境差の吸収用）

## ログ / 可観測性

- journalctl に構造化ログ（state, metrics, decision, switch_result, reason）
- `status`（サブコマンド or unix socket）で以下を表示
  - 現在状態
  - 直近の集計値
  - 最終切替時刻と理由

## 権限 / セキュリティ

- `mmcli --set-allowed-modes` は特権が必要。
- 推奨: systemd service を root 実行。
- 代替: polkit で必要操作のみ許可（要設計）。

## systemd 要件

- `After=ModemManager.service NetworkManager.service`
- `Restart=always`
- `RestartSec=3`

## 非目標（初期リリースでは扱わない）

- トラフィック量からバッファブロートを厳密推定して判定に組み込む
- AT コマンドによる band 固定/セルロック等（環境依存が強い）
