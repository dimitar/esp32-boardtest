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
