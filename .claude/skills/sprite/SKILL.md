---
name: sprite
description: Regenerate one or more sprites (or all) with the code art pipeline and review the result. Use after editing anything in Tools/sprites/, or when asked to change how a character, enemy, boss, hazard or background looks or animates.
---

# /sprite [name ...]

1. Edit the drawing code in `Tools/sprites/characters/<module>.py` if a change was asked for.
   Read `docs/sprite-spec.md` first; frame counts and sizes there are enforced by tests.
2. Build: `Tools/.venv/bin/python Tools/sprites/build.py <name ...>` (no name = everything,
   which also regenerates the app icon).
3. Look at the result before saying anything about it: Read
   `Tools/sprites/out/contact/<name>.png` (every animation as rows of frames). GIFs are in
   `Tools/sprites/out/preview/` for the user to open.
4. Check each frame: nothing clipped at the frame edge, feet on the same ground line, the
   silhouette readable at 1×, facing the right way (enemies face left in the contact sheet).
5. Run `Tools/.venv/bin/python -m pytest -q Tools/sprites/tests`.

Never edit PNGs or `Sprites.json` by hand. Never use `random` — use `draw.noise(seed)` so output
stays byte-identical. If a frame count or size changes, update `docs/sprite-spec.md`, the `SPEC`
table in `Tools/sprites/tests/test_sprites.py` and any animation names used in
`App/Scenes/GameScene.swift` together.
