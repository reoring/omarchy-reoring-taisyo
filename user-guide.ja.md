# Hyprland ショートカットガイド（omarchy-reoring-taisyo）

このガイドは、このディレクトリに含まれる Hyprland のキーバインド（ショートカット）をまとめたものです。

このリポジトリ内: `home/.config/hypr/bindings.conf`
適用後の場所: `~/.config/hypr/bindings.conf`（`apply.sh` で反映）

## 修飾キーの表記

- `Super`: Windows/Command キー
- `AltGr`: 右 Alt（ISO_Level3_Shift）
- `code:10..19`: 数字キー列（多くの配列で `1..0`）

ヒント: `Super+I` で Omarchy のキーバインド一覧（`omarchy-menu-keybindings`）を開けます。

## アプリ起動

| キー | 動作 |
| --- | --- |
| `Super+Enter` | ターミナル（"terminal cwd" で起動） |
| `Super+Shift+F` | ファイルマネージャ（Nautilus） |
| `Super+Shift+B` | ブラウザ |
| `Super+Shift+Alt+B` | ブラウザ（プライベート） |
| `Super+Shift+M` | 音楽（Spotify） |
| `Super+Shift+N` | エディタ |
| `Super+Shift+D` | Docker TUI（lazydocker） |
| `Super+Shift+G` | Signal |
| `Super+Shift+O` | Obsidian |
| `Super+Shift+W` | Typora |
| `Super+Shift+/` | 1Password |

## Web アプリ

| キー | 動作 |
| --- | --- |
| `Super+Shift+A` | ChatGPT |
| `Super+Shift+Alt+A` | Grok |
| `Super+Shift+C` | HEY Calendar |
| `Super+Shift+E` | HEY Mail |
| `Super+Shift+Y` | YouTube |
| `Super+Shift+Alt+G` | WhatsApp |
| `Super+Shift+Ctrl+G` | Google Messages |
| `Super+Shift+P` | Google Photos |
| `Super+Shift+X` | X |
| `Super+Shift+Alt+X` | X（投稿画面） |

## ワークスペース（AltGr 運用）

この設定は、どちらか一方のディスプレイを "main monitor" として扱います。

- `AltGr+QWERTASDFG` は、常に main monitor 側のワークスペース `1..10` を対象にします。
- `AltGr+Z/X/C/V/B` は、外部モニター接続時に "parking" 用ワークスペースを non-main 側に表示します。
  - `Z=99`, `X=98`, `C=97`, `V=96`, `B=95`
  - 2枚目のモニターが無い場合は `11..15` にフォールバックします。
- `AltGr+1..0` は、main monitor 側のワークスペース `16..25` を対象にします。

main monitor の切替は `Super+Ctrl+M` です。

### ワークスペースに移動

| キー | 動作 |
| --- | --- |
| `AltGr+Q/W/E/R/T` | ワークスペース `1/2/3/4/5`（main） |
| `AltGr+A/S/D/F/G` | ワークスペース `6/7/8/9/10`（main） |
| `AltGr+Z/X/C/V/B` | parking `99/98/97/96/95`（フォールバック `11/12/13/14/15`） |
| `AltGr+1..0` | ワークスペース `16..25`（main） |

### ウィンドウを移動

ワークスペース系のキーに `Shift` を足します:

- `AltGr+Shift+...` で、アクティブウィンドウをそのワークスペースへ移動（フォーカスも移動）

## ウィンドウ / 表示 調整

| キー | 動作 |
| --- | --- |
| `Super+H/J/K/L` | フォーカスを左/下/上/右へ移動 |
| `Super+U` | 分割方向トグル（dwindle） |
| `Super+Ctrl+-` / `Super+Ctrl+=` | 夜間モードを暖色/寒色へ（hyprsunset） |
| `Super+Alt+-` / `Super+Alt+=` | アクティブウィンドウの透明度を下げる/上げる |
| `Super+Alt+Shift+-` / `Super+Alt+Shift+=` | 全体のブラーを下げる/上げる |
| `Super+Shift+;` / `Super+Shift+'` | 現在ワークスペースの gaps を下げる/上げる |
| `Super+Shift+Ctrl+-` / `Super+Shift+Ctrl+=` | モニタースケールを下げる/上げる（フォーカス中のモニター） |
| `Super+Ctrl+R` | リフレッシュレート切替（利用可能なら 60/120） |
| `Super+Ctrl+Y` | Waybar 表示トグル |
| `Super+Ctrl+M` | main monitor 切替 + ワークスペース再配置 |
| `Super+Ctrl+P` | 内蔵ディスプレイの ON/OFF（外部無しで消えない安全設計） |
| `Super+Ctrl+O` | ふた閉じサスペンドの ON/OFF（systemd user service） |

## 設定の場所

- キーバインドは `~/.config/hypr/bindings.conf` にあります。
- ワークスペースの "main/park" ルーティングは `~/.local/bin/hypr-ws` と `~/.local/bin/hypr-main-monitor-toggle` で実装されています。
