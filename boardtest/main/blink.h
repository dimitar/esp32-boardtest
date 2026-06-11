#pragma once

// Starts a FreeRTOS task that toggles CONFIG_BLINK_GPIO at ~1 Hz.
void blink_start(void);
