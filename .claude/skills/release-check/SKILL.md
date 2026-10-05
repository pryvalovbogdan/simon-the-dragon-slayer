---
name: release-check
description: Gate before any TestFlight or App Store upload. Builds Release and verifies the bundle id is real, no debug flags ship, and icon, version and privacy manifest are present.
---

# /release-check

Run `Tools/release-check.sh` and report each line.

- **placeholder bundle id** — the owner must set `PRODUCT_BUNDLE_IDENTIFIER` (and the display
  name) in `project.yml` to match their Apple Developer App ID. Do not invent one.
- Also run `/check`.

Not covered here and still needed from the owner: Apple Developer account and signing, App
Store Connect listing and screenshots, age rating, and play-testing on a real device.
