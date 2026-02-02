# omarchy-reoring-taisyo

Omarchy (Hyprland) の標準設定に、reoring のカスタム設定/スクリプトを上書き適用するためのバンドルです。

このディレクトリは `~/.local/share/omarchy/`（Omarchy 管理ファイル）には触れず、ユーザー設定 (`~/.config/*`, `~/.local/bin/*`) のみを更新します。

`apply.sh` は `home/` 以下を `$HOME` にコピーし、上書き前にタイムスタンプ付きバックアップを作成します。

ドキュメント:

- English README: `README.md`
- Hyprland ショートカットガイド: `docs/user-guide.md` (EN) / `user-guide.ja.md` (JA)

## 何ができるか（要点）

- AltGr を使ったワークスペース運用（"main monitor" 概念 + もう一方に parking ワークスペース）
- vim 風フォーカス移動（`Super+H/J/K/L`）と、`hypr-*` の各種調整/トグル（opacity/blur/gaps/scale/refresh/nightlight など）
- Waybar に "main monitor" / ふた閉じサスペンド状態を表示（クリックでトグル）
- ハードウェア依存の設定を必要時のみ適用:
  - `monitors.conf` は `DP-4` を検出したときだけ適用（または `--force-monitors`）
  - `envs.conf` は NVIDIA を検出したときだけ適用（または `--force-nvidia-env`）。さらに `apply.sh` が `~/.config/hypr/hyprland.conf` に source 行を追加します

## 含まれるもの（ファイル）

- Fcitx5
  - `~/.config/environment.d/90-fcitx5.conf`, `~/.config/environment.d/fcitx.conf`（IME の環境変数）
  - `~/.config/fcitx5/config`, `~/.config/fcitx5/profile`（ホットキー + デフォルトIM）
  - `~/.config/fcitx5/conf/*.conf`（アドオンの小さな調整）
- Hyprland
  - `~/.config/hypr/bindings.conf`（AltGr ワークスペース運用、vim風フォーカス移動、各種調整キーなど）
  - `~/.config/hypr/hypridle.conf`（ロック/DPMS タイムアウトの調整）
  - `~/.config/hypr/input.conf`（Caps→Ctrl、タッチパッド自然スクロール）
  - `~/.config/hypr/monitors.conf`（DP-4 を想定した追加設定。自動検出/強制オプションあり）
  - `~/.config/hypr/envs.conf`（NVIDIA向け env。自動検出/強制オプションあり）
- Waybar
  - `~/.config/waybar/config.jsonc`（main monitor / lid の custom モジュール追加）
  - `~/.config/waybar/style.css`（上記モジュールにCSS適用）
  - `~/.local/bin/waybar-main-monitor`, `~/.local/bin/waybar-lid-suspend`
- systemd (user)
  - `~/.config/systemd/user/lid-nosuspend.service`（lid close の suspend を inhibit するトグル用）
- スクリプト
  - `~/.local/bin/hypr-ws`（main/park 概念でワークスペース移動）
  - `~/.local/bin/hypr-*-adjust` / `hypr-*-toggle`（opacity/blur/gaps/scale/refresh/main-monitor/internal-display/lid）

補足:

- NVIDIA env を適用する場合、`apply.sh` は `~/.config/hypr/hyprland.conf` に `source = ~/.config/hypr/envs.conf` を挿入/追記することがあります。
- キーバインドは個人設定寄りです（Spotify/Signal/1Password/Web アプリなど）。必要に応じて `~/.config/hypr/bindings.conf` を編集してください（ショートカットガイド参照）。
- 外部モニター名が `DP-4` でない場合は `home/.config/hypr/monitors.conf` を調整し、`--force-monitors` で適用してください。

## 使い方

このディレクトリで:

```sh
bash ./apply.sh
```

同じコマンドを再実行しても安全です（差分がないファイルはスキップされます）。

オプション:

- `--dry-run` 変更内容だけ表示
- `--skip-packages` yay によるパッケージ導入をスキップ
- `--no-waybar` Waybar関連をスキップ
- `--with-shaders` `~/.config/hypr/shaders` を `/usr/share/aether/shaders` からsymlink生成
- `--force-monitors` `~/.config/hypr/monitors.conf` を強制適用（未検出でも）
- `--force-nvidia-env` `~/.config/hypr/envs.conf` を強制適用（未検出でも）
- `--skip-nvidia-env` NVIDIA env 適用を常にスキップ

## 前提 / 依存

- Omarchy + Hyprland 環境（`omarchy-launch-*` など Omarchy の helper を呼びます）
- よく使うコマンド: `bash`, `install`, `python`（3系）, `hyprctl`, `jq`, `systemctl --user`, `notify-send`
- `yay`（デフォルトで fcitx5 関連パッケージをインストールします。不要なら `--skip-packages`）
- Waybar（Waybar 関連を適用する場合）

## カスタマイズ

- `home/` 以下を編集して `bash ./apply.sh` を再実行するか、適用後の `~/.config/` / `~/.local/bin/` を直接編集してください。

適用後:

- Hyprland: 通常は自動リロードしますが、必要なら `hyprctl reload`
- Waybar: `omarchy-restart-waybar`（`apply.sh` が可能なら自動実行）

## ロールバック

上書き前に `*.bak.YYYYmmdd-HHMMSS` を同じパスに作成します。

## ライセンス

MIT（`LICENSE` 参照）。
