# JOSEONLIKE — Asset Requirements

**Asset production is frozen.** The owner supplies art and audio. Do not generate, cut,
commission or "temporarily improve" assets during a feature session.

## Owner drop box (2026-08-14)

The owner sources art himself and drops it into `new_asset/`. Features ship with rough
placeholders and the art is wired in afterwards as its own commit.

- Drop raw files anywhere under `new_asset/` — any resolution, green screen or
  transparent, sheet or single frame. Naming hint only: `<subject>.png`,
  `<subject>_walk.png`.
- Processing to game-ready assets (chroma key, area downscale, palette quantization,
  frame strip assembly) happens in a separate asset commit; the source file stays in
  `new_asset/` untouched.
- Game-ready output lives at `asset/characters/<id>/{idle,walk,portrait}.png`,
  `asset/weapon/...`, `asset/drop/...`. Reference pipeline:
  `asset/characters/taoist/build_assets.py`.
- Nothing in `new_asset/` is ever loaded by the game directly.

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
[MISSING] old_talisman travel art + xp orb sprite (AC-4)
Size:      talisman ~8x14 px rotated to flight direction; orb ~10x10 px
Members:   res://asset/weapon/travel/old_talisman.png,
           res://asset/drop/xp_orb.png (idle, optional 2-frame shimmer)
Used by:   N3-3 auto-attack projectile, N3-5 XP drop (scripts/combat/projectile.gd,
           scripts/combat/xp_orb.gd)
Fallback:  code-drawn paper ColorRect + vermilion seal / cyan-green draw_circle orb
```

```
[MISSING] loot drop icons (9): bamboo, tough_fiber, beast_fang, talisman_paper,
          wonhon_shard, dokkaebi_flame, whetstone, ghost_iron, fire_spirit_stone
Size:      24x24 px idle (+ optional 32x32 collect frames x4, like existing drops)
Members:   res://asset/drop/loot/<loot_id>/idle.png per loot id
Used by:   DropPool loot drops (R2-2), data/loot.json
Fallback:  PlaceholderArt swatch tinted by tier (LootDrops.TIER_TINTS)
```

```
[MISSING] lightning_talisman weapon icon + travel art + thunder_stone loot icon
Size:      same as existing weapon icons / travel sprites / 24x24 loot idle
Members:   res://asset/weapon/icons/lightning_talisman.png,
           res://asset/weapon/travel/(lightning bolt).png,
           res://asset/drop/loot/thunder_stone/idle.png
Used by:   lightning talisman mod line (taoist lightning build)
Fallback:  old_talisman icon / spirit_bolt travel art / tier-tinted swatch
```

```
[MISSING] mod weapon icons (3): sharp_sword, ghost_sword, flame_sword
Size:      same as existing weapon icons
Members:   res://asset/weapon/icons/<weapon_id>.png
Used by:   data/weapon_mods.json results (R2-4)
Fallback:  the base sword icon (asset/weapon/icons/sword.png)
```

```
[MISSING] power-up card icons: weapon icons (old_talisman, sword, bow + upgrades)
          and passive stat icons (attack_damage, attack_speed, move_speed,
          max_hp, magnet_radius)
Size:      72x72 px card well (48x48 reuse in the owned-weapon strip)
Members:   weapons.json sprite paths (res://asset/weapon/icons/<id>.png) +
           res://asset/ui/passive_icons/<passive_id>.png
Used by:   N3-6 power-up popup (scripts/ui/level_up_popup.gd icon wells)
Fallback:  INK well + first syllable of name_ko as a GOLD glyph
```

```
[MISSING] combat HUD icons (AC-3): pause, info, skull kill counter, coin (yeopjeon)
Size:      20x20 px counter icons; 44x44 px touch glyphs (pause/info)
Members:   res://asset/ui/hud/{pause,info,skull,coin}.png
Used by:   N3-7 combat HUD (scripts/ui/combat_hud.gd)
Fallback:  code-drawn palette-token glyphs (PauseGlyph/InfoGlyph/SkullIcon/CoinIcon)
```

```
[MISSING] bamboo forest props (AC-4): bamboo_clump, rock, log, puddle solids +
          grass_tuft, fern, pebble decor
Size:      logical sizes in data/props.json "size" (e.g. bamboo_clump 48x96);
          bottom-center anchored; any uniform export scale (code rescales to
          the logical size, NEAREST)
Members:   res://asset/stages/bamboo_forest/props/<prop_id>.png
Used by:   N3-9 stage field (scripts/combat/stage_field.gd); art drops in with
          zero code change once the PNGs exist at these paths
Fallback:  palette-token placeholder shapes of the same logical size
```

## Anticipated (not yet needed — do not pre-produce)

These become `[MISSING]` entries only when the feature that needs them is actually
being built:

- Abandoned Temple stage ground and backdrop (ROADMAP M3-1)
- Second boss set (M3-3)
- Camp interiors for Workshop / Training Ground / Shrine (M2-3..M2-5)
- Icons for weapons added past the current 7 (M3-4..N)
