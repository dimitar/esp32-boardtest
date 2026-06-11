# esp32

Home automation firmware for ESP32 boards. The end goal is an **ESP32 + CC1101
RF433 controller for A-OK roller-shutter motors** (sold here under the **NuStyle**
brand), exposed to **Home Assistant**.

The shutter motors use the **A-OK protocol at 433.92 MHz OOK/ASK** — a
reverse-engineered, 65-bit framed protocol with a per-remote ID and checksum.
It isn't a secure rolling code, so captured UP/DOWN/STOP frames can be replayed
directly (pairing the ESP as a new virtual remote via each motor's PROGRAM
button is the advanced alternative). Protocol reference:
[akirjavainen/A-OK](https://github.com/akirjavainen/A-OK).

## What's in here

Two independent sub-projects, each with its own toolchain and README:

| Directory | Toolchain | Purpose |
|-----------|-----------|---------|
| [`shutters-cc1101/`](shutters-cc1101/) | ESPHome (YAML) | **The shutter controller** — the real deliverable. Capture the remote, then drive the shutters as Home Assistant covers. |
| [`boardtest/`](boardtest/) | ESP-IDF v5.5.4 (C) | Board bring-up — chip info + blink + optional WiFi, to confirm a new board is alive. |

`scripts/` holds the ESP-IDF install/activate/chip-detect helpers used by
`boardtest`. `docs/` holds the design spec and implementation plan.

## Hardware

ESP32 dev board + **CC1101 433 MHz transceiver** + a 433 MHz antenna + jumper
wires. The CC1101 wiring and a per-pin table are in
[`shutters-cc1101/README.md`](shutters-cc1101/README.md).

> ⚠️ **The CC1101 is 3.3 V only — 5 V permanently destroys it.** Power it from
> the ESP32's `3V3` pin. ESP32 SPI pins are 3.3 V, so no level shifter is needed.

## Getting started

- **Build the shutter controller:** see [`shutters-cc1101/README.md`](shutters-cc1101/README.md).
  Requires ESPHome (a virtualenv lives at `~/esp/esphome-venv`).
- **Bring up a bare board first:** see [`boardtest/README.md`](boardtest/README.md).
  Requires ESP-IDF (`./scripts/setup-idf.sh` installs it to `~/esp/esp-idf`).

## Secrets

Credentials are never committed. ESP-IDF keeps WiFi creds in the gitignored
`sdkconfig` (set via `menuconfig`); ESPHome keeps them in a gitignored
`secrets.yaml` (copy `shutters-cc1101/secrets.yaml.example`).
