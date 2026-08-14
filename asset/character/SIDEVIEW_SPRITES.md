# Side-view character sprites (V8)

V8 is the definitive 48 x 48, two-head-tall character set. It supersedes the
32 x 32 V5 sprites and the tall 48 x 64 V6 sprites. Game code remains
dimension-agnostic; only the existing `idle.png` and `walk.png` assets changed.

## Runtime contract

- Logical canvas: **48 x 48 px** per frame.
- Shared ground line: logical row **46**.
- Export scale: **16x nearest-neighbour**.
- Exported frame: **768 x 768 px**.
- `idle.png`: one right-facing frame, **768 x 768 px**.
- `walk.png`: four right-facing frames, **3072 x 768 px**.
- Pixel format: RGBA PNG, binary alpha, exact 16x grid alignment, a
  one-logical-pixel near-black outline, and 19-20 opaque palette colors per
  character.
- Screen target: the game's 2x draw scale displays a frame on a 96 x 96 px
  screen footprint.

Each figure is 45 logical pixels tall, including hat or plume and outline. The
locked head region is 22 logical pixels tall (about 49% of the figure height),
which keeps the V5 two-head chibi silhouette instead of V6's four-head body.

## Locked designs

- **Taoist (도사):** broad tan `삿갓`, gray-white dopo with muted blue trim,
  yellow talisman slips at the belt, and an upright `석장` pilgrim staff with
  visible top rings. The sprite has no sword or scabbard.
- **Warrior (무관):** navy `전립` with a red plume, navy cheollik and dark
  lamellar chest, red waist sash, and a curved hwando held low.
- **Archer (궁수):** shallow flat woven `패랭이`, deep-green hunter jacket,
  tan trousers, white gaiters, back quiver with a diagonal red strap, and a
  Korean gakgung bow in the front hand.

Left-facing sprites are produced by the engine mirror; all source art faces
right.

## References and Higgsfield generation

The V5 side sprites at commit `97eb0d0` are the proportion and silhouette
reference. `new_asset/Character.png` is used only for costume materials and
palette. The per-character costume crops remain at:

- `asset/character/Taoist/raw/character_v6_reference.png`
- `asset/character/Warrior/raw/character_v6_reference.png`
- `asset/character/Archer/raw/character_v6_reference.png`

Each character came from one Higgsfield GPT Image 2 generation containing idle
plus all four walk phases, preserving within-sheet frame consistency. Every job
used 2K output, high quality, a 16:9 sheet, both locked references, and a flat
`#FF00FF` background.

- Taoist job: `3718a069-d79e-4c21-a0d8-bf8119c97440`
- Warrior job: `3afb8048-2fc4-4e78-a715-ee3b3fe735c3`
- Archer job: `9704e6af-512a-4d2f-9d55-902aecdaf7b9`

Selected raw sheets:

- `asset/character/Taoist/raw/side_sheet_v8_higgsfield.png`
- `asset/character/Warrior/raw/side_sheet_v8_higgsfield.png`
- `asset/character/Archer/raw/side_sheet_v8_higgsfield.png`

## Walk order and deterministic processing

Slice `walk.png` as **4 columns x 1 row**, using 768 x 768 cells:

1. Contact A: front heel planted, legs scissored wide.
2. Passing A: legs gathered, support foot planted, body one logical pixel up.
3. Contact B: opposite heel planted, legs scissored wide.
4. Passing B: opposite support foot planted, body one logical pixel up.

`tools/process_higgsfield_sideview_sprites.py` performs the deterministic
post-processing:

1. Removes the magenta backdrop and extracts the five generated silhouettes.
2. Applies one reduction scale per sheet and anchors every pose to 48 x 48 with
   the outline on row 46.
3. Quantizes every pose to one palette derived from the definitive costume
   crop, with no dithering.
4. Adds the one-logical-pixel outline and binary alpha.
5. Replaces only the central head rectangle with the idle drawing so face and
   hat pixels cannot drift; limbs, held gear, quiver, and costume folds remain
   authored by the one Higgsfield sheet.
6. Raises passing poses exactly one logical pixel while retaining the authored
   support-sole pixels on row 46.
7. Exports at 16x nearest-neighbour and writes GIF and contact-sheet review
   artifacts.

Run from the repository root:

```text
python tools/process_higgsfield_sideview_sprites.py \
  --metrics asset/character/side_v8_metrics.json
```

## Verification

Automated verification in `asset/character/side_v8_metrics.json` confirms for
all three characters:

- idle 768 x 768 and walk 3072 x 768;
- four distinct logical walk frames;
- binary alpha and exact 16x logical-grid alignment;
- bottom row 46 for all twelve walk frames;
- top rows `2, 1, 2, 1`, proving the one-pixel passing bob;
- byte-identical locked head pixels after compensating for that bob;
- contact stride widths greater than their paired passing widths;
- 22 px head region over a 45 px full silhouette.

The 8.3 fps loops are:

- `asset/character/Taoist/raw/walk_v8_preview.gif`
- `asset/character/Warrior/raw/walk_v8_preview.gif`
- `asset/character/Archer/raw/walk_v8_preview.gif`

`asset/character/side_v8_contact_sheet.png` was reviewed at enlarged 1x-logical
resolution. The silhouettes are distinct: staff-and-satgat Taoist,
plume-and-low-sword Warrior, and flat-hat bow-and-quiver Archer. Both contact
poses read wide, both passing poses read gathered, feet remain on the shared
ground line, and no frame reads as a jump or slide.

Keep texture filtering and mipmaps disabled in Godot so the logical pixels stay
crisp.
