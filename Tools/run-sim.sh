#!/bin/bash
# Builds the app, installs it on an iPhone simulator, launches it and saves screenshots.
# Usage: [ORIENT=landscape|portrait] Tools/run-sim.sh [level number or "endless" for bot autoplay] [seconds ...]
#   Tools/run-sim.sh              -> menu screenshot
#   Tools/run-sim.sh 1 4 20 40    -> level 1 played by the bot, shots after 4 s, 20 s and 40 s
#   Tools/run-sim.sh endless 60   -> an endless run played by the bot, shot after 60 s
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${SIM_DEVICE:-$(xcrun simctl list devices available | grep -E '^\s+iPhone' | tail -1 | grep -oE '[0-9A-F-]{36}')}"
OUT=.build/screens
ORIENT="${ORIENT:-landscape}"
mkdir -p "$OUT"

xcodegen generate >/dev/null
xcodebuild -project SimonTheDragonSlayer.xcodeproj -scheme SimonTheDragonSlayer -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath .build/xcode build \
  2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)' || true
APP=.build/xcode/Build/Products/Debug-iphonesimulator/SimonTheDragonSlayer.app
[ -d "$APP" ] || { echo "build failed: $APP missing"; exit 1; }

xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl terminate "$DEVICE" com.example.simonthedragonslayer 2>/dev/null || true

LEVEL="${1:-}"
if [ -n "$LEVEL" ]; then
  shift
  xcrun simctl launch "$DEVICE" com.example.simonthedragonslayer -autoplay "$LEVEL" -orientation "$ORIENT" >/dev/null
  PREVIOUS=0
  for AT in "${@:-4}"; do
    sleep $((AT - PREVIOUS)); PREVIOUS=$AT
    xcrun simctl io "$DEVICE" screenshot "$OUT/level${LEVEL}_${ORIENT}_${AT}s.png" >/dev/null 2>&1
    echo "$OUT/level${LEVEL}_${ORIENT}_${AT}s.png"
  done
else
  xcrun simctl launch "$DEVICE" com.example.simonthedragonslayer -orientation "$ORIENT" >/dev/null
  sleep 3
  xcrun simctl io "$DEVICE" screenshot "$OUT/menu_${ORIENT}.png" >/dev/null 2>&1
  echo "$OUT/menu_${ORIENT}.png"
fi
