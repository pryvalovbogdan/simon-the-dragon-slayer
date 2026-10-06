---
name: play
description: Build the game, run it in the iPhone simulator and capture screenshots, optionally with the bot playing a level. Use to see a change in the real app or when asked to run, launch or screenshot the game.
---

# /play [level] [seconds ...]

- `Tools/run-sim.sh` — builds, installs, launches, screenshots the menu.
- `Tools/run-sim.sh endless 60` — the bot plays an endless run (levels back to back, faster each loop).
- `Tools/run-sim.sh 2 12 41` — launches level 2 with the validator bot playing (`-autoplay`,
  Debug builds only) and takes screenshots 12 s and 41 s after launch.

Prefix with `ORIENT=portrait` for the upright layout (default `landscape`); check both for
anything visual. Screenshots land in `.build/screens/`; Read them and describe what is actually on screen.
A level reaches its boss after about `length / speed` seconds (33–36 s for the shipped levels).

Set `SIM_DEVICE=<udid>` to pick a simulator (`xcrun simctl list devices available`); the
default is the last iPhone listed. If `xcodebuild` says no matching destination, pass a UDID.

Autoplay proves rendering and the rules, not touch input: tapping, holding to charge and the
pause button need a person in the simulator or on a device. Say so when reporting.
