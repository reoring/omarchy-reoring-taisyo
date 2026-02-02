# omarchy-reoring-taisyo

Omarchy (Hyprland) の標準設定に、reoring のカスタム部分を上書き適用するためのスナップショットです。

このディレクトリは `~/.local/share/omarchy/` には触れず、ユーザー設定 (`~/.config/*`, `~/.local/bin/*`) のみを更新します。

## 含まれるもの

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

## 使い方

```sh
cd omarchy-reoring-taisyo
bash ./apply.sh
```

オプション:

- `--dry-run` 変更内容だけ表示
- `--no-waybar` Waybar関連をスキップ
- `--with-shaders` `~/.config/hypr/shaders` を `/usr/share/aether/shaders` からsymlink生成
- `--force-monitors` `~/.config/hypr/monitors.conf` を強制適用（未検出でも）
- `--force-nvidia-env` `~/.config/hypr/envs.conf` を強制適用（未検出でも）
- `--skip-nvidia-env` NVIDIA env 適用を常にスキップ

適用後:

- Hyprland: 通常は自動リロードしますが、必要なら `hyprctl reload`
- Waybar: `omarchy-restart-waybar`（`apply.sh` が可能なら自動実行）

## ロールバック

上書き前に `*.bak.YYYYmmdd-HHMMSS` を同じパスに作成します。
