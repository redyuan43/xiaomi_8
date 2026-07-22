#!/bin/sh
set -eu

INPUT_DIR=${1:-/home/ivan/ubuntu24-inputs}
TARGET=${TARGET:-/ubuntu24}
IMPORT_SOURCE_IDENTITY=${IMPORT_SOURCE_IDENTITY:-0}
BUILD_HOST_MODE=${BUILD_HOST_MODE:-0}
MODULES_SOURCE=${MODULES_SOURCE:-/lib/modules/5.12.0-sdm845}
FIRMWARE_SOURCE=${FIRMWARE_SOURCE:-/lib/firmware}
STAGE=${TARGET}.stage
BASE="$INPUT_DIR/ubuntu-base-24.04.4-base-arm64.tar.gz"
OVERLAY="$INPUT_DIR/equuleus-ubuntu24-overlay.tar.gz"
PACKAGES="$INPUT_DIR/packages.txt"
PD_SOURCE="$INPUT_DIR/pd-mapper-1.1.tar.gz"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "run as root"
[ "$(uname -m)" = aarch64 ] || fail "expected aarch64 host"
if [ "$BUILD_HOST_MODE" != 1 ]; then
    grep -Eq '^ID="?postmarketos"?$' /etc/os-release || fail "bootstrap must run from postmarketOS"
    [ "$(findmnt -n -o SOURCE /)" = /dev/sda21 ] || fail "unexpected userdata root"
fi
[ ! -e "$TARGET" ] || fail "$TARGET already exists"
[ -d "$MODULES_SOURCE" ] || fail "missing modules source $MODULES_SOURCE"
[ -d "$FIRMWARE_SOURCE" ] || fail "missing firmware source $FIRMWARE_SOURCE"
for file in "$BASE" "$OVERLAY" "$PACKAGES" "$PD_SOURCE" "$INPUT_DIR/SHA256SUMS"; do
    [ -f "$file" ] || fail "missing $file"
done
(cd "$INPUT_DIR" && sha256sum -c SHA256SUMS)

available_kb=$(df -Pk "$(dirname "$TARGET")" | awk 'NR == 2 {print $4}')
[ "$available_kb" -ge 12582912 ] || fail "less than 12 GiB free at target"

cleanup_mounts() {
    for path in run dev/pts dev sys proc; do
        mountpoint -q "$STAGE/$path" && umount -R "$STAGE/$path" || true
    done
}
trap cleanup_mounts EXIT INT TERM

if [ -e "$STAGE" ]; then
    grep -Eq '^ID=ubuntu$' "$STAGE/etc/os-release" || fail "$STAGE is not an Ubuntu rootfs"
    printf 'Resuming validated Ubuntu stage at %s\n' "$STAGE"
else
    mkdir -p "$STAGE"
    tar -xpf "$BASE" -C "$STAGE"
fi
mkdir -p "$STAGE/etc/apt" "$STAGE/etc/NetworkManager/system-connections"
if [ -f "$STAGE/etc/apt/sources.list.d/ubuntu.sources" ]; then
    rm -f "$STAGE/etc/apt/sources.list"
else
    cat > "$STAGE/etc/apt/sources.list" <<'EOF'
deb http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse
EOF
fi
cp -L /etc/resolv.conf "$STAGE/etc/resolv.conf"
cat > "$STAGE/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
chmod 0755 "$STAGE/usr/sbin/policy-rc.d"

mkdir -p "$STAGE/proc" "$STAGE/sys" "$STAGE/dev/pts" "$STAGE/run"
mount -t proc proc "$STAGE/proc"
mount --rbind /sys "$STAGE/sys"
mount --make-rslave "$STAGE/sys"
mount --rbind /dev "$STAGE/dev"
mount --make-rslave "$STAGE/dev"
mount --rbind /run "$STAGE/run"
mount --make-rslave "$STAGE/run"

package_args=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$PACKAGES" | tr '\n' ' ')
chroot "$STAGE" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
# shellcheck disable=SC2086
chroot "$STAGE" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $package_args

tar -xpf "$OVERLAY" -C "$STAGE"
chown -R root:root \
    "$STAGE/etc/X11" \
    "$STAGE/etc/equuleus" \
    "$STAGE/etc/modules-load.d" \
    "$STAGE/etc/modprobe.d" \
    "$STAGE/etc/systemd" \
    "$STAGE/etc/sysctl.d" \
    "$STAGE/usr/local/bin" \
    "$STAGE/usr/local/libexec" \
    "$STAGE/usr/local/share"
mkdir -p "$STAGE/usr/local/src"
tar -xpf "$PD_SOURCE" -C "$STAGE/usr/local/src"
chroot "$STAGE" make -C /usr/local/src/pd-mapper-1.1 clean
chroot "$STAGE" make -C /usr/local/src/pd-mapper-1.1
chroot "$STAGE" make -C /usr/local/src/pd-mapper-1.1 install

mkdir -p "$STAGE/lib/modules" "$STAGE/lib/firmware"
cp -a "$MODULES_SOURCE" "$STAGE/lib/modules/5.12.0-sdm845"
for path in qcom ath10k qca regulatory.db regulatory.db.p7s; do
    [ -e "$FIRMWARE_SOURCE/$path" ] && cp -a "$FIRMWARE_SOURCE/$path" "$STAGE/lib/firmware/"
done
chroot "$STAGE" depmod -a 5.12.0-sdm845

chroot "$STAGE" getent passwd ivan >/dev/null 2>&1 || \
    chroot "$STAGE" useradd -m -s /bin/bash -G sudo,audio,video,input,netdev ivan
chroot "$STAGE" usermod -aG audio ivan
chroot "$STAGE" passwd -l ivan

if [ "$IMPORT_SOURCE_IDENTITY" = 1 ]; then
    if [ -r /etc/NetworkManager/system-connections/330_5G.nmconnection ]; then
        cp /etc/NetworkManager/system-connections/330_5G.nmconnection \
            "$STAGE/etc/NetworkManager/system-connections/"
        chmod 0600 "$STAGE/etc/NetworkManager/system-connections/330_5G.nmconnection"
    fi

    password_hash=$(awk -F: '$1 == "ivan" {print $2}' /etc/shadow)
    [ -n "$password_hash" ] && chroot "$STAGE" usermod -p "$password_hash" ivan
    if [ -r /home/ivan/.ssh/authorized_keys ]; then
        install -d -m 0700 -o 1000 -g 1000 "$STAGE/home/ivan/.ssh"
        install -m 0600 -o 1000 -g 1000 \
            /home/ivan/.ssh/authorized_keys \
            "$STAGE/home/ivan/.ssh/authorized_keys"
    fi
fi

cat > "$STAGE/etc/hostname" <<'EOF'
xiaomi-equuleus-ubuntu
EOF
ln -sfn /usr/share/zoneinfo/Asia/Shanghai "$STAGE/etc/localtime"
cat > "$STAGE/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 xiaomi-equuleus-ubuntu xiaomi-equuleus
::1 localhost ip6-localhost ip6-loopback
EOF
cat > "$STAGE/etc/fstab" <<'EOF'
# Root is bind-mounted by the equuleus initramfs from /dev/sda21/ubuntu24.
proc /proc proc nosuid,nodev,noexec 0 0
EOF
cat > "$STAGE/etc/NetworkManager/system-connections/equuleus-usb.nmconnection" <<'EOF'
[connection]
id=equuleus-usb
type=ethernet
interface-name=usb0
autoconnect=true

[ipv4]
method=shared
address1=172.16.42.1/24

[ipv6]
method=disabled
EOF
chmod 0600 "$STAGE/etc/NetworkManager/system-connections/equuleus-usb.nmconnection"

chroot "$STAGE" systemctl set-default multi-user.target
chroot "$STAGE" systemctl mask display-manager.service lightdm.service 2>/dev/null || true
chroot "$STAGE" systemctl enable NetworkManager.service ssh.service systemd-timesyncd.service
chroot "$STAGE" systemctl enable tqftpserv.service rmtfs.service equuleus-mss.service pd-mapper.service equuleus-wifi.service equuleus-adsp.service equuleus-audio.service
chroot "$STAGE" systemctl enable equuleus-xorg.service equuleus-vnc-firewall.service
mkdir -p "$STAGE/var/lib/systemd/linger"
touch "$STAGE/var/lib/systemd/linger/ivan"
mkdir -p "$STAGE/home/ivan/.vnc" "$STAGE/home/ivan/.config/systemd/user/default.target.wants"
install -m 0755 "$STAGE/etc/equuleus/vnc-xstartup" "$STAGE/home/ivan/.vnc/xstartup"
ln -sfn /etc/systemd/user/equuleus-local-xfce.service \
    "$STAGE/home/ivan/.config/systemd/user/default.target.wants/equuleus-local-xfce.service"
ln -sfn /etc/systemd/user/equuleus-battery-panel.service \
    "$STAGE/home/ivan/.config/systemd/user/default.target.wants/equuleus-battery-panel.service"
chown -R 1000:1000 "$STAGE/home/ivan/.vnc" "$STAGE/home/ivan/.config"

rm -f "$STAGE/usr/sbin/policy-rc.d"
chroot "$STAGE" apt-get clean
rm -rf "$STAGE/var/lib/apt/lists"/* "$STAGE/etc/machine-id"
touch "$STAGE/etc/machine-id"
cleanup_mounts
trap - EXIT INT TERM
mv "$STAGE" "$TARGET"
printf 'Ubuntu rootfs installed at %s\n' "$TARGET"
