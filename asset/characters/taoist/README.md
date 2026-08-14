# Young Taoist character set

This set uses the owner-authored replacement sheets in `new_asset/taoist.png` and `new_asset/taoist_walk.png`. The approved clean-shaven face, crimson hair, anime eyes, blush, navy/teal robe, ringed staff, talisman, and straw hat come directly from those raster sources. `build_assets.py` performs only chroma removal, cropping, nearest-neighbor reduction, exact palette snapping, proportion rebalance, and source-pixel frame assembly.

## Source art

| File | Canvas | SHA-256 | Contents used |
| --- | ---: | --- | --- |
| `new_asset/taoist.png` | 2048×2048 | `C27141316B56356E54C06F958057A994DFF7C2E871DE956BD2D1F911B04E330C` | left full-body idle and right bust portrait |
| `new_asset/taoist_walk.png` | 1536×1024 | `149E14311D86FC72DEFBF078D9656D45A628775D2868C9ECF5BCA3C7CBE637DE` | numbered top-row poses 1–4 |

The owner replacement supersedes the earlier generated model-sheet revision. Its working art brief was:

```text
Young, pretty Korean Taoist adept in chunky two-head anime pixel art. Preserve the vivid
crimson-pink hair, large eyes with visible whites and clear crimson irises, cheek blush,
small nose and mouth, navy/teal robe, ringed staff, and paper talisman. Give the character
a clearly readable wide straw conical hat, tilted so the entire face remains visible.
Use crisp black outlines, saturated flat color, and one or two hard shading steps. No beard,
wrinkles, old-sage silhouette, muted palette, sword, text, shadow, or background detail;
render on a flat chroma-green background.
```

## Output contract

| File | Logical canvas | Export canvas | Notes |
| --- | ---: | ---: | --- |
| `idle.png` | 32×32 | 512×512 | Right-looking idle; 29 px subject height; head ratio `0.482759` |
| `walk.png` | 128×32 | 2048×512 | Four 32×32 frames: contact, pass+bob, contact, pass+bob |
| `portrait.png` | 48×48 | 768×768 | Full hat and head fit inside the canvas |
| `preview.gif` | 32×32 | 512×512 | Four-frame loop at an exact 8 fps average |
| `contact-sheet.png` | n/a | 2560×1024 | Dark-green `#1c2416` silhouette/readability check |

All PNGs have binary alpha (`0` or `255`) and exact 16× nearest-neighbor blocks. Walk frames use the authored lower-body poses from sheet frames 1–4; the frame-one head and torso are locked across the strip, while passing frames 2 and 4 receive the required one-logical-pixel bob.

## Proportion measurement

The script measures the final 32×32 idle in code. Hair begins on logical row 4, the chin ends on row 17, and the full opaque figure is 29 rows high:

```text
(17 - 4 + 1) / 29 = 0.482759
```

This is inside the owner-locked `0.42–0.55` range. The source head pixels are retained; only their vertical allocation versus the body is changed, so the total sprite remains 29 px tall.

## Palette

The in-world sprites use 23 exact opaque colors plus transparency. The portrait uses 32 exact opaque colors plus transparency. Key colors include:

```text
outline       #000000  #070304  #020001
hair          #6a062f  #a9052f  #b71435  #d30b45
skin/blush    #fdca97  #fce9b4  #db9250
hat/staff     #955e44  #e8b96d  #db9250
robe          #242b52  #3d4275  #4f4774
sash          #1e5467  #58836c
talisman      #e8b96d  #d30b45
```

## Reproduction

1. Keep the two source sheets at the paths listed above.
2. Install Pillow if needed: `python -m pip install Pillow`.
3. Run `python asset/characters/taoist/build_assets.py` from the repository root.
4. The script removes strong chroma green, isolates each source figure, reduces it to the logical grid, snaps the approved exact palettes, compresses the body until the measured two-head ratio passes, locks the walk upper body, exports at 16× nearest-neighbor scale, and writes the GIF/contact sheet.

Final visual review compared `idle.png` directly beside the owner reference `basic.png`. The head/body balance reads in the same chunky family, the wide hat and vivid hair remain distinct on `#1c2416`, the portrait has clear padding around the full hat, and no sword appears anywhere.
