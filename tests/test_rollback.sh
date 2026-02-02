#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
bindir="$tmp/bin"
mkdir -p "$home" "$bindir"

write_stub() {
  local name="$1"
  local body="$2"
  local path="$bindir/$name"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '%s\n' "$body"
  } >"$path"
  chmod +x "$path"
}

write_stub systemctl 'exit 0'
write_stub hyprctl 'case "${1:-}" in monitors) printf "%s\n" "[]" ;; *) exit 0 ;; esac'
write_stub notify-send 'exit 0'
write_stub omarchy-restart-waybar 'exit 0'

mkdir -p "$home/.config/hypr"
printf '%s\n' "OLD_INPUT" >"$home/.config/hypr/input.conf"

HOME="$home" PATH="$bindir:$PATH" bash ./apply.sh --skip-packages --no-waybar --force-monitors --skip-nvidia-env >/dev/null

if grep -Fxq "OLD_INPUT" "$home/.config/hypr/input.conf"; then
  printf '%s\n' "expected input.conf to be overwritten by apply.sh" >&2
  exit 1
fi

set +e
out=$(HOME="$home" PATH="$bindir:$PATH" bash ./rollback.sh 2>&1)
st=$?
set -e

if [[ $st -ne 0 ]]; then
  printf '%s\n' "expected: rollback exit 0" >&2
  printf '%s\n' "actual:   exit $st" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi

if ! grep -Fxq "OLD_INPUT" "$home/.config/hypr/input.conf"; then
  printf '%s\n' "expected rollback to restore original input.conf" >&2
  exit 1
fi

printf '%s\n' "PASS: rollback restores input.conf"
