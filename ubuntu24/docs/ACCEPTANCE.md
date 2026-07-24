# Acceptance and rollback

## Before temporary boot

```sh
fastboot devices
fastboot getvar product
fastboot getvar unlocked
fastboot boot dist/boot.img
```

Expected product is `equuleus`. Permanent boot writes are allowed only through
the reviewed `equuleus-installer commit` gate after acceptance.

## Ubuntu baseline

- `systemctl is-system-running` reaches `running` or only documented `degraded` units.
- `uname -r` is `5.12.0-sdm845` and `/` is `/dev/sda21[/ubuntu24]`.
- SSH works over USB at `172.16.42.1`.
- NetworkManager can connect after the operator supplies a Wi-Fi profile.
- DNS, HTTPS and time synchronization work.
- `vncpasswd`, `gui-start`, Remmina to port `5901`, and `gui-stop` work.
- Chromium, Thunar, Mousepad, Xterm and Onboard start as user `ivan`.
- Power, volume-up and volume-down are visible as Linux input capabilities.
- Battery capacity and charging state are visible in `/sys/class/power_supply`.

## Display safe area

The native framebuffer remains `1080x2248`. The final clockwise-rotated Xorg
desktop must report `2072x1080`, with a 96-pixel physical black inset on the
left and an 80-pixel inset on the right:

```sh
cat /sys/class/graphics/fb0/virtual_size
DISPLAY=:0 xdpyinfo | awk '/dimensions:/ { print $2 }'
readlink -f /etc/equuleus/xorg-active.conf
grep -E 'EQUULEUSFBDEV|safe insets' /var/log/Xorg.0.log
```

Expected results are:

```text
1080,2248
2072x1080
/etc/X11/equuleus-fbdev-safe.conf
```

Before enabling the custom driver, the stage-one Dock service may be tested
with the stock `2248x1080` desktop. In that mode `_NET_WORKAREA` must begin at
X=96 and have width 2072, but fullscreen applications are not yet accepted:

```sh
DISPLAY=:0 xprop -root _NET_WORKAREA
```

Touch acceptance requires taps and drags at the four safe-area corners and
center to track correctly. Touches entirely inside physical Y ranges `0..95`
and `2168..2247` must not activate controls at the logical desktop edges.

## Bluetooth stage

Bluetooth is accepted only when `hci0` exists, scanning returns real devices,
and one physical device pairs, connects and reconnects after restarting BlueZ.
Module loading alone is not success.

## Camera stage

Camera acceptance requires all of the following:

- `/dev/media*` exists and `media-ctl -p` shows the Qualcomm CAMSS graph.
- The graph includes the expected sensor entity, starting with rear `imx363`.
- A capture node reports a camera driver through `v4l2-ctl --all`.
- A bounded capture produces real frames without CAMSS, CSID, CSIPHY, or VFE
  errors in the kernel log.

The existing `qcom-venus-decoder` and `qcom-venus-encoder` `/dev/video*`
nodes are codec devices, not camera success criteria.

## Cellular modem

Run:

```sh
equuleus-cellular-status
```

The MSS remote processor must be running, QMI services DMS, NAS, WDS, UIM and
IPA control must be listed, and the modem operating mode must be `online`.
With a known-good SIM installed, UIM must report the card as present,
ModemManager must list the modem, and NetworkManager must be able to establish
a packet-data connection through an IPA, WWAN or RMNET interface.

## Rollback

To roll only the physical display back to the stock Xorg driver over USB SSH:

```sh
sudo equuleus-display-safe-area-rollback
```

To enable the final safe-area driver again:

```sh
sudo equuleus-display-safe-area-enable
```

The stock profile restores a `2248x1080` X desktop. The FTS dead zones remain
inactive for input events at the physical rounded edges, while the remaining
touch area keeps its original coordinates.

Power-cycle or reboot to the bootloader and temporarily boot:

```sh
fastboot boot /home/ivan/github/redmi_8/equuleus-porting/releases/equuleus-linux-touch-20260717/postmarketos-v24.12/equuleus-pmos-v24.12-linux5.12-touch-boot.img
```

Before `commit`, the boot partition is not modified. Device-specific backups
provide the same-device rollback source after a permanent boot commit.
