"""Checks the generated art against docs/sprite-spec.md and against the game's content files."""
import json
import sys
from pathlib import Path

import pytest
from PIL import Image

TOOL = Path(__file__).resolve().parents[1]
ROOT = TOOL.parents[1]
sys.path.insert(0, str(TOOL))

import build  # noqa: E402
import export  # noqa: E402

# sprite -> (size, {animation: frames}). Mirrors docs/sprite-spec.md; change both together.
SPEC = {
    "hero": ((48, 48), {"run": 8, "stop": 4, "idle": 4, "jump": 2, "fall": 2, "cast": 6, "hurt": 2, "death": 6}),
    "fireball": ((16, 16), {"fly": 4, "impact": 5}),
    "fireball_charged": ((24, 24), {"fly": 4, "impact": 5}),
    "goblin": ((32, 32), {"walk": 6, "death": 4}),
    "giant": ((48, 64), {"walk": 6, "swing": 6, "hurt": 2, "death": 6}),
    "archer": ((24, 32), {"idle": 2, "shoot": 4, "death": 4}),
    "hound": ((32, 20), {"run": 6, "death": 4}),
    "raven": ((24, 20), {"fly": 4, "death": 3}),
    "wolf": ((32, 20), {"run": 6, "death": 4}),
    "skeleton": ((24, 32), {"walk": 6, "death": 4}),
    "ghost": ((24, 28), {"float": 4, "death": 3}),
    "thorns": ((28, 14), {"still": 1}),
    "boss_giant": ((96, 96), {"idle": 4, "slam": 8, "stunned": 4, "hurt": 2, "death": 8}),
    "boss_dragon": ((128, 96), {"idle": 6, "breath": 8, "tail": 6, "hurt": 2, "death": 8}),
    "boss_queen": ((64, 96), {"idle": 4, "summon": 6, "cast": 6, "hurt": 2, "death": 8}),
    "boss_stormking": ((96, 128), {"idle": 6, "lightning": 8, "phase": 6, "hurt": 2, "death": 10}),
}


@pytest.fixture(scope="module")
def sprites():
    return {s.name: s for s in build.all_sprites()}


@pytest.mark.parametrize("name", sorted(SPEC))
def test_sprite_matches_spec(sprites, name):
    size, animations = SPEC[name]
    sprite = sprites[name]
    assert sprite.size == size
    assert {anim: len(a.frames) for anim, a in sprite.anims.items()} == animations


def test_every_frame_has_its_sprite_size_and_is_not_blank(sprites):
    for sprite in sprites.values():
        for name, anim in sprite.anims.items():
            for index, frame in enumerate(anim.frames):
                assert frame.size == sprite.size, f"{sprite.name}/{name}[{index}]"
                # The last frames of a death may dissolve to nothing; everything else must draw something.
                if name != "death":
                    assert frame.getbbox() is not None, f"{sprite.name}/{name}[{index}] is empty"


def test_output_is_deterministic(sprites):
    again = {s.name: s for s in build.all_sprites()}
    for name, sprite in sprites.items():
        for anim, data in sprite.anims.items():
            for a, b in zip(data.frames, again[name].anims[anim].frames):
                assert a.tobytes() == b.tobytes(), f"{name}/{anim} differs between runs"


def test_animation_actually_moves(sprites):
    for name in ("hero", "goblin", "giant", "hound", "boss_dragon"):
        anim = next(iter(sprites[name].anims.values()))
        assert len({frame.tobytes() for frame in anim.frames}) > 1, f"{name}: all frames identical"


def test_manifest_and_atlas_match_the_code(sprites):
    """Fails when someone edits a character but forgets to run build.py."""
    manifest = json.loads(export.MANIFEST.read_text())
    assert set(manifest) == set(sprites)
    for name, sprite in sprites.items():
        assert (manifest[name]["width"], manifest[name]["height"]) == sprite.size
        for anim, data in sprite.anims.items():
            assert manifest[name]["animations"][anim]["frames"] == len(data.frames)
            for index, frame in enumerate(export.frames_of(sprite, anim)):
                frame_name = export.frame_name(name, anim, index)
                path = export.ATLAS / f"{frame_name}.imageset" / f"{frame_name}.png"
                assert path.exists(), f"{path.name} missing: run Tools/sprites/build.py"
                assert Image.open(path).convert("RGBA").tobytes() == frame.tobytes(), f"{frame_name} is stale"


def test_every_thing_the_game_can_show_has_a_sprite(sprites):
    resources = ROOT / "App" / "Resources"
    needed = set()
    for path in sorted((resources / "Levels").glob("level_*.json")):
        level = json.loads(path.read_text())
        needed |= {item["kind"] for item in level["items"]}
        needed |= {level["boss"], f"ground_{level['background']}", f"ground_{level['background']}_fill",
                   f"ground_{level['background']}_earth", f"bg_{level['background']}_sky_top"}
        needed |= {f"bg_{level['background']}_{layer}" for layer in ("sky", "far", "near", "clouds", "puffs", "bushes")}
        if level.get("ravines"):
            needed |= {f"ravine_{level['background']}", f"ravine_{level['background']}_fill",
                       f"ravine_{level['background']}_deep"}
    for boss in json.loads((resources / "Bosses.json").read_text()):
        for attack in boss["attacks"]:
            needed |= {f"hazard_{h['kind']}" for h in attack["hazards"]}
            needed |= {s["kind"] for s in attack.get("summons", [])}
    needed |= {"hazard_arrow", "hero", "fireball", "fireball_charged", "medal", "spark_star", "spark_ember", "spark_feather"}
    needed |= {f"ability_{name}" for name in ("fireball", "doubleJump", "chargedFireball")}
    assert needed - set(sprites) == set()
