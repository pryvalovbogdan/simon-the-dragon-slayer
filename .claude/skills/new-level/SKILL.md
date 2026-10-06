---
name: new-level
description: Create or rework a level file and prove it is beatable. Use when asked to add a level, change obstacle placement or difficulty, or add or retune a boss pattern.
---

# /new-level <number>

Read `docs/level-format.md` first.

1. Create `App/Resources/Levels/level_<NN>.json` (two digits; files load in name order).
   - `entryHeroLevel` must not exceed the highest `bossRewardLevel` of earlier levels.
   - Leave 150 units clear at the start and 60 before `length`.
   - Things to run under (icicle, raven, high boss hazards) sit at y 42+; the hero is 32 tall.
   - Start around 110+ units between ground threats and tighten from there.
2. Add the level's `nameKey` (and a new boss's `<id>.name`) to `App/Resources/Lore.json`.
3. A new theme needs four sprites (`bg_<theme>_sky|far|near`, `ground_<theme>`) in
   `Tools/sprites/characters/scenery.py`. A new boss needs an entry in `Bosses.json`, a sprite
   named like its id, lore keys `<id>.name`, and an entry in `GameScene.attackAnimation`.
4. Validate: `swift test --package-path Packages/GameCore`. A failure such as
   `no-hit bot failed at distance 2310 (dead)` names where the unfair spot is; a distance past
   `length` means the boss pattern. Fix the content and rerun.
5. Watch it: `Tools/run-sim.sh <number> 10 25 40` and Read the screenshots.

The validator proves a perfect run exists; it does not prove the level is fun. Say which you
checked.
