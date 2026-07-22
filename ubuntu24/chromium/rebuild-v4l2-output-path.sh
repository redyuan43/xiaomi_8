#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: rebuild-v4l2-output-path.sh CHROMIUM_SOURCE [OUT_DIR]

Rebuild only the patched Linux GPU media client, its static archive, and the
final Chromium executable. OUT_DIR defaults to out/Release.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
	usage >&2
	exit 2
fi

source_dir=$(realpath "$1")
out_arg=${2:-out/Release}
if [[ "$out_arg" = /* ]]; then
	out_dir=$(realpath "$out_arg")
else
	out_dir=$(realpath "$source_dir/$out_arg")
fi

object=\
"obj/media/mojo/services/services/gpu_mojo_media_client_linux.o"
archive="obj/media/mojo/services/libmedia_mojo_services.a"
source_file="$source_dir/media/mojo/services/gpu_mojo_media_client_linux.cc"

for command in ninja awk tail bash sha256sum; do
	command -v "$command" >/dev/null || {
		echo "Missing command: $command" >&2
		exit 1
	}
done

test -f "$out_dir/build.ninja"
test -f "$source_file"

if ! grep -q "CreateCpuVideoFrame" "$source_file"; then
	echo "The CPU-backed V4L2 output patch is not applied." >&2
	exit 1
fi

run_generated_command() {
	local target=$1
	ninja -C "$out_dir" -t commands "$target" |
		tail -n 1 |
		(cd "$out_dir" && bash)
}

write_rsp() {
	local target=$1
	local rule=$2
	local destination=$3

	ninja -C "$out_dir" -t query "$target" |
		awk -v marker="  input: $rule" '
			$0 == marker { inside = 1; next }
			inside && /^    \|/ { inside = 0; next }
			inside && /^    / {
				sub(/^    /, "")
				print
			}
		' >"$destination"

	test -s "$destination"
}

echo "[1/3] Compiling $object"
run_generated_command "$object"

echo "[2/3] Rebuilding $archive"
mkdir -p "$(dirname "$out_dir/$archive.rsp")"
write_rsp "$archive" alink "$out_dir/$archive.rsp"
grep -qx "$object" "$out_dir/$archive.rsp"
run_generated_command "$archive"

echo "[3/3] Relinking chrome"
write_rsp chrome link "$out_dir/chrome.rsp"

sdk_root=${FLATPAK_SDK_ROOT:-\
"$HOME/.local/share/flatpak/runtime/org.freedesktop.Sdk/aarch64/24.08/active/files"}
if [[ ! -d "$sdk_root/lib/aarch64-linux-gnu" ]]; then
	echo "Flatpak SDK libraries not found under: $sdk_root" >&2
	exit 1
fi

export LIBRARY_PATH="$sdk_root/lib/aarch64-linux-gnu:$sdk_root/lib"
run_generated_command chrome

"$out_dir/chrome" --version
sha256sum "$out_dir/chrome"
