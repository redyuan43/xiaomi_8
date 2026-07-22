#!/bin/sh
set -eu

BASE_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz"
BASE_SHA256="04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:-/mnt/ivan-ext4-offload/redmi_8/equuleus-ubuntu24/inputs}
PD_SOURCE=${PD_SOURCE:-/home/ivan/github/redmi_8/equuleus-porting/releases/equuleus-linux-touch-20260717/postmarketos-v24.12/pd-mapper-v1.1/pd-mapper-1.1.tar.gz}

mkdir -p "$OUT"
if [ ! -f "$OUT/ubuntu-base-24.04.4-base-arm64.tar.gz" ]; then
    curl -fL --retry 3 "$BASE_URL" -o "$OUT/ubuntu-base-24.04.4-base-arm64.tar.gz"
fi
printf '%s  %s\n' "$BASE_SHA256" "$OUT/ubuntu-base-24.04.4-base-arm64.tar.gz" | sha256sum -c -
cp -f "$PD_SOURCE" "$OUT/pd-mapper-1.1.tar.gz"
tar -C "$ROOT/rootfs-overlay" -czf "$OUT/equuleus-ubuntu24-overlay.tar.gz" .
cp -f "$ROOT/packages.txt" "$OUT/packages.txt"
cp -f "$ROOT/scripts/bootstrap-rootfs.sh" "$OUT/bootstrap-rootfs.sh"
(cd "$OUT" && sha256sum \
    ubuntu-base-24.04.4-base-arm64.tar.gz \
    pd-mapper-1.1.tar.gz \
    equuleus-ubuntu24-overlay.tar.gz \
    packages.txt \
    bootstrap-rootfs.sh > SHA256SUMS)
printf 'Prepared inputs in %s\n' "$OUT"
