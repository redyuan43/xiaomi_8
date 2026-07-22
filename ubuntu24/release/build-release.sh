#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOTFS=${ROOTFS:?set ROOTFS to the clean rootfs tar.zst}
BOOT_IMAGE=${BOOT_IMAGE:?set BOOT_IMAGE to the tested candidate boot image}
OUT=${OUT:-/home/dgx/xiaomi_8-artifacts/releases/equuleus-ubuntu24-rc}
USERDATA_BYTES=${USERDATA_BYTES:-121425080320}
RELEASE_ID=${RELEASE_ID:-equuleus-ubuntu24-$(date +%Y%m%d)-rc}
SIGNING_KEY=${SIGNING_KEY:-}

for command in zstd sha256sum; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Missing command: $command" >&2
        exit 1
    }
done
[ -f "$ROOTFS" ] || { echo "Missing rootfs: $ROOTFS" >&2; exit 1; }
[ -f "$BOOT_IMAGE" ] || { echo "Missing boot image: $BOOT_IMAGE" >&2; exit 1; }
[ ! -e "$OUT" ] || {
    echo "Refusing to overwrite existing output: $OUT" >&2
    exit 1
}
mkdir -p "$OUT"

install -m 0644 "$BOOT_IMAGE" "$OUT/boot.img"
install -m 0644 "$ROOTFS" "$OUT/rootfs.tar.zst"
install -m 0755 "$ROOT/release/equuleus-installer" "$OUT/equuleus-installer"
install -m 0755 "$ROOT/release/equuleus-backup-device" "$OUT/equuleus-backup-device"
install -m 0755 "$ROOT/release/raw-to-android-sparse.py" \
    "$OUT/raw-to-android-sparse.py"
install -m 0755 "$ROOT/release/create-backup-key.sh" \
    "$OUT/create-backup-key.sh"
cat > "$OUT/release.env" <<EOF
RELEASE_ID=$RELEASE_ID
PRODUCT=equuleus
USERDATA_BYTES=$USERDATA_BYTES
STATUS=release-candidate
SECOND_DEVICE_VALIDATED=0
EOF

if [ -n "$SIGNING_KEY" ]; then
    gpg --batch --yes --export "$SIGNING_KEY" > "$OUT/release-signing-key.gpg"
fi
(cd "$OUT" && sha256sum \
    boot.img rootfs.tar.zst equuleus-installer \
    equuleus-backup-device raw-to-android-sparse.py create-backup-key.sh \
    release.env \
    ${SIGNING_KEY:+release-signing-key.gpg} > SHA256SUMS)

if [ -n "$SIGNING_KEY" ]; then
    gpg --batch --yes --local-user "$SIGNING_KEY" \
        --armor --detach-sign --output "$OUT/SHA256SUMS.asc" "$OUT/SHA256SUMS"
fi
printf 'Built release candidate: %s\n' "$OUT"
