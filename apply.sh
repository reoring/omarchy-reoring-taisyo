#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_HOME="$ROOT/home"

DRY_RUN=0
NO_WAYBAR=0
WITH_SHADERS=0
FORCE_MONITORS=0
FORCE_NVIDIA_ENV=0
SKIP_NVIDIA_ENV=0
CHECK_ONLY=0
SKIP_PACKAGES=0
APPLY_GTK_GSETTINGS=1

usage() {
  cat <<'EOF'
Usage: apply.sh [options]

Options:
  --check              Print environment/repo checks and exit
  --dry-run            Print actions without changing files
  --skip-packages      Skip package install via yay
  --gtk-gsettings       Also set GTK prefs via gsettings (Emacs keys + button layout) [default]
  --no-gtk-gsettings    Do not touch GTK gsettings
  --no-waybar          Skip Waybar config/scripts
  --with-shaders       Symlink ~/.config/hypr/shaders from /usr/share/aether/shaders
  --force-monitors     Always install ~/.config/hypr/monitors.conf
  --force-nvidia-env   Always install ~/.config/hypr/envs.conf and source it
  --skip-nvidia-env    Never install ~/.config/hypr/envs.conf
  -h, --help           Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --gtk-gsettings) APPLY_GTK_GSETTINGS=1 ;;
    --no-gtk-gsettings) APPLY_GTK_GSETTINGS=0 ;;
    --no-waybar) NO_WAYBAR=1 ;;
    --with-shaders) WITH_SHADERS=1 ;;
    --force-monitors) FORCE_MONITORS=1 ;;
    --force-nvidia-env) FORCE_NVIDIA_ENV=1 ;;
    --skip-nvidia-env) SKIP_NVIDIA_ENV=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

log() {
  printf '%s\n' "$*" >&2
}

preflight() {
  log "Preflight check"
  log "repo: $ROOT"
  log "source: $SRC_HOME"
  log

  if [[ ! -d "$SRC_HOME" ]]; then
    log "ERROR: missing source directory: $SRC_HOME"
    return 1
  fi

  local missing=0
  local f
  for f in \
    .config/environment.d/90-fcitx5.conf \
    .config/environment.d/fcitx.conf \
    .config/gtk-3.0/settings.ini \
    .config/gtk-4.0/settings.ini \
    .config/fcitx5/config \
    .config/fcitx5/profile \
    .config/fcitx5/conf/clipboard.conf \
    .config/fcitx5/conf/notifications.conf \
    .config/fcitx5/conf/xcb.conf \
    .config/hypr/bindings.conf \
    .config/hypr/hypridle.conf \
    .config/hypr/input.conf \
    .config/hypr/monitors.conf \
    .config/hypr/envs.conf \
    .config/systemd/user/lid-nosuspend.service \
    .config/waybar/config.jsonc \
    .config/waybar/style.css \
    .local/bin/hypr-ws \
    .local/bin/hyprsunset-adjust \
    .local/bin/hypr-opacity-adjust \
    .local/bin/hypr-blur-adjust \
    .local/bin/hypr-gaps-adjust \
    .local/bin/hypr-scale-adjust \
    .local/bin/hypr-refresh-toggle \
    .local/bin/hypr-main-monitor-toggle \
    .local/bin/hypr-internal-display-toggle \
    .local/bin/hypr-lid-suspend-toggle \
    .local/bin/waybar-main-monitor \
    .local/bin/waybar-lid-suspend \
    .local/bin/waybar-wwan \
    .local/bin/wwan-menu
  do
    if [[ -f "$SRC_HOME/$f" ]]; then
      log "ok: $f"
    else
      log "MISSING: $f"
      missing=1
    fi
  done

  log

  local c
  for c in install cp mkdir cmp date; do
    if command -v "$c" >/dev/null 2>&1; then
      log "cmd: $c"
    else
      log "cmd: $c (missing)"
    fi
  done

  for c in python python3 jq hyprctl systemctl notify-send omarchy-restart-waybar nmcli mmcli walker fzf yay; do
    if command -v "$c" >/dev/null 2>&1; then
      log "cmd: $c"
    else
      log "cmd: $c (missing)"
    fi
  done

  log
  if detect_nvidia; then
    log "detect: nvidia=yes"
  else
    log "detect: nvidia=no"
  fi
  if hyprctl_has_monitor "DP-4"; then
    log "detect: monitor DP-4=yes"
  else
    log "detect: monitor DP-4=no/unknown"
  fi

  if (( missing )); then
    log
    log "ERROR: repo is missing required source files"
    return 1
  fi

  return 0
}

ts() {
  date +%Y%m%d-%H%M%S
}

run() {
  if (( DRY_RUN )); then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

install_yay_packages() {
  if (( SKIP_PACKAGES )); then
    log "skip: packages (--skip-packages)"
    return 0
  fi

  if ! command -v yay >/dev/null 2>&1; then
    log "note: yay not found; skipping package install"
    return 0
  fi

  # Derived from reoring's current install state.
  local -a pkgs=(
    fcitx5
    fcitx5-configtool
    fcitx5-gtk
    fcitx5-qt
    cskk-git
    cskk-git-debug
    fcitx5-cskk-git
    fcitx5-cskk-git-debug
    skk-jisyo
  )

  log "Installing packages via yay (may prompt for sudo): ${pkgs[*]}"
  run yay -S --needed "${pkgs[@]}" || log "note: yay package install failed; continuing"
}

backup_if_needed() {
  local dest="$1"
  if [[ ! -e "$dest" ]]; then
    return 0
  fi

  local backup="${dest}.bak.$(ts)"
  run mkdir -p "$(dirname "$backup")"
  run cp -a "$dest" "$backup"
  log "backup: $dest -> $backup"
}

install_file() {
  local src="$1"
  local dest="$2"
  local mode="$3"

  if [[ ! -f "$src" ]]; then
    log "ERROR: missing source file: $src"
    return 1
  fi

  if [[ -e "$dest" ]] && cmp -s "$src" "$dest"; then
    log "ok: $dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    backup_if_needed "$dest"
  fi

  run mkdir -p "$(dirname "$dest")"
  run install -m "$mode" "$src" "$dest"
  log "installed: $dest"
}

detect_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 && return 0
  [[ -d /proc/driver/nvidia ]] && return 0
  return 1
}

hyprctl_has_monitor() {
  local name="$1"
  command -v hyprctl >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  hyprctl monitors -j 2>/dev/null | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null 2>&1
}

ensure_source_line() {
  local file="$1"
  local line="$2"
  local after_regex="$3"

  if [[ ! -f "$file" ]]; then
    log "skip: $file not found (cannot add source line)"
    return 0
  fi

  if grep -Fxq "$line" "$file"; then
    log "ok: already sourced in $file"
    return 0
  fi

  backup_if_needed "$file"
  if (( DRY_RUN )); then
    log "[dry-run] insert into $file: $line"
    return 0
  fi

  python - "$file" "$line" "$after_regex" <<'PY'
import re
import sys

path = sys.argv[1]
line = sys.argv[2]
after = sys.argv[3]

with open(path, 'r', encoding='utf-8', errors='replace') as f:
    lines = f.readlines()

if any(l.rstrip('\n') == line for l in lines):
    raise SystemExit(0)

pat = re.compile(after)
out = []
inserted = False

for l in lines:
    out.append(l)
    if (not inserted) and pat.search(l):
        if not out[-1].endswith('\n'):
            out[-1] = out[-1] + '\n'
        out.append(line + '\n')
        inserted = True

if not inserted:
    if out and not out[-1].endswith('\n'):
        out[-1] = out[-1] + '\n'
    out.append(line + '\n')

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(out)
PY

  log "updated: $file"
}

if (( CHECK_ONLY )); then
  preflight
  exit $?
fi

log "Applying reoring customizations to: $HOME"

install_yay_packages

# Fcitx5 (IME)
install_file "$SRC_HOME/.config/environment.d/90-fcitx5.conf" "$HOME/.config/environment.d/90-fcitx5.conf" 0644
install_file "$SRC_HOME/.config/environment.d/fcitx.conf" "$HOME/.config/environment.d/fcitx.conf" 0644

# GTK (key theme / window controls)
install_file "$SRC_HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini" 0644
install_file "$SRC_HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" 0644

install_file "$SRC_HOME/.config/fcitx5/config" "$HOME/.config/fcitx5/config" 0644
install_file "$SRC_HOME/.config/fcitx5/profile" "$HOME/.config/fcitx5/profile" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/notifications.conf" "$HOME/.config/fcitx5/conf/notifications.conf" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/xcb.conf" "$HOME/.config/fcitx5/conf/xcb.conf" 0644
install_file "$SRC_HOME/.config/fcitx5/conf/clipboard.conf" "$HOME/.config/fcitx5/conf/clipboard.conf" 0644

apply_gtk_gsettings() {
  if ! command -v gsettings >/dev/null 2>&1; then
    log "note: gsettings not found; skipping GTK gsettings"
    return 0
  fi

  # Best-effort: in many GTK setups, XSettings/GSettings override ~/.config/gtk-*/settings.ini.
  # These keys are commonly consumed by GTK apps (especially on GNOME/libadwaita stacks).
  run gsettings set org.gnome.desktop.interface gtk-key-theme 'Emacs' \
    || log "note: failed to set org.gnome.desktop.interface gtk-key-theme"
  run gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' \
    || log "note: failed to set org.gnome.desktop.wm.preferences button-layout"
}

if (( APPLY_GTK_GSETTINGS )); then
  apply_gtk_gsettings
else
  log "note: skipping GTK gsettings (--no-gtk-gsettings)"
fi

# Hyprland user configs
install_file "$SRC_HOME/.config/hypr/bindings.conf" "$HOME/.config/hypr/bindings.conf" 0644
install_file "$SRC_HOME/.config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf" 0644
install_file "$SRC_HOME/.config/hypr/input.conf" "$HOME/.config/hypr/input.conf" 0644

# Optional monitors.conf (machine-specific)
if (( FORCE_MONITORS )); then
  install_file "$SRC_HOME/.config/hypr/monitors.conf" "$HOME/.config/hypr/monitors.conf" 0644
else
  if hyprctl_has_monitor "DP-4"; then
    install_file "$SRC_HOME/.config/hypr/monitors.conf" "$HOME/.config/hypr/monitors.conf" 0644
  else
    log "skip: ~/.config/hypr/monitors.conf (DP-4 not detected; use --force-monitors)"
  fi
fi

# Optional NVIDIA envs (hardware-specific)
if (( SKIP_NVIDIA_ENV )); then
  log "skip: ~/.config/hypr/envs.conf (--skip-nvidia-env)"
else
  if (( FORCE_NVIDIA_ENV )) || detect_nvidia; then
    install_file "$SRC_HOME/.config/hypr/envs.conf" "$HOME/.config/hypr/envs.conf" 0644
    ensure_source_line "$HOME/.config/hypr/hyprland.conf" \
      'source = ~/.config/hypr/envs.conf' \
      '^source\s*=\s*~/.local/share/omarchy/default/hypr/envs\.conf\s*$'
  else
    log "skip: ~/.config/hypr/envs.conf (NVIDIA not detected; use --force-nvidia-env)"
  fi
fi

# Hypr helper scripts
install_file "$SRC_HOME/.local/bin/hypr-ws" "$HOME/.local/bin/hypr-ws" 0755
install_file "$SRC_HOME/.local/bin/hyprsunset-adjust" "$HOME/.local/bin/hyprsunset-adjust" 0755
install_file "$SRC_HOME/.local/bin/hypr-opacity-adjust" "$HOME/.local/bin/hypr-opacity-adjust" 0755
install_file "$SRC_HOME/.local/bin/hypr-blur-adjust" "$HOME/.local/bin/hypr-blur-adjust" 0755
install_file "$SRC_HOME/.local/bin/hypr-gaps-adjust" "$HOME/.local/bin/hypr-gaps-adjust" 0755
install_file "$SRC_HOME/.local/bin/hypr-scale-adjust" "$HOME/.local/bin/hypr-scale-adjust" 0755
install_file "$SRC_HOME/.local/bin/hypr-refresh-toggle" "$HOME/.local/bin/hypr-refresh-toggle" 0755
install_file "$SRC_HOME/.local/bin/hypr-main-monitor-toggle" "$HOME/.local/bin/hypr-main-monitor-toggle" 0755
install_file "$SRC_HOME/.local/bin/hypr-monitor-position" "$HOME/.local/bin/hypr-monitor-position" 0755
install_file "$SRC_HOME/.local/bin/hypr-internal-display-toggle" "$HOME/.local/bin/hypr-internal-display-toggle" 0755
install_file "$SRC_HOME/.local/bin/hypr-lid-suspend-toggle" "$HOME/.local/bin/hypr-lid-suspend-toggle" 0755

# systemd user service for lid toggle
install_file "$SRC_HOME/.config/systemd/user/lid-nosuspend.service" "$HOME/.config/systemd/user/lid-nosuspend.service" 0644

# Fcitx5: cskk addon depends on libcskk (cskk-git installs it under /usr/lib/cskk).
install_file \
  "$SRC_HOME/.config/systemd/user/app-org.fcitx.Fcitx5@autostart.service.d/override.conf" \
  "$HOME/.config/systemd/user/app-org.fcitx.Fcitx5@autostart.service.d/override.conf" \
  0644
if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user daemon-reload >/dev/null 2>&1 || true

  # Apply the new env immediately when possible.
  run systemctl --user try-restart app-org.fcitx.Fcitx5@autostart.service >/dev/null 2>&1 || true
fi

# Waybar (optional)
if (( NO_WAYBAR )); then
  log "skip: Waybar (--no-waybar)"
else
  install_file "$SRC_HOME/.local/bin/waybar-main-monitor" "$HOME/.local/bin/waybar-main-monitor" 0755
  install_file "$SRC_HOME/.local/bin/waybar-lid-suspend" "$HOME/.local/bin/waybar-lid-suspend" 0755
  install_file "$SRC_HOME/.local/bin/waybar-wwan" "$HOME/.local/bin/waybar-wwan" 0755
  install_file "$SRC_HOME/.local/bin/wwan-menu" "$HOME/.local/bin/wwan-menu" 0755
  install_file "$SRC_HOME/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc" 0644
  install_file "$SRC_HOME/.config/waybar/style.css" "$HOME/.config/waybar/style.css" 0644

  if command -v omarchy-restart-waybar >/dev/null 2>&1; then
    run omarchy-restart-waybar >/dev/null 2>&1 || true
  else
    log "note: restart waybar manually (e.g. omarchy-restart-waybar)"
  fi
fi

# Optional shaders directory
if (( WITH_SHADERS )); then
  if [[ -d /usr/share/aether/shaders ]]; then
    run mkdir -p "$HOME/.config/hypr/shaders"
    for f in /usr/share/aether/shaders/*.glsl; do
      [[ -e "$f" ]] || continue
      run ln -sf "$f" "$HOME/.config/hypr/shaders/$(basename "$f")"
    done
    log "linked: ~/.config/hypr/shaders -> /usr/share/aether/shaders"
  else
    log "skip: /usr/share/aether/shaders not found"
  fi
fi

# Trigger reloads when possible
if command -v hyprctl >/dev/null 2>&1; then
  run hyprctl reload >/dev/null 2>&1 || true
fi

log "Done. Backups are saved as *.bak.YYYYmmdd-HHMMSS next to the originals."
