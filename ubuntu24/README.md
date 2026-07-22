# Ubuntu 24.04 for Xiaomi Mi 8 Pro (equuleus)

This repository contains the reproducible userspace, initramfs and service
configuration for booting Ubuntu 24.04.4 ARM64 on the Xiaomi Mi 8 Pro. It uses
the already verified downstream Linux `5.12.0-sdm845` kernel and never flashes
the Android boot partition.

## Layout

- Android/userdata remains `/dev/sda21` and keeps the working postmarketOS root.
- Ubuntu is installed in the isolated `/ubuntu24` directory on that filesystem.
- The custom initramfs bind-mounts `/ubuntu24` as `/sysroot` and switches to it.
- The physical display defaults to a text console (`multi-user.target`).
- `gui-start`, `gui-stop` and `gui-status` manage an on-demand Xfce Xvnc session.

## Safety rules

- Verify `fastboot getvar product` reports `equuleus` and the bootloader is
  unlocked before booting an image.
- Use `fastboot boot`, never `fastboot flash boot`.
- Do not stop a running MSS remoteproc through sysfs. The Ubuntu rmtfs override
  intentionally removes `-s` so service shutdown cannot stop MSS.
- Keep Wi-Fi, VNC, Tailscale and login credentials out of Git and release
  archives.
- Epiphany currently runs with the WebKit sandbox disabled because this
  downstream 5.12 runtime rejects unprivileged user namespaces. Treat browsing
  as experimental and remove the compatibility environment variable after a
  kernel upgrade restores the sandbox.

## Build flow

1. Run `scripts/prepare-artifacts.sh` on the workstation.
2. Copy the generated inputs and `scripts/bootstrap-rootfs.sh` to the running
   postmarketOS system.
3. Run the bootstrap script as root to create `/ubuntu24` natively on ARM64.
4. Run `scripts/build-boot-image.sh` to produce the temporary Android boot
   image.
5. Verify identity and boot it with `fastboot boot`.

To package a separately built test kernel while preserving the verified
userspace and initramfs, set `KERNEL` and use a distinct output name:

```sh
KERNEL=/path/to/Image.gz-dtb \
OUT="$PWD/dist/equuleus-test-boot.img" \
scripts/build-boot-image.sh
```

See `docs/ACCEPTANCE.md` for the exact validation and rollback procedure.
See `docs/AUDIO.md` for WCD9340 microphone and TAS2557 speaker setup.
See `docs/CHROMIUM-V4L2.md` for the validated Qualcomm Venus hardware-decoding
path in Chromium.

## Tailscale

Install from Tailscale's official Ubuntu 24.04 stable repository, then authenticate:

```sh
sudo scripts/install-tailscale.sh
sudo tailscale up --hostname=equuleus-ubuntu
```
