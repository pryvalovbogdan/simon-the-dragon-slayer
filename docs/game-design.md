# Game design

## Loop

The hero runs automatically. The level scrolls toward him at the level's speed.

| Input | Action |
| --- | --- |
| Tap (left 62% of the screen) | Jump. Hold for a higher jump; release early for a short hop. |
| Tap again in the air | Double jump (hero level 3+). |
| Tap the right side | Fireball (hero level 2+). |
| Hold the right side, then release | Charged fireball: 3 damage (hero level 4). |

Three hearts. A hit costs one and gives 1.2 s of immunity (the hero blinks). Zero hearts ends the run.
Landing on top of a goblin, wolf, hound or archer is safe: the hero bounces off, but the enemy is
not hurt and gives no XP. Only fireballs defeat enemies.

## Progression

XP comes from coins (5), enemies burned with fireballs (10–40) and is topped up by shrines and bosses.

| Hero level | XP | Unlocks |
| --- | --- | --- |
| 1 | 0 | — |
| 2 | 100 | Fireball |
| 3 | 300 | Double jump |
| 4 | 600 | Charged fireball |

Abilities a level needs are **guaranteed**, never left to how many coins the player picked up:
level 1 has a shrine that raises the hero to level 2 before the boss, and each boss raises the hero
to the level the next stage assumes (`bossRewardLevel` → next level's `entryHeroLevel`). Coins and
kills only get you there sooner. XP is saved when a level is cleared.

## Obstacles and enemies

| Id | Behaviour | Beat it by |
| --- | --- | --- |
| `tree` | Static, 24 high | Jump (fireballs pass through it) |
| `root` | Static, low | Hop |
| `thorns` | Static, low and wide | A full jump (fireballs pass through it) |
| `goblin` | Walks toward the hero | Jump or bounce over it, or burn |
| `wolf` | Fast ground runner, 2 HP | Jump or bounce over it, or 2 fireballs |
| `skeleton` | Slow walker with a raised blade, 2 HP | Jump clear (landing on it hurts), or 2 fireballs |
| `ghost` | Drifts in overhead, then swoops to the ground when close | Jump clear of it late; fireballs pass through and landing on it hurts |
| `giant` | Slow, 56 high, 3 HP | 3 fireballs, or a double jump |
| `icicle` | Hangs just above head height | Stay on the ground |
| `archer` | Stands and shoots low arrows | Jump the arrows; bounce over it or burn (2 HP) |
| `hound` | Fast ground runner | Jump or bounce over it, or burn |
| `raven` | Flies just above head height | Stay on the ground (a jumping fireball also works) |
| `coin` | +5 XP | — |
| `shrine` | Raises the hero to the level's `shrineLevel` | Cannot be missed |

## Levels and bosses

During a boss fight the world keeps scrolling and the boss stays ahead of the hero (210 units in
landscape, 170 in portrait where less fits on screen; levels are validated at both). Every boss
attack is one of two shapes: **low** (jump it) or **high** (stay down). Attacks are announced by a
wind-up animation; ground strikes that appear ahead blink before they can hurt.

| # | Theme | Speed | Boss | Twist |
| --- | --- | --- | --- | --- |
| 1 | forest | 110 | `boss_giant` | Always vulnerable. Shockwaves (low) and boulders (high). |
| 2 | mountain | 120 | `boss_dragon` | Only vulnerable while recovering after an attack. |
| 3 | wastes | 130 | `boss_queen` | Summons hounds and ravens that soak up fireballs. |
| 4 | tower | 140 | `boss_stormking` | Only charged fireballs hurt, and only while recovering. |

Bosses change attack pattern as their health drops (`phases` in `Bosses.json`).

## Names

All display text comes from `App/Resources/Lore.json`, keyed by role id.
