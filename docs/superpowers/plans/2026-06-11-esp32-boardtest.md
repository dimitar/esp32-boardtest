# ESP32 Board-Test Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an ESP-IDF v5.5.4 repo that installs the toolchain and provides a `boardtest` project which confirms a board is alive (chip info + blink) and connects to WiFi, with a clean structure for adding sensor tests later.

**Architecture:** A single ESP-IDF project (`boardtest/`) whose `main` component orchestrates three independent modules — chip-info (inline), `blink` (FreeRTOS task), and `wifi` (station, optional). WiFi creds and the blink GPIO are Kconfig options stored in a gitignored `sdkconfig`. Helper scripts handle the one-time IDF install, per-shell activation, and per-board chip detection. The build is target-agnostic (`idf.py set-target <chip>` chosen per board).

**Tech Stack:** ESP-IDF v5.5.4, C, CMake, FreeRTOS, esptool.py, bash.

**Validator note (firmware):** There is no host unit-test harness here. The objective validators are: (a) `idf.py build` compiles cleanly, and (b) on-device `idf.py flash monitor` shows the expected serial output. Each code task ends in a build check; the final task is the on-device check.

---

## File Structure

- `.gitignore` — ignore `build/`, `sdkconfig`, `sdkconfig.old`, `managed_components/`; keep `sdkconfig.defaults`.
- `scripts/setup-idf.sh` — idempotent ESP-IDF v5.5.4 install to `~/esp/esp-idf`.
- `scripts/env.sh` — sources `~/esp/esp-idf/export.sh` to put `idf.py` on PATH.
- `scripts/detect-chip.sh` — reads the connected board, prints chip, suggests `set-target`.
- `boardtest/CMakeLists.txt` — project-level CMake (includes IDF project.cmake).
- `boardtest/sdkconfig.defaults` — non-secret build defaults.
- `boardtest/main/CMakeLists.txt` — registers `main` component sources.
- `boardtest/main/Kconfig.projbuild` — `WIFI_SSID`, `WIFI_PASSWORD`, `BLINK_GPIO`, `WIFI_MAX_RETRY`.
- `boardtest/main/chip_info.h` / `chip_info.c` — print chip details.
- `boardtest/main/blink.h` / `blink.c` — blink task.
- `boardtest/main/wifi.h` / `wifi.c` — station connect, optional.
- `boardtest/main/main.c` — `app_main()` orchestration.
- `boardtest/components/README.md` — scaffold placeholder for sensor drivers.
- `README.md` — setup, detect, build, flash instructions.

---

## Task 1: Repo scaffolding and .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# ESP-IDF build artifacts
build/
sdkconfig
sdkconfig.old
managed_components/
dependencies.lock

# macOS
.DS_Store
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for ESP-IDF artifacts"
```

---

## Task 2: ESP-IDF install script

**Files:**
- Create: `scripts/setup-idf.sh`

- [ ] **Step 1: Write `scripts/setup-idf.sh`**

```bash
#!/usr/bin/env bash
# One-time ESP-IDF v5.5.4 install. Idempotent: safe to re-run.
set -euo pipefail

IDF_VERSION="v5.5.4"
IDF_PATH="${HOME}/esp/esp-idf"

# macOS prerequisites (no-op if already installed)
if command -v brew >/dev/null 2>&1; then
  brew list ninja    >/dev/null 2>&1 || brew install ninja
  brew list dfu-util >/dev/null 2>&1 || brew install dfu-util
fi

mkdir -p "${HOME}/esp"

if [ ! -d "${IDF_PATH}/.git" ]; then
  echo "Cloning ESP-IDF ${IDF_VERSION} to ${IDF_PATH} ..."
  git clone -b "${IDF_VERSION}" --depth 1 --recursive --shallow-submodules \
    https://github.com/espressif/esp-idf.git "${IDF_PATH}"
else
  echo "ESP-IDF already present at ${IDF_PATH}, skipping clone."
fi

# Install tools for all supported targets (chip variant is unknown).
( cd "${IDF_PATH}" && ./install.sh all )

echo "ESP-IDF ${IDF_VERSION} installed. Run 'source scripts/env.sh' to activate."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/setup-idf.sh
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n scripts/setup-idf.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/setup-idf.sh
git commit -m "feat: add idempotent ESP-IDF install script"
```

---

## Task 3: Environment activation script

**Files:**
- Create: `scripts/env.sh`

- [ ] **Step 1: Write `scripts/env.sh`**

```bash
#!/usr/bin/env bash
# Source this (do NOT execute) to put idf.py on PATH:  source scripts/env.sh
IDF_PATH="${HOME}/esp/esp-idf"
if [ ! -f "${IDF_PATH}/export.sh" ]; then
  echo "ESP-IDF not found at ${IDF_PATH}. Run scripts/setup-idf.sh first." >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck disable=SC1091
. "${IDF_PATH}/export.sh"
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n scripts/env.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add scripts/env.sh
git commit -m "feat: add env.sh to activate idf.py per shell"
```

---

## Task 4: Chip detection script

**Files:**
- Create: `scripts/detect-chip.sh`

- [ ] **Step 1: Write `scripts/detect-chip.sh`**

```bash
#!/usr/bin/env bash
# Detect the connected ESP32 chip and suggest the matching set-target.
# Requires an activated IDF env (run: source scripts/env.sh) so esptool.py is on PATH.
set -euo pipefail

if ! command -v esptool.py >/dev/null 2>&1; then
  echo "esptool.py not found. Run 'source scripts/env.sh' first." >&2
  exit 1
fi

PORT="${1:-}"
PORT_ARG=()
[ -n "${PORT}" ] && PORT_ARG=(--port "${PORT}")

echo "Detecting chip (plug in exactly one board)..."
# chip_id output includes a 'Detecting chip type... <CHIP>' line.
OUT="$(esptool.py "${PORT_ARG[@]}" chip_id 2>&1)" || { echo "$OUT" >&2; exit 1; }
echo "$OUT"

CHIP="$(printf '%s\n' "$OUT" | grep -iE 'Detecting chip type' | tail -1 | sed -E 's/.*\.\.\.[[:space:]]*//' )"
case "$(printf '%s' "$CHIP" | tr 'A-Z ' 'a-z-')" in
  *esp32-s3*) TARGET=esp32s3 ;;
  *esp32-s2*) TARGET=esp32s2 ;;
  *esp32-c3*) TARGET=esp32c3 ;;
  *esp32-c6*) TARGET=esp32c6 ;;
  *esp32-h2*) TARGET=esp32h2 ;;
  *esp32*)    TARGET=esp32 ;;
  *)          TARGET="" ;;
esac

if [ -n "$TARGET" ]; then
  echo ""
  echo "Detected: ${CHIP}"
  echo "Next:  cd boardtest && idf.py set-target ${TARGET} && idf.py flash monitor"
else
  echo "Could not map chip to a target automatically; see output above." >&2
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/detect-chip.sh
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n scripts/detect-chip.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/detect-chip.sh
git commit -m "feat: add chip detection helper"
```

---

## Task 5: boardtest project skeleton + Kconfig

**Files:**
- Create: `boardtest/CMakeLists.txt`
- Create: `boardtest/sdkconfig.defaults`
- Create: `boardtest/main/CMakeLists.txt`
- Create: `boardtest/main/Kconfig.projbuild`

- [ ] **Step 1: Write `boardtest/CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(boardtest)
```

- [ ] **Step 2: Write `boardtest/sdkconfig.defaults`**

```
# Non-secret build defaults. Secrets (WiFi creds) are set via menuconfig
# and live in the gitignored sdkconfig.
CONFIG_ESPTOOLPY_FLASHSIZE_4MB=y
```

- [ ] **Step 3: Write `boardtest/main/CMakeLists.txt`**

```cmake
idf_component_register(
    SRCS "main.c" "chip_info.c" "blink.c" "wifi.c"
    INCLUDE_DIRS "."
)
```

- [ ] **Step 4: Write `boardtest/main/Kconfig.projbuild`**

```
menu "Board Test Configuration"

    config WIFI_SSID
        string "WiFi SSID"
        default ""
        help
            SSID of the AP to connect to. Leave blank to skip WiFi at boot.

    config WIFI_PASSWORD
        string "WiFi Password"
        default ""
        help
            Password of the AP. Ignored if SSID is blank.

    config WIFI_MAX_RETRY
        int "WiFi maximum connect retries"
        default 5
        help
            Number of reconnect attempts before giving up (board keeps running).

    config BLINK_GPIO
        int "Blink LED GPIO number"
        default 2
        help
            GPIO connected to the onboard LED. Common: 2 (WROOM), 48 (many S3),
            8 (many C3). Adjust per board.

endmenu
```

- [ ] **Step 5: Commit**

```bash
git add boardtest/CMakeLists.txt boardtest/sdkconfig.defaults boardtest/main/CMakeLists.txt boardtest/main/Kconfig.projbuild
git commit -m "feat: add boardtest project skeleton and Kconfig"
```

---

## Task 6: chip_info module

**Files:**
- Create: `boardtest/main/chip_info.h`
- Create: `boardtest/main/chip_info.c`

- [ ] **Step 1: Write `boardtest/main/chip_info.h`**

```c
#pragma once

// Logs chip model, cores, silicon revision, flash size, and base MAC over UART.
void chip_info_print(void);
```

- [ ] **Step 2: Write `boardtest/main/chip_info.c`**

```c
#include "chip_info.h"

#include <inttypes.h>
#include "esp_chip_info.h"
#include "esp_flash.h"
#include "esp_mac.h"
#include "esp_log.h"

static const char *TAG = "chip_info";

void chip_info_print(void)
{
    esp_chip_info_t info;
    esp_chip_info(&info);

    const char *model;
    switch (info.model) {
        case CHIP_ESP32:   model = "ESP32";    break;
        case CHIP_ESP32S2: model = "ESP32-S2"; break;
        case CHIP_ESP32S3: model = "ESP32-S3"; break;
        case CHIP_ESP32C3: model = "ESP32-C3"; break;
        case CHIP_ESP32C6: model = "ESP32-C6"; break;
        case CHIP_ESP32H2: model = "ESP32-H2"; break;
        default:           model = "unknown";  break;
    }

    uint32_t flash_size = 0;
    if (esp_flash_get_size(NULL, &flash_size) != ESP_OK) {
        flash_size = 0;
    }

    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_STA);

    ESP_LOGI(TAG, "Chip: %s, cores: %d, revision: %d.%d",
             model, info.cores,
             info.revision / 100, info.revision % 100);
    ESP_LOGI(TAG, "Flash: %" PRIu32 " MB", flash_size / (1024 * 1024));
    ESP_LOGI(TAG, "WiFi STA MAC: %02x:%02x:%02x:%02x:%02x:%02x",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}
```

- [ ] **Step 3: Commit**

```bash
git add boardtest/main/chip_info.h boardtest/main/chip_info.c
git commit -m "feat: add chip_info module"
```

---

## Task 7: blink module

**Files:**
- Create: `boardtest/main/blink.h`
- Create: `boardtest/main/blink.c`

- [ ] **Step 1: Write `boardtest/main/blink.h`**

```c
#pragma once

// Starts a FreeRTOS task that toggles CONFIG_BLINK_GPIO at ~1 Hz.
void blink_start(void);
```

- [ ] **Step 2: Write `boardtest/main/blink.c`**

```c
#include "blink.h"

#include "sdkconfig.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "blink";

static void blink_task(void *arg)
{
    const gpio_num_t pin = (gpio_num_t)CONFIG_BLINK_GPIO;
    gpio_reset_pin(pin);
    gpio_set_direction(pin, GPIO_MODE_OUTPUT);

    bool on = false;
    while (1) {
        on = !on;
        gpio_set_level(pin, on);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void blink_start(void)
{
    ESP_LOGI(TAG, "Blinking GPIO %d", CONFIG_BLINK_GPIO);
    xTaskCreate(blink_task, "blink", 2048, NULL, 5, NULL);
}
```

- [ ] **Step 3: Commit**

```bash
git add boardtest/main/blink.h boardtest/main/blink.c
git commit -m "feat: add blink module"
```

---

## Task 8: wifi module

**Files:**
- Create: `boardtest/main/wifi.h`
- Create: `boardtest/main/wifi.c`

- [ ] **Step 1: Write `boardtest/main/wifi.h`**

```c
#pragma once

#include <stdbool.h>

// Connects as a station to CONFIG_WIFI_SSID. If the SSID is empty, logs a
// notice and returns false without starting WiFi. Returns true if a connection
// (and IP) was obtained within CONFIG_WIFI_MAX_RETRY attempts.
bool wifi_connect(void);
```

- [ ] **Step 2: Write `boardtest/main/wifi.c`**

```c
#include "wifi.h"

#include <string.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_log.h"
#include "nvs_flash.h"

static const char *TAG = "wifi";

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

static EventGroupHandle_t s_wifi_events;
static int s_retry_count;

static void event_handler(void *arg, esp_event_base_t base,
                          int32_t id, void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_retry_count < CONFIG_WIFI_MAX_RETRY) {
            s_retry_count++;
            ESP_LOGI(TAG, "Retrying connect (%d/%d)",
                     s_retry_count, CONFIG_WIFI_MAX_RETRY);
            esp_wifi_connect();
        } else {
            xEventGroupSetBits(s_wifi_events, WIFI_FAIL_BIT);
        }
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)data;
        ESP_LOGI(TAG, "Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_count = 0;
        xEventGroupSetBits(s_wifi_events, WIFI_CONNECTED_BIT);
    }
}

bool wifi_connect(void)
{
    if (strlen(CONFIG_WIFI_SSID) == 0) {
        ESP_LOGW(TAG, "WIFI_SSID is empty; skipping WiFi. Set it via 'idf.py menuconfig'.");
        return false;
    }

    esp_err_t nvs = nvs_flash_init();
    if (nvs == ESP_ERR_NVS_NO_FREE_PAGES || nvs == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    s_wifi_events = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL, NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL, NULL));

    wifi_config_t wifi_config = { 0 };
    strncpy((char *)wifi_config.sta.ssid, CONFIG_WIFI_SSID,
            sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char *)wifi_config.sta.password, CONFIG_WIFI_PASSWORD,
            sizeof(wifi_config.sta.password) - 1);

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "Connecting to SSID '%s'...", CONFIG_WIFI_SSID);

    EventBits_t bits = xEventGroupWaitBits(
        s_wifi_events, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
        pdFALSE, pdFALSE, portMAX_DELAY);

    if (bits & WIFI_CONNECTED_BIT) {
        ESP_LOGI(TAG, "Connected.");
        return true;
    }
    ESP_LOGE(TAG, "Failed to connect after %d retries.", CONFIG_WIFI_MAX_RETRY);
    return false;
}
```

- [ ] **Step 3: Commit**

```bash
git add boardtest/main/wifi.h boardtest/main/wifi.c
git commit -m "feat: add wifi station module"
```

---

## Task 9: app_main orchestration

**Files:**
- Create: `boardtest/main/main.c`

- [ ] **Step 1: Write `boardtest/main/main.c`**

```c
#include "chip_info.h"
#include "blink.h"
#include "wifi.h"

#include "esp_log.h"

static const char *TAG = "boardtest";

void app_main(void)
{
    ESP_LOGI(TAG, "=== ESP32 board test ===");
    chip_info_print();
    blink_start();
    wifi_connect();
    ESP_LOGI(TAG, "Setup complete; blink task running.");
}
```

- [ ] **Step 2: Commit**

```bash
git add boardtest/main/main.c
git commit -m "feat: add app_main orchestration"
```

---

## Task 10: components scaffold placeholder

**Files:**
- Create: `boardtest/components/README.md`

- [ ] **Step 1: Write `boardtest/components/README.md`**

```markdown
# Components

Drop reusable peripheral / sensor drivers here, one directory per component.
Each needs its own `CMakeLists.txt` with `idf_component_register(...)`; ESP-IDF
picks it up automatically.

Example skeleton for a new `bme280` driver:

```
components/bme280/
├── CMakeLists.txt        # idf_component_register(SRCS "bme280.c" INCLUDE_DIRS ".")
├── bme280.c
└── bme280.h
```

Then `#include "bme280.h"` from `main/` and add `bme280` to the `main`
component's `REQUIRES` if needed.
```

- [ ] **Step 2: Commit**

```bash
git add boardtest/components/README.md
git commit -m "docs: add components scaffold placeholder"
```

---

## Task 11: Build verification

**Files:** none (validation only). Requires the background IDF install to have finished.

- [ ] **Step 1: Activate IDF**

Run: `source scripts/env.sh`
Expected: prints ESP-IDF environment info, `idf.py` now on PATH.

- [ ] **Step 2: Set a target and build**

Run: `cd boardtest && idf.py set-target esp32 && idf.py build`
Expected: ends with `Project build complete.` and a `boardtest.bin` path. (Target is provisional; the real per-board target comes from `detect-chip.sh`.)

- [ ] **Step 3: Commit any generated tracked defaults if changed**

```bash
git add -A boardtest/sdkconfig.defaults
git commit -m "chore: build verification (esp32 target)" || echo "nothing to commit"
```

---

## Task 12: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

````markdown
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
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with setup and flash instructions"
```

---

## Task 13: On-device verification (requires a board)

**Files:** none (validation only).

- [ ] **Step 1: Detect the chip**

```bash
source scripts/env.sh
./scripts/detect-chip.sh
```
Expected: prints the chip and the exact `set-target` to run.

- [ ] **Step 2: Set target, configure, flash, monitor**

```bash
cd boardtest
idf.py set-target <detected-chip>
idf.py menuconfig    # set blink GPIO for this board; optionally WiFi creds
idf.py flash monitor
```
Expected: serial log shows chip info, `Blinking GPIO N`, the onboard LED toggles
~1 Hz, and either `Got IP: <addr>` or the "WIFI_SSID is empty" notice.

- [ ] **Step 3: Confirm and report**

Confirm the LED physically blinks and the chip info matches the board. Report
the detected chip and correct LED GPIO back so defaults can be noted if useful.
