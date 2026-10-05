# Simon the Dragon Slayer — agent instructions

2D auto-runner for iPhone (Swift + SpriteKit). The hero runs, jumps obstacles, levels up into a
fireball, and fights a boss at the end of each of four levels. An original setting: do not add
names, places or story from existing books, films or games.

## Rules that are easy to break

1. **Game rules live in `Packages/GameCore` and never import SpriteKit/UIKit.** `App/` only draws
   `RunnerWorld` state and forwards touches. If a change decides whether something is hit, dies or
   unlocks, it belongs in GameCore with a test.
2. **`RunnerWorld` must stay a deterministic value type** — no randomness, no clocks, no reference
   types. The validator bot copies the world and steps the copy to look ahead; anything
   non-deterministic silently breaks level validation.
3. **Display names live only in `App/Resources/Lore.json`.** Code, asset names and level data use
   neutral role ids (`hero`, `boss_dragon`, …), so anything can be renamed in one place.
4. **Art is code.** Never hand-edit PNGs under `Assets.xcassets/Sprites.spriteatlas` or
   `Sprites.json`; change `Tools/sprites/characters/*.py` and run the build. Output must be
   byte-identical between runs (use `draw.noise(seed)`, never `random`).
5. **Every level must be beatable without taking a hit.** `swift test` proves it with a bot playing
   on one heart. If a level fails, fix the level or the boss pattern — not the bot or the test.
6. `SimonTheDragonSlayer.xcodeproj` is generated. Edit `project.yml`, then `xcodegen generate`.

## Commands

```
Tools/check.sh                       # rules + level solvability + art tests + simulator build
swift test --package-path Packages/GameCore
Tools/.venv/bin/python Tools/sprites/build.py [name ...]   # regenerate art (all if no name)
python3 Tools/sfx/build.py           # regenerate sound effects
Tools/run-sim.sh                     # build, launch in simulator, screenshot the menu
Tools/run-sim.sh 2 12 41             # bot plays level 2; screenshots at 12 s and 41 s
ORIENT=portrait Tools/run-sim.sh 1 39   # same, upright (default is landscape)
Tools/release-check.sh               # gate before any TestFlight/App Store upload
```

First-time setup: `brew install xcodegen` and
`python3 -m venv Tools/.venv && Tools/.venv/bin/pip install pillow pytest`.

## Where things are

| Path | What |
| --- | --- |
| `Packages/GameCore/Sources/GameCore/World.swift` | The simulation: movement, collisions, fireballs, boss state machine |
| `…/Bot.swift` | Look-ahead bot and `LevelValidator` |
| `…/Progression.swift`, `Items.swift` | XP thresholds, abilities, per-item hitboxes and stats |
| `App/Resources/Levels/level_NN.json`, `Bosses.json` | Content — see `docs/level-format.md` |
| `App/Scenes/GameScene.swift` | Rendering, input, sound; maps `GameEvent`s to animations |
| `Tools/sprites/` | Art pipeline — see `docs/sprite-spec.md` |
| `docs/game-design.md` | Mechanics, progression, levels and bosses |

Units: 1 world unit = 1 sprite pixel. Both orientations are supported: `GameScene.sceneSize` picks a
whole number of device pixels per unit so that at least 330×180 units fit in landscape and 230×180
in portrait (larger sprites, shorter view; the boss stands at `narrowBossOffset` there, and the
whole playfield is stretched 1.4× vertically to use the tall screen), and `layout(viewSize:)`
re-frames on rotation without touching the simulation. Check visual changes in **both** orientations.
Characters are drawn facing right; enemies are mirrored on export (`faces_left=True`).

## Skills and agents

Skills: `/sprite`, `/new-enemy`, `/new-level`, `/play`, `/check`, `/release-check`.
Agents: `gameplay-engineer`, `pixel-artist`, `level-designer`, `qa-playtester` — the artist and the
level designer touch files disjoint from the engineer's, so they can work in parallel.
