# garmin-watchface

Custom Connect IQ watch face for the Garmin Forerunner 245 Music (product id `fr245m`, 240x240 round, 64 colours, API 3.3).

## Toolchain

- Connect IQ SDK via the SDK Manager (Windows), plus the target device file
- VS Code with the Garmin "Monkey C" extension
- Developer key: `openssl genrsa -out developer_key.pem 4096 && openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt` (kept out of git)

## Install

Build the `.prg`, plug the watch in over USB and copy it to `GARMIN/APPS/`.
