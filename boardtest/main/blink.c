#include "blink.h"

#include <stdbool.h>
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
