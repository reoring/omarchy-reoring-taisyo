#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash tests/test_apply_check.sh
bash tests/test_rollback.sh

printf '%s\n' "ok"
