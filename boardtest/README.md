# boardtest — ESP32 bring-up (ESP-IDF)

ESP-IDF v5.5.4 project for confirming a new ESP32 board works: prints chip info,
blinks an LED, and optionally connects to WiFi. Target-agnostic — detect the
chip per board, then set the matching target.

## One-time setup

```bash
../scripts/setup-idf.sh       # installs ESP-IDF v5.5.4 to ~/esp/esp-idf (~10-20 min)
```

## Each terminal

```bash
source ../scripts/env.sh      # puts idf.py on PATH
```

## Per board

```bash
source ../scripts/env.sh
../scripts/detect-chip.sh          # prints chip + the set-target to run
idf.py set-target <chip>           # e.g. esp32, esp32s3, esp32c3
idf.py menuconfig                  # Board Test Configuration: WiFi SSID/pass, blink GPIO
idf.py flash monitor               # flash + watch serial (Ctrl-] to exit)
```

Expected serial output: chip model/cores/flash/MAC, a "Blinking GPIO N" line
(LED toggles ~1 Hz), and either a WiFi IP or a notice that SSID is unset.

## Configuration

Set via `idf.py menuconfig` → **Board Test Configuration**:

- **WiFi SSID / Password** — leave SSID blank to skip WiFi at boot.
- **Blink LED GPIO** — default 2 (WROOM). Common alternatives: 48 (many S3), 8 (many C3).

Values live in `sdkconfig`, which is gitignored — no secrets in source.
`idf.py set-target` regenerates `sdkconfig` from `sdkconfig.defaults`, clearing
these — put non-secret defaults (e.g. the blink GPIO) in `sdkconfig.defaults` to
make them stick.

## Adding sensor tests

See `components/README.md`.
