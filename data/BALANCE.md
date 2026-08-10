# M1 Balance Notes — Bamboo Forest (10 min / 600s)

**Re-derived against the real formulas landed in `scripts/core/run_state.gd`
(commit 367da99 / 071776a).** The original version of this document assumed a
guessed arithmetic XP curve and a "player dumps half their picks into the
starting weapon" model. Both were wrong. This version reads `run_state.gd`
directly and derives the curve from it.

**Reconciled against a real combat playthrough (previous pass, main at
409646e).** combat played Bamboo Forest once, won, and reported ground
truth: boss killed in 27.6s at ~145 observed single-target DPS. Boss hp was
raised to match. This turned out to be the wrong number to tune against —
see below.

**Reconciled against five combat playthroughs, agnostic picker, no forcing
(previous pass).** Result: 4 of 5 died before the boss spawned, 0 of 5 won —
against 1 of 2 winning before that pass's retune. The single-run
145 dps figure came from `twin_sword`/`divine_bow` being picked up directly
out of the `weapon_new` pool; the same pass that measured 145 dps also
marked those two `evolution_only`, which retroactively deleted the pool
access that produced the measurement. **The core lesson, not just that
pass's fix: a change to what the level-up pool offers changes the dps the
boss must be sized against — the two are coupled, and re-deriving one
without the other silently invalidates a tuned number.** `bamboo_spirit_lord.hp`
was retuned to 2150 against a re-derived, validated 39.6 dps model.

**Five more playthroughs against that retune (two passes ago).** It worked
on every axis it targeted: win rate 0/5 → 3/5, any evolution 1/5 → 4/5, and
the full `old_talisman` → `fire_talisman` → `phoenix_talisman` chain fired
in 3/5 (core-engine's evolved-weapon-level tracking fix, landed since the
previous pass, is what made that chain reachable at all). The 39.6 dps model
was vindicated precisely: the one run that never evolved measured 41 dps on
the boss hp curve — 1% off the model, not a lucky number. **What it
exposed:** boss TTK was 12.2-14.4s against the 55s target, undershooting in
the *opposite* direction from before. Root cause wasn't the hp value — it
was that `phoenix_talisman` quadrupled single-target dps (~41 unevolved →
~160 evolved) at the *same point in the same run*, so 2150 hp was
simultaneously a 13s fight when phoenix was present and unwinnable when it
wasn't. That pass narrowed the spread (`phoenix_talisman` damage/cooldown/
`projectile_count` cut) and re-sized `bamboo_spirit_lord.hp` to 3150 for
the projected middle.

**Correction that changes how much to trust every number above this
line.** combat found its measurement instrument itself was broken: the
sweep seed only drove level-up choice, while crit rolls, spawn placement,
and the swarm weave each called `randomize()` independently, so two runs of
the *same build* diverged and no build-to-build comparison — including
every "N of 5 wins" figure in this document before this pass — was ever
statistically valid. combat routed every random stream through one seeded
RNG and verified a seed now reruns bit-identical. **This pass's numbers are
from the first genuinely controlled sweep, extended to ten seeds because
the headline question is a rate.** Treat every dps/win-rate figure dated
before this correction as directional noise, not a measurement — the
*diagnoses* built on them (projectile_count, the ranged-pressure danger
model, the survivability fix) held up when re-checked against controlled
data, but the specific percentages didn't.

**Ten controlled seeds against the previous pass's spread fix (this
pass).** The spread fix and its diagnosis were both correct: evolved dps
measured 84.8 against a projected 79, unevolved 38.0 against a modeled 41 —
a 2.23x spread versus the 1.9x projected and the ~4x chasm before it. What
the controlled sweep exposed instead: win rate 2/10, and the correlation is
sharper than anything measured so far — the phoenix chain wins 2 of 2, no
other chain loses 8 of 8 (one run evolved `sword`→`twin_sword`, worth only
~3 dps and inside the unevolved band, and still lost). Chain rate is 2/10,
any evolution 3/10 — the nerf did not make evolution pointless, it made it
the *only* path to a win, which is its own problem: the boss is now a
phoenix-chain check that locks out 80% of runs before dps even matters.
Boss TTK missed the 45-70s window in both directions (evolved 37.2s, 8s
under floor; unevolved extrapolates to ~83s, and no unevolved run actually
survived that long — seed 7 had the boss at 588/3150 hp at +70s and died
first). Genuine improvement in shape, separate from the win-rate problem:
5 of 10 runs now reach the boss and fight it for 29-77s, instead of dying
before it spawned. That pass narrowed the spread further
(`phoenix_talisman` damage/`per_level.damage` cut again) and did not touch
`evolutions.json` — the passive-draw floor was already at 1, and the
remaining reachability gap was diagnosed as needing engine-side choice-pool
weighting, not a data threshold.

**THE EVOLUTION PROBLEM IS NOW CLOSED (this pass).** core-engine's
weighting fix landed on both halves of the requirement (4x weapon-level
weight, 2x passive weight, not passive-only) and it worked exactly as
projected: chain rate 3/10 → 6/10, any evolution 6/10 → 8/10, wins
4/10 → 6/10, mean gating weapon level 1.75 → 3.00, and all six wins now
chain (6 of 6). This validates the earlier reachability diagnosis (see
"Evolution reachability, round 2" below, corrected this pass) rather than
contradicting it — the model's 76.8% theoretical per-draw ceiling landed
within a point of the design intent, and the gap to the observed 60% chain
rate is now fully accounted for by early deaths, not a wrong model.

**What's left, cleanly separable now that reachability isn't confounding
the picture:** boss TTK undershoots specifically on *early* chains — see
"Boss" below — and the isolated survivability residual (4/10 losses,
unchanged) needs a deliberate decision rather than more tuning. Two data
changes this pass (`phoenix_talisman`'s curve, `bamboo_spirit_lord.hp`),
one documentation correction (survivability), and one explicit "leave it"
decision.

**THE M1 BALANCE ROUND IS NOW CLOSED (this pass, no data changed).**
combat's confirming sweep proved the remaining boss-TTK spread (five win
TTKs, strictly monotonic in chain time, 40.4-76.1s) is structurally too
wide for any single `bamboo_spirit_lord.hp` to fit inside the 45-70s
window this document had been tuning against — see "Boss, round 4." The
window is retired as an assumption that was never a GDD requirement, not
patched around. Survivability is confirmed closed at a stable 2/10
early-death rate across three consecutive sweeps — see "Survivability,
round 3." Reachability was already closed. Nothing in `data/**` changes
this pass; this pass is the record of the decision, not a new tuning pass.

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
- Weapon slot cap of 4: **documented** in ARCHITECTURE.md section 3.3, still
  not enforced by a `weapons.size()` check in `run_state.gd`'s
  `_new_weapon_choices()` (doc/code gap, not this worktree's file to fix).
  **This pass, the cap became moot for M1 content anyway:**
  `_new_weapon_choices()` now skips `evolution_only` weapons
  (`scripts/core/run_state.gd`, confirmed by reading the landed code), and
  only 3 of the 7 M1 weapons are *not* `evolution_only` — so the highest
  weapon count reachable via `weapon_new` is 3, well under the cap whether
  or not the cap is ever implemented. The uncapped-pool risk this bullet
  used to flag no longer applies to this content set; it would resurface
  only if a future non-`evolution_only` weapon pushed the base-weapon count
  above 4.

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
  ~39 dps figure below rather than modeled separately.

**Resolved, but the finding flipped (previous pass got this backwards):**
- The old_talisman-only DPS model was called "~2.5x undercounting real dps"
  last pass, based on the 145 dps single-run measurement. That measurement
  came from a pool state (`twin_sword`/`divine_bow` obtainable as
  `weapon_new` picks) that the *same* pass's `evolution_only` field then
  removed. With those two excluded, the `weapon_new` pool is `{old_talisman,
  sword, bow}` — 3 weapons, not 7 — and a run can never hold more than 3
  concurrent weapons via the ordinary pool (`evolution_only` weapons only
  arrive by evolving one of these three). Re-run against the corrected pool
  size, the model produces **39.6 dps at minute 10**, matching the five-run
  boss measurement of **~39 dps** to within 1.5% — the model was not
  "undercounting," the *pool it modeled* changed after the measurement was
  taken. See "DPS model" below for the full re-derivation and the general
  lesson.
- Evolution trigger timing. combat wired `weapon_evolved` and verified the
  trigger fires correctly by forcing it — the mechanic works, and fired
  organically once across five runs (seed 4, `sword` → `twin_sword` at
  t=461.9s). The remaining defect is narrower than last pass thought: weapon
  level 3 is reached routinely; landing 2 stacks of one *specific* passive
  (out of 8) inside a ~14-level-up run is the actual bottleneck. See
  "Evolution reachability" below.

**New this pass — total incoming HP does not predict player danger:**
- combat measured damage taken per minute across five runs and it does not
  track the pressure column at all: minute 6 (11.0 hp/s, this document's
  previous "step-up" minute) took **zero damage in all five runs**; minute 9
  (18.0 hp/s) also took zero damage in 4 of 5. Minute 7 (9.75 hp/s — *lower*
  pressure than minute 6) hurt in 4 of 5. The bucketing arithmetic is
  correct (combat reproduced it independently) — the column itself isn't
  wrong, using it as a danger proxy is. See "Danger model" below for the
  fix (a ranged-pressure term) and the re-derived narrative.

## Data change log

**Prior passes:** `forest_goblin.xp_drop` 3→1 (de-front-load the geometric
XP curve); `bamboo_brute.hp` 60→85; `bamboo_spirit_lord.hp` 7000→4000→8000
(the 8000 value is superseded this pass, see "Boss"); added
`evolution_only` to all 7 weapons in `weapons.json`; added the
`old_talisman`→`fire_talisman` rule to `evolutions.json` so
`old_talisman.evolves_to` stops being a dead pointer; lowered every
evolution rule from `min_weapon_level: 5, min_passive_stacks: 3` to
`min_weapon_level: 3, min_passive_stacks: 3→2` (the weapon-level half of
that change held up; the passive half didn't, see "Evolution
reachability").

**Previous pass, against five real playthroughs:**
- `bamboo_spirit_lord.hp`: **8000 → 2150** (superseded this pass, see
  "Loadout spread"). Re-tuned against the real observed 39 dps (not 145 —
  see "DPS model").
- `forest_spirit.damage`: **9.0 → 5.0** (a 44% cut). Primary survivability
  fix — see "Survivability". Held this pass; no further change.
- `taoist.base_hp`: **100 → 120** (a 20% buffer increase, `characters.json`).
  Secondary survivability fix. Held this pass; no further change.
- `evolutions.json`: **`min_passive_stacks: 2 → 1`** on all four rules,
  `min_weapon_level` left at 3. See "Evolution reachability" — the weapon
  side of the threshold already worked; the passive side didn't. This is
  the fix that made the evolution chain reachable, which is what exposed
  the loadout-spread problem below.

**Two passes ago, against five more real playthroughs of the above:**
- `phoenix_talisman`: `damage` 30.0→25.0, `cooldown_sec` 0.9→0.95,
  `projectile_count` 2→1, `per_level.damage` 6.0→5.0. The loadout-spread
  fix — validated by the controlled sweep at 84.8 dps evolved vs. a 79
  projection.
- `bamboo_spirit_lord.hp`: **2150 → 3150** (superseded this pass). Re-sized
  for the middle of the narrowed evolved/unevolved dps band.

**Two passes ago, against the first controlled ten-seed sweep:**
- `phoenix_talisman`: `damage` 25.0→17.5, `per_level.damage` 5.0→3.5
  (`cooldown_sec`, `per_level.cooldown_sec`, `projectile_count` unchanged).
  Round 2 of the loadout-spread fix.
- `bamboo_spirit_lord.hp`: **3150 → 2600** (superseded this pass). Re-centered
  for the further-narrowed band.

**This pass, against the ten-seed sweep with core-engine's evolution
reachability fix landed:**
- `phoenix_talisman`: `damage` 17.5→19.0, `per_level.damage` 3.5→2.2
  (`cooldown_sec`, `per_level.cooldown_sec`, `projectile_count`
  unchanged). Round 3 of the loadout-spread fix, this time targeting the
  *internal* spread within the now-dominant chained-win population (early
  vs. late chains), not an evolved-vs-unevolved split — see "Boss".
- `bamboo_spirit_lord.hp`: **2600 → 3600**. Re-centered again — see "Boss".
- `evolutions.json`: **not changed this pass.** Reachability is closed;
  touching `min_weapon_level` again to influence chain *timing* was
  considered and rejected — see "Boss" for why.
- No survivability-affecting fields changed this pass (`forest_spirit.damage`,
  `taoist.base_hp`, wave table) — see "Survivability, round 2": 4/10 losses
  is deliberately accepted as the target, not tuned further.
- `evolutions.json`'s `min_passive_stacks` was **not** changed this pass —
  it's already at its floor (1, the minimum non-zero value the schema
  allows). See "Evolution reachability": the chain-reachability fix this
  pass needed is engine-side, not a threshold this worktree can retune
  further.

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

## Weapon/passive growth under the real pick pool (corrected pool size)

**Re-derived this pass.** The previous version of this table modeled
`new-weapon slots = 7 - owned` (every weapon in `weapons.json` eligible for
`weapon_new`). That was already stale the moment `evolution_only` landed:
`_new_weapon_choices()` skips `evolution_only` weapons, so the real
`weapon_new` pool for a Taoist run is `{sword, bow}` (2 options — 3 counting
the already-owned `old_talisman`), not 6. This changes the whole curve, not
just the endgame: with only 3 weapons ever reachable outside evolution, the
pool exhausts its "new weapon" supply fast and tips toward
upgrade-and-passive picks much earlier than the old 7-weapon model assumed.

Same method as before (weapon-upgrade slots = owned non-maxed weapons;
new-weapon slots = `3 - owned` while `owned < 3`; passive slots = non-maxed
of 8; each pool item equally likely to be the one applied):

| Minute | Level | Weapons owned | Avg weapon level | Avg stacks/passive |
|---|---|---|---|---|
| 1 | 3 | 1.35 | 1.15 | 0.18 |
| 2 | 4 | 1.50 | 1.21 | 0.27 |
| 3 | 7 | 1.87 | 1.41 | 0.55 |
| 4 | 9 | 2.07 | 1.54 | 0.73 |
| 5 | 10 | 2.15 | 1.61 | 0.82 |
| 6 | 11 | 2.23 | 1.67 | 0.91 |
| 7 | 13 | 2.36 | 1.81 | 1.09 |
| 8 | 14 | 2.42 | 1.88 | 1.18 |
| 9 | 15 | 2.47 | 1.95 | 1.27 |
| 10 | 16 | 2.52 | 2.02 | 1.36 |

Weapons owned caps out around 2.5 (never reaches even the real 3-weapon
ceiling on average, since some runs stay on 2), and per-passive stacks climb
faster than before (1.36 avg by minute 10 vs. the old model's 1.07) simply
because there's less competition from new-weapon picks. Both numbers matter
directly below: fewer owned weapons means lower total dps than the old
model predicted; higher passive stacks is *why* the passive side of the
evolution requirement is now the easier one to hit, not the weapon-level
side (see "Evolution reachability").

## DPS model (re-derived, validated against real measurement)

Same formula as before — `owned_weapons ×
old_talisman_damage(avg_level)/old_talisman_cooldown(avg_level) × (1 +
0.06×avg_stacks) × (1 + 0.08×avg_stacks)` — run against the corrected
"Weapon/passive growth" table above instead of the stale 7-weapon-pool one:

| Minute | DPS |
|---|---|
| 1 | 14.4 |
| 2 | 16.5 |
| 3 | 22.6 |
| 4 | 26.5 |
| 5 | 28.4 |
| 6 | 30.3 |
| 7 | 34.0 |
| 8 | 35.9 |
| 9 | 37.8 |
| 10 | 39.6 |

**Validation:** minute 10's 39.6 dps against the five-run measured boss dps
of ~39 is a 1.5% difference — close enough to treat the model as
trustworthy going forward, in sharp contrast to the previous pass's 57.6 vs.
145 (a 2.5x *understatement* that was actually a stale-pool artifact, not a
model error) and this pass's *initial* re-check showing the old 57.6 number
now **overstating** real dps by ~1.5x. Both the "undercounts by 2.5x" and
"overcounts by 1.5x" framings were describing the same static model against
two different real pool configurations — the model itself was never
consistently biased in one direction, which is why applying a correction
factor to the old number (rather than re-deriving from the actual current
pool) would have been wrong twice in two different ways. The number to
carry forward is: **this model tracks real dps well when the pool it
simulates matches the pool the game actually offers**, and needs re-checking
again any time `weapon_new` eligibility, `max_level`, or evolution
thresholds change.

## Danger model: incoming HP alone doesn't predict what hurts

**Incoming HP by minute (unchanged from last pass — combat reproduced this
column independently and confirmed the bucketing is correct):**

| Minute | Incoming HP | HP/s | DPS | Margin |
|---|---|---|---|---|
| 1 | 280 | 4.67 | 14.4 | 3.08x |
| 2 | 200 | 3.33 | 16.5 | 4.95x |
| 3 | 336 | 5.60 | 22.6 | 4.04x |
| 4 | 128 | 2.13 | 26.5 | 12.44x |
| 5 | 408 | 6.80 | 28.4 | 4.18x |
| 6 | 660 | 11.00 | 30.3 | 2.75x |
| 7 | 585 | 9.75 | 34.0 | 3.49x |
| 8 | 552 | 9.20 | 35.9 | 3.90x |
| 9 | 1080 | 18.00 | 37.8 | 2.10x |
| 10 | 1554 | 25.90 | 39.6 | 1.53x |

**This margin column does not predict what actually hurt players across
five runs, and combat's per-minute damage-taken data proves it directly:**
minute 6 (11.0 hp/s, margin 2.75x — reads as one of the tightest minutes in
the table) took **zero damage in all five runs**. Minute 9 (18.0 hp/s,
margin 2.10x — reads even tighter) also took zero damage in 4 of 5. Minute 7
(9.75 hp/s, margin 3.49x — reads *safer* than both 6 and 9) hurt in 4 of 5.
The column is arithmetically right; using total incoming hp as a danger
proxy is wrong.

**Why:** Bamboo Forest is movement-only combat (GDD section 6) — kiting
answers `chase` and `charger` monsters completely, because they can only
threaten a player who stops moving or gets cornered. It does not answer
`ranged` monsters, which threaten from outside the player's backoff
distance regardless of how well they kite. Minute 6's wave (`bamboo_brute`
×4, `forest_goblin` ×16) is 100% chase/charger — high hp pressure, zero
ranged content, zero recorded damage. Minute 9's wave (`bamboo_brute` ×8,
`forest_goblin` ×20) is the same shape. Minute 7 is the first wave where
`forest_spirit` (`behaviour: ranged`) is *not* the only content but *is*
present alongside chase/charger — and it's the only one of the three that
hurt.

**Ranged-pressure term:** `forest_spirit_count × forest_spirit.damage` per
minute, computed against the damage value in effect at measurement time
(9.0, before this pass's fix) to explain the observed pattern, and against
the corrected value (5.0) to show the intended effect of the fix:

| Minute | forest_spirit count | Ranged pressure @ 9.0 dmg (measured) | Ranged pressure @ 5.0 dmg (this pass) |
|---|---|---|---|
| 3 | 6 | 54 | 30 |
| 4 | 8 | 72 | 40 |
| 5 | 8 | 72 | 40 |
| 6 | 0 | **0** | **0** |
| 7 | 10 | 90 | 50 |
| 8 | 12 | 108 | 60 |
| 9 | 0 | **0** | **0** |
| 10 | 14 | 126 | 70 |

Minutes 6 and 9 read as exactly zero on this column — matching the observed
zero-damage minutes precisely, something the incoming-HP column cannot do
since both minutes have substantial (in minute 9's case, the second-highest
in the run) chase/charger pressure. This is the column that should be read
as the danger proxy for Bamboo Forest; incoming HP remains useful as a
total-clear-workload figure (how much the player's DPS has to chew through)
but should not be read as a survivability signal.

## Loadout spread — the actual defect this pass fixes

**Every prior boss-sizing pass assumed one representative dps figure per
run length. Five replays against the working evolution chain prove that
assumption false at this specific point in the game.** Same point in the
same 10-minute run, two outcomes: a run that never evolved measures ~41 dps
on the boss; a run that completed `old_talisman` → `fire_talisman` →
`phoenix_talisman` measures ~160 dps — a **3.9x spread from one binary
event** (did evolution complete or not), not from skill, luck-of-passives,
or run length. combat's arithmetic: a 55s fight wants ~2250 hp at 41 dps and
~8800 hp at 160 dps. No single hp value serves both, and both of this pass's
remaining losses were the unevolved branch — the boss was already
unwinnable for roughly half the runs before a single hp number could ever
fix it.

**Decision: narrow the spread to ~2x or less by cutting `phoenix_talisman`'s
own stats, not the pre-evolution weapons' `per_level` curves and not the
evolution trigger's multiply-vs-behaviour design.** Three levers, why one
was chosen:
- *Pre-evolution `per_level` curves* (`old_talisman`, `fire_talisman`) —
  buffing these to close the gap from below would raise the *unevolved*
  floor, which sounds appealing but doesn't touch the actual defect: the
  spread is `phoenix_talisman`'s output relative to everything else, and
  buffing the floor just makes both branches bigger while the ratio between
  them stays close to 4x. Not pulled.
- *Evolution multiplying damage vs. changing behaviour* — a legitimate
  redesign (evolution as a utility/behaviour change rather than a raw dps
  spike) but is a bigger structural change than this pass's mandate, and
  `phoenix_talisman` already carries behaviour upside (`pierce: 2,
  area_scale: 1.8` vs. `fire_talisman`'s `pierce: 1, area_scale: 1.4`) —
  the evolution already isn't *purely* a damage multiplier, it's a damage
  multiplier that's currently too large. Deferred, not required to hit the
  ~2x target.
- **`phoenix_talisman`'s own damage/cooldown/projectile_count — the lever
  pulled.** This directly targets the number that's actually 4x too high,
  is a single weapon's stats (smallest possible blast radius for the fix),
  and preserves everything else this pass already validated (the
  unevolved-branch dps model, the pressure/danger analysis, survivability).

**The mechanism behind the 3.9x, and why `projectile_count` matters more
than damage or cooldown alone:** true single-target dps for a weapon is
`damage × projectile_count / cooldown_sec`, not just `damage / cooldown_sec`
— a detail the DPS model above never needed until now, because every other
M1 weapon fires 1-2 projectiles at comparable damage/cooldown ratios.
`phoenix_talisman` was the outlier: `damage: 30, cooldown_sec: 0.9,
projectile_count: 2` gives a level-1 unit dps of `30×2/0.9 ≈ 66.7` —
already ~5x `old_talisman`'s comparable-level unit dps (~13.1) *before* any
of `phoenix_talisman`'s own `per_level` growth is applied. Every other
`evolution_only` weapon (`fire_talisman`, `twin_sword`, `divine_bow`)
projectile-and-damage-scales in line with its tier; `phoenix_talisman` alone
compounded a rare→epic damage jump with a projectile-count *doubling*,
producing a spike far beyond what "one tier better" should mean.

**Change made:** `phoenix_talisman.damage` 30→25, `.cooldown_sec` 0.9→0.95,
`.projectile_count` 2→1, `.per_level.damage` 6.0→5.0 (cooldown per_level
unchanged at -0.04). New level-1 unit dps: `25×1/0.95 ≈ 26.3` — a ~61%
reduction in the standalone-weapon output that was driving the spread.
Applying that ratio to the 160 dps measurement (the other owned weapons and
passive multiplier are unaffected by this change) gives an estimated new
evolved-branch dps of **~79** against the unevolved branch's measured
**~41 dps — a ~1.9x spread**, inside the ~2x target. This is a model
projection from the same DPS methodology validated to within 1.5% earlier
in this document, not a re-measurement — combat's next replay is the actual
check.

**Evolution still reads as a real payoff.** At the moment of evolving
(`fire_talisman` at the required level 3: `damage: 26, cooldown_sec: 1.0` →
unit dps 26.0), `phoenix_talisman` at level 1 (unit dps 26.3) is an
immediate, if modest, upgrade, and it clearly outscales from there — level 3
(`damage: 35, cooldown_sec: 0.87`) reaches unit dps ~40.2, +55% over
`fire_talisman`'s trigger-level output. Combined with retained utility
upside (`pierce: 2, area_scale: 1.8`, both above `fire_talisman`'s), this
keeps evolution feeling like a genuine tier-up without being the run-ending
spike it was.

**Calibration check on the projection above, now that the controlled sweep
has a real number:** the projected 79 evolved dps landed within 7% of the
measured 84.8 — close enough that the same methodology (scale the
`phoenix_talisman` unit-dps ratio, apply it to the measured total) is
trustworthy for round 2 below, with the same explicit caveat that it's a
projection, not a guarantee.

## Loadout spread, round 2 — correcting a modeling error, then cutting further

**Target: narrow 2.23x (measured) toward ~1.5x.** With unevolved dps
measured at 38.0 (real, not the 41 this document modeled before), hitting
1.5x means the evolved branch needs to land near **57 dps** — a further cut
of `57 / 84.8 ≈ 0.672` (about a third off the current evolved output).

**Correction found while planning this cut:** the round-1 analysis modeled
`phoenix_talisman` starting at level 1 on evolving and reaching level 3
only after two more upgrade picks. That's wrong. `RunState.evolve_weapon()`
(`scripts/core/run_state.gd`) rewrites the weapon entry in place and
**inherits the source weapon's level**, clamped to the target's own
`max_level` — its own doc comment explains why: combat already carries the
level across the swap node-side, and a level-1 restart would strand the
second leg of a chain, since it gates on the evolved weapon reaching a
level it could no longer reach again inside one run. Concretely:
`fire_talisman` inherits whatever level `old_talisman` was at when the
first evolution fired (at least 3, the gate); and because
`_check_evolutions()` re-scans every owned weapon on every level-up, the
second evolution can fire on the *very next* level-up if `skill_power` is
already held — so `phoenix_talisman` typically starts at level 3+
*inherited*, not level 1. This explains why the real 84.8 measurement ran
a bit hotter than the (level-1-anchored) 79 projection, and it changes
where this round's cut should land: cutting raw `damage` again would push
`phoenix_talisman`'s *immediate, inherited* stats below `fire_talisman`'s
trigger-level output, which breaks "evolution must still feel earned" — the
previous round's cut already brought the two close together
(`phoenix_talisman`@1 old-model 26.3 vs. `fire_talisman`@3's 26.0 was
already a near-tie, and that comparison was using the wrong phoenix level).

**Change made: scale `damage` and `per_level.damage` by the same ~0.70
factor, leave `cooldown_sec`/`per_level.cooldown_sec`/`projectile_count`
untouched.** `phoenix_talisman.damage` 25.0→17.5, `per_level.damage`
5.0→3.5. Scaling damage alone (not cooldown) preserves the *trigger-moment*
comparison ratio exactly, so the immediate payoff doesn't collapse: at the
inherited level 3, new unit dps is `(17.5 + 3.5×2) / 0.87 ≈ 28.2` against
`fire_talisman`@3's `26.0` — still a real, if modest, +8% immediate upgrade,
continuing to outscale from there as levels accumulate. Applying the same
~0.70 ratio to the measured 84.8 total (the same scaling methodology
calibrated to 7% above) projects **evolved dps ≈ 59**, giving **59 / 38.0 ≈
1.55x** — inside the ~1.5x target.

## Boss

`bamboo_spirit_lord.hp`: **3150 → 2600.** Re-centered for the further-
narrowed band using the same geometric-mean method as before (time-to-kill
is a ratio, so centering the branches' TTK ratio — not the raw hp
difference — splits the difference fairly): `sqrt(38.0 × 59) ≈ 47.4` dps at
the target midpoint, `47.4 × 55 ≈ 2610`, rounded to **2600**. Resulting
time-to-kill: **~68.4s** on the unevolved branch (2600 / 38.0), **~44.1s**
on the evolved branch (2600 / 59) — both now close to the 45-70s design
window (unevolved sits near the top of it, evolved is ~1s under the floor)
rather than round 1's 77s/40s spread, itself already far better than the
original 13s/204s chasm. As the residual ~1.55x spread implies, no single
hp value perfectly centers both branches while any spread remains — this
is the closest data alone can bring them without also closing the spread
to 1.0x, which is not the target.

Two other levers remain on the table and both are out of this worktree's
reach: a damage-reduction/invulnerability phase (boss AI, `scripts/combat/
boss.gd`) that could widen the acceptable TTK band without further data
changes, and deliberately restricting how early rare-grade weapons enter
play (choice-pool logic, `scripts/core/run_state.gd`, already partially
addressed by `evolution_only`). Both are engine behaviour, not data —
reported here rather than attempted, per the ownership boundary.

`bamboo_spirit_lord.damage` (35/hit) against a Taoist with `base_hp: 120`
plus whatever `max_hp` stacks were picked still means the fight has to be
won by kiting, not tanking, per the GDD's movement-only combat model — the
boss hp number changes how long that kiting has to hold up, not whether
kiting is required.

**Genuine improvement in shape, unrelated to this section's fix:** the
controlled sweep shows 5 of 10 runs now reach the boss and fight it for
29-77s, instead of dying before it spawned. That's a real result of the
prior passes' survivability work (`forest_spirit.damage`, `taoist.base_hp`)
holding up under a controlled sweep, not something this pass touched.

## Boss, round 3 — the spread moved inside the winning population itself

**With reachability closed, all six wins now chain, and the residual
problem lives entirely inside that population.** Three wins land inside
45-70s (45.9s, 51.5s, 45.2s); the other three miss by running too *fast*
(27-34s). combat traces the fast group to early chains — chain-trigger
times moved much earlier this sweep (107/132/147/194/227/527s, vs.
197/219/313s before), because reachability no longer gates on luck the way
it did.

**Proof, from the real numbers alone, that a pure `bamboo_spirit_lord.hp`
change cannot fix this — no model required.** Time-to-kill is
`hp / dps`, so changing `hp` alone multiplies every observed TTK by the
same factor `k`. Lifting the fastest win (27s) to the 45s floor needs
`k ≥ 45/27 ≈ 1.667`. Applying that same `k` to the *slowest already-in-
window* win (51.5s) gives `51.5 × 1.667 ≈ 85.9s` — 16s past the 70s
ceiling. **No single `k` satisfies both constraints simultaneously.**
This is the same shape of problem as "Loadout spread" above (spread too
wide for one hp value to center), but now it's internal to the chained
population instead of between chained and unchained runs — hp alone was
never going to be the whole fix, which is exactly why the task asked which
of three levers to pull rather than assuming hp.

**Why it's the fast group and not the slow one that grew, and why that
points at the phoenix curve specifically:** an early chain doesn't stay
weak. `RunState.evolve_weapon()` inherits level at the *moment* of
evolving, but the weapon keeps leveling normally afterward through ordinary
`weapon_upgrade` picks — so a chain that fires at t=107s has ~493s of
remaining run time to level `phoenix_talisman` further before the boss
fight, while a chain firing at t=527s has only ~73s. The earlier the
chain, the more of `phoenix_talisman`'s own `per_level` growth an early
win actually cashes in by boss time. Concretely, on the previous round's
curve (`damage: 17.5, per_level.damage: 3.5`), level 3 (the earliest
possible, at the trigger) gives unit dps `(17.5+3.5×2)/0.87 ≈ 28.2`; level
8 (plausible for an early chain with hundreds of seconds to keep leveling)
gives `(17.5+3.5×7)/0.67 ≈ 62.7` — a 2.23x spread from `phoenix_talisman`'s
own leveling curve alone, before counting anything else the run
accumulated in that extra time.

**Decision: flatten `phoenix_talisman`'s `per_level.damage`, not
`bamboo_spirit_lord.hp` alone and not chain *timing*.** Three levers, why
one:
- *Chain timing* (raising `evolutions.json`'s `min_weapon_level` again,
  now 3, to delay the earliest possible trigger) — rejected. Reachability
  is explicitly closed this pass ("mean gating weapon level 1.75 → 3.00"
  sits right at the current threshold, not comfortably above it), and
  raising the bar risks reopening the problem core-engine's weighting fix
  just closed. Not worth the risk for a lever that only indirectly affects
  the real driver (post-evolution leveling *time*, not trigger level).
- *Boss hp alone* — proven above not to work; the spread itself has to
  narrow.
- **`phoenix_talisman.per_level.damage` — the lever pulled**, paired with
  a small base `damage` increase to hold the trigger-moment floor in
  place. This directly targets the mechanism identified above: how much an
  early chain's *extra leveling time* is worth, without touching
  reachability, wave data, or anything upstream of the weapon itself.

**Change made:** `phoenix_talisman.damage` 17.5→19.0,
`per_level.damage` 3.5→2.2 (`cooldown_sec`, `per_level.cooldown_sec`,
`projectile_count` unchanged). Level 3 (trigger floor) becomes
`(19.0+2.2×2)/0.87 ≈ 26.9` — still above `fire_talisman`@3's `26.0` (a
+3.5% immediate upgrade, preserving "evolution must still feel earned").
Level 8 (late-leveled ceiling) becomes `(19.0+2.2×7)/0.67 ≈ 51.3` — the
level-8-to-level-3 ratio drops from 2.23x to 1.91x, a ~14% compression of
the single largest driver of the early/late spread.

**`bamboo_spirit_lord.hp`: 2600 → 3600.** This is a projection, not a
re-derivation from a full new decomposition — the "other weapons + passive
multiplier" estimate this document used for round 2's sizing was built
against the *pre*-4x/2x-weighting passive-accumulation rate and is now
stale (the weighting fix broadly raises passive stacking for every build,
not just phoenix chains, so that estimate would understate current
non-phoenix dps). Rather than compound a known-stale assumption, this
number comes from scaling the *directly observed* dps implied by the real
TTKs (fast ≈ 2600/27 ≈ 96.3, slow ≈ 2600/51.5 ≈ 50.5 at the old hp) by the
14% compression ratio just computed, then re-centering by geometric mean:
`sqrt(50 × 82) ≈ 64`, `64 × 57.5 ≈ 3680`, rounded to **3600**. Projected
result: the fast group moves from ~27-34s toward the low-to-mid 40s
(still likely to land close to, not comfortably inside, the 45s floor);
the already-good group moves from ~45-52s toward the mid-60s-to-low-70s
(comfortably inside, possibly brushing the 70s ceiling on the slowest one).
**State this plainly: this projection carries real uncertainty** — every
previous round's projection has needed correction against the next real
sweep, and this one chains two approximations (the compression ratio and
the geometric-mean re-centering) rather than one. If combat's next sweep
shows the fast group still short of 45s or the slow group past 70s, the
next lever is the same `per_level.damage` compression pushed further,
informed by which side actually missed.

## Boss, round 4 — the 45-70s window is retired

**combat's confirming sweep on the round-3 projection returned a proof,
not a number.** Five win TTKs: 40.4s, 44.9s, 55.7s, 68.2s, 76.1s — 2 of 5
inside the (former) 45-70s window. The flattening genuinely fixed the
early-chain undershoot the round-3 change targeted: the two unders are now
within 5s of the 45s floor, not 27-34s below it as before. What replaced
it is a symmetric late-chain *overshoot* at 76.1s.

**This is structural, not a miscalibration — TTK is now strictly monotonic
in chain time across every win:**

| Chain time | Win TTK |
|---:|---:|
| 130s | 40.4s |
| 180s | 44.9s |
| 271s | 55.7s |
| 373s | 68.2s |
| 582s | 76.1s |

Every later chain produced a slower kill, in order, with no crossovers.
That's the same mechanism round 3 identified (an early chain gets more
post-evolution leveling time before the boss) still operating — round 3's
`per_level.damage` cut reduced the *slope* of this relationship and the
`hp` increase raised its *intercept*, but neither changes that it's still
a slope: **the band-to-window ratio barely moved, 1.89x → 1.88x, against a
window that is itself only `70/45 = 1.56x` wide.** The band is
structurally wider than the window. No single `bamboo_spirit_lord.hp`
value can contain it — proven the same way round 3's proof worked, now
against real numbers instead of a projection: scaling to bring 76.1s down
to the 70s ceiling needs `hp ≈ 3311`, which drops the bottom to `40.4 ×
(3311/3600) ≈ 37.2s`, past the 45s floor. Scaling to bring 40.4s up to the
45s floor needs `hp ≈ 4010`, which pushes the top to `76.1 × (4010/3600) ≈
84.8s`, past the 70s ceiling. Every `hp` value that fixes one end breaks
the other. **`bamboo_spirit_lord.hp` is exhausted as a lever for this
specific problem** — not under-tuned, not one round away from fitting;
structurally unable to fit a monotonic 1.88x-wide band into a 1.56x-wide
window regardless of where it's centered.

**Decision: retire the 45-70s window rather than keep tuning against
it.** The window was an assumption this document wrote into itself early
in the balance process — never a GDD requirement. The GDD (section 17)
asks for 10-15 minute *sessions*, not a specific boss-fight duration within
one. A boss fight spanning 40-76s inside a ten-minute run is a reasonable
spread for a roguelike whose entire premise is that builds diverge — chain
time is exactly the kind of run-to-run variance the genre is built around,
not a bug to eliminate.

**Why not chase it further instead:** the only remaining lever that could
narrow the band is attacking chain-time variance directly — retuning
`evolutions.json`'s thresholds so chains cluster more tightly in time.
That file was deliberately frozen after "Evolution reachability, round 2"
specifically to protect the reachability win (mean gating weapon level
sitting right at the current threshold, not comfortably above it — see
"Boss, round 3"). Trading a closed, hard-won reachability result to chase
a boss-fight-length window that was never a real requirement is a worse
trade than the thing it would buy. **No further `phoenix_talisman` or
`bamboo_spirit_lord.hp` change is made this pass.** If this decision is
revisited, it should be revisited deliberately — as a conscious choice to
spend the reachability margin on tighter chain timing — not re-litigated
by incrementally re-tuning boss hp or the phoenix curve against a window
this document no longer holds itself to.

**What held, confirming the round-3 change did exactly what it targeted
and nothing else:**
- **Reachability untouched: chain 6/10, any evolution 8/10, both
  unchanged.** The `per_level.damage` flatten cost nothing in
  reachability — it's a post-trigger leveling curve, not a threshold, so
  it was never going to interact with how often a chain fires, only with
  how strong it gets afterward.
- **dps floor unchanged to the decimal: 33.9.** This is the expected,
  necessary result, not a coincidence — the floor is set by an *unevolved*
  run, and a `phoenix_talisman` stat change structurally cannot move a
  number that comes from a build that never reaches `phoenix_talisman`.
  Confirms the round-3 change was correctly scoped to the chained
  population only.
- **dps ceiling down 9.8% to 84.7, as intended.** This is the
  `per_level.damage` compression showing up directly in the one number it
  was built to move — the late-leveled, high-level-phoenix case that was
  driving the old spread.

## Where the run should feel dangerous (confirmed — minute 7 is the intended spike)

**Settled this pass, not just re-derived.** The `forest_spirit.damage`
9→5 cut (previous pass) lowered the *magnitude* of what minute 7 does —
and, paired with `base_hp` 100→120, is what turned losses into wins — but a
second independent batch of five runs shows it did not move *where* the
danger sits: minute 6 is still ~zero damage across all five runs, minute 7
is still the peak in 4 of 5. Two batches of five runs agreeing on the same
shape is the signal this is real design intent, not a one-batch artifact —
**minute 7 is confirmed as the intended spike; minute 6 stays a
reaction-only minute by design, not by accident.** No wave, monster, or
damage changes were made in response to this section this pass — the
previous pass's fix already had the right shape, just needed a second
measurement to confirm it held.

Re-derived from the ranged-pressure term and the (now ten total) run
measurements:

1. **Minutes 1-5** — safe. `forest_spirit` is present from minute 3 onward
   but at low density (6-8 count), and player dps (14.4-28.4) comfortably
   outpaces the modest ranged pressure (0-72 at the pre-fix damage value).
   Consistent with the GDD's "learn the loop" framing for the first half of
   a session.
2. **Minute 6** — *not* dangerous, despite the highest incoming-HP figure up
   to that point (660). Zero damage taken in all five measured runs, because
   the wave is 100% `chase`/`charger` (`bamboo_brute` ×4, `forest_goblin`
   ×16) and kiting fully answers both. This is a reaction/spatial-awareness
   minute (learning to route around the charger), not a DPS-race minute.
3. **Minute 7** — the real first danger point. `forest_spirit` count jumps
   to 10 (from 0 the minute before) while `bamboo_brute` is still present —
   the first minute combining ranged pressure the player can't fully dodge
   with melee/charger pressure demanding movement. Hurt in 4 of 5 measured
   runs, the only minute before 9-10 that did.
4. **Minute 8** — ranged pressure climbs further (`forest_spirit` ×12,
   pre-fix pressure 108, the second-highest in the run) with no
   `bamboo_brute` in that bucket. Not independently measured as a distinct
   danger point by combat, but the ranged-pressure trend says it should read
   as at least as dangerous as minute 7, possibly more.
5. **Minute 9** — *not* dangerous despite the second-highest incoming-HP
   figure in the run (1080). Zero `forest_spirit` in this bucket (same
   `chase`/`charger`-only shape as minute 6) — zero damage in 4 of 5 runs
   confirms it.
6. **Minute 10** — the real climax. Highest `forest_spirit` count in the run
   (14, pre-fix pressure 126) *plus* the highest incoming HP (1554,
   `bamboo_brute` ×10 among it) *plus* the run's last wave immediately
   preceding the boss. Every pressure signal — ranged and total — peaks
   here simultaneously, by design.

Net shape: two "reaction" minutes (6, 9) that look dangerous on paper but
aren't, separated by one real ranged danger point (7) and building to a
second, bigger one (8, unconfirmed) before the true climax (10) feeds
directly into the boss. This is a different shape than the previous pass
described (which had a single step-up at minute 6) — it's two smaller
spikes either side of a false one, not one big spike.

## Survivability

**4 of 5 runs died before the boss even spawned — the headline failure this
pass, and it's fixed with data.** No natural HP regeneration exists anywhere
in the frozen interfaces (`RunState` has no heal path, no passive restores
HP, and no health pickup exists in any `data/*.json` file) — every point of
damage taken is permanent for the run, so a monster whose damage output the
player can't fully avoid is a running clock, not a spike to survive once.
Given the danger model above, that monster is `forest_spirit`: `chase`/
`charger` pressure (minutes 6, 9, and the chase/charger share of every other
minute) is fully avoidable by kiting per the GDD's movement-only combat
model, but ranged pressure isn't, and it climbs every minute it's present
(54 → 72 → 72 → 90 → 108 → 126 at the pre-fix damage value, minutes 3-10).
Summed across the whole run, that's 522 pressure-units of damage the player
cannot fully dodge, against a `base_hp: 100` character with no recovery.

**Decision: cut `forest_spirit.damage`, not wave composition or spawn
density.** Three levers were on the table:
- *Wave composition/ranged density* — reducing `forest_spirit` counts would
  cut total ranged pressure too, but at the cost of undoing the escalating-
  density shape the wave table was deliberately built around (see "Danger
  model" — the climb from 6 to 14 count is what makes minute 10 the
  climax). Left alone.
- *Monster damage* (`forest_spirit.damage`) — cuts lethality per landed hit
  without touching spawn density, so the visual/spatial escalation (more
  spirits on screen as the run goes on) survives untouched while each
  individual hit costs less against a hp pool that never refills. This is
  the lever pulled: **9.0 → 5.0**, a 44% cut. Every ranged-pressure number
  above scales down by the same 44% (522 → 290 pressure-units for the whole
  run).
- *Player-facing sustain* (`taoist.base_hp`) — doesn't address the root
  cause (unavoidable chip damage with no recovery still eventually kills
  over a 600s run at any fixed hp value), but stacks with the damage cut
  rather than substituting for it: **100 → 120**, a 20% buffer increase.

**Combined effect:** "hits of forest_spirit damage a Taoist can absorb"
goes from `100 / 9 ≈ 11.1` to `120 / 5 = 24` — more than double the margin,
from both directions at once, without touching wave density or the
escalating-danger shape the stage was designed around.

## Survivability, round 2 — deliberately accepted, not tuned further

**The isolated residual, and the correction that goes with it.** With
reachability closed and boss TTK now cleanly separable (see "Boss, round
3"), losses are the last open variable, and they're stable: **4/10 across
the controlled sweep**, unchanged from before this pass's evolution fix.
Of those four, two are early deaths (level 13, 12 level-ups, both at
minute 8) and two more cluster at minute 11 — this document's earlier
"roughly half of all runs" claim for the early-death rate was a guess, not
a measurement, and has been corrected above (see "Evolution reachability,
round 2") to the real, twice-measured figure: **2/10**, not half.

**Decision: 4/10 losses in a 10-minute run is accepted as the M1 target,
not a residual to keep tuning toward zero.** This worktree has already
pulled real survivability levers twice (`forest_spirit.damage` 9→5,
`taoist.base_hp` 100→120, see "Survivability" above) and they measurably
worked — the win rate this document has tracked across every sweep went
0/5 → 1/2(pre-controlled) → ... → 6/10 this pass, and none of those wins
existed before the survivability fix landed. A 40% loss rate for a
10-minute roguelike run is not obviously wrong by genre convention — it
reads as "genuinely winnable, genuinely capable of going wrong," not
"punishing" or "trivial." Grinding it toward 0/10 would mean either
removing danger the danger-curve section above deliberately built
(minute 7's ranged spike, the pre-boss climax at minute 10) or padding
`base_hp` past what a kiting-focused, no-regeneration combat model should
need — both would undo real design intent for a number that isn't
demonstrated to be wrong. **No data change made for this item.** If a
future sweep shows the loss rate drifting materially away from ~4/10 (in
either direction) as other changes land, that's the signal to revisit this
decision — not a fixed schedule to keep nudging it.

## Survivability, round 3 — closed

**Early deaths: exactly 2/10, three consecutive sweeps.** Same two seeds
each time, same characteristics (minute 8, level 13, 12 level-ups) — not a
range or a trend, a stable, repeated measurement. This is as settled as
any number in this document gets: three independent controlled sweeps
landing on the identical figure is confirmation, not coincidence.

**Total losses moved 4/10 → 5/10 this round, and that is not
survivability drifting — it's a direct, expected consequence of the
"Boss, round 3" hp raise, not a new failure mode.** Seed 10 chained,
reached the boss (something it could not do before reachability closed),
and could not finish the fight before the run's time limit at minute 12.
That's a *win-rate* effect of raising `bamboo_spirit_lord.hp` for the
"Boss, round 3" fix, showing up in the loss column because an unfinished
boss fight counts as a loss — not a new way for a run to die earlier or
more often. The early-death rate that actually measures survivability
(2/10) didn't move at all.

**Conclusion: survivability is closed.** The "Survivability, round 2"
decision above (4/10 as the accepted M1 target, not tuned toward zero)
stands; the loss-column tick to 5/10 is boss-TTK accounting, not a reason
to reopen it. No `forest_spirit.damage`, `taoist.base_hp`, or wave change
is made this pass.

## Evolution reachability

**Weapon-level retune held up; passive-stack retune didn't.** combat
verified the evolution *trigger* is correctly implemented (forcing it
works, `weapon_evolved` fires) and it fired *organically* once across five
runs — seed 4, `sword` → `twin_sword` at t=461.9s, on the previous pass's
`min_weapon_level: 3, min_passive_stacks: 2`. That's confirmation the
weapon-level half of the previous retune (5 → 3) was correctly sized. The
passive half wasn't: seed 4 itself sat at `old_talisman@4` for the rest of
that run waiting on a second `skill_power` stack that never came, and 1 of
5 runs seeing any evolution at all is too rare for what's meant to be a
headline build-defining mechanic.

**Why the passive side is the binding constraint, not the weapon side:**
the "Weapon/passive growth" table above (re-derived this pass) shows avg
weapon level reaching 1.5-2.0 by mid-run — comfortably past 3 for whichever
weapon a player actually favors, since the average blends across all owned
weapons — while avg per-passive stacks stays under 1.4 through minute 10,
*spread across 8 passives*. Landing 2 stacks of one *specific* named passive
(not just any passive) out of that spread, inside a run with only ~14
level-ups total, is the harder ask by a wide margin — exactly what seed 4
demonstrated directly.

**Retuned: `min_passive_stacks: 2 → 1` on all four rules,
`min_weapon_level` left at 3.** Per instruction, only the passive side moves
— the weapon side is proven working. A single stack of the right passive is
within reach of the pool math shown above without being automatic (a player
still has to draw that specific passive at least once out of 8 options),
preserving evolution as a real but not guaranteed payoff.

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

**Resolved since the above was written:** core-engine's evolved-weapon-level
tracking fix landed (see "Loadout spread, round 2"), so the
`fire_talisman` → `phoenix_talisman` step is no longer structurally
blocked. It fired in 3 of 5 runs immediately after — mechanically, the
chain works.

## Evolution reachability, round 2 — the passive threshold has hit its floor

**`min_passive_stacks` cannot be retuned any further; it's already at the
schema minimum (1).** The controlled ten-seed sweep still measured only
2/10 chain completion (3/10 any evolution) with that floor in place, and
`tools/validate_data.gd` rejects a non-positive `min_passive_stacks` by
design — 0 would mean the rule fires without ever landing the passive at
all, which isn't "reachable," it's "the requirement doesn't exist." There
is no lower number to retune to.

**Why this is a probability-of-a-single-draw problem, not a threshold
problem, and why that ceiling is genuinely outside this worktree's data
levers:** with `min_passive_stacks: 1`, the phoenix chain's binding
requirement reduces to "did `skill_power` get drawn at least once, while
`old_talisman` also reached level 3, before the run ended." Every level-up
offers 3 choices sampled from a pool of roughly 8 passives plus a handful
of weapon options (this document's own "Weapon/passive growth" model puts
the pool at roughly constant size ~10-11 for most of a run, since
`weapon_new` slots convert 1:1 into `weapon_upgrade` slots as the 3
reachable base weapons are acquired). A back-of-envelope calc using that
model — per-level miss-probability `1 - 1/11 ≈ 0.909`, applied across a
full ~15-level-up run — predicts roughly **76% of runs draw `skill_power`
at least once**, nowhere close to the measured ~20-30%. That gap is itself
informative: **correction, made this pass — this document originally
guessed "roughly half of all runs" die before accumulating enough
level-ups to draw against, inferred from the "5 of 10 reach the boss"
figure without direct death-timing data. That guess was wrong and is
corrected here rather than left in the record: combat has since measured
early deaths directly, twice, at a stable 2/10** (not half), bucketed at
minute 8 (×2) with characteristic level 13 / 12 level-ups at death. A 2/10
early-death rate accounts for most, not all, of the gap between this
section's 76.8%-ish theoretical per-draw ceiling and the 60% chain rate
core-engine's fix ultimately achieved (see the intro above) — the model's
draw-probability math was right; the survival-rate assumption plugged into
its explanation was the part that needed real data, and now has it.

**Levers checked and ruled out, all still inside `data/**`:**
- *Lower `min_passive_stacks` further* — already at the schema floor (1).
- *Bump `xp_drop` values to buy a few more level-ups* — modeled explicitly:
  a ~30-40% `forest_spirit`/`bamboo_brute` `xp_drop` increase (the largest
  change that wouldn't also re-break the front-loading fix by touching
  `forest_goblin`) raises the implied endgame level by only ~1 (level
  16→17, i.e. one extra level-up), moving the modeled draw-success
  probability from ~76% to ~78% — a rounding error against the ~50
  percentage-point gap this needs to close, and it risks distorting the
  XP-level table, the danger-curve minute mapping, and every DPS-by-minute
  number this document has calibrated. Not worth pulling for a fix this
  small.
- *Broaden which passive satisfies each rule* — `evolutions.json`'s
  `requires_passive` is a single string field (ARCHITECTURE.md section 4,
  frozen); there's no schema room to say "any of N passives" without a
  contract change.
- *Add alternate evolution paths gated on easier-to-draw passives* — would
  require new `evolution_only` weapon entries (new sprites, new balance
  surface) for a mechanic the task didn't ask to expand, not a tuning fix.

**Conclusion: this needs engine behaviour, not data.** The actual lever
that would move chain-reachability from ~20% toward the requested 70-80%
is *how the choice pool weights passives*, not any per-rule threshold —
concretely, weighting `skill_power`/`attack_damage`/`attack_speed` (the
three currently-used evolution-gating passives) higher in
`RunState._passive_choices()`/`_build_choices()`, or some other mechanism
that raises the odds of the *specific* required passive appearing without
touching the frozen `min_passive_stacks` contract. That's
`scripts/core/run_state.gd` — outside `data/**`. Flagging this rather than
attempting a data workaround, per instruction: **I could not find a data-
only lever that materially moves this number**, and the smallest lever I
did find (an xp bump) isn't worth its side effects for a ~2 percentage
point gain against a ~50 point target.

**Confirmed correct: core-engine landed the recommended fix.** Weighting
both halves of the requirement (4x weapon-level, 2x passive, not
passive-only — the weapon side needed a lighter push since it's a 1-step
gate while the passive side is competing against 7 other options) took
chain rate 3/10 → 6/10, any evolution 6/10 → 8/10, and wins 4/10 → 6/10.
**Evolution reachability is closed.** The remaining open item from this
section is boss TTK, which is no longer a reachability problem — see
"Boss, round 3" above.

**Mild overcorrection, noted per combat's caveat, not acted on.** The
weighting flipped which half of the requirement is now the tighter
constraint — previously weapon-level was easy and passive-draw was the
bottleneck; now the reverse holds slightly. combat is explicit this costs
far less than the asymmetry it replaced (the passive half only ever needed
one successful draw where the weapon half needed two level-ups), and
recommends against chasing it further. Agreed — no `evolutions.json`
change made for this specific point.

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

## Future-area bestiary — Capital City, Royal Tomb, Spirit World

**Eighteen monsters added to `data/monsters.json`, art only until now.**
asset-forge generated sprites for the GDD's three post-M1 areas
(`asset/SECOND_ASSET_BATCH_REPORT.md`); this pass gives them full schema
entries. **No stage or wave references these monsters** — Capital City,
Royal Tomb, and Spirit World are not wired into any `data/stages.json`
entry, `bamboo_forest` is untouched, and wiring a future area into an
actual playable stage is explicitly a decision this worktree has not been
asked to make. This section documents a bestiary, not a balanced encounter.

**These numbers are not tuned against Bamboo Forest's curve, and
shouldn't be read as if they were.** Every number above this point in the
document (DPS model, danger model, boss hp) exists because it was measured
against real play of Bamboo Forest specifically. None of that measurement
exists for these three areas — there's no stage, no wave table, no player
loadout progression to size them against yet. What follows is a **tiering
scheme**, not a validated difficulty curve: internally consistent,
anchored to Bamboo Forest's shipped numbers as a starting reference point,
but a placeholder pending real playtesting once these areas actually
become stages.

**Tiering scheme:** each area is one step in a geometric progression from
Bamboo Forest (tier 1, ×1.0), applied to `hp`, `damage`, `xp_drop`, and
`gold_drop`. `speed` is *not* tier-scaled — it reflects movement pace, not
raw power, and scaling it up per tier would make later areas control
worse rather than feel harder, which isn't the intent.

| Tier | Area | Multiplier |
|---|---|---|
| 1 | Bamboo Forest (shipped) | ×1.0 |
| 2 | Capital City | ×1.6 |
| 3 | Royal Tomb | ×2.4 |
| 4 | Spirit World | ×3.4 |

Each tier's trash monsters are anchored to one of Bamboo Forest's three
trash archetypes, scaled by that tier's multiplier, with individual
narrative variance (a "scout" runs faster and hits softer than a
"guardian," an "elite" named figure like `jeoseung_saja` sits ~10% above
its archetype baseline) — the same method used for the four Bamboo Forest
monsters already in this document, just without real playtest data to
correct it against yet:

| Archetype | Anchor | hp | damage | xp_drop | gold_drop |
|---|---|---:|---:|---:|---:|
| `chase` | `forest_goblin` | 20 | 6 | 1 | 1 |
| `ranged` | `forest_spirit` | 16 | 5 | 5 | 2 |
| `charger` | `bamboo_brute` | 85 | 18 | 8 | 4 |
| `boss` | `bamboo_spirit_lord` | 2600 | 35 | 200 | 150 |

*(`bamboo_spirit_lord.hp` is 3600 as of "Boss, round 3" above — the
future-area monster hp values below were computed against 2600, the
anchor at the time this bestiary was written, and were not recomputed
when the boss retune landed since that's outside this section's scope.
They're already a stated placeholder pending real playtest data for these
areas; treat the tier multipliers as the durable part of this scheme, not
these specific numbers.)*

`swarm` has no Bamboo Forest anchor (unused there) — extrapolated at
~60% of the `chase` archetype's hp/damage with higher speed, reflecting
"individually weak, dangerous in numbers," and flagged here as the one
archetype baseline that's a pure estimate rather than a scaled-down real
number.

**Capital City (×1.6) — the first future area, `dokkaebi_king` boss:**

| id | Role | hp | damage | speed | behaviour | Note |
|---|---|---:|---:|---:|---|---|
| `gwimyeon_dokkaebi` | standard chase | 32 | 10 | 58 | `chase` | baseline chase archetype |
| `blue_dokkaebi` | swarm | 19 | 6 | 68 | `swarm` | common variant, meant to appear in numbers |
| `gumiho_scout` | fast scout | 26 | 9 | 75 | `chase` | lower hp/damage than `gwimyeon_dokkaebi`, faster — a harassment variant, not a fox-in-disguise (that's reserved for the real `gumiho` boss two areas later) |
| `seonbi_wraith` | ranged | 26 | 8 | 38 | `ranged` | baseline ranged archetype |
| `haetae_guardian` | charger | 136 | 29 | 65 | `charger` | baseline charger archetype |
| `dokkaebi_king` | **boss** | 4160 | 56 | 52 | `boss` | baseline boss archetype |

**Royal Tomb (×2.4) — `ancient_imugi` boss:**

| id | Role | hp | damage | speed | behaviour | Note |
|---|---|---:|---:|---:|---|---|
| `cheonyeo_gwisin` | ranged | 38 | 12 | 40 | `ranged` | baseline ranged archetype |
| `dalgyal_gwisin` | chase | 48 | 14 | 50 | `chase` | baseline chase archetype, slower — an unsettling crawl rather than a rush |
| `jeoseung_saja` | elite charger | 224 | 47 | 72 | `charger` | ~10% above the charger baseline — a named folklore figure (the death-messenger), not a generic beast |
| `tomb_jangseung` | stationary ranged | 38 | 12 | 15 | `ranged` | ranged archetype stats, speed cut to near-stationary — a totem, not a mobile caster |
| `imugi_whelp` | weak chase | 41 | 12 | 58 | `chase` | ~15% under the chase baseline — "whelp" is explicitly the young/weak form of `ancient_imugi` |
| `ancient_imugi` | **boss** | 6240 | 84 | 48 | `boss` | baseline boss archetype |

**Spirit World (×3.4) — `gumiho` boss, the pre-endgame area:**

| id | Role | hp | damage | speed | behaviour | Note |
|---|---|---:|---:|---:|---|---|
| `wonhon` | ranged | 54 | 17 | 44 | `ranged` | baseline ranged archetype — the direct thematic escalation of `forest_spirit` (`name_ko` shares the "원혼" root) |
| `dokkaebi_fire` | ranged | 54 | 17 | 55 | `ranged` | same baseline as `wonhon`, faster — a will-o'-the-wisp flicker rather than a drifting ghost |
| `shadow_dokkaebi` | fast chase | 62 | 20 | 80 | `chase` | above the chase baseline in hp/damage but the fastest non-boss monster in the bestiary — a stealth ambusher, hits harder when it catches you |
| `fox_spirit` | swarm | 41 | 14 | 70 | `swarm` | baseline swarm archetype |
| `bulgasari` | charger | 289 | 61 | 65 | `charger` | baseline charger archetype — the toughest non-boss monster shipped, matching its folklore role as an unstoppable metal-devouring beast |
| `gumiho` | **boss** | 8840 | 119 | 55 | `boss` | baseline boss archetype — the true nine-tailed fox, distinct from the lesser `gumiho_scout` two tiers earlier |

**`collision_radius` derivation — same method as Bamboo Forest, verified
independently rather than trusted from the asset report.** All eighteen
sprites ship on a 92×92 transparent canvas; the asset report states each
one's opaque content size and a "max radius" (half that content width).
Measured every sprite's canvas, opaque bounding box, and per-row median
silhouette width directly (`PIL`, same script as the Bamboo Forest pass) —
the measured bounding boxes matched the report's stated content sizes
exactly, confirming the report's numbers rather than just trusting them.
`collision_radius` is set to half the *median* row width (not the max row
or the canvas), so a raised weapon or ornament — several of these sprites
have one, e.g. `jeoseung_saja`'s staff, `haetae_guardian`'s mane — doesn't
inflate the hitbox past the actual body, consistent with the Bamboo Forest
derivation above. Every value landed well inside the report's own stated
ceiling and `tools/validate_data.gd`'s half-sprite-width check (the
largest, `gumiho` at 29.5, is still under half of the 92px canvas):

| id | Content bbox | Median row width | `collision_radius` |
|---|---:|---:|---:|
| `gwimyeon_dokkaebi` | 36×54 | 27 | 13.5 |
| `blue_dokkaebi` | 38×50 | 28 | 14.0 |
| `gumiho_scout` | 51×48 | 42 | 21.0 |
| `seonbi_wraith` | 28×52 | 18 | 9.0 |
| `haetae_guardian` | 49×58 | 41 | 20.5 |
| `dokkaebi_king` | 60×76 | 51 | 25.5 |
| `cheonyeo_gwisin` | 50×52 | 47 | 23.5 |
| `dalgyal_gwisin` | 47×44 | 47 | 23.5 |
| `jeoseung_saja` | 58×58 | 51 | 25.5 |
| `tomb_jangseung` | 29×58 | 18 | 9.0 |
| `imugi_whelp` | 49×52 | 28 | 14.0 |
| `ancient_imugi` | 69×76 | 52 | 26.0 |
| `wonhon` | 38×50 | 26 | 13.0 |
| `dokkaebi_fire` | 48×44 | 34 | 17.0 |
| `shadow_dokkaebi` | 44×52 | 29 | 14.5 |
| `fox_spirit` | 49×48 | 37 | 18.5 |
| `bulgasari` | 59×58 | 41 | 20.5 |
| `gumiho` | 76×76 | 59 | 29.5 |

**Directional rotation sprites — not implemented, flagged for a
coordinator decision.** The asset report's `verify_assets.py` output
mentions "32 monster rotations" from the first art batch (four existing
Bamboo Forest monsters × eight directions) that nothing currently
references, since `monsters.json`'s `sprite` field is a single flat path.
I did not add a schema field for these. Reasoning: `data/**` is this
worktree's to design, but a directional-sprite field is only useful if
combat actually branches rendering on facing direction, and that's a
`scripts/combat/**` decision (how facing is tracked, whether it's worth
the render-state complexity for top-down auto-combat where the player
mostly watches silhouettes in motion, not idle facing) — not something
content-data should decide unilaterally by inventing a field first and
hoping combat consumes it. **My recommendation, offered for the
coordinator to weigh, not acted on:** probably not worth it for M1's
auto-combat loop specifically — Vampire-Survivors-style games are
readable from silhouette and movement alone, and eight-direction sprite
swapping is a meaningful `scripts/combat/**` and `scripts/weapons/**`
(hooking into whatever already flips/rotates player sprites, see
`character_motion.gd`) undertaking for a payoff that's mostly idle-frame
polish. If the coordinator decides it's worth it, the schema shape I'd
suggest is a `sprite_directions` object (8 keys, one per compass
direction) alongside the existing flat `sprite` (kept as the idle/default
fallback so nothing else breaks), added only once combat confirms it will
actually branch on it.
