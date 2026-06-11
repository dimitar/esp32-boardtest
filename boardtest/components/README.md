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
