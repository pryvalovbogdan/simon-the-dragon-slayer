---
name: new-enemy
description: Add a new enemy or obstacle type to the game end to end - rules, sprite, rendering, docs and tests. Use when asked for a new kind of enemy, obstacle or pickup.
---

# /new-enemy <id>

`<id>` is a neutral lower-case role id (`wolf`, not a character name).

1. **Rules** — `Packages/GameCore/Sources/GameCore/Items.swift`: add the `ItemKind` case and its
   `ItemSpec` (hitbox, `baseY`, hp, xp, velocity, `stompable`, `burnable`, `minHeroLevel`).
   Special behaviour (like the archer's arrows) goes in `RunnerWorld.moveEntities`. Add a test
   in `WorldTests.swift` for whatever is new about it.
2. **Sprite** — add `build()` output named exactly `<id>` in `Tools/sprites/characters/` with
   `faces_left=True`, `cx`/`ground` set, and at least a looping default animation plus `death`.
   Run `/sprite <id>` and review it.
3. **Rendering** — `App/Scenes/GameScene.swift`: add the default animation to
   `defaultAnimation`.
4. **Docs and spec** — row in `docs/game-design.md`, row in `docs/sprite-spec.md`, entry in
   `SPEC` in `Tools/sprites/tests/test_sprites.py`, kind listed in `docs/level-format.md`.
5. Place it in a level (`/new-level` or edit an existing one) and run `/check`. The bot must
   still clear every level on one heart; if it cannot, the enemy's numbers are unfair - tune the
   spec, do not loosen the validator.
