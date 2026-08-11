# Asset set-gap and combat-readability report

Date: 2026-08-11  
Branch: `CastleBelll/asset-forge`  
Authority: `ASSET_SPEC.md` and `asset/character/Taoist/Idle/rotations/south.png`

## Outcome

- Shipped four-frame death sequences for all eighteen folklore monsters that were missing
  them. Together with the seven existing character/Bamboo Forest sequences, the repository
  now contains 25/25 required death sets; all pass the irreversible-collapse gate.
- Resolved the open monster-walk member with a measured negative result. Four conditioned,
  two-frame sheet trials spanning humanoid, quadruped, floating-spirit and serpentine body
  plans passed neither the locality nor identity gate, so no generated walk frames ship.
  `asset/monster/WALK_STATUS.json` records the pixel-snapped procedural substitute for all
  22 monster sets.
- Shipped five canonical east-facing projectiles in flight, four canonical east-oriented
  melee attacks, and separate four-frame impacts for fireball and spirit bolt. The original
  thirteen effect sets were left byte-for-byte untouched.
- Nothing from the requested list was dropped.

The image-generation workflow required preserving every pre-cutout sheet, cutting through
`slice_sheet.py` and `pixelize.py`, and visually inspecting contact sheets at final pixel size.
Higgsfield was used because the task explicitly required that backend; the general imagegen
workflow informed the reference conditioning, chroma, framing and post-generation inspection.

## Credits

| Item | Value |
|---|---:|
| Starting balance | 924.55 |
| Preflight | 2 credits per Nano Banana Pro 1K sheet job |
| Submitted jobs | 26 |
| Actual spend | 52.00 |
| Ending balance | 872.55 |

The 26 jobs were 18 first-pass death sheets, one Bulgasari layout retry, four representative
walk sheets, one travel/melee sheet and two magic-impact sheets. As observed in earlier work,
the backend charged per submitted job; the estimate therefore used jobs, not the misleading
multi-result interpretation. Raw output is retained below each monster's `raw/` directory,
under `asset/weapon/raw/`, and under `asset/effect/raw/`. Use of the generated output remains
subject to the Higgsfield workspace's applicable plan and terms.

## Monster set inventory

All rotation counts are 8/8. All deaths use the fixed frame order `0 hit/anticipation`,
`1 collapse`, `2 near-rest`, `3 corpse/rest/dissipation`; every final frame is 92x92 with hard
alpha. For each monster, consuming code should load
`res://asset/monster/<id>/death/0.png` through `3.png` in numeric order. Walk is satisfied by
the procedural contract in `asset/monster/WALK_STATUS.json`, not by generated image frames.

| Monster id | Class height | Rotations | Death | Walk |
|---|---:|---:|---:|---|
| `forest_goblin` | 44 | 8 | 4 existing, pass | procedural |
| `forest_spirit` | 46 | 8 | 4 existing, pass | procedural |
| `bamboo_brute` | 58 | 8 | 4 existing, pass | procedural |
| `bamboo_spirit_lord` | 76 | 8 | 4 existing, pass | procedural |
| `gwimyeon_dokkaebi` | 54 | 8 | 4 new, pass | procedural |
| `blue_dokkaebi` | 50 | 8 | 4 new, pass | procedural |
| `gumiho_scout` | 48 | 8 | 4 new, pass | procedural |
| `seonbi_wraith` | 52 | 8 | 4 new, pass | procedural |
| `haetae_guardian` | 58 | 8 | 4 new, pass | procedural |
| `dokkaebi_king` | 76 | 8 | 4 new, pass | procedural |
| `cheonyeo_gwisin` | 52 | 8 | 4 new, pass | procedural |
| `dalgyal_gwisin` | 44 | 8 | 4 new, pass | procedural |
| `jeoseung_saja` | 58 | 8 | 4 new, pass | procedural |
| `tomb_jangseung` | 58 | 8 | 4 new, pass | procedural |
| `imugi_whelp` | 52 | 8 | 4 new, pass | procedural |
| `ancient_imugi` | 76 | 8 | 4 new, pass | procedural |
| `wonhon` | 50 | 8 | 4 new, pass | procedural |
| `dokkaebi_fire` | 44 | 8 | 4 new, pass | procedural |
| `shadow_dokkaebi` | 52 | 8 | 4 new, pass | procedural |
| `fox_spirit` | 48 | 8 | 4 new, pass | procedural |
| `bulgasari` | 58 | 8 | 4 new, pass | procedural |
| `gumiho` | 76 | 8 | 4 new, pass | procedural |

### New death measurements

The gate requires all three transitions to change at least 64 pixels, the terminal frame to
differ by at least 128 pixels, and the terminal silhouette to retain at most 82% of the first
frame's height or at most 65% of its opaque area. These numbers are intentionally progression
metrics, not the identity gate that correctly rejects walk cycles.

| Set | Consecutive changed pixels | Terminal changed | Final/first height | Final/first area |
|---|---|---:|---:|---:|
| `gwimyeon_dokkaebi` | 1783, 1801, 1048 | 1752 | 0.574 | 0.741 |
| `blue_dokkaebi` | 1545, 1758, 1592 | 1741 | 0.640 | 0.872 |
| `gumiho_scout` | 1624, 1439, 1116 | 1761 | 0.562 | 0.782 |
| `seonbi_wraith` | 1429, 1391, 983 | 1143 | 0.673 | 0.154 |
| `haetae_guardian` | 2698, 2409, 2067 | 2770 | 0.517 | 0.681 |
| `dokkaebi_king` | 3280, 2879, 2531 | 3154 | 0.487 | 0.641 |
| `cheonyeo_gwisin` | 1364, 1219, 702 | 1253 | 0.519 | 0.512 |
| `dalgyal_gwisin` | 1438, 1272, 957 | 1334 | 0.500 | 0.518 |
| `jeoseung_saja` | 1604, 1337, 715 | 1593 | 0.517 | 0.678 |
| `tomb_jangseung` | 1392, 922, 614 | 1040 | 0.224 | 0.324 |
| `imugi_whelp` | 1727, 1567, 1035 | 1334 | 0.346 | 0.539 |
| `ancient_imugi` | 2604, 2557, 1946 | 2447 | 0.417 | 0.583 |
| `wonhon` | 1002, 1210, 963 | 662 | 1.000 | 0.563 |
| `dokkaebi_fire` | 955, 1028, 776 | 929 | 0.318 | 0.112 |
| `shadow_dokkaebi` | 1420, 995, 874 | 1320 | 0.538 | 0.228 |
| `fox_spirit` | 1463, 1442, 1078 | 1254 | 0.562 | 0.206 |
| `bulgasari` | 2583, 2542, 2260 | 2649 | 0.776 | 0.732 |
| `gumiho` | 4036, 2855, 2550 | 4390 | 0.562 | 0.608 |

Full machine-readable measurements are in `asset/character/raw/death_metrics.json`; final and
raw visual audits are `asset/monster/raw/death_frames_overview.png` and
`asset/monster/raw/death_sheet_overview.png`. The first Bulgasari sheet contained five
staggered figures rather than four regular cells and was rejected during layout review; it is
retained as `asset/monster/bulgasari/raw/death_sheet_2026_higgsfield.png`. The accepted retry is
`asset/monster/bulgasari/raw/death_sheet_2026_retry_higgsfield.png`.

## Monster walk: measured negative and procedural resolution

Each trial was conditioned on that monster's reviewed south idle and generated as one two-cell
sheet. Acceptance required at least 60% of change in the lower body, at most two head-silhouette
alpha changes, and a non-identical frame pair. All four body plans failed:

| Trial | Changed vs idle | Lower-body share | Head alpha changes | Pair delta | Result |
|---|---|---|---|---:|---|
| `blue_dokkaebi` humanoid | 1083, 1040 | 36.01%, 37.40% | 26, 4 | 901 | reject |
| `gumiho_scout` quadruped | 1584, 1588 | 33.96%, 34.07% | 135, 132 | 1142 | reject |
| `wonhon` floating spirit | 1493, 1518 | 34.56%, 36.43% | 363, 333 | 1144 | reject |
| `ancient_imugi` serpentine boss | 3192, 3196 | 50.41%, 50.31% | 117, 124 | 1940 | reject |

The results are in `asset/monster/raw/walk_trial_metrics.json`; rejected cut frames and raw
sheets remain under each trial monster's `raw/walk_trial/`. The model changed heads, upper
silhouettes and body proportions more than a stable walk permits. More credits would repeat the
four already-rejected character-motion methods, so a usable image walk now requires human pixel
animation rather than diffusion.

Combat/core integration required for the recorded substitute:

1. While a monster's velocity is non-zero and death is not active, animate the Sprite2D's local
   integer position at 8 Hz through `(0,0), (0,-1), (0,-2), (0,-1)`.
2. Use no scaling, rotation, interpolation or subpixel movement.
3. Reset immediately to `(0,0)` when stopped, hit-stunned or entering death; death playback then
   owns the sprite.

## Projectiles in flight

All five sprites are 32x32 transparent canvases, authored pointing east (`+X`) with readable
head/tail silhouettes. Rotate the sprite so local `+X` follows the projectile velocity.

| Id | Path | Content bbox | Opaque / bright-core pixels |
|---|---|---:|---:|
| `spinning_talisman` | `res://asset/weapon/travel/spinning_talisman.png` | 21x14 | 118 / 19 |
| `arrow` | `res://asset/weapon/travel/arrow.png` | 27x10 | 175 / 13 |
| `fireball` | `res://asset/weapon/travel/fireball.png` | 26x14 | 235 / 72 |
| `throwing_knife` | `res://asset/weapon/travel/throwing_knife.png` | 31x10 | 194 / 28 |
| `spirit_bolt` | `res://asset/weapon/travel/spirit_bolt.png` | 24x12 | 159 / 64 |

The 8-16px readability target is met on each projectile's cross-section (10-14px); elongated
heads/tails intentionally use more width so direction remains readable. Raw source and cells:
`asset/weapon/raw/combat_travel_melee_sheet_higgsfield.png` and
`asset/weapon/raw/combat_travel_melee_cells/`.

## Melee swings

All four are 64x64 and use east (`+X`) as the canonical aim direction. Rotate around the
attacker. `dual_blade_cross` is intentionally rotationally symmetric; its cross silhouette
communicates the attack family rather than a leading edge.

| Id | Path | Content bbox | Opaque / bright-core pixels |
|---|---|---:|---:|
| `wide_sword_arc` | `res://asset/weapon/melee/wide_sword_arc.png` | 39x44 | 809 / 465 |
| `dual_blade_cross` | `res://asset/weapon/melee/dual_blade_cross.png` | 46x48 | 898 / 272 |
| `heavy_overhead` | `res://asset/weapon/melee/heavy_overhead.png` | 50x48 | 932 / 284 |
| `spear_thrust` | `res://asset/weapon/melee/spear_thrust.png` | 64x19 | 570 / 157 |

Machine-readable travel/melee measurements are in
`asset/weapon/raw/combat_art_metrics.json`; the inspected contact sheet is
`asset/weapon/raw/combat_art_overview.png`.

## Magic travel/impact pairs

Effects always play `0 anticipation`, `1 expansion`, `2 peak`, `3 dissipation`.

| Travel art | Arrival art | Impact bright cores | Impact frame deltas |
|---|---|---|---|
| `res://asset/weapon/travel/spinning_talisman.png` | `res://asset/effect/talisman_burst/{0..3}.png` | existing | existing |
| `res://asset/weapon/travel/fireball.png` | `res://asset/effect/fireball_impact/{0..3}.png` | 4, 196, 1851, 7 | 886, 2893, 2893 |
| `res://asset/weapon/travel/spirit_bolt.png` | `res://asset/effect/spirit_bolt_impact/{0..3}.png` | 29, 478, 535, 0 | 686, 1179, 1006 |
| `res://asset/weapon/travel/arrow.png` | `res://asset/effect/impact_hit/{0..3}.png` | existing generic | existing |
| `res://asset/weapon/travel/throwing_knife.png` | `res://asset/effect/impact_hit/{0..3}.png` | existing generic | existing |

The two new impacts pass the mobile-readability/progression gate. Their inspected contact sheet
is `asset/effect/raw/paired_impact_overview.png`; detailed numbers are folded into
`asset/effect/raw/effect_metrics.json`.

## Classification of the original thirteen effect sets

- Arrival/impact: `talisman_burst`, `impact_hit`, `lightning`.
- Stationary area/aura: `spirit_flame`, `fire`, `poison_cloud`, `ward_barrier`, `seal_field`.
- Summon telegraph/aura: `summon_circle`.
- Directional attack art: `slash` (melee swing), `spirit_beam` (channelled beam).
- Presentation flourishes: `level_up`, `evolution_flourish`.

`fire` is the only ambiguous filename: it is a stationary flame bloom, not a fireball in
flight. Nothing was silently recategorised or regenerated.

## Verification

All commands exited 0 from the repository root.

```text
> godot --headless --path . --import
[no stdout]
exit 0

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
exit 0

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
exit 0
```

The validator also printed its existing warning once per monster that loading a PNG directly
as an Image will not work on export; no validation error accompanied those warnings.

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
Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed
exit 0
```

The verifier now binds all 25 death sets to their progression metrics, all 15 effect sets to
their readability metrics, all 22 monster walks to the measured procedural-resolution record,
and all nine canonical travel/melee sprites to their east-orientation/readability record. It
also rejects an opaque sheet grid line retained on a checked animation or combat-art edge.
