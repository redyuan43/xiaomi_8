# Xiaomi Mi 8 Pro Linux port

This repository preserves the validated Linux port for the Xiaomi Mi 8 Pro
(`equuleus`, Snapdragon 845).

## Repository layout

- `ubuntu24/`: Ubuntu 24.04 userspace, initramfs, service configuration,
  validation notes and reproducible boot-image tooling.
- `kernel/`: Linux 5.12 SDM845 kernel source with the validated equuleus
  touchscreen, WCN3990 Wi-Fi and WCN3990 Bluetooth changes.

The two directories retain their original Git histories through subtree
imports.

## Validated hardware

- UFS root filesystem and USB networking
- Touchscreen
- WCN3990 Wi-Fi
- WCN3990 Bluetooth controller and radio scanning
- Concurrent Wi-Fi, Bluetooth and Tailscale operation
- On-demand Xfce desktop through authenticated VNC
- WCD9340 microphone and TAS2557 internal speaker
- Chromium H.264 playback through the Qualcomm Venus V4L2 decoder

See `ubuntu24/docs/VALIDATION-20260720.md` for the base system validation,
`ubuntu24/docs/AUDIO.md` for audio, and `ubuntu24/docs/CHROMIUM-V4L2.md` for
the Chromium hardware-decoding implementation and evidence.

## Safety

Use `fastboot boot` for test images. Do not flash a partition without a
separately reviewed rollback plan. Credentials, proprietary firmware, rootfs
archives and generated boot images are intentionally excluded from this Git
repository.
