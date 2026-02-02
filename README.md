# omarchy-reoring-taisyo

reoring's Omarchy (Hyprland) customizations, packaged so they can be applied on top of a standard Omarchy setup.

This bundle does NOT touch `~/.local/share/omarchy/` (Omarchy-managed files). It only updates user-owned config/scripts (`~/.config/*`, `~/.local/bin/*`).

Japanese documentation: `README.ja.md`

## What's included

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

## Usage

```sh
cd omarchy-reoring-taisyo
bash ./apply.sh
```

Options:

- `--dry-run` Print planned actions only
- `--no-waybar` Skip Waybar config/scripts
- `--with-shaders` Symlink `~/.config/hypr/shaders` from `/usr/share/aether/shaders`
- `--force-monitors` Always install `~/.config/hypr/monitors.conf` (even if DP-4 is not detected)
- `--force-nvidia-env` Always install `~/.config/hypr/envs.conf` and source it
- `--skip-nvidia-env` Never install `~/.config/hypr/envs.conf`

After applying:

- Hyprland usually auto-reloads; if needed run `hyprctl reload`
- Waybar: `omarchy-restart-waybar` (the script will try to run this)

## Rollback

Before overwriting, the script creates a backup next to the target file as `*.bak.YYYYmmdd-HHMMSS`.
