#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: rollback.sh [options]

Restore the latest *.bak.YYYYmmdd-HHMMSS backups created by apply.sh.

Options:
  --dry-run   Print actions without changing files
  -h, --help  Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf '%s\n' "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

log() {
  printf '%s\n' "$*" >&2
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

latest_apply_backup_for() {
  local dest="$1"

  shopt -s nullglob
  local candidates=("${dest}.bak."*)
  shopt -u nullglob

  local best_path=""
  local best_ts=""

  local p
  for p in "${candidates[@]}"; do
    [[ "$p" == *".bak.rollback."* ]] && continue

    local t
    t="${p##*.bak.}"
    if [[ "$t" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
      if [[ -z "$best_ts" || "$t" > "$best_ts" ]]; then
        best_ts="$t"
        best_path="$p"
      fi
    fi
  done

  printf '%s' "$best_path"
}

backup_current() {
  local dest="$1"
  if [[ ! -e "$dest" ]]; then
    return 0
  fi

  local backup="${dest}.bak.rollback.$(ts)"
  run mkdir -p "$(dirname "$backup")"
  run cp -a "$dest" "$backup"
  log "backup: $dest -> $backup"
}

restore_one() {
  local dest="$1"

  local backup
  backup="$(latest_apply_backup_for "$dest")"
  if [[ -z "$backup" ]]; then
    log "skip: $dest (no backup found)"
    return 0
  fi

  backup_current "$dest"
  run mkdir -p "$(dirname "$dest")"
  run cp -a "$backup" "$dest"
  log "restored: $dest <- $backup"
}

log "Rolling back reoring customizations in: $HOME"

dests=(
  "$HOME/.config/environment.d/90-fcitx5.conf"
  "$HOME/.config/environment.d/fcitx.conf"
  "$HOME/.config/gtk-3.0/settings.ini"
  "$HOME/.config/gtk-4.0/settings.ini"
  "$HOME/.config/fcitx5/config"
  "$HOME/.config/fcitx5/profile"
  "$HOME/.config/fcitx5/conf/clipboard.conf"
  "$HOME/.config/fcitx5/conf/notifications.conf"
  "$HOME/.config/fcitx5/conf/xcb.conf"

  "$HOME/.config/hypr/bindings.conf"
  "$HOME/.config/hypr/hypridle.conf"
  "$HOME/.config/hypr/input.conf"
  "$HOME/.config/hypr/monitors.conf"
  "$HOME/.config/hypr/envs.conf"

  "$HOME/.local/bin/hypr-ws"
  "$HOME/.local/bin/hyprsunset-adjust"
  "$HOME/.local/bin/hypr-opacity-adjust"
  "$HOME/.local/bin/hypr-blur-adjust"
  "$HOME/.local/bin/hypr-gaps-adjust"
  "$HOME/.local/bin/hypr-scale-adjust"
  "$HOME/.local/bin/hypr-refresh-toggle"
  "$HOME/.local/bin/hypr-main-monitor-toggle"
  "$HOME/.local/bin/hypr-monitor-position"
  "$HOME/.local/bin/hypr-internal-display-toggle"
  "$HOME/.local/bin/hypr-lid-suspend-toggle"

  "$HOME/.config/systemd/user/lid-nosuspend.service"

  "$HOME/.local/bin/waybar-main-monitor"
  "$HOME/.local/bin/waybar-lid-suspend"
  "$HOME/.config/waybar/config.jsonc"
  "$HOME/.config/waybar/style.css"
)

for dest in "${dests[@]}"; do
  restore_one "$dest"
done

log "Done."
