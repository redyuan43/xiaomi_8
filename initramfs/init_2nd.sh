#!/bin/sh
# shellcheck disable=SC1091

. /init_functions.sh
. /init_functions_2nd.sh

setup_udev
setup_usb_network
start_unudhcpd
setup_framebuffer
setup_dynamic_partitions "${deviceinfo_super_partitions:=}"
run_hooks /hooks
mount_subpartitions
wait_root_partition

partition=$(find_root_partition)
check_filesystem "$partition"
mkdir -p /hostroot /sysroot
mount -t ext4 -o rw "$partition" /hostroot || fail_halt_boot

if [ ! -x /hostroot/ubuntu24/sbin/init ]; then
    echo "$LOG_PREFIX ERROR: /ubuntu24/sbin/init is missing" > /dev/kmsg
    show_splash "Ubuntu rootfs missing\nBoot the preserved postmarketOS image to repair it"
    fail_halt_boot
fi

mount --bind /hostroot/ubuntu24 /sysroot || fail_halt_boot
if ! umount /hostroot; then
    echo "$LOG_PREFIX ERROR: unable to detach userdata top-level mount" > /dev/kmsg
    fail_halt_boot
fi

echo "Switching root to Ubuntu 24.04"
if [ -e /proc/1/fd/3 ]; then
    exec 1>&3 2>&4
fi
echo ratelimit > /proc/sys/kernel/printk_devkmsg
killall udevd syslogd 2>/dev/null || true
for pid in $(pidof sh); do
    [ "$pid" = 1 ] || kill -9 "$pid"
done
exec switch_root /sysroot /sbin/init

echo "$LOG_PREFIX ERROR: Ubuntu switch_root failed" > /dev/kmsg
fail_halt_boot

