#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Setup mpvpaper (video live wallpaper) for Omarchy/Hyprland.

Usage:
  bash setup-mpvpaper-live-wallpaper.sh --video /path/to/wallpaper.mp4 [--monitor eDP-1] [--mode fill]
  bash setup-mpvpaper-live-wallpaper.sh --disable

Options:
  --video PATH        Path to an .mp4 (or any mpv-supported file)
  --monitor NAME      Hyprland monitor name (e.g. eDP-1, DP-1)
  --mode MODE         Video sizing: fit (default), fill (crop to remove bars), stretch (distort)
  --with-audio        Enable audio (default: off)
  --mpv-opts STRING   Extra mpv options (appended)
  --disable           Disable live wallpaper (removes Hyprland autostart block, stops mpvpaper)
  --noconfirm         Pass --noconfirm to yay
  -h, --help          Show this help

What it does:
  - Installs: mpv, mpvpaper (via yay)
  - Writes:  ~/.config/mpvpaper-wallpaper.env
  - Writes:  ~/.local/bin/start-mpvpaper-wallpaper
  - Updates: ~/.config/hypr/autostart.conf (adds exec-once)
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

video=""
monitor=""
mode="fit"
with_audio=0
mpv_opts_extra=""
noconfirm=0
disable=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disable)
      disable=1
      shift
      ;;
    --video)
      [[ ${2-} ]] || die "--video requires a value"
      video="$2"
      shift 2
      ;;
    --monitor)
      [[ ${2-} ]] || die "--monitor requires a value"
      monitor="$2"
      shift 2
      ;;
    --with-audio)
      with_audio=1
      shift
      ;;
    --mode)
      [[ ${2-} ]] || die "--mode requires a value"
      mode="$2"
      shift 2
      ;;
    --mpv-opts)
      [[ ${2-} ]] || die "--mpv-opts requires a value"
      mpv_opts_extra="$2"
      shift 2
      ;;
    --noconfirm)
      noconfirm=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1 (use --help)"
      ;;
  esac
done

hypr_autostart="$HOME/.config/hypr/autostart.conf"
launcher="$HOME/.local/bin/start-mpvpaper-wallpaper"

if [[ $disable -eq 1 ]]; then
  need_cmd python3

  mkdir -p "$HOME/.config/hypr"

  # Remove our managed block from Hyprland autostart (if present).
  python3 - <<'PY'
import os

autostart = os.path.expanduser('~/.config/hypr/autostart.conf')
begin = '# --- mpvpaper live wallpaper (managed by setup-mpvpaper-live-wallpaper.sh) ---\n'
end = '# --- end mpvpaper live wallpaper ---\n'

try:
  with open(autostart, 'r', encoding='utf-8') as f:
    s = f.read()
except FileNotFoundError:
  s = ''

if begin in s and end in s:
  pre = s.split(begin, 1)[0]
  post = s.split(end, 1)[1]
  out = pre + post
  with open(autostart, 'w', encoding='utf-8') as f:
    f.write(out)
PY

  pkill -x mpvpaper >/dev/null 2>&1 || true

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi

  printf 'Disabled mpvpaper live wallpaper.\n'
  printf '  Hypr:   %s\n' "$hypr_autostart"
  printf '  Runner: %s\n' "$launcher"
  exit 0
fi

[[ -n "$video" ]] || die "--video is required (or use --disable)"

if [[ ! -f "$video" ]]; then
  die "video not found: $video"
fi

need_cmd yay
need_cmd python3

if command -v meson >/dev/null 2>&1; then
  if ! meson --version >/dev/null 2>&1; then
    cat >&2 <<'EOF'
error: meson is present but broken (Python module 'mesonbuild' not found).

This usually means a partial upgrade: your installed Python version doesn't match
the repository versions.

Fix:
  sudo pacman -Syu

Then rerun this script.
EOF
    exit 1
  fi
fi

yay_flags=(--needed)
if [[ $noconfirm -eq 1 ]]; then
  yay_flags+=(--noconfirm --answerclean None --answerdiff None)
fi

printf 'Installing packages with yay...\n'
yay -S "${yay_flags[@]}" mpv mpvpaper

if [[ -z "$monitor" ]]; then
  if command -v hyprctl >/dev/null 2>&1; then
    if hyprctl monitors >/dev/null 2>&1; then
      monitor="$(hyprctl monitors | awk '/^Monitor /{print $2; exit}')"
    fi
  fi

  if [[ -z "$monitor" && -f "$HOME/.config/hypr/monitors.conf" ]]; then
    monitor="$(awk '
      $0 !~ /^[[:space:]]*#/ {
        if (match($0, /^[[:space:]]*monitor[[:space:]]*=[[:space:]]*([^,[:space:]]+)/, a)) {
          print a[1];
          exit
        }
      }
    ' "$HOME/.config/hypr/monitors.conf" 2>/dev/null || true)"
  fi
fi

[[ -n "$monitor" ]] || die "could not auto-detect monitor; pass --monitor (e.g. --monitor eDP-1)"

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/hypr"

env_file="$HOME/.config/mpvpaper-wallpaper.env"

base_mpv_opts="--loop-file=inf --no-terminal --no-input-default-bindings"

case "$mode" in
  fit)
    ;;
  fill)
    base_mpv_opts="$base_mpv_opts --panscan=1.0"
    ;;
  stretch)
    base_mpv_opts="$base_mpv_opts --keepaspect=no"
    ;;
  *)
    die "invalid --mode: $mode (expected: fit|fill|stretch)"
    ;;
esac

if [[ $with_audio -eq 0 ]]; then
  base_mpv_opts="$base_mpv_opts --no-audio"
fi
if [[ -n "$mpv_opts_extra" ]]; then
  base_mpv_opts="$base_mpv_opts $mpv_opts_extra"
fi

{
  printf 'MONITOR=%q\n' "$monitor"
  printf 'VIDEO=%q\n' "$video"
  printf 'MPV_OPTS=%q\n' "$base_mpv_opts"
} >"$env_file"

cat >"$launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cfg="$HOME/.config/mpvpaper-wallpaper.env"
if [[ ! -f "$cfg" ]]; then
  echo "error: missing $cfg" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$cfg"

pkill -x mpvpaper >/dev/null 2>&1 || true
pkill -x swaybg >/dev/null 2>&1 || true

if command -v uwsm-app >/dev/null 2>&1; then
  exec uwsm-app -- mpvpaper -o "$MPV_OPTS" "$MONITOR" "$VIDEO"
else
  exec mpvpaper -o "$MPV_OPTS" "$MONITOR" "$VIDEO"
fi
EOF
chmod +x "$launcher"

touch "$hypr_autostart"

python3 - <<'PY'
import os

autostart = os.path.expanduser('~/.config/hypr/autostart.conf')
launcher = os.path.expanduser('~/.local/bin/start-mpvpaper-wallpaper')

begin = '# --- mpvpaper live wallpaper (managed by setup-mpvpaper-live-wallpaper.sh) ---\n'
end = '# --- end mpvpaper live wallpaper ---\n'
block = begin + f'exec-once = {launcher}\n' + end

try:
  with open(autostart, 'r', encoding='utf-8') as f:
    s = f.read()
except FileNotFoundError:
  s = ''

if begin in s and end in s:
  pre = s.split(begin, 1)[0]
  post = s.split(end, 1)[1]
  out = pre + block + post
else:
  if s and not s.endswith('\n'):
    s += '\n'
  out = s + '\n' + block if s else block

with open(autostart, 'w', encoding='utf-8') as f:
  f.write(out)
PY

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true

  # Hyprland's exec-once won't run on reload; start it now for immediate effect.
  hyprctl dispatch exec "$launcher" >/dev/null 2>&1 || true
fi

printf '\nDone.\n'
printf '  Monitor: %s\n' "$monitor"
printf '  Video:   %s\n' "$video"
printf '  Config:  %s\n' "$env_file"
printf '  Runner:  %s\n' "$launcher"
printf '  Hypr:    %s\n' "$hypr_autostart"

cat <<'EOF'

Note:
  Hyprland does not re-run exec-once on config reload.
  This script tries to start the wallpaper immediately; if you still don't see it,
  run:
    hyprctl dispatch exec "$HOME/.local/bin/start-mpvpaper-wallpaper"
  or log out and back in.
EOF
