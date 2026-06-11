# ESP32 Board Test

ESP-IDF v5.5.4 repo for confirming new ESP32 boards work: chip info, blink, and
optional WiFi. Build is target-agnostic — detect the chip per board, then set
the matching target.

## One-time setup

```bash
./scripts/setup-idf.sh        # installs ESP-IDF v5.5.4 to ~/esp/esp-idf (~10-20 min)
```

## Each terminal

```bash
source scripts/env.sh         # puts idf.py on PATH
```

## Per board

```bash
source scripts/env.sh
./scripts/detect-chip.sh           # prints chip + the set-target to run
cd boardtest
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

## Adding sensor tests

See `boardtest/components/README.md`.
