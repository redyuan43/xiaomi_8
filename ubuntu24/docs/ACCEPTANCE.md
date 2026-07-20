# Acceptance and rollback

## Before temporary boot

```sh
fastboot devices
fastboot getvar product
fastboot getvar unlocked
fastboot boot dist/equuleus-ubuntu24.04.4-linux5.12-cli-boot.img
```

Expected product is `equuleus`. Do not use `fastboot flash`.

## Ubuntu baseline

- `systemctl is-system-running` reaches `running` or only documented `degraded` units.
- `uname -r` is `5.12.0-sdm845` and `/` is `/dev/sda21[/ubuntu24]`.
- SSH works over USB at `172.16.42.1`.
- NetworkManager connects to the preserved `330_5G` profile.
- DNS, HTTPS and time synchronization work.
- `vncpasswd`, `gui-start`, Remmina to port `5901`, and `gui-stop` work.
- Epiphany, Thunar, Mousepad, Xterm and Onboard start as user `ivan`.
- `nm-applet`, `nm-connection-editor`, `blueman-applet`, and `blueman-manager`
  start in the Xfce session.
- `evtest` and `libinput list-devices` identify the FTS touchscreen as
  `/dev/input/event0`.

If `wlan0` is absent, recover the MSS and Wi-Fi services without stopping an
already running remoteproc:

```sh
sudo systemctl reset-failed equuleus-mss.service equuleus-wifi.service
sudo systemctl start equuleus-mss.service
sudo systemctl start equuleus-wifi.service
```

Then verify all three layers rather than trusting only the service exit code:

```sh
cat /sys/class/remoteproc/remoteproc0/state
ip link show wlan0
nmcli device status
```

## Bluetooth stage

Bluetooth is accepted only when `hci0` exists, scanning returns real devices,
and one physical device pairs, connects and reconnects after restarting BlueZ.
Module loading alone is not success.

## Rollback

Power-cycle or reboot to the bootloader and temporarily boot:

```sh
fastboot boot /home/ivan/github/redmi_8/equuleus-porting/releases/equuleus-linux-touch-20260717/postmarketos-v24.12/equuleus-pmos-v24.12-linux5.12-touch-boot.img
```

The Android boot partition and partition table are never modified.
