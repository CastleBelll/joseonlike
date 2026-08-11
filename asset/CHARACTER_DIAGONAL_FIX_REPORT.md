# Character Diagonal Rotation Fix Report

## What was wrong

The runtime mapping was not changed. Before editing, the fixed-canvas mean absolute RGBA
distance reproduced combat's Warrior result exactly: `north-east` to `north-west` was **1.92**,
while `north-east` mirrored to `north-west` was 4.69. That was duplicated north-east
handedness under the north-west filename.

The Warrior's southern pair was a different fault that a mirror metric cannot expose. Relative
horizontal skin/face centroids showed the labels were reversed: the old `south-east` was -2.5px
(following `west` at -1.9px) while the old `south-west` was +2.1px (following `east` at +2.5px).
I relabelled those two existing PNGs by swapping the files; no generation was used for that fix.

## Shipped fixes

- `asset/character/Warrior/Idle/rotations/north-west.png` is a new per-direction Higgsfield
  render conditioned on the Warrior's north, west, opposite diagonal, and a mirrored pose
  reference derived from his own correct cell. It was cut through `pixelize.py` to 46px content
  on the standard 92x92 canvas.
- `asset/character/Warrior/Idle/rotations/south-east.png` and `south-west.png` are the relabelled
  original cells. After relabelling their centroid signs are +2.1px and -2.5px respectively,
  matching east/right and west/left.
- Archer had no south-diagonal swap: `south-east` is +0.8px versus east +2.0px, and
  `south-west` is -0.3px versus west -2.1px. It did have an unreported near-duplicate:
  `north`/`north-west` measured **1.76**, so
  `asset/character/Archer/Idle/rotations/north-west.png` was regenerated per direction and cut
  through `pixelize.py` to the same 46px/92px contract.

The final contact sheets are `asset/rotation_audit/contact_sheets/Warrior.png` and
`asset/rotation_audit/contact_sheets/Archer.png`. I inspected both in the canonical order. The
three southern cells show faces with their shoulders/weapons leading toward the named side,
east and west are opposite profiles, and the three northern cells show the back. Warrior and
Archer north-west now lead up-left and are visibly distinct from both north and north-east.

## Generation result and retained raw

The first two Warrior attempts were rejected: the first ignored chroma and turned into a
front-left/white-background pose; the second retained a visible profile instead of a rear
three-quarter pose. Those failures remain at:

- `asset/character/Warrior/raw/north-west_direction_fix_failed_higgsfield.png`
- `asset/character/Warrior/raw/north-west_direction_fix_retry_higgsfield.png`

The accepted third raw and cut are
`asset/character/Warrior/raw/north-west_direction_fix_pose_higgsfield.png` and
`north-west_direction_fix_pose_cut.png`. The Archer raw and cut are
`asset/character/Archer/raw/north-west_direction_fix_higgsfield.png` and
`north-west_direction_fix_cut.png`.

## Gate added

`tools/asset/verify_assets.py` now compares all 28 pairs in each of the three player rotation
sets (84 comparisons) using combat's mean absolute per-channel RGBA distance over the fixed
92x92 canvas. A pair below **2.50** fails while naming both paths. This threshold catches the
measured 1.92 Warrior defect and the newly found 1.76 Archer defect while retaining margin below
the final minima:

| set | final closest pair | final distance |
|---|---|---:|
| Taoist | east / west | 5.11 |
| Warrior | north-east / north | 2.88 |
| Archer | north-west / south-west | 4.58 |

The absolute gate is intentionally scoped to player sprites because all three share 92x92
canvas and 46px content. Applying 2.50 to monsters would create false failures: monster content
ranges from 44 to 150px and includes symmetric/known-limited spirits, so transparent canvas area
changes the mean.

I did **not** add a dishonest automated diagonal-handedness classifier. Swapping
`south-east`/`south-west` preserves both their direct and mirror-pair distances, so those numbers
cannot prove which label is which. Instead `audit_rotation_facing.py` schema 2 records the exact
direction expected for every cell, explicitly records that diagonal handedness is manual-only,
and SHA-256-binds the approved contact sheet and cells; `verify_assets.py` enforces that record.

## Credits

Higgsfield balance before generation was **840.55**. Preflight was 2 credits per submitted
Nano Banana Pro 1K job. Four jobs were submitted (Archer accepted first try; Warrior accepted on
the third try). Final balance was **832.55: 8.00 credits spent**, exactly matching the
per-submitted-job preflight.

## Verification

All required commands exited 0.

```text
> godot --headless --path . --import
(no stdout)
exit 0

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
exit 0

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
exit 0
```

The data validator also emitted its existing `Loaded resource as image file, this will not work
on export` warning once per monster PNG. Those warnings do not fail validation and are outside
this asset-owned change.

```text
> python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 4 chrome assets, 34 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props
Six multi-reference motion sheets rejected: 0/96 frames passed the regional stability gate
Expansion assets verified: 18 folklore monsters + 144 rotations, 60 effect frames, 12 structures, 3 title assets
Set-gap additions verified: 100 death frames, 22 procedural walk records, 5 travel sprites, 4 melee swings
Loot and boss-scale assets verified: 12 pickup sets (48 collect frames) + 120x150 boss with 8 rotations and 4 death frames
Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed
Character near-duplicate gate verified: 84 pairs at mean-RGBA threshold 2.50; minima: Taoist 5.11 (east/west), Warrior 2.88 (north-east/north), Archer 4.58 (north-west/south-west)
UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed
exit 0
```
