# Side-view character sprites (v4)

## Runtime format

- Logical canvas: **32 × 32 pixels** per frame.
- Export scale: **16× nearest-neighbour**, matching `new_asset/basic.png`.
- Exported frame size: **512 × 512 pixels**.
- `idle.png`: one three-quarter-right idle frame, **512 × 512**.
- `walk.png`: four three-quarter-right walk frames in one horizontal strip, **2048 × 512**.
- Color: RGBA PNG with binary alpha. Every exported mark is a uniform **16 × 16** block from the logical grid.
- Shared ground line: logical row **29**. Frames retain their full canvases and transparent margins.

The movement direction is screen-right, while the face and torso retain the natural three-quarter view used by `basic.png`. Mirror the same textures in-engine for leftward movement.

## V4 youthful character design bible

V4 removes the beard, heavy jaw, hidden-eye, and bulky-body cues that made the
previous roster read as three middle-aged men after reduction to 32 x 32. The
classes and gameplay silhouettes stay intact, but the lineup now reads as three
young adventurers rather than veteran archetypes.

- **Taoist, youthful wandering mystic:** clean-shaven bright face, visible eyes,
  satgat tilted upward, slim gray-white dopo with cobalt binding, ringed seokjang,
  and gold talismans. Palette: gray-white, straw gold, cobalt, dark brown.
- **Warrior, youthful cadet:** lean athletic build, bright clean face, short dark
  hair below a navy jeonrip, lively crimson tassel and sash, fitted lamellar, and
  low-held hwando. Palette: navy, cobalt highlights, crimson, steel, brass.
- **Archer, youthful mountain scout:** clean-shaven smiling face, visible eyes,
  short tied hair, paeraengi worn back, cropped forest jacket, tapered tan trousers,
  red quiver strap, and front-held gakgung. Palette: forest green, tan, straw gold,
  coral red, dark brown.

The final Higgsfield MCP v4 source sheets are preserved at:

- `asset/character/Taoist/raw/side_sheet_youth_v4_higgsfield.png`
- `asset/character/Warrior/raw/side_sheet_youth_v4_higgsfield.png`
- `asset/character/Archer/raw/side_sheet_youth_v4_higgsfield.png`

The processor prefers these final MCP files, then the uploaded v4 conditioning
references (`side_sheet_youth_v4.png`), and finally the v3
`side_sheet_higgsfield.png` sources.

### V4 generation prompts

V4 was produced through the Higgsfield MCP with GPT Image 2 at 2K, high quality,
16:9, one result per character. Each `side_sheet_youth_v4.png` conditioning
reference was uploaded to the Higgsfield Asset library before generation. Final
generation job IDs:

- Taoist: `efe0cb67-b2db-4298-8993-6ba4a6270e98`
- Warrior: `6f15f0b6-d09f-429c-b996-4a7dfd401006`
- Archer: `c18897e6-51e0-4981-9e8b-90a53cbb55ef`

All three prompts shared these production constraints:

```text
Redesign the character as a clearly youthful Korean adventurer while preserving
exactly five separated poses in one horizontal row: idle, contact A, passing A,
contact B, passing B. Keep one identical scale, face, costume, held item, palette,
and ground line. Use chunky two-heads-tall 32x32 logical-pixel art, a one-pixel dark
outline, large clean clusters, flat shading, and 2-3 shades per material. Put the
figures on perfectly flat #FF00FF. No beard, moustache, stubble, wrinkles, bulky
body, hidden eyes, antialiasing, gradients, dithering, labels, dividers, shadows,
scenery, or watermark.
```

Character-specific prompt blocks were:

```text
Taoist: clean-shaven man in his early twenties with bright eyes and dark side hair;
straw satgat tilted upward; slim gray-white dopo with cobalt trim; gold talismans;
upright ringed seokjang 10-15% taller than the character.

Warrior: clean-shaven male cadet in his late teens or early twenties with a lean
athletic build and short dark hair; navy round jeonrip and crimson tassel; fitted
navy lamellar and crimson sash; low-held hwando with brass guard and steel edge.

Archer: lean clean-shaven man around twenty with a small confident smile and tied
hair; paeraengi worn slightly back; cropped forest-green jacket and tapered tan
trousers; coral-red quiver strap, visible arrows, and front-held dark wood gakgung.
```

## V3 character design bible

The three palettes intentionally occupy different color families so the roster stays readable on the game's dark backgrounds and leaves room for the planned Mudang and Executioner.

- **Taoist (도사), wandering mystic:** wide conical straw satgat low over the eyes; gray-white dopo with strong blue binding; upright ringed seokjang pilgrim staff taller than the character; yellow-gold talisman flashes tucked into the belt. Palette: gray-white, straw tan, medium blue, gold.
- **Warrior (무사), Joseon soldier:** round navy jeonrip with a bright red tassel; broad navy cheollik/lamellar silhouette with crimson sash accents; low-held curved hwando with a bright steel edge. Palette: navy, readable blue highlights, crimson, steel; no brown-dominant armor.
- **Archer (궁수), mountain hunter:** flat straw paeraengi; deep-green hunting jacket separated clearly from tan trousers; bright red diagonal quiver strap and visible back quiver/arrow tips; front-held gakgung. Palette: forest green, tan, straw gold, red; no brown monochrome.

Held gear and costume marks contain no lettering or one-sided emblem, so horizontal mirroring remains valid.

## Walk order and slicing

Slice `walk.png` as **4 columns × 1 row**, using 512 × 512 regions:

1. Contact A
2. Passing A
3. Contact B
4. Passing B

Loop frames `0 → 1 → 2 → 3` at approximately 8–10 fps. The walk frames share one pixel-identical upper-body layer through logical row 22; only the generated lower garment and legs retain the alternating poses.

## Higgsfield generation

Each final v3 character used exactly **one Higgsfield generation containing all five poses** (idle plus four walk phases). No pose was generated independently.

- Service: Higgsfield MCP image generation.
- Model: **GPT Image 2** (`gpt_image_2`).
- Parameters: **2K**, **high** quality, **16:9**, one result.
- Conditioning: uploaded `new_asset/basic.png` as the only image reference in every call.
- Chroma backdrop: flat `#FF00FF`, selected so the Archer's required deep green survives extraction.
- Raw sheet size: **2688 × 1520**.
- Final generation job IDs:
  - Taoist: `3af062d3-7b40-451f-b9b4-38c2799fc2cc`
  - Warrior: `919396d1-64f7-45b7-bb2a-093bdcb1b9a8`
  - Archer: `4f292ca4-da7f-465a-a918-c9d2fc4fc385`

Raw generated sheets are preserved at:

- `asset/character/Taoist/raw/side_sheet_higgsfield.png`
- `asset/character/Warrior/raw/side_sheet_higgsfield.png`
- `asset/character/Archer/raw/side_sheet_higgsfield.png`

### Final prompt structure

All three calls shared this production constraint block:

```text
Create one horizontal sheet with exactly five poses of one identical character:
idle, contact A, passing A, contact B, passing B. Use basic.png's chunky,
approximately two-heads-tall, three-quarter-right 32x32 logical-pixel style.
Lock the face, hat, torso, palette, held item, scale, and ground line. Animate only
the legs and the smallest necessary arm shift. Use a one-logical-pixel dark outline,
large clean clusters, flat cel shading, and only 2-3 shades per material. No dithering,
noise, gradients, antialiasing, tiny detail, dividers, labels, shadows, or scenery.
Keep five separated connected silhouettes on perfectly flat #FF00FF.
```

The character-specific prompt blocks were:

```text
Taoist: conical straw-tan satgat (not a black flat gat); gray-white dopo with vivid
blue trim; upright ringed seokjang attached to the hand and 10-15% taller than the
character; two yellow-gold talisman slips tucked at the belt. Keep gray-white, straw,
blue, and gold as clean distinct material blocks.

Warrior: dark navy round jeonrip with a bright red tassel; broad navy cheollik and
simplified lamellar chest; crimson sash accents; low-held curved hwando with brass
guard and bright steel edge. Use essentially no muddy brown and keep navy, crimson,
and steel strongly separated.

Archer: flat straw paeraengi (not conical); deep forest-green hunting jacket, clearly
tan trousers, bright red diagonal quiver strap, visible back quiver with arrow tips,
and front-held gakgung with taut string. Keep green, tan, straw, and red distinct.
```

## Local post-processing

Run from the repository root:

```text
python tools/process_higgsfield_sideview_sprites.py
```

The processor performs generated-image transformations only; it does not draw character pixels:

1. Removes green or magenta chroma pixels by color dominance.
2. Finds the five largest connected foreground components and orders them left-to-right.
3. Reduces all figures with one per-character scale onto a 32 × 32 logical grid.
4. Aligns each frame from its hat/head anchor and fixes the feet to logical ground row 29.
5. Reuses the first generated walk frame's upper layer through row 22 for the remaining walk frames, removing face, costume, and held-item flicker.
6. Quantizes all five frames together to a per-character authored palette of up to **16 opaque colors** with no dithering.
7. Exports at 16× using nearest-neighbour sampling.

## Verification

All raw sheets, idle sprites, and four-frame strips were visually inspected against a dark background after processing. Automated checks confirmed:

- exact dimensions: idle 512 × 512; walk 2048 × 512;
- transparent corners and binary alpha;
- all opaque pixels snapped to the 16× export grid;
- equal 512-pixel walk cells and one common canvas height;
- at most 17 RGBA entries per character including transparency (up to 16 opaque authored palette entries);
- logical alpha bounds ending on ground row 29;
- **0.0 logical-pixel upper-body center spread** across every walk loop;
- pixel-identical walk upper bodies and distinct lower-body frames;
- no chroma remnants, dividers, labels, or watermark;
- the required hat, costume, held weapon, and palette identity remain readable at the actual 32 × 32 logical resolution.

Keep texture filtering and mipmaps disabled in Godot so the logical pixels remain crisp.
