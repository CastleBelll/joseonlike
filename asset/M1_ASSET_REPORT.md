# JOSEONLIKE M1 asset handoff

## Per-direction direct-conditioning retry

The third motion test used the existing south rotation itself as a direct image-to-image
reference and asked Higgsfield to alter only the two feet into opposite walk contact poses.
This is materially stronger conditioning than the earlier separate renders or packed sheet.
Each single-result job preflighted at 2 credits; the workspace balance moved from 1062.55 to
1058.55, confirming an actual spend of 4 credits for two submitted jobs. No further
directions, attacks, Warrior frames, or Archer frames were generated after the gate failed.

Jobs and recuttable evidence:

- `3268bf63-ac4c-441b-ab90-37004bc67fc4`: south `walk_0`, left foot forward.
- `444bff5e-57dd-41b1-9a18-9176a1814cd8`: south `walk_1`, right foot forward.
- Raw 1024px outputs and 92x92 `pixelize.py` cuts:
  `asset/character/Taoist/raw/conditioned_south/`.
- Reproducible regional measurements:
  `asset/character/Taoist/raw/conditioned_south/metrics.json`, produced by
  `tools/asset/measure_conditioned_motion.py`.

The comparison uses the exact RGBA `ImageChops.difference` method and the authority's
37x46 canonical window, so its denominator remains 1,702 pixels and is directly comparable
to the 449/1,702 (26.38%) separate-render baseline. `Lower share` is the proportion of all
changed pixels falling in the last 15 rows, where the requested feet/leg edit belongs;
hat/staff columns report alpha changes, so nonzero values prove silhouette movement.

| Direction/frame | Changed pixels | Percent | Lower share | Upper changed | Hat alpha changed | Staff alpha changed | Decision |
|---|---:|---:|---:|---:|---:|---:|---|
| south `walk_0` | 1005/1702 | 59.05% | 34.43% | 659 | 22 | 72 | reject |
| south `walk_1` | 987/1702 | 57.99% | 34.95% | 642 | 25 | 74 | reject |

Decision: **direct per-direction conditioning also fails.** Both frames changed more than
twice the 449-pixel baseline rather than preserving the authority. Roughly two thirds of
each change escaped the lower body, and the supposedly fixed hat and staff silhouettes both
moved. The model also expanded the authority's 52-colour cut to 72 and 77 colours. These
would visibly flicker, so the cut frames remain evidence under `raw/` and there are
deliberately no files in `asset/character/Taoist/Walk/rotations/` or
`asset/character/Taoist/Attack/rotations/` for combat to load.

Combat integration is therefore unchanged: consume **no new paths** from this attempt and
keep `asset/character/Taoist/Idle/rotations/<direction>.png` as the directional authority.
The current deterministic motion implementation should remain until an artist edits those
exact 37x46 sprites at pixel level. A shippable replacement needs two hand-authored contact
poses per direction whose changes are confined to the lowest leg pixels, plus cardinal
attack VFX or hand-authored attack poses; diffusion output is not a safe source for those
frames after three independently measured failures.

## Single-image motion-sheet retry

The follow-up tested the strongest practical diffusion workaround: all motion frames packed
into one 4x3 image so they share generation context. Higgsfield job
`242d1780-6751-479c-94bb-354e9ad6c0d9` cost the preflighted 2 credits, moving the balance
from 1064.55 to 1062.55. Unlike the earlier multi-result preflight, this was exactly one
submitted job, so the estimate and final balance agree.

The raw 1200x896 sheet is
`asset/character/Taoist/raw/taoist_motion_sheet_higgsfield.png`. The model added visible
grid lines despite the prompt; `slice_sheet.py --inset=4` removed those regular borders,
then every cell passed through `pixelize.py` at 46px content height on a 92x92 canvas.
Recuttable cells are under `asset/character/Taoist/raw/motion_cells/`, measured cutouts are
under `asset/character/Taoist/raw/motion_cut/`, and the machine-readable results are in
`asset/character/Taoist/raw/motion_metrics.json`.

Logical cell order, left-to-right then top-to-bottom:

```text
idle_0, idle_1, walk_0, walk_1,
walk_2, walk_3, attack_0, attack_1,
attack_2, attack_3, EMPTY, EMPTY
```

The exact earlier ImageChops method was reused on the authority's canonical 37x46 window,
so every percentage has the same 1,702-pixel denominator as the 449-pixel separate-render
baseline.

| Comparison | Changed pixels | Percent | Alpha changed |
|---|---:|---:|---:|
| Separate-render baseline | 449 | 26.38% | 0 |
| idle_0 -> idle_1 | 510 | 29.96% | 6 |
| walk_0 -> walk_1 | 926 | 54.41% | 281 |
| walk_1 -> walk_2 | 965 | 56.70% | 313 |
| walk_2 -> walk_3 | 1004 | 58.99% | 381 |
| walk_3 -> walk_0 | 972 | 57.11% | 341 |
| attack_0 -> attack_1 | 1084 | 63.69% | 284 |
| attack_1 -> attack_2 | 1233 | 72.44% | 463 |
| attack_2 -> attack_3 | 1200 | 70.51% | 444 |

Against the authority, individual frames changed as follows:

| Frame | Changed pixels | Percent | Alpha changed |
|---|---:|---:|---:|
| idle_0 | 840 | 49.35% | 103 |
| idle_1 | 832 | 48.88% | 101 |
| walk_0 | 969 | 56.93% | 180 |
| walk_1 | 1011 | 59.40% | 355 |
| walk_2 | 731 | 42.95% | 64 |
| walk_3 | 1039 | 61.05% | 417 |
| attack_0 | 1050 | 61.69% | 274 |
| attack_1 | 978 | 57.46% | 246 |
| attack_2 | 1207 | 70.92% | 505 |
| attack_3 | 626 | 36.78% | 81 |

Decision: **do not ship the sheet frames.** Packing did not beat the baseline even for the
near-identical idle pair: it regressed by 61 pixels / 3.58 percentage points. The four walk
frames alternate between carrying the staff and having no staff at all, which reads as a
large pop rather than locomotion. Attack frames retain the staff but still change 63.69% to
72.44% between consecutive cells. This is a second measured negative result, so no Warrior
or Archer credits were spent.

Combat must consume **no new motion paths** from this retry; everything under the Taoist
`raw/` directory is evidence only. Keep loading the existing eight
`asset/character/Taoist/Idle/rotations/*.png` direction sprites and retain the procedural
idle/walk/attack implementation specified below. The intended frame order above is recorded
only so a future human retouch pass can reuse the sheet layout; it is not an integration API.

## Engineering decision: procedural character motion

The style authority was independently measured as a 92x92 canvas with opaque bounds
`(27,23)-(63,68)`, a 37x46 character, and 52 opaque colours. Two separate Higgsfield
same-pose renders were cut to 37x46 through `tools/asset/pixelize.py`. Their silhouettes
matched, but 449 of 1,702 pixels (26.4%) changed between them; staff details, robe folds,
face, hat highlights, and colours visibly flicker. Each also changed more than 500 pixels
relative to the authority. Generating walk/attack frames would therefore make the player
less coherent, not more animated.

Use the existing eight Taoist rotations as one authoritative sprite per direction. Motion
must be deterministic and pixel-snapped:

- Select the nearest of the existing eight rotations from the nonzero movement vector.
- Idle at 4 Hz with integer `Sprite2D.position.y` frames `[0, -1, -1, 0]`.
- Walk at 8 Hz with integer local offsets `[Vector2(-1,0), Vector2(0,-1),
  Vector2(1,0), Vector2(0,0)]`; flip the x sequence for alternating steps. Do not use
  continuous subpixel bobbing, fractional scale, or sprite rotation.
- On attack, keep the body sprite fixed. Present the authored weapon/projectile VFX, flash
  the body for at most 60 ms, and optionally apply a one-pixel recoil opposite the aim for
  one physics tick. The VFX carries the attack; the character does not redraw.
- Reset local sprite offset to `Vector2.ZERO` when movement or attack state changes so
  motion never leaks into collision placement.

The failed test is intentionally retained under `asset/character/raw/motion_test/` as raw
and pixelized evidence. It is not production art.

## Production assets

### Characters

- Taoist: existing eight rotations under `asset/character/Taoist/Idle/rotations/`.
- Warrior: `asset/character/Warrior/Idle/rotations/south.png`, 92x92 canvas, 29x46 content.
- Archer: `asset/character/Archer/Idle/rotations/south.png`, 92x92 canvas, 38x46 content.

Warrior and Archer are single-direction M1 portraits/gameplay fallbacks. Do not synthesize
their other directions independently; mirror only when direction readability is sufficient,
or commission a hand-authored rotation set later.

### Weapon icons and gameplay VFX

Every generated sprite below was sliced from the raw Higgsfield sheet and passed through
`pixelize.py` against the Taoist rotation palette.

- Fixed 32x32 HUD icons: `asset/weapon/icons/{old_talisman,fire_talisman,phoenix_talisman,sword,twin_sword,bow,divine_bow}.png`
- Gameplay art: `asset/weapon/projectiles/{old_talisman,fire_talisman,phoenix_talisman,sword,twin_sword,bow,divine_bow}.png`
- Recuttable sources: `asset/weapon/raw/higgsfield_weapon_sheet.png` and `asset/weapon/raw/cells/`

Combat worktree changes required:

1. Add `sprite` to all seven entries in `data/weapons.json`, pointing to the corresponding
   `res://asset/weapon/icons/<id>.png` file (content-data worktree).
2. Add a `Texture2D`/resource path property to `Projectile`; `_ensure_sprite()` should use
   it instead of `PlaceholderArt.placeholder(tint)`. Map talisman ids to old/fire/phoenix
   projectile art and bow ids to bow/divine-bow art.
3. Add an authored visual texture property to `MeleeArc`, replacing its placeholder
   `Polygon2D`; use `sword.png` for sword and `twin_sword.png` for twin sword. Preserve the
   existing collision circle and rotate only this VFX to `facing.angle()`.
4. Use the procedural character offsets above in `scripts/combat/player.gd`; collision and
   root `CharacterBody2D` position remain unchanged.

### Stage ground

- `asset/stage/bamboo_forest_ground.png`
- `asset/stage/abandoned_temple_ground.png`

Both are 256x256, 32-colour, darkened tiles with bit-identical opposite edges guaranteed by
mirrored construction. Raw Higgsfield concepts are under `asset/stage/raw/`.

Combat worktree changes required: add a background layer behind actors in
`scenes/combat/stage.tscn`, select the ground texture from `stage_id`, enable texture repeat,
and cover at least the camera viewport plus one tile margin. Bamboo Forest maps to
`bamboo_forest_ground.png`; Abandoned Temple maps to `abandoned_temple_ground.png`.

### UI/UX

- Passive icons, all fixed 32x32: `asset/ui/passive/<passive_id>.png`
- Achievement icons, all fixed 32x32: `asset/ui/achievement/<achievement_id>.png`
- Currency and XP: `asset/ui/currency/{gold,xp}.png`
- State icons: `asset/ui/state/{lock,check}.png`
- Nine-slice chrome: `asset/ui/chrome/panel_9slice.png` and
  `button_{normal,hover,pressed}_9slice.png`

The chrome uses the existing ink/paper/vermilion/gold constants exactly. Icons have distinct
silhouettes/internal shapes so state is not colour-only. Meta-UI should replace emoji and
placeholder chips with these paths and configure nine-slice margins at 6 px for the panel
and 6 px horizontal / 8 px vertical for buttons.

### Audio

- Loop: `asset/audio/ambience/bamboo_forest_loop.wav` (12.0 s)
- SFX: `asset/audio/sfx/{combat_hit,enemy_death,level_up,boss_spawn,ui_click}.wav`

All are mono 22.05 kHz PCM and peak-normalized at or below -3 dBFS. The ambience is built
from periodic components whose cycle length is exactly the file length. Combat should route
hit/death SFX to a shared limited-voice pool; meta-UI should play level-up and UI click; boss
controller should play boss spawn. Do not stack duplicate hit sounds in the same physics
frame.

`asset/audio/LICENSE.md` records provenance. These files contain no samples or third-party
material. Higgsfield audio was not used because the configured endpoint is speech-only and
explicitly cannot generate ambience or sound effects.

## Higgsfield provenance and limitations

The workspace started with 1082.55 credits and ended with 1064.55, so the pass spent 18
credits total. Cost preflights were performed; each completed image job cost 2 credits.
The two-result motion preflight reported 2 credits but the final balance indicates the
backend charged per submitted job; this discrepancy is worth remembering for future batch
estimates. Source jobs:

- Motion tests: `9a2f2ecd-1d22-47be-9dae-89ef62a590bd`,
  `7ed6c4da-dac1-4407-a3c5-5191d26bab54`
- Weapons: `bddbcc88-b441-4b1d-a9ae-39adf90c4ee9`
- UI icons: `5354d426-10d8-48ff-9919-9d8d3a3a48d8`
- Bamboo ground: `0edaee1a-72e0-4a1f-a34c-37e6db9f1fcd`
- Temple ground: `2f907a25-833f-49ef-ad56-fe8287d5d42e`
- Warrior: `fc66d71d-2bf6-420d-ba7b-cfa5fe2605c1`
- Archer: `95a61dd9-5e00-436b-9de9-219642fe7d79`

Higgsfield did well on isolated icons, independent character concepts, and environmental
concept texture. It did not produce safe frame-to-frame character consistency, its
AutoSprite model was exposed by discovery but rejected both cost estimation and generation,
and its audio connector could not perform the requested SFX task. A future art pass should
use a human-authored sprite animator for directional character motion and retain this
procedural motion until such a set is complete.

## Verification

Asset contract verifier:

```text
$ python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 4 chrome assets, 14 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
```

Required Godot commands, with real output:

```text
$ godot --headless --path . --import
(no stdout or stderr; exit 0)

$ godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
(exit 0)

$ godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

PASS data validation: no errors
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_goblin.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:311)
       [1] validate_all (res://tools/validate_data.gd:75)
       [2] _init (res://tools/validate_data.gd:48)
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_spirit.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:311)
       [1] validate_all (res://tools/validate_data.gd:75)
       [2] _init (res://tools/validate_data.gd:48)
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_brute.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:311)
       [1] validate_all (res://tools/validate_data.gd:75)
       [2] _init (res://tools/validate_data.gd:48)
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_spirit_lord.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:311)
       [1] validate_all (res://tools/validate_data.gd:75)
       [2] _init (res://tools/validate_data.gd:48)
(exit 0)
```

The four validator warnings predate this asset set and arise because the validator itself
loads monster PNGs as raw `Image` objects. No monster sprite or collision dimension changed.

### Single-sheet retry verification (real output)

```text
$ python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 4 chrome assets, 14 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
(exit 0)

$ godot --headless --path . --import
(no stdout or stderr; exit 0)

$ godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
(exit 0)

$ godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

PASS data validation: no errors
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_goblin.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:345)
       [1] validate_all (res://tools/validate_data.gd:76)
       [2] _init (res://tools/validate_data.gd:49)
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_spirit.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:345)
       [1] validate_all (res://tools/validate_data.gd:76)
       [2] _init (res://tools/validate_data.gd:49)
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_brute.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:345)
       [1] validate_all (res://tools/validate_data.gd:76)
       [2] _init (res://tools/validate_data.gd:49)
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_spirit_lord.png'. Instead, import the image file as an Image resource and load it normally as a resource.
   at: load (core/io/image.cpp:2770)
   GDScript backtrace (most recent call first):
       [0] _validate_monsters (res://tools/validate_data.gd:345)
       [1] validate_all (res://tools/validate_data.gd:76)
       [2] _init (res://tools/validate_data.gd:49)
(exit 0)
```

### Direct-conditioned retry verification (real output)

```text
$ python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 4 chrome assets, 14 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
(exit 0)

$ godot --headless --path . --import
(no stdout or stderr; exit 0)

$ godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
(exit 0)

$ godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

PASS data validation: no errors
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_goblin.png'. Instead, import the image file as an Image resource and load it normally as a resource.
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_spirit.png'. Instead, import the image file as an Image resource and load it normally as a resource.
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_brute.png'. Instead, import the image file as an Image resource and load it normally as a resource.
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_spirit_lord.png'. Instead, import the image file as an Image resource and load it normally as a resource.
(exit 0)
```

The validator warnings are the same pre-existing raw-Image loading warnings described
above; no monster asset or collision dimension changed in this retry.
