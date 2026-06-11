# Shutters — ESP32 + CC1101 (A-OK 433.92 MHz)

ESPHome controller for A-OK roller-shutter motors (NuStyle-branded) using an
ESP32 and a CC1101 433.92 MHz transceiver, integrated into Home Assistant.

A-OK uses **433.92 MHz OOK/ASK** with a 65-bit framed protocol that is *not* a
secure rolling code, so captured UP/DOWN/STOP frames can be replayed directly.

## Wiring (CC1101 module → ESP32)

**The CC1101 is 3.3 V only — 5 V will permanently destroy it.** Connect VCC to
the ESP32's **3V3** pin, never 5V/VIN.

| CC1101 pin | ESP32 GPIO | Purpose |
|------------|-----------|---------|
| VCC        | 3V3       | Power (3.3 V only!) |
| GND        | GND       | Ground |
| CSN / CS   | GPIO5     | SPI chip select |
| SCK        | GPIO18    | SPI clock |
| MOSI (SI)  | GPIO23    | SPI data in |
| MISO (SO)  | GPIO19    | SPI data out |
| GDO0       | GPIO4     | Transmit data (`remote_transmitter`) |
| GDO2       | GPIO16    | Receive data (`remote_receiver`) |
| ANT        | —         | 433 MHz antenna (don't skip — ~1 m without, 15 m+ with) |

If your ESP32 board reserves any of these pins, change them in the YAML and this
table together.

## Setup

1. Install ESPHome (`pip install esphome`, or the Home Assistant add-on).
2. Create your secrets file:
   ```bash
   cp secrets.yaml.example secrets.yaml   # then edit with your WiFi creds
   ```
   `secrets.yaml` is gitignored.

## Workflow

### 1. Capture your remote
Flash the capture profile, then watch the logs and press a shutter button:
```bash
esphome run capture.yaml
```
Each button press prints a **raw timing list** (microseconds; negative = gap).
Record the list for UP, DOWN, and STOP on each shutter. Confirm it's coming
through at 433.92 MHz; if nothing decodes, the only other A-OK-adjacent
frequency to try is 433.42 MHz (edit `frequency:` in `capture.yaml`).

### 2. Build the control config
```bash
cp shutter.example.yaml shutter.yaml
```
Paste the captured timings into the `open_action` / `close_action` /
`stop_action` `code:` lists, one `cover:` block per shutter. Then:
```bash
esphome run shutter.yaml
```
The shutters appear in Home Assistant as cover entities.

## Advanced: pair as a new remote instead of replaying

Because A-OK frames carry a per-remote ID + checksum, you can also generate a
*new* virtual remote rather than replay the existing one: construct a frame with
your own ID and the computed checksum, put the motor into pairing mode with its
PROGRAM button, and send the pair command within ~10 s. The frame format and
checksum are documented in the akirjavainen/A-OK reference
(https://github.com/akirjavainen/A-OK). Replaying captured codes (above) is
simpler and is the recommended starting point.

## Validate before flashing

```bash
esphome config capture.yaml      # checks the YAML is valid
esphome compile capture.yaml     # full compile without uploading
```
