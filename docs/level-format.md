# Level and boss data

## `App/Resources/Levels/level_NN.json`

Files are loaded in file-name order; adding `level_05.json` adds a fifth level with no code change.

```json
{
  "id": "level_01",
  "nameKey": "level.1.name",
  "background": "forest",
  "speed": 110,
  "length": 3600,
  "entryHeroLevel": 1,
  "shrineLevel": 2,
  "boss": "boss_giant",
  "bossRewardLevel": 3,
  "ravines": [{ "at": 1420, "width": 30 }],
  "items": [{ "at": 420, "kind": "root" }, { "at": 704, "kind": "coin", "y": 30 }]
}
```

| Field | Meaning |
| --- | --- |
| `nameKey` | Key in `App/Resources/Lore.json` holding the display name |
| `background` | Theme: needs sprites `bg_<theme>_sky`, `_clouds`, `_puffs`, `_far`, `_near`, `_bushes` and `ground_<theme>` |
| `speed` | World units per second |
| `length` | Distance at which the boss appears |
| `entryHeroLevel` | Hero level the player is guaranteed on entry; must not exceed what earlier bosses grant |
| `shrineLevel` | Hero level granted by a `shrine` item (required if one is placed) |
| `bossRewardLevel` | Hero level granted for beating the boss |
| `items[].at` | Distance from the start. Keep 150 clear at the start and 60 before `length` |
| `items[].kind` | An `ItemKind`: tree, root, thorns, goblin, wolf, skeleton, ghost, giant, icicle, archer, hound, raven, coin, shrine |
| `items[].y` | Optional height above ground (coin arcs) |
| `ravines[]` | Optional gaps in the ground: `at` is the left rim, `width` how far it spans. Needs sprites `ravine_<theme>` and `ravine_<theme>_fill` |

Useful numbers: a full jump is 50 high and lasts 0.67 s, so it covers `speed × 0.67` units
(≈ 74 at speed 110). A tap hop is about 10 high. Leave roughly 110+ units between ground threats.

Ravines: a fall ends the run, so the validator caps `width` at 65% of a full jump's reach (47 at
speed 110, 60 at 140) and wants at least 16. Keep them out of the start runway and the last 60
units, leave 40 of ground between two of them, and put nothing that stands on the ground inside
one (coins above are fine). Walking enemies turn back at a rim, so one placed between two ravines
patrols the ledge. To have a walker turn where the player can watch, start it far enough from the
rim that it arrives about two seconds after it spawns (a goblin about 45 units, a hound about 90).

## `App/Resources/Bosses.json`

```json
{
  "id": "boss_giant", "hp": 20, "width": 56, "height": 84, "baseY": 0,
  "vulnerable": "always", "requiresCharged": false,
  "attacks": [{
    "name": "slam", "telegraph": 0.8, "duration": 0.6, "recover": 0.8,
    "hazards": [{ "kind": "shockwave", "delay": 0, "y": 0, "width": 16, "height": 10, "closingSpeed": 150 }]
  }],
  "phases": [{ "startsBelow": 1, "attacks": ["slam"] }]
}
```

- `vulnerable`: `always`, or `recover` (damage only lands in the pause after an attack).
- An attack runs `telegraph` → `duration` (hazards and `summons` spawn at their `delay`) → `recover`.
- Hazard `y` is its bottom edge: `0` makes a low hazard to jump, `42` a high one to run under
  (the hero's hitbox is 14 wide and 32 tall, so anything below 32 hits him standing).
- `closingSpeed` is how fast it approaches on screen. With `ahead` the hazard appears that far in
  front of the hero instead of at the boss; set `closingSpeed` to the level speed to pin it to the
  ground, and `arm` to the seconds it blinks as a warning first.
- `phases` are ordered by falling `startsBelow` (HP fraction); the first must be `1`.
- Each hazard `kind` needs a sprite `hazard_<kind>`; each boss a sprite named like its `id` with
  `idle` and `death`, plus attack animations mapped in `GameScene.attackAnimation`.

## Validation

`swift test --package-path Packages/GameCore` runs `LevelValidator` on every level file: static
checks (runway, abilities guaranteed where needed, ravines, boss and attack names resolve) and then a bot
that must finish the level and boss **on a single heart**. A failure reports the distance at which
the bot was hit, e.g. `no-hit bot failed at distance 4431 (dead)` — a distance past `length` means
the boss pattern is the problem.
