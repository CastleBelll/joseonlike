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

Every prop has binary alpha and at most 33 opaque colours. The four ground
tiles use 6-7 flat colours. The base tile's dominant colour is below 70%; the
three variant dominants are respectively 52, 31, and 42 summed RGB levels from
the base, clearing the ground-quality test's 24-level floor. No asset contains
an antialiased edge, gradient, or dither pattern.

`contact-sheet.png` places the ruined props at gameplay size beside the bamboo
forest's fallen log, small rock, and shrine post. `ground-verification.png`
shows an 8x8 runtime-style mix with per-tile rotations and the three variants
composited at the game's 68% alpha.

## Generation record

The built-in image generation tool produced one source image for each shipped
asset. The bamboo contact sheet established logical-pixel density and night
lighting; the regenerated `rusted_armor` and `ash_wraith` idles established the
second-night charcoal, ash, soot-brown, and restrained rust-orange palette.
The ground sources were used as palette/composition studies; the final ground
patterns are deterministic logical-pixel constructions so their tiling
contract is testable. Prop sources are reduced directly by `build_assets.py`.

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

Place the 12 generated sources under `tmp/ruined_village/` using the shipped
file names, then run from the repository root:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/stages/ruined_village/build_assets.py
```

The builder fails if a ground tile is too flat, a variant is too close to the
base, a prop is empty, solid alpha is not binary, a solid misses its bottom
placement row, or any prop exceeds 64 opaque colours.
