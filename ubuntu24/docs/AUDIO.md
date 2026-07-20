# Audio on Xiaomi Mi 8 Pro

The phone uses the Qualcomm WCD9340 (Tavil) codec for microphones and a Texas
Instruments TAS2557 smart amplifier for the internal loudspeaker. Audio DSP
services run on the SDM845 ADSP through QDSP6.

## Kernel paths

- `SLIMBUS_0_TX` carries WCD9340 microphone capture to QDSP6.
- `QUATERNARY_MI2S_RX` carries QDSP6 playback to TAS2557.
- TAS2557 control uses a GPIO-backed I2C adapter on GPIO85/86. The hardware
  GENI SE5 instance is GSI-only on this boot firmware, while enabling its GPI
  DMA controller caused an unrecoverable USB/network startup failure during
  testing. Keep GPI DMA disabled for this port.
- GPIO76 resets TAS2557 and GPIO30 is its interrupt line.

The TAS2557 driver is derived from the GPLv2 TI/Xiaomi implementation in
<https://github.com/Coconutat/android_kernel_xiaomi_sdm845_byd_exp>, with
Android-only speaker-ID, misc-device and TILOAD interfaces removed. It was
migrated from the legacy ASoC codec API to the Linux 5.12 component API and
uses `kernel_read()` for the calibration file.
The imported reference revision is
`fe6f300f0aabe38a7c750a18a1597dc2ce54c7cc` (`KernelSU-Next`).

## Proprietary runtime files

These files are copied from the phone's read-only Android partitions and are
not committed to Git:

- stock ADSP split firmware from `/mnt/modem-stock/image`;
- `/mnt/vendor-stock/firmware/tas2557_uCDSP.bin`;
- `/mnt/persist-stock/audio/tas2557_cal.bin`.

Install them with:

```sh
sudo scripts/install-audio-firmware.sh \
  /mnt/modem-stock/image \
  /mnt/vendor-stock/firmware/tas2557_uCDSP.bin \
  /mnt/persist-stock/audio/tas2557_cal.bin
```

The expected destination paths are `/lib/firmware/qcom/sdm845/mi8`,
`/lib/firmware/tas2557_uCDSP.bin`, and
`/mnt/vendor/persist/audio/tas2557_cal.bin`.

## Automatic routing

`equuleus-adsp.service` starts the ADSP. `equuleus-audio.service` then waits
for ALSA card 0 and configures the stock main-microphone path:

```text
ADC3 -> AMIC/DEC5 -> SLIM TX5 -> SLIMBUS_0_TX -> MultiMedia1
```

When TAS2557 is present and its 48 kHz firmware configuration is ready, the
same service loads calibration index 255 and enables:

```text
MultiMedia1 -> QUAT_MI2S_RX -> TAS2557 ASI1
```

The amplifier remains powered off until a playback stream starts and returns
to off when that stream closes.

## Manual tests

Record the main microphone:

```sh
arecord -D hw:0,0 -f S16_LE -r 48000 -c 1 -d 5 mic-test.wav
```

Play a conservative 48 kHz stereo test file:

```sh
aplay -D hw:0,0 speaker-test-low.wav
```

The validated 1 kHz test tone used `volume=0.01` (approximately `-40 dB`) and
was intentionally quiet. A continuous 15-second playback was heard from the
phone's internal loudspeaker; TAS2557 powered down normally afterward.

Do not attempt simultaneous capture and playback through the same
`MultiMedia1` frontend. The current QDSP6 stack can leave that PCM session in
an error state; use sequential tests or separate frontends after implementing
and validating their routing.

## Validated hashes

- v9 temporary boot image: `fbd0db6539ff4a2264287b68d122380f7f8530e630670f8bc9fd4b0b77d15863`
- TAS2557 module: `e4ed640268f43a9f7b7ac54e4018ae7ca7f36006acd5e41a9a3e9f37fc431f27`
- TAS2557 firmware: `bfc717f8da0f573f07e29c463c2fb9d37adc6e0ab8ca9e41ac8a3e4e3a2e7434`
- device calibration: `65cf583380f8b0b2bec4455aa680f313fad9b2c4351d446de19a05135914eba1`
