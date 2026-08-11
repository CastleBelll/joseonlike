# Loot Drops and Bamboo Spirit Lord Scale Report

## Shipped inventory

All pickup art uses hard alpha and pure-black outlines. Idle sprites are `24x24` canvases;
the subject height is intentionally limited to the requested 8--16px ground-pickup range.
Every collect sequence uses a `32x32` fixed canvas and frame order `0 anticipation`,
`1 expansion`, `2 peak`, `3 dissipation`.

| id | idle path | content bbox | collect path |
|---|---|---:|---|
| `xp_small` | `asset/drop/xp_small/idle.png` | 8x8 | `asset/drop/xp_small/collect/{0..3}.png` |
| `xp_medium` | `asset/drop/xp_medium/idle.png` | 14x12 | `asset/drop/xp_medium/collect/{0..3}.png` |
| `xp_large` | `asset/drop/xp_large/idle.png` | 20x16 | `asset/drop/xp_large/collect/{0..3}.png` |
| `gold_coin` | `asset/drop/gold_coin/idle.png` | 9x10 | `asset/drop/gold_coin/collect/{0..3}.png` |
| `gold_pile` | `asset/drop/gold_pile/idle.png` | 23x16 | `asset/drop/gold_pile/collect/{0..3}.png` |
| `health_gourd` | `asset/drop/health_gourd/idle.png` | 14x16 | `asset/drop/health_gourd/collect/{0..3}.png` |
| `magnet` | `asset/drop/magnet/idle.png` | 18x16 | `asset/drop/magnet/collect/{0..3}.png` |
| `chest_common` | `asset/drop/chest_common/idle.png` | 14x16 | `asset/drop/chest_common/collect/{0..3}.png` |
| `chest_rare` | `asset/drop/chest_rare/idle.png` | 17x16 | `asset/drop/chest_rare/collect/{0..3}.png` |
| `chest_epic` | `asset/drop/chest_epic/idle.png` | 17x16 | `asset/drop/chest_epic/collect/{0..3}.png` |
| `chest_legendary` | `asset/drop/chest_legendary/idle.png` | 14x16 | `asset/drop/chest_legendary/collect/{0..3}.png` |
| `chest_mythic` | `asset/drop/chest_mythic/idle.png` | 16x16 | `asset/drop/chest_mythic/collect/{0..3}.png` |

The grade chests do not depend on hue alone: common is a rectangular iron-bound box, rare
adds a diamond silhouette, epic has a round/spiked silhouette, legendary has a crowned
hexagonal silhouette, and mythic uses a lotus/halo silhouette. The automated pair gate found
at least eight changed alpha pixels for every one of the ten grade pairs.

The XP tier opaque areas are 40, 111 and 210 pixels, strictly increasing. Every pickup's
four collect frames is byte-distinct; consecutive changed-pixel counts are retained in
`asset/drop/raw/drop_metrics.json`. The visual contact sheet is
`asset/drop/raw/drop_contact_sheet.png`; the three original sheets remain beside it.

I included the magnet. The current runtime's ordinary attraction radius is only 90px, so a
temporary screen-wide vacuum creates the familiar end-of-wave recovery beat and gives the
player a useful positioning reward rather than duplicating an existing pickup.

## Existing XP art assessment

`asset/ui/currency/xp.png` is a 32px HUD diamond, while the live in-world pickup was a green
16px solid placeholder rendered around 6--7px after runtime scale. The new ground XP is
conceptually consistent with the HUD icon (cyan diamond/crystal and bright core), but it is
authored to a different, appropriate standard: three ground-readable sizes, pure-black
silhouette, and collect feedback. The old runtime placeholder is not consistent with either
the HUD art or this set and should be replaced by the new paths.

## Bamboo spirit lord

The replacement flat sprite is `asset/monster/bamboo_spirit_lord.png`, exactly `120x150`
content and canvas. Eight rotations are in
`asset/monster/bamboo_spirit_lord/rotations/<direction>.png`, each on `192x192`, in the
standard order `south`, `south-east`, `east`, `north-east`, `north`, `north-west`, `west`,
`south-west`; content heights are all 150 and widths are respectively
120, 106, 70, 115, 111, 111, 71 and 97.

The death sequence is `asset/monster/bamboo_spirit_lord/death/{0..3}.png`, frame order
`standing collapse`, `sag`, `spirit breakup`, `root-pile terminal`. Its irreversible-collapse
gate passed with consecutive changed pixels `[8838, 7717, 7331]`, terminal delta 9466,
terminal height ratio 0.762, and terminal opaque-area ratio 0.264.

The first two boss sheets were rejected because they reinvented the bamboo spirit as a human
elder; they remain in `asset/monster/bamboo_spirit_lord/raw/` as negative evidence. The retry
preserved the grey spirit mask and bamboo crown, and a deterministic post-cut remap removed
remaining human skin hues from hands and ears. I inspected the rebuilt contact sheet cell by
cell: southern views show the mask, east/west are opposing profiles, northern views show the
back, and all adjacent views remain distinguishable. The hash-bound facing audit was renewed
only after that review.

`data/monsters.json` must be updated by content-data, not this worktree. The new true width is
120px, so validation permits at most a 60px collision radius; a 48--50px starting radius is a
reasonable visual fit but should be confirmed in play rather than copied blindly.

## Integration notes

Combat should load the idle path for a stationary drop and play the four collect frames in
ascending numeric order before freeing the pickup. Chest grade ids map directly to GDD grades.
No scenery was added in this batch; if the parallel walkable-camp rebuild needs more than
`asset/structure/`, that should be a scoped follow-up.

## Generation and credits

Higgsfield Nano Banana Pro 1K preflight reported 2 credits per submitted job. Seven jobs were
submitted: three loot sheets, two rejected initial boss sheets, and two accepted boss retries.
The balance moved from **854.55 to 840.55 credits: 14.00 credits spent**, exactly matching the
per-submitted-job estimate.

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

The data validator additionally emitted its existing `Loaded resource as image file, this will
not work on export` warning once for each monster PNG; these warnings do not fail validation and
this asset-owned worktree did not modify the validator.

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
UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed
exit 0
```
