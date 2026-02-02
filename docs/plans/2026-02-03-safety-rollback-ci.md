# Safety / Rollback / CI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a preflight check mode, a rollback helper, and CI checks (shellcheck + basic tests) for this Omarchy customization bundle.

**Architecture:** Keep `apply.sh` as the single entry point for applying files from `home/` into `$HOME`. Add a new `rollback.sh` that restores the latest `*.bak.YYYYmmdd-HHMMSS` backups created by `apply.sh` for the files this repo manages. Add GitHub Actions CI to run shell linting and a small bash test suite in a hermetic temp `$HOME` with stubbed external commands.

**Tech Stack:** bash, python (3.x), GitHub Actions, shellcheck, bats-core

---

### Task 1: Add a minimal test harness (bats)

**Files:**
- Create: `tests/bats/apply_check.bats`
- Create: `tests/bats/rollback.bats`
- Create: `tests/bats/test_helper.bash`

**Step 1: Add a failing test for `apply.sh --check`**

```bash
@test "apply.sh --check exits 0" {
  run bash ./apply.sh --check
  [ "$status" -eq 0 ]
}
```

**Step 2: Run bats to verify RED**

Run: `bats tests/bats/apply_check.bats`
Expected: FAIL because `--check` is not implemented yet.

**Step 3: Add a failing test for rollback restoring a backup**

Create a temp `$HOME`, create an existing target file, run `apply.sh` to generate a backup, then run `rollback.sh` and assert the original content is restored.

**Step 4: Run bats to verify RED**

Run: `bats tests/bats/rollback.bats`
Expected: FAIL because `rollback.sh` does not exist yet.

**Step 5: Commit tests (still failing)**

Run:

```bash
git add tests/bats
git commit -m "test: add failing bats coverage for check/rollback"
```

---

### Task 2: Implement `apply.sh --check` (preflight)

**Files:**
- Modify: `apply.sh`
- Test: `tests/bats/apply_check.bats`

**Step 1: Implement minimal `--check` CLI parsing**

- Add a `CHECK_ONLY=0` flag.
- Parse `--check`.

**Step 2: Implement `preflight()` output**

Print (stderr or stdout, but consistent):

- Detected repo root and `home/` path
- Presence of key commands used by this repo (`install`, `python`, `jq`, `hyprctl`, `systemctl`, `notify-send`)
- Optional detections (best-effort): NVIDIA present? DP-4 present? (only when tools exist)

Exit code:

- `0` when the repo layout looks correct
- `>0` only when required repo files are missing (avoid breaking users on systems missing optional tools)

**Step 3: Ensure `--check` does not change anything**

- Do not create backups
- Do not install files
- Do not call `hyprctl reload` or `systemctl`

**Step 4: Run bats to verify GREEN**

Run: `bats tests/bats/apply_check.bats`
Expected: PASS.

**Step 5: Commit**

```bash
git add apply.sh tests/bats/apply_check.bats
git commit -m "feat: add apply.sh preflight check"
```

---

### Task 3: Add `rollback.sh` (restore latest backups)

**Files:**
- Create: `rollback.sh`
- Test: `tests/bats/rollback.bats`

**Behavior:**

- Restores the latest `*.bak.YYYYmmdd-HHMMSS` backup for each managed destination path.
- Supports `--dry-run` (prints what would be restored).
- Does not delete files that have no backup.
- Before restoring, back up the current destination to a new `*.bak.rollback.YYYYmmdd-HHMMSS` (or similar) to keep rollback reversible.

**Step 1: Write the minimal script skeleton + usage**

**Step 2: Implement `latest_backup_for(dest)` selection**

- Look for `${dest}.bak.*`
- Pick the latest by timestamp lexicographic order.

**Step 3: Implement restore loop for the known destination file list**

Use the same destination paths as `apply.sh` installs:

- `~/.config/hypr/bindings.conf`
- `~/.config/hypr/hypridle.conf`
- `~/.config/hypr/input.conf`
- `~/.config/hypr/monitors.conf`
- `~/.config/hypr/envs.conf`
- `~/.local/bin/hypr-*`
- `~/.config/systemd/user/lid-nosuspend.service`
- `~/.config/waybar/*` and `~/.local/bin/waybar-*`

**Step 4: Run bats to verify GREEN**

Run: `bats tests/bats/rollback.bats`
Expected: PASS.

**Step 5: Commit**

```bash
git add rollback.sh tests/bats/rollback.bats
git commit -m "feat: add rollback helper script"
```

---

### Task 4: Add CI (shellcheck + bats)

**Files:**
- Create: `.github/workflows/ci.yml`

**Step 1: Add workflow that runs on push + PR**

- Install dependencies (`shellcheck`, `bats`, `jq`)
- Run `bash -n` on bash scripts
- Run `shellcheck` on `apply.sh`, `rollback.sh`, and `home/.local/bin/*`
- Run bats tests

**Step 2: Fix shellcheck warnings until CI is clean**

- Prefer code changes over disables.
- If a disable is necessary, add a short comment explaining why.

**Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add shellcheck and bats"
```

---

### Task 5: Docs touch-ups

**Files:**
- Modify: `README.md`
- Modify: `README.ja.md`

**Step 1: Document new commands**

- `bash ./apply.sh --check`
- `bash ./rollback.sh` and `--dry-run`

**Step 2: Commit**

```bash
git add README.md README.ja.md
git commit -m "docs: document check and rollback"
```

---

### Task 6: Verification

Run locally:

- `bash -n apply.sh rollback.sh`
- `bats tests/bats`

Confirm CI workflow file is present and targets the correct script paths.
