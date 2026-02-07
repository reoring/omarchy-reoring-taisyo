# Hey Omarchy-! / へい、おまち〜!

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
- Waybar custom modules for "main monitor" (toggle + external position menu), DDC brightness, Fcitx EN group toggle, lid-close suspend, keyboard cleaning mode, and pointer visibility (all clickable toggles)
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
  - `~/.config/waybar/config.jsonc` (adds custom modules: main monitor / DDC brightness / fcitx EN group / lid / keyboard cleaning / pointer visibility)
  - `~/.config/waybar/style.css` (CSS for the above)
  - `~/.local/bin/waybar-main-monitor`, `~/.local/bin/waybar-ddc-brightness`, `~/.local/bin/waybar-fcitx-en`, `~/.local/bin/waybar-lid-suspend`, `~/.local/bin/waybar-keyboard-clean`, `~/.local/bin/waybar-cursor-invisible`
- systemd (user)
  - `~/.config/systemd/user/lid-nosuspend.service` (toggle-style inhibitor for lid-close suspend)
  - `~/.config/systemd/user/app-org.fcitx.Fcitx5@autostart.service.d/override.conf` (fix: make `fcitx5-cskk` find `libcskk` when using `cskk-git`)
- Scripts
  - `~/.local/bin/fcitx-en-toggle` (toggle fcitx5 group: cskk-only <-> cskk+keyboard-us)
  - `~/.local/bin/hypr-ws` (main/park workspace routing)
  - `~/.local/bin/hypr-monitor-position` (set external monitor position: left/right/up/down)
  - `~/.local/bin/ddc-brightness` (DDC/CI brightness for external monitors: get/set/up/down)
  - `~/.local/bin/hypr-*-adjust` / `hypr-*-toggle` (opacity/blur/gaps/scale/refresh/main-monitor/internal-display/lid/keyboard-clean/cursor-invisible)

Notes:

- Fcitx EN group toggle is bound to `Super+Ctrl+J` and is also available as a Waybar `JP/EN` module.
- `apply.sh` temporarily stops fcitx5 while installing `~/.config/fcitx5/*` to avoid fcitx autosave overwriting updated config.
- When installing NVIDIA envs, `apply.sh` may edit `~/.config/hypr/hyprland.conf` to add `source = ~/.config/hypr/envs.conf`.
- Some keybindings are personal (Spotify/Signal/1Password/web apps). Adjust in `~/.config/hypr/bindings.conf` (see the shortcut guide).
- If your external monitor name is not `DP-4`, update `home/.config/hypr/monitors.conf` (and apply with `--force-monitors`).

## Usage

From this repo directory:

Optional (DDC brightness setup: `i2c-dev` + udev rules):

```sh
bash ./setup-ddcutil.sh
```

```sh
bash ./apply.sh
```

Preflight (no changes):

```sh
bash ./apply.sh --check
```

Re-running is safe: unchanged files are detected and skipped.

Options:

- `--check` Print environment/repo checks and exit
- `--dry-run` Print planned actions only
- `--skip-packages` Skip package install via yay
- `--gtk-gsettings` Also set GTK prefs via gsettings (Emacs keys + button layout) (enabled by default)
- `--no-gtk-gsettings` Do not touch GTK gsettings
- `--no-waybar` Skip Waybar config/scripts
- `--with-shaders` Symlink `~/.config/hypr/shaders` from `/usr/share/aether/shaders`
- `--force-monitors` Always install `~/.config/hypr/monitors.conf` (even if DP-4 is not detected)
- `--force-nvidia-env` Always install `~/.config/hypr/envs.conf` and source it
- `--skip-nvidia-env` Never install `~/.config/hypr/envs.conf`

## Requirements / assumptions

- Omarchy + Hyprland setup (these files/scripts call Omarchy helpers like `omarchy-launch-*`)
- Tools commonly available on Omarchy systems: `bash`, `install`, `python` (3.x), `hyprctl`, `jq`, `systemctl --user`, `notify-send`, `walker` (or `fzf`)
- `yay` (used by default to install fcitx5-related packages; skip with `--skip-packages`)
- Optional (DDC brightness): `ddcutil` (installed by default via `apply.sh` unless `--skip-packages`; `setup-ddcutil.sh` also installs udev rules)
- Waybar (only if you install Waybar config)

## Customize

- Edit files under `home/` and re-run `bash ./apply.sh`, or edit the installed copies under `~/.config/` and `~/.local/bin/`.

After applying:

- Hyprland usually auto-reloads; if needed run `hyprctl reload`
- Waybar: `omarchy-restart-waybar` (the script will try to run this)

## Rollback

Before overwriting, the script creates a backup next to the target file as `*.bak.YYYYmmdd-HHMMSS`.

To restore the latest backups for the files managed by this repo:

```sh
bash ./rollback.sh
```

Dry-run:

```sh
bash ./rollback.sh --dry-run
```

## License

MIT (see `LICENSE`).
