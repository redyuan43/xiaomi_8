# Xiaomi Mi 8 Pro Linux test image

This directory preserves the reproducible, non-destructive Linux bring-up
workflow for Xiaomi Mi 8 Pro (`equuleus`, Snapdragon 845).

## Proven state

- Linux 5.12 boots with `fastboot boot` through a USB 2.0 connection.
- UFS, USB RNDIS and the bootloader-provided simple framebuffer work.
- ST FTS V521 probes at I2C address `0x49` and registers `/dev/input/event0`.
- The verified chip ID is `36 39`, firmware is `0062`, and config is `0031`.
- Physical touch increased the FTS IRQ counter from 1 to 707.
- No phone partition was written during validation.

## Build

Inputs:

1. An Alpine aarch64 initramfs containing the `init` file in this directory.
2. The Android `mkbootimg.py` tool.
3. Docker.

Run from this kernel repository:

```sh
tools/equuleus/build-test-boot.sh \
  "$PWD/../build-5.12-repro" \
  "$PWD/../build-5.12/equuleus-test-initramfs.cpio.gz" \
  "$PWD/../mkbootimg.py"
```

The output is `equuleus-linux-test-boot.img`. Always compare its SHA256 with
the release manifest before booting it.

## Temporary boot

Use the exact ADB serial of the Mi 8 Pro. The script verifies both the Android
codename and fastboot product before booting:

```sh
tools/equuleus/boot-temporary.sh 9825e5a1 \
  ../build-5.12/equuleus-linux-test-boot.img
```

The script only invokes `fastboot boot`; it never flashes a partition.

## USB diagnostic shell

After Linux enumerates as USB ID `0525:a4a2`, locate the new `enx*` interface
and configure the host:

```sh
iface=$(ip -o link show | awk -F': ' '/enx/ {print $2; exit}')
sudo ip addr replace 192.168.7.1/24 dev "$iface"
nc -s 192.168.7.1 192.168.7.2 2323
```

Useful checks:

```sh
uname -a
cat /proc/bus/input/devices
grep -i fts /proc/interrupts
od -An -tx1 -w24 /dev/input/event0
```

## Return to Android

The test initramfs has no init daemon, so use a forced kernel reboot:

```sh
printf 'sync; reboot -f\n' | \
  nc -s 192.168.7.1 -w 4 192.168.7.2 2323
```

If USB networking is unavailable, hold Power for approximately 15 seconds.

## Safety boundaries

- Do not run `fastboot flash`, `fastboot erase`, EDL tools or partitioning
  commands as part of this workflow.
- Do not update the touchscreen controller firmware from the experimental
  kernel. The driver deliberately preserves the known-good Android firmware.
- A persistent postmarketOS installation requires a separately reviewed
  partition and rollback plan.

