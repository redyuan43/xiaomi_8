#!/bin/sh
set -eu

TARGET=${TARGET:-/ubuntu24}
DISPLAY_NUM=${DISPLAY_NUM:-9}
DISPLAY=:$DISPLAY_NUM
VNC_LOCALHOST=${VNC_LOCALHOST:-yes}
VNC_SECURITY_TYPES=${VNC_SECURITY_TYPES:-None}
RUN_ACCEPTANCE=${RUN_ACCEPTANCE:-yes}
HOLD_SECONDS=${HOLD_SECONDS:-0}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "run as root"
chroot "$TARGET" test -x /usr/bin/vncserver || fail "TigerVNC is missing"
case "$VNC_LOCALHOST" in yes|no) ;; *) fail "VNC_LOCALHOST must be yes or no" ;; esac
case "$VNC_SECURITY_TYPES" in None|VncAuth) ;; *) fail "unsupported VNC security type" ;; esac
case "$RUN_ACCEPTANCE" in yes|no) ;; *) fail "RUN_ACCEPTANCE must be yes or no" ;; esac
case "$HOLD_SECONDS" in *[!0-9]*|'') fail "HOLD_SECONDS must be a non-negative integer" ;; esac
[ "$VNC_SECURITY_TYPES" != VncAuth ] || chroot "$TARGET" test -s /home/ivan/.vnc/passwd || \
    fail "VNC password is missing"

cleanup() {
    chroot "$TARGET" runuser -u ivan -- env HOME=/home/ivan \
        vncserver -kill "$DISPLAY" >/dev/null 2>&1 || true
    chroot "$TARGET" pkill -u ivan >/dev/null 2>&1 || true
    sleep 1
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

chroot "$TARGET" runuser -u ivan -- env HOME=/home/ivan USER=ivan \
    vncserver "$DISPLAY" -geometry 1280x720 -depth 24 -localhost "$VNC_LOCALHOST" \
    -SecurityTypes "$VNC_SECURITY_TYPES" -xstartup /home/ivan/.vnc/xstartup
sleep 8
chroot "$TARGET" runuser -u ivan -- env HOME=/home/ivan DISPLAY="$DISPLAY" xset q >/dev/null
if [ "$RUN_ACCEPTANCE" = yes ]; then
    chroot "$TARGET" pgrep -a xfce4-session
    chroot "$TARGET" pgrep -a xfwm4
    chroot "$TARGET" curl -fsS https://example.com/ >/dev/null
    chroot "$TARGET" runuser -u ivan -- env HOME=/home/ivan USER=ivan DISPLAY="$DISPLAY" \
        GTK_A11Y=none LIBGL_ALWAYS_SOFTWARE=1 WEBKIT_DISABLE_COMPOSITING_MODE=1 \
        WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
        sh -c 'epiphany-browser --new-window https://example.com >$HOME/.vnc/epiphany-test.log 2>&1 &'
    sleep 12
    chroot "$TARGET" pgrep -a -f epiphany
    printf 'Virtual Xfce and Epiphany chroot test passed on %s\n' "$DISPLAY"
fi
[ "$HOLD_SECONDS" -eq 0 ] || sleep "$HOLD_SECONDS"
