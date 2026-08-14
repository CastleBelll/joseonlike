# Title screen art

The title art is a two-layer Higgsfield-generated Joseon night scene plus a
separate signboard object. `bg_sky.png` is opaque; `bg_village.png` has binary
alpha above its roofline so the game can parallax the village independently.
The optional fog layer was intentionally omitted: the generated sky already has
thin restrained clouds, and a third haze layer made the logo-safe area busier.

## Asset contract

| File | Logical size | Export size | Role |
| --- | ---: | ---: | --- |
| `bg_sky.png` | 540x960 | 1080x1920 | Opaque night sky |
| `bg_village.png` | 540x960 | 1080x1920 | Binary-alpha village foreground |
| `logo_ko.png` | 420x200 | 840x400 | Korean signboard logo object |
| `logo_en.png` | 420x200 | 840x400 | English signboard logo object |
| `preview.png` | 540x960 | 540x960 | Layer verification with mock UI |

The shipped layers are created at logical resolution and exported once at 2x
with nearest-neighbour scaling, so every logical pixel is a uniform 2x2 block.
The sky and village use 40-colour reductions; the signboard uses 32 colours.
Village and signboard alpha are keyed at source resolution, premultiplied, BOX
downscaled, then thresholded back to binary before the final NEAREST export.

The palette stays in the established night family: blue-black and indigo sky,
charcoal/navy roofs, subdued brown walls, and muted ground. Pale moonlight and
small amber lanterns/windows are the only bright scene accents. The title uses
the repository's NeoDunggeunmo pixel font in warm ivory with a dark pixel
outline, while the generated plaque carries the small vermilion seal accent.

## Higgsfield generation record

Requested model: `nano_banana_pro`; Higgsfield served `nano_banana_2` at 1K.
Each source cost 2 credits, for 6 credits total. The benchmark title capture was
used as the composition reference and the bamboo-forest contact sheet as the
project palette/pixel-density reference.

- Sky job: `e2d9b1b4-ca8a-4336-9d37-bb1dda16d48e`
- Village job: `7fce8a0b-ca05-43ba-a5de-b98ff3787cae`
- Signboard job: `289e14e8-e8f7-46d8-a65d-b9c8850b76b5`

The source URLs are embedded in `build_assets.py`; missing inputs are downloaded
to `tmp/title/` automatically.

### Sky prompt

```text
Use case: historical-scene
Asset type: layered portrait game title background, SKY LAYER ONLY
Primary request: create a crisp pixel-art Joseon-era night sky for a 540x960 portrait mobile title screen.
Input images: Image 1 is the structural composition benchmark; Image 2 is the project's established night palette and pixel density reference.
Scene/backdrop: deep blue-black night sky, one large pale moon in the upper-right-middle, sparse stars, a few thin low-contrast horizontal clouds and distant haze.
Style/medium: deliberate hand-placed 16-bit pixel art with chunky square pixels, flat color ramps, hard pixel clusters, no smooth gradients.
Composition/framing: full 9:16 portrait; keep the upper-middle region broadly clear for a large logo; sky fills the whole canvas with no buildings, ground, UI, frames, characters or text.
Lighting/mood: quiet cool moonlight; dark overall, only moon and sparse stars are bright.
Color palette: desaturated navy, indigo, blue-gray, pale ivory moon.
Constraints: clean negative space, crisp pixel edges, no blur, no photographic texture, no lettering, no watermark.
```

### Village prompt

```text
Use case: historical-scene
Asset type: transparent-ready FOREGROUND VILLAGE LAYER for a portrait game title screen
Primary request: create a crisp pixel-art Joseon village at night occupying only the LOWER 45 percent of a 9:16 portrait canvas.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background everywhere above and behind the village.
Subject: 2-3 depth layers of dark tiled hanok roof silhouettes, a centered gate and courtyard wall, a stone-and-earth path widening toward the viewer, a few compact warm lit windows and hanging lanterns.
Style/medium: deliberate hand-placed 16-bit pixel art, chunky square pixels, flat cel shading, 1-2 shadow steps, crisp dark outlines.
Composition/framing: village starts around 55 percent height; bottom quarter is quiet and low contrast so one wooden button remains legible.
Constraints: no sky art, UI, text, characters, watermark, or #ff00ff in the village art.
```

### Signboard prompt

```text
Use case: logo-brand
Asset type: transparent-ready title logo object for a portrait pixel-art game
Primary request: create one front-facing Joseon wooden signboard object with a curved dark tiled mini-roof, one small hanging lantern on each side, and a small red seal accent.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Subject: wide horizontal dark wooden plaque with an empty central face for later lettering.
Style/medium: deliberate hand-placed 16-bit pixel art, chunky square pixels, crisp dark outline, flat cel shading.
Constraints: entire roof tips and lanterns visible; no text, letters, watermark, or #ff00ff in the object.
```

## Rebuild

Requires Python 3 and Pillow. From the repository root:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/title/build_assets.py
```

The build fails if the canvas sizes drift, keyed alpha is not binary, or the
village art intrudes into the upper logo-safe sky. `preview.png` composites the
Korean logo, both background layers, a mock 85%-width wood start button, and a
corner settings glyph at the exact logical 540x960 screen size.
