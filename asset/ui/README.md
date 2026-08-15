# UI icon and chrome assets

This set replaces the Korean-letter placeholders with Higgsfield-generated
pixel art. The build reads `data/weapons.json` and `data/loot.json` and fails if
an ID is missing from the atlas mapping, so filenames stay directly bindable
without a lookup table. The current data contains 28 weapon IDs and 11 loot
IDs; no extra ID was invented to match the older task-count wording.

## Logical and export sizes

All gameplay assets are authored at the logical size below and exported once at
16x with nearest-neighbour scaling. Icon and chrome alpha is binary.

| Folder / file | Logical | Export | Contract |
| --- | ---: | ---: | --- |
| `weapon_icons/<id>.png` | 32x32 | 512x512 | 28 weapon IDs, transparent |
| `loot_icons/<id>.png` | 24x24 | 384x384 | 11 loot IDs, transparent |
| `hud/{skull,coin,pause,info,timer}.png` | 16x16 | 256x256 | transparent HUD glyphs |
| `chrome/wood_button_normal.png` | 64x32 | 1024x512 | normal 9-slice |
| `chrome/wood_button_hover.png` | 64x32 | 1024x512 | hover 9-slice |
| `chrome/wood_button_pressed.png` | 64x32 | 1024x512 | pressed 9-slice |
| `chrome/paper_panel.png` | 64x64 | 1024x1024 | paper-panel 9-slice |
| `verification-grid.png` | 280x268 source | 1120x1072 | 1x INK wells, viewed at 4x |

### 9-slice margins

- Wood buttons: left/right/top/bottom = **8 logical px** = 128 exported px.
- Paper panel: left/right/top/bottom = **12 logical px** = 192 exported px.

These margins keep the rounded button corners and the paper panel's lattice
ornaments fixed. Only the quiet center and straight middle edges may stretch.
The three button centers palette-snap to the DESIGN tokens: normal `#e2a057`,
hover `#edb26c`, pressed `#c08544`; borders use the `WOOD_BORDER` family.

## IDs and verification order

The verification grid uses the JSON insertion order, left-to-right. Weapon rows
contain seven wells each:

```text
old_talisman, fire_talisman, phoenix_talisman, beopgeom, bongmageom, hwabu, hwaryeongbu
noebu, noejeongbu, seokjang, ghost_staff, honbul, flame_honbul, gyeolgye
hwayeom_gyeolgye, sinjang, noe_sinjang, jineon, bongin_jineon, sal, gwisal
sword, twin_sword, sharp_sword, ghost_sword, flame_sword, bow, divine_bow
```

Loot follows in two rows:

```text
bamboo, tough_fiber, beast_fang, talisman_paper, wonhon_shard, dokkaebi_flame, whetstone
ghost_iron, cinnabar, thunder_stone, fire_spirit_stone
```

The HUD row is `skull, coin, pause, info, timer`, followed by the three wood
states and the paper panel. The 1x composition was inspected on `INK #1a1613`
at 4x NEAREST: charms retain paper/flame/bolt differences, staffs remain long,
wards and mantras are distinct circles, the summon pair retains armored busts,
and every martial weapon keeps a countable blade/bow silhouette. Loot tiers use
bundle, tail/notch, dish/tool, and faceted/pronged silhouettes in addition to
their common/uncommon/rare/epic colors.

## Palette and processing

The generated hues are retained and reduced per icon to 8-18 colors. Every
source is chroma-keyed before resizing, RGB is premultiplied by alpha, both RGB
and alpha are BOX-downscaled, alpha is thresholded to binary, and a one-logical-
pixel `#110d14` silhouette outline is restored. Only the final 16x export uses
NEAREST. The four chrome plates additionally snap to the DESIGN.md wood, paper,
border and lattice color families.

The first weapon atlas included a generated dark icon-well preview behind each
subject. That source-only well is removed before resizing, then the same shared
outline step restores the icon boundary; shipped weapon PNGs are transparent.
The HUD source arranged the first four glyphs as a 2x2 block and tucked the
timer into unused space, so documented source-space crops isolate those five
generated objects without redrawing them.

## Higgsfield generation record

Requested model: `nano_banana_pro`; receipts reported `nano_banana_2`, 1K.
Seven sources cost 2 credits each, 14 credits total.

| Source | Job ID |
| --- | --- |
| Weapon atlas A | `8e9e6923-0807-40c4-af63-e096761a25d0` |
| Weapon atlas B | `9f52901c-42a4-4980-b778-c39a1103c1c6` |
| Weapon atlas C | `33ea2d75-5a07-4f08-8e98-34cbfb64fc7d` |
| Weapon atlas D | `b9b32d1f-c011-4bc1-bd5c-e4611b02e563` |
| Loot atlas | `95708d0b-5998-4467-8e18-8e584aafa00a` |
| HUD atlas | `7317550f-bd64-4dd9-89c6-c871b9e51ff6` |
| Chrome atlas | `fea4a173-26c2-4885-a8d8-37de222cf4f7` |

The conditioning images were the specified power-up and gameplay captures, the
Taoist idle sprite, and the bamboo-forest contact sheet. Shared prompt:

```text
Create isolated 16-bit game pixel-art objects on a perfectly flat #ff00ff
chroma-key atlas. Use chunky square pixels, a one-pixel-like near-black outline,
flat high-contrast clusters, 1-2 hard cel-shading steps, and upper-left light.
One centered object per exact cell, generous magenta gutters, no overlaps,
labels, letters, numbers, frames, watermark, gradients, blur, or #ff00ff inside
an object. Silhouette and action must remain legible at the stated logical size.
```

Weapon atlas subjects were specified cell-by-cell as paper/flame/phoenix,
explosion/lightning, ringed staffs, orbiting soul flames, ward circles, curse
mark, armored generals, mantra/seal rings, sword-qi blades, curved hwando and
horn bows. Loot was specified cell-by-cell using the exact JSON material names
and tier-shape hierarchy. HUD requested the five named minimal glyphs. Chrome
requested three blank, identical button silhouettes in the DESIGN state colors
and one blank paper panel with four confined lattice corners.

## Rebuild

Requires Python 3 and Pillow. Missing immutable Higgsfield source images are
downloaded to `tmp/ui_icons/` from the URLs embedded in `build_assets.py`.

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/ui/build_assets.py
```

The build fails on JSON/mapping drift, incorrect logical size, non-binary alpha,
undersized silhouettes, or surviving magenta fringe. It then recreates every
16x PNG and `verification-grid.png` deterministically.
