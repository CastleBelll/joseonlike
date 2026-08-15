# Night bamboo forest assets

This set is the first-stage night bamboo forest kit. Higgsfield MCP generated the
two base atlases; `build_assets.py` only performs chroma-keying, premultiplied
BOX downscaling, palette quantization, alpha cleanup, tile construction, and
16x nearest-neighbour export.

## Asset contract

All dimensions below are logical pixels; every shipped PNG is exported at 16x.
Solid sprites have binary alpha and their visible footprint touches the bottom
row of the canvas. Decor is non-colliding; only the fog intentionally keeps
partial alpha.

| File | Logical size | Role |
| --- | ---: | --- |
| `ground_tile.png` | 32x32 | Opaque, seamless base ground |
| `ground_variants/patchy_grass.png` | 32x32 | Opaque, seamless variant |
| `ground_variants/dirt.png` | 32x32 | Opaque, seamless variant |
| `ground_variants/moss.png` | 32x32 | Opaque, seamless variant |
| `props/bamboo_clump_small.png` | 24x40 | Solid obstacle |
| `props/bamboo_clump_large.png` | 40x56 | Solid obstacle |
| `props/rock_small.png` | 20x16 | Solid obstacle |
| `props/rock_large.png` | 32x26 | Solid obstacle |
| `props/water_puddle.png` | 40x28 | Walkable ground decal (QA-1: flat water must not block) |
| `props/fallen_log.png` | 48x20 | Solid obstacle |
| `props/stone_lantern.png` | 20x36 | Solid obstacle |
| `props/shrine_post.png` | 16x40 | Solid obstacle |
| `decor/grass_tuft.png` | 12x10 | Non-colliding decor |
| `decor/fern.png` | 16x14 | Non-colliding decor |
| `decor/pebbles.png` | 14x8 | Non-colliding decor |
| `decor/fog_wisp.png` | 48x24 | Non-colliding, semi-transparent decor |

`contact-sheet.png` compares a 4x4 repetition of the base tile with a sparse
mixed-stage mock-up containing every prop, every decor sprite, and the Taoist
for scale. `tile-verification.png` is a pure 8x8 base grid with per-tile
rotation. `ground-verification.png` is the required 8x8 gameplay mix: 10 of 64
cells (15.625%) are variants, grouped into three small clusters, and every cell
uses a deterministic 0/90/180/270-degree rotation.

## Palette and processing

The quiet ground palette remains anchored to the median of the Higgsfield base
swatch. Current dominant colours are base `#161e1f`, patchy grass `#192221`,
dirt `#1b1f1e`, and moss `#17211e`. Each tile has only seven interior grain
pixels at exactly one RGB level above or below its dominant colour, so the grain
survives as real logical pixels without becoming a blurred texture. Props keep
the original shared 32-colour palette, including cool moonlit accents such as
`#293c47`, `#2f444d`, `#415250`, and `#50737f`.

The original ground builder reduced a swatch to 16x16 and reflected it on both
axes. That forced a countable diamond/lattice motif into every 32x32 tile. The
replacement deliberately constructs an almost-flat 32x32 logical surface from
the source-derived night colour and seven non-adjacent one-pixel grain marks.
Every edge is one flat dominant colour, and the script requires all four edge
arrays to be interchangeable, not only opposite-edge pairs; therefore any
90-degree rotation remains seamless. The pure and mixed 8x8 composites were
visually inspected at 4x NEAREST: there is no repeated figure or visible tile
grid, while the clustered variants register only as very broad, faint hue/value
shifts.

Transparent sprites are keyed before resizing. RGB is premultiplied by alpha,
both colour and alpha are BOX-resampled, solid alpha is thresholded back to
binary, and the result is palette-snapped before its sole 16x NEAREST upscale.
The fog uses the same colour process but preserves soft alpha.

The quiet-ground retake reused the already-approved Higgsfield atlas and spent
no additional generation credits; only the deterministic ground reduction and
verification composite changed.

## Higgsfield generation record

Requested model: `nano_banana_pro`; the Higgsfield receipts reported the
serving model as `nano_banana_2`, 2K. Total generation cost was 4 credits.

- Ground job: `13cd71df-ee49-4735-85e9-44c7d4cc76fd`
- Props job: `9f026f92-5974-4e8c-8778-4a65744b247a`
- Ground source URL: <https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260814_084027_13cd71df-ee49-4735-85e9-44c7d4cc76fd.png>
- Props source URL: <https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260814_084024_9f026f92-5974-4e8c-8778-4a65744b247a.png>

### Ground prompt

```text
Use case: stylized-concept
Asset type: top-down pixel-art game environment texture atlas
Input images: Images 1-2 establish the near-black night-world value range and subtle prop density; Images 3-4 establish chunky logical-pixel scale and flat outlined color clusters.
Primary request: Create FOUR square, edge-to-edge forest-floor texture swatches arranged in an exact 2x2 grid with thin perfectly flat #ff00ff gutters. Top-left: base dark bamboo-forest earth. Top-right: sparse patchy grass. Bottom-left: compacted dirt. Bottom-right: subtle moss.
View: strict orthographic top-down, no perspective, no horizon.
Night palette: deep desaturated green-black and charcoal earth, faint cool blue-green moonlit variation, extremely low contrast. The world must read as NIGHT; bright UI/characters will be the brightest elements.
Style: deliberately chunky pixel-art clusters matching a 38-pixel-tall character, flat fills, no antialiasing look, restrained 1-2 shading steps.
Tile intent: each square is a seamless repeating texture with opposite edges matching; no central focal point.
Constraints: no plants taller than ground cover, no rocks, bamboo stalks, props, characters, UI, labels, text, shadows, lighting gradients, or border decoration inside swatches.
Avoid: daylight green, neon green, saturated emerald, photographic texture, painterly detail, noise, blur, gradients, isometric perspective.
```

### Props prompt

```text
Use case: stylized-concept
Asset type: top-down/three-quarter pixel-art game prop sprite atlas
Input images: Images 1-2 establish the dark night-world palette and prop density; Images 3-4 establish the chunky logical-pixel density, simple color blocks, and 1-pixel dark outline.
Primary request: Create exactly TWELVE separate night bamboo-forest props arranged in a clean 4-column by 3-row atlas on one perfectly flat solid #ff00ff chroma-key background. No labels or text.
Exact cells left-to-right:
Row 1: small bamboo clump; large bamboo clump; small mossy rock; large mossy rock.
Row 2: still moonlit water puddle; horizontal fallen bamboo log; stone lantern; small shrine post.
Row 3: grass tuft; fern; small pebbles; translucent low fog wisp.
Composition: one isolated centered prop per equal cell, generous magenta space between cells, no overlaps. Every solid prop's visual base/footprint sits at the bottom of its cell. Bamboo clumps have only 3-5 thick stalks with dark joint bands and a few broad leaves; compact, readable silhouette.
Night palette: very dark low-saturation blue-green, olive-black, charcoal and muted brown with small cool moonlit blue accents. No prop may be brighter than the reference character's face.
Style: coarse chunky pixel art, strong single-logical-pixel near-black outline, flat fills, 1-2 hard cel-shading steps, same apparent pixel density as a 38-pixel-tall in-world character.
Constraints: flat #ff00ff background only, no floor, cast shadow, glow, characters, UI, labels, letters, numbers, watermark, decorative frames, or extra objects.
Avoid: daylight green, vivid emerald, neon, realistic painting, smooth vector art, antialiasing, soft blur, gradients, dense foliage that hides footprints.
```

The four conditioning images were the two specified gameplay screenshots,
`asset/characters/taoist/idle.png`, and the owner's chunky pixel-style character
reference from `new_asset/character`.

## Rebuild

Requires Python 3 and Pillow. Download the two source URLs to:

```text
tmp/bamboo_forest/higgsfield-ground.png
tmp/bamboo_forest/higgsfield-props.png
```

Then run from the repository root:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/stages/bamboo_forest/build_assets.py
```

The build fails if a ground edge differs or cannot interchange with a rotated
edge, a solid prop does not reach its base row, solid alpha is not binary, or a
keyed magenta fringe remains.
