# Asset expansion round report

## Outcome

This batch ships seven measured four-frame death sequences, 144 directional frames for the
eighteen folklore monsters, four summon creatures, three four-frame spiritual effects, and ten
new weapon/evolution pairs with both 32px icons and 64px gameplay art. The existing character
walk/attack decision is unchanged: generated identity-preserving motion failed four prior gates,
so those animations remain procedural; death passed because progressive silhouette collapse is
the intended result rather than an error.

Higgsfield balance was `1002.55` before generation and `940.55` afterward: **62 credits spent**
for 31 submitted sheet jobs. Preflight reported 2 credits per submitted job, and actual billing
matched that corrected per-job estimate exactly.

## Death motion: accepted

Frame order for every sequence is `0, 1, 2, 3`: upright/stagger, active collapse, prone or
dissolving peak, terminal corpse/dissipation. Play once and hold or remove frame 3; never loop.

| Sequence | Shipped path | Consecutive changed pixels | Terminal change | Final/first height | Final/first area | Result |
|---|---|---:|---:|---:|---:|---|
| Taoist | `asset/character/Taoist/Death/{0..3}.png` | 1090, 1520, 1419 | 1220 | 0.451 | 0.823 | pass |
| Warrior | `asset/character/Warrior/Death/{0..3}.png` | 930, 1430, 919 | 1450 | 0.482 | 0.788 | pass |
| Archer | `asset/character/Archer/Death/{0..3}.png` | 1607, 1885, 1689 | 1887 | 0.643 | 0.744 | pass |
| forest_goblin | `asset/monster/forest_goblin/death/{0..3}.png` | 4516, 1979, 1334 | 4614 | 0.315 | 0.201 | pass |
| forest_spirit | `asset/monster/forest_spirit/death/{0..3}.png` | 2505, 2840, 1294 | 2854 | 0.228 | 0.022 | pass |
| bamboo_brute | `asset/monster/bamboo_brute/death/{0..3}.png` | 2282, 2660, 2116 | 2807 | 0.565 | 0.555 | pass |
| bamboo_spirit_lord | `asset/monster/bamboo_spirit_lord/death/{0..3}.png` | 2947, 3020, 2326 | 2861 | 1.108 | 0.095 | pass |

The lord's final height ratio exceeds 1 because its last frame contains a high drifting mote;
opaque area falls to 9.5%, so the terminal dissipation still passes. The reproducible evidence is
in `asset/character/raw/death_metrics.json`, and every source sheet/cell remains in the relevant
`raw/` directory.

## Folklore monster rotations

Every set uses a 92x92 canvas. Runtime direction order is:

`south, south-east, east, north-east, north, north-west, west, south-west`

Load each as `asset/monster/<id>/rotations/<direction>.png`. Existing flat
`asset/monster/<id>.png` files are deliberately untouched, so current data paths and collision
radius validation remain stable.

| id | content height | frames |
|---|---:|---:|
| gwimyeon_dokkaebi | 54 | 8 |
| blue_dokkaebi | 50 | 8 |
| gumiho_scout | 48 | 8 |
| seonbi_wraith | 52 | 8 |
| haetae_guardian | 58 | 8 |
| dokkaebi_king | 76 | 8 |
| cheonyeo_gwisin | 52 | 8 |
| dalgyal_gwisin | 44 | 8 |
| jeoseung_saja | 58 | 8 |
| tomb_jangseung | 58 | 8 |
| imugi_whelp | 52 | 8 |
| ancient_imugi | 76 | 8 |
| wonhon | 50 | 8 |
| dokkaebi_fire | 44 | 8 |
| shadow_dokkaebi | 52 | 8 |
| fox_spirit | 48 | 8 |
| bulgasari | 58 | 8 |
| gumiho | 76 | 8 |

Visual inspection confirmed distinct front, oblique, side, and rear silhouettes in all eighteen
sheets. These rotations are usable idle authorities, but they are not new monster data entries;
content/runtime owners must add any rotation map without replacing the validated flat sprite.

## Summons and spiritual effects

Static summon IDs and paths:

| id | path | canvas | content height |
|---|---|---:|---:|
| paper_familiar | `asset/summon/creatures/paper_familiar.png` | 92x92 | 46 |
| haetae_cub | `asset/summon/creatures/haetae_cub.png` | 92x92 | 52 |
| three_legged_crow | `asset/summon/creatures/three_legged_crow.png` | 92x92 | 48 |
| turtle_serpent_guardian | `asset/summon/creatures/turtle_serpent_guardian.png` | 92x92 | 58 |

Effect paths are `asset/effect/<id>/{0..3}.png`, all 64x64. Frame order is anticipation,
expansion, peak, dissipation.

| id | bright-core pixels by frame | changed pixels | result |
|---|---:|---:|---|
| ward_barrier | 14, 84, 358, 107 | 1582, 2111, 1833 | pass |
| spirit_beam | 37, 156, 296, 38 | 597, 1486, 1536 | pass |
| seal_field | 98, 299, 439, 86 | 1667, 2302, 1873 | pass |

The first beam cut failed honestly because its peak covered 95.31% of the canvas. Recutting the
same raw sheet at common full-cell scale reduced the footprint while retaining progression; the
second cut passed. No regeneration or additional credit was used. Together with the earlier ten
sets, all thirteen effect sequences now pass `measure_effect_sheets.py`.

Suggested mechanics: `summon_circle` can spawn any of the four creature IDs; `ward_barrier`
supports a timed shield, `spirit_beam` a channelled directional skill, and `seal_field` persistent
area denial.

## Weapons

Each ID has `asset/weapon/icons/<id>.png` (32x32) and
`asset/weapon/projectiles/<id>.png` (64x64):

`spear, dragon_spear, moon_dual_sword, storm_dual_sword, axe, tiger_axe,
throwing_knife, rain_of_knives, poison_knife, hundred_poison_blade`

Evolution pairs are spear -> dragon_spear, moon_dual_sword -> storm_dual_sword, axe ->
tiger_axe, throwing_knife -> rain_of_knives, and poison_knife -> hundred_poison_blade. The icon
generator added English captions and used a 6+4 layout despite the 5x2 request; asymmetric slicing
removed the caption band before pixelization, and inspection confirmed no lettering survives in
the shipped icons.

## Passive/trait decision

No duplicate passive assets were generated. The eight existing icons already give each frozen
stat a distinct 32px silhouette; rarity/tier should be encoded by shared level-up-card chrome,
stars, or a numeric badge so the semantic glyph remains stable and the UI does not depend on
colour alone.

## Required integration outside this worktree

- Combat/runtime: play the death paths above at `0 -> 1 -> 2 -> 3`, non-looping, and stop the
  procedural bob once death begins.
- Monster presentation: select `rotations/<direction>.png` for the eighteen IDs while keeping
  each current flat sprite as the data authority until content-data adds a rotation field.
- Content-data: add the five base/evolution weapon pairs and four summon IDs only after choosing
  stats, triggers, collision radii, and unlock rules; this asset worktree intentionally did not
  edit `data/**`.
- Combat/VFX: load each effect in numeric order at 64x64; anchor barrier and seal field at their
  centers, and orient the beam in the cast direction.

## Verification (real output)

```text
> godot --headless --path . --import
exit 0 (no stdout)

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
exit 0

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
exit 0
```

The validator also emitted its existing `Loaded resource as image file, this will not work on
export` warning once for each of the 22 flat monster sprites while checking real pixel width; no
warning was introduced by repointing data because no data path was changed.

```text
> python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 4 chrome assets, 34 weapon assets, 2 characters, 2 seamless tiles, 6 audio files
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props
Six multi-reference motion sheets rejected: 0/96 frames passed the regional stability gate
Expansion assets verified: 18 folklore monsters + 144 rotations, 52 effect frames, 12 structures, 3 title assets
Round-two additions verified: 28 death frames, 4 summoned creatures, 20 weapon icons/projectiles
exit 0
```

Higgsfield-generated images follow Higgsfield's applicable workspace terms; no third-party stock
or separately licensed source art was added.
