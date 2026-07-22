#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 /path/to/chrome" >&2
	exit 2
fi

if [[ $(id -u) -eq 0 ]]; then
	echo "Run this installer as the desktop user, not as root." >&2
	exit 1
fi

source_binary=$(realpath "$1")
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target_dir="$HOME/.local/opt/chromium-equuleus-v4l2"
launcher_dir="$HOME/.local/bin"
application_id=org.chromium.Chromium
branch=equuleus-v4l2

test -x "$source_binary"
flatpak info --user "$application_id//$branch" >/dev/null

digest=$(sha256sum "$source_binary" | awk '{print substr($1, 1, 12)}')
target_binary="$target_dir/chrome-$digest"

mkdir -p "$target_dir" "$launcher_dir"
if [[ ! -e "$target_binary" ]]; then
	install -m 0755 "$source_binary" "$target_binary"
fi
ln -sfn "$(basename "$target_binary")" "$target_dir/chrome"

flatpak run \
	--user \
	--branch="$branch" \
	--arch=aarch64 \
	--command=sh \
	"$application_id" \
	-c '
		target=$HOME/.local/opt/chromium-equuleus-v4l2
		for source in /app/chromium/*; do
			name=${source##*/}
			[ "$name" = chrome ] ||
				ln -sfn "$source" "$target/$name"
		done
	'

install -m 0755 \
	"$script_dir/chromium-equuleus-v4l2" \
	"$launcher_dir/chromium-equuleus-v4l2"

flatpak run \
	--user \
	--branch="$branch" \
	--arch=aarch64 \
	--command="$target_dir/chrome" \
	"$application_id" \
	--version
sha256sum "$target_binary"
echo "Installed launcher: $launcher_dir/chromium-equuleus-v4l2"
