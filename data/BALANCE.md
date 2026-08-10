# M1 Balance Notes — Bamboo Forest (10 min / 600s)

**Re-derived against the real formulas landed in `scripts/core/run_state.gd`
(commit 367da99 / 071776a).** The original version of this document assumed a
guessed arithmetic XP curve and a "player dumps half their picks into the
starting weapon" model. Both were wrong. This version reads `run_state.gd`
directly and derives the curve from it.

**Reconciled against a real combat playthrough (this pass, main at
409646e).** combat played Bamboo Forest end to end against this worktree's
data and reported ground truth: `{victory:true, time_sec:627.6, kills:213,
gold:352}`, boss spawned at t=599.8s, boss killed in 27.6s at ~145 observed
single-target DPS. Two defects follow directly from that measurement (boss
TTK, a pressure-column arithmetic error) and are fixed below using the
observed numbers as ground truth, not by re-deriving a new model from
scratch — per instruction, measured beats modeled where they disagree.

## What changed from the first pass, and why it mattered

`RunState.xp_to_next(L) = round(5 * 1.25^(L-1))` — **geometric**, not the
`8 + 4*(L-1)` arithmetic guess used originally. Geometric growth is cheap
early (level 2 costs 5 XP, level 5 costs 12) and expensive late (level 20
alone costs 278 XP — more than the entire first three minutes of the original
wave table combined). Re-running the *original, unmodified* wave table
against this formula produced implied levels of **6, 7, 10, 11, 12, 13, 14,
15, 16, 18** by minute — levels 1-3 roughly *doubled* versus the original
design (was 4, 5, 7), while minute 10 came in *lower* (18 vs 20). The curve
front-loads much harder than the arithmetic guess did. Left alone, minutes
1-3 of Bamboo Forest would have played as trivial, and the late game would
have been softer than intended, not harder.

Separately, `RunState._build_choices()` draws 3 options from a pool of
*every* non-maxed owned weapon (upgrade), *every* unowned weapon while fewer
than 4 are held (new), and *every* non-maxed passive (8 of them). That pool
is heavily skewed toward breadth: at level 1 there are 6 "new weapon" options
against 1 "upgrade" option, so a player who treats all 3 offered choices as
equally desirable acquires most of the 4-weapon cap almost immediately, then
splits remaining picks 4-ways (owned weapons) against 8-ways (passives) —
weapons end up leveling *slowly*, passives end up *diluted* across 8 stats
where only 2 (`attack_damage`, `attack_speed`) affect raw DPS. The original
"player invests in one weapon" model was simply wrong about how the actual
pick pool behaves.

## What's guessed vs. what's derived (updated)

**Now derived (moved out of "guessed" since core-engine landed them):**
- XP curve: `xp_to_next(L) = round(5 * 1.25^(L-1))`, read directly from
  `run_state.gd`.
- Choices per level-up: exactly 3, drawn from a pool that shrinks as weapons
  hit `max_level` and passives hit `max_stacks` (`_build_choices()`).
- Level-up picks are applied by `RunState.apply_choice()` itself via
  `grant_weapon`/`grant_passive`, both of which hard-cap at the
  content-declared `max_level`/`max_stacks` — a run cannot stack past what
  this worktree's data declares.
- Weapon slot cap of 4: **documented** in ARCHITECTURE.md section 3.3
  ("Concurrent weapon slots are capped at 4; the choice pool stops offering
  `weapon_new` once four weapons are held") and treated as authoritative
  below. **Caveat:** the landed `_new_weapon_choices()` in `run_state.gd`
  does not actually check `weapons.size()` anywhere — it only excludes
  weapons already owned, with no upper bound. This is a doc/code gap, not
  something this worktree can fix (`scripts/core/**` is out of scope here).
  Flagged to the coordinator; this analysis uses the documented cap of 4
  since that's the committed contract, but if the cap is never implemented,
  a run could pick up all 7 weapons and the real DPS curve would run higher
  than modeled here.

**Still guessed (genuinely unowned by this worktree, not yet landed):**
- Pick-selection policy. The pool math is real; which of the 3 offered
  options a player actually takes is not. This document assumes an
  "agnostic" player — equivalent in expectation to picking uniformly at
  random from the whole eligible pool each level-up — because it's the only
  policy that doesn't require guessing player psychology. A real player who
  prioritizes weapon upgrades over passives would out-DPS this model; one who
  hoards passives would under-DPS it.
- Crit multiplier and how `crit_chance` actually resolves in combat — still
  not independently verified by this worktree; folded into the observed
  145 dps figure below rather than modeled separately.

**Resolved this pass (was "guessed"/"not landed"):**
- Evolution trigger timing. combat wired `weapon_evolved` and verified the
  trigger fires correctly by forcing it — the mechanic works. What was
  actually broken was reachability: `min_weapon_level: 5` +
  `min_passive_stacks: 3` on one specific passive, drawn from a ~15-option
  pool across only 14-16 level-ups in a full run, essentially never
  completes under real play. See "Evolution reachability" below.
- The old_talisman-only DPS model was wrong, and now we know by how much:
  the real pick pool hands `twin_sword`/`divine_bow` out directly at their
  own rare-grade stats (not a gradual level-up from a weak common weapon),
  so a real 4-weapon loadout out-damages the old_talisman-only model by
  ~2.5x (observed 145 dps vs. modeled 57.6 at the same point in a run). See
  "Boss" below for how this is handled.

## Data change made in this pass

`forest_goblin.xp_drop`: **3 → 1**. This is the single lever pulled to fix
the front-loading described above — goblins dominate the spawn count in
minutes 1-3, so their XP is what was pushing the curve two levels ahead of
design intent. Spirit (5) and brute (8) xp_drop are untouched.

`bamboo_brute.hp`: **60 → 85**, and `bamboo_spirit_lord.hp`: **7000 → 4000**
(this pass: **4000 → 8000**, see "Boss" below). Both are pressure-side
corrections — the real pick-pool DPS model runs meaningfully higher
late-game than the original guess did (more weapons owned beats one
deeply-leveled weapon), so trash and boss HP needed to come up to keep the
intended danger shape and boss fight length.

**This pass, additionally:**
- `bamboo_spirit_lord.hp`: 4000 → 8000, retuned against the real observed
  145 dps rather than the flawed 57.6 model (see "Boss").
- Recomputed the entire pressure column in the DPS-vs-pressure table
  directly from `stages.json` + `monsters.json` — two rows (minute 6, 7)
  had a manual bucketing error (see "Enemy pressure" below).
- `evolutions.json`: added a `fire_talisman` rule (`old_talisman` +
  `skill_power`) so `old_talisman.evolves_to` stops being a dead pointer,
  and lowered every rule's thresholds from `min_weapon_level: 5,
  min_passive_stacks: 3` to `min_weapon_level: 3, min_passive_stacks: 2`
  (see "Evolution reachability").
- `weapons.json`: added the required `evolution_only` field to all 7
  weapons — `true` on `fire_talisman`, `phoenix_talisman`, `twin_sword`,
  `divine_bow` (the four evolution results), `false` on the three base
  weapons.

## XP curve → implied player level by minute (re-derived)

Cumulative XP is unchanged in shape (same wave table, only `forest_goblin`
xp_drop dropped), read against the real geometric formula:

| Minute | Cumulative XP | Implied level |
|---|---|---|
| 1 | 14 | 3 |
| 2 | 24 | 4 |
| 3 | 66 | 7 |
| 4 | 106 | 9 |
| 5 | 160 | 10 |
| 6 | 192 | 11 |
| 7 | 298 | 13 |
| 8 | 376 | 14 |
| 9 | 460 | 15 |
| 10 | 634 | 16 |

Close to the original design's *shape* (steady early climb, minute-4 lull as
spirit-only, minute-7 jump as brute joins), landing a bit softer at the very
end (level 16 vs the original guess of 20) — an acceptable trade for not
being trivial in minutes 1-3.

## Weapon/passive growth under the real pick pool (agnostic-player model)

Each row is the expected state when the run reaches that minute's level,
computed by walking the pool composition level-by-level (weapon-upgrade
slots = owned non-maxed weapons; new-weapon slots = `7 - owned` while
`owned < 4`; passive slots = non-maxed of 8) and taking each pool item as
equally likely to be the one applied, per level-up:

| Minute | Level | Weapons owned | Avg weapon level | Avg stacks/passive |
|---|---|---|---|---|
| 1 | 3 | 1.8 | 1.09 | 0.13 |
| 2 | 4 | 2.1 | 1.13 | 0.20 |
| 3 | 7 | 3.0 | 1.25 | 0.40 |
| 4 | 9 | 3.6 | 1.34 | 0.53 |
| 5 | 10 | 3.8 | 1.38 | 0.60 |
| 6 | 11 | 4.0 (cap) | 1.42 | 0.67 |
| 7 | 13 | 4.0 | 1.57 | 0.82 |
| 8 | 14 | 4.0 | 1.65 | 0.90 |
| 9 | 15 | 4.0 | 1.74 | 0.98 |
| 10 | 16 | 4.0 | 1.82 | 1.07 |

The weapon cap (4) is reached by minute 5-6. Average weapon level stays low
(1.8-2.3 range through minute 10) — under this pick model, breadth wins over
depth almost the whole run, and `max_level: 8` is never realistically
reached by minute 10. This is the opposite of the original guess.

## Enemy pressure vs. DPS by minute (pressure column corrected)

**The pressure column below was wrong in the previous pass.** combat's
playthrough reported real incoming HP of 660 at minute 6 and 585 at minute 7
against this document's stated 340 and 905 — the opposite ordering. Root
cause: manual bucketing error. The wave at `at_sec: 330` (16 `forest_goblin`)
falls in the minute-6 bucket `[300, 360)`, not minute 7 — it was hand-
assigned to the wrong minute when the table was first written. The fix is to
recompute the whole column programmatically from `stages.json` +
`monsters.json` rather than patch the two visibly-wrong rows, since a manual
process that produced one bucketing error could have produced others that
happen to look plausible:

```python
pressure = [0.0] * 10
for wave in stages_json["bamboo_forest"]["waves"]:
    minute_idx = min(wave["at_sec"] // 60, 9)
    pressure[minute_idx] += monsters_json[wave["monster_id"]]["hp"] * wave["count"]
```

The DPS column is unchanged from the previous pass (`owned_weapons ×
old_talisman_damage(avg_level)/old_talisman_cooldown(avg_level) × passive
multipliers` — see "What's guessed vs. derived" above for why this
under-counts real loadouts by ~2.5x once rare-grade weapons enter play,
confirmed by the boss measurement below). **Read the DPS numbers in this
table as a conservative floor, not a real measurement** — only the boss row
has been calibrated against actual combat data; the rest of the column
carries the same old_talisman-only bias, likely increasingly so from
minute 5-6 onward as `weapon_new` starts handing out `twin_sword`/
`divine_bow` and evolutions (now reachable, see below) start landing.

| Minute | DPS (floor, uncalibrated) | Incoming HP | HP/s | Margin | Note |
|---|---|---|---|---|---|
| 1 | 18.5 | 280 | 4.67 | 3.97x | goblins only |
| 2 | 22.7 | 200 | 3.33 | 6.80x | still comfortable |
| 3 | 34.4 | 336 | 5.60 | 6.15x | forest_spirit introduced |
| 4 | 41.9 | 128 | 2.13 | 19.65x | intentional lull |
| 5 | 45.6 | 408 | 6.80 | 6.70x | density climbing |
| 6 | 49.2 | 660 | 11.00 | 4.47x | bamboo_brute introduced (85 hp) *and* the real step-up minute — sharpest margin drop in the run so far |
| 7 | 52.3 | 585 | 9.75 | 5.36x | pressure eases off from minute 6, margin recovers |
| 8 | 54.0 | 552 | 9.20 | 5.87x | still recovering |
| 9 | 55.8 | 1080 | 18.00 | 3.10x | **second danger minute** |
| 10 | 57.6 | 1554 | 25.90 | 2.22x | **tightest margin of the run**, by design, right before the boss |

## Boss

**Retuned against real measurement, not the model.** combat's playthrough
killed the boss in 27.6s at ~145 observed single-target DPS against
`bamboo_spirit_lord.hp: 4000` — a fight designed for 45-70s came in at half
the floor. Root cause, per the task: the DPS model above treats every
weapon as an `old_talisman` clone, but the real `weapon_new` pool hands
`twin_sword`/`divine_bow` (rare grade, higher base damage) out directly, and
a real 4-weapon loadout collectively out-damages the model by ~2.5x (145 vs.
57.6 modeled at the same run length). The model is fixed by *not*
re-deriving a new theoretical number for the boss specifically — 145 is a
real measurement and beats another guess.

`bamboo_spirit_lord.hp`: **4000 → 8000**. At the observed 145 dps that's a
55.2s time-to-kill, centered in the 45-70s window this fight was designed
for. (8000 / 145 ≈ 55.17s; the previous 4000 / 145 ≈ 27.6s matches the
reported measurement exactly, confirming 145 dps as the right number to
tune against rather than the model's 57.6.)

Two other levers were on the table and both are out of this worktree's
reach: a damage-reduction/invulnerability phase (boss AI, `scripts/combat/
boss.gd`) and restricting how early rare-grade weapons enter the
`weapon_new` pool (choice-pool logic, `scripts/core/run_state.gd`). Both are
engine behaviour, not data — reported here rather than attempted, per the
ownership boundary; either would be a legitimate alternative to a flat HP
increase if combat wants a more textured fight (e.g. a phase break instead
of one long tank-and-spank), and the coordinator can route that if wanted.

`bamboo_spirit_lord.damage` (35/hit) against a Taoist with `base_hp: 100`
plus whatever `max_hp` stacks were picked still means the fight has to be
won by kiting, not tanking, per the GDD's movement-only combat model — an
8000 hp boss doesn't change that math, it only changes how long the kiting
has to hold up.

## Where the run should feel dangerous (revised — minute 6, not minute 7)

1. **Minute 6** — the real step-up, confirmed by the corrected pressure
   column: margin drops from minute 5's 6.70x to 4.47x, the sharpest single-
   minute drop in the run. This lines up with `bamboo_brute`'s introduction
   (18 dmg / 70 spd charger) *and* a 16-goblin wave landing in the same
   60-second window — previously described as two separate, milder effects
   split across minutes 6 and 7, but they're the same minute.
2. **Minute 7** — pressure eases (585 vs. minute 6's 660), margin recovers
   to 5.36x. Previously mis-described as the sharper of the two.
3. **Minute 9-10** — sustained pressure into the boss, margin bottoming out
   at 2.22x at minute 10, directly into an 8000 hp / 35 dmg boss.

Minutes 1-5 stay above ~4x margin (with an extreme 19.65x lull at minute 4)
— consistent with the GDD's "learn the loop" framing for the first half of a
10-15 minute session. Given the DPS column's uncalibrated-floor caveat above,
every margin number in this table should be read as a lower bound — the run
is probably somewhat safer than this table states, not more dangerous.

## Evolution reachability

**Previously unreachable.** combat verified the evolution *trigger* is
correctly implemented (forcing it works, `weapon_evolved` fires), so the
defect was entirely in the thresholds: `min_weapon_level: 5,
min_passive_stacks: 3` on one named passive, drawn from a pool of up to
~15 concurrent options (owned-weapon upgrades + unowned weapons while under
the 4-slot cap + 8 passives) across only 14-16 total level-ups in a full
run. Getting one specific weapon to level 5 *and* one specific passive to 3
stacks needs roughly half of an entire run's picks funneled into a single
combo — the "Weapon/passive growth" table above shows *average* weapon
level never exceeds ~1.8-2.3 and *average* per-passive stacks never exceeds
~1.1 by minute 10, so 5/3 was multiple run-lengths above what real play
produces even when somewhat lucky.

**Retuned:** every rule in `evolutions.json` now reads `min_weapon_level: 3,
min_passive_stacks: 2` — roughly the level a focused-but-not-perfect player
reaches on their starting weapon and one passive they lean into, not the
run-average. Still not guaranteed every run (that's the point — it's a
build-defining payoff, not a freebie), but no longer arithmetically
foreclosed by the pick pool's own math.

**`old_talisman.evolves_to: "fire_talisman"` had no matching rule** — the
single most visible dead evolution pointer in the game, since it's on the
default character's starting weapon. Fixed by adding the rule (`old_talisman`
+ `skill_power` → `fire_talisman`) rather than repointing, since GDD section
7's stated chain is Old Talisman → Fire Talisman → ... and repointing would
have broken that chain instead of completing it. This also makes
`fire_talisman` the fourth `evolution_only` weapon alongside
`phoenix_talisman`, `twin_sword`, `divine_bow` — all four M1 evolution
results are now excluded from the ordinary `weapon_new` pool
(ARCHITECTURE.md section 4), so reaching a rule's threshold buys something
the pool can't hand over for free.

## Sprite scale and `collision_radius` (now a required, authoritative field)

**Correction:** an earlier pass of this document recorded sprite dimensions
from the first art generation, which was discarded for not matching the
Taoist reference style. The art was regenerated; the numbers below are
measured directly from the files currently in `asset/monster/`
(`PIL Image.size`, re-verified in this pass, not copied from a prior report):

| Monster | Sprite canvas (px) | Median silhouette width* | Max silhouette width* |
|---|---|---|---|
| forest_goblin | 33×44 | 23 | 30 |
| forest_spirit | 26×46 | 16 | 24 |
| bamboo_brute | 61×58 | 43 | 61 |
| bamboo_spirit_lord | 60×76 | 47 | 60 |

Reference: the Taoist player sprite's canvas is 92×92, but its actual
silhouette (alpha bounding box) is 37×46 — the canvas carries padding for
8-direction rotation framing that the monster sprites don't have (their
canvas is already tightly cropped to the silhouette, confirmed by checking
each file's alpha bbox against its canvas size).

*Median/max silhouette width = per-row count of non-transparent pixels,
median and max taken across all rows. This distinguishes core body from
protruding elements: `bamboo_brute` holds a club that widens a minority of
rows to the full 61px canvas, but a typical row (median) is 43px — the club
is not the body. Same effect, smaller, on `bamboo_spirit_lord`'s two
outstretched blade-like ornaments (median 47 vs. max 60).

**`collision_radius` (ARCHITECTURE.md section 4, now required)** is set to
half the *median* silhouette width, not half the canvas or half the max row
— so a swung club or an ornamental blade doesn't inflate the hitbox past
what the body actually occupies:

| Monster | `collision_radius` | Derivation |
|---|---|---|
| forest_goblin | 11.5 | 23 (median width) / 2 |
| forest_spirit | 8.0 | 16 / 2 |
| bamboo_brute | 21.5 | 43 / 2 |
| bamboo_spirit_lord | 23.5 | 47 / 2 |

All four are comfortably under the validator's half-canvas ceiling (16.5,
13.0, 30.5, 30.0 respectively) — the point of that ceiling isn't that these
values are near it, it's that a typo (e.g. transposing brute and boss, or
entering a canvas dimension instead of a radius) gets caught instead of
silently shipping as an invisible wall.

**Feel being aimed for:** `forest_goblin` and `forest_spirit` should read as
small and threadable — a player weaving through a cluster of 5-10 goblins
(minutes 1-5 spawn density) needs real gaps to path through, not a wall of
11.5-radius circles touching edge-to-edge. `bamboo_brute` at 21.5 is
deliberately the largest non-boss radius (roughly double the goblin's) —
it's the charger, and the collision size should make "don't stand where the
brute is" a real spatial commitment, not a graze. `bamboo_spirit_lord` at
23.5 is only marginally larger than the brute despite being visually the
biggest sprite (60×76 vs. 61×58) — a boss fight that's already won on
attack-pattern reading and kiting room, not on the body itself being an
unavoidable wall, matches the ~45-70s single-target fight this document
designs around above; a boss hitbox much larger than the brute's would fight
that kiting design.

This section previously argued for adding `collision_radius` to the schema;
that argument is now resolved — the coordinator approved it and
ARCHITECTURE.md section 4 requires it. `tools/validate_data.gd` enforces
presence, positivity, and the half-sprite-width ceiling described above.
