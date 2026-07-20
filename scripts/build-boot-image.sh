#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
KNOWN_GOOD=${KNOWN_GOOD:-/home/ivan/github/redmi_8/equuleus-porting/releases/equuleus-linux-touch-20260717/postmarketos-v24.12/equuleus-pmos-v24.12-linux5.12-touch-boot.img}
UNPACK=${UNPACK:-/home/ivan/github/redmi_8/equuleus-porting/unpack_bootimg.py}
MKBOOT=${MKBOOT:-/home/ivan/github/redmi_8/equuleus-porting/mkbootimg.py}
BUILD="$ROOT/build"
DIST="$ROOT/dist"
RAMDISK_DIR="$BUILD/ramdisk"
OUT=${OUT:-$DIST/equuleus-ubuntu24.04.4-linux5.12-cli-boot.img}
KERNEL=${KERNEL:-$BUILD/unpacked/kernel}

rm -rf "$BUILD"
mkdir -p "$RAMDISK_DIR" "$DIST"
python3 "$UNPACK" --boot_img "$KNOWN_GOOD" --out "$BUILD/unpacked" --format info > "$BUILD/boot-info.txt"
gzip -dc "$BUILD/unpacked/ramdisk" | (cd "$RAMDISK_DIR" && cpio -idmu --quiet)
install -m 0755 "$ROOT/initramfs/init_2nd.sh" "$RAMDISK_DIR/init_2nd.sh"
(cd "$RAMDISK_DIR" && find . -print0 | cpio --null -o -H newc --quiet | gzip -9) > "$BUILD/ubuntu-initramfs.cpio.gz"
python3 "$MKBOOT" \
    --kernel "$KERNEL" \
    --ramdisk "$BUILD/ubuntu-initramfs.cpio.gz" \
    --cmdline 'console=tty0 console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xA84000 loglevel=7 PMOS_NOSPLASH' \
    --base 0 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 \
    --pagesize 4096 \
    --header_version 1 \
    -o "$OUT"
file "$OUT"
sha256sum "$OUT" | tee "$DIST/SHA256SUMS"
printf 'Built %s\n' "$OUT"
