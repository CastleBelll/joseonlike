# Bamboo forest monsters

The four stage-one monsters were generated as one base atlas with Higgsfield MCP
and then processed locally. The local script does not author the character
designs: it removes the chroma field, BOX-reduces, quantizes the generated hues,
reinforces two tiny eye marks, assembles animation frames, and performs the sole
16x NEAREST export.

## Files and scale

All sizes in the table are logical pixels. Exported PNG dimensions are exactly
16 times larger in each axis.

| Monster | Idle canvas / figure | Walk strip | Palette | Visual role |
| --- | --- | --- | ---: | --- |
| `forest_goblin` | 32x32 / 27px | 128x32 | 20 | Small olive/orange common mob |
| `forest_spirit` | 32x32 / 29px | 128x32 | 20 | Pale white-blue weakest spirit |
| `bamboo_brute` | 48x48 / 44px | 192x48 | 28 | Broad jade/bamboo elite |
| `bamboo_spirit_lord` | 96x96 / 84px | 384x96 | 32 | Moonlit jade/cyan boss |

Each monster folder contains `idle.png` and a four-frame right-facing
`walk.png`. The boss also contains `idle_breathe.png`, a two-frame subtle
one-pixel inhale while keeping its ground base fixed.

The walk order is contact, passing/bob, opposite contact, opposite
passing/bob. Upper bodies are copied pixel-for-pixel from the idle (passing
frames use only the specified one-logical-pixel vertical bob); the lower halves
change stance and lead side. The build fails if the four frames are not unique.

`contact-sheet.png` is a true 1x composite on the shipped bamboo ground, then
upscaled exactly 8x with NEAREST. Left to right it shows goblin, spirit, Taoist,
brute, and boss. Visual inspection confirmed that all five silhouettes are
readable, the goblin and white-blue spirit separate instantly, and the hierarchy
`goblin < spirit < Taoist < brute << boss` is unambiguous.

## Palette

- Goblin: olive `#9b9f59`, `#798248`, shadow `#3f462d`, orange `#c27241`.
- Spirit: pale `#d7f1f7`, `#a8cae6`, blue `#76a0bf`, cyan eye accent.
- Brute: jade `#477d67`, `#2c524b`, bamboo olive `#6c6e42`.
- Boss: moonlit jade `#66a88f`, teal `#38757b`, pale `#cfeff4`, blue `#7ba3b7`.
- Shared outlines remain near-black (`#060706` to `#0b0d11`).

The generated hues are quantized per monster and are not recoloured. The
palette separation is intentional swarm readability: white-blue spirit, olive
goblin, dark jade brute, and pale-cyan/jade boss.

## Processing contract

1. Chroma-key and despill the full-resolution magenta field before reduction.
2. Premultiply RGB by alpha, BOX-resize RGB and alpha together, then
   un-premultiply surviving pixels.
3. Threshold alpha at 128 so every game sprite is binary transparent/opaque.
4. Quantize without dithering to the compact per-monster palette above.
5. Restore only the one-pixel goblin/ghost eye accents that survive on the
   downscaled subject; the generated horns and silhouettes are otherwise kept.
6. Assemble contact/passing animation from the same logical idle so the upper
   body is locked, then upscale once at 16x with NEAREST.

The script validates figure height, bottom-row placement, binary alpha, missing
or duplicate walk frames, upper-body lock/bob, and residual magenta fringe.
Because these monsters are intentionally green, the original magenta key was
chosen instead of green; “no green fringe” is satisfied as no green screen is
used anywhere in this pipeline.

## Higgsfield generation record

- Requested model: `nano_banana_pro` (receipt serving model: `nano_banana_2`)
- Resolution: 1K, square
- Cost: 2 credits
- Job: `eaa12347-8529-499b-abeb-6bafe5fceeb5`
- Source: <https://d8j0ntlcm91z4.cloudfront.net/user_3HCgsqzSxMMvzqXejoYwa267X3D/hf_20260814_092026_eaa12347-8529-499b-abeb-6bafe5fceeb5.png>

The generation was conditioned on the shipped Taoist idle and walk, the bamboo
forest contact sheet, and benchmark gameplay screenshot `_06`.

### Prompt

```text
Use case: stylized-concept
Asset type: top-down-light 2D pixel-art monster sprite atlas for a night bamboo-forest survivor game
Input images: Image 1 is the exact player pixel density, chunky proportions, outline and cel-shading target; Image 2 shows the required four-frame logical-pixel animation density; Image 3 establishes the nearly-black cool bamboo ground and prop palette the monsters must read against; Image 4 establishes swarm readability through unmistakable silhouette and palette separation.
Primary request: Create exactly FOUR isolated full-body monster base sprites arranged in a precise 2-column by 2-row atlas, separated by wide perfectly flat solid #ff00ff gutters and surrounded by the same flat #ff00ff chroma-key background. No labels or text.
Exact cells:
Top-left: forest_goblin, a small Korean dokkaebi trash mob, stubby 2-head body, olive-green skin, two short ivory horns, pointed ears, mischievous bright eyes, ragged muted orange waistcloth, empty hands, compact running-ready silhouette.
Top-right: forest_spirit, a weak wronged Korean spirit, pale white-blue face and drifting translucent-looking hanbok wisp, long sleeve tips, no feet, tiny cyan eyes, simple teardrop floating silhouette that contrasts hard against the goblin.
Bottom-left: bamboo_brute, an elite Korean ogre, visibly broad and muscular, dark jade skin, thick bamboo-plank shoulder and forearm armor with dark joint bands, one broken horn, heavy planted legs, dangerous forward-leaning silhouette, empty hands.
Bottom-right: bamboo_spirit_lord boss, majestic bamboo spirit king, very large broad silhouette, crown of five bamboo shoots, pale spectral face, flowing layered robe in moonlit jade and blue-white, two ribbon-like spectral sleeves and a compact halo of moonlit green leaf wisps; regal and threatening, not cluttered.
Pose/view: every monster faces RIGHT in the same three-quarter top-down-light view, neutral idle with limbs separated enough for later animation; full silhouette and base visible, generous padding, no overlap.
Style: deliberately coarse chunky pixel art matching the reference Taoist, large square pixel clusters, crisp near-black one-logical-pixel outline, flat fills, only 1-2 hard cel-shading steps, no subpixel details.
Palette separation: goblin olive green plus orange; spirit luminous white-blue; brute dark jade plus tan bamboo; boss moonlit emerald, cyan and pale robe. Keep the background-world values dark but make each identity accent readable on #192020 ground.
Hierarchy: goblin smallest and narrowest, spirit slightly taller, brute about 1.6x goblin height and twice its bulk, boss about 3x goblin height and by far the largest visual mass.
Constraints: one character only per cell, no floor, no cast shadow, no scenery, no weapons, no swords, no staffs, no text, no letters, no numbers, no watermark, no UI, no frames other than the flat magenta gutters. Every subject must be fully connected and its visual base must sit near the bottom of its cell.
Avoid: daylight scenery, realistic painting, smooth vector art, soft antialiasing, blur, gradients, excessive texture, muddy monochrome, tiny facial noise, body parts merging into the background, Western goblin armor, comedy mascot style.
```

## Rebuild

Requires Python 3 and Pillow. Download the source URL above to:

```text
tmp/bamboo_monsters/higgsfield-monsters.png
```

Then run from the repository root:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/monsters/build_assets.py
```
