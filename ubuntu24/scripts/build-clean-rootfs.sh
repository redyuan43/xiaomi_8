#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INPUT_DIR=${INPUT_DIR:-"$ROOT/inputs"}
OUTPUT=${OUTPUT:-"$ROOT/dist/equuleus-ubuntu24-rootfs.tar.zst"}
WORK_DIR=${WORK_DIR:-"$ROOT/build/clean-rootfs"}
MODULES_SOURCE=${MODULES_SOURCE:?set MODULES_SOURCE to a 5.12.0-sdm845 module tree}
FIRMWARE_SOURCE=${FIRMWARE_SOURCE:?set FIRMWARE_SOURCE to the staged firmware tree}
CHROMIUM_BUNDLE=${CHROMIUM_BUNDLE:-}
CHROMIUM_BINARY=${CHROMIUM_BINARY:-}
CHROMIUM_RUNTIME_BUNDLE=${CHROMIUM_RUNTIME_BUNDLE:-}

[ "$(id -u)" -eq 0 ] || {
    echo "Run as root; chroot mounts and package installation are required." >&2
    exit 1
}

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$(dirname "$OUTPUT")"
BUILD_HOST_MODE=1 \
IMPORT_SOURCE_IDENTITY=0 \
TARGET="$WORK_DIR/ubuntu24" \
MODULES_SOURCE="$MODULES_SOURCE" \
FIRMWARE_SOURCE="$FIRMWARE_SOURCE" \
    "$ROOT/scripts/bootstrap-rootfs.sh" "$INPUT_DIR"

if [ -n "$CHROMIUM_BUNDLE$CHROMIUM_BINARY$CHROMIUM_RUNTIME_BUNDLE" ]; then
    [ -f "$CHROMIUM_BUNDLE" ] || {
        echo "Missing CHROMIUM_BUNDLE: $CHROMIUM_BUNDLE" >&2
        exit 1
    }
    [ -x "$CHROMIUM_BINARY" ] || {
        echo "Missing executable CHROMIUM_BINARY: $CHROMIUM_BINARY" >&2
        exit 1
    }
    [ -f "$CHROMIUM_RUNTIME_BUNDLE" ] || {
        echo "Missing CHROMIUM_RUNTIME_BUNDLE: $CHROMIUM_RUNTIME_BUNDLE" >&2
        exit 1
    }
    chromium_dir="$WORK_DIR/ubuntu24/opt/equuleus-release/chromium"
    install -d -m 0755 "$chromium_dir"
    install -m 0644 "$CHROMIUM_BUNDLE" "$chromium_dir/chromium.flatpak"
    install -m 0644 "$CHROMIUM_RUNTIME_BUNDLE" "$chromium_dir/runtime.flatpak"
    install -m 0755 "$CHROMIUM_BINARY" "$chromium_dir/chrome"
    install -m 0755 "$ROOT/chromium/chromium-equuleus-v4l2" \
        "$WORK_DIR/ubuntu24/usr/local/bin/chromium-equuleus-v4l2"
    cp "$ROOT/chromium/install-equuleus-chromium-v4l2.sh" \
        "$chromium_dir/install.sh"
    chmod 0755 "$chromium_dir/install.sh"
    install -d -m 0755 -o 1000 -g 1000 \
        "$WORK_DIR/ubuntu24/home/ivan/.config/systemd/user/default.target.wants"
    ln -sfn /etc/systemd/user/equuleus-chromium-bootstrap.service \
        "$WORK_DIR/ubuntu24/home/ivan/.config/systemd/user/default.target.wants/equuleus-chromium-bootstrap.service"
fi

tar --numeric-owner --xattrs --acls -C "$WORK_DIR/ubuntu24" -cpf - . |
    zstd -T0 -19 -o "$OUTPUT"
sha256sum "$OUTPUT" > "$OUTPUT.sha256"
printf 'Built clean rootfs: %s\n' "$OUTPUT"
