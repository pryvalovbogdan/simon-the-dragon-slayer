---
name: check
description: Run every automated check - game rules, level solvability, art tests and a simulator build. Use before reporting work as done and before committing.
---

# /check

Run `Tools/check.sh`. It runs, in order:

1. `swift test` on GameCore — rules, and every level cleared by the bot on a single heart.
2. `pytest Tools/sprites/tests` — sprites match the spec, are deterministic, and the committed
   atlas and `Sprites.json` match the drawing code (a failure here usually means `build.py`
   was not rerun).
3. `xcodegen` + `xcodebuild` for the iOS simulator.

Report failures with their output. Do not call work verified if a step failed or was skipped;
for anything visual also run `/play` and look at the screenshots.
