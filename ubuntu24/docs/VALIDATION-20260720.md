# Live validation on 2026-07-20

Device: Xiaomi Mi 8 Pro (`equuleus`, serial `9825e5a1`). The image was started
with `fastboot boot`; no Android partition was flashed.

## Passed

- Ubuntu 24.04.4 LTS ARM64 booted with Linux `5.12.0-sdm845`.
- `/` was mounted from `/dev/sda21[/ubuntu24]`.
- systemd reached `running` with no failed units after the MSS startup fix.
- USB SSH worked at `172.16.42.1`.
- WCN3990 Wi-Fi connected to the preserved NetworkManager profile.
- NetworkManager's Xfce tray applet and connection editor were installed and
  started in the VNC session. Blueman's tray applet and manager also started
  successfully without replacing the Xfce session or unmasking the display
  manager.
- A later live recovery reproduced the MSS registration race: `wlan0` was
  absent while `equuleus-mss.service` was failed and remoteproc0 was offline.
  Resetting and starting `equuleus-mss.service`, followed by
  `equuleus-wifi.service`, brought remoteproc0 online, loaded `ath10k_snoc`,
  created `wlan0`, and automatically reconnected the saved `330_5G` profile.
  The recovered interface received `192.168.31.124/24`; DNS and HTTPS were
  verified without rebooting the phone.
- WCN3990 Bluetooth initialized through UART6 after enabling the QUP0 wrapper
  and the GPIO45-48 CTS/RTS/TX/RX pin configuration.
- BlueZ downloaded `qca/crbtfw21.tlv` and `qca/crnv21.bin`; `hci0` reached
  `UP RUNNING` with no frame-reassembly or baud-rate errors.
- A 15-second BlueZ scan discovered nearby classic and BLE devices. Wi-Fi,
  Bluetooth and Tailscale remained active at the same time.
- DNS and HTTPS worked after selecting NetworkManager's direct DNS backend.
- NTP synchronized and the timezone was set to `Asia/Shanghai`.
- Direct VNC on port 5901 completed `VncAuth` and displayed Xfce.
- Xorg `fbdev` rendered the physical simple framebuffer as a 2248x1080
  clockwise-rotated Xfce desktop. The FTS touchscreen was bound through
  libinput with the corresponding transformation matrix, and the user accepted
  the on-device landscape layout.
- Thunar, Mousepad, Xterm, Onboard and Epiphany started in the VNC session.
- GNOME Keyring and AT-SPI started inside the virtual desktop session.
- Tailscale 1.98.9 ARM64 installed and `tailscaled` remained running after the
  iptables alternatives were changed from nft to legacy.
- Tailnet authentication completed as `equuleus-ubuntu`. SSH and authenticated
  VNC were both tested from `ivan-ms-7b17` to the Tailscale IP.
- ADSP firmware started automatically and WCD9340 registered the
  `Xiaomi Mi 8 Pro` ALSA card with three QDSP6 playback/capture frontends.
- The stock main-microphone route recorded five seconds of 48 kHz, 16-bit mono
  PCM. The captured signal measured `-43.1 dB` mean and `-12.9 dB` peak, proving
  that the file was not silent.
- TAS2557 was detected at GPIO-I2C address `16-004c` as PG2.1 silicon. Its
  28,364-byte firmware passed program, PLL, configuration and checksum loading.
- The device-specific 442-byte TAS2557 calibration file parsed as one
  calibration and produced `Get Cali_Re=1258411800`.
- A conservative 48 kHz stereo playback started TAS2557, reported
  `PowerUpFlag=0xfc`, and powered the amplifier off when the stream closed.
- A 15-second continuous 1 kHz tone at approximately `-40 dB` was heard from
  the internal loudspeaker, completing acoustic validation.
- User `ivan` was added to the `audio` group and can access `/dev/snd` without
  sudo after a new login.
- The FTS touchscreen remained visible to both `evtest` and `libinput` as
  `/dev/input/event0` after the desktop management tools were installed.

## Kernel compatibility notes

- The downstream kernel does not provide nftables, so Tailscale must use the
  legacy iptables alternatives.
- Policy routing is unavailable (`IP_MULTIPLE_TABLES` is disabled). Tailscale
  logs a warning, but direct incoming Tailnet SSH and VNC work. Subnet-router
  and exit-node operation are not supported by this kernel configuration.
- WebKit's bubblewrap sandbox cannot create an unprivileged user namespace.
  Epiphany therefore uses the documented compatibility environment variable.
- The VNC desktop uses software rendering. DRI acceleration is not expected.
- The physical desktop uses the bootloader-provided simple framebuffer rather
  than DRM/KMS. It is suitable for Xorg `fbdev` but not yet a native Wayland
  target for Phosh or Plasma Mobile.
- MSS registration can finish after the Wi-Fi startup service begins. The
  remoteproc wait helper therefore retries the `offline` to `start` transition
  on every polling iteration instead of checking it only once.
- If this boot-time race still leaves MSS failed, it can be recovered without
  rebooting or touching the remoteproc sysfs stop path:

  ```sh
  sudo systemctl reset-failed equuleus-mss.service equuleus-wifi.service
  sudo systemctl start equuleus-mss.service
  sudo systemctl start equuleus-wifi.service
  ```

  Success requires remoteproc0 to report `running`, `wlan0` to exist, and
  NetworkManager to report an active Wi-Fi connection; a successful service
  exit alone is not sufficient evidence.

## Pending

- Pair, connect and reconnect a user-selected Bluetooth peripheral. Controller
  initialization and real radio scanning have passed; no peripheral was paired
  automatically because pairing changes external device state.
- Simultaneous microphone loopback remains unsupported. The QDSP6 MultiMedia1
  frontend rejected full-duplex parameter setup, so microphone and speaker
  acceptance tests are intentionally sequential.
- A K808 Bluetooth keyboard has paired but has not yet produced verified input
  events. The next temporary boot image builds `CONFIG_UHID=y`; acceptance
  requires BlueZ to create an input event device and keystrokes to reach the
  physical Xfce session.
