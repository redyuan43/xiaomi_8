#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root" >&2
	exit 1
fi

source_dir=${1:-/mnt/vendor-stock/firmware}
target_dir=${2:-/lib/firmware}

for file in ipa_fws.mdt ipa_fws.b00 ipa_fws.b01 ipa_fws.b02 \
	ipa_fws.b03 ipa_fws.b04; do
	[ -f "$source_dir/$file" ] || {
		echo "Missing $source_dir/$file" >&2
		exit 1
	}
done

install -d -m 0755 "$target_dir"
install -m 0644 "$source_dir"/ipa_fws.mdt "$source_dir"/ipa_fws.b0[0-4] \
	"$target_dir/"

sha256sum "$target_dir"/ipa_fws.mdt "$target_dir"/ipa_fws.b0[0-4]
