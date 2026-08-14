# Side-view character sprites (V6)

V6 is based exclusively on the definitive design sheet at
`new_asset/Character.png`. It supersedes all earlier chunky 32 x 32 anchors and
all earlier no-weapon directions.

## Source measurement and runtime format

- Definitive source: **2688 x 1520 px**, magenta-backed, three characters.
- Measured authored pixel cadence: approximately **22 source pixels per logical
  pixel** (the source is softly rendered rather than an exact integer upscale).
- Measured source figures: approximately **55-58 logical pixels tall**, including
  the Warrior's plume.
- V6 logical canvas: **48 x 64 px** per frame.
- Export scale: **16x nearest-neighbour**.
- Exported frame size: **768 x 1024 px**.
- Shared ground line: logical row **61**.
- `idle.png`: one right-facing frame, **768 x 1024 px**.
- `walk.png`: four right-facing frames in one horizontal strip,
  **3072 x 1024 px**.
- Pixel format: RGBA PNG, binary alpha, 20-color reference-derived opaque
  palette, one-logical-pixel near-black outline.

The 48 x 64 canvas keeps all three characters on one canvas, export scale, and
ground line while retaining the taller four-head design and the Taoist sword,
Warrior hwando, Archer bow, and Archer back quiver without cropping.

## Definitive V6 designs

- **Taoist (도사):** black scholar yugun/heukrip with tail, white dopo, cobalt
  sash and trim, yellow belt talisman, vivid red ritual sword held low.
- **Warrior (무관):** navy jeonrip with red plume, dark lamellar chest vest,
  red waist sash, curved hwando held low.
- **Archer (궁수):** woven straw satgat, forest-green jacket, tan baggy trousers,
  white gaiters, back quiver with visible arrows, gakgung held in front.

The character crops used as the only generation references are preserved at:

- `asset/character/Taoist/raw/character_v6_reference.png`
- `asset/character/Warrior/raw/character_v6_reference.png`
- `asset/character/Archer/raw/character_v6_reference.png`

Crop rectangles in the 2688 x 1520 source were Taoist `(0,64)-(896,1440)`,
Warrior `(896,32)-(1696,1440)`, and Archer `(1696,64)-(2688,1440)`.

## Higgsfield generation

Each final character uses exactly one Higgsfield generation containing idle plus
all four walk phases. No frame was independently generated.

- Model: **GPT Image 2** (`gpt_image_2`).
- Output: **2K**, high quality, 16:9, one result per character.
- Background: perfectly flat `#FF00FF`.
- Final job IDs:
  - Taoist: `7f499a2b-6603-4eda-b3e2-8b739f8afacf`
  - Warrior: `92bba6ff-8ad1-4a5d-aed5-e57f1a011917`
  - Archer: `21549b97-36b8-4736-86f9-6173e992e40b`

Final raw sheets:

- `asset/character/Taoist/raw/side_sheet_v6_natural_higgsfield.png`
- `asset/character/Warrior/raw/side_sheet_v6_natural_higgsfield.png`
- `asset/character/Archer/raw/side_sheet_v6_natural_higgsfield.png`

The final generation prompt explicitly defines a relaxed human walk: heel-strike
contact, planted support-leg passing, opposite heel-strike contact, opposite
support-leg passing. At least one complete foot must remain on the same ground
line in every phase; pelvis movement is horizontal; shoulder height is level;
and airborne, jumping, hopping, running, lunging, crouching, and high-knee
marching poses are prohibited. Character-specific prompt clauses require the
authoritative costume and held weapon in every frame.

## Walk order and processing

Slice `walk.png` as **4 columns x 1 row**, using 768 x 1024 cells:

1. Contact A: front heel strike, rear toe leaving.
2. Passing A: planted support leg, opposite swing knee passing.
3. Contact B: opposite heel strike, opposite rear toe leaving.
4. Passing B: opposite planted support leg and swing knee passing.

`tools/process_higgsfield_sideview_sprites.py` performs only sheet-level and
pixel-grid post-processing:

1. Removes the magenta backdrop and extracts the five Higgsfield silhouettes.
2. Applies one reduction scale and a shared head/ground anchor on 48 x 64.
3. Quantizes every pose to one palette derived from its authoritative crop.
4. Adds the one-logical-pixel outline and binary alpha.
5. Keeps Higgsfield's authored contact and passing leg art intact. No limbs are
   synthesized, mirrored, or redrawn.
6. Raises each generated passing pose by exactly one logical pixel and retains
   its generated sole row on ground row 61, so the support foot never floats.
7. Exports all frames at 16x nearest-neighbour and writes the verification GIFs.

Run from the repository root:

```text
python tools/process_higgsfield_sideview_sprites.py \
  --metrics asset/character/side_v6_metrics.json
```

## Verification

Automated verification recorded in `asset/character/side_v6_metrics.json`
confirms for all three characters:

- idle 768 x 1024 and walk 3072 x 1024;
- four distinct 48 x 64 logical walk cells;
- binary alpha and exact 16x logical-grid alignment;
- all four phases end on shared ground row 61;
- logical top rows `3, 2, 3, 2`, giving exactly a one-pixel passing bob;
- head-anchor horizontal spread of 0.995 px (Taoist), 0.794 px (Warrior), and
  1.092 px (Archer);
- contact and passing silhouettes are distinct and the mandatory held gear is
  present in every generated phase.

The final loops are preserved at:

- `asset/character/Taoist/raw/walk_v6_preview.gif`
- `asset/character/Warrior/raw/walk_v6_preview.gif`
- `asset/character/Archer/raw/walk_v6_preview.gif`

They were inspected at **8.3 fps** (120 ms per frame) on a dark background. The
sequence reads as heel contact -> planted passing step -> opposite heel contact
-> opposite planted passing step: one sole stays on row 61 in every phase, the
stride alternates, the body rises only on the two passing frames, and there is no
airborne/jump frame or sliding ground-line change.

Keep texture filtering and mipmaps disabled in Godot so the logical pixels remain
crisp.
