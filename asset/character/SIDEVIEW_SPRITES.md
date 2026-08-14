# Side-view character sprites

## Format

- Logical canvas: **32 × 32 pixels** per frame.
- Export scale: **16× nearest-neighbour**, matching `new_asset/basic.png`.
- Exported frame size: **512 × 512 pixels**.
- `idle.png`: one right-facing frame, **512 × 512**.
- `walk.png`: four right-facing frames in one horizontal strip, **2048 × 512**; each cell is 512 pixels wide.
- Color: RGBA PNG with binary alpha (fully transparent or fully opaque). All marks align to the 16× export grid; there are no antialiased or subpixel edge colors.

The idle logical alpha bounds are `(9, 3)–(26, 29)` for Taoist, `(7, 5)–(26, 29)` for Warrior, and `(7, 3)–(27, 29)` for Archer. These remain centered on the same 32 × 32 canvas and share the same ground line.

## Walk order

The strip is ordered left to right:

1. Contact A — rear leg back, leading leg forward; arms counter-swing.
2. Passing A — legs gather under the torso.
3. Contact B — the opposite leg leads; arms reverse.
4. Passing B — the forward foot lifts into the next loop.

Loop frames `0 → 1 → 2 → 3` at about 8–10 fps. The head and central torso crop is byte-identical in every walk frame; only the limb parts and their resulting silhouette outlines change.

## Generation method

The sprites are deterministic pixel constructions in `tools/generate_sideview_sprites.py`. The script draws each character once on a 32 × 32 RGBA canvas from flat polygons and rectangles, builds a one-logical-pixel dark outer outline from the combined silhouette, reuses the fixed head/torso layers for all poses, and changes only programmatic arm/leg parts. It then enlarges with nearest-neighbour sampling and writes the six runtime PNGs.

Regenerate from the repository root with:

```text
python tools/generate_sideview_sprites.py
```

The generator validates dimensions, binary transparency, bounded palettes, distinct walk poses, stable head/torso bytes, and uniform 16 × 16 export blocks before saving.

## Visual verification

All six exports were inspected as nearest-neighbour representations of their 1× logical pixels. At logical scale, the three silhouettes remain distinct: the Taoist has a topknot and pale blue-trimmed dopo, the Warrior has a tied headband and broad lamellar chest, and the Archer has a wide paeraengi with a diagonal leather harness. The walk strips were read left-to-right and as a loop; contact frames alternate cleanly, passing frames keep the feet from sliding, hands remain empty, and the fixed upper body prevents frame-to-frame costume flicker.

## Integrator notes

- The authored direction is **right**. Mirror the same textures horizontally in-engine for left-facing movement; no lettering, weapon, or direction-specific emblem needs a separate left asset.
- Slice `walk.png` as a 4-column, 1-row sprite sheet using 512 × 512 regions.
- Use nearest-neighbour sampling. In Godot, keep texture filtering and mipmaps disabled for crisp logical pixels.
- Keep every frame on its full canvas rather than trimming transparent margins; shared canvas alignment prevents animation jitter.
- Do not scale these relative to `new_asset/basic.png`; both use the same 16× export factor.
