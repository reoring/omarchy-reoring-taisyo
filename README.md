# omarchy-reoring-taisyo

reoring's opinionated Omarchy (Hyprland) customizations, packaged as a small bundle you can apply on top of a standard Omarchy setup.

This bundle does NOT touch `~/.local/share/omarchy/` (Omarchy-managed files). It only updates user-owned config/scripts (`~/.config/*`, `~/.local/bin/*`).

`apply.sh` copies files from `home/` into your `$HOME` and creates timestamped backups before overwriting.

Docs:

- Japanese README: `README.ja.md`
- Hyprland shortcut guide: `docs/user-guide.md` (EN) / `user-guide.ja.md` (JA)

## What you get

Highlights:

- AltGr workspace workflow with a "main monitor" concept + parking workspaces for the other display
- Vim-style focus movement (`Super+H/J/K/L`) and small `hypr-*` adjust/toggle scripts (opacity/blur/gaps/scale/refresh/nightlight, etc.)
- Waybar custom modules for "main monitor" and lid-close suspend state (clickable toggles)
- Hardware-aware installs:
  - `monitors.conf` is installed only when `DP-4` is detected (or `--force-monitors`)
  - `envs.conf` is installed only when NVIDIA is detected (or `--force-nvidia-env`) and `apply.sh` ensures `~/.config/hypr/hyprland.conf` sources it

## What's included (files)

- Fcitx5
  - `~/.config/environment.d/90-fcitx5.conf`, `~/.config/environment.d/fcitx.conf` (IME env vars)
  - `~/.config/fcitx5/config`, `~/.config/fcitx5/profile` (hotkeys + default IM)
  - `~/.config/fcitx5/conf/*.conf` (small addon tweaks)
- Hyprland
  - `~/.config/hypr/bindings.conf` (AltGr workspace workflow, vim-style focus movement, adjustment keybinds)
  - `~/.config/hypr/hypridle.conf` (lock/DPMS timeout tweaks)
  - `~/.config/hypr/input.conf` (Caps -> Ctrl, touchpad natural scrolling)
  - `~/.config/hypr/monitors.conf` (adds a DP-4 entry; auto-detected unless forced)
  - `~/.config/hypr/envs.conf` (NVIDIA env vars; auto-detected unless forced)
- Waybar
  - `~/.config/waybar/config.jsonc` (adds custom modules: main monitor / lid)
  - `~/.config/waybar/style.css` (CSS for the above)
  - `~/.local/bin/waybar-main-monitor`, `~/.local/bin/waybar-lid-suspend`
- systemd (user)
  - `~/.config/systemd/user/lid-nosuspend.service` (toggle-style inhibitor for lid-close suspend)
- Scripts
  - `~/.local/bin/hypr-ws` (main/park workspace routing)
  - `~/.local/bin/hypr-*-adjust` / `hypr-*-toggle` (opacity/blur/gaps/scale/refresh/main-monitor/internal-display/lid)

Notes:

- When installing NVIDIA envs, `apply.sh` may edit `~/.config/hypr/hyprland.conf` to add `source = ~/.config/hypr/envs.conf`.
- Some keybindings are personal (Spotify/Signal/1Password/web apps). Adjust in `~/.config/hypr/bindings.conf` (see the shortcut guide).
- If your external monitor name is not `DP-4`, update `home/.config/hypr/monitors.conf` (and apply with `--force-monitors`).

## Usage

From this repo directory:

```sh
bash ./apply.sh
```

Re-running is safe: unchanged files are detected and skipped.

Options:

- `--dry-run` Print planned actions only
- `--skip-packages` Skip package install via yay
- `--no-waybar` Skip Waybar config/scripts
- `--with-shaders` Symlink `~/.config/hypr/shaders` from `/usr/share/aether/shaders`
- `--force-monitors` Always install `~/.config/hypr/monitors.conf` (even if DP-4 is not detected)
- `--force-nvidia-env` Always install `~/.config/hypr/envs.conf` and source it
- `--skip-nvidia-env` Never install `~/.config/hypr/envs.conf`

## Requirements / assumptions

- Omarchy + Hyprland setup (these files/scripts call Omarchy helpers like `omarchy-launch-*`)
- Tools commonly available on Omarchy systems: `bash`, `install`, `python` (3.x), `hyprctl`, `jq`, `systemctl --user`, `notify-send`
- `yay` (used by default to install fcitx5-related packages; skip with `--skip-packages`)
- Waybar (only if you install Waybar config)

## Customize

- Edit files under `home/` and re-run `bash ./apply.sh`, or edit the installed copies under `~/.config/` and `~/.local/bin/`.

After applying:

- Hyprland usually auto-reloads; if needed run `hyprctl reload`
- Waybar: `omarchy-restart-waybar` (the script will try to run this)

## Rollback

Before overwriting, the script creates a backup next to the target file as `*.bak.YYYYmmdd-HHMMSS`.

## License

MIT (see `LICENSE`).
