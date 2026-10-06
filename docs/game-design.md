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
Landing on top of a goblin, wolf or skeleton defeats it in one go and gives its XP, and the hero
bounces off. Landing on a hound or archer is a safe bounce only: it is not hurt and gives no XP, so
those need fireballs. Running into any of them from the side costs a heart.

## Progression

XP comes from coins (5), enemies burned with fireballs or jumped on (10–40) and is topped up by
shrines and bosses.

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
| `goblin` | Walks toward the hero | Land on it or burn it, or jump over |
| `wolf` | Fast ground runner, 2 HP | Land on it or 2 fireballs, or jump over |
| `skeleton` | Slow walker, 2 HP | Land on it or 2 fireballs, or jump over |
| `ghost` | Drifts in overhead, then swoops to the ground when close | Jump clear of it late; fireballs pass through and landing on it hurts |
| `giant` | Slow, 56 high, 3 HP | 3 fireballs, or a double jump |
| `icicle` | Hangs just above head height | Stay on the ground |
| `archer` | Stands and shoots low arrows | Jump the arrows; bounce over it or burn (2 HP) |
| `hound` | Fast ground runner | Jump or bounce over it, or burn |
| `raven` | Flies just above head height | Stay on the ground (a jumping fireball also works) |
| `coin` | +5 XP | — |
| `shrine` | Raises the hero to the level's `shrineLevel` | Cannot be missed |

Ravines are gaps in the ground. The hero keeps their footing until their middle is past the rim;
after that they fall, and a fall ends the run whatever hearts are left. Jump them — fireballs,
arrows and flying enemies cross freely. Anything that walks (`goblin`, `wolf`, `skeleton`, `giant`,
`hound`) turns around at a rim and heads back the other way, so an enemy on a ledge between two
ravines paces it, and one that has turned runs ahead of the hero until it is caught or burned.
There are no ravines in a boss fight.

## Levels and bosses

During a boss fight the world keeps scrolling and the boss stays ahead of the hero (210 units in
landscape, 140 in portrait where less fits on screen; levels are validated at both). Every boss
attack is one of two shapes: **low** (jump it) or **high** (stay down). Attacks are announced by a
wind-up animation; ground strikes that appear ahead blink before they can hurt.

| # | Theme | Speed | Boss | Twist |
| --- | --- | --- | --- | --- |
| 1 | forest | 110 | `boss_giant` | Always vulnerable. Shockwaves (low) and boulders (high). |
| 2 | mountain | 120 | `boss_dragon` | Only vulnerable while recovering after an attack. |
| 3 | wastes | 130 | `boss_queen` | Summons hounds and ravens that soak up fireballs. |
| 4 | tower | 140 | `boss_stormking` | Only charged fireballs hurt, and only while recovering. |

Bosses change attack pattern as their health drops (`phases` in `Bosses.json`).

## Endless run

The menu's START button begins an endless run: the levels in order, each with its boss, then round
again from the first. It is open from the first launch. Beating a level in an endless run is also
what makes that level appear on the menu to play on its own.

- The hero starts every run at level 1 with three hearts, whatever the save holds, and keeps their
  XP and abilities from level to level. Hearts carry over; each boss beaten gives one back.
- Every completed loop runs the whole game clock 15% faster (hero, enemies, bosses and their
  attacks alike), up to twice the normal speed from loop 8. Because only the clock changes, the
  proof that each level can be beaten without a hit holds on every loop.
- The run ends when the hearts run out or the hero falls. The score adds up across levels; the best
  score and the most levels beaten in one run are saved. XP earned here is not saved.

## Names

All display text comes from `App/Resources/Lore.json`, keyed by role id.
