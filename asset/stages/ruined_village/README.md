# Night ruined-village terrain kit

This is the second-night ruined-village kit. Its canvas scale follows the
bamboo-forest set: art is authored at gameplay resolution, quantized without
dithering, then exported at 16x with nearest-neighbour sampling.

## Asset contract

| File | Logical size | Role |
| --- | ---: | --- |
| `ground_tile.png` | 32x32 | Opaque seamless scorched/ash courtyard soil |
| `ground_variants/ash_drift.png` | 32x32 | Ash accumulation variant |
| `ground_variants/scorched_earth.png` | 32x32 | Burn-scar variant |
| `ground_variants/broken_paving.png` | 32x32 | Broken flat-stone variant |
| `props/burnt_beam.png` | 20x16 | Solid, breakable rafters |
| `props/collapsed_roof.png` | 24x18 | Solid roof-tile rubble |
| `props/broken_wall.png` | 20x16 | Solid, breakable mud wall |
| `props/charred_stump.png` | 16x16 | Solid, breakable stump |
| `props/ash_pile.png` | 16x10 | Non-colliding decor |
| `props/broken_jar.png` | 12x12 | Non-colliding decor |
| `props/scorched_post.png` | 16x40 | Non-colliding decor |
| `props/ember_glow.png` | 16x12 | Non-colliding decor |

Every prop has binary alpha and at most 6 opaque colours. The four ground
tiles use 4 flat colours. No asset contains an antialiased edge, gradient, or
dither pattern.

`contact-sheet.png` places the ruined props at gameplay size beside the bamboo
forest's fallen log, small rock, and shrine post. `ground-verification.png`
shows an 8x8 runtime-style mix with per-tile rotations and the three variants
composited at the game's 68% alpha. `prop-comparison.png` is the blind [C]
check: all eight props in one unlabeled row at 3x gameplay size (36-72px wide).

## Second-pass self-check

- [A] The bamboo anchor's 64 4x4-block luminance means span 6.3758, or 2.500%
  of the full 0-255 luminance range. The revised ruined-village base span is
  0.0000 (0.000%): every block has identical four-colour counts with a unique
  hashed order, so the tile has grain but no named or repeating motif.
- [B] Base mean RGB is `(23.625, 26.312, 27.000)`. Absolute per-channel mean
  differences are ash drift `(7.375, 7.312, 7.250)`, scorched earth
  `(5.188, 5.750, 6.312)`, and broken paving `(4.188, 4.125, 4.062)`; every
  channel is below the required 24.
- [C] Geometry checks require two crossed beam parallelograms, four diagonal
  roof ridges, the wall's long horizontal crown and vertical cut, two stump
  rings, an ash-pile visible-bounds ratio of 3.20:1, three connected jar
  components (body + two shards), a post ratio above 2.5:1, and a uniquely
  high-chroma ember core. The unlabeled comparison was inspected at
  `asset/stages/ruined_village/prop-comparison.png`; all eight silhouettes are
  distinguishable.

## Generation record

The first pass used built-in image generation for one source image per asset.
After two silhouette rejections, those generated sources were removed from the
shipping path: the current ground and props are authored directly at logical
resolution by `build_assets.py`. This makes every required line, curve, ring,
ridge, detached shard, and palette limit measurable and repeatable. The bamboo
contact sheet still establishes logical-pixel density and night lighting; the
regenerated `rusted_armor` and `ash_wraith` idles establish the second-night
charcoal, ash, soot-brown, and restrained rust-orange palette.

Shared prop prompt:

```text
Use case: stylized-concept
Asset type: isolated top-down/three-quarter pixel-art game prop sprite
Style references: bamboo contact sheet for chunky logical-pixel density, hard
1px near-black outline, simple silhouette, bottom-grounded placement and dark
night lighting; rusted armor and ash wraith for the ruined-village charcoal,
ash gray, soot brown and restrained rust-orange palette.
Style: deliberately chunky pixel art for a 38px-tall in-world character; flat
fills; 1-2 hard cel-shading steps; hard pixel edges; no antialiasing.
Composition: one isolated centered prop, generous transparent padding, readable
at tiny gameplay size.
Constraints: genuinely transparent background; no floor scene, cast shadow,
characters, UI, text, frame, extra objects, gradients, dithering, blur, or
watermark.
```

The eight subject lines were: crossed blackened Joseon rafters; collapsed roof
tiles with splintered wood; a jagged mud-and-stone wall with exposed lath; a
split charred stump; a low windblown ash mound; a shattered brown onggi jar; a
tall blackened guardian/structural post; and three nearly cold charcoal embers
with sparse dull orange-red cores.

Shared ground prompt:

```text
Use case: stylized-concept
Asset type: seamless top-down pixel-art game ground texture
Primary request: one edge-to-edge ruined-village courtyard surface at night.
Style references: bamboo contact sheet for 32px logical density, hard flat
clusters and night values; rusted armor and ash wraith for the charcoal, ash,
muted brown and restrained rust-orange palette.
Composition: strict orthographic top-down, no perspective, horizon, or focal
point; perfectly seamless, rotation-friendly.
Style: chunky pixel art, flat fills, 3-6 hard steps, no antialiasing.
Constraints: no props, plants, characters, UI, text, cast shadows, gradients,
dithering, noise, blur, watermark, border, or central motif.
```

The four surface requests were thin ash over scorched compacted soil,
windblown ash drifts, irregular cold burn scars, and sparse broken flat paving
stones half-sunk in earth.

## Rebuild

Run from the repository root; no external source atlas is required:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/stages/ruined_village/build_assets.py
```

The builder fails if [A]'s block span exceeds either 25% of the full luminance
range or the bamboo anchor, if any [B] mean channel differs by more than 24,
if a prop is empty/partially transparent/off its placement row, if any prop
exceeds 64 opaque colours, or if [C]'s measurable geometry contracts fail.
