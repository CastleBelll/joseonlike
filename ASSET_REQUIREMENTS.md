# JOSEONLIKE — Asset Requirements

**Asset production is frozen.** The owner supplies art and audio. Do not generate, cut,
commission or "temporarily improve" assets during a feature session.

## Drop box layout (reorganised 2026-08-20)

```
new_asset/
  owner/      every pack and file the OWNER sourced — one folder per pack
  generated/  art generated on request inside this project
```

Two folders, because the two have different standing. Owner packs are source
material with their own licensing; generated files are this project's output
and can be re-made from a prompt. Build scripts read from `new_asset/owner/…`;
nothing under either folder is ever loaded by the game directly.

## Owner drop box (2026-08-14)

The owner sources art himself and drops it into `new_asset/owner/`. Features ship with rough
placeholders and the art is wired in afterwards as its own commit.

- Drop raw files anywhere under `new_asset/owner/` — any resolution, green screen or
  transparent, sheet or single frame. Naming hint only: `<subject>.png`,
  `<subject>_walk.png`.
- Processing to game-ready assets (chroma key, area downscale, palette quantization,
  frame strip assembly) happens in a separate asset commit; the source file stays in
  `new_asset/owner/` untouched.
- Game-ready output lives at `asset/characters/<id>/{idle,walk,portrait}.png`,
  `asset/weapon/...`, `asset/drop/...`. Reference pipeline:
  `asset/characters/taoist/build_assets.py`.
- Nothing in `new_asset/owner/` is ever loaded by the game directly.

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

[DELIVERED N9-8] summon_sinjang — asset/weapon/fx/sinjang.png (20x32,
           authored in asset/weapon/build_fx.py: helmed spirit-general in
           luminance, engine-modulated for the thunder variant), wired in
           scripts/combat/summon.gd. Idle/walk animation frames remain a
           nice-to-have for a future art pass.

[MISSING] fx_jineon_shockwave
Size:      ~270x270 px expanding ring
Members:   3-4 frame pulse ring, sealing-gold variant (봉인 진언)
Used by:   weapons.json jineon / bongin_jineon (N4-4b)
Fallback:  reused DeathPuff disc flash

[MISSING] fx_sal_curse_mark
Size:      ~16x16 px overhead mark
Members:   cursed-enemy marker (projectile variant shipped N9-3f)
Used by:   weapons.json sal / gwisal (N4-4b)
Fallback:  no on-enemy marker yet

[MISSING] ui_active_buttons
Size:      64x64 px each
Members:   축지/벽사진 icon discs, ready + cooling states (AC-3 scope)
Used by:   CombatHud active cluster (N4-4b)
Fallback:  wood-token drawn discs with the skill name

---

## Missing

```
[MISSING] xp orb sprite (AC-4)
Size:      orb ~10x10 px
Members:   res://asset/drop/xp_orb.png (idle, optional 2-frame shimmer)
Used by:   N3-5 XP drop (scripts/combat/xp_orb.gd)
Fallback:  cyan-green draw_circle orb
```

Satisfied by the AC-3 icon set + N3-13 wiring (asset/ui, scripts/ui/ui_icons.gd):
all 28 weapon icons, all 11 loot icons (mod-card display; the in-field drop
stays the intentional tier-tinted diamond per DESIGN.md §5.1), and the HUD
skull/coin/pause/info glyphs. The former [MISSING] entries for loot icons,
thunder_stone, mod weapon icons, weapon card icons and combat HUD icons are
cleared; what remains of those wants is below.

```
[MISSING] taoist archetype non-projectile FIELD art (N4-4a): seokjang,
          honbul, ghost_staff, flame_honbul (projectile travel + elemental hit
          sprites shipped N9-3f; icons shipped in AC-3)
Size:      staff swing arc sheet, soul-flame orb ~10x10 (2-frame flicker)
Used by:   N4-4a weapon mechanics (scripts/combat/auto_weapon.gd,
           projectile.gd)
Fallback:  palette-token WOOD/WEAPON_GHOST arc strokes and WEAPON_SOUL orbs
```

```
[DELIVERED N9-89] passive stat icons — all 18 of data/passives.json, one
           Joseon folk object each (tiger claw, folding fan, jipsin, gourd,
           ginseng, rattan shield, bokjumeoni, lodestone, bound books,
           talisman fan, arrow, yut sticks, tiger fang, cinnabar brush, bagua
           mirror, flint striker, chain links, seal stamp), generated as one
           batch so the set reads as one hand and installed by
           asset/build_from_generated.py. The old free-pack eleven (western
           boots, clover, gear-heart) are replaced.
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
[DELIVERED N9-12] camp_backdrop — asset/camp/backdrop.png (1080x1920,
           composited in asset/camp/build_backdrop.py from the N1-2-REVISED
           production title layers under a NIGHT scrim gradient), wired in
           scripts/ui/camp_screen.gd over the kept NIGHT fallback fill.
           Bespoke per-building sign art stays a future nice-to-have.
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
[DELIVERED N9-5d] reward_chest — asset/pickups/chest.png (22x18, authored
           in asset/weapon/build_fx.py: 반닫이 silhouette, brass fittings
           + lock plate), wired in scripts/combat/chest.gd over the kept
           gold pulse. A dedicated open-animation frame set remains a
           nice-to-have for a future art pass.
```

```
[DELIVERED N9-89] pickup_magnet — asset/pickups/magnet.png (14x14,
           lodestone with iron filings and a red thread, generated and cut in
           asset/build_from_generated.py), wired in scripts/combat/pickup.gd
           KIND_TEXTURES. The code-drawn blue horseshoe stays as the
           missing-file fallback.
```

```
[NICE-TO-HAVE] prop_break_frames (N5-5)
Size:      per breakable prop (bamboo_clump_small / rock_small /
           fallen_log), 2-3 shatter frames or a damaged variant
Used by:   Breakable props (scripts/combat/breakable.gd)
Fallback:  IN USE — hit flash + pooled death-puff ring on shatter.
```

## 투사체 · 이펙트 스프라이트 시트 — 오너 작업 대기 (2026-08-20)

> **배경 날린 원본은 `new_asset/needs_sprite/`에 모여 있다.** 10장 전부 투명
> PNG이고, 같은 폴더의 `README.md`가 파일마다 목표 경로 · 셀 크기 · 권장 프레임
> 수를 적어둔다. `python asset/build_sprite_requests.py`로 다시 만든다.


N9-78에서 무기 아이콘 9종, 투사체 10종, 신장/석장 원호는 생성 이미지를 잘라
실제 경로에 넣었다. 아래 항목은 **가로 스트립(애니메이션)** 이라 한 장짜리
그림으로 대체할 수 없다. 참고용 원본은 `new_asset/generated/`에 있고, 프레임만
만들어 주면 같은 경로에 그대로 들어간다.

시트 규약: **정사각 프레임의 가로 스트립**. 프레임 수는 `너비 ÷ 높이`로
읽으므로 파일 모양이 곧 선언이다 — 고정된 프레임 수를 따로 적을 필요가 없다.

```
[NEEDS FRAMES] swing_arc — asset/effect/swing_arc.png
Size:      20px 정사각 프레임, 현재 2프레임 (40x20)
Used by:   근접 휘두름 궤적 (N9-70)
Reference: new_asset/generated/fx_swing_arc.png (양끝이 뾰족한 베기 자국)
Note:      초승달이 아니라 베기 자국이다 — 양끝이 바늘처럼 가늘어야 한다
```

### 투사체가 날면서 움직이려면 (N9-80)

투사체 그림도 스트립을 받는다. 다만 캐릭터 시트와 계약이 다르다 — 투사체는
정사각이 아니라(20x7, 18x10) 파일 모양만으로는 40x20이 한 장인지 2프레임인지
구분할 수 없다. 그래서 **프레임 수를 `data/weapons.json`에 적는다**:

```json
"travel_sprite": "res://asset/weapon/travel/old_talisman.png",
"travel_frames": 4
```

파일은 셀을 가로로 이어 붙인 것이고, 셀 크기는 지금 파일 크기 그대로다.
4프레임이면 `18x10` → `72x10`. 키를 빼면 1프레임(지금 상태)이다.
`travel_frames`가 폭을 나누지 못하면 `validate_data`가 실패한다.

지금 전부 1프레임이라 정지 그림이다. 움직이면 좋을 후보, 값어치 순:

| 투사체 | 셀 크기 | 왜 |
|---|---|---|
| `hwabu` / `hwaryeongbu` | 18x18 / 16x18 | 불꽃이 흔들려야 불로 읽힌다 |
| `sal` / `gwisal` | 18x18 / 16x18 | 저주 연기가 일렁여야 한다 |
| `old_talisman` / `fire_talisman` | 18x10 | 종이가 팔랑이는 것이 이 무기의 정체다 |
| `beopgeom` / `bongmageom` | 20x7 | 검기가 번쩍이면 좋지만 셋 중 제일 급하지 않다 |

4프레임이면 충분하다. 12fps로 도는데 비행이 1초 미만이라 그보다 많으면
플레이어가 못 본다.

공용 타격 이펙트 `hit_lightning` / `hit_paper` / `blink_puff`는 2026-08-24
일관성 패스에서 제한 팔레트 픽셀 아트로 교체했다. 미참조 무료팩 이펙트
`hit_neutral` / `hit_fire` / `hit_curse`는 레지스트리와 함께 삭제했다.

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
