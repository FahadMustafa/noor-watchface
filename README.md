# Noor

A Connect IQ watch face for the Garmin Forerunner 245 Music, built around prayer times.

![Noor on a Forerunner 245 Music](screenshot.png)

## What it shows

- **Next prayer** with its time and a countdown (`in 1h 19m`). Between Fajr and sunrise it shows **Sunrise** (the end of Fajr time) in gold. Dhuhr shows as **Jumuah** on Fridays. The arc along the top rim fills from the previous prayer to the next one.
- **Date**: weekday, `dd/mm`, and the Hijri date in the Umm al-Qura calendar.
- **Time** in 12-hour format. A red phone icon appears under AM/PM when the phone is disconnected.
- **Heart rate, Body Battery and steps**, then **calories** and **battery**. Battery is also drawn as the arc along the bottom rim and turns red at 20% or below.

## Install

1. Download `noor.prg` from the [latest release](https://github.com/FahadMustafa/noor-watchface/releases/latest).
2. Connect the watch over USB and copy `noor.prg` into the `GARMIN/APPS` folder.
   - Windows: the watch shows up in File Explorer as a portable device.
   - macOS: use [OpenMTP](https://openmtp.ganeshrvel.com/), because the watch uses MTP and Finder can't see it.
3. Eject and unplug the watch. The file disappears from `GARMIN/APPS` once the watch installs it; that is expected.
4. On the watch, hold **UP**, select **Watch Face**, scroll to **Noor**, press **START** and select **Apply**.
5. Give it a location once: go outside, start any GPS activity until GPS is ready, then discard it. Until then the top line says `No location yet`. The face also picks up the location in the weather report from your phone.

To remove it, delete it from the watch-face list on the watch or use Garmin Express. The Connect IQ phone app can't remove apps that were copied over USB.

## Prayer times

Times are calculated on the watch from its last known position. The calculation method is chosen from that position and follows what [aladhan.com](https://aladhan.com) uses for each country:

| Where | Method | Fajr | Isha |
|---|---|---|---|
| Saudi Arabia | Umm al-Qura | 18.5° | 90 min after Maghrib (120 in Ramadan) |
| UAE, Oman | Dubai | 18.2° | 18.2° |
| Qatar, Bahrain | Qatar | 18° | 90 min after Maghrib |
| Kuwait | Kuwait | 18° | 17.5° |
| Jordan | Jordan | 18° | 18° |
| Egypt | Egyptian General Authority of Survey | 19.5° | 17.5° |
| Turkey | Diyanet | 18° | 17° |
| Pakistan, India, Bangladesh | Karachi | 18° | 18° |
| Malaysia, Singapore, Indonesia | JAKIM / MUIS / Kemenag | 20° | 18° |
| North America | ISNA | 15° | 15° |
| Everywhere else | Muslim World League | 18° | 17° |

Asr uses the standard (Shafi'i, Maliki, Hanbali) shadow length. At high latitudes, where the sun never gets low enough for Fajr or Isha in summer, the angle-based rule applies.

The unit tests compare 21 city and date cases against api.aladhan.com and all match within one minute.

Known limits:

- Countries are matched with rectangles, so a town right on a border can get the neighbouring country's method. The difference is a few minutes at Fajr and Isha.
- The Hijri date and the Ramadan Isha rule use an embedded Umm al-Qura table that runs to 1470 AH (October 2048). After that the Hijri date is hidden.
- After you travel, the times follow the last known position until the watch gets a GPS fix or a weather update from the phone.

## Customization

There are no settings on the watch or in the Connect IQ phone app. The phone app only shows settings for apps installed from the Connect IQ Store. To change something, edit the source and build your own `.prg`:

| To change | Edit |
|---|---|
| Colours | the `C_*` constants at the top of `source/NoorView.mc` (the screen has 64 colours, each channel `00`, `55`, `AA` or `FF`) |
| Which metrics show, and where | the `metric(...)` calls and y positions in `onUpdate` in `source/NoorView.mc` |
| Calculation method for a region | `REGIONS` in `source/Prayer.mc` (first match wins) |
| Minute adjustments to match your mosque | `TUNE` in `source/Prayer.mc`, per method: `[fajr, sunrise, dhuhr, asr, maghrib, isha]` |
| Method parameters | `FAJR_ANGLE`, `ISHA_ANGLE`, `ISHA_MINUTES`, `MAGHRIB_MINUTES` in `source/Prayer.mc` |
| Fonts | regenerate the files in `resources/fonts` with `tools/mkfont.py` from any TTF |
| Supported watches | add `<iq:product>` entries in `manifest.xml`. Only `fr245m` (240x240 round) is tested, and the layout assumes that screen. |

## Build from source

The face is plain Monkey C, so the official route works: install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and the Monkey C extension for VS Code, open the folder, run **Monkey C: Build for Device** and pick the Forerunner 245 Music.

This repo also has a headless Linux setup, tested on Ubuntu 24.04 under WSL:

```sh
# SDK and device files (needs a free Garmin account)
go install github.com/lindell/connect-iq-sdk-manager-cli@latest
connect-iq-sdk-manager-cli agreement accept
connect-iq-sdk-manager-cli login
connect-iq-sdk-manager-cli sdk set 9.3.0
connect-iq-sdk-manager-cli device download -d fr245m -F

# Signing key, outside the repo
openssl genrsa -out key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in key.pem -out ~/.Garmin/developer_key.der -nocrypt

# Simulator image (Ubuntu 22.04: the SDK needs libwebkit2gtk-4.0, which 24.04 dropped)
docker build -t ciq-sim .

tools/sim.sh test   # unit tests in the simulator
tools/sim.sh shot   # build bin/noor.prg and write screenshot.png
```

## Credits

- [Outfit](https://fonts.google.com/specimen/Outfit) font, SIL Open Font License 1.1
- [Material Symbols Rounded](https://fonts.google.com/icons) icons, Apache License 2.0
- Umm al-Qura month table from [hijridate](https://github.com/dralshehri/hijridate), MIT License, Copyright (c) Mohammed Alshehri
- Sun position formulas from [praytimes.org](http://praytimes.org)

The code is released under the [MIT License](LICENSE).
