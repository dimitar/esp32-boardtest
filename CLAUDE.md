# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project intent

The end goal of this repo is an **ESP32 + CC1101 RF433 controller for A-OK roller-shutter
motors** (sold under the **NuStyle** brand), integrated into **Home Assistant**. The shutter
motors speak the **A-OK protocol at 433.92 MHz OOK/ASK** — a reverse-engineered, 65-bit
framed protocol with a per-remote ID + checksum. It is *not* a secure rolling code, so
captured UP/DOWN/STOP frames can be replayed directly (pairing the ESP as a new virtual
remote via each motor's PROGRAM button is the advanced alternative). Protocol reference:
https://github.com/akirjavainen/A-OK

The repo holds **two independent sub-projects with different toolchains**:

| Dir | Toolchain | Purpose |
|-----|-----------|---------|
| `boardtest/` | ESP-IDF v5.5.4 (C) | Board bring-up: prints chip info, blinks an LED, optional WiFi STA. Used to verify new boards are alive. |
| `shutters-cc1101/` | ESPHome (YAML) | The actual shutter controller. The real deliverable. |

`boardtest` was the initial "is the hardware working" project; `shutters-cc1101` is where the
shutter-control work lives. They share nothing and are built with separate tools.

## Toolchain locations (installed outside the repo)

- **ESP-IDF v5.5.4** → `~/esp/esp-idf`. Activate per shell with `source scripts/env.sh`
  (wraps `~/esp/esp-idf/export.sh`), which puts `idf.py`/`esptool.py` on PATH.
- **ESPHome** → virtualenv at `~/esp/esphome-venv`. Run as `~/esp/esphome-venv/bin/esphome ...`
  or `source ~/esp/esphome-venv/bin/activate` first.
- First-time ESP-IDF install: `./scripts/setup-idf.sh` (idempotent; ~10–20 min).

## Common commands

### boardtest (ESP-IDF)
```bash
source scripts/env.sh                  # activate idf.py (once per terminal)
./scripts/detect-chip.sh               # ID the connected chip, prints the set-target to run
cd boardtest
idf.py set-target esp32                # or esp32s3 / esp32c3 etc. per detect-chip
idf.py menuconfig                      # "Board Test Configuration": WIFI_SSID/PASSWORD, BLINK_GPIO
idf.py build                           # validator: must end "Project build complete."
idf.py flash monitor                   # flash + serial (Ctrl-] exits). Needs a board + USB port.
```

### shutters-cc1101 (ESPHome)
```bash
cd shutters-cc1101
cp secrets.yaml.example secrets.yaml   # then edit WiFi creds (secrets.yaml is gitignored)
~/esp/esphome-venv/bin/esphome config capture.yaml    # validator: "Configuration is valid!"
~/esp/esphome-venv/bin/esphome run capture.yaml        # flash the capture profile; watch logs
# record raw timings from the remote, then:
cp shutter.example.yaml shutter.yaml   # paste captured UP/DOWN/STOP codes per cover block
~/esp/esphome-venv/bin/esphome run shutter.yaml
```

## Conventions and gotchas (non-obvious, will bite you)

- **CC1101 is 3.3 V ONLY** — wire VCC to the ESP32 `3V3` pin. 5 V permanently destroys it.
  ESP32 SPI pins are 3.3 V so no level shifter is needed. Pinout used in the YAML:
  CS=GPIO5, SCK=GPIO18, MOSI=GPIO23, MISO=GPIO19, GDO0(TX)=GPIO4, GDO2(RX)=GPIO16, plus a
  433 MHz antenna (range is ~1 m without one).
- **Secrets stay out of git.** ESP-IDF: WiFi creds go in `sdkconfig` (gitignored) via
  `menuconfig`, never in the committed `sdkconfig.defaults`. ESPHome: creds go in
  `secrets.yaml` (gitignored); only `secrets.yaml.example` is tracked. Verify before any push.
- **`idf.py set-target <chip>` wipes `sdkconfig`** (regenerates from `sdkconfig.defaults`),
  clearing menuconfig values including WiFi creds. To make a setting survive, put it in the
  committed `sdkconfig.defaults` — but never secrets.
- **Scripts target macOS bash 3.2.57.** Under `set -u`, expanding an empty array as
  `"${arr[@]}"` throws "unbound variable"; use the `${arr[@]+"${arr[@]}"}` guard (see
  `scripts/detect-chip.sh`).
- **No host unit tests (firmware).** The real validators are: `idf.py build` / `esphome config`
  compiling cleanly, and on-device behavior over the serial monitor. Verify changes that way.
- **boardtest's `main` component** implicitly depends on all ESP-IDF components, so adding
  esp_wifi/esp_netif/nvs etc. needs no explicit `REQUIRES`. New sources must be listed in
  `boardtest/main/CMakeLists.txt`. Reusable drivers go in `boardtest/components/<name>/`.

## Docs

`docs/superpowers/specs/` and `docs/superpowers/plans/` hold the design spec and
implementation plan for `boardtest` (dated 2026-06-11).
