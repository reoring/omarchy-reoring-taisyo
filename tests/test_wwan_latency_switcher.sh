#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DAEMON="$ROOT/home/.local/bin/wwan-latency-switcher"
PASS=0
FAIL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bindir="$tmp/bin"
mkdir -p "$bindir"

write_stub() {
  local name="$1"
  local body="$2"
  local path="$bindir/$name"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "$body"
  } >"$path"
  chmod +x "$path"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf 'PASS: %s\n' "$label"
    (( PASS++ )) || true
  else
    printf 'FAIL: %s  expected=[%s]  actual=[%s]\n' "$label" "$expected" "$actual" >&2
    (( FAIL++ )) || true
  fi
}

assert_match() {
  local label="$1" pattern="$2" actual="$3"
  if [[ "$actual" =~ $pattern ]]; then
    printf 'PASS: %s\n' "$label"
    (( PASS++ )) || true
  else
    printf 'FAIL: %s  pattern=[%s]  actual=[%s]\n' "$label" "$pattern" "$actual" >&2
    (( FAIL++ )) || true
  fi
}

# -------------------------------------------------------------------
# Source daemon functions (non-daemon path)
# -------------------------------------------------------------------
# We source the script in a subshell with a mock environment so we can
# call individual functions. The script dispatches on $1 so we override
# that to avoid triggering main_daemon or cmd_status.

# Helper: run a bash snippet that sources the daemon and calls a function
run_fn() {
  local setup="$1"
  local call="$2"
  bash -c "
    set -euo pipefail
    # Prevent dispatch at end of source by wrapping in a function
    eval \"\$(sed 's/^cmd=.*\$/cmd=__source__/;s/^case \"\\\$cmd\"$/case \"__never__\"/' '$DAEMON')\"
    $setup
    $call
  " 2>/dev/null || true
}

# Better approach: extract and test functions by sourcing with overrides
eval_daemon() {
  local snippet="$1"
  PATH="$bindir:$PATH" bash -c "
    set -euo pipefail
    # Source everything but skip the dispatch at the bottom
    source <(sed '/^cmd=.*/,\$d' '$DAEMON')
    $snippet
  " 2>&1
}

# -------------------------------------------------------------------
# Test: ping_target parsing
# -------------------------------------------------------------------

# Create a mock ping that outputs realistic data
write_stub ping '
if [[ "${*}" == *"1.1.1.1"* ]]; then
  cat <<PINGEOF
PING 1.1.1.1 (1.1.1.1) from 10.0.0.1 wwan0: 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=55 time=45.2 ms
64 bytes from 1.1.1.1: icmp_seq=2 ttl=55 time=52.1 ms
64 bytes from 1.1.1.1: icmp_seq=3 ttl=55 time=48.7 ms
64 bytes from 1.1.1.1: icmp_seq=4 ttl=55 time=120.3 ms
64 bytes from 1.1.1.1: icmp_seq=5 ttl=55 time=50.5 ms

--- 1.1.1.1 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 804ms
rtt min/avg/max/mdev = 45.200/63.360/120.300/28.456 ms
PINGEOF
elif [[ "${*}" == *"8.8.8.8"* ]]; then
  cat <<PINGEOF
PING 8.8.8.8 (8.8.8.8) from 10.0.0.1 wwan0: 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=35.1 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=38.4 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=117 time=42.0 ms
64 bytes from 8.8.8.8: icmp_seq=5 ttl=117 time=39.8 ms

--- 8.8.8.8 ping statistics ---
5 packets transmitted, 4 received, 20% packet loss, time 804ms
rtt min/avg/max/mdev = 35.100/38.825/42.000/2.456 ms
PINGEOF
fi
'

# Test ping_target with good latency target
result=$(eval_daemon '
IFACE=wwan0
PING_COUNT=5
PING_INTERVAL=0.2
PING_TIMEOUT=1
PING_CMD=ping
result=$(ping_target "1.1.1.1")
echo "$result"
')

# Expected: sorted RTTs are 45.2, 48.7, 50.5, 52.1, 120.3
# Median (index 2) = 50.5
# P95 (index 4) = 120.3
# Loss = 0%
read -r med p95 loss <<<"$result"
assert_eq "ping_target median" "50.50" "$med"
assert_eq "ping_target p95" "120.30" "$p95"
assert_eq "ping_target loss" "0.0" "$loss"

# Test ping_target with lossy target
result2=$(eval_daemon '
IFACE=wwan0
PING_COUNT=5
PING_INTERVAL=0.2
PING_TIMEOUT=1
PING_CMD=ping
result=$(ping_target "8.8.8.8")
echo "$result"
')

read -r med2 p95_2 loss2 <<<"$result2"
# Sorted RTTs: 35.1, 38.4, 39.8, 42.0 → median=(38.4+39.8)/2=39.1, p95=42.0
assert_eq "ping_target lossy median" "39.10" "$med2"
assert_eq "ping_target lossy p95" "42.00" "$p95_2"
assert_eq "ping_target lossy loss" "20.0" "$loss2"

# -------------------------------------------------------------------
# Test: measure_all aggregation
# -------------------------------------------------------------------
result_all=$(eval_daemon '
IFACE=wwan0
PING_COUNT=5
PING_INTERVAL=0.2
PING_TIMEOUT=1
PING_CMD=ping
TARGETS="1.1.1.1 8.8.8.8"
result=$(measure_all)
echo "$result"
')

read -r agg_med agg_p95 agg_loss <<<"$result_all"
# median-of-medians: median(50.50, 39.10) = (39.10+50.50)/2 = 44.80
# median-of-p95s: median(120.30, 42.00) = (42.00+120.30)/2 = 81.15
# max loss: max(0.0, 20.0) = 20.0
assert_eq "measure_all agg_median" "44.80" "$agg_med"
assert_eq "measure_all agg_p95" "81.15" "$agg_p95"
assert_eq "measure_all agg_loss" "20.0" "$agg_loss"

# -------------------------------------------------------------------
# Test: evaluate_degrade threshold logic
# -------------------------------------------------------------------

# Case: enough bad samples → should degrade
degrade_yes=$(eval_daemon '
DEGRADE_MEDIAN=120
DEGRADE_P95=300
DEGRADE_LOSS=2
DEGRADE_WINDOW=60
DEGRADE_COUNT=3
now=$(date +%s)
WIN_TS=($now $now $now $now)
WIN_MEDIAN=(130 140 125 50)
WIN_P95=(100 100 100 100)
WIN_LOSS=(0 0 0 0)
if evaluate_degrade; then echo "YES"; else echo "NO"; fi
')
assert_eq "evaluate_degrade triggers on high median" "YES" "$degrade_yes"

# Case: not enough bad samples → should not degrade
degrade_no=$(eval_daemon '
DEGRADE_MEDIAN=120
DEGRADE_P95=300
DEGRADE_LOSS=2
DEGRADE_WINDOW=60
DEGRADE_COUNT=3
now=$(date +%s)
WIN_TS=($now $now $now $now)
WIN_MEDIAN=(50 60 130 55)
WIN_P95=(100 100 100 100)
WIN_LOSS=(0 0 0 0)
if evaluate_degrade; then echo "YES"; else echo "NO"; fi
')
assert_eq "evaluate_degrade no trigger (1 bad < 3)" "NO" "$degrade_no"

# Case: loss triggers degradation
degrade_loss=$(eval_daemon '
DEGRADE_MEDIAN=120
DEGRADE_P95=300
DEGRADE_LOSS=2
DEGRADE_WINDOW=60
DEGRADE_COUNT=3
now=$(date +%s)
WIN_TS=($now $now $now $now)
WIN_MEDIAN=(50 50 50 50)
WIN_P95=(100 100 100 100)
WIN_LOSS=(5 10 3 0)
if evaluate_degrade; then echo "YES"; else echo "NO"; fi
')
assert_eq "evaluate_degrade triggers on high loss" "YES" "$degrade_loss"

# -------------------------------------------------------------------
# Test: evaluate_recover threshold logic
# -------------------------------------------------------------------

# Case: all good → should recover
recover_yes=$(eval_daemon '
RECOVER_MEDIAN=70
RECOVER_P95=150
RECOVER_LOSS=1
RECOVER_WINDOW=600
now=$(date +%s)
WIN_TS=($now $now $now $now)
WIN_MEDIAN=(40 50 45 55)
WIN_P95=(80 90 85 100)
WIN_LOSS=(0 0 0 0.5)
if evaluate_recover; then echo "YES"; else echo "NO"; fi
')
assert_eq "evaluate_recover all good" "YES" "$recover_yes"

# Case: one bad sample → should not recover
recover_no=$(eval_daemon '
RECOVER_MEDIAN=70
RECOVER_P95=150
RECOVER_LOSS=1
RECOVER_WINDOW=600
now=$(date +%s)
WIN_TS=($now $now $now $now)
WIN_MEDIAN=(40 50 75 55)
WIN_P95=(80 90 85 100)
WIN_LOSS=(0 0 0 0)
if evaluate_recover; then echo "YES"; else echo "NO"; fi
')
assert_eq "evaluate_recover blocked by one bad median" "NO" "$recover_no"

# Case: too few samples
recover_few=$(eval_daemon '
RECOVER_MEDIAN=70
RECOVER_P95=150
RECOVER_LOSS=1
RECOVER_WINDOW=600
now=$(date +%s)
WIN_TS=($now $now)
WIN_MEDIAN=(40 50)
WIN_P95=(80 90)
WIN_LOSS=(0 0)
if evaluate_recover; then echo "YES"; else echo "NO"; fi
')
assert_eq "evaluate_recover needs >= 3 samples" "NO" "$recover_few"

# -------------------------------------------------------------------
# Test: detect_initial_state from mock mmcli
# -------------------------------------------------------------------

# Mock mmcli that reports 4g+5g allowed
write_stub mmcli '
if [[ "${*}" == *"-K"* ]]; then
  echo "modem.generic.allowed-modes=4g|5g"
  echo "modem.generic.state=connected"
fi
'

state_5g=$(eval_daemon '
MODEM_ID=0
detect_initial_state
echo "$STATE"
')
assert_eq "detect_initial_state 5g" "PREFER_5G" "$state_5g"

# Mock mmcli that reports 4g only
write_stub mmcli '
if [[ "${*}" == *"-K"* ]]; then
  echo "modem.generic.allowed-modes=4g"
  echo "modem.generic.state=connected"
fi
'

state_lte=$(eval_daemon '
MODEM_ID=0
detect_initial_state
echo "$STATE"
')
assert_eq "detect_initial_state lte" "FORCE_LTE" "$state_lte"

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
total=$(( PASS + FAIL ))
printf '\n%d/%d tests passed\n' "$PASS" "$total"
if (( FAIL > 0 )); then
  exit 1
fi
