#!/bin/bash
# Everything that can be verified without a human: game rules, level solvability, art, and an app build.
set -uo pipefail
cd "$(dirname "$0")/.."
FAILED=0
run() { echo "── $1"; shift; if "$@"; then echo "   ok"; else echo "   FAILED"; FAILED=1; fi; }

run "game rules + every level beatable without a hit (swift test)" \
  bash -c 'set -o pipefail; swift test --package-path Packages/GameCore 2>&1 | grep -E "✘|error:|Test run with"'
run "sprites match spec, are deterministic and up to date (pytest)" \
  Tools/.venv/bin/python -m pytest -q Tools/sprites/tests
run "app builds for the simulator" \
  bash -c 'xcodegen generate >/dev/null && xcodebuild -project SimonTheDragonSlayer.xcodeproj -scheme SimonTheDragonSlayer -configuration Debug \
    -destination "generic/platform=iOS Simulator" -derivedDataPath .build/xcode build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; \
    [ "${PIPESTATUS[0]}" = 0 ]'
exit $FAILED
