# Asset pipeline

How generated art becomes a sprite that matches the rest of the game. Read this before
generating anything — the first attempt at monster art was thrown away for ignoring it.

## The reference sprite is the contract

`asset/character/Taoist/Idle/rotations/south.png` is the style authority. Measured, not
assumed:

- Canvas 92x92, but the **character occupies only 37x46 pixels**.
- 52 colours, dominated by pure black `(0,0,0)` outline and dark blue-grey `(31,34,49)`.
- Chibi proportions, head roughly one third of body height.
- Low top-down camera, looking down from slightly above.
- Flat shading, two or three tones per material. No gradients, no anti-aliasing.

**Resolution is the thing that breaks first.** A monster drawn 120px tall reads as a
different, far more detailed art style no matter how good the prompt was. Current sizes,
all consistent with the 37x46 player:

| Asset | Size |
|---|---|
| Taoist (player) | 37x46 |
| forest_goblin | 33x44 |
| forest_spirit | 26x46 |
| bamboo_brute | 61x58 |
| bamboo_spirit_lord (boss) | 60x76 |

## Generating

Pass the reference sprite as an image input and state its measured traits as hard
constraints — "match the reference" alone does not work. What did work:

- "the reference is a tiny 37x46 pixel sprite, every feature is a few chunky square blocks"
- "enormous clearly countable square pixel blocks, no anti-aliasing, no gradients"
- "thick solid near-black outline around the whole silhouette"
- "CHIBI proportions, head roughly one third of body height"
- "low top-down camera looking down from slightly above"

Framing: demand a margin of empty background on all four sides. Asking for the subject to
"fill the frame" crops the feet off.

Background: flat chroma for a clean cutout, and pick a colour the subject does not contain.
A green creature on a green screen keys away to nothing — that cost one regeneration.
Magenta `#FF00FF` is the safe default; state explicitly that no magenta may appear on the
subject.

## Cutting

```bash
python tools/asset/pixelize.py <in.png> <out.png> <content_height> <palette_dir> [canvas_size]
# e.g.
python tools/asset/pixelize.py asset/monster/raw/forest_goblin_raw.png \
    asset/monster/forest_goblin.png 44 asset/character/Taoist/Idle/rotations
```

It chroma-keys the flat background, crops to content, downscales to the target logical
height with BOX (averaging beats NEAREST here — NEAREST point-samples one arbitrary source
pixel per cell and keeps generator noise), then quantises.

For fixed-size UI icons, pass `32` as `canvas_size`. Oversized wide subjects are scaled
down proportionally with nearest-neighbour and centred on a transparent 32x32 canvas.

The palette is the reference palette **plus** the subject's own dominant hues. Snapping to
the reference palette alone turned the bamboo brute stone grey, because the reference
contains no green. Style consistency comes from resolution, outline weight and flat
shading — not from identical hues. Outline pixels are forced to pure black so the
silhouette still reads at sprite size.

Keep the pre-cutout generator output under `asset/<kind>/raw/` so a sprite can be recut at
another size without paying to regenerate it.

Generated contact sheets can be split into recuttable raw cells before pixelizing:

```bash
python tools/asset/slice_sheet.py sheet.png asset/ui/raw/cells 5 4 first second _ fourth
```

If a generator adds a uniform grid line despite the prompt, pass `--inset=N` before the
cell names to trim that many source pixels from every cell edge before chroma-keying.

M1 helper scripts are deterministic and safe to rerun:

- `make_seamless_tile.py` darkens, quantises, and mirror-wraps generated ground concepts.
- `build_ui_chrome.py` rebuilds the ink/paper/vermilion nine-slice chrome and currency icons.
- `synthesize_audio.py` rebuilds the original peak-safe M1 WAV set.
- `verify_assets.py` checks fixed canvases, hard alpha, chroma removal, tile seams, palettes,
  audio formats/peaks, and the retained motion-consistency evidence.
- `measure_motion_sheet.py` compares cut motion cells on the authority's canonical 37x46
  window and writes reproducible JSON using the same pixel-diff denominator as the original
  separate-render test.

## Import settings

`project.godot` sets `default_texture_filter=0` (nearest) globally. Never enable filtering
on a sprite import — it turns the pixel grid to mush.
