# M1 Balance Notes — Bamboo Forest (10 min / 600s)

This is the reasoning behind the numbers in `characters.json`, `weapons.json`,
`passives.json`, `evolutions.json`, `monsters.json`, and `stages.json`. Everything
below is derived **forward** from the actual `waves` array and `xp_drop`/`hp` values
committed in this worktree — not backfitted after picking a "nice" curve.

## What's guessed vs. what's derived

`content-data` does not own the leveling formula, weapon-slot count, or combat
resolution (crit multiplier, passive stacking application, evolution trigger timing) —
those live in `core-engine`/`combat`. To reason about balance anyway, this document
states explicit assumptions and flags every one. If any of these turn out wrong once
combat is implemented, the numbers below (spawn density, monster HP, boss HP) are the
first things to revisit — the *shape* of the curve (escalate → dip → escalate harder →
boss) should hold regardless.

**Guessed (not in any schema, invented for this analysis):**
- XP-to-next-level formula: `xp_to_next(L) = 8 + 4*(L-1)`. Standard-shape arithmetic
  ramp for this genre; no such formula exists in code yet.
- Weapon slot count: assumed ~4 concurrent weapons by late game (Vampire-Survivors-
  style loadout). Not specified anywhere.
- Passive uptake: assumed players pick up 3-5 stacks of their 1-2 favored passives by
  minute 8-10, not all 8 evenly.
- Multi-weapon + passive DPS multiplier (~2.5-3x over single-weapon baseline) applied
  qualitatively in the late-game estimate — this is the least rigorous number here.
- Kill rate = spawn rate (player DPS assumed to always outpace incoming spawns, so XP
  income is spawn-bound, not DPS-bound, except explicitly noted danger minutes).

**Derived (from committed data, arithmetic only):**
- Cumulative XP by minute (from `stages.json` waves × `monsters.json` xp_drop).
- Implied level by minute (cumulative XP against the guessed formula above).
- Incoming HP pressure by minute (from waves × monster hp).
- Single-weapon baseline DPS by minute (from `weapons.json` old_talisman base +
  per_level, at an assumed weapon level derived from implied player level).

## XP curve → implied player level by minute

| Minute | New XP this min | Cumulative XP | Implied level |
|---|---|---|---|
| 1 | 42 | 42 | 4 |
| 2 | 30 | 72 | 5 |
| 3 | 66 | 138 | 7 |
| 4 | 40 | 178 | 9 |
| 5 | 82 | 260 | 11 |
| 6 | 32 | 292 | 11 |
| 7 | 138 | 430 | 14 |
| 8 | 114 | 544 | 16 |
| 9 | 124 | 668 | 17 |
| 10 | 222 | 890 | 20 |

Minute 6 is a deliberate XP lull (only the first small `bamboo_brute` wave spawns) —
it's a breather right after the charger is introduced, so the player is dealing with a
new threat type without also being XP-starved *and* swarmed simultaneously. Minute 10
is the steepest XP minute in the run (222 XP, more than minutes 1+2 combined) — that's
the pre-boss surge wave doing double duty as both a difficulty spike and a last chance
to bank a level before the boss.

## Enemy pressure vs. baseline DPS by minute

"Baseline DPS" = old_talisman/fire_talisman alone, at weapon level ≈
`min(round(implied_level/2), 8)` (assumes roughly half of level-up choices go into the
starting weapon, capped at `max_level: 8`). This is a **lower bound** — real DPS by
mid-game includes secondary weapons and passive stacks and is meaningfully higher; see
guesses above.

| Minute | Weapon lvl | Baseline DPS | Incoming HP | HP/s pressure | Margin | Note |
|---|---|---|---|---|---|---|
| 1 | 2 | 13.0 | 280 | 4.7 | 2.8x | goblins only, trivial |
| 2 | 3 | 16.4 | 200 | 3.3 | 5.0x | still trivial, absorbing new baseline |
| 3 | 4 | 20.0 | 336 | 5.6 | 3.6x | forest_spirit (ranged) introduced |
| 4 | 5 | 24.0 | 128 | 2.1 | 11.4x | intentional lull before minute 5 ramp |
| 5 | 6 | 28.4 | 408 | 6.8 | 4.2x | density climbing again |
| 6 | 6 | 28.4 | 240 | 4.0 | 7.1x | bamboo_brute (charger) introduced — HP pressure is low but its 18 dmg/hit at 70 spd is a burst-damage spike DPS math doesn't capture; this is the "learn to dodge the charger" minute |
| 7 | 7 | 33.3 | 780 | 13.0 | 2.6x | **first real danger minute** — goblin+spirit+brute concurrently, margin drops from >4x to 2.6x |
| 8 | 8 (cap) | 38.8 | 552 | 9.2 | 4.2x | weapon hits max_level, margin recovers |
| 9 | 8 (cap) | 38.8 | 880 | 14.7 | 2.6x | **second danger minute** — brute+goblin pre-boss ramp |
| 10 | 8 (cap) | 38.8 | 1304 | 21.7 | 1.8x | **tightest margin of the run**, by design — final surge wave right before the boss |

Boss (`bamboo_spirit_lord`, 7000 hp): with the assumed late-game multi-weapon/passive
multiplier (~2.5-3x baseline, i.e. ~100-160 combined dps), time-to-kill lands around
45-70s. At 35 dmg/hit and a Taoist base_hp of 100 (plus whatever max_hp passive stacks
were picked), the player can absorb only a handful of unblocked hits — the fight has to
be won by kiting (movement-only combat per the GDD), not by tanking. If playtesting
shows TTK outside ~40-80s, `bamboo_spirit_lord.hp` is the number to retune first.

## Where the run should feel dangerous

Three deliberate spikes, by design rather than accident:
1. **Minute 6** — bamboo_brute's introduction. Not a DPS problem (margin is fine), a
   *reaction* problem: first enemy that punishes standing still.
2. **Minute 7** — the first minute where all three trash types overlap. Margin dips to
   2.6x, the sharpest drop in the run up to that point.
3. **Minute 9-10** — sustained high pressure (margin never recovers above 2.6x, drops
   to 1.8x at minute 10) leading directly into the boss. This is intentional: minute 10
   should feel like the hardest trash the run has, so the boss reads as a
   different, climactic kind of hard rather than "more of the same."

Minutes 1-5 stay comfortably above 3x margin except the minute-4 lull — this is the
"learn the loop" half of the run per the GDD's 10-15 minute session target.

## Weapon/evolution progression

`old_talisman` (common) has enough headroom (max_level 8, +3 dmg/-0.05s cooldown per
level) to carry minutes 1-8 alone before hitting its cap, matching the implied level
curve above. `evolutions.json` gates `phoenix_talisman` at weapon level 5 + 3 stacks
of `skill_power`, both plausibly reachable by minute 4-5 per the level curve — early
enough that the evolved form, not the base form, is what's fighting minutes 7-10 and
the boss. Same shape applies to `sword`→`twin_sword` and `bow`→`divine_bow`.

`bamboo_brute` (hp 60) needs ~2s at minute-6 baseline DPS to kill one-on-one — long
enough to be a real target priority decision when 4-10 of them are on screen, short
enough not to stall the loop.
