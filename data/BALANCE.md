# M1 Balance Notes — Bamboo Forest (10 min / 600s)

**Re-derived against the real formulas landed in `scripts/core/run_state.gd`
(commit 367da99 / 071776a).** The original version of this document assumed a
guessed arithmetic XP curve and a "player dumps half their picks into the
starting weapon" model. Both were wrong. This version reads `run_state.gd`
directly and derives the curve from it.

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
- Crit multiplier and how `crit_chance` actually resolves in combat — not
  landed (`scripts/combat/**` doesn't exist yet in this worktree's view).
- Evolution trigger timing. `GameData.evolution_for()` is implemented and
  correctly checks `weapon_level`/`passive_stacks` thresholds against
  `evolutions.json`, but nothing in `run_state.gd` calls it — no code path
  swaps a weapon on reaching threshold or emits `weapon_evolved`. Evolution
  is a working *query*, not yet a wired *effect*. The DPS model below assumes
  no evolution bonus is live yet; once combat wires it, endgame DPS should be
  treated as a floor, not a ceiling.

## Data change made in this pass

`forest_goblin.xp_drop`: **3 → 1**. This is the single lever pulled to fix
the front-loading described above — goblins dominate the spawn count in
minutes 1-3, so their XP is what was pushing the curve two levels ahead of
design intent. Spirit (5) and brute (8) xp_drop are untouched.

`bamboo_brute.hp`: **60 → 85**, and `bamboo_spirit_lord.hp`: **7000 → 4000**.
Both are pressure-side corrections, explained below — the real pick-pool DPS
model runs meaningfully higher late-game than the original guess did (more
weapons owned beats one deeply-leveled weapon), so trash and boss HP needed
to come up/down respectively to keep the intended danger shape and boss
fight length.

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

## Expected DPS vs. enemy pressure by minute (re-derived)

DPS model: `owned_weapons × (old_talisman_damage(avg_level) /
old_talisman_cooldown(avg_level)) × (1 + 0.06×avg_stacks) × (1 +
0.08×avg_stacks)` — using `old_talisman`'s own per-level curve as a stand-in
"average weapon" (the 7 weapons differ in specifics but are close enough in
order of magnitude for this estimate), and applying the average
passive-stack count to both `attack_damage` and `attack_speed` multipliers
(a simplification — see guesses above). Pressure uses the unchanged wave
table with `bamboo_brute.hp` at its new value of 85.

| Minute | DPS | Incoming HP | HP/s | Margin | Note |
|---|---|---|---|---|---|
| 1 | 18.5 | 280 | 4.67 | 3.97x | goblins only |
| 2 | 22.7 | 200 | 3.33 | 6.80x | still comfortable |
| 3 | 34.4 | 336 | 5.60 | 6.15x | forest_spirit introduced |
| 4 | 41.9 | 128 | 2.13 | 19.65x | intentional lull |
| 5 | 45.6 | 408 | 6.80 | 6.70x | density climbing |
| 6 | 49.2 | 340 | 5.67 | 8.68x | bamboo_brute introduced (85 hp) — again a burst-damage/reaction threat, not a DPS one |
| 7 | 52.3 | 905 | 15.08 | 3.47x | **first real danger minute** — sharpest margin drop so far |
| 8 | 54.0 | 552 | 9.20 | 5.87x | margin recovers |
| 9 | 55.8 | 1080 | 18.00 | 3.10x | **second danger minute** |
| 10 | 57.6 | 1554 | 25.90 | 2.22x | **tightest margin of the run**, by design, right before the boss |

The overall margin curve sits higher than the original arithmetic-curve
design (which targeted ~1.8-2.6x at the danger minutes) — this is the real,
derived consequence of the pool math rewarding weapon breadth: 4 weapons at
low level collectively out-DPS the single maxed weapon the original design
assumed. Rather than fight that with further HP inflation (which starts to
feel like padding trash HP to compensate for a mechanic this worktree
doesn't own), the shape — comfortable early, tightening at 7/9/10, boss last
— is preserved and considered acceptable; the exact numeric margin is less
important than the shape once real combat resolution (crit, evolution) is
live and can be re-measured.

## Boss

`bamboo_spirit_lord.hp` dropped 7000 → 4000. At minute-10 baseline DPS (57.6,
no crit/evolution bonus, since neither is wired yet) that's a 69s
time-to-kill; once crit_chance and weapon evolution land in combat, expect
DPS to rise and TTK to fall into roughly the 45-60s range this fight is
designed for. `bamboo_spirit_lord.damage` (35/hit) against a Taoist with
`base_hp: 100` plus whatever `max_hp` stacks were picked (likely 0-1 stacks
given the passive dilution above) still means the fight has to be won by
kiting, not tanking, per the GDD's movement-only combat model.

## Where the run should feel dangerous (unchanged intent, re-verified)

1. **Minute 6** — `bamboo_brute`'s introduction. Margin is still generous
   (8.68x); the danger is reactive (18 dmg / 70 spd charge), not a DPS
   problem, same as originally designed.
2. **Minute 7** — first minute all three trash types overlap. Margin drops
   from 8.68x to 3.47x, the sharpest relative drop in the run.
3. **Minute 9-10** — sustained pressure into the boss, margin bottoming out
   at 2.22x at minute 10, directly into a 4000 hp / 35 dmg boss.

Minutes 1-5 stay above ~4x margin (with an extreme 19.65x lull at minute 4)
— consistent with the GDD's "learn the loop" framing for the first half of a
10-15 minute session.
