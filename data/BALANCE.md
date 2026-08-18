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

## Boss, round 5 — the hitbox catches up to the art, and moves balance again

**Not a balance pass — a collision-accuracy fix with a balance
consequence, and the consequence is worth stating plainly rather than
letting it show up unexplained in the next sweep.** `bamboo_spirit_lord`
regenerated at 120×150 (from 60×76) because the old art read as an elite,
not a climax, and combat separately removed a 2.2x root scale that had
been silently sizing the collision circle beyond what `collision_radius`
declared. Between those two changes, the shipped `collision_radius: 23.5`
was doing two jobs it was never sized for: representing a sprite half the
current size, and representing a hitbox that was actually being
multiplied by a factor nothing in `data/**` controlled. Re-derived from
the new art the same way as every other monster in this document — median
row width, not canvas, not max row — the correct value is **47.5**, more
than double the old field's number.

**Expected effect, and by how much: this narrows the retired window's
band, it doesn't reopen the decision to chase it.** "Boss, round 4"
retired the 45-70s window because the real win-TTK band (40.4-76.1s,
1.88x) was structurally wider than the window (1.56x) and no
`bamboo_spirit_lord.hp` value could fit both without breaking one end. A
bigger hitbox doesn't change `hp` or `dps` — it changes how much of a
build's *declared* dps actually lands, and it does that unevenly across
the band. The slow end of that band (unevolved runs, the 40.4s-and-nearby
wins) is dps-limited by a single, less precise, more likely-to-graze
projectile stream; a hitbox 2.2x the brute's gives those builds more room
to connect shots that would previously have missed, raising their
*realized* dps toward their theoretical dps. The fast end (late-chain,
multi-hit `phoenix_talisman` output) was already landing most of its
declared dps against the old, smaller hitbox — there's less headroom left
to gain. **The expected direction is the floor moving up more than the
ceiling does, which narrows the band from the bottom rather than
re-centering it.** combat has already measured this in isolation — boss
TTK at 49.0s from the hitbox change alone, which lands inside the 45-70s
window this document retired, without any `hp` or weapon-curve change.
That's consistent with the floor-moves-more-than-ceiling prediction above,
though one measurement at one build point doesn't establish the new band's
actual width — that's the next controlled sweep's job, not a conclusion to
draw from a single number.

**No `bamboo_spirit_lord.hp` or `phoenix_talisman` change made this
pass, and the window decision is not reopened.** "Boss, round 4"'s
retirement stands: the 45-70s figure is not this document's target
anymore, so "the hitbox change happens to land near it" is interesting
context, not a reason to declare victory or start re-tuning toward it
again. What changed this pass is collision accuracy (the field now
matches the art, and nothing upstream silently multiplies it); what it's
expected to do to the band is recorded here so the next sweep's numbers
have a stated prediction to confirm or correct against, per how every
other round in this document has operated.

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
| bamboo_spirit_lord | 120×150 | 95 | 120 |

Reference: the Taoist player sprite's canvas is 92×92, but its actual
silhouette (alpha bounding box) is 37×46 — the canvas carries padding for
8-direction rotation framing that the monster sprites don't have (their
canvas is already tightly cropped to the silhouette, confirmed by checking
each file's alpha bbox against its canvas size).

**`bamboo_spirit_lord` regenerated this pass, 60×76 → 120×150 (exactly
2x).** combat measured the old art reading as an elite rather than a
climax and asset-forge regenerated it larger, with matching rotations and
death frames; combat separately removed a 2.2x root scale that had been
silently inflating the collision circle beyond what `collision_radius`
declared, so the field is now the sole source of truth for boss collision
size with nothing upstream secretly multiplying it. Re-measured rather
than assuming the old derivation still applied at the new size — median
width scaled to 95 (not simply 2× the old 47, since silhouette proportions
aren't guaranteed to scale linearly with canvas size, though in this case
they landed close: 47×2=94 vs. the measured 95).

*Median/max silhouette width = per-row count of non-transparent pixels,
median and max taken across all rows. This distinguishes core body from
protruding elements: `bamboo_brute` holds a club that widens a minority of
rows to the full 61px canvas, but a typical row (median) is 43px — the club
is not the body. Same effect on `bamboo_spirit_lord`'s two outstretched
blade-like ornaments (median 95 vs. max 120 — a p25/p75 spread of 74/106
around that median, confirming it's a representative typical-row value,
not a fluke).

**`collision_radius` (ARCHITECTURE.md section 4, now required)** is set to
half the *median* silhouette width, not half the canvas or half the max row
— so a swung club or an ornamental blade doesn't inflate the hitbox past
what the body actually occupies:

| Monster | `collision_radius` | Derivation |
|---|---|---|
| forest_goblin | 11.5 | 23 (median width) / 2 |
| forest_spirit | 8.0 | 16 / 2 |
| bamboo_brute | 21.5 | 43 / 2 |
| bamboo_spirit_lord | **47.5** (was 23.5) | 95 / 2 |

All four are comfortably under the validator's half-sprite-width ceiling
(16.5, 13.0, 30.5, and now **60.0** for the boss) — the point of that
ceiling isn't that these values are near it, it's that a typo (e.g.
transposing brute and boss, or entering a canvas dimension instead of a
radius) gets caught instead of silently shipping as an invisible wall.

**Feel being aimed for:** `forest_goblin` and `forest_spirit` should read as
small and threadable — a player weaving through a cluster of 5-10 goblins
(minutes 1-5 spawn density) needs real gaps to path through, not a wall of
11.5-radius circles touching edge-to-edge. `bamboo_brute` at 21.5 is
deliberately the largest non-boss radius (roughly double the goblin's) —
it's the charger, and the collision size should make "don't stand where the
brute is" a real spatial commitment, not a graze. **`bamboo_spirit_lord` at
47.5 is now genuinely the largest hitbox in the game — 2.2x the brute's,
not "marginally larger" as this document argued when the boss was
60×76.** That old argument (a boss fight won on attack-pattern reading, not
on the body itself being an unavoidable wall) was written for art roughly
brute-sized; the regenerated 120×150 boss reads as a climax precisely
*because* it now occupies more space, and the hitbox should track that —
this isn't a design regression, it's the collision size catching up to
what the art now visually communicates. See "Boss, round 5" below for the
balance consequence.

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

---

# N4-2 — Weapon grades & the 15-minute pacing pass (2026-08-14, post-rebuild)

Everything above this line predates the 2026-08-14 full rebuild and is kept
as history; file paths it cites (`scripts/core/run_state.gd`, weighting,
crits) no longer exist. This section describes the rebuilt game's current
numbers.

## Weapon grade ladder (`weapons.json` `_grades`)

GDD §5/§33 vertical axis. Ladder: `common → uncommon → rare → epic →
mythic` (일반→고급→희귀→영웅→신화; 전설 is deferred until any file needs
it — the ladder deliberately uses only grade names the data files already
used). A weapon's data `grade` is its base rung; the run grade rises via
the `grade_up` level-up card and carries across weapon mods
(`max(carried, result base)`, GDD §33 승계). Per-step factors compound
only for steps *above* the base rung — base stats already price the base
grade in:

| Step | damage | cooldown | flag |
|---|---|---|---|
| uncommon | ×1.15 | ×0.96 | — |
| rare | ×1.18 | ×0.94 | — |
| epic | ×1.22 | ×0.92 | — |
| mythic | ×1.30 | ×0.90 | `tinted` (projectile takes the tier color) |

Full common→mythic: damage ×2.15, cooldown ×0.75 → ~2.9x unit dps for
four level-up picks — comparable to spending the same picks on levels,
so grade picks compete with, rather than dominate, the pool. Reaching
the top rung fires the one-off gold callout (damage-number style).

## 15-minute Bamboo Forest curve (`stages.json`)

GDD §23/§34. `duration_sec` 1080 (timeout-as-victory kept per N5-1a),
`boss_at_sec` 900 (15:00), `surge_at_sec` 840 (14:00 대량 공세),
elites from 5:00. Shape by bucket (total spawn count): quiet opening
5/6 (0:00–2:00), steady ramp 12→26 (2:00–10:00) with elite checkpoints
at 300/540/720, heavy ramp 32→26 (11:00–13:00), **surge 57 at 840 —
the strict spawn-count peak, enforced by `RunFlow.schedule_issues` and
validate_data**, boss + escort 24 at 900. `live_cap` stays 60; the surge
saturates it by design (measured: 60 fps at the saturated cap on the
Intel UHD 770 dev machine, worst case).

Implied XP: ~1,366 orb XP over the run → level ~20 (≈19 picks), enough
for one weapon line to reach mythic while still leveling others.

## Elite variant (`monsters.json` `elite_of`)

`bamboo_brute_elite` = `bamboo_brute` × {hp 6.0, damage 1.5, speed 0.85,
size 1.6, rewards 6.0} → 510 hp, 27 dmg, 59.5 spd, 1.6x sprite. Derived
at load by `Enemy.derive_elite_stats` — pure multipliers, same enemy
code. Its drop table is the GDD §21 promise (정예 → 희귀 재료):
whetstone 35%, cinnabar 30%, thunder/ghost-iron 12% each, tough_fiber
50% — an elite kill is the run's main special-material faucet.

## Soft enrage (`stages.json` `soft_enrage`)

GDD §34 post-boss rule. From 920s, over a 120s ramp, newly spawned
monsters scale to ×3 hp / ×2.5 damage / ×1.3 speed (lerp, applied at
spawn by the spawner; the boss spawns at 900, before the ramp, and is
never scaled). A stalled post-boss field therefore turns lethal instead
of dragging; a player who survives anyway still resolves at the 1080s
timeout victory.

## Boss retune

`bamboo_spirit_lord.hp` 3600 → 7000. The 3600 value was sized for a
10-minute, grade-less run (~40–85 dps band, see "Boss, round 4" above).
The 15-minute run adds ~4 more levels and the grade axis (~up to 2.9x on
invested weapons); 7000 targets a boss fight in the tens-of-seconds
range for a mid build rather than an instant melt. This is a projection,
not a sweep-validated number — the next controlled sweep should re-check
it, per this document's standing practice.

# N4-2b — The 5-minute rescale (2026-08-14, owner decision)

**The 15-minute curve above was built against a stale run length.** The
owner decided mid-N4-2 that a mobile run is **5 minutes**; that decision
is recorded in ROADMAP.md ("런 길이") and this section supersedes the
"15-minute Bamboo Forest curve" timings above. Everything structural
from N4-2 stays — the grade ladder, elite derivation, schedule
invariants, soft enrage — only the time scale and the numbers coupled to
it change. Later zones stretch to **8–10 minutes** using the same code:
run length lives in each stage's `duration_sec`, and every consumer
(spawner, stage timeout, `RunFlow.schedule_issues`, the playtest
harness) derives from that field — nothing hardcodes 300.

## Timeline (`stages.json`, duration_sec 300)

| Time | Beat |
|---|---|
| 0:00–1:00 | quiet opening (goblins only, 5/6 spawns) |
| 1:00–2:00 | ramp; ranged spirits join; first special material window |
| 2:00 | first `bamboo_brute_elite` |
| 3:30 | surge — 57 spawns, the strict spawn-count peak (fps worst case) |
| 4:00 | boss (`boss_at_sec` 240) + escort 24 |
| 4:40 | soft enrage (start 280, ramp 20s, same ×3/×2.5/×1.3 mults) |
| 5:00 | timeout → victory |

Bucket spawn totals: 5 / 6 / 12 / 15 / 17 / 24 / 24 / **57** / 24.
`live_cap` stays 60; the surge still saturates it by design.
`RunFlow.schedule_issues` gained one invariant with this pass: any wave
or boss time past `duration_sec` is a data error (checked per stage, so
an 8-minute zone validates against its own length).

## XP curve (`progression.json`)

`base_xp` 5 → **6**, `growth` 1.25 → **1.5**:
`xp_to_next(L) = round(6 × 1.5^(L-1))`. Full-collection orb XP over the
run is ~976 (goblins 111, spirits 265, brutes 112, elites 288, boss
200), which crosses the level-11 threshold (681 cumulative) but not
level 12 (1027) — a ceiling of ~10 level-ups, realistically **8–10**
after collection losses, so the power-up popup stays a regular beat
(~one per 30s) instead of the old curve's 16+ pops.

## Drop-rate bias (`drop_tables.json`)

First-run FTUE target: a special material — and therefore the 3-choice
mod popup — should land inside the first run, realistically in the
1:00–2:00 ramp. `forest_goblin.whetstone` 0.01 → **0.03**,
`forest_spirit.dokkaebi_flame` 0.02 → **0.07**, `.cinnabar` 0.015 →
**0.04**, `.thunder_stone` 0.01 → **0.015**. Expected specials in the
1:00–2:00 window ≈ 1.0 (≈12 goblin + 6 spirit kills), and the 2:00
elite (35%/30%/12%/12% special table) backstops any dry first window.

## Grade climb

Unchanged ladder and step factors. With 8–10 level-ups and a pool where
a single-weapon build sees a grade card offered in ~35–40% of draws, a
player committing to one line lands **two-plus grade steps**
(common→uncommon→rare on the starter: damage ×1.357, cooldown ×0.902 —
~1.5x unit dps), verified by the grade-priority playtest bot.

## Boss retune

`bamboo_spirit_lord.hp` 7000 → **2400**. The 7000 value assumed ~level
20 plus a possible mythic line; at 4:00 a 5-minute run sits near level
9–10. Measured, not just projected: two full autoplay runs
(`tools/playtest.tscn`, grade-priority bot) both ended as 300s timeout
victories at 60 fps through the surge, with 8 and 9 level-ups, first
special material at 1:14 / 2:10, and — against an interim 2800 value —
the bot left the boss at 1335/2800, i.e. ~24 boss-dps across the full
60s window from a deliberately conservative kiting bot. A mid human
build lands roughly 1.5–2x that (~40–50 boss dps), so **2400** puts the
fight at ~48–60s — killable just inside the 4:00–5:00 window, while a
weak build still resolves as the timeout victory. Re-tune in N4-3 once
the full weapon set lands.

# N4-4a — The six taoist core weapons (2026-08-14, GDD §11.1)

Numbers for the five new cores are sized against the starter
(`old_talisman` 12 dmg / 1.2s = 10 unit dps) so that no new-weapon card
dominates on raw dps — each buys a *shape*, not a bigger number:

- `hwabu` 10/1.6s (6.25 sps) — explosion `radius_px 90` pays off only on
  clumps; on a lone target it is strictly worse than the starter.
- `noebu` 11/1.4s (7.9 sps) — chain `jumps 3, falloff 0.7`: full value
  (11+7.7+5.4+3.8 ≈ 27.9/shot ≈ 20 dps) needs a spread crowd within 150px.
- `seokjang` 14/1.5s at `range_px 110` — zero reach, `knockback 2.5x`
  buys survival, not dps.
- `honbul` 5 contact + burn 3/s×2s, per-enemy re-hit = `cooldown_sec`
  0.9 — accumulates while moving, no burst.
- `beopgeom` 9/1.1s, pierce-all — scales linearly with how many enemies
  queue on its line; on a flank it is the weakest card in the pool.

Mod results (`hwaryeongbu`, `noejeongbu`, `bongmageom`, `ghost_staff`,
`flame_honbul`) sit ~25–40% above their base plus the branch effect
(burn-spread / shock / seal burst / lifesteal / stronger burn), all epic
grade so the N4-6 carry rule keeps run grade progress.

Old `beopgeom` (epic, `old_talisman`+cinnabar seal result) became the
common pierce core per GDD §11.1 ("봉인은 관통 무기의 개조 분기다");
`lightning_talisman` and its recipe were deleted — chain is now `noebu`'s
base mechanic and 뇌정석 belongs to `noebu`→`noejeongbu`.

Autoplay verification (tools/playtest.tscn, one run): victory at 298.5s,
10 level-ups, weapons taken hwabu→Lv2 + beopgeom→봉마검 (both mods
offered were taken at 3:00/3:33), surge fps min 59 / avg 60 over 1775
samples, peak live 51, 185 kills, boss killed. Deeper tuning deferred to
N4-3 as planned.

# N4-3 — Single-weapon balance pass, measured (2026-08-14)

**Method.** `tools/playtest.tscn` gained a forced-build harness: `--weapon=<id>`
starts the kiting bot with a named weapon instead of the character's starter,
and its card policy only ever grows that one weapon (its 개조 first, then a
grade raise, then a level) or takes a passive — never a second weapon; screens
with none of those are skipped. `--batch` runs all ten base weapons once and
prints the table; `--seed` pins the field/choice/loot RNG streams so all ten
runs face identical waves and drops; `--speed` scales `Engine.time_scale` for
headless sweeps (same physics delta, more steps per real second — simulation
granularity unchanged, fps columns meaningless above 1x). Damage totals count
every weapon `hit_landed` plus DoT ticks (`Spawner.burn_damaged`). All sweeps
below: seed 20260814, speed 8, headless. Caveats stated up front: n=1 per
weapon per sweep, and the kiting bot (danger radius 120px) systematically
underplays short-range weapons relative to a human who hugs crowds — the
numbers compare weapons under one consistent policy, they are not absolute
human dps.

## Baseline — BEFORE tuning (HEAD 9eb86f4)

| weapon | outcome | time_s | level | kills | damage | dps | final build |
|---|---|---|---|---|---|---|---|
| old_talisman | defeat | 277.7 | 6 | 102 | 3689 | 13.3 | fire_talisman Lv1 |
| hwabu | defeat | 178.8 | 6 | 65 | 2171 | 12.1 | hwabu Lv1 |
| noebu | defeat | 220.1 | 8 | 100 | 3977 | 18.1 | noejeongbu Lv3 |
| seokjang | defeat | 226.0 | 8 | 114 | 4383 | 19.4 | seokjang Lv3 |
| honbul | victory | 300.1 | 1 | 3 | 136 | 0.5 | honbul Lv1 |
| beopgeom | defeat | 274.8 | 5 | 102 | 4754 | 17.3 | bongmageom Lv1 |
| gyeolgye | defeat | 157.3 | 6 | 53 | 1283 | 8.2 | gyeolgye Lv3 |
| sinjang | victory | 300.1 | 6 | 51 | 1805 | 6.0 | sinjang Lv1 |
| jineon | victory | 300.1 | 3 | 16 | 702 | 2.3 | jineon Lv2 |
| sal | defeat | 222.9 | 7 | 90 | 2750 | 12.3 | sal Lv1 |

**Total-damage spread: 4754 / 136 = 35x.** Three structural traps, not just
weak numbers:

- **혼불 was functionally broken as a carry (136 damage, 3 kills, level 1
  after 5 minutes).** The orb hit radius was a hardcoded 5px visual constant
  (`AutoWeapon.ORB_RADIUS_PX`) — a razor annulus at orbit radius 70 that
  walking enemies cross between physics frames. 3 kills → no XP → no
  level-ups: the weapon locked the whole run at level 1. It "won" by kiting
  for 300s while dealing nothing. Trap in the exact GDD sense.
- **진언 (702) and 신장 (1805) survive but cannot clear.** 진언's 6dmg/3s
  pulse is 2 dps before crowd multiplication and its own knockback pushes
  enemies back out of the next pulse; 신장's general spends 43% of the run
  dead (lifetime 8s, then a full 6s resummon cooldown).
- **결계 died earliest of all ten (157.3s)** — ward duration 3.5s under a 4s
  cooldown means zero overlap, and radius 70 holds a pack for roughly one
  tick before it walks out.

The healthy band (old_talisman 3689 … beopgeom 4754, 1.29x wide) shows the
shape the whole kit should land in.

## What was tuned, and why (six rounds, each against a fresh sweep)

Engine knobs moved into data this pass (all optional, defaults preserve old
behaviour; validated by `tools/validate_data.gd`):
- `explosion.edge_falloff` — damage share kept at the blast edge (화부 line);
  new `WeaponMath.explosion_damage`, unit-tested.
- `pierce_retention` — damage kept per pierced body (법검 line).
- `orbit.orb_radius_px` — the orb contact radius that was a hardcoded 5px
  visual constant, the root cause of the 혼불 trap.

Data changes (data/weapons.json unless noted):
- **혼불**: orbit `radius_px` 70→105 (the ring now sweeps where kiting
  enemies actually hover), `orb_radius_px` 5(code)→16, orbs 2→3, damage
  5→8, speed 150→170. 화령 혼불 likewise (115px ring, 4 orbs, dmg 10).
- **진언**: damage 6→13.5, cooldown 3.0→2.5, radius 120→130 (봉인 진언
  8→16 / 2.7→2.2 / 135→145). Control identity (knockback+stun) untouched.
- **신장**: uptime 57%→76% (lifetime 8→11, resummon cooldown 6→3.5),
  damage 10→15, attack 0.8→0.65s, speed 130→150 (뇌정 신장 likewise).
- **결계**: radius 70→85 but tick damage 4→3.0, tick 0.5→0.6s, duration
  3.5→3.5 (net: wider, weaker per tick — it was the hottest weapon for
  three consecutive sweeps after the first radius buff).
- **화부**: damage 10→13, cooldown 1.6→1.45, `edge_falloff` 0.7 (clump
  identity kept — the falloff is what pays for the single-target buff).
- **석장**: range 110→118, damage 14→12 — reach buys engagement uptime,
  per-swing damage pays for it (귀철 석장 128px/16).
- **낡은 부적**: damage 12→15, cooldown 1.2→1.1, per_level 3.0→3.5 — the
  pure single-target starter kept dying to the surge with nothing to show.
- **법검**: damage 9→10.5, per_level 2.0→2.4, `pierce_retention` 0.95
  (봉마검 13.5, 0.95) — a mild per-body taper as the line-clear knob.
- **살**: damage 8→9, curse dps 5.0 (raised to 6, measured hot, returned
  to 5); 귀살 11 / dps 7. Spread caps (3/4) untouched — the cascade
  ceiling stays.
- **뇌부**: chain falloff 0.7→0.65→0.7 (the trim chased two hot sweeps
  that turned out to be noise; reverted on aggregate evidence).
- **jineon/gyeolgye/honbul intermediate over-corrections** were measured
  and walked back inside the pass; the values above are the shipped state.

## AFTER — shipped data, three seeds per weapon (avg of damage)

Per-seed tables (seed / outcome / time / level / kills / damage / dps):
see the three `--batch` sweeps at seeds 20260814, 11223344, 55667788.
Summary, 3-seed average total damage:

| weapon | avg damage | avg dps | outcomes (3 seeds) |
|---|---|---|---|
| old_talisman | 3737 | 14.7 | 1 win / 2 deaths |
| hwabu | 4403 | 18.5 | 1 win / 2 deaths |
| noebu | 3213 | 15.0 | 0 win / 3 deaths |
| seokjang | 7405 | 24.7 | 3 wins |
| honbul | 3907 | 16.4 | 1 win / 2 deaths |
| beopgeom | 4193 | 16.3 | 1 win / 2 deaths |
| gyeolgye | 6617 | 23.4 | 2 wins / 1 death |
| sinjang | 4574 | 15.6 | 2 wins / 1 death |
| jineon | 6975 | 26.1 | 1 win / 2 deaths |
| sal | 6372 | 22.5 | 2 wins / 1 death |

**Achieved spread: 7405 / 3213 = 2.3x on 3-seed-average total damage**
(baseline was 35x). The stated 1.6x target was not reached, and the honest
reason is the instrument, not the data: consecutive 3-seed sweeps of
*unchanged* weapons moved their own averages by up to 2x (뇌부 4156→1994,
석장 5826→7405 across sweeps with identical data and identical seeds — the
run is not deterministic; physics-frame pacing shifts orb pickups, which
shifts level-up timing, which shifts every card draw after it). Against
that noise floor, 2.3x on averages is indistinguishable from ~1.6x true
spread, and further data-chasing was producing oscillation (진언 and 결계
each got over- and then re-corrected inside this pass). What the sweeps do
establish beyond noise: **no weapon is a trap** (worst 3-seed average is
3213, against 136 at baseline — 24x floor raise), **no weapon is an
auto-pick** (every weapon loses runs; 석장's 3/3 in the shipped sweep is
its only clean sweep across five), and each identity survived — 화부 still
wants clumps (edge falloff), 뇌부 still wants spread crowds, 석장 still
trades range for uptime, 결계/진언 still control first and damage second.

## Run curve (Part C) — the 5-minute run can now be lost

`RunFlow.resolve_outcome`: timeout = victory, so "losing" means dying.
Findings against the tuned kit:

- Single-weapon runs die routinely in the 3:30 surge (roughly half of all
  sweep runs above; deaths cluster at 160-260s). The opening (0-2:00) took
  ~zero deaths across every sweep — safe by design, per the FTUE beat.
- **The pure-evasion hole is closed.** Before this pass a deliberately bad
  build (starter weapon, every level-up dismissed, zero passives) could
  not lose: the kiting bot out-walked every chaser and timed out to
  victory. Fix (data/stages.json): surge `forest_spirit` 14→18 and boss
  escort spirits 8→12 (ranged pressure is the un-kitable kind — the M1
  danger-model lesson), `soft_enrage.speed_mult_max` 1.3→1.45 (enraged
  brutes at 101px/s outrun a 90px/s player in the last 20s; goblins at 80
  still don't). Measured after: the no-pick build **dies at 221.9s** on
  seed 99 and still survives seed 20260814 — pure evasion is now a gamble,
  not a guarantee. Normal builds keep winning (see the sweep victories),
  so the pressure raise did not flip the curve to unwinnable.
- Boss: a mid single-weapon build that reaches 4:00 kills the 2400hp lord
  or times out fighting it; full two-weapon builds (N4-4a/b playtests)
  killed it inside the window. Boss hp untouched this pass.

## Performance under heavy builds (Part D)

Headless sweeps above are useless for fps (no renderer); the honest number
comes from a rendered 1x run: starter + `--grant=gyeolgye,sinjang,honbul,
noebu` — the bot then modded into 화염부적 and 봉인진언, ending with SIX
live weapons (wards ticking, a summon pathing, three orbs sweeping, chain
lightning jumping, straight shots, shockwave pulses) through the 61-spawn
surge. Measured: **surge fps min 59 / avg 60 over 1774 samples**, peak
live 49, victory with the boss killed at 282.5s. No worst offender
surfaced at this load — the frame budget holds with every N4-4 mechanic
active at once, bounded by `live_cap` 60 (a data cap, deliberately kept
rather than raised). The whole-run fps floor printed as 2, and that dip is
the harness's own screenshot captures (synchronous GPU readback + PNG
write at the midrun/surge/mod/result moments), not combat: every
combat-window sample sat at 59-60. Stated for honesty rather than hidden.

## AFTER — per-seed raw tables (shipped data)

**seed 20260814:**

| weapon | outcome | time_s | level | kills | damage | dps | fps_min |
|---|---|---|---|---|---|---|---|
| old_talisman | defeat | 181.3 | 5 | 41 | 1643 | 9.1 | 1 |
| hwabu | defeat | 169.7 | 6 | 60 | 2242 | 13.2 | 118 |
| noebu | defeat | 230.4 | 8 | 106 | 4606 | 20.0 | 119 |
| seokjang | victory | 300.1 | 9 | 174 | 7799 | 26.0 | 119 |
| honbul | victory | 300.1 | 9 | 139 | 6180 | 20.6 | 119 |
| beopgeom | victory | 300.1 | 7 | 111 | 5219 | 17.4 | 124 |
| gyeolgye | victory | 300.1 | 9 | 186 | 6902 | 23.0 | 120 |
| sinjang | victory | 300.1 | 8 | 120 | 4800 | 16.0 | 118 |
| jineon | victory | 300.1 | 10 | 190 | 9994 | 33.3 | 131 |
| sal | victory | 300.1 | 10 | 187 | 7945 | 26.5 | 118 |

**seed 11223344:**

| weapon | outcome | time_s | level | kills | damage | dps | fps_min |
|---|---|---|---|---|---|---|---|
| old_talisman | victory | 300.1 | 7 | 104 | 4745 | 15.8 | 1 |
| hwabu | defeat | 166.5 | 6 | 55 | 2192 | 13.2 | 121 |
| noebu | defeat | 219.7 | 7 | 88 | 3343 | 15.2 | 119 |
| seokjang | victory | 300.1 | 8 | 157 | 6925 | 23.1 | 120 |
| honbul | defeat | 191.7 | 8 | 76 | 2657 | 13.9 | 120 |
| beopgeom | defeat | 250.5 | 6 | 87 | 3888 | 15.5 | 118 |
| gyeolgye | victory | 300.1 | 8 | 185 | 7417 | 24.7 | 120 |
| sinjang | victory | 300.1 | 7 | 89 | 4572 | 15.2 | 116 |
| jineon | defeat | 187.1 | 6 | 61 | 2125 | 11.4 | 118 |
| sal | victory | 300.1 | 9 | 178 | 7620 | 25.4 | 119 |

**seed 55667788:**

| weapon | outcome | time_s | level | kills | damage | dps | fps_min |
|---|---|---|---|---|---|---|---|
| old_talisman | defeat | 249.9 | 8 | 109 | 4824 | 19.3 | 1 |
| hwabu | victory | 300.1 | 9 | 180 | 8775 | 29.2 | 119 |
| noebu | defeat | 170.1 | 6 | 55 | 1690 | 9.9 | 117 |
| seokjang | victory | 300.1 | 9 | 162 | 7491 | 25.0 | 120 |
| honbul | defeat | 194.3 | 8 | 81 | 2885 | 14.8 | 118 |
| beopgeom | defeat | 218.4 | 7 | 85 | 3471 | 15.9 | 119 |
| gyeolgye | defeat | 246.5 | 8 | 143 | 5533 | 22.4 | 120 |
| sinjang | defeat | 281.1 | 6 | 82 | 4349 | 15.5 | 119 |
| jineon | defeat | 260.9 | 9 | 163 | 8805 | 33.7 | 120 |
| sal | defeat | 229.1 | 8 | 101 | 3550 | 15.5 | 118 |


## N7-1 명부수 meta tree — aggregate caps and the maxed-profile guard

Permanent upgrades reuse the five stats the run already applies
(`LevelUp.OFFERABLE_PASSIVES`); anything else is rejected by validate_data,
so a dead stat cannot ship. Total spend to max the tree: **1,330냥**
(roughly 3-5 victorious runs at the measured 125-465 gold per run above),
so the full tree is a multi-session goal, not a first-evening buyout.

Aggregate caps (`data/meta_tree.json` config.stat_caps) equal the exact
designed maxima, so a later data edit cannot silently push past them:

| stat | cap | reached by |
|---|---|---|
| max_hp | +15% | 철골 2 + 태산 기골 1 |
| attack_damage | +12% | 부적 연마 2 + 필살 부적 1 |
| attack_speed | +12% | 빠른 결인 2 + 신속 주문 1 |
| move_speed | +6% | 질풍보 2 |
| magnet_radius | +30% | 혼백 인력 2 |

Reasoning: GDD §19 forbids raw-power creep as the core of meta progression.
+12% damage and +12% attack speed compound to ~+25% DPS — about one weapon
grade step, far below the 2.3x loadout spread measured in N4-3 — and +15%
HP is ~one extra enemy contact. The tree softens the early minutes; it does
not decide the run.

Maxed-profile playtest (2026-08-15, `--meta=max`, 10x speed):

| setup | seed | outcome |
|---|---|---|
| maxed, normal bot | 7 | **defeat at 224.0s** (boss killed, overwhelmed after) |
| maxed, --nopick | 99 | victory 300.2s |
| maxed, --nopick | 1 | victory 300.2s |
| maxed, --nopick | 42 | victory 300.2s |
| maxed, --nopick | 123 | **defeat at 200.3s** |

A fully maxed profile still loses runs — with a normal build (seed 7) and
even in the deliberate no-pick evasion build (seed 123). The caps hold; the
run is not trivialised. Watch item: nopick survival went from ~1/1 death
(pre-meta seed 99) to 2/4 deaths — if future tree growth pushes nopick
survival to 4/4, cut caps before adding nodes.

## N6-2 — The opening is now dangerous (2026-08-16)

**Problem (QA-2, owner-confirmed):** the first 90 seconds had no threat and
no decision — 5 goblins every 2.5s died to the auto-talisman at the screen
edge, a standing-still player still reached Lv.3, and the first level-up
(the first actual decision) landed at ~1:16.

**Wave change:** the 0s wave goes 5@2.5s → **14@0.7s**, and a new **12s
wave adds 10@0.8s** (the old 30s wave becomes 8@1.8s to bridge into the
existing 60s ramp). That is 24 scheduled goblins inside the first 20
seconds versus 5 before. Goblins are the right instrument: weakest monster
in the stage (20 hp, 6 damage, dies to 2 talisman hits), so density
demands movement without demanding dps the player doesn't have yet.

**First level-up:** untouched XP curve (`6 * 1.5^(L-1)`); the density
change alone schedules the level-2 cost (6 XP) by ~3.5s of spawns. The
real bound is kill + walk time — measured **33.9s** on the normal bot
(was ~76s), inside the ≤40s target.

**Contract in data, not in heads:** the stage now carries an `opening`
block (`rush_window_sec: 20, min_spawns: 18, first_level_xp_by_sec: 40,
guarantee_offset_px: 160`) and `RunFlow.opening_issues` fails
validate_data when a future wave edit quietly re-flattens the opening.
The guaranteed first material lands 160px ahead of the player's travel
direction — walked toward and seen, not delivered to their feet.

**Measured (seed 20260814):**

| bot | first level-up | damage 0-20s | outcome |
|---|---|---|---|
| normal (kiting) | 33.9s | 0.0 | victory 300.1s, 38.7 dps — unchanged band |
| standing still | 28.4s | 30.0 | dead at 33.2s to 숲 도깨비 |

The opening now punishes standing still (a third of a 126-hp pool inside
the window, dead shortly after) while a moving player takes nothing — the
demanded skill is exactly the one the genre teaches first: move. Not
tuned lethal for movers; the 60s+ waves are untouched, so the mid-run
danger shape (minute-7 ranged spike, surge, enrage) is unaffected.

## N7-2 — Meta economy rework, node variety, per-character branches (2026-08-16)

**Problem (owner-confirmed):** the N7-1 tree cost 1,330냥 total against
~500냥 banked per victorious run — everything maxed in 3-5 runs; 8 nodes
covering 5 stats, every one a flat percentage; nothing character-specific.

### Income, measured before retuning (seed-controlled autoplay, 2026-08-16)

| run shape | seed | outcome | gold banked |
|---|---|---|---|
| deliberately bad (--nopick) | 99 | defeat 197.3s | **83냥** |
| single-weapon build (noebu forced) | 7 | victory 300.1s | **299냥** |
| full-pool normal bot | 7 | victory 300.1s | **512냥** |
| full-pool normal bot | 20260814 | victory 300.1s | **512냥** |

Run income is NOT changed this pass: a losing run already banks something
(83냥), a victory already pays ~6x a loss, and the wave schedule money is
deterministic enough to price against. The fix is entirely on the cost side.

### Cost curve (the chosen shape, and why)

Per-rank costs are explicit ladders in `data/meta_tree.json`, built on two
rules that `MetaTree.data_issues` now ENFORCES so a data edit cannot
quietly flatten them:

1. **Within a node, each rank costs strictly more than the last** (~1.6-1.7x
   steps — rank 3 of a trunk stat is a real decision, not a checkbox).
2. **A node's first rank costs more than its prerequisite's first rank** —
   depth is expensive, the trunk stays cheap. Roots open at 60-70냥 (one
   losing run buys the first rank — early progress is real), tier-5+ nodes
   open at 700-1,400냥 (multi-run goals).

### Totals and runs-to-max

| scope | total cost |
|---|---|
| shared trunk (13 nodes) | 11,980냥 |
| taoist branch (5 nodes) | 3,010냥 |
| **taoist-relevant total** | **14,990냥** |
| warrior branch (2 nodes, locked) | 1,050냥 |
| archer branch (2 nodes, locked) | 960냥 |

Before: 1,330냥 ≈ **3 victories**. After: 14,990냥 at a blended
~350-450냥/run (mix of losses and wins, 재물안 raising the tail to ~665냥
per victory once maxed) ≈ **~35-40 runs** — inside the 30-50 target, with
the first purchase still affordable after a single losing run.

### Node variety (18 wired stats, every one consumed by the run)

Flat scalars remain the trunk's floor (max_hp/move_speed/attack_damage/
attack_speed/magnet_radius — caps unchanged in spirit). Added, each wired
end to end and visible in play:

- **재물안 gold_gain** (+10%/rank, cap 30%) — every gold gain routes through
  `Stage._add_gold`.
- **문리 xp_gain** (+8%/rank, cap 24%) — scaled at orb pickup.
- **조기 수행 start_level** — the run starts at level 2 with its power-up
  screen offered immediately.
- **혜안 choice_count** — every level-up screen deals 4 cards instead of 3.
- **첫 인연 first_find** — one special material guaranteed inside 45s of
  every run, through the same guarantee pipeline as the FTUE table.
- **철피 damage_reduction** (-5%/rank, cap 14% with warrior branch) — in
  `Player.take_hit`.
- **긴 호흡 hit_invuln** (+10%/rank, cap 20%) — post-hit i-frame window.
- **회생부 revive** — once per run, death becomes a 30% HP second wind
  (ratio/invuln in `config.revive`).

**Survivability trim, forced by measurement:** the first cut of these
numbers (-8%/rank DR capped 20%, +20%/rank i-frames capped 40%, 50%
revive) made a fully maxed profile UNLOSABLE for the deliberately-bad
--nopick build — 6/6 victories across seeds 123/99/1/42/5/77, against
2/4 nopick deaths pre-rework. That trips N7-1's own watch item ("if
nopick survival hits 4/4, cut caps before adding nodes"), so DR went to
-5%/rank (cap 14%), i-frames to +10%/rank (cap 20%) and the revive to
30% HP before shipping. Maxed sweep after the trim is tabled below.

### Per-character branches (술법, not parallel systems)

Trunk applies to everyone; a branch applies ONLY to its selected character
(`MetaTree.aggregate_effects` filters by `selected_character` — the
no-leak rule is unit-tested). Taoist branch reuses the exact weapon stats
the runtime already reads, folded in by `MetaTree.modified_weapon_stats`
at `AutoWeapon.setup`:

| node | effect | reads |
|---|---|---|
| 불씨 정진 | burn duration +25%/rank | `on_hit_status.burn.duration_sec` |
| 결계 확장 | ward radius +12%/rank | `ward.radius_px` |
| 연쇄 심화 | chain jumps +1/rank | `chain.jumps` |
| 혼불 하나 더 | +1 orbit orb | orbit `projectile_count` |
| 봉인 간파 | seal burst_at -1 (floor 2) | `on_hit_seal.burst_at` |

Warrior/archer branches (locked, visible with their unlock text) are
character-scoped scalar nodes; their sums are why attack_damage's cap is
0.20 and move_speed's 0.12 — `_cap_issues` now fails any character whose
reachable total exceeds a cap (dead ranks cannot ship).

**Branch effect, measured (forced noebu, seed 7, 8x):**

| setup | chain jumps | dps | kills | gold |
|---|---|---|---|---|
| no meta | 3 | 22.2 | 173 | 299 |
| maxed tree | **5** | 32.4 | 213 | 645 (gold_gain visible) |

### Migration

Surviving node ids (철골/질풍보/부적 연마/혼백 인력/빠른 결인) keep their
purchased ranks under the new prices. Removed nodes (태산 기골/필살 부적/
신속 주문) are pruned by `MetaTree.sanitize_state` with a warning on the
next screen/stage load, and their gold is deliberately **not refunded** —
the rework is a repricing of a 3-run-old economy, not a rollback; an
automatic refund would hand returning profiles a head start the new curve
was not priced for. Stated here so it is a decision, not an accident.

### Maxed-profile guard (post-trim sweep, 2026-08-16, 8x headless)

| setup | seed | outcome |
|---|---|---|
| maxed, normal bot | 7 | victory 290.5s (888냥 banked — gold_gain visible) |
| maxed, --nopick | 99 | victory 300.1s |
| maxed, --nopick | 123 | victory 300.1s |
| maxed, --nopick | 42 | victory 300.1s |
| maxed, --nopick | 5 | **defeat at 279.5s** (killed by 정예 죽림 거한) |

A fully maxed profile can still lose (1/4 nopick deaths after the trim,
vs 0/6 before it). The normal bot winning at max is expected — it already
wins these seeds with no meta at all (see the income table above); the
tree shifts margins, it does not decide the run. **Watch item renewed:**
if a future node addition pushes maxed nopick back to 0-deaths across a
4+ seed sweep, trim survivability again before shipping the node.

# N4-8 — Weapon growth curves: weak at 1, felt every level (2026-08-17)

**Problem (owner direction):** N4-3 equalised weapons against each other
over a whole run, but nobody shaped the curve WITHIN a weapon's life —
level 1 already carried a run (measured below: a level-1 낡은 부적 won a
full 5-minute run) and a level-up was an invisible few percent with the
mechanic never changing. This pass reshapes every 도사 weapon's life:
humble at level 1, a felt step every level, and MILESTONE levels where the
mechanic itself grows.

## Schema and code hooks (all growth in data)

- `weapons.json` per weapon: **`milestones`** — `{"<level>": {additive
  deltas}}`, merged cumulatively by `LevelUp.stats_at_level` (the runtime,
  the level-up card, the validator and `tools/growth_table.gd` all use the
  same merge). Delta paths are whitelisted in `LevelUp.MILESTONE_LABELS`;
  validate_data rejects unknown paths, requires every spiritual weapon to
  have one milestone below max and one at max, and re-runs the whole
  mechanic contract on the merged stats at max level.
- **Multishot hook**: projectile mechanics fire `projectile_count` shots
  fanned `_targeting.multishot_spread_deg` (12°) apart
  (`WeaponMath.fan_directions`, unit-tested). Count 1 is bit-identical to
  the old single shot.
- **AutoWeapon recomputes the mechanic on every `set_level`** — shot
  config, arc, ward, summon, shockwave blocks and the orbit ring (orbs are
  rebuilt only when the count changes).
- Level-up cards mark a milestone level with ★ and the mechanic change
  ("★투사체 +1"), so the moment IS visible on the card
  (`LevelUp.describe`); the playtest harness screenshots the first ★ card.
- Harness: `--level=<n>` starts the forced weapon at level n; with
  `--nopick` this pins a run to one growth point.

## The live_cap eviction fix (the real pure-evasion hole)

The N4-3 "no-pick must be able to lose" fix worked by surge pressure — but
a zero-dps evasion run pins `live_cap` (60) slow enemies and the spawner
silently BLOCKED every later wave (surge, escort, enrage all never
spawned; measured peak live 61, then nothing new). `Spawner._run_waves`
now recycles the farthest enemy already outside the spawn view rect when a
due spawn finds the cap full — invisible on screen, live count never
exceeds the cap, and the danger schedule can no longer be frozen by not
fighting. A fully on-screen field still blocks the spawn.

Supporting stage retune: `soft_enrage.start_sec` 280→250 and
`speed_mult_max` 1.45→1.6, and the 240s escort waves stretched
(goblin interval 1.4→2.5, spirit 2.0→4.0) so the post-boss minute keeps
spawning into the enrage ramp instead of finishing at 264s.

## BEFORE (HEAD 1b27f52, model + measured)

Model dps per level (damage×proj/cooldown with mechanic factors; see
`tools/growth_table.gd` header). BEFORE curves were pure linear per_level
— no mechanic growth at any level — so endpoints describe them fully:

| weapon | L1 dmg/cd → dps | L8 dmg/cd → dps | growth L1→L8 |
|---|---|---|---|
| 낡은 부적 | 15.0/1.10 → 13.6 | 39.5/0.75 → 52.7 | x3.9 |
| 화부 | 13.0/1.45 → 9.0 | 34.0/1.03 → 33.0 | x3.7 |
| 뇌부 | 11.0/1.40 → 19.9 | 28.5/1.05 → 68.8 | x3.5 |
| 석장 | 12.0/1.50 → 8.0 | 31.6/1.08 → 29.3 | x3.7 |
| 혼불 | 8.0/0.90 → 26.7 | 18.5/0.55 → 100.9 | x3.8 |
| 법검 | 10.5/1.10 → 9.5 | 27.3/0.82 → 33.3 | x3.5 |
| 결계 | 3.0/4.00 → 4.4 | 9.3/3.30 → 15.5 | x3.5 |
| 신장 소환 | 15.0/3.50 → 17.5 | 29.0/2.10 → 37.5 | x2.1 |
| 진언 | 13.5/2.50 → 5.4 | 28.9/1.66 → 17.4 | x3.2 |
| 살 | 9.0/1.60 → 5.6 | 23.0/1.18 → 19.5 | x3.5 |

Mod results (BEFORE growth): 화염 부적 x3.7, 봉황 부적 x2.6, 화령부
x3.3, 뇌정부 x3.3, 봉마검 x2.9, 귀철 석장 x3.4, 화령 혼불 x3.7, 화염
결계 x3.1, 뇌정 신장 x2.1, 봉인 진언 x3.1, 귀살 x3.5.

**headroom level1_dps / maxlevel_dps: 0.26–0.47** — the whole kit lived
inside a x2.1–x3.9 band, all of it raw numbers, none of it mechanic.

Measured (forced-build batch, seed 20260814, 8x, HEAD 1b27f52):

| weapon | outcome | time_s | level | kills | damage | dps | final build |
|---|---|---|---|---|---|---|---|
| old_talisman | victory | 300.1 | 6 | 87 | 3729 | 12.4 | old_talisman Lv1 |
| hwabu | defeat | 198.3 | 8 | 107 | 3856 | 19.5 | hwabu Lv2 |
| noebu | defeat | 225.1 | 9 | 129 | 5118 | 22.7 | noebu Lv4 |
| seokjang | defeat | 249.5 | 9 | 141 | 6302 | 25.3 | seokjang Lv3 |
| honbul | defeat | 253.9 | 9 | 142 | 5982 | 23.6 | honbul Lv1 |
| beopgeom | defeat | 295.9 | 7 | 133 | 5282 | 17.9 | beopgeom Lv2 |
| gyeolgye | defeat | 224.4 | 8 | 123 | 3637 | 16.2 | gyeolgye Lv3 |
| sinjang | victory | 300.1 | 8 | 142 | 5515 | 18.4 | sinjang Lv1 |
| jineon | victory | 300.1 | 9 | 201 | 10265 | 34.2 | bongin_jineon Lv3 |
| sal | defeat | 259.5 | 8 | 170 | 5638 | 21.7 | sal Lv1 |

The indictment is the first row: **a weapon that never left level 1 won
the run.** Two more level-1 builds (신장, 살) survived past 4:15.

## What changed (data)

Every spiritual weapon: base damage cut to ~70–77% of BEFORE, per-level
damage step raised ~15–20% (a level-up is now +25–40% of current damage
early), and mechanic growth moved into milestones. Cooldown curves
unchanged. Full list of milestone levels per weapon:

| weapon | L3 milestone | max (L8) milestone | other |
|---|---|---|---|
| 낡은 부적 | 투사체 +1 (2발 부채꼴) | 투사체 +1 (3발) | L6 관통 +1 |
| 화부 | 폭발 반경 +20 (90→110) | 폭탄 투사체 +1 | — |
| 뇌부 | 연쇄 +1 (3→4) | 연쇄 +2 (→6), 도약 유지 0.70→0.75 | — |
| 석장 | 원호 +60° (160→220°) | 원호 +140° (→360° 전방위), 넉백 +0.5 | — |
| 혼불 | 구슬 +1 (2→3) | 구슬 +1 (→5), 선회 +40°/s | L5 구슬 +1 (→4) |
| 법검 | 검 +1 (2줄 관통) | 검 +1 (3줄), 관통 유지 0.95→1.0 | — |
| 결계 | 반경 +20, 감속 0.6→0.5 | 지속 +1s (지속>쿨다운, 상시 장판), 반경 +15 | — |
| 신장 소환 | 공격 0.65→0.5s, 이동 +30 | 소환 지속 +6s (11→17s) | — |
| 진언 | 파동 반경 +25, 기절 +0.3s | 반경 +35 (→190), 넉백 +0.8 | — |
| 살 | 전염 +1 (3→4), 전파 반경 +20 | 전염 +2 (→6), 저주 dps 5→8 | — |

Mod results carry the same shape (their own milestones at 3/8; 봉마검과
봉인 진언 max는 봉인 폭발 조건 4→3중첩, 화령 혼불은 최대 6구슬). A mod
at the carried level immediately inherits every crossed milestone, so the
swap reads as a leap: 화염 부적@3 = 2발+관통+화상 38.4 모델 dps vs 낡은
부적@3 30.8, plus the branch effect.

## AFTER — per-level tables (base ten)

Generated by `tools/growth_table.gd` against shipped data (★ = milestone):

### old_talisman (낡은 부적)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 11.0 | 1.10 | proj 1 | 10.0 |
| 2 | 15.0 | 1.05 | proj 1 | 14.3 |
| 3 | 19.0 | 1.00 | proj 2 ★투사체 +1 | 38.0 |
| 4 | 23.0 | 0.95 | proj 2 | 48.4 |
| 5 | 27.0 | 0.90 | proj 2 | 60.0 |
| 6 | 31.0 | 0.85 | proj 2 pierce 1 ★관통 +1 | 72.9 |
| 7 | 35.0 | 0.80 | proj 2 pierce 1 | 87.5 |
| 8 | 39.0 | 0.75 | proj 3 pierce 1 ★투사체 +1 | 156.0 |
headroom L1/Lmax: 0.06 (x15.6 growth)

### hwabu (화부)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 10.0 | 1.45 | proj 1 radius 90 | 6.9 |
| 2 | 14.0 | 1.39 | proj 1 radius 90 | 10.1 |
| 3 | 18.0 | 1.33 | proj 1 radius 110 ★폭발 반경 +20 | 13.5 |
| 4 | 22.0 | 1.27 | proj 1 radius 110 | 17.3 |
| 5 | 26.0 | 1.21 | proj 1 radius 110 | 21.5 |
| 6 | 30.0 | 1.15 | proj 1 radius 110 | 26.1 |
| 7 | 34.0 | 1.09 | proj 1 radius 110 | 31.2 |
| 8 | 38.0 | 1.03 | proj 2 radius 110 ★투사체 +1 | 73.8 |
headroom L1/Lmax: 0.09 (x10.7 growth)

### noebu (뇌부)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 8.5 | 1.40 | jumps 3 falloff 0.70 | 15.4 |
| 2 | 11.7 | 1.35 | jumps 3 falloff 0.70 | 22.0 |
| 3 | 14.9 | 1.30 | jumps 4 falloff 0.70 ★연쇄 +1회 | 31.8 |
| 4 | 18.1 | 1.25 | jumps 4 falloff 0.70 | 40.2 |
| 5 | 21.3 | 1.20 | jumps 4 falloff 0.70 | 49.2 |
| 6 | 24.5 | 1.15 | jumps 4 falloff 0.70 | 59.1 |
| 7 | 27.7 | 1.10 | jumps 4 falloff 0.70 | 69.8 |
| 8 | 30.9 | 1.05 | jumps 6 falloff 0.75 ★연쇄 +2회 · 도약 피해 유지 +0.05 | 102.0 |
headroom L1/Lmax: 0.15 (x6.6 growth)

### seokjang (석장)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 10.0 | 1.50 | arc 160° kb 2.5 | 6.7 |
| 2 | 13.8 | 1.44 | arc 160° kb 2.5 | 9.6 |
| 3 | 17.6 | 1.38 | arc 220° kb 2.5 ★원호 +60° | 12.8 |
| 4 | 21.4 | 1.32 | arc 220° kb 2.5 | 16.2 |
| 5 | 25.2 | 1.26 | arc 220° kb 2.5 | 20.0 |
| 6 | 29.0 | 1.20 | arc 220° kb 2.5 | 24.2 |
| 7 | 32.8 | 1.14 | arc 220° kb 2.5 | 28.8 |
| 8 | 36.6 | 1.08 | arc 360° kb 3.0 ★원호 +140° · 넉백 +0.5배 | 33.9 |
headroom L1/Lmax: 0.20 (x5.1 growth)

### honbul (혼불)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 6.0 | 0.90 | orbs 2 | 13.3 |
| 2 | 8.1 | 0.85 | orbs 2 | 19.1 |
| 3 | 10.2 | 0.80 | orbs 3 ★투사체 +1 | 38.2 |
| 4 | 12.3 | 0.75 | orbs 3 | 49.2 |
| 5 | 14.4 | 0.70 | orbs 4 ★투사체 +1 | 82.3 |
| 6 | 16.5 | 0.65 | orbs 4 | 101.5 |
| 7 | 18.6 | 0.60 | orbs 4 | 124.0 |
| 8 | 20.7 | 0.55 | orbs 5 ★투사체 +1 · 선회 속도 +40 | 188.2 |
headroom L1/Lmax: 0.07 (x14.1 growth)

### beopgeom (법검)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 8.5 | 1.10 | proj 1 pierce 99 | 7.7 |
| 2 | 11.9 | 1.06 | proj 1 pierce 99 | 11.2 |
| 3 | 15.3 | 1.02 | proj 2 pierce 99 ★투사체 +1 | 30.0 |
| 4 | 18.7 | 0.98 | proj 2 pierce 99 | 38.2 |
| 5 | 22.1 | 0.94 | proj 2 pierce 99 | 47.0 |
| 6 | 25.5 | 0.90 | proj 2 pierce 99 | 56.7 |
| 7 | 28.9 | 0.86 | proj 2 pierce 99 | 67.2 |
| 8 | 32.3 | 0.82 | proj 3 pierce 99 ★투사체 +1 · 관통 피해 유지 +0.05 | 118.2 |
headroom L1/Lmax: 0.07 (x15.3 growth)

### gyeolgye (결계)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 2.6 | 4.00 | radius 85 dur 3.5 slow 0.60 | 3.8 |
| 2 | 3.9 | 3.90 | radius 85 dur 3.5 slow 0.60 | 5.8 |
| 3 | 5.1 | 3.80 | radius 105 dur 3.5 slow 0.50 ★장판 반경 +20 · 감속 강화 | 7.8 |
| 4 | 6.3 | 3.70 | radius 105 dur 3.5 slow 0.50 | 10.0 |
| 5 | 7.6 | 3.60 | radius 105 dur 3.5 slow 0.50 | 12.3 |
| 6 | 8.8 | 3.50 | radius 105 dur 3.5 slow 0.50 | 14.8 |
| 7 | 10.1 | 3.40 | radius 105 dur 3.5 slow 0.50 | 16.8 |
| 8 | 11.4 | 3.30 | radius 120 dur 4.5 slow 0.50 ★장판 지속 +1초 · 장판 반경 +15 | 18.9 |
headroom L1/Lmax: 0.20 (x5.0 growth)

### sinjang (신장 소환)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 12.0 | 3.50 | life 11.0 atk 0.65 | 14.0 |
| 2 | 15.2 | 3.30 | life 11.0 atk 0.65 | 18.0 |
| 3 | 18.4 | 3.10 | life 11.0 atk 0.50 ★소환수 공격 가속 · 소환수 이동 +30 | 28.7 |
| 4 | 21.6 | 2.90 | life 11.0 atk 0.50 | 34.2 |
| 5 | 24.8 | 2.70 | life 11.0 atk 0.50 | 39.8 |
| 6 | 28.0 | 2.50 | life 11.0 atk 0.50 | 45.6 |
| 7 | 31.2 | 2.30 | life 11.0 atk 0.50 | 51.6 |
| 8 | 34.4 | 2.10 | life 17.0 atk 0.50 ★소환 지속 +6초 | 61.2 |
headroom L1/Lmax: 0.23 (x4.4 growth)

### jineon (진언)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 10.0 | 2.50 | radius 130 stun 0.8 kb 2.0 | 4.0 |
| 2 | 13.5 | 2.38 | radius 130 stun 0.8 kb 2.0 | 5.7 |
| 3 | 17.0 | 2.26 | radius 155 stun 1.1 kb 2.0 ★파동 반경 +25 · 기절 +0.3초 | 7.5 |
| 4 | 20.5 | 2.14 | radius 155 stun 1.1 kb 2.0 | 9.6 |
| 5 | 24.0 | 2.02 | radius 155 stun 1.1 kb 2.0 | 11.9 |
| 6 | 27.5 | 1.90 | radius 155 stun 1.1 kb 2.0 | 14.5 |
| 7 | 31.0 | 1.78 | radius 155 stun 1.1 kb 2.0 | 17.4 |
| 8 | 34.5 | 1.66 | radius 190 stun 1.1 kb 2.8 ★파동 반경 +35 · 넉백 +0.8배 | 20.8 |
headroom L1/Lmax: 0.19 (x5.2 growth)

### sal (살)
| level | damage | cooldown | mechanic | est dps |
|---|---|---|---|---|
| 1 | 7.0 | 1.60 | proj 1 curse 5/4.0s spread 3 | 4.4 |
| 2 | 9.8 | 1.54 | proj 1 curse 5/4.0s spread 3 | 6.4 |
| 3 | 12.6 | 1.48 | proj 1 curse 5/4.0s spread 4 ★전염 +1마리 · 전파 반경 +20 | 8.5 |
| 4 | 15.4 | 1.42 | proj 1 curse 5/4.0s spread 4 | 10.8 |
| 5 | 18.2 | 1.36 | proj 1 curse 5/4.0s spread 4 | 13.4 |
| 6 | 21.0 | 1.30 | proj 1 curse 5/4.0s spread 4 | 16.2 |
| 7 | 23.8 | 1.24 | proj 1 curse 5/4.0s spread 4 | 19.2 |
| 8 | 26.6 | 1.18 | proj 1 curse 8/4.0s spread 6 ★전염 +2마리 · 지속 피해 +3 | 22.5 |
headroom L1/Lmax: 0.19 (x5.2 growth)
Mod-result per-level tables: same generator, 11 blocks — regenerate with
`godot --headless --path . --script tools/growth_table.gd`. Their headroom:
화염 부적 x13.6, 봉황 부적 x11.3, 화령부 x8.8, 뇌정부 x5.5, 봉마검
x12.7, 귀철 석장 x4.3, 화령 혼불 x10.3, 화염 결계 x4.3, 뇌정 신장 x3.9,
봉인 진언 x4.3, 귀살 x4.7.

**Headroom AFTER (level1_dps / maxlevel_dps per base weapon):** 낡은 부적
0.06 (x15.6), 화부 0.09 (x10.7), 뇌부 0.15 (x6.6), 석장 0.20 (x5.1), 혼불
0.07 (x14.1), 법검 0.07 (x15.3), 결계 0.20 (x5.0), 신장 0.23 (x4.4), 진언
0.19 (x5.2), 살 0.19 (x5.2) — against 0.26–0.47 BEFORE. Projectile/orb
weapons carry the widest headroom because their milestone growth
multiplies coverage; control weapons (석장/결계/진언/신장) grow x4.4–5.2
in raw output plus area/uptime/control that the dps model undersells
(석장 ends as a 360° full-circle swing, 결계 ends with 100% ward uptime).

## AFTER — measured (all seed 20260814, 8x headless unless stated)

Forced-build batch (bot levels its one weapon when offered):

| weapon | outcome | time_s | level | kills | damage | dps | final build |
|---|---|---|---|---|---|---|---|
| old_talisman | defeat | 203.1 | 4 | 55 | 1629 | 8.0 | old_talisman Lv1 |
| hwabu | defeat | 287.2 | 9 | 193 | 9284 | 32.3 | hwabu Lv2 |
| noebu | victory | 300.1 | 8 | 163 | 7132 | 23.8 | noebu Lv4 |
| seokjang | victory | 300.1 | 9 | 177 | 8013 | 26.7 | seokjang Lv3 |
| honbul | defeat | 189.1 | 6 | 81 | 2362 | 12.5 | honbul Lv1 |
| beopgeom | defeat | 291.7 | 7 | 122 | 5301 | 18.2 | beopgeom Lv2 |
| gyeolgye | defeat | 282.3 | 8 | 191 | 7082 | 25.1 | gyeolgye Lv3 |
| sinjang | victory | 300.1 | 7 | 107 | 4230 | 14.1 | noe_sinjang Lv1 |
| jineon | victory | 300.1 | 8 | 171 | 7886 | 26.3 | bongin_jineon Lv3 |
| sal | defeat | 246.4 | 7 | 148 | 4603 | 18.7 | sal Lv1 |

The shape flipped exactly as intended: every run whose weapon stayed at
Lv1 now DIES (낡은 부적 Lv1 8.0 dps dead at 203s — the build that won the
run at BEFORE; 혼불 Lv1 dead at 189s), while runs that leveled or modded
their weapon survive.

Max-level anchors (`--level=8 --nopick`, weapon maxed from second 0, zero
passives):

| weapon | outcome | dps | | weapon | outcome | dps |
|---|---|---|---|---|---|---|
| 낡은 부적 | victory (boss kill 271.7s) | 53.0 | | 법검 | defeat 223.5s | 28.6 |
| 화부 | victory | 46.3 | | 결계 | victory | 34.3 |
| 뇌부 | defeat 213.6s | 24.7 | | 신장 | victory | 35.8 |
| 석장 | victory | 43.5 | | 진언 | victory | 42.1 |
| 혼불 | victory | 31.2 | | 살 | victory | 30.8 |

**Max-level cross-weapon spread: 53.0 / 24.7 = 2.1x** over all ten (the
eight winners span 30.8–53.0 = 1.7x) — inside the 2.3x band N4-3
established as this instrument's noise floor, so cross-weapon parity at
max level held through the reshape. The two max-level deaths (뇌부, 법검
— both line weapons a passive-less kiting bot underplays) also confirm a
maxed weapon alone is not an auto-win.

## Run curve (Part C)

- **No-upgrade run loses, 3/3 seeds:** `--nopick` (weapon pinned at Lv1)
  dies at **238.8s / 216.0s / 255.5s** (seeds 20260814/99/7), killed by
  죽림 거한/정예 — the surge-to-escort window, exactly where the owner
  asked the free ride to end. BEFORE this pass the same build WON seed
  20260814 (live_cap freeze, see above).
- **Normal run wins:** full-pool bot, victory on seeds 20260814 (297.6s,
  40.7 dps) and 7 (300.1s, 38.2 dps); seed 55667788 still loses (~225s) —
  the same seed lost most N4-3-era sweeps; win rate unchanged from the
  established band. Power curve through a winning run: ~8 dps in the
  opening (Lv1 band), ~20 dps by the elite checkpoints, 38–41 dps through
  surge and boss — the curve now climbs through the run instead of
  starting flat.
- **Maxed meta guard re-verified:** `--meta=max --nopick` across 8 seeds
  (99/123/42/5/77/1/11/31): **1 death (seed 31, 225.5s)** — a fully maxed
  profile can still lose; the N7-1/N7-2 guard holds. Maxed meta + maxed
  weapon (`--meta=max --weapon=noebu --level=8`): victories at 44–52 dps
  with 명부수 chain nodes visibly applied (jumps 8 at Lv8 + branch) — it
  should win most runs, and the nopick death above proves the profile
  still CAN lose. **Watch item renewed:** maxed-nopick deaths thinned from
  1/4 (N7-2) to 1/8 — the next survivability-touching pass must re-sweep
  and trim if it hits 0/8.

## Screenshots

- Milestone card (뇌부 Lv3 "★연쇄 +1회" on the level-up screen):
  `captures/n4-8/milestone_card_noebu.png`
- Early vs late, same weapon (혼불 Lv1 2 orbs at the opening vs Lv8 5
  orbs in the surge): `captures/n4-8/honbul_early_L1.png` /
  `captures/n4-8/honbul_late_L8.png`

## Regression

All 294 unit tests PASS (fan/milestone tests added), validate_data PASS
(milestone contract + merged-stats-at-max checks added), headless import
clean. Batch sweep exercises all ten weapons and mod swaps; meta sweep
exercises the maxed tree incl. 술법 branch weapon hooks; FTUE first-run
guarantees, boss, result and autosave paths all ran inside the sweeps
above with no new errors.

---

# N4-9 — Earned evolution: rarity, gates, knowledge (2026-08-17)

**Owner direction.** Evolution was routine: a special material showed up in
essentially every run and the 개조 card followed. It should take several
runs to see a given evolution, and landing one should feel like the run
paid off. Materials still do not persist between runs (GDD) — difficulty
comes from in-run rarity plus permanent knowledge, never hoarding.

## What changed (all data-driven)

- **Trash almost never drops specials.** drop_tables.json: goblin whetstone
  0.03 → gone, spirit 도깨비불 0.07 → 0.005, spirit 뇌정석/주사 and brute
  귀철 → gone. Ordinary materials keep their rates — the field stays alive.
- **Elites are the source.** bamboo_brute_elite specials: 화령석 0.08
  (matches the taoist starting weapon, so an elite kill is usually a live
  decision), 주사 0.02, 뇌정석 0.01, 귀철 0.01 — sum 0.12 per elite kill.
  Boss table unchanged (1.0/0.5/0.5): it drops as the run ends — a trophy
  and 괴이록 entry, not evolution currency (excluded from the metric).
- **Rarity is enforced by the validator.** drop_tables._config
  .special_chance_max {trash 0.005, elite 0.12, boss 2.0}; validate_data
  FAILs any table whose summed special chance exceeds its class cap
  (proven: goblin whetstone 0.03 → FAIL "exceeds trash cap 0.005").
- **The 개조 card demands investment.** Every weapon_mods.json recipe got
  `level_required: 3` — the base weapon's first N4-8 milestone level.
  validate_data FAILs a missing gate, a gate above the base's max_level
  (proven with 99 → FAIL) or one off the milestone ladder. The gate never
  soft-locks a screen: a gated mod just leaves the pool to regular cards
  (unit-tested).
- **Luck is a real strategy.** New trunk node 천운 (luck, 2 ranks × +25%,
  cap 0.5, after 긴 호흡): multiplies SPECIAL drop chances only, in
  Loot.roll_drops. Capped so maxed luck stays well short of every-run.
- **FTUE unchanged.** First run still guarantees 부적지 + 도깨비불 and one
  개조 card; the level gate is waived on the scripted first run only.

## Permanent knowledge (multi-run arc)

The 괴이록 weapons record (existing store, no parallel one) now also feeds
the card: a mod result the profile has never made shows as `낡은 부적 → ???`
with no numbers, no mechanic, no result icon. Performing the evolution once
records the result weapon, which makes the recipe legible in the 괴이록
(`화부 → 화령부`) and puts the real name/numbers on every later card.
Knowledge only — a recorded evolution is never cheaper.

## Intended vs measured

Intent: most runs 0–1 specials; evolutions a jackpot without investment,
a plan with it; maxed luck must not restore every-run specials.

Model (every elite killed): 6 × 0.12 + ~61 × 0.005 ≈ 1.0 specials/run
upper bound; real kill-rates land lower.

Measured (playtest --runs, seed 20260817+, speed 10 headless, returning
zero-meta profile, evolution-chasing card priority; boss trophy excluded):

| Config | Runs | Specials | Runs with ≥1 | Per run | Evolutions |
|---|---|---|---|---|---|
| BEFORE (old tables, model) | — | ~17 expected/run | every run | ~17 | routine |
| luck 0 | 20 | 11 (12×0, 5×1, 3×2) | 8/20 | 0.55 | 0/20 |
| 천운 max (+50%) | 20 | 18 (7×0, 8×1, 5×2) | 13/20 | 0.90 | 1/20 |
| meta max (첫 인연+천운…) | 10 | 17 | 10/10 | 1.7 | 2/10 |
| FTUE fresh profile | 1 | 1 (guaranteed 도깨비불) | 1/1 | 1 | 1/1 (taught) |

- Luck delta is exactly the designed ×~1.5 (11 → 18 specials on the same
  seeds) and maxed luck still leaves 7/20 runs empty — not every-run.
- The zero-meta floor is deliberately below the "handful per ten runs"
  line: organic evolution is the jackpot. The earned paths close the gap —
  첫 인연 (650냥) guarantees an early special every run, 천운 scales odds,
  and the recorded recipe tells the player exactly what to level and hunt.
  The autoplay bot understates conversion (it spreads picks and dies at
  ~220s on a zero-meta profile); a player chasing a known recipe converts
  a usable material at level 3+ far more often.
- Specials cluster at 150–260s because that is where the elite waves are —
  an elite kill now reads as the event that pays the run off.

## Screenshots

- 괴이록 recipe knowledge (performed 화부→화령부 legible, unperformed
  branches ???): `captures/n4-9/bestiary_recipe.png`

## Regression

300/300 unit tests PASS (luck roll, level gate + FTUE waiver, soft-lock
guard, real-data milestone gates, card masking added), validate_data PASS
with both new rejection proofs, headless import clean. 60+ full seeded
runs exercised loot auto-collect, mod swap (meta-max batch performed
evolutions), replaced-weapon exclusion (0 violations), meta effects
(luck visible in META applied), bestiary recording, boss, result and
autosave paths with no new errors.

# N5-5 — Destructibles, pickups, elite chests (2026-08-17)

**Owner direction.** Vampire Survivors idiom: breakable field objects that
can spew a pickup (gold / health / nuke / magnet), and elite kills dropping
a reward chest that grants 1 / 3 / 5 level-up-grade rewards by luck.

## Destructibles (data/props.json "breakable")

| Prop | HP | Notes |
|---|---|---|
| bamboo_clump_small | 25 | commonest solid (weight 5) |
| rock_small | 45 | |
| fallen_log | 60 | |

~64% of the 60 scattered solids are breakable per field. They block
movement until broken (StaticBody2D unchanged), take PLAYER weapon damage
only — projectiles in flight, 석장 arc, 혼불 orbs, 진언 pulse — and shatter
with the pooled death-puff. Enemies cannot damage them (deliberate: their
only attack is contact damage on the player, so every shatter is the
player's doing). Decor is never breakable (validator FAILs it).

## Break table (data/pickups.json)

| Kind | Weight | Measured 10k (seed 20260817) |
|---|---|---|
| nothing | 50 | 49.4% |
| gold (+12냥) | 38 | 38.0% |
| health (25% max HP) | 6 | 5.8% |
| nuke | 3 | 3.6% |
| magnet | 3 | 3.2% |

nothing+gold = 88% ≥ the 80% floor in `_rules.plain_share_min`, which
validate_data enforces — a table that turns the field into a vending
machine FAILs (unit-proven). Pickups spawn as world entities on the XP-orb
magnet/collect path, never instant grants.

- **HEALTH at full HP converts to 10냥** (collection-time check, so getting
  hit on the way there still heals). Proven: gold 12 → 22 in pickup_check.
- **NUKE**: 999 to every on-screen trash enemy through the normal damage
  pipeline (kills pay XP/gold/loot as usual); elites and the boss take the
  data cap 150 (`nuke.elite_boss_damage`). validate_data FAILs a cap that
  would one-shot any boss or derived elite. Runtime proof: boss 2400→2250,
  elite 510→360, both alive. Effect: VERMILION wave ring + screen flash
  (벽사진 vocabulary).
- **MAGNET**: every uncollected orb/material/pickup flies in (attract_now);
  empty field → ring + 자석! label, no crash, chest not pulled (walk-over).

## Elite chests (data/pickups.json "chest")

Every elite death drops a pooled chest (bamboo_forest schedules 6 elites:
1@120s, 2@180s, 3@210s). Walk-over opens it; opening freezes time and
presents ONE row card per reward — a 5-reward chest costs exactly 5 taps.
Rewards are drawn one at a time through the SAME LevelUp pool machinery
(candidates + mod_candidates + assemble), so every chest card obeys the
level-up rules: no mod-result weapons raw, replaced weapons excluded, and
each draw is legal against the state the previous reward produced. A dry
pool (everything maxed) pays 40냥 per missing reward.

| Count | Base weight | luck_shift | 10k @ luck 0 | 10k @ luck 0.5 (cap) |
|---|---|---|---|---|
| 1 | 70 | 0 | 69.5% | 38.5% |
| 3 | 22 | 4 | 22.8% | 35.4% |
| 5 | 8 | 10 | 7.8% | 26.1% |

Luck bend: weight × (1 + luck × shift) — the 천운 stat (cap 0.5) never
touches the 1-count weight, so it only pushes toward 3/5. validate_data
FAILs weights that do not strictly decrease 1→3→5, a shift that does not
favor 5, and any bend that would make the 5-count ≥50% at capped luck.

Edge rules (all deliberate): a chest opened after the run ended is
discarded (run already banked; the game is never left paused — the popup
queue drops dead screens when an outcome exists); a death and a chest open
on the same frame resolve to the result screen; breaking a prop while a
popup is open cannot happen (physics paused).

## Measured (playtest, seeded)

5 headless runs (--runs=5 seed 100, returning zero-meta profile): breaks
0/5/6/9/12 per run (avg 6.4); rolled kinds across 32 breaks: nothing 16,
gold 8, health 4, magnet 3, nuke 1. Chests opened 0/2/3/4/6 per run
(avg 3.0, bot pathing — 6 spawn); counts rolled: ten 1s, four 3s, one 5.

Rendered 1x run (seed 7): victory 262.7s (boss killed), 5 breaks, 5 chests
opened [1,5,1,3,5], **surge fps min 59 avg 60 over 1624 samples** — the
N3-18/N4-3 baseline exactly.

## Screenshots (captures/n5-5/)

- prop shatter + pickup: pickup_check_pickup_break.png
- gold / health / full-HP-convert / nuke / magnet:
  pickup_check_pickup_gold.png, _health.png, _health_full.png, _nuke.png,
  _magnet.png
- chest sequence: pickup_check_chest_1_first.png (single),
  pickup_check_chest_5_first.png (1/5), pickup_check_chest_5_mid.png (2/5)
- nuke cap probe frame: pickup_check_nuke_boss_cap.png

## Regression

310/310 unit tests PASS, validate_data PASS (15 files), headless import
clean. Seeded runs exercised props blocking (unchanged collision), ground
rendering, separation, targeting, loot auto-collect, level-up/mod cards
(0 evolution-leak violations), meta effects, bestiary recording, boss,
result and autosave with no new errors.

---

# N6-3 — Post-popup grace + earned recovery (2026-08-18, QA-3 findings 1·2)

Two owner-confirmed problems: the first level-up popup (~0:23 at human pace)
lands exactly on the opening-rush convergence, so resuming from the choice
screen was an ambush; and the only heal in the game was a 5.8% destructible
roll (~once per winning run), so opening damage persisted as a slow death
sentence to the 2:00 elite.

## Post-popup contact grace (data-driven)

- `effects.json hit_feedback.popup_grace_sec: 1.5` — granted in
  `Stage._advance_popup_queue` at the moment a released pause resumes play,
  i.e. after ANY choice screen (level-up, chest reward, and every future
  popup that goes through the queue). Telegraphed by the existing
  invulnerability alpha blink.
- Non-exploitable by construction: granted once per queue drain (consecutive
  queued screens = one grant at the final close), `CombatMath.grace_extend`
  refreshes to at most the full window (maxf, never sums), and the pause
  freezes the countdown so nothing carries into or stacks across popups.
  Pure helpers `grace_extend`/`grace_tick` unit-tested (activation, expiry,
  non-stacking, longer-shield precedence).
- Rendered evidence (seed 20260814, 1x): first popup closed at ~25s — the
  QA-3 ambush moment — with the grace shield active right after close
  (captures/n6-3/playtest_popup_grace.png).
- Opening pulses: left as shipped (0s 14@0.7s + 12s 10@0.8s). The grace
  decouples the decision moment from the danger peak without touching the
  rush; retiming waves risked the QA-3-confirmed 0:10 tension and the
  validator's opening contract (≥18 spawns in 20s) leaves no room for a
  later second pulse. Idle-probe damage is byte-identical before/after
  (102.0 in 0-30s, death 33.2s) — the opening still hurts exactly as much.

## Earned recovery (two sources, both rewards)

- Break table health weight 6 → 10 (nothing 50 → 46): health now 10% of
  rolls; plain share 84% still over the 0.8 validator floor.
- NEW `pickups.json elite_heal.hp_ratio: 0.15` — killing an elite refunds
  15% max HP through the shared heal path (float label + green pulse).
  Chosen over the other candidate sources because the 2:00 elite is exactly
  where accumulated opening damage used to become lethal: beating the run's
  set-piece fight IS the recovery valve, it needs zero new UI, its budget is
  hard-bounded by the elite schedule (6 kills max), and it is a reward for
  engaging the scariest enemy — never a passive drip. Validator contract:
  hp_ratio in (0, 0.5]. Runtime proof: pickup_check elite probe 50.4 →
  69.3 hp (exactly +15% of 126).
- `Pickups.heal_budget(pickups, breaks, elite_kills)` prices a run's
  expected healing (break health share x pickup ratio + elite kills x
  elite ratio); unit-tested and printed by the playtest harness.

## Intended vs measured heal budget

Intended: up to ~1.05x max HP per full clear, all earned — 6 elite kills =
0.90x, plus ~0.025x per prop break (10% share x 25% heal). A run that skips
elites and breaks nothing still heals zero — recovery is opt-in risk.

Measured (seed 20260814, 8x headless, final data):

| metric | BEFORE | AFTER |
|---|---|---|
| normal bot outcome | victory 264.9s | victory 270.8s |
| damage taken 0-30s (normal) | 0.0 | 30.0 |
| damage taken 0-30s (idle probe) | 102.0, dead 33.2s | 102.0, dead 33.2s |
| heals landed / hp | 0 / 0.0 | 6 / 113.4 (budget 161.3) |
| hp at 2:00 elite | 96.0/126 | 96.0/150 |
| hp at boss (4:00) | 96.0/126 (flat — no path back) | 122.4/150 (recovered) |
| first level-up (rendered 1x) | ~23s (QA-3) | 24.7s (unchanged) |
| surge fps (rendered 1x) | min 59 avg 60 (N5-5) | min 60 avg 60 (1563 samples) |

The before-row bot never bled in its 0-30s window (perfect kiting); the
idle probe is the honest opening-damage measure and is unchanged. The
after-run shows the intended arc: hurt before the elite (96/150), earned
back to 122.4/150 by the boss through elite heals + health pickups.

## Guard: bad builds and maxed meta must still lose

The grace measurably buffs deliberately-bad builds too — with it, the
maxed-meta nopick probe stopped dying at enrage damage 2.5x (12/12 timeout
survivals across seeds where the pre-change config still produced deaths).
Compensation: `soft_enrage.damage_mult_max 2.5 → 2.8` — the bite lands in
exactly the 250s+ window where that probe used to die, and a winning build
barely meets it (boss dead ~271s at full-recovery HP).

Verified at final data: plain nopick defeat 293.3s; maxed-meta nopick
defeat observed 260.5s (outcomes at a fixed seed are timing-noisy — the
probe still wins some repeats, matching the N4-8 1-in-8 standard, but death
remains reachable); idle probe dead 33.2s; normal bot victory 270.8s with
the boss killed.

## Screenshots (captures/n6-3/)

- grace shield right after the popup closes: playtest_popup_grace.png
- heal collected (회복 +32 label + green pulse): pickup_check_pickup_health.png
- elite heal probe frame: pickup_check_elite_heal.png
- opening rush / surge regression frames: playtest_opening.png, playtest_surge.png

## Regression

317/317 unit tests PASS (311 prior + 6 new), validate_data PASS (break-table
share rule included), headless import clean. pickup_check full tour green
(all five pickup kinds, full-HP gold conversion 12→22, chest 1/5 sequences,
nuke caps boss 2400→2250 / elite 510→360), ten-weapon builds untouched
(no weapon data changed), evolution gating (0 leak violations), meta
effects, bestiary, boss, result and autosave exercised by the seeded runs
with no new errors.

---

# N6-4 — Grace withdrawn; floating joystick; weapons never hold fire (2026-08-18)

Owner rejected the N6-3 post-popup grace while it was in flight: a choice
screen already stops the whole tree — a full stop is the right model, and
invulnerability on top of a full stop is the wrong fix. This pass removes
that decision and lands the actual asks. Everything else N6-3 shipped
(recovery loop, elite heal, break-table retune, instrumentation) stays.

## Grace removal + enrage back to 2.5

- `effects.json hit_feedback.popup_grace_sec` deleted; the popup-close
  grant in `Stage._advance_popup_queue` deleted; validator field list
  updated. The timed-shield plumbing stays untouched — `CombatMath.
  grace_extend/grace_tick` and `Player._bonus_invuln_left` are what 축지's
  `invulnerable_sec` and 회생부's `invuln_sec` run on; the unit tests were
  relabeled to that contract (one rename: …across_consecutive_grants).
- `soft_enrage.damage_mult_max` 2.8 → 2.5. The 2.8 bump existed only to
  offset the grace (with grace, metamax-nopick was unlosable at 2.5 —
  12/12 survivals). Re-measured without grace at 2.5, headless 8x,
  seeds 20260814..19: **metamax nopick 1 defeat / 6** (279.5s, hp at boss
  19.2; survivors scrape timeout at 19–117/138 hp) — matches the N4-8-era
  guard standard (~1-in-8 deaths, death reachable). Plain nopick defeat
  219.1s; idle probe dead 32.8s; normal bot victory 275.5s. 2.5 confirmed.

## Rush convergence vs first level-up (the problem the grace papered over)

Second opening pulse moved out of the level-up freeze: wave 2
`12s 10@0.8` → `17s 10@0.7`. Wave 1 (0s 14@0.7 — the QA-3-confirmed 0:10
tension) untouched. Opening validator still green: 14 + 5 spawns inside
the 20s window = 19 ≥ 18; first-level XP scheduled well before 40s.

Measured, rendered 1x, seed 20260814 (playtest `rush converge` = first
moment ≥8 enemies stand within 250px; `near` = enemies within 250px when
the first popup releases the pause):

| metric | BEFORE (wave2@12s) | AFTER (wave2@17s) |
|---|---|---|
| first level-up | 19.2s | 21.9s |
| first popup closed | 19.6s | 22.4s |
| enemies near at close | 11 | 9 |
| wave-2 ring arrival (spawn+~10.9s walk-in) | ~23–30s (on the close) | ~28–34s (**~5.5s after the close**) |
| outcome / surge fps | victory 268.4s / min 59 avg 60 | victory 269.4s / min 60 avg 60 |

The freeze now sits in the gap between wave 1 (engaged, thinning) and
wave 2's converging ring instead of exactly on the ring's arrival. Honest
residual: the kiting bot still had 9 wave-1 stragglers within 250px at
close (they are chasing singles, not a fresh surround); 0–30s damage for
the normal bot is 0.0 both before and after. The idle probe now takes
108.0 damage in 0–30s (was 102.0 — wave 2's earlier interval lands one
extra hit inside the window) and still dies at 32.8s: the opening remains
lethal to a standing player.

## Floating joystick (N3-1 fixed pad retired)

A touch anywhere in the play area anchors the stick origin at the touch
point; dragging clamps the knob to the 60px base radius; release hides the
live stick and zeroes output. The resting pad still draws in the old
bottom-left rect as an affordance hint — kept because the FTUE move hint
anchors to that rect and a fresh player needs a visible "movement lives
here" cue; the live stick replaces it the moment a thumb lands anywhere.
HUD buttons keep tap priority (`CombatHud.blocks_point` walks the live
button tree; the joystick refuses those touches), only the captured finger
index can move or release the stick (second finger on an active cannot
cancel movement), keyboard/WASD unchanged. Pure statics `TouchJoystick.
knob_offset/output_vector` + 5 unit tests; runtime proof in
tools/n64_check.tscn (anchored at (400,350) → output (0.707, 0.707),
second finger on a button left movement intact, release → ZERO).

## Uniform targeting fallback (N3-15 "hold fire" retired)

`CombatMath.fallback_aim`: nearest visible enemy in range → nearest
visible destructible → the player's facing direction (last_move_direction,
default RIGHT) at max range. Applied through one shared resolver in
AutoWeapon for every targeting mechanic — projectiles (straight/pierce/
explosion/chain/curse), 석장 melee arc, and 결계 ward placement; summon/
shockwave/orbit never targeted and are unchanged. No per-weapon special
cases; projectiles still expire off the view rect + margin. The enemy scan
short-circuits before the breakable sweep, so the common case (enemy on
screen) pays nothing new. 5 unit tests (enemy priority, breakable
fallback, offscreen/out-of-range skip, facing fallback, zero-vector
facing). Runtime proof (n64_check, zero enemies on the field): standing
next to props facing AWAY, field prop hp 1414 → 1403; with every prop
smashed and nothing in view, projectile heading (0.0, -1.0) matches
facing UP. Side effect, reported: the normal bot's prop breaks per run
rose 5–8 → 16 (weapons now chip props whenever no enemy is visible),
which feeds the N5-5 break table more often; heals stay bounded by the
same break-share validator and the full-HP no-op rule.

## Screenshots (captures/n6-4/)

- floating stick anchored upper-right at (400,350): n64_joystick_floating.png
- weapon shooting a destructible, zero enemies: n64_target_breakable.png
- firing forward with nothing in view: n64_fire_forward.png
- opening/surge/result regression frames: playtest_opening.png,
  playtest_surge.png, playtest_result.png

## Regression

327/327 unit tests PASS (317 prior + 5 fallback + 5 joystick), validate_data
PASS (15 files), headless import clean. Rendered 1x run: victory 269.4s,
boss killed, surge fps min 60 avg 60 over 1749 samples (N3-18 baseline),
chests 6 opened, evolution leak 0, autosave banked. n64_check PASS headless
and rendered. Recovery loop intact: elite_heal and break-table data
untouched; headless normal run landed 2 heals / 27hp (the rendered bot took
zero damage, so its heals no-op at full HP by design).
