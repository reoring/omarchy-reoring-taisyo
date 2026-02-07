#!/usr/bin/env bash
set -euo pipefail

# Setup Wi-Fi tethering (Access Point) on ThinkPad X1 13".
#
# This machine commonly runs:
# - Wi-Fi/Ethernet: iwd + systemd-networkd
# - WWAN: NetworkManager + ModemManager
#
# Because NetworkManager is configured to leave wl* unmanaged
# (/etc/NetworkManager/conf.d/10-wwan-only.conf), use iwd for AP mode and let
# systemd-networkd provide DHCP + NAT (IPMasquerade) on the AP interface.

MARKER="Managed by hey-omarchy (ThinkPad X1-13 Wi-Fi AP)"

DEFAULT_IFACE="wlan0"
DEFAULT_SSID="TPX1-WWAN"
DEFAULT_ADDR="10.42.0.1/24"
DEFAULT_DNS1="1.1.1.1"
DEFAULT_DNS2="8.8.8.8"
DEFAULT_UPLINK="auto"
DEFAULT_UPLINK_FALLBACK="wwan0"
DEFAULT_USE_UFW=1

UFW_COMMENT_PREFIX="hey-omarchy hotspot"

usage() {
  cat <<'EOF'
Usage:
  setup-wifi-ap-from-wwan.sh install [--iface IFACE] [--address CIDR] [--dns DNS1,DNS2]
  setup-wifi-ap-from-wwan.sh start   [--iface IFACE] [--ssid SSID] [--pass PASS] [--uplink IFACE|auto] [--no-ufw]
  setup-wifi-ap-from-wwan.sh stop    [--iface IFACE] [--uplink IFACE|auto] [--no-ufw]
  setup-wifi-ap-from-wwan.sh status  [--iface IFACE]
  setup-wifi-ap-from-wwan.sh uninstall [--iface IFACE] [--uplink IFACE|auto] [--no-ufw]

What it does:
  - Installs a systemd-networkd .network file that only applies when IFACE is in
    AP mode (WLANInterfaceType=ap): static address + DHCP server + IPv4 NAT.
  - Starts/stops an access point via iwd (iwctl ap ...).

Notes:
  - Starting AP will disconnect IFACE from any current Wi-Fi network.
  - This script does NOT install packages. You need: iwd + systemd-networkd.
  - If systemd-resolved is used (stub 127.0.0.53), explicitly setting DNS for
    DHCP clients is recommended (default: 1.1.1.1, 8.8.8.8).
  - If ufw is active, start/stop will add/remove ufw rules for DHCP (udp/67)
    and forwarding (IFACE -> UPLINK). Use --no-ufw to skip.
EOF
}

action="${1:-}"
shift || true

iface="$DEFAULT_IFACE"
ssid="$DEFAULT_SSID"
passphrase=""
addr="$DEFAULT_ADDR"
dns1="$DEFAULT_DNS1"
dns2="$DEFAULT_DNS2"
uplink="$DEFAULT_UPLINK"
use_ufw=$DEFAULT_USE_UFW

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --iface) iface="${2:-}"; shift 2 ;;
    --ssid) ssid="${2:-}"; shift 2 ;;
    --pass) passphrase="${2:-}"; shift 2 ;;
    --uplink) uplink="${2:-}"; shift 2 ;;
    --address) addr="${2:-}"; shift 2 ;;
    --dns)
      dns_csv="${2:-}"
      shift 2
      dns1="${dns_csv%%,*}"
      dns2="${dns_csv#*,}"
      if [[ "$dns2" == "$dns_csv" ]]; then
        dns2=""
      fi
      ;;
    --no-ufw) use_ufw=0; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

case "$action" in
  install|start|stop|status|uninstall) ;;
  -h|--help|help|"") usage; exit 0 ;;
  *) echo "Unknown action: $action" >&2; usage; exit 2 ;;
esac

SUDO=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "This script needs root (or sudo)." >&2
    exit 1
  fi
fi

timestamp() {
  date +%Y%m%d-%H%M%S
}

has_marker() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qF "$MARKER" "$f" 2>/dev/null
}

backup_if_needed() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if has_marker "$f"; then
    return 0
  fi
  local bak="${f}.bak.$(timestamp)"
  $SUDO cp -a "$f" "$bak"
  echo "Backup: $bak"
}

install_file() {
  local mode="$1"
  local path="$2"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  $SUDO install -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
}

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "Missing command: $c" >&2
    return 1
  fi
  return 0
}

gen_passphrase() {
  # WPA2-PSK requires 8..63 characters.
  if [[ -r /dev/urandom ]] && command -v tr >/dev/null 2>&1 && command -v head >/dev/null 2>&1; then
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
    return 0
  fi
  return 1
}

network_file="/etc/systemd/network/15-${iface}-ap.network"
state_dir="/run/hey-omarchy"
uplink_state_file="$state_dir/wifi-ap-${iface}.uplink"

resolve_uplink() {
  if [[ -n "$uplink" && "$uplink" != "auto" ]]; then
    echo "$uplink"
    return 0
  fi

  if command -v ip >/dev/null 2>&1 && command -v awk >/dev/null 2>&1; then
    local dev
    dev="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}')"
    if [[ -n "${dev:-}" ]]; then
      echo "$dev"
      return 0
    fi
  fi

  echo "$DEFAULT_UPLINK_FALLBACK"
}

write_uplink_state() {
  local dev="$1"
  if ! $SUDO install -d -m 0755 "$state_dir"; then
    return 1
  fi
  if ! $SUDO sh -c "printf '%s\\n' '$dev' > '$uplink_state_file'"; then
    return 1
  fi
}

read_uplink_state() {
  if [[ -r "$uplink_state_file" ]]; then
    local dev=""
    IFS= read -r dev <"$uplink_state_file" || true
    if [[ -n "$dev" ]]; then
      echo "$dev"
      return 0
    fi
  fi
  return 1
}

ufw_available() {
  command -v ufw >/dev/null 2>&1
}

ufw_cleanup_hotspot_rules() {
  [[ "$use_ufw" -eq 1 ]] || return 0
  ufw_available || return 0

  # Prefer deleting by our comment prefix (stable even if uplink changed).
  local nums=""
  nums="$($SUDO ufw status numbered 2>/dev/null | awk -v prefix="$UFW_COMMENT_PREFIX" '
    match($0, /^\[[[:space:]]*([0-9]+)\]/, m) { last=m[1] }
    /^[[:space:]]*#/ && index($0, prefix) { if (last != "") print last }
  ' | sort -rn | uniq || true)"

  if [[ -n "$nums" ]]; then
    while IFS= read -r n; do
      [[ -n "$n" ]] || continue
      $SUDO ufw --force delete "$n" >/dev/null 2>&1 || true
    done <<<"$nums"
  fi

  # Fallback: delete by rule spec (best-effort).
  $SUDO ufw --force delete allow in on "$iface" to any port 67 proto udp >/dev/null 2>&1 || true

  local dev=""
  if dev="$(read_uplink_state 2>/dev/null)"; then
    $SUDO ufw --force route delete allow in on "$iface" out on "$dev" >/dev/null 2>&1 || true
  else
    dev="$(resolve_uplink)"
    $SUDO ufw --force route delete allow in on "$iface" out on "$dev" >/dev/null 2>&1 || true
  fi

  $SUDO rm -f "$uplink_state_file" >/dev/null 2>&1 || true
}

ufw_setup_hotspot_rules() {
  [[ "$use_ufw" -eq 1 ]] || return 0
  ufw_available || return 0

  local dev
  dev="$(resolve_uplink)"

  if [[ -z "$dev" ]]; then
    echo "ufw: could not determine uplink (use --uplink IFACE); skipping." >&2
    return 0
  fi

  # Ensure a clean slate for our rules.
  ufw_cleanup_hotspot_rules || true

  echo "ufw: allow DHCP (udp/67) on $iface"
  if ! $SUDO ufw allow in on "$iface" to any port 67 proto udp comment "$UFW_COMMENT_PREFIX dhcp" >/dev/null; then
    echo "ufw: failed to add DHCP rule" >&2
  fi

  echo "ufw: allow forwarding $iface -> $dev"
  if ! $SUDO ufw route allow in on "$iface" out on "$dev" comment "$UFW_COMMENT_PREFIX forward" >/dev/null; then
    echo "ufw: failed to add forwarding rule" >&2
  fi

  write_uplink_state "$dev" || true
}

install_networkd_ap_file() {
  $SUDO install -d -m 0755 /etc/systemd/network
  backup_if_needed "$network_file"
  install_file 0644 "$network_file" <<EOF
# $MARKER
[Match]
Name=$iface
WLANInterfaceType=ap

[Network]
Address=$addr
DHCPServer=yes
IPMasquerade=ipv4

[DHCPServer]
PersistLeases=runtime
DNS=$dns1
EOF
  if [[ -n "$dns2" ]]; then
    $SUDO sh -c "printf '%s\n' 'DNS=$dns2' >> '$network_file'"
  fi

  echo "Installed: $network_file"
  $SUDO networkctl reload >/dev/null 2>&1 || true
}

uninstall_networkd_ap_file() {
  if [[ -f "$network_file" ]] && has_marker "$network_file"; then
    $SUDO rm -f "$network_file"
    echo "Removed: $network_file"
    $SUDO networkctl reload >/dev/null 2>&1 || true
  else
    echo "Not removing (missing or not ours): $network_file"
  fi
}

start_ap() {
  require_cmd iwctl
  require_cmd networkctl

  if [[ -z "$passphrase" ]]; then
    if passphrase="$(gen_passphrase 2>/dev/null)"; then
      echo "Generated passphrase: $passphrase"
    else
      echo "Error: passphrase required (use --pass)." >&2
      exit 1
    fi
  fi

  if [[ ${#passphrase} -lt 8 || ${#passphrase} -gt 63 ]]; then
    echo "Error: passphrase length must be 8..63 characters." >&2
    exit 2
  fi

  if [[ ! -f "$network_file" ]]; then
    echo "Network config not installed yet: $network_file" >&2
    echo "Run: bash $0 install" >&2
    exit 1
  fi

  # iwd exposes the AccessPoint D-Bus interface only when the device Mode is set
  # to "ap". Switching the Mode may power the interface off, so power it back on.
  $SUDO iwctl device "$iface" set-property Mode ap >/dev/null 2>&1 || true
  $SUDO iwctl device "$iface" set-property Powered on >/dev/null 2>&1 || true

  # Best-effort: disconnect station mode (ignore errors).
  $SUDO iwctl station "$iface" disconnect >/dev/null 2>&1 || true

  echo "Starting AP: iface=$iface ssid=$ssid"
  if ! $SUDO iwctl ap "$iface" start "$ssid" "$passphrase"; then
    if iwctl ap "$iface" show 2>/dev/null | grep -Eq '^[[:space:]]*Started[[:space:]]+yes[[:space:]]*$'; then
      echo "AP already started; continuing."
    else
      echo "Failed to start AP." >&2
      exit 1
    fi
  fi

  # Ensure networkd picks up WLANInterfaceType=ap match.
  $SUDO networkctl reconfigure "$iface" >/dev/null 2>&1 || true

  ufw_setup_hotspot_rules || true

  echo "Status:"
  iwctl ap "$iface" show || true
  $SUDO networkctl status "$iface" --no-pager || true
}

stop_ap() {
  require_cmd iwctl
  require_cmd networkctl

  echo "Stopping AP: iface=$iface"
  $SUDO iwctl ap "$iface" stop || true

  ufw_cleanup_hotspot_rules || true

  # Return to station mode for normal Wi-Fi use.
  $SUDO iwctl device "$iface" set-property Mode station >/dev/null 2>&1 || true
  $SUDO iwctl device "$iface" set-property Powered on >/dev/null 2>&1 || true

  # Re-apply normal station config (20-wlan.network) if/when iwd returns to managed.
  $SUDO networkctl reconfigure "$iface" >/dev/null 2>&1 || true

  echo "Status:"
  iwctl ap list || true
  $SUDO networkctl status "$iface" --no-pager || true
}

show_status() {
  require_cmd iwctl
  require_cmd iw
  require_cmd networkctl

  echo "Wi-Fi interface: $iface"
  iw dev || true
  echo ""
  iwctl ap list || true
  echo ""
  iwctl ap "$iface" show || true
  echo ""
  $SUDO networkctl status "$iface" --no-pager || true
}

case "$action" in
  install)
    install_networkd_ap_file
    ;;
  start)
    start_ap
    ;;
  stop)
    stop_ap
    ;;
  status)
    show_status
    ;;
  uninstall)
    ufw_cleanup_hotspot_rules || true
    uninstall_networkd_ap_file
    ;;
esac
