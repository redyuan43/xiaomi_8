# Live validation on 2026-07-20

Device: Xiaomi Mi 8 Pro (`equuleus`, serial `9825e5a1`). The image was started
with `fastboot boot`; no Android partition was flashed.

## Passed

- Ubuntu 24.04.4 LTS ARM64 booted with Linux `5.12.0-sdm845`.
- `/` was mounted from `/dev/sda21[/ubuntu24]`.
- systemd reached `running` with no failed units after the MSS startup fix.
- USB SSH worked at `172.16.42.1`.
- WCN3990 Wi-Fi connected to the preserved NetworkManager profile.
- WCN3990 Bluetooth initialized through UART6 after enabling the QUP0 wrapper
  and the GPIO45-48 CTS/RTS/TX/RX pin configuration.
- BlueZ downloaded `qca/crbtfw21.tlv` and `qca/crnv21.bin`; `hci0` reached
  `UP RUNNING` with no frame-reassembly or baud-rate errors.
- A 15-second BlueZ scan discovered nearby classic and BLE devices. Wi-Fi,
  Bluetooth and Tailscale remained active at the same time.
- DNS and HTTPS worked after selecting NetworkManager's direct DNS backend.
- NTP synchronized and the timezone was set to `Asia/Shanghai`.
- Direct VNC on port 5901 completed `VncAuth` and displayed Xfce.
- Thunar, Mousepad, Xterm, Onboard and Epiphany started in the VNC session.
- GNOME Keyring and AT-SPI started inside the virtual desktop session.
- Tailscale 1.98.9 ARM64 installed and `tailscaled` remained running after the
  iptables alternatives were changed from nft to legacy.
- Tailnet authentication completed as `equuleus-ubuntu`. SSH and authenticated
  VNC were both tested from `ivan-ms-7b17` to the Tailscale IP.

## Kernel compatibility notes

- The downstream kernel does not provide nftables, so Tailscale must use the
  legacy iptables alternatives.
- Policy routing is unavailable (`IP_MULTIPLE_TABLES` is disabled). Tailscale
  logs a warning, but direct incoming Tailnet SSH and VNC work. Subnet-router
  and exit-node operation are not supported by this kernel configuration.
- WebKit's bubblewrap sandbox cannot create an unprivileged user namespace.
  Epiphany therefore uses the documented compatibility environment variable.
- The VNC desktop uses software rendering. DRI acceleration is not expected.
- MSS registration can finish after the Wi-Fi startup service begins. The
  remoteproc wait helper therefore retries the `offline` to `start` transition
  on every polling iteration instead of checking it only once.

## Pending

- Pair, connect and reconnect a user-selected Bluetooth peripheral. Controller
  initialization and real radio scanning have passed; no peripheral was paired
  automatically because pairing changes external device state.
