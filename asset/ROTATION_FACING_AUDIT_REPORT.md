# Rotation-facing audit report

Date: 2026-08-11

Base merged before work: `origin/main` at `70749fe`

Direction order: `south, south-east, east, north-east, north, north-west, west, south-west`

## Outcome

All three character sets and all 22 monster sets were rebuilt as contact sheets and
visually reviewed. The final 25 sets satisfy the semantic rule: the three southern
views show the face, east/west are opposite profiles, and the three northern views
show the back. Adjacent directions remain visibly distinguishable.

The full initial finding list is preserved in
`asset/rotation_audit/INITIAL_FACING_AUDIT.md`. The first visual pass identified:

| Set | Cells that failed before regeneration |
|---|---|
| Warrior | east, north-west, west |
| Archer | east, north-east, north-west, south-west |
| bamboo_brute | north-east, north-west, south-west |
| bamboo_spirit_lord | north-east, north-west |
| cheonyeo_gwisin | all eight (the old five-column source had been sliced as four) |
| forest_spirit | north-east, north-west |
| gumiho | south-east, north-east, north, north-west |

A stricter second east/west pass exposed three misses in that first list:
`gumiho/west`, `imugi_whelp/west`, and `tomb_jangseung/west` duplicated the east-facing
profile. This is recorded rather than hidden. Their accepted east sprites were reflected
exactly into west, preserving the approved identity while guaranteeing the opposite facing.

## Generated and retained

Seven complete sets were regenerated as one conditioned sheet per set, then sliced and
cut through `pixelize.py` against the Taoist rotation palette:

- `asset/character/Warrior/Idle/rotations/*.png`
- `asset/character/Archer/Idle/rotations/*.png`
- `asset/monster/bamboo_brute/rotations/*.png`
- `asset/monster/bamboo_spirit_lord/rotations/*.png`
- `asset/monster/cheonyeo_gwisin/rotations/*.png`
- `asset/monster/forest_spirit/rotations/*.png`
- `asset/monster/gumiho/rotations/*.png`

The raw sheets and sliced raw cells remain under each set's `raw/` directory. The first
`bamboo_brute` generation invented a club, so it was rejected and retained as
`asset/monster/bamboo_brute/raw/facing_fix_sheet_higgsfield.png`; the accepted empty-handed
retry is `asset/monster/bamboo_brute/raw/facing_fix_sheet_retry_higgsfield.png`.

Three narrowly corrected profiles are:

- `asset/monster/gumiho/rotations/west.png`
- `asset/monster/imugi_whelp/rotations/west.png`
- `asset/monster/tomb_jangseung/rotations/west.png`

The 16 sets left unchanged are Taoist, ancient_imugi, blue_dokkaebi, bulgasari,
dalgyal_gwisin, dokkaebi_fire, dokkaebi_king, forest_goblin, fox_spirit,
gumiho_scout, gwimyeon_dokkaebi, haetae_guardian, jeoseung_saja, seonbi_wraith,
shadow_dokkaebi, and wonhon. `dokkaebi_fire` is nearly symmetric, but it still has
unambiguous front eyes, an unmarked back, and the lateral eye on opposite sides; it does
not require removal of directional rotations.

No `data/**`, `scripts/**`, or `scenes/**` file was changed. Existing consumers already
use the same paths, so no coordinator-side path or frame-order change is required.

## Per-set inventory

Legend: `S, SE, E, NE, N, NW, W, SW` are the eight files in the required order.
“Documented otherwise” is reserved for a creature intentionally treated as non-directional.

| Set | Members present | Documented otherwise | Missing |
|---|---|---|---|
| Taoist | S, SE, E, NE, N, NW, W, SW | none | none |
| Warrior | S, SE, E, NE, N, NW, W, SW | none | none |
| Archer | S, SE, E, NE, N, NW, W, SW | none | none |
| ancient_imugi | S, SE, E, NE, N, NW, W, SW | none | none |
| bamboo_brute | S, SE, E, NE, N, NW, W, SW | none | none |
| bamboo_spirit_lord | S, SE, E, NE, N, NW, W, SW | none | none |
| blue_dokkaebi | S, SE, E, NE, N, NW, W, SW | none | none |
| bulgasari | S, SE, E, NE, N, NW, W, SW | none | none |
| cheonyeo_gwisin | S, SE, E, NE, N, NW, W, SW | none | none |
| dalgyal_gwisin | S, SE, E, NE, N, NW, W, SW | none | none |
| dokkaebi_fire | S, SE, E, NE, N, NW, W, SW | none | none |
| dokkaebi_king | S, SE, E, NE, N, NW, W, SW | none | none |
| forest_goblin | S, SE, E, NE, N, NW, W, SW | none | none |
| forest_spirit | S, SE, E, NE, N, NW, W, SW | none | none |
| fox_spirit | S, SE, E, NE, N, NW, W, SW | none | none |
| gumiho | S, SE, E, NE, N, NW, W, SW | none | none |
| gumiho_scout | S, SE, E, NE, N, NW, W, SW | none | none |
| gwimyeon_dokkaebi | S, SE, E, NE, N, NW, W, SW | none | none |
| haetae_guardian | S, SE, E, NE, N, NW, W, SW | none | none |
| imugi_whelp | S, SE, E, NE, N, NW, W, SW | none | none |
| jeoseung_saja | S, SE, E, NE, N, NW, W, SW | none | none |
| seonbi_wraith | S, SE, E, NE, N, NW, W, SW | none | none |
| shadow_dokkaebi | S, SE, E, NE, N, NW, W, SW | none | none |
| tomb_jangseung | S, SE, E, NE, N, NW, W, SW | none | none |
| wonhon | S, SE, E, NE, N, NW, W, SW | none | none |

No creature was classified as lacking a meaningful front. `dokkaebi_fire` is the closest
case because its flame silhouette is nearly radial, but its face is visible in S/SE/SW,
absent in NE/N/NW, and its single lateral eye swaps sides between E and W. That makes its
directional set meaningful at gameplay scale. `forest_spirit` is also shape-symmetric, but
its pale front torso versus solid dark rear supplies a readable front/back cue.

## Facing verification design

`tools/asset/build_rotation_contact_sheets.py` creates deterministic per-set sheets and
four overview pages. `tools/asset/audit_rotation_facing.py --write` only records approval
when every contact sheet exactly matches the current source cells, then stores the expected
semantic label and SHA-256 for all 200 cells plus the contact sheets. `verify_assets.py`
now fails if a direction label, reviewed cell, contact sheet, or set coverage changes; it
also requires exact opposing mirrors for the three repaired same-facing profile pairs.

A universal pixel threshold was measured and rejected as the primary classifier. Correct
asymmetric sprites such as `gwimyeon_dokkaebi` had an east/west mirror/direct ratio of
1.59, while several visually correct front/back groups had cross-group distance no larger
than within-group drift. A hash-bound semantic review catches the known gumiho regression
without false-rejecting weapons, tails, or deliberately asymmetric silhouettes.

## Higgsfield credits

- Starting balance: 940.55
- Preflight: Nano Banana Pro, 1K, 16:9, 2 credits per submitted job
- Jobs submitted: 8 (seven sets plus the bamboo brute retry)
- Actual spend: 16.00 credits
- Ending balance: 924.55

## Verification output

All required commands exited 0.

### `godot --headless --path . --import`

```text
(no stdout)
```

### `godot --headless --path . --quit`

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

### `godot --headless --path . --script tools/validate_data.gd`

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

PASS data validation: no errors
```

Godot additionally emitted the existing “Loaded resource as image file” warning for the
22 flat monster sprites inspected by `tools/validate_data.gd`; these warnings do not affect
the exit status and no flat monster sprite or data record changed in this task.

### `python tools/asset/verify_assets.py`

```text
M1 assets verified: 20 UI icons + 4 chrome assets, 34 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props
Six multi-reference motion sheets rejected: 0/96 frames passed the regional stability gate
Expansion assets verified: 18 folklore monsters + 144 rotations, 52 effect frames, 12 structures, 3 title assets
Round-two additions verified: 28 death frames, 4 summoned creatures, 20 weapon icons/projectiles
Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed
```
