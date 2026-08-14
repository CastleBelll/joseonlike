# Young Taoist character set

This set replaces the rejected old-sage interpretation with a clearly young, clean-shaven Taoist adept. Higgsfield authored the base character art; `build_assets.py` performs only chroma removal, cropping, nearest-neighbor reduction, palette snapping, and source-pixel frame assembly.

## Mandatory reference inspection

- `new_asset/basic.png` — a tiny chunky pixel figure with vivid magenta hair, a pale face, and saturated cyan/pink/gold accessories.
- `new_asset/Character.png` — three clean-outlined Korean pixel heroes on magenta: a white-robed youth, a navy-armored guard, and a straw-hatted green archer.
- `new_asset/523051e1-580e-4c49-8499-d86b210a7bf7.png` — a compact dark-clad figure with deep magenta hair and a pale lavender face covering.
- `new_asset/532ccc6c-5c28-4a06-9a7f-b1090ad1e79c.png` — a black-outfitted chunky figure whose bright pink side locks dominate the silhouette.
- `new_asset/76dfc822-fc88-4ef3-a850-051d5f7ed069.png` — a saturated pink/red character with tall hair or ear-like tufts and a bright gold chest accent.
- `new_asset/ffd9c51c-eda6-4938-beeb-c92eb89b883b.png` — an indigo-haired young figure in a brown coat with a bright cyan-and-white eye/face accent.
- `example/KakaoTalk_20260814_143733532_01.png` — the Korean character-select screen with 설아 and 무운 cards; 설아 establishes the youthful, readable portrait standard.
- `example/KakaoTalk_20260814_143733532_06.png` — gameplay in a dark forest showing the small fan-carrying player sprite among skeletons, goblins, trees, and XP orbs.

`DESIGN.md` section 5.1 was read before generation. Its owner-locked rules—young age, anime-pretty face, vivid hair, two-head proportions, high saturation, and identity props layered over that look—were treated as hard constraints.

## Higgsfield source

- Requested model alias: `nano_banana_pro`
- Generation receipt model: `nano_banana_2`
- Job ID: `d97ba21c-7ca3-4b91-9b12-a3fc66ad10fd`
- Output: 2048×2048 PNG, 1:1, 2K
- Cost: 2 Higgsfield credits (coordinator-approved)
- Reference inputs: `Character.png`, `523051e1-580e-4c49-8499-d86b210a7bf7.png`, and the `_01` character-select capture

### Prompt

```text
Create a square pixel-art character model sheet for a Korean roguelite. Show the SAME single young Taoist adept twice: left, a full-body right-facing idle sprite pose; right, a waist-up character-select portrait. Use the provided images only as the owner-locked style and scale family references.

Character: late teens to twenties, unmistakably young and pretty, clean-shaven, no wrinkles, no old-sage silhouette. Anime face with very large eyes showing visible white sclera and crisp crimson irises, tiny nose and mouth, warm cheek blush, clean black outline. Vivid deep crimson-to-magenta hair is the main silhouette identifier, with sweeping bangs framing the face. Two-head chunky chibi proportions: head about half total height, short torso and legs, blocky hands and feet. High-saturation flat colors with one or two hard shading steps.

Taoist identity props sit on top of that youthful look: a compact straw conical hat worn sharply tilted back so the entire face and hair stay visible; a ringed ritual staff held behind/beside the body; several yellow-red paper talismans at the belt and on the staff. NEVER a sword. Outfit: saturated indigo/navy short robe, teal sash, crimson cords, ivory collar, gold accents. Character faces right in the full-body view.

Pixel execution: deliberate chunky pixel clusters, crisp black 1-pixel-style outline, no anti-aliasing, no blur, no painterly texture, no dithering, no gradients. Full-body pose must have a clear readable silhouette suitable for reduction to 32x32; portrait should retain the same face, hair, hat, clothes, staff and talismans with richer detail. Place both views well separated on a perfectly flat solid #00ff00 chroma-key background, no shadows, no floor, no text, no watermark. Do not use #00ff00 in the character.

Hard avoid: beard, mustache, wrinkles, closed or tiny eyes, realistic adult face, middle-aged man, old hermit, sage, gray/brown hair, muted or sepia colors, oversized hat hiding the eyes, weapon blade, sword, extra limbs, multiple characters.
```

## Output contract

| File | Logical canvas | Export canvas | Notes |
| --- | ---: | ---: | --- |
| `idle.png` | 32×32 | 512×512 | Right-looking idle, 29 px subject height |
| `walk.png` | 128×32 | 2048×512 | Four 32×32 frames, horizontal |
| `portrait.png` | 48×48 | 768×768 | Character-select bust |
| `preview.gif` | 32×32 | 512×512 | Four-frame loop, alternating 120/130 ms delays for exactly 8 fps on average |
| `contact-sheet.png` | n/a | 2560×1024 | Dark-green `#1c2416` readability check |

All sprite PNGs use binary alpha (`0` or `255`) and exact 16× nearest-neighbor blocks. Walk frames 1 and 3 use the idle source, while frames 2 and 4 move only existing hand/lower-leg regions and apply a one-logical-pixel bob; head and central torso pixels remain identical after bob alignment.

## Palette

The in-world sprite is snapped to 24 RGBA entries (23 opaque colors plus transparent); the portrait uses 32 opaque colors plus transparent. Dominant opaque colors are:

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

1. Download the completed Higgsfield job PNG to `tmp/taoist/higgsfield-base-retake.png`.
2. Install Pillow if needed: `python -m pip install Pillow`.
3. Run `python asset/characters/taoist/build_assets.py` from the repository root.
4. The script removes only strong chroma-green pixels, uses fixed source crops for the full body and portrait, snaps flat palettes without dithering, assembles walk frames from existing logical pixels, exports at 16× nearest-neighbor scale, and writes the contact sheet/GIF.

Final visual review confirmed a youthful clean-shaven face, visible eye whites and crimson irises, cheek blush, vivid crimson hair, tilted face-revealing hat, ringed staff, talismans, dark-ground readability, and no sword.
