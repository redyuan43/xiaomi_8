#!/bin/sh
set -eu

TARGET=${TARGET:-/ubuntu24}
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ "$#" -gt 0 ] || { echo "usage: chroot-run.sh command [args...]" >&2; exit 2; }

cleanup() {
    for path in run dev/pts dev sys proc; do
        if mountpoint -q "$TARGET/$path"; then
            umount -R "$TARGET/$path" || umount -Rl "$TARGET/$path" || true
        fi
    done
}
trap cleanup EXIT INT TERM

mkdir -p "$TARGET/proc" "$TARGET/sys" "$TARGET/dev/pts" "$TARGET/run"
mount -t proc proc "$TARGET/proc"
mount --rbind /sys "$TARGET/sys"
mount --make-rslave "$TARGET/sys"
mount --rbind /dev "$TARGET/dev"
mount --make-rslave "$TARGET/dev"
mount --rbind /run "$TARGET/run"
mount --make-rslave "$TARGET/run"
chroot "$TARGET" "$@"

