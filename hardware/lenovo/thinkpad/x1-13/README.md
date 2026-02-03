# ThinkPad X1 (13") - Suspend Fix (Quectel WWAN / MHI)

## Problem

On some ThinkPad X1 13" systems with an internal Quectel WWAN modem, `systemctl suspend`
fails immediately. Typical symptoms:

- Closing the lid does not enter sleep
- `systemctl suspend` returns without suspending
- Journal shows the kernel aborting suspend with errors like:
  - `mhi-pci-generic 0000:08:00.0: failed to suspend device: -16`
  - `PM: Some devices failed to suspend, or early wake event detected`
  - `Failed to put system to sleep. System resumed again: Device or resource busy`

This points to the WWAN device using the MHI PCI driver (`mhi-pci-generic`) blocking
suspend.

## Important Note (systemd 259)

On this setup (Arch + systemd 259), hooks placed in `/etc/systemd/system-sleep/` are
**not** executed by `systemctl suspend`. `systemd-sleep(8)` runs executables from:

- `/usr/lib/systemd/system-sleep/`

Therefore, installing a workaround hook in `/etc/systemd/system-sleep/` will not fix
`systemctl suspend` on its own.

The reliable approach is to run the workaround via a systemd unit tied to
`sleep.target`.

## Solution

Install the provided setup script:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-suspend-mhi-wwan-hook.sh install
```

This installs:

- `/usr/local/libexec/mhi-wwan-sleep`
- `/etc/systemd/system/mhi-wwan-sleep.service` (enabled; `WantedBy=sleep.target`)

How it works:

- On sleep entry (before `sleep.target`):
  - `rfkill block wwan`
  - bring down `wwan*` interface
  - unbind the WWAN PCI device from its driver
  - unload MHI modules (best-effort)
- On resume:
  - reload MHI modules
  - bind the PCI device back to `mhi-pci-generic`
  - `rfkill unblock wwan`

Then test:

```sh
systemctl suspend
```

## Logs / Debug

The helper logs to the journal with tag `mhi-sleep-hook`:

```sh
journalctl -b -t mhi-sleep-hook --no-pager
```

## WWAN Behavior

WWAN will generally become usable again after resume, but the cellular data session
may need to reconnect (depending on how WWAN is managed on the system).

## Uninstall

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-suspend-mhi-wwan-hook.sh uninstall
```
