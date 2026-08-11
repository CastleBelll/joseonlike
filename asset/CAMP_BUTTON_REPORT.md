# Camp Ground and Button Redesign Report

## Outcome

The base camp now has a warm, inhabited ground family that is visually and
measurably separate from the Bamboo Forest combat tile. Three complete button
directions were authored and measured; **royal seal** is the shipped canonical
direction because it has the clearest Joseon identity, the strongest focus cue,
and an unmistakable physical pressed state without leaving the established ink,
vermilion, paper and gold family.

## Audit before generation

- `scripts/ui/camp.gd` currently loads
  `res://asset/stage/bamboo_forest_ground.png` as `GROUND_TEXTURE`, confirming
  that the safe hub and hunting ground are literally using the same art.
- The existing camp already had four buildings plus stone-lantern and jangseung
  scenery. It had no camp-owned ground, path, approach, threshold or boundary art.
- The previous canonical button set had normal, hover and pressed images only.
  Disabled reused a tinted normal texture in `scripts/ui/palette.gd`.
- The previous buttons were nearly plain nested rectangles. The hover fill was
  the known `#cd5137` pairing at 3.76:1 against the light button text, below the
  WCAG AA 4.5:1 target.
- Panel chrome, version plaque and list rows used the same palette, but the
  version plaque was the closest interactive-family neighbour and needed to
  follow the selected button motif. Panel and list-row furniture are content
  containers, not controls; they do not need replacement for this direction.

## Camp ground set

Higgsfield Nano Banana Pro produced two 1024px concepts conditioned on the
existing Bamboo Forest ground and Joseon gate. Both generator outputs are kept
for recutting:

- `asset/camp/raw/camp_ground_concept_a.png`
- `asset/camp/raw/camp_ground_concept_b.png`

Both were cut through `tools/asset/pixelize.py` against
`asset/character/Taoist/Idle/rotations`, then limited to 32 colours and given
exact terminal seams by `tools/asset/build_camp_ground.py`.

| Asset | Canvas | Colours | Use |
|---|---:|---:|---|
| `asset/camp/ground/courtyard.png` | 256x256 | 32 | Recommended camp ground: swept warm earth and an inhabited flagstone crossroads |
| `asset/camp/ground/flagstone.png` | 256x256 | 32 | Denser plaza/ceremonial courtyard alternative |
| `asset/camp/transition/path_overlay_north.png` | 256x256 | 23 | Transparent north-south worn path overlay; rotate in 90-degree increments |
| `asset/camp/transition/gate_approach_north.png` | 256x256 | 22 | Path plus two-rail threshold for the existing Joseon gate; rotate in 90-degree increments |
| `asset/camp/transition/boundary_north.png` | 256x256 | 5 | Ditch/stone-curb safe-zone edge, intended beneath fence or gate art; rotate in 90-degree increments |

The two opaque ground tiles are exactly seamless on both axes. The transition
pieces intentionally are overlays rather than standalone seamless tiles: their
transparent ends and distinct north edge carry the transition meaning.
All deliverables use hard alpha. The Bamboo Forest ground's mean RGB brightness
is **28.99**; the camp courtyard is **155.74**, a deliberate 126.75-point lift
that reads as warm, inhabited and safe rather than as another combat arena.
The visual QA composite at the current 540x960 building coordinates is
`asset/camp/raw/camp_layout_preview.png`; it is reference-only, not a runtime asset.

### Meta-UI integration

No scene or script was edited in this worktree. Meta-UI should:

1. Change `scripts/ui/camp.gd` `GROUND_TEXTURE` from
   `res://asset/stage/bamboo_forest_ground.png` to
   `res://asset/camp/ground/courtyard.png`.
2. Place `path_overlay_north.png` over the courtyard between building entries.
3. Place `gate_approach_north.png` beneath `asset/structure/joseon_gate.png`.
4. Place `boundary_north.png` beneath `asset/structure/wooden_fence.png` and at
   open map edges. Rotate any of the three north-authored overlays by 0/90/180/270
   degrees; do not create direction copies.

The current camp code stretches one 256px ground sprite to 540x960. The new
crossroads composition still works under that implementation, while the exact
seams also support a later repeated-tile implementation without new art.

## Button directions

Every direction contains `normal`, `hover`, `pressed` and `disabled` as 64x32
nine-slices. Margins are **left 6, top 8, right 6, bottom 8**.

### A. Royal seal — selected and shipped

Paths:

- Canonical: `asset/ui/chrome/button_{normal,hover,pressed,disabled}_9slice.png`
- Review copy: `asset/ui/chrome/candidates/royal_seal/`

Why ship it: the clipped vermilion seal, gold focus brackets and ink impression
feel specific to the Joseon visual language without becoming ornate at phone
size. Normal contrast is 7.34:1, hover is 15.55:1, and pressed is 7.34:1.
Pressed differs from normal in 316 pixels, including 140 alpha/silhouette pixels:
the entire face moves down two pixels, a top recess opens, and the lower foot
thickens. Disabled has a broken frame and diagonal hatching, so neither pressed
nor disabled relies on colour alone.

### B. Ink tablet — complete alternative

Path: `asset/ui/chrome/candidates/ink_tablet/`

A heavy scholar's inkstone with binding tabs. It is maximally legible
(15.55:1 for normal, hover and pressed), but reads more severe and modern than
the selected seal. Pressed differs in 710 pixels with 200 alpha changes.

### C. Knotted talisman — complete alternative

Path: `asset/ui/chrome/candidates/knotted_talisman/`

A dark talisman body with paper/gold side knots. It is the most distinctive
silhouette and keeps 15.55:1 enabled-state contrast, but its projecting knots
consume more horizontal space when many compact buttons are stacked. Pressed
differs in 452 pixels with 132 alpha changes.

The side-by-side review sheet is
`asset/ui/raw/button_redesign/button_directions_overview.png`; exact evidence is
in `asset/ui/chrome/button_redesign_metrics.json`.

### UI-family follow-through

- `asset/ui/main/version_plaque_9slice.png` was updated in place with the
  selected seal's paired corner impressions and gold top key. Its margins remain
  **8px on all sides**, so `scripts/ui/title.gd` consumes it without code changes.
- `asset/ui/chrome/panel_9slice.png` and `asset/ui/meta/list_row_9slice.png` do
  **not** need to follow. They remain paper content containers, while the selected
  direction reserves the stronger ink/vermilion seal silhouette for actions.
- Canonical normal/hover/pressed paths are unchanged, so every existing
  `UiPalette.apply_button_style` call picks up the redesign automatically.
- Meta-UI should preload
  `res://asset/ui/chrome/button_disabled_9slice.png` and use it for the disabled
  style instead of tinting the normal texture. Until that small code change, the
  authored disabled state exists but is not consumed.

## Credits

- Balance before: **832.55**
- Preflight quote: **2 credits** for two results
- Balance after: **828.55**
- Actual spend: **4.00 credits**

As seen in earlier batches, the backend charged each submitted result as a job,
so the actual spend was twice the two-result preflight quote.

## Verification

`tools/asset/verify_assets.py` now requires both seamless camp grounds, all
three overlays, the brightness separation, all 12 button candidate images,
canonical-to-selected byte identity, enabled-state AA contrast, and pressed
alpha-shape differences.

All four required commands exited 0. Real output:

```text
> godot --headless --path . --import
[no stdout; exit 0]

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
```

The validator also emitted its pre-existing `Loaded resource as image file`
warning once for each of the 22 monster flat sprites; there was no validation
error and the command exited 0.

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
Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed
Character near-duplicate gate verified: 84 pairs at mean-RGBA threshold 2.50; minima: Taoist 5.11 (east/west), Warrior 2.88 (north-east/north), Archer 4.58 (north-west/south-west)
UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed
Camp identity verified: 2 warm seamless tiles + 3 rotatable north-facing transition overlays
Button redesign verified: 3 directions x 4 states; selected royal_seal, 6x8 margins, WCAG-AA/pressed-shape gates passed
```
