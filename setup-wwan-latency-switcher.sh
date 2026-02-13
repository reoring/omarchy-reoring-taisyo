#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="wwan-latency-switcher.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
DAEMON_SRC="home/.local/bin/wwan-latency-switcher"
DAEMON_DEST="/usr/local/bin/wwan-latency-switcher"
CONFIG_DIR="/etc/wwan-latency-switcher"
CONFIG_FILE="${CONFIG_DIR}/config"

usage() {
  cat >&2 <<'EOF'
Usage:
  setup-wwan-latency-switcher.sh install     Install daemon + systemd service (default)
  setup-wwan-latency-switcher.sh uninstall   Remove daemon + service (preserves config)
  setup-wwan-latency-switcher.sh status      Show service status
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

action="${1:-install}"
case "$action" in
  install|uninstall|status) ;;
  -h|--help|help) usage; exit 0 ;;
  *) log "Unknown action: $action"; usage; exit 2 ;;
esac

# -------------------------------------------------------------------
# status
# -------------------------------------------------------------------
if [[ "$action" == "status" ]]; then
  if [[ ! -f "$SERVICE_PATH" ]]; then
    log "Service not installed ($SERVICE_PATH not found)"
    exit 1
  fi
  systemctl is-active "$SERVICE_NAME" || true
  systemctl is-enabled "$SERVICE_NAME" || true
  log ""
  if command -v wwan-latency-switcher >/dev/null 2>&1; then
    wwan-latency-switcher status 2>/dev/null || true
  elif [[ -x "$DAEMON_DEST" ]]; then
    "$DAEMON_DEST" status 2>/dev/null || true
  fi
  exit 0
fi

# -------------------------------------------------------------------
# uninstall
# -------------------------------------------------------------------
if [[ "$action" == "uninstall" ]]; then
  sudo systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
  sudo rm -f "$SERVICE_PATH" "$DAEMON_DEST"
  sudo systemctl daemon-reload
  log "Removed: $SERVICE_PATH"
  log "Removed: $DAEMON_DEST"
  log "Note: config preserved at $CONFIG_DIR (remove manually if desired)"
  exit 0
fi

# -------------------------------------------------------------------
# install
# -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/${DAEMON_SRC}"

if [[ ! -f "$SRC" ]]; then
  fail "Daemon script not found: $SRC"
fi

log "Installing daemon to $DAEMON_DEST"
sudo install -m 0755 "$SRC" "$DAEMON_DEST"

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "Creating default config at $CONFIG_FILE"
  sudo install -d -m 0755 "$CONFIG_DIR"
  sudo install -m 0644 /dev/stdin "$CONFIG_FILE" <<'EOF'
# wwan-latency-switcher configuration
# This file is sourced as shell; use KEY=value syntax.

MODEM_ID=0
IFACE=wwan0
TARGETS="1.1.1.1 8.8.8.8"
POLL_INTERVAL=10

# Degradation thresholds
DEGRADE_MEDIAN=120
DEGRADE_P95=300
DEGRADE_LOSS=2
DEGRADE_WINDOW=60
DEGRADE_COUNT=3

# Recovery thresholds
RECOVER_MEDIAN=70
RECOVER_P95=150
RECOVER_LOSS=1
RECOVER_WINDOW=600

# Flap guard
COOLDOWN=300
MIN_STATE_TIME=600
MAX_SWITCHES_PER_HOUR=2

# mmcli commands (%MODEM% is replaced with MODEM_ID)
CMD_FORCE_LTE="mmcli -m %MODEM% --set-allowed-modes=4g"
CMD_PREFER_5G="mmcli -m %MODEM% --set-allowed-modes=4g|5g --set-preferred-mode=5g"
CMD_PREFER_5G_FALLBACK="mmcli -m %MODEM% --set-allowed-modes=4g|5g"
EOF
else
  log "Config already exists at $CONFIG_FILE (preserved)"
fi

log "Installing systemd unit to $SERVICE_PATH"

tmp_unit="$(mktemp)"
trap 'rm -f "$tmp_unit"' EXIT

cat >"$tmp_unit" <<EOF
[Unit]
Description=WWAN latency-based 4G/5G switching daemon
After=ModemManager.service NetworkManager.service
Wants=ModemManager.service

[Service]
Type=simple
ExecStart=${DAEMON_DEST} daemon
Restart=always
RestartSec=3
RuntimeDirectory=wwan-latency-switcher

[Install]
WantedBy=multi-user.target
EOF

sudo install -m 0644 "$tmp_unit" "$SERVICE_PATH"

sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME"

log ""
log "Installed: $DAEMON_DEST"
log "Installed: $SERVICE_PATH"
log "Config:    $CONFIG_FILE"
log "Enabled:   $SERVICE_NAME"
log ""
log "Next:"
log "  journalctl -u $SERVICE_NAME -f"
log "  wwan-latency-switcher status"
