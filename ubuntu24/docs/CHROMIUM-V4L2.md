# Chromium Venus/V4L2 hardware decode

This document records the validated Chromium hardware-decoding path on the
Xiaomi Mi 8 Pro (`equuleus`, Snapdragon 845). The final validation used
Chromium `150.0.7871.128`, Ubuntu 24.04 ARM64 and Linux `5.12.0-sdm845`.

## Validated result

YouTube H.264 playback used the Qualcomm Venus decoder while the Xorg fbdev
desktop remained responsive:

| Measurement | Before | After 10 seconds |
| --- | ---: | ---: |
| Media time | 0.000 s | 10.022 s |
| Decoded frames | 4 | 248 |
| Dropped frames | 0 | 16 |
| Venus interrupt count | 233 | 356 |

The video reported `readyState=4`, no media error, and a decoded size of
854x480. The final browser screenshot is stored at
`docs/images/chromium-youtube-hwdecode-20260722.png`.

## Hardware and display facts

- `/dev/video0` is the Qualcomm Venus decoder.
- The node advertises MPEG-2, H.264, VP8, VP9 and HEVC decode up to 4096x4096.
- There is no `/dev/media0` on the validated image.
- Xorg uses the fbdev driver with a rotated display.
- DRI3 and a scanout-capable native-pixmap path are unavailable.
- Chromium therefore renders through ANGLE and llvmpipe even though video
  decoding itself can run on Venus.

## Why upstream Chromium stalled

The stock Linux V4L2 pipeline reached Venus, but its output path assumed that
decoded NV12 buffers could become native pixmaps and GPU mailboxes. That
assumption is false on the fbdev display stack.

The failures appeared in this order:

1. GPU blocklisting made video decode unavailable.
2. The GPU sandbox did not expose the required Venus node.
3. GL image processing failed with `Importing NV12 buffers is not supported`.
4. Selecting LibYUV reached Venus, but `PlatformVideoFramePool` still failed
   while allocating scanout/native-pixmap output frames.
5. YouTube stayed at 0:00 even though the Venus interrupt counter moved.

The final patch preserves V4L2/Venus decoding, gives the V4L2 path a
`STORAGE_OWNED_MEMORY` frame allocator, and uses
`SimpleVideoFrameConverter`. LibYUV copies the decoded NV12 image into a
CPU-backed `VideoFrame`, which Mojo can deliver to the renderer without DRI3
or native pixmaps.

This is hardware decode with a CPU-side display copy. It is not a zero-copy
display path.

## Apply the patch

From the Chromium `150.0.7871.128` source directory:

```sh
git apply \
  /path/to/xiaomi_8/ubuntu24/chromium/patches/0001-media-gpu-use-cpu-backed-v4l2-output-frames.patch
```

The patch changes only:

```text
media/mojo/services/gpu_mojo_media_client_linux.cc
```

## Required build configuration

The validated ARM64 build used these relevant GN arguments:

```gn
use_sysroot = false
enable_nacl = false
treat_warnings_as_errors = false
proprietary_codecs = true
ffmpeg_branding = "Chrome"
use_vaapi = false
use_v4l2_codec = true
```

The Flatpak manifest used the Freedesktop 24.08 SDK and Chromium
`150.0.7871.128`. Rust, Bindgen, Node, JDK, Esbuild and Gperf paths must point
to the corresponding files in the active Flatpak build environment; do not
copy workstation-specific absolute paths into a portable manifest.

## Targeted rebuild

Do not run a normal `ninja chrome` after regenerating the existing output
directory. Regeneration can make thousands of old targets appear dirty.

Use the targeted helper instead:

```sh
ubuntu24/chromium/rebuild-v4l2-output-path.sh \
  /path/to/chromium-source \
  out/Release
```

The helper performs only these operations:

1. Directly executes the generated compile command for
   `gpu_mojo_media_client_linux.o`.
2. Recreates `libmedia_mojo_services.a` from its 37 existing objects.
3. Reconstructs `chrome.rsp` from Ninja metadata.
4. Runs only the final Chromium link command with the Freedesktop 24.08 SDK
   library path.

The script expects the existing configured build directory and the user
installation of `org.freedesktop.Sdk/aarch64/24.08`.

## Device installation

The Flatpak branch remains required because the home-directory executable
uses `/app/chromium` resources and the Flatpak runtime:

```sh
flatpak info --user org.chromium.Chromium//equuleus-v4l2
ubuntu24/chromium/install-equuleus-chromium-v4l2.sh /path/to/chrome
```

The installer:

- installs a SHA-tagged binary under
  `~/.local/opt/chromium-equuleus-v4l2/`;
- updates the `chrome` symlink atomically;
- links the existing Flatpak resources beside the executable;
- installs `~/.local/bin/chromium-equuleus-v4l2`.

The launcher defaults to the tested proxy:

```text
http://127.0.0.1:10808
```

Override it when necessary:

```sh
CHROMIUM_PROXY_SERVER= chromium-equuleus-v4l2
```

## Runtime flags

The validated launcher uses:

```text
--no-sandbox
--disable-gpu-sandbox
--ignore-gpu-blocklist
--enable-features=AcceleratedVideoDecoder,AcceleratedVideoDecodeLinuxGL,LibYuvImageProcessor
--disable-features=VaapiVideoDecoder,VaapiVideoEncoder,Vulkan,UseGLForScaling,PreferGLImageProcessor
```

`--no-sandbox` is required when the executable lives in the home directory.
Without it, Chromium asks the Flatpak portal to spawn its zygote, but that
secondary sandbox cannot see the home-directory executable. This substantially
reduces browser isolation. Keep this as a dedicated test browser and do not
replace the stable browser with it.

## Validation procedure

Open an H.264 YouTube video, expose a local DevTools port, and sample all three
signals during the same playback interval:

```sh
grep -i venus /proc/interrupts
pgrep -af 'type=gpu-process'
DISPLAY=:0 xdpyinfo >/dev/null
```

Through DevTools, record:

- `video.currentTime`;
- `video.readyState`;
- `video.getVideoPlaybackQuality().totalVideoFrames`;
- `video.getVideoPlaybackQuality().droppedVideoFrames`.

Hardware decode is accepted only when:

- media time and decoded-frame count advance;
- the Venus interrupt count increases during that same interval;
- the Chromium GPU process remains alive;
- the page displays moving video without the frame-pool or NV12 import errors;
- Xorg remains responsive.

A log line mentioning FFmpeg's H.264 decoder is not sufficient evidence of
software fallback because Chromium also probes decoder capabilities. Use the
synchronized playback, frame and Venus measurements above.

## Lessons retained

- Inspect the real device node before changing Chromium sandbox policy.
- Do not assume `/dev/media0` exists on this downstream kernel.
- Separate decode acceleration from display acceleration: Venus can decode
  while Xorg still renders through llvmpipe.
- A growing hardware interrupt count with `currentTime=0` proves decoder work,
  not successful presentation.
- Avoid full rebuilds when one object, one archive and one final link are
  sufficient.
- Keep audio changes isolated; this Chromium work does not modify ALSA,
  PipeWire, QDSP6 or TAS2557 configuration.
