# Destructible Stage Object Report

## Outcome

Eight Joseon-world destructibles ship as complete 64x64 sets: one intact sprite,
four irreversible break frames, and one explicit debris-rest alias per object.
All eight passed the progression, scale, hard-alpha, chroma, breakable-cue and
debris-equivalence gates, and the complete visual audit is retained at
`asset/destructible/raw/destructible_contact_sheet.png`.

## Why these eight

The selection weights the two M1 stages and varies silhouette and break material
so the objects do not read as eight recoloured containers:

- **Bamboo Forest:** `onggi_jar`, `straw_bundle`, `bamboo_basket`, `rice_sack`.
  These are inhabited-edge/farm objects appropriate beside bamboo paths, and
  break as pottery, loose straw, wicker and fabric/grain respectively.
- **Abandoned Temple:** `supply_crate`, `handcart`, `offering_vessels`,
  `roof_tile_stack`. These suggest evacuation, offerings and building decay,
  and break as timber, detached wheel/shafts, mixed ceramics/metal and giwa tile.

Every intact sprite carries the same small vermilion paper seal or knotted
tassel. That is the learned “this can be broken for loot” cue that decorative
stage structures do not have. It is a shape/ornament cue as well as a colour
cue: the hanging rectangular tag remains identifiable without relying on red.

## Inventory and frame order

For each id below:

```text
asset/destructible/<id>/intact.png
asset/destructible/<id>/break/0.png   first impact / loosened binding
asset/destructible/<id>/break/1.png   major split or tilt
asset/destructible/<id>/break/2.png   active irreversible collapse
asset/destructible/<id>/break/3.png   resting debris
asset/destructible/<id>/debris.png    byte-identical alias of break/3
```

Ids: `onggi_jar`, `straw_bundle`, `bamboo_basket`, `rice_sack`,
`supply_crate`, `handcart`, `offering_vessels`, `roof_tile_stack`.

All runtime images are 64x64 hard-alpha PNGs cut through `pixelize.py` against
the Taoist rotation palette. Intact content heights are 34–40px, deliberately
below the 44–58px trash-monster range.

## Measured collapse evidence

Numbers are changed RGBA pixels for the four transitions
`intact→0`, `0→1`, `1→2`, `2→3`. The terminal number compares intact directly
to resting debris. A set passes when every transition is material, the terminal
state is different, and the object either loses height/area or fragments into
more disconnected pieces.

| Id | Intact h | Transition changes | Terminal | Final height ratio | Final area ratio | Result |
|---|---:|---|---:|---:|---:|---|
| onggi_jar | 39 | 894, 1059, 1051, 1023 | 1112 | 0.564 | 0.497 | pass |
| straw_bundle | 34 | 661, 661, 696, 776 | 720 | 0.588 | 0.784 | pass |
| bamboo_basket | 36 | 836, 789, 850, 824 | 835 | 0.750 | 0.703 | pass |
| rice_sack | 39 | 885, 1061, 1121, 1106 | 1165 | 0.718 | 0.834 | pass |
| supply_crate | 40 | 1162, 1235, 1544, 1511 | 1361 | 0.675 | 0.709 | pass |
| handcart | 37 | 1054, 1404, 1467, 1666 | 1507 | 1.135 | 0.858 | pass by fragmentation |
| offering_vessels | 39 | 792, 1100, 1030, 1159 | 1233 | 0.769 | 0.787 | pass |
| roof_tile_stack | 40 | 1002, 1424, 1671, 1642 | 1409 | 0.725 | 0.739 | pass |

The handcart is the honest exception to a height-only collapse rule: its fallen
shafts make the debris bbox taller, but the wheel detaches, opaque components
increase from 1 to 2, area falls to 0.858, and every transition changes more than
1,000 pixels. The contact sheet confirms it reads as a disassembled cart rather
than an upright identity-drift frame.

## Combat drop guidance

The authoritative machine-readable mapping is
`asset/destructible/destructible_manifest.json`. Suggested per-object weights:

| Id | Stage | Suggested yield | Why |
|---|---|---|---|
| onggi_jar | both | 70% `health_gourd`, 30% `gold_coin` | jars plausibly store restorative drink/herbs or household coins |
| straw_bundle | Bamboo | 65% `gold_coin`, 35% `health_gourd` | a bundle can hide a small purse or gathered medicine, not a chest |
| bamboo_basket | Bamboo | 70% `gold_coin`, 30% `health_gourd` | a foraging basket carries provisions and small valuables |
| rice_sack | both | 75% `health_gourd`, 25% `gold_coin` | food storage should bias recovery; coin can be hidden in the binding |
| supply_crate | both | 60% `gold_pile`, 30% `health_gourd`, 10% `chest_common` | the most credible container for supplies and an occasional chest |
| handcart | both | 55% `gold_pile`, 35% `magnet`, 10% `chest_common` | bulk cargo supports gold/chest; iron fittings make magnet plausible |
| offering_vessels | Temple | 70% `gold_coin`, 30% `magnet` | offerings contain coins; spiritual attraction fits ritual vessels |
| roof_tile_stack | Temple | 100% `gold_coin` | only a small hidden reward is credible; premium loot would feel arbitrary |

Common chests are limited to the supply crate and handcart. Rare/epic/legendary/
mythic chests should remain elite/boss rewards; allowing a roof-tile stack to
produce one would undermine the requested world logic.

### Integration contract

Combat should load `intact.png`, then on destruction play `break/0.png` through
`break/3.png` once in numeric order at roughly 60–80ms per frame. Spawn the drop
when frame 3 lands so the reward appears out of settled debris rather than before
the object breaks. Leave `debris.png` for about 1.5–3 seconds, then fade or return
it to the pool; permanent debris would accumulate until it obscures combat and
inflate draw/node counts. All eight should therefore leave debris briefly, but
none should leave it for the full run.

No `data/**`, `scripts/**` or `scenes/**` file was changed here.

## Generation and credits

Tool: Higgsfield Nano Banana Pro, two separately submitted 1K 4:3 sheet jobs,
each conditioned on `asset/prop/raw/props_sheet_higgsfield.png` and the Taoist
south authority. Job ids:

- Bamboo Forest: `4e5a9438-5b92-4100-b91e-0ea656ed06e4`
- Abandoned Temple: `69fd7621-c367-4ee8-86cb-93a5fc32057f`

Prompt set: each sheet requested an exact 5-column × 4-row grid; each row was one
named object and each column was intact, first impact, major split, active
collapse, resting debris. Both prompts required a flat `#FF00FF` background,
no magenta subject pixels, one centred subject per cell, generous padding, the
shared vermilion loot seal, pure-black outline, low top-down camera, countable
square pixels, flat two/three-tone shading, no captions/grid/floor/shadows/loot/
explosions/motion blur, and no fragments crossing cell boundaries.

- Balance before: **828.55**
- Preflight: **2 credits per sheet**
- Balance after: **824.55**
- Actual spend: **4.00 credits**

Both generated sheets and all 40 recuttable raw cells remain under
`asset/destructible/raw/`.

## Verification

All required commands exited 0. Real output:

```text
> godot --headless --path . --import
(no output; exit 0)

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
```

The data validator also emitted its existing `Loaded resource as image file`
warnings for monster PNGs; they do not concern the new destructibles and the
command exited 0.

```text
> python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 5 chrome assets, 34 weapon assets, 2 characters, 4 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props
Six multi-reference motion sheets rejected: 0/96 frames passed the regional stability gate
Expansion assets verified: 18 folklore monsters + 144 rotations, 60 effect frames, 12 structures, 3 title assets
Set-gap additions verified: 100 death frames, 22 procedural walk records, 5 travel sprites, 4 melee swings
Loot and boss-scale assets verified: 12 pickup sets (48 collect frames) + 120x150 boss with 8 rotations and 4 death frames
Destructible stage objects verified: 8 intact sprites + 32 break frames + 8 debris aliases; progression/scale/cue gates passed
Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed
Character near-duplicate gate verified: 84 pairs at mean-RGBA threshold 2.50; minima: Taoist 5.11 (east/west), Warrior 2.88 (north-east/north), Archer 4.58 (north-west/south-west)
UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed
Camp identity verified: 2 warm seamless tiles + 3 rotatable north-facing transition overlays
Button redesign verified: 3 directions x 4 states; selected royal_seal, 6x8 margins, WCAG-AA/pressed-shape gates passed
```

Additional focused checks also passed: `python -m py_compile` for all three
new/changed asset scripts and `git diff --check` (only Git's existing LF-to-CRLF
working-copy notices were printed).
