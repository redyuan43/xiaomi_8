#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: $0 ADB_SERIAL BOOT_IMAGE" >&2
	exit 2
fi

serial=$1
image=$2
device=$(adb -s "$serial" shell getprop ro.product.device 2>/dev/null | tr -d '\r')

if [ "$device" != "equuleus" ]; then
	echo "refusing to boot: ADB device is '$device', expected 'equuleus'" >&2
	exit 1
fi

adb -s "$serial" reboot bootloader
i=0
while [ "$i" -lt 30 ]; do
	if fastboot devices | grep -q "^$serial[[:space:]]"; then
		break
	fi
	i=$((i + 1))
	sleep 1
done

product=$(fastboot -s "$serial" getvar product 2>&1 | sed -n 's/.*product: //p' | tr -d '\r')
unlocked=$(fastboot -s "$serial" getvar unlocked 2>&1 | sed -n 's/.*unlocked: //p' | tr -d '\r')

if [ "$product" != "equuleus" ] || [ "$unlocked" != "yes" ]; then
	echo "refusing to boot: product=$product unlocked=$unlocked" >&2
	exit 1
fi

# This is intentionally temporary. Never replace it with `fastboot flash`.
fastboot -s "$serial" boot "$image"

