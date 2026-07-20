#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root" >&2
    exit 1
fi

source_dir=${1:-/mnt/modem-stock/image}
speaker_firmware=${2:-/mnt/vendor-stock/firmware/tas2557_uCDSP.bin}
speaker_calibration=${3:-/mnt/persist-stock/audio/tas2557_cal.bin}
target_dir=/lib/firmware/qcom/sdm845/mi8

for file in adsp.mdt adsp.b00 adsp.b01 adsp.b02 adsp.b03 adsp.b04 adsp.b05 \
    adsp.b06 adsp.b07 adsp.b08 adsp.b09 adsp.b10 adsp.b11 adsp.b12 \
    adsp.b13 adsp.b14 adspr.jsn adspua.jsn; do
    [ -f "$source_dir/$file" ] || {
        echo "Missing $source_dir/$file" >&2
        exit 1
    }
done

[ -f "$speaker_firmware" ] || {
    echo "Missing $speaker_firmware" >&2
    exit 1
}

[ -f "$speaker_calibration" ] || {
    echo "Missing $speaker_calibration" >&2
    exit 1
}

install -d -m 0755 "$target_dir"
install -m 0644 "$source_dir"/adsp.b* "$source_dir"/adspr.jsn \
    "$source_dir"/adspua.jsn "$target_dir/"
install -m 0644 "$source_dir/adsp.mdt" "$target_dir/adsp.mbn"
install -m 0644 "$speaker_firmware" /lib/firmware/tas2557_uCDSP.bin
install -d -m 0755 /mnt/vendor/persist/audio
install -m 0644 "$speaker_calibration" \
    /mnt/vendor/persist/audio/tas2557_cal.bin

sha256sum "$target_dir/adsp.mbn" "$target_dir"/adsp.b* \
    /lib/firmware/tas2557_uCDSP.bin \
    /mnt/vendor/persist/audio/tas2557_cal.bin
