#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${VERSION:-equuleus-ubuntu24.04.4-linux5.12-gui-uhid}
INPUTS=${INPUTS:?set INPUTS to the directory created by prepare-artifacts.sh}
BOOT_IMAGE=${BOOT_IMAGE:?set BOOT_IMAGE to the validated temporary boot image}
OUT=${OUT:-$ROOT/releases/$VERSION}
ARCHIVE=${ARCHIVE:-$ROOT/releases/$VERSION-install-bundle.tar.gz}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ -f "$BOOT_IMAGE" ] || fail "missing boot image: $BOOT_IMAGE"
[ -d "$INPUTS" ] || fail "missing prepared inputs: $INPUTS"
for file in \
    ubuntu-base-24.04.4-base-arm64.tar.gz \
    pd-mapper-1.1.tar.gz \
    equuleus-ubuntu24-overlay.tar.gz \
    packages.txt \
    bootstrap-rootfs.sh \
    SHA256SUMS; do
    [ -f "$INPUTS/$file" ] || fail "missing prepared input: $file"
done

rm -rf "$OUT"
mkdir -p "$OUT/inputs"
install -m 0644 "$BOOT_IMAGE" "$OUT/equuleus-ubuntu24-boot.img"
for file in \
    ubuntu-base-24.04.4-base-arm64.tar.gz \
    pd-mapper-1.1.tar.gz \
    equuleus-ubuntu24-overlay.tar.gz \
    packages.txt \
    bootstrap-rootfs.sh \
    SHA256SUMS; do
    install -m 0644 "$INPUTS/$file" "$OUT/inputs/$file"
done
install -m 0644 "$ROOT/docs/MULTI-DEVICE.md" "$OUT/INSTALL.md"

(cd "$OUT/inputs" && sha256sum -c SHA256SUMS)
(cd "$OUT" && sha256sum equuleus-ubuntu24-boot.img INSTALL.md > SHA256SUMS)
tar -C "$(dirname -- "$OUT")" -czf "$ARCHIVE" "$(basename -- "$OUT")"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
printf 'Built %s\n' "$ARCHIVE"
