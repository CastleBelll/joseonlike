# V7 gameplay asset batch

## Outcome

This batch replaces every currently requested loot and weapon-icon placeholder with a
coherent Character.png-family sprite, adds the two requested east-canonical travel sprites,
and supplies two small status loops plus an optional damage-digit strip. No file under
`data/`, `scripts/`, or `scenes/` was edited.

Shipped:

- 11 loot idle icons at `res://asset/drop/loot/<loot_id>/idle.png`, each on a `24x24`
  canvas with an 18-pixel maximum content height.
- 5 weapon icons at `res://asset/weapon/icons/<weapon_id>.png`, each `32x32`.
- `res://asset/weapon/travel/lightning_bolt.png` and
  `res://asset/weapon/travel/beopgeom_bolt.png`, each `32x32` and pointing east (`+X`).
- `res://asset/effect/status/burn/strip.png` and
  `res://asset/effect/status/seal/strip.png`, horizontal `4 x 24x24` loops.
- Optional `res://asset/ui/hud/damage_digits.png`, ten horizontal `8x10` cells ordered
  `0..9`.

The reviewed overview is `asset/raw/v7_asset_contact_sheet.png`; exact canvases, colour
counts, hard-alpha values, opaque counts, bboxes, and SHA-256 hashes are retained in
`asset/raw/v7_asset_metrics.json`. Final PNGs can be reproduced with
`python tools/asset/generate_v7_batch.py`.

## Loot metrics and tier accents

Every loot icon uses binary alpha, a one-pixel near-black outline, two or three material
tones, and a one-pixel outer tier rim using the live fallback colours from `LootDrops`:
common `#EBEBEB`, uncommon `#5CD96B`, rare `#528FF2`, epic `#A861EB`.

| id | tier | content bbox | opaque pixels | visual read |
|---|---|---:|---:|---|
| `bamboo` | common | 17x18 | 223 | three green stalks with a tan binding |
| `tough_fiber` | common | 19x18 | 279 | tan rope coil with a loose end and central gap |
| `beast_fang` | common | 16x18 | 226 | curved ivory fang with a brown root |
| `talisman_paper` | common | 14x18 | 243 | yellow folded paper with a red seal glyph |
| `wonhon_shard` | uncommon | 13x18 | 179 | pale cyan faceted soul shard |
| `dokkaebi_flame` | uncommon | 15x18 | 193 | teal wisp with a white spiral core |
| `whetstone` | rare | 17x18 | 240 | grey bevelled sharpening block |
| `ghost_iron` | epic | 17x18 | 238 | dark cursed iron with a violet fissure |
| `fire_spirit_stone` | epic | 16x18 | 226 | black-red stone with an ember core |
| `thunder_stone` | epic | 18x18 | 253 | blue stone split by a cyan bolt |
| `cinnabar` | rare | 17x18 | 256 | clustered red mineral crystals |

The silhouettes deliberately do not rely on tier hue: material form remains the primary
identifier and the rim is only a secondary rarity signal.

## Weapon metrics

| asset | canvas | content bbox | opaque pixels | notes |
|---|---:|---:|---:|---|
| `icons/sharp_sword.png` | 32x32 | 28x29 | 311 | narrow bright steel and cyan edge |
| `icons/ghost_sword.png` | 32x32 | 27x29 | 340 | jagged dark blade and violet curse vein |
| `icons/flame_sword.png` | 32x32 | 27x28 | 323 | orange blade with asymmetric flame tongue |
| `icons/lightning_talisman.png` | 32x32 | 21x29 | 525 | yellow paper and blue bolt glyph |
| `icons/beopgeom.png` | 32x32 | 28x29 | 335 | red ritual blade, gold guard, paper seal |
| `travel/lightning_bolt.png` | 32x32 | 30x18 | 297 | east-pointing stepped lightning head/tail |
| `travel/beopgeom_bolt.png` | 32x32 | 30x12 | 223 | east-pointing red ritual-sword bolt |

Dedicated impact sets were intentionally not shipped. `WeaponArt` currently maps both
weapons to `spirit_bolt`, whose paired arrival is `spirit_bolt_impact`; adding differently
named `64x64` four-frame folders would remain unwired and choosing names/mappings would
require the prohibited game-code change. The travel assets are ready for a later mapping
pass; until then the existing spirit-bolt travel/impact pair remains the runtime fallback.

## Status strips

The status strips use a loop rather than the one-shot anticipation/expansion/peak/
dissipation contract of `EffectPool`. See `asset/effect/status/README.md` for the exact
cell rectangles, frame bboxes, opaque counts, transition deltas, anchor, and timing.

## Damage-number recommendation

The current engine-rendered labels already use the right palette and hierarchy. Keep the
existing spec: normal `#FFFFFF` at 14 px; critical `#FFD140` at 20 px; both with a 3 px
`#1A1712` outline, no drop shadow, 0.6 second lifetime, and 24 px upward travel. The larger
gold critical number communicates type through size as well as hue.

`asset/ui/hud/damage_digits.png` is an optional hard-alpha `0..9` sheet (`80x10`, ten
`8x10` cells) if a future HUD pass needs deterministic pixel glyphs. It is not wired and
does not replace the engine font.

## Generation provenance

The built-in image-generation workflow produced one supporting loot concept sheet at
`asset/drop/raw/v7_loot_concept_imagegen.png`. Its final prompt was:

> Create an orderly 4-column by 3-row Joseon-folklore material icon sheet containing
> bamboo, tough plant fibre, beast fang, talisman paper, soul shard, dokkaebi flame,
> whetstone, cursed iron, ember stone, thunder stone, and cinnabar; match the supplied
> Character.png/drop/weapon references with low-resolution pixel art, flat quantized
> palettes, a dark one-pixel-looking outline, crisp blocky pixels, consistent apparent
> size, and a flat `#FF00FF` background; use no labels, shadows, gradients, extra objects,
> or watermark.

That concept was used only for subject/silhouette comparison. It was too detailed to cut
directly to `24x24`, so every final sprite was authored by deterministic logical-pixel
primitives and palette rules. Higgsfield was not used: an additional generative backend
would not improve these exact-grid assets and would add a second non-deterministic source.

## Verification

Visual review was performed on `asset/raw/v7_asset_contact_sheet.png` at nearest-neighbour
scale. The deterministic generator rejects wrong canvases, empty images, soft alpha, and
duplicate status frames; its output reports 21 final PNGs. Repository import, full asset
verification, data validation, and a clean regeneration are recorded in the task handoff.
