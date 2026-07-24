# Equuleus clean release and installer

## Scope

This flow targets Xiaomi Mi 8 Pro (`equuleus`) only. It does not support
`dipper`. Release artifacts and per-device backups are stored outside Git:

```text
/home/dgx/xiaomi_8-artifacts/releases/
/home/dgx/xiaomi_8-artifacts/device-backups/<serial>/
```

A bundle remains a release candidate until it passes the automated checks and
manual key, battery, display, audio, Wi-Fi, Bluetooth and Chromium video tests
on a second clean equuleus.

## Clean rootfs

`build-clean-rootfs.sh` requires explicit inputs and does not copy the build
host's account password, SSH keys, Wi-Fi profiles, browser profile or proxy
credentials. The optional Chromium inputs install the offline equuleus V4L2
Flatpak and its hardware-decoding launcher.

The resulting filesystem contains:

- physical framebuffer Xorg and Xfce on display `:0`;
- a `2072x1080` safe X desktop centered between 96-pixel and 80-pixel
  physical black insets;
- NetworkManager, Blueman, PipeWire and WirePlumber;
- the validated audio services and Qualcomm firmware staging;
- power/volume input support and the PMI8998 battery module;
- Chromium with the Qualcomm Venus V4L2 decoding path;
- VNC software installed but not enabled without a password.

## Dedicated backup key

Create a dedicated OpenPGP encryption key on the workstation. Export the public
key for the phone and store the private-key export on offline removable media.
Do not put either private keys or decrypted partition images in Git or the
generic release directory.

The included generator intentionally requires an existing, empty offline-media
directory and must be invoked explicitly:

```sh
KEY_UID='Xiaomi 8 backup <backup@example.invalid>' \
OFFLINE_DIR=/media/ivan/USB_OFFLINE/equuleus-key \
./create-backup-key.sh
```

Use the printed fingerprint as both the encrypted-backup recipient and the
`SIGNING_KEY` value when building a signed release.

## Per-device backup

Copy `equuleus-backup-device` and the public key to the running phone, import
the public key, then run the helper with `sudo`. It backs up every partition
listed by `/dev/disk/by-partlabel` except `userdata`, compresses each image and
encrypts it to the dedicated recipient. `COMPLETE`, `partitions.tsv` and
`SHA256SUMS` form the installation receipt.

Backups are only for restoring the same serial-numbered device. Generic
installation never restores or flashes these images.

## Two-stage installation

With exactly one unlocked equuleus in fastboot mode:

```sh
./equuleus-installer inspect
./equuleus-installer prepare ~/.ssh/id_ed25519.pub \
  /home/dgx/xiaomi_8-artifacts/device-staging/<serial>
./equuleus-installer install \
  /home/dgx/xiaomi_8-artifacts/device-backups/<serial> \
  /home/dgx/xiaomi_8-artifacts/device-staging/<serial> \
  --confirm-erase <serial>
```

`prepare` extracts the clean rootfs template, adds only the supplied OpenSSH
public key for `ivan`, then creates a userdata sparse image bound to the
connected fastboot serial. The generic release package itself contains no
password or SSH key.

`install` verifies the release, backup receipt and prepared-device receipt,
flashes only that userdata sparse image, then uses `fastboot boot boot.img`.
It does not write the boot partition.

After Linux is reachable:

```sh
./equuleus-installer verify ivan@172.16.42.1 ./reports/<serial>
./equuleus-installer accept ./reports/<serial>/acceptance.txt \
  --confirm <serial>
```

Only after manual acceptance and a return to fastboot:

```sh
./equuleus-installer commit \
  ./reports/<serial>/acceptance.txt.accepted \
  --confirm-flash-boot <serial>
```

`commit` writes only `boot`, then reboots. It refuses a mismatched product,
locked bootloader, serial mismatch, incomplete backup or missing acceptance.

## Acceptance

Automated acceptance requires:

- Linux `5.12.0-sdm845` and `/dev/sda21[/ubuntu24]`;
- `KEY_POWER`, `KEY_VOLUMEUP` and `KEY_VOLUMEDOWN` input capabilities;
- battery capacity exported under `/sys/class/power_supply`;
- physical Xorg, local Xfce, NetworkManager and audio services active;
- the `equuleusfbdev` module and `2072x1080` safe display profile active;
- video device nodes and the equuleus Chromium launcher present.

Manual acceptance must additionally verify:

- volume-up/down change PipeWire volume;
- short power press locks the Xfce session and does not power off;
- charging state and battery percentage change plausibly;
- touchscreen, keyboard and mouse remain responsive during video playback;
- touches in the physical rounded-edge dead zones do not activate logical
  desktop edge controls;
- normal and fullscreen windows remain inside the visible safe rectangle;
- Wi-Fi, Bluetooth, speaker and microphone still work;
- YouTube H.264 playback uses the Qualcomm Venus hardware decoder.
