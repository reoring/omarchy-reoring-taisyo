# Hyprland Shortcut Guide (omarchy-reoring-taisyo)

This guide documents the Hyprland keybindings shipped by this repo.

Source in this repo: `home/.config/hypr/bindings.conf`
Installed to: `~/.config/hypr/bindings.conf` (via `apply.sh`)

## Modifier keys

- `Super`: the Windows/Command key
- `AltGr`: Right Alt (ISO_Level3_Shift)
- `code:10..19`: the number row (`1..0` on most layouts)

Tip: Press `Super+I` to open Omarchy's keybinding menu (`omarchy-menu-keybindings`).

## App launchers

| Keys | Action |
| --- | --- |
| `Super+Enter` | Terminal (opens in "terminal cwd") |
| `Super+Shift+F` | File manager (Nautilus) |
| `Super+Shift+B` | Browser |
| `Super+Shift+Alt+B` | Browser (private) |
| `Super+Shift+M` | Music (Spotify) |
| `Super+Shift+N` | Editor |
| `Super+Shift+D` | Docker TUI (lazydocker) |
| `Super+Shift+G` | Signal |
| `Super+Shift+O` | Obsidian |
| `Super+Shift+W` | Typora |
| `Super+Shift+/` | 1Password |

## Web apps

| Keys | Action |
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
| `Super+Shift+Alt+X` | X (compose) |

## Workspaces (AltGr workflow)

This setup treats one display as the "main" monitor:

- `AltGr+QWERTASDFG` always targets workspaces `1..10` on the current main monitor.
- `AltGr+Z/X/C/V/B` targets "parking" workspaces on the non-main monitor when an external display is connected:
  - `Z=99`, `X=98`, `C=97`, `V=96`, `B=95`
  - If there is no second monitor, these fall back to `11..15`.
- `AltGr+1..0` targets workspaces `16..25` on the main monitor.

Switch which monitor is considered "main" with `Super+Ctrl+M`.

### Switch workspace

| Keys | Action |
| --- | --- |
| `AltGr+Q/W/E/R/T` | Go to workspace `1/2/3/4/5` (main) |
| `AltGr+A/S/D/F/G` | Go to workspace `6/7/8/9/10` (main) |
| `AltGr+Z/X/C/V/B` | Go to parking workspace `99/98/97/96/95` (fallback `11/12/13/14/15`) |
| `AltGr+1..0` | Go to workspace `16..25` (main) |

### Move active window

Add `Shift` to the workspace keys:

- `AltGr+Shift+...` moves the active window to that workspace (and focuses it).

## Window / display adjustments

| Keys | Action |
| --- | --- |
| `Super+H/J/K/L` | Move focus left/down/up/right |
| `Super+U` | Toggle split (dwindle) |
| `Super+Ctrl+-` / `Super+Ctrl+=` | Nightlight warmer/cooler (hyprsunset) |
| `Super+Alt+-` / `Super+Alt+=` | Active window opacity down/up |
| `Super+Alt+Shift+-` / `Super+Alt+Shift+=` | Global blur down/up |
| `Super+Shift+;` / `Super+Shift+'` | Workspace gaps down/up |
| `Super+Shift+Ctrl+-` / `Super+Shift+Ctrl+=` | Monitor scale down/up (focused monitor) |
| `Super+Ctrl+R` | Toggle refresh rate (60/120 when available) |
| `Super+Ctrl+Y` | Toggle Waybar |
| `Super+Ctrl+M` | Toggle main monitor + consolidate workspaces |
| `Super+Ctrl+P` | Toggle internal display (safe: won't disable your only monitor) |
| `Super+Ctrl+O` | Toggle lid-close suspend (systemd user service) |

## Where to change things

- Keybindings live in `~/.config/hypr/bindings.conf`.
- Workspace routing logic is implemented by `~/.local/bin/hypr-ws` and `~/.local/bin/hypr-main-monitor-toggle`.
