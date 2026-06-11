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
