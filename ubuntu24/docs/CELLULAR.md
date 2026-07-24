# Qualcomm cellular modem on Xiaomi Mi 8 Pro

The Equuleus modem runs on the SDM845 MSS remote processor. Control traffic
uses QMI over QRTR and packet traffic uses the Qualcomm IPA network device.

## Safety

Never write generic data to `modemst1`, `modemst2`, `fsg`, `persist` or the
other radio calibration partitions. Those partitions contain device-specific
identity, provisioning and calibration data. This port only reads the stock
modem firmware and communicates with the running modem.

## Boot sequence

1. `rmtfs.service` and `tqftpserv.service` provide the modem's remote storage.
2. `equuleus-mss.service` starts the MSS remote processor.
3. `equuleus-modem.service` loads IPA and RMNET, waits for QMI on `qrtr://0`
   and changes the modem operating mode to `online`, then selects LTE first
   with UMTS and GSM fallback.
4. ModemManager starts after modem initialization and exposes the modem to
   NetworkManager.

Run the non-destructive diagnostic command:

```sh
equuleus-cellular-status
```

The command intentionally does not print the IMEI.

## IPA firmware

The IPA driver requires the device's stock `ipa_fws.mdt` and split firmware
files. Mount the stock vendor partition read-only and install them with:

```sh
sudo mount -o ro /dev/disk/by-partlabel/vendor /mnt/vendor-stock
sudo scripts/install-cellular-firmware.sh
```

The proprietary firmware is not stored in Git. A release firmware staging
tree must contain `ipa_fws.mdt` and `ipa_fws.b00` through `ipa_fws.b04` at its
root.

## Mobile data

After ModemManager lists a modem, create a NetworkManager GSM connection with
the SIM operator's APN:

```sh
nmcli connection add type gsm ifname '*' con-name cellular apn APN
nmcli connection up cellular
```

Do not hard-code an operator APN in the system image.

## Expected results

- `qrtr-lookup` lists DMS, NAS, WDS, UIM and IPA control services.
- The modem operating mode is `online`.
- UIM slot status reports a present SIM instead of `absent`.
- ModemManager lists the Qualcomm SoC modem.
- An IPA, WWAN or RMNET network interface is present.
- NetworkManager can register and establish a packet-data connection.

`absent` or `no-atr-received` means the modem cannot communicate with the SIM.
Check that the SIM is inserted and works in the stock system before debugging
APN or packet-data setup.

## Validation on July 24, 2026

Temporary boot validation completed the Linux-side path:

- IPA firmware authenticated and the driver completed setup.
- `rmnet_ipa0` was created.
- ModemManager exported a `qcom-soc` modem using `qrtr0` and `rmnet_ipa0`.
- NetworkManager exposed `qrtr0` as a GSM device.
- LTE, UMTS and GSM were enabled with LTE first in the acquisition order.

Both physical SIM slots reported `absent`, so operator registration, APN
activation and packet-data traffic remain pending a known-good installed SIM.
