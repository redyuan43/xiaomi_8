# Ubuntu 24.04 for Xiaomi Mi 8 Pro (equuleus)

This repository contains the reproducible userspace, initramfs and service
configuration for booting Ubuntu 24.04.4 ARM64 on the Xiaomi Mi 8 Pro. It uses
the downstream Linux `5.12.0-sdm845` kernel and supports a guarded, two-stage
Linux-only installation after temporary-boot acceptance.

## Layout

- Userdata is `/dev/sda21`; a release image dedicates it to the Linux layout.
- Ubuntu is installed in the isolated `/ubuntu24` directory on that filesystem.
- The custom initramfs bind-mounts `/ubuntu24` as `/sysroot` and switches to it.
- Xorg starts on the physical framebuffer and the `ivan` user starts Xfce on
  display `:0`.
- VNC scraping is installed but remains disabled until a VNC password is set.
- Power and volume keys are described by the equuleus device tree; the PMI8998
  fuel gauge is exposed through Linux power-supply sysfs.

## Safety rules

- Verify `fastboot getvar product` reports `equuleus` and the bootloader is
  unlocked before booting an image.
- Always use `fastboot boot` for acceptance before committing `boot`.
- `equuleus-installer commit` is the only supported permanent boot write path.
- Never flash bootloader, modem, persist, calibration or other device-specific
  partitions from a generic release.
- Do not stop a running MSS remoteproc through sysfs. The Ubuntu rmtfs override
  intentionally removes `-s` so service shutdown cannot stop MSS.
- Keep Wi-Fi, VNC, Tailscale and login credentials out of Git and release
  archives.
- Epiphany currently runs with the WebKit sandbox disabled because this
  downstream 5.12 runtime rejects unprivileged user namespaces. Treat browsing
  as experimental and remove the compatibility environment variable after a
  kernel upgrade restores the sandbox.

## Build flow

1. Run `scripts/prepare-artifacts.sh` on the ARM64 workstation.
2. Build the kernel and install its modules into an artifact staging tree.
3. Run `scripts/build-clean-rootfs.sh` with explicit module, firmware and
   Chromium inputs.
4. Run `release/build-release.sh` to create the clean rootfs template,
   `boot.img`, checksums and the guarded installer.
5. Back up every non-userdata partition with
   `release/equuleus-backup-device`.
6. Run `equuleus-installer prepare` with an operator public key, then
   `equuleus-installer install`, validate the temporary boot, and use the
   separate `accept` and `commit` commands.

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
See `docs/INSTALLER.md` for the complete backup, install and release gate.

## Tailscale

Install from Tailscale's official Ubuntu 24.04 stable repository, then authenticate:

```sh
sudo scripts/install-tailscale.sh
sudo tailscale up --hostname=equuleus-ubuntu
```
