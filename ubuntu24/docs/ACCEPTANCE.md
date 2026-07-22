# Acceptance and rollback

## Before temporary boot

```sh
fastboot devices
fastboot getvar product
fastboot getvar unlocked
fastboot boot dist/boot.img
```

Expected product is `equuleus`. Permanent boot writes are allowed only through
the reviewed `equuleus-installer commit` gate after acceptance.

## Ubuntu baseline

- `systemctl is-system-running` reaches `running` or only documented `degraded` units.
- `uname -r` is `5.12.0-sdm845` and `/` is `/dev/sda21[/ubuntu24]`.
- SSH works over USB at `172.16.42.1`.
- NetworkManager can connect after the operator supplies a Wi-Fi profile.
- DNS, HTTPS and time synchronization work.
- `vncpasswd`, `gui-start`, Remmina to port `5901`, and `gui-stop` work.
- Chromium, Thunar, Mousepad, Xterm and Onboard start as user `ivan`.
- Power, volume-up and volume-down are visible as Linux input capabilities.
- Battery capacity and charging state are visible in `/sys/class/power_supply`.

## Bluetooth stage

Bluetooth is accepted only when `hci0` exists, scanning returns real devices,
and one physical device pairs, connects and reconnects after restarting BlueZ.
Module loading alone is not success.

## Rollback

Power-cycle or reboot to the bootloader and temporarily boot:

```sh
fastboot boot /home/ivan/github/redmi_8/equuleus-porting/releases/equuleus-linux-touch-20260717/postmarketos-v24.12/equuleus-pmos-v24.12-linux5.12-touch-boot.img
```

Before `commit`, the boot partition is not modified. Device-specific backups
provide the same-device rollback source after a permanent boot commit.
