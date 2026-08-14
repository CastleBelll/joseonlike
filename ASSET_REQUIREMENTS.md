# JOSEONLIKE — Asset Requirements

**Asset production is frozen.** The owner supplies art and audio. Do not generate, cut,
commission or "temporarily improve" assets during a feature session.

When a feature needs art that does not exist:

1. Ship the feature with `PlaceholderArt` (`scripts/combat/placeholder_art.gd`) or an
   existing sprite.
2. Add a `[MISSING]` entry below.
3. Continue. A missing asset never blocks or delays a gameplay feature.

Style, sizes, direction naming and set rules: [ASSET_SPEC.md](ASSET_SPEC.md).

Entry format:

```
[MISSING] <asset_id>
Size:      <WxH px>
Members:   <frames / rotations / states required>
Used by:   <feature or data id that references it>
Fallback:  <what ships until it arrives>
```

---

## Missing

```
[MISSING] loot drop icons (9): bamboo, tough_fiber, beast_fang, talisman_paper,
          wonhon_shard, dokkaebi_flame, whetstone, ghost_iron, fire_spirit_stone
Size:      24x24 px idle (+ optional 32x32 collect frames x4, like existing drops)
Members:   res://asset/drop/loot/<loot_id>/idle.png per loot id
Used by:   DropPool loot drops (R2-2), data/loot.json
Fallback:  PlaceholderArt swatch tinted by tier (LootDrops.TIER_TINTS)
```

```
[MISSING] mod weapon icons (3): sharp_sword, ghost_sword, flame_sword
Size:      same as existing weapon icons
Members:   res://asset/weapon/icons/<weapon_id>.png
Used by:   data/weapon_mods.json results (R2-4)
Fallback:  the base sword icon (asset/weapon/icons/sword.png)
```

## Anticipated (not yet needed — do not pre-produce)

These become `[MISSING]` entries only when the feature that needs them is actually
being built:

- Abandoned Temple stage ground and backdrop (ROADMAP M3-1)
- Second boss set (M3-3)
- Camp interiors for Workshop / Training Ground / Shrine (M2-3..M2-5)
- Icons for weapons added past the current 7 (M3-4..N)
