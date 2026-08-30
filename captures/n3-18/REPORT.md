# N3-18 Per-skill Effect Rework — Diagnosis & Fix Report (2026-08-16)

Method: all twelve effects captured in isolation at 540x960 on the real night
stage via `tools/weapon_demo.tscn` (hit-triggered + timed shots), before and
after, judged by eye. Crowd legibility proven with a 6-weapon heavy build
playtest at the surge (`tools/playtest.tscn --weapon=hwabu
--grant=noebu,honbul,gyeolgye,jineon,sal --seed=7`).

Captures: `captures/n3-18/before/` (96 shots), `captures/n3-18/after/`
(96 shots), crowd: `captures/n3-18/after/surge_crowd.png`.

| # | 기술 | What was wrong (failure axes) | What changed | Reads now? |
|---|---|---|---|---|
| 1 | 낡은 부적 (single) | LEGIBILITY: 6x12px paper invisible in flight — a hit was just a damage number (before `demo_old_talisman_hit2`) | Paper 7x14 from data (`paper_width/length_px`) + short flight trail (`paper_trail_sec` 0.14) on every shot | Yes — throw path visible (after `demo_active_chukji_2`, top-left paper+trail) |
| 2 | 화부 (explosion) | COLOUR: pack sprite's magenta rays + arcade orange screamed against the night palette. SCALE: frame art filled ~55% of the frame → blast drew ~90px for a 180px true diameter — a lie. MECHANIC: ray-star read "sparkle", not area | Sprite dropped (sheet deleted). Parametric BlastRing EXPLOSION style: gold/white core flash (first 35%), filled disc + rim easing exactly onto the data radius, 8 ember sparks riding the front. Duration 0.35→0.45 | Yes — warm fire disc landing on the true area (after `demo_hwabu_hit2`) |
| 3 | 뇌부 (chain) | LEGIBILITY: bolt only drew BETWEEN consecutive hits — vs sparse targets nothing ever showed; 3.5px width vanished at 540px (before `demo_noebu_hit2`/`_5`: zero visible effect) | First hit now crackles a short leg in along the flight line (`chain_first_leg_px` 44). Bolt root width 3.5→5 (data `chain_bolt_width_px`), duration 0.22→0.3, brighter core | Yes — lightning arcs into the target even solo (after `demo_noebu_hit2`) |
| 4 | 석장 (melee arc) | MECHANIC: two thin concentric arc slivers in dim tan read as disconnected scratches, not a swing area (before `demo_seokjang_hit2`) | Filled wedge polygon from player to true range + bright PAPER leading edge with white core; sweep 0.22→0.26. Allocation-free (pre-sized PackedVector2Array) | Yes — swung sector + direction obvious (after `demo_seokjang_hit2`) |
| 5 | 혼불 (orbit+burn) | SCALE/COLOUR: 2.1x glow halo turned 16px orbs into ~65px white fog moons; long trail smeared comets (before `demo_honbul_4`) | Glow capped at the data hit radius (what glows is what hits), 3-lobe tapering flame body + white core, trail 0.24→0.15s and thinner | Yes — floating soul flames, hitbox honest (after `demo_honbul_4`) |
| 6 | 법검 (pierce) | TIMING: 0.16s fat trail read as comet blob, blade 4x24 small | Blade 5x32 (data), trail 0.24s — a drawn line through the crowd | Yes — piercing streak (after `demo_beopgeom_hit2`) |
| 7 | 결계 (ward) | MECHANIC: plain gold circle = debug range ring, not a barrier formation (before `demo_gyeolgye_4`) | Rotating dashed outer ring + counter-rotating double-square (eight-point) sigil + soft fill; spin from data (`ward_spin_deg_s` 40). Tick pulse kept. Spin phase reset on pooled re-arm | Yes — unmistakable 진 (after `demo_gyeolgye_4`) |
| 8 | 신장 (summon strike) | PLAYBACK: pack strike frames incoherent at 28px — white blob at the hit (before `demo_sinjang_hit2`). (Summon body = registered placeholder art, out of scope) | Sprite dropped (sheet deleted); code X-slash promoted to shipped visual, half-length 12→18 from data (`summon_strike_px`), 0.16→0.2s | Yes — crisp tinted X with white core (after `demo_sinjang_hit2`) |
| 9 | 진언 (shockwave) | COLOUR/MECHANIC: filled disc + core wash drew a pale mush blob over the player and enemies — fog, not a control wave (before `demo_jineon_hit1`) | New BlastRing WAVE style: double ring + white core rim, no fill, landing on the data radius; 0.35→0.5s. Camera nudge kept | Yes — clean expanding pulse, enemies inside stay readable (surge_crowd.png, rings around player) |
| 10 | 살 (spreading curse) | TIMING: 0.3s jump vanished before the eye caught the spread; thin bolt | Jump 0.45s (`curse_jump_sec`), bolt width/core shared with chain (5px root). Curse ⊗ mark unchanged (already read) | Yes — spread leg visible, marks read across a crowd (after `demo_sal_hit2`, surge_crowd.png) |
| 11 | 축지 (blink) | COLOUR: white smoke sheet modulated ACCENT_TAOIST (#4a7fd6) = near-black smoke on night ground — invisible (before `demo_active_chukji_2`) | Tint → WEAPON_SOUL (pale soul-blue), logical 48→56px. Sheet kept (smoke is not parametric; fits) | Yes — both ends of the jump read (after `demo_active_chukji_2`) |
| 12 | 벽사진 (emergency burst) | SCALE/COLOUR: DeathPuff reuse opened a 110px OPAQUE flat gold pancake + 0.28-alpha full-screen olive wash for 0.4s — paint splat, palette killed (before `demo_active_byeoksajin_2`) | Pooled BlastRing WAVE at the true 220px radius (`burst_ring_sec` 0.55); screen flash 0.4→0.22s and alpha 0.28→0.14 (punctuation, not flood) | Yes — gold wave says "cleared up to here" (after `demo_active_byeoksajin_2`) |

## Sprite vs parametric split (re-examined)
- Dropped sheets: `explosion.png` (colors + scale lie), `strike_flash.png`
  (incoherent at 28px). Both deleted; ASSET_LICENSES.md updated.
- Kept sheet: `blink_puff.png` (smoke — genuinely better than parametric).
- Everything radius-driven or point-to-point stays code-drawn: blast, wave,
  bolts, wedge, ward sigil, orbit flames, trails.
- Real art still wanted (already registered in ASSET_REQUIREMENTS.md):
  ward ground decal, summon body sprites, per-weapon travel/impact art.

## Performance
Surge, heavy 6-weapon build, seed 7: **fps min 59 / avg 60** (1775 samples),
whole-run floor 45 (one-off during boss+surge overlap, same as baseline runs),
peak live 50, victory 300s. Baseline was min 59 / avg 60 → **no frame cost**.

## Regression evidence (same playtest run)
Victory at 300s, 10 level-ups picked, mod card taken (gwisal epic), boss
engaged (hp 715/2400 at timeout), damage numbers/hit flash/knockback/death
puffs/loot/HUD all exercised; tests 285/285 PASS; validate_data PASS;
headless import clean.
