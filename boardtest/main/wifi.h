#pragma once

#include <stdbool.h>

// Connects as a station to CONFIG_WIFI_SSID. If the SSID is empty, logs a
// notice and returns false without starting WiFi. Returns true if a connection
// (and IP) was obtained within CONFIG_WIFI_MAX_RETRY attempts.
bool wifi_connect(void);
