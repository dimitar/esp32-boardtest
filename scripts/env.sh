#!/usr/bin/env bash
# Source this (do NOT execute) to put idf.py on PATH:  source scripts/env.sh
IDF_PATH="${HOME}/esp/esp-idf"
if [ ! -f "${IDF_PATH}/export.sh" ]; then
  echo "ESP-IDF not found at ${IDF_PATH}. Run scripts/setup-idf.sh first." >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck disable=SC1091
. "${IDF_PATH}/export.sh"
