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
