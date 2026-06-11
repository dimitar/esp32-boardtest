# ESP32 Board-Test Repo — Design

**Date:** 2026-06-11
**Status:** Approved
**Framework:** ESP-IDF v5.x (latest stable)

## Goal

A repo at `/Users/jmilo/src/esp32` that installs ESP-IDF and provides a working
first project to confirm newly-acquired ESP32 boards are alive (chip info +
blink) and can connect to WiFi, with a clean structure for adding peripheral /
sensor tests later.

The exact ESP32 variant is unknown at design time, so the build is
target-agnostic and the chip is detected per-board over USB.

## Decisions

| Decision | Choice |
|----------|--------|
| Framework | ESP-IDF v5.x |
| First-cut scope | Blink + WiFi + sensor scaffold |
| IDF install | Install now, latest stable, to `~/esp/esp-idf` |
| WiFi credentials | menuconfig / Kconfig (`sdkconfig` gitignored) |
| Chip target | Auto-detected per board; nothing hardcoded to one variant |
| Default blink GPIO | 2 (common WROOM onboard LED), configurable via menuconfig |

## Repo Layout

```
esp32/
├── README.md              # setup + flash + detect-chip instructions
├── .gitignore             # ignores build/, sdkconfig (keeps sdkconfig.defaults)
├── scripts/
│   ├── setup-idf.sh       # one-time IDF install (clone + install.sh)
│   ├── env.sh             # source to activate idf.py (wraps export.sh)
│   └── detect-chip.sh     # reads connected board, prints chip + suggests set-target
├── boardtest/             # the first ESP-IDF project
│   ├── CMakeLists.txt
│   ├── sdkconfig.defaults
│   ├── components/        # sensor drivers go here later (README placeholder)
│   └── main/
│       ├── CMakeLists.txt
│       ├── Kconfig.projbuild   # WIFI_SSID, WIFI_PASSWORD, BLINK_GPIO
│       ├── main.c              # orchestrates: chip info → blink → wifi
│       ├── blink.c / blink.h
│       └── wifi.c  / wifi.h
└── docs/superpowers/specs/2026-06-11-esp32-boardtest-design.md
```

## Components

### ESP-IDF install (`scripts/`)
- `setup-idf.sh`: clones ESP-IDF v5.x (latest stable release branch) to
  `~/esp/esp-idf`, runs the official `install.sh`. Idempotent — skips clone if
  the directory already exists.
- `env.sh`: sources `~/esp/esp-idf/export.sh` so `idf.py` is on PATH. Run
  `source scripts/env.sh` once per terminal.
- `detect-chip.sh`: wraps `esptool.py chip_id` (or `--chip auto`) to print the
  connected chip and suggest the matching `idf.py set-target` command.

### `boardtest` application
On boot, `main.c` runs three steps:

1. **Chip info** — prints chip model, core count, silicon revision, flash size,
   and base MAC over the serial monitor. The "is it alive / what is it" check.
2. **Blink** — blinks an LED on `CONFIG_BLINK_GPIO` (default 2) in its own
   FreeRTOS task.
3. **WiFi** — connects as a station to `CONFIG_WIFI_SSID` /
   `CONFIG_WIFI_PASSWORD`, logs the assigned IP. If SSID is blank, logs a notice
   and skips — the board still passes the alive-check without WiFi configured.

### WiFi credentials (Kconfig)
`Kconfig.projbuild` defines `WIFI_SSID`, `WIFI_PASSWORD`, `BLINK_GPIO`. Set via
`idf.py menuconfig`; values land in `sdkconfig`, which is gitignored.
`sdkconfig.defaults` holds non-secret defaults.

## Data / Control Flow

```
power on
  └─ app_main()
       ├─ print_chip_info()          # synchronous, logs to UART
       ├─ start_blink_task()         # FreeRTOS task, configurable GPIO
       └─ wifi_init_sta()            # connects if SSID set, logs IP; else skips
```

## Chip Auto-Detection Flow

```
plug board in
  → scripts/detect-chip.sh     # e.g. reports "esp32s3"
  → idf.py set-target esp32s3
  → idf.py flash monitor
```

## Error Handling

- **Blank WiFi SSID:** skip WiFi init, log a notice. Not an error.
- **WiFi connect failure:** retry a bounded number of times, then log failure and
  continue (blink + chip info still work).
- **`setup-idf.sh` re-run:** idempotent; skips clone if `~/esp/esp-idf` exists.
- **No board connected at flash time:** ESP-IDF/esptool surfaces the port error;
  README documents `detect-chip.sh` and port selection.

## Git

Repo initialized at `/Users/jmilo/src/esp32`. `.gitignore` excludes `build/` and
`sdkconfig` (keeps `sdkconfig.defaults`). Initial commit includes scripts, the
`boardtest` project, README, and this spec.

## Verification

- `idf.py build` succeeds in `boardtest/` (after `idf.py set-target <chip>`).
- With a board attached, `idf.py flash monitor` shows chip info, a blinking LED,
  and (if creds set) a WiFi IP.

## Out of Scope (for now)

- Concrete sensor drivers (the `components/` dir is scaffolding only).
- Multi-project monorepo layout (single project for now; can grow later).
- OTA, provisioning, deep-sleep, or production firmware concerns.
