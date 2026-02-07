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

## WWAN Data (Docomo SIM)

This directory includes a setup script that configures WWAN using ModemManager +
NetworkManager, while leaving Wi-Fi/Ethernet to systemd-networkd/iwd.

Troubleshooting notes (what we actually hit on RM520N-GL) are in:

- hardware/lenovo/thinkpad/x1-13/WWAN.md

Install:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wwan-docomo.sh install
```

Change APN (example):

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wwan-docomo.sh install --apn mopera.net --con-name docomo-mopera
```

Bring it up/down:

```sh
nmcli connection up docomo
nmcli connection down docomo
```

Auto-reconnect after resume:

- Enabled by default by `setup-wwan-docomo.sh install`.
- To disable (manual connect only):

```sh
sudo nmcli connection modify docomo connection.autoconnect no
```

If ModemManager logs say "software radio switch is OFF", run:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wwan-docomo.sh enable
```

If it still won't connect, force direct MBIM radio enable:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wwan-docomo.sh enable --wait 60 --direct-mbim
```

If the modem is not detected after install, reboot once (firmware load).

## Wi-Fi Tethering (AP) from WWAN

This setup uses iwd + systemd-networkd for Wi-Fi. NetworkManager is configured to
ignore `wl*` (WWAN-only), so use the iwd AP feature and let systemd-networkd serve
DHCP + NAT.

If ufw is enabled (default input/forward DROP), you must also allow DHCP + routing.
The script does this automatically on start/stop.

Install the AP network config:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wifi-ap-from-wwan.sh install
```

Start/stop:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wifi-ap-from-wwan.sh start --ssid TPX1-WWAN --pass 'change-this-pass'
bash hardware/lenovo/thinkpad/x1-13/setup-wifi-ap-from-wwan.sh stop
```

If you want to manage firewall rules yourself:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wifi-ap-from-wwan.sh start --no-ufw ...
```

Status:

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-wifi-ap-from-wwan.sh status
```

## Uninstall

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-suspend-mhi-wwan-hook.sh uninstall
```

## 3D (OpenGL/Vulkan) packages

Install Intel Mesa + Vulkan packages (and lib32 variants if multilib is enabled):

```sh
bash hardware/lenovo/thinkpad/x1-13/setup-3d-packages.sh install
```

Verify:

```sh
glxinfo -B
vulkaninfo --summary
```
