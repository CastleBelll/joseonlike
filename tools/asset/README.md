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
subject. `pixelize.py` also removes darker/noisy members of the magenta family because
multi-cell generations sometimes vary the requested flat key slightly between cells.

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

If a backend ignores the chroma request and draws a grey transparency checkerboard, retain
that failure in `raw/` and pass `--checker-background`. The option removes only bright neutral
pixels connected to a cell edge, so enclosed white effect cores remain intact. Do not use it
on ordinary chroma sheets.

Keep the pre-cutout generator output under `asset/<kind>/raw/` so a sprite can be recut at
another size without paying to regenerate it.

Generated contact sheets can be split into recuttable raw cells before pixelizing:

```bash
python tools/asset/slice_sheet.py sheet.png asset/ui/raw/cells 5 4 first second _ fourth
```

Full-frame generated panels use the same palette/quantisation path without chroma removal:

```bash
python tools/asset/pixelize.py panel.png backdrop.png 960 \
  asset/character/Taoist/Idle/rotations 540x960 --opaque-background
```

`WIDTHxHEIGHT` performs a centred cover crop before quantisation. Use it only for opaque
panels such as backdrops; sprites still use a square canvas size and chroma-key cutout.

If a generator adds a uniform grid line despite the prompt, pass `--inset=N` before the
cell names to trim that many source pixels from every cell edge before chroma-keying.
Use `--inset-x`, `--inset-top`, and `--inset-bottom` when a backend adds a caption band or
uneven outer margin; the weapon expansion sheet uses this to discard generator captions
before the 32px cut rather than trying to key text out afterward.

For irreversible animation such as a collapse or dissipation, pass `--fixed-cell` with a
square canvas. It retains the sheet's common scale instead of cropping and enlarging each
frame independently, which would make a fallen body as tall as its standing frame.

M1 helper scripts are deterministic and safe to rerun:

- `make_seamless_tile.py` darkens, quantises, and mirror-wraps generated ground concepts.
- `build_ui_chrome.py` rebuilds the ink/paper/vermilion nine-slice chrome and currency icons.
- `synthesize_audio.py` rebuilds the original peak-safe M1 WAV set.
- `process_author_audio.py` retains the seven author deliveries under `asset/audio/raw/`,
  files the three MP3s losslessly, and trims/resamples/levels the four replacement one-shots.
- `process_title_layers.py` cuts the eight individually generated title members at their
  registered canvases, extracts the valid halo/mote from two over-generated raws, builds the
  review composite, mirror-wraps the horizontal fog seam, and locally compresses the
  8429e00 ground's control band without moving or erasing its authored detail. The action
  band must retain 3.0--7.0 local 8px luminance deviation; a lower number is a failed wash,
  not an improvement.
- `verify_assets.py` checks fixed canvases, hard alpha, chroma removal, tile seams, palettes,
  audio formats/peaks, rejects unregistered runtime audio, and checks the retained
  motion-consistency evidence.
- `measure_motion_sheet.py` compares cut motion cells on the authority's canonical 37x46
  window and writes reproducible JSON using the same pixel-diff denominator as the original
  separate-render test.
- `measure_conditioned_motion.py` applies that same 1,702-pixel comparison to direct
  image-to-image edits and separates lower-body changes from stable upper-body, hat, and
  staff regions. The retained south-direction trial failed because only about 35% of its
  changes stayed in the lower body and both stable silhouettes moved.
- `measure_directional_motion.py` compares every generated motion cell against its own
  direction's 92x92 idle authority and records per-frame lower-body concentration, head
  silhouette stability, pair differences, and a sheet-level acceptance summary.
- `process_monster_death_sheets.py` slices and pixelizes the eighteen folklore-monster
  death sheets with their audited layouts; `normalize_death_sequence.py` preserves the
  common sheet scale, and `clean_tiny_components.py` removes isolated generator specks.
- `measure_death_sheets.py` measures all twenty-five four-frame death sequences as irreversible
  collapse: every transition and the terminal state must differ materially, and the final
  silhouette must lose height or opaque area. This is deliberately not the identity gate
  that correctly rejects generated walk and attack frames.
- `process_monster_walk_trials.py` and `measure_monster_walk_trials.py` retain the four-body-plan
  monster walk experiment. All four conditioned two-frame trials failed upper-body stability;
  `asset/monster/WALK_STATUS.json` records the measured procedural replacement for all 22 sets.
- `process_combat_effects.py` slices and pixelizes canonical east-facing travel/melee art and
  the paired fireball/spirit-bolt impacts; `measure_combat_art.py` checks their small-screen
  silhouettes and bright cores.
- `measure_effect_sheets.py` records opaque coverage, bright-core pixels, and consecutive
  frame deltas for the fifteen four-frame effect sheets. Its final dissipation frame is exempt
  from the bright-core gate but still must retain a readable silhouette and distinct motion.
- `build_rotation_contact_sheets.py` lays out every character and monster in the semantic
  order south, south-east, east, north-east, north, north-west, west, south-west. View all
  four overview pages before accepting directional art; filenames and pixel differences do
  not prove that a sprite actually faces its label.
- `audit_rotation_facing.py --write` records a manual contact-sheet decision and binds it to
  the SHA-256 of all 200 reviewed cells. `verify_assets.py` rejects any later cell change
  until its contact sheet is rebuilt, viewed, and the manifest is deliberately renewed. The
  retained pixel diagnostics are evidence, not a classifier: correct asymmetric weapons and
  tails produce false positives under a universal mirror or distance threshold.
- Player rotations additionally use a 2.50 mean-RGBA near-duplicate gate over every pair in
  each eight-cell set. This caught Warrior north-east/north-west at 1.92 and Archer
  north/north-west at 1.76; all player sprites share a 92px canvas and 46px content height, so
  the absolute cut is comparable. Do not apply that number blindly to monsters: their 44--150px
  content scale and deliberately symmetric spirits dilute whole-canvas means. Diagonal
  handedness remains a hash-bound manual contact-sheet decision because swapping two mirror
  images leaves every honest mirror-pair metric unchanged.
- `process_ui_journey.py` slices the visually audited Higgsfield UI sheets by their actual
  layouts, sends every selected generated cell through `pixelize.py`, and then calls
  `build_ui_furniture.py` for exact-palette state frames, bars, toggles, and nine-slices.
  Generator sheet layout is not trusted: this batch returned 2x2 and irregular 5/5/4 grids
  despite explicit 4x1 or 5x3 requests. Generated pseudo-lettering is also never accepted as
  UI copy; use real font rendering or a non-text symbolic replacement.
- `build_ui_journey_overview.py` builds three review pages for the final icons,
  illustrations, and furniture. `measure_ui_journey.py` writes the reproducible inventory,
  state-shape, hard-alpha, chroma, exact-palette, and WCAG-AA evidence used by
  `verify_assets.py`.
- `process_drops_and_boss.py` slices the three loot sheets, builds fixed-scale idle/collect
  presentations, and cuts the enlarged bamboo spirit lord rotations/death sheet at a common
  150px content scale. The model's first boss pass changed the bamboo spirit into a human;
  those rejected raws remain alongside the accepted grey-mask retry, whose stray skin hues
  are deterministically remapped to dark spirit bark after pixelization.
- `measure_drop_sets.py` checks all twelve pickup sets for 8--16px idle readability, four
  distinct collect frames, increasing XP-tier area, hard alpha/chroma removal, and pairwise
  alpha-shape differences between all five grade chests. `build_drop_contact_sheet.py`
  retains the visual-review layout under `asset/drop/raw/`.
- `process_destructibles.py` slices the two 5x4 Joseon object sheets, cuts every cell through
  `pixelize.py` on a common 64px fixed canvas, normalises intact objects below trash-monster
  height, and keeps break frame 3 as an explicit debris alias. `measure_destructibles.py`
  applies an irreversible-collapse/fragmentation gate, checks the shared vermilion breakable
  cue, and retains the labelled visual-review sheet under `asset/destructible/raw/`.

Rotation sheets are not the default generation method. A model may ignore the requested
layout, which makes fixed-grid slicing put grid lines, neighboring figures, or the wrong
facing into a named cell. Prefer direct per-direction generation for new rotation work. A
sheet is acceptable only when every sliced cell is inspected individually, contains exactly
one complete figure with no grid/caption bleed, matches its semantic direction, and passes
the mechanical asset checks; if any of those fail, stop slicing that sheet and regenerate
the affected directions directly.

## Import settings

`project.godot` sets `default_texture_filter=0` (nearest) globally. Never enable filtering
on a sprite import — it turns the pixel grid to mush.
