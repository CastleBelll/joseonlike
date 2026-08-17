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

[MISSING] weapon_gyeolgye_ward
Size:      ~170x170 px (radius-scaled)
Members:   ward circle ground decal + placement flash, fire variant (화염 결계)
Used by:   weapons.json gyeolgye / hwayeom_gyeolgye (N4-4b)
Fallback:  palette-token rotating sigil — dashed ring + eight-point star (scripts/combat/ward.gd, N3-18)

[MISSING] summon_sinjang
Size:      40x40 logical frames (16x export blocks, like the taoist)
Members:   idle + 4-frame walk, right-facing (left is mirrored), thunder tint variant
Used by:   weapons.json sinjang / noe_sinjang (N4-4b)
Fallback:  palette-token robed silhouette (scripts/combat/summon.gd)

[MISSING] fx_jineon_shockwave
Size:      ~270x270 px expanding ring
Members:   3-4 frame pulse ring, sealing-gold variant (봉인 진언)
Used by:   weapons.json jineon / bongin_jineon (N4-4b)
Fallback:  reused DeathPuff disc flash

[MISSING] fx_sal_curse_mark
Size:      ~16x16 px overhead mark
Members:   cursed-enemy marker + projectile talisman variant
Used by:   weapons.json sal / gwisal (N4-4b)
Fallback:  curse-tinted projectile paper; no on-enemy marker yet

[MISSING] ui_active_buttons
Size:      64x64 px each
Members:   축지/벽사진 icon discs, ready + cooling states (AC-3 scope)
Used by:   CombatHud active cluster (N4-4b)
Fallback:  wood-token drawn discs with the skill name

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

Satisfied by the AC-3 icon set + N3-13 wiring (asset/ui, scripts/ui/ui_icons.gd):
all 28 weapon icons, all 11 loot icons (mod-card display; the in-field drop
stays the intentional tier-tinted diamond per DESIGN.md §5.1), and the HUD
skull/coin/pause/info glyphs. The former [MISSING] entries for loot icons,
thunder_stone, mod weapon icons, weapon card icons and combat HUD icons are
cleared; what remains of those wants is below.

```
[MISSING] taoist archetype weapon FIELD art (N4-4a): travel/impact sprites for
          hwabu, noebu, seokjang, honbul, beopgeom, hwaryeongbu, noejeongbu,
          bongmageom, ghost_staff, flame_honbul (icons shipped in AC-3)
Size:      charm travel sprites ~8x14, sword-qi blade ~6x26, staff swing arc
           sheet, soul-flame orb ~10x10 (2-frame flicker), explosion burst
           sheet ~3 frames
Used by:   N4-4a weapon mechanics (scripts/combat/auto_weapon.gd,
           projectile.gd)
Fallback:  palette-token placeholders per weapon — tinted paper/blade rects
           (WEAPON_FIRE/LIGHTNING/SEAL), WOOD/WEAPON_GHOST arc strokes,
           WEAPON_SOUL orbs, WEAPON_FIRE ring flash
```

```
[MISSING] passive stat icons: attack_damage, attack_speed, move_speed,
          max_hp, magnet_radius
Size:      32x32 logical, like the weapon icons
Members:   res://asset/ui/passive_icons/<passive_id>.png (UiIcons would need
           a passive_icon lookup once these exist)
Used by:   N3-6 power-up popup (scripts/ui/level_up_popup.gd icon wells)
Fallback:  INK well + first syllable of name_ko as a GOLD glyph (the N3-13
           missing-icon fallback path)
```

```
[MISSING] title corner settings gear glyph
Size:      48x48 px touch glyph
Members:   res://asset/ui/title/settings_gear.png
Used by:   title corner utilities (scripts/ui/title.gd _build_utilities);
           DESIGN.md §4 and asset/title/preview.png show a gear icon
Fallback:  wood-styled text button "설정"/"Settings"
```

```
[MISSING] camp_backdrop (N5-3)
Size:      540x960 full-bleed (2x export like the title layers)
Members:   night village/base-camp scene behind the camp UI — hanok buildings
           for 괴이록/무기 도감/훈련장/지역 선택 spots, lantern accents;
           optional per-building sign art once interiors exist
Used by:   scenes/camp.tscn (scripts/ui/camp_screen.gd)
Fallback:  NIGHT background + NIGHT_BROWN stats card + CARD_BG building spot
           buttons (palette tokens only)
```

```
[MISSING] meta_tree_backdrop (N7-1)
Size:      540 wide, ~750+ tall scrollable strip (2x export)
Members:   신목 (sacred tree) illustration behind the 명부수 node graph —
           trunk, branches, canopy glow like 설화 capture `_02`; optional
           root/soil footer under the deepest row
Used by:   scenes/meta_tree.tscn (scripts/ui/meta_tree_screen.gd Canvas)
Fallback:  code-drawn WOOD_BORDER trunk line + prerequisite edge lines
           (palette tokens only)
```

```
[MISSING] meta_node_icons (N7-1, roster expanded N7-2)
Size:      16px logical (32px 2x NEAREST), one per data/meta_tree.json node
Members:   trunk: iron_bones / wind_steps / sharp_talisman / soul_pull /
           quick_hands / coin_eye / head_start / insight / fourth_card /
           first_find / stone_skin / long_breath / revive; taoist branch:
           burn_mastery / ward_wide / chain_reach / orbit_extra /
           seal_ease; warrior: hwando_hone / iron_stance; archer:
           wind_read / rapid_nock; plus a small lock badge overlay
Used by:   meta tree node circles + detail card icon well
Fallback:  loot icons borrowed per node via the "icon" data field
           (tough_fiber, beast_fang, talisman_paper, wonhon_shard,
           whetstone, bamboo, cinnabar, thunder_stone); lock reads as the
           word 잠김 + dimmed icon
```

```
[NICE-TO-HAVE] bestiary_undiscovered_stamp (N5-4)
Size:      16px logical (32px 2x NEAREST)
Used by:   괴이록 undiscovered row icon well (scripts/ui/bestiary_screen.gd)
Fallback:  IN USE — the entry's real art self-modulated to INK reads as a
           silhouette; entries with no art show a "?" glyph. No new asset is
           required for the feature; a dedicated ink-stamp mark would only
           polish the ??? rows.
```

```
[MISSING] reward_chest (N5-5)
Size:      ~20x16px logical in-world sprite (closed + open frame; a short
           3-4 frame open burst is a plus)
Used by:   elite reward chest entity (scripts/combat/chest.gd)
Fallback:  IN USE — code-drawn wood box with gold clasp + pulsing gold
           glow. Reads, but a real chest sprite is the payoff moment and
           deserves art.
```

```
[MISSING] pickup_set (N5-5)
Size:      ~14px logical in-world sprites, 4 members: coin (엽전), health
           (medicine pouch/herb), nuke (talisman bomb/spark), magnet
           (lodestone)
Used by:   prop-break pickups (scripts/combat/pickup.gd)
Fallback:  IN USE — code-drawn glyph discs (gold coin w/ square hole,
           green cross, vermilion burst star, blue horseshoe). Shape+color
           per DESIGN.md §2.
```

```
[NICE-TO-HAVE] prop_break_frames (N5-5)
Size:      per breakable prop (bamboo_clump_small / rock_small /
           fallen_log), 2-3 shatter frames or a damaged variant
Used by:   Breakable props (scripts/combat/breakable.gd)
Fallback:  IN USE — hit flash + pooled death-puff ring on shatter.
```

## Anticipated (not yet needed — do not pre-produce)

These become `[MISSING]` entries only when the feature that needs them is actually
being built:

- Abandoned Temple stage ground and backdrop (ROADMAP M3-1)
- Second boss set (M3-3)
- Stage 2/3 monster sprite sets (gwimyeon_dokkaebi .. gumiho): their
  data/monsters.json entries carry no `sprite` key yet and render the
  placeholder rect until each stage is actually built
- Camp interiors for Workshop / Training Ground / Shrine (M2-3..M2-5)
- Icons for weapons added past the current 7 (M3-4..N)
