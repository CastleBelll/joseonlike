# JOSEONLIKE second asset batch

## Outcome

This pass ships eighteen Korean-folklore monster concepts for the three future areas,
ten four-frame combat/upgrade effect sets, the four base-camp buildings, eight Joseon
scenery structures, and verified English and Korean title art. Every generated deliverable
was submitted as a multi-cell sheet, preserved under the relevant `raw/` directory, sliced
with `slice_sheet.py`, and cut/quantised with `pixelize.py` against the Taoist rotation
palette. No file under `data/`, `scripts/`, or `scenes/` was edited.

## Credits and provenance

Higgsfield balance was 1034.55 credits before generation. The fifteen planned sheets
preflighted at 2 credits each (30 total); one 2-credit correction sheet replaced a jangseung
cell with an untrustworthy generated inscription, so the final spend was 32 credits and the
ending balance was 1002.55. This estimate treats each submitted job as billable, correcting
the earlier misleading two-result preflight behavior.

Jobs:

- Capital City monsters: `039a506d-e057-43d8-942e-2bae3ea898b9`
- Royal Tomb monsters: `54735f52-8ec6-4d52-ba15-ba7635d737a5`
- Spirit World monsters: `a5e96c03-2f32-4616-b8ed-f02797851258`
- Talisman burst: `f85c1f29-4719-4a40-a9e3-7ac98e735e8b`
- Spirit flame: `2687ddff-f23b-4acc-9a6d-a4f94a9e75ad`
- Summon circle: `fa7599a1-2db9-4aad-9afc-9664b9c67cb4`
- Fire: `ffdfafdc-7d70-4b24-9628-cc8369797cd8`
- Lightning: `7073f0cc-1eef-42a0-bc29-51e24455f4e8`
- Poison cloud: `ebc4ffd1-6737-45fa-a30a-4b17516bf9c4`
- Slash: `d6bb9326-0742-48ef-8c96-5c59b9336934`
- Impact hit: `d362173b-a1c2-4c3f-aa9a-e4d2d914c5a5`
- Level-up: `cd2f08bb-2edf-4769-813e-6bd5a6503c08`
- Evolution flourish: `07db35f7-2f8e-448b-b611-1e73bafd4088`
- Camp/structure sheet: `b5185952-9fb9-4ec8-a0b8-39781f144a83`
- Title sheet: `6decea23-25fa-40f4-9da6-e02aaa43b7df`
- Inscription-free jangseung correction sheet: `87063f03-1b48-4c0f-af1a-a95aba25d8f2`

## Monster handoff

All final sprites use a 92x92 transparent canvas. The size below is the measured opaque
content; `content-data` must add the monster entries and choose `collision_radius <=
floor(content_width / 2)`.

| Area | id/path under `asset/monster/` | Content | Max radius |
|---|---|---:|---:|
| Capital City | `gwimyeon_dokkaebi.png` | 36x54 | 18 |
| Capital City | `blue_dokkaebi.png` | 38x50 | 19 |
| Capital City | `gumiho_scout.png` | 51x48 | 25 |
| Capital City | `seonbi_wraith.png` | 28x52 | 14 |
| Capital City | `haetae_guardian.png` | 49x58 | 24 |
| Capital City boss | `dokkaebi_king.png` | 60x76 | 30 |
| Royal Tomb | `cheonyeo_gwisin.png` | 50x52 | 25 |
| Royal Tomb | `dalgyal_gwisin.png` | 47x44 | 23 |
| Royal Tomb | `jeoseung_saja.png` | 58x58 | 29 |
| Royal Tomb | `tomb_jangseung.png` | 29x58 | 14 |
| Royal Tomb | `imugi_whelp.png` | 49x52 | 24 |
| Royal Tomb boss | `ancient_imugi.png` | 69x76 | 34 |
| Spirit World | `wonhon.png` | 38x50 | 19 |
| Spirit World | `dokkaebi_fire.png` | 48x44 | 24 |
| Spirit World | `shadow_dokkaebi.png` | 44x52 | 22 |
| Spirit World | `fox_spirit.png` | 49x48 | 24 |
| Spirit World | `bulgasari.png` | 59x58 | 29 |
| Spirit World boss | `gumiho.png` | 76x76 | 38 |

Raw group sheets and recuttable cells are under `asset/monster/raw/later_areas/`.
These sprites are intentionally not present in `data/monsters.json` yet.

## Effects handoff

Combat/meta-UI should load `res://asset/effect/<effect_id>/<frame>.png`. Every frame is
64x64. The frame order for all ten sets is `0` anticipation, `1` expansion, `2` peak,
`3` dissipation; play once and stop, with the owning worktree choosing timing by gameplay.

Effect ids: `talisman_burst`, `spirit_flame`, `summon_circle`, `fire`, `lightning`,
`poison_cloud`, `slash`, `impact_hit`, `level_up`, `evolution_flourish`.

The measurement gate checks compact opaque coverage, a near-white active core in frames
0-2, and at least 16 changed pixels per consecutive transition. Frame 3 is allowed to lose
the core because it is explicitly dissipation, but it still needs a readable silhouette.
All ten sheets passed:

| Effect | Bright-core pixels 0/1/2/3 | Changed pixels 0-1/1-2/2-3 |
|---|---|---|
| talisman_burst | 361 / 249 / 452 / 389 | 777 / 1151 / 1416 |
| spirit_flame | 202 / 476 / 520 / 267 | 1958 / 2378 / 1638 |
| summon_circle | 575 / 546 / 664 / 2 | 2047 / 2231 / 2049 |
| fire | 132 / 241 / 190 / 0 | 1827 / 1535 / 1068 |
| lightning | 375 / 273 / 676 / 141 | 1246 / 1431 / 1415 |
| poison_cloud | 32 / 428 / 376 / 132 | 2499 / 2510 / 2162 |
| slash | 141 / 715 / 873 / 284 | 1281 / 1626 / 1428 |
| impact_hit | 138 / 175 / 301 / 155 | 1076 / 1562 / 1342 |
| level_up | 820 / 323 / 522 / 114 | 1770 / 1009 / 1016 |
| evolution_flourish | 616 / 408 / 405 / 180 | 2063 / 2025 / 1517 |

Reproducible detail is in `asset/effect/raw/effect_metrics.json`; rerun with
`python tools/asset/measure_effect_sheets.py`.

## Structures and title handoff

All structures are transparent 128x128 sprites. Exact paths and opaque content sizes:

| Asset | Path | Content |
|---|---|---:|
| Workshop | `asset/structure/workshop.png` | 109x88 |
| Archive | `asset/structure/archive.png` | 104x88 |
| Training Ground | `asset/structure/training_ground.png` | 116x88 |
| Shrine | `asset/structure/camp_shrine.png` | 88x88 |
| Jangseung pair | `asset/structure/jangseung_pair.png` | 56x88 |
| Stone lantern | `asset/structure/stone_lantern.png` | 51x88 |
| Joseon gate | `asset/structure/joseon_gate.png` | 95x88 |
| Roadside shrine | `asset/structure/roadside_shrine.png` | 70x88 |
| Stone pagoda | `asset/structure/stone_pagoda.png` | 59x88 |
| Wooden fence | `asset/structure/wooden_fence.png` | 128x64 |
| Village well | `asset/structure/village_well.png` | 82x88 |
| Ritual altar | `asset/structure/ritual_altar.png` | 88x88 |

The title assets are transparent 480x96 images:

- `asset/title/joseonlike_en.png` — visually verified exact `JOSEONLIKE`
- `asset/title/joseonlike_ko.png` — visually verified glyph-by-glyph as `조` `선` `라` `이` `크`
- `asset/title/title_frame_blank.png` — same ornament for runtime/localized text

Meta-UI must add these textures to the camp cards and main screen; this worktree did not
edit those scenes. The blank title frame is the safe localization fallback.

## Generator limitations and decisions

- Higgsfield did much better on effects than character motion: effects preserve a trackable
  shape, bright core, and chronological scale change even though individual debris pixels vary.
- The fire sheet ignored the requested flat magenta and drew a grey transparency checker.
  Its raw failure remains preserved. `pixelize.py --checker-background` now removes only
  bright neutral pixels connected to a cell edge, preserving the enclosed white fire core.
- The first structure sheet added a questionable tiny inscription to the jangseung despite
  the no-text instruction. That cell was rejected, remains in raw evidence, and the shipped
  `jangseung_pair.png` comes from a separate inscription-free two-variant correction sheet.
- The title model succeeded unusually well: both the English and Korean lettering remained
  correct after pixelization, so no font fallback was needed. The blank frame is still shipped.

## Verification

All required commands exited 0. Real output:

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
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/forest_spirit.png'. Instead, import the image file as an Image resource and load it normally as a resource.
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_brute.png'. Instead, import the image file as an Image resource and load it normally as a resource.
WARNING: Loaded resource as image file, this will not work on export: 'res://asset/monster/bamboo_spirit_lord.png'. Instead, import the image file as an Image resource and load it normally as a resource.
(exit 0)

$ python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 4 chrome assets, 14 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props
Six multi-reference motion sheets rejected: 0/96 frames passed the regional stability gate
Expansion assets verified: 18 folklore monsters, 40 effect frames, 12 structures, 3 title assets
(exit 0)
```

The four warnings are the unchanged validator implementation warnings for the existing
flat Bamboo Forest monster PNGs. This batch did not replace those assets or edit collision data.
