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

**Five more playthroughs against that retune (this pass).** It worked on
every axis it targeted: win rate 0/5 → 3/5, any evolution 1/5 → 4/5, and the
full `old_talisman` → `fire_talisman` → `phoenix_talisman` chain fired in
3/5 (core-engine's evolved-weapon-level tracking fix, landed since the last
pass, is what made that chain reachable at all). The 39.6 dps model was
vindicated precisely: the one run that never evolved measured 41 dps on the
boss hp curve — 1% off the model, not a lucky number. **What it exposed:**
boss TTK is now 12.2-14.4s against the 55s target, undershooting in the
*opposite* direction from before. Root cause isn't the hp value — it's that
`phoenix_talisman` quadruples single-target dps (~41 unevolved → ~160
evolved) at the *same point in the same run*, so 2150 hp is simultaneously a
13s fight when phoenix is present and unwinnable when it isn't. No single
hp number satisfies both branches; both of this pass's two remaining losses
were runs without phoenix. **This pass narrows the spread instead of
picking a number** — see "Loadout spread" below.

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

**This pass, against five more real playthroughs of the above:**
- `phoenix_talisman`: `damage` 30.0→25.0, `cooldown_sec` 0.9→0.95,
  `projectile_count` 2→1, `per_level.damage` 6.0→5.0. The loadout-spread
  fix — see "Loadout spread".
- `bamboo_spirit_lord.hp`: **2150 → 3150**. Re-sized for the middle of the
  narrowed evolved/unevolved dps band, not re-derived from a single
  measurement — see "Loadout spread".

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

## Boss

`bamboo_spirit_lord.hp`: **2150 → 3150.** Sized for the *middle* of the
narrowed band rather than re-derived from either endpoint, per instruction.
Using the geometric mean of the two branches (appropriate here because
time-to-kill is a *ratio* — dps × time — so centering the *ratio* of the two
branches' TTKs, not their raw hp difference, is what actually splits the
difference fairly): `sqrt(41 × 79) ≈ 56.9` dps at the target midpoint,
`56.9 × 55 ≈ 3130`, rounded to **3150**. Resulting time-to-kill: **~76.8s**
on the unevolved branch (3150 / 41), **~39.9s** on the evolved branch
(3150 / 79) — both within shouting distance of the 45-70s design window
(unevolved runs a bit long, evolved runs a bit short) rather than the
previous 13s/204s chasm, and importantly: **no run is now unwinnable or a
trivial stomp purely because of whether one specific evolution completed.**

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

**Known external caveat, not compensated for in data:** core-engine's
evolved-weapon-level tracking bug (see "Boss" above) means a weapon that has
evolved once currently can't be read at its correct level for a *second*
evolution — this specifically blocks the `fire_talisman` → `phoenix_talisman`
step (evolving twice in the same weapon line) regardless of these
thresholds. `sword` → `twin_sword`, `bow` → `divine_bow`, and
`old_talisman` → `fire_talisman` (each a single evolution) are unaffected.

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
