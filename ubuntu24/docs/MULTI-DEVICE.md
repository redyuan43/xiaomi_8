# Equuleus multi-device installation bundle

This bundle is only for Xiaomi Mi 8 Pro (`equuleus`) devices with an unlocked
bootloader. It is not a generic Xiaomi, SDM845 or Android installer.

It intentionally does not include device credentials, Wi-Fi profiles, SSH keys,
Tailscale state, or a copy of another phone's userdata. Each target device
creates its own `/dev/sda21/ubuntu24` rootfs.

## Build the bundle

Prepare the rootfs inputs, build a kernel boot image that includes the current
kernel configuration, then package the two together:

```sh
./scripts/prepare-artifacts.sh /path/to/inputs
INPUTS=/path/to/inputs \
BOOT_IMAGE=/path/to/equuleus-ubuntu24-boot.img \
./scripts/build-release-bundle.sh
```

Verify the generated archive before copying it to another machine:

```sh
sha256sum -c equuleus-ubuntu24.04.4-linux5.12-gui-uhid-install-bundle.tar.gz.sha256
```

## Install on each target device

1. Verify `fastboot getvar product` reports `equuleus` and the bootloader is
   unlocked. Do not continue on a different product.
2. Start the known postmarketOS environment used by this project, then copy the
   bundle's `inputs/` directory to the phone.
3. Run `bootstrap-rootfs.sh` as root on that target to create `/ubuntu24` on
   its own userdata filesystem.
4. Reboot to fastboot and run only:

   ```sh
   fastboot boot equuleus-ubuntu24-boot.img
   ```

The boot image is temporary: it does not flash `boot`, `dtbo`, userdata, or the
partition table. Rebooting returns the target to its prior Android or
postmarketOS boot path.

## First boot checks

- `uname -r` reports `5.12.0-sdm845`.
- `/` is `/dev/sda21[/ubuntu24]`.
- `wlan0`, `hci0`, `/dev/input/event0`, and the physical Xfce screen exist.
- Run `vncpasswd` as `ivan`; Remmina can then connect to port 5901 and shares
  the physical desktop.
- Pair a Bluetooth keyboard only after confirming that BlueZ creates an input
  event device for it.
