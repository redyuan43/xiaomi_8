#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
	echo "usage: $0 BUILD_DIR INITRAMFS_CPIO_GZ MKBOOTIMG_PY" >&2
	exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
build_dir=$1
initramfs=$2
mkbootimg=$3
image="$build_dir/equuleus-linux-test-boot.img"
builder=equuleus-kernel-builder:22.04

mkdir -p "$build_dir"
docker build -t "$builder" "$script_dir"

docker run --rm \
	-v "$source_dir:/src" \
	-v "$build_dir:/build" \
	"$builder" sh -lc '
		set -eu
		make -C /src O=/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
		cd /build
		/src/scripts/kconfig/merge_config.sh -m -O /build \
			/build/.config \
			/src/arch/arm64/configs/sdm845.config \
			/src/tools/equuleus/equuleus-test.config
		make -C /src O=/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
		make -C /src O=/build ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image.gz dtbs
	'

cp "$build_dir/arch/arm64/boot/Image.gz" "$build_dir/Image.gz-dtb"
cat "$build_dir/arch/arm64/boot/dts/qcom/sdm845-xiaomi-equuleus.dtb" \
	>> "$build_dir/Image.gz-dtb"

python3 "$mkbootimg" \
	--header_version 1 \
	--pagesize 4096 \
	--base 0x00000000 \
	--kernel "$build_dir/Image.gz-dtb" \
	--ramdisk "$initramfs" \
	--cmdline "console=tty0 console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xA84000 loglevel=7" \
	--output "$image"

sha256sum "$image"
