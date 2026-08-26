class_name CombatRng
extends RefCounted
## The run's combat randomness, kept apart from everything decorative (C6).
##
## Crit rolls used to call the global `randf()`. So do the sprite frame a prop
## picks, the direction a curse creep curls and the art a chain bolt draws — all
## off the SAME global stream, so how many frames had been rendered before a
## weapon fired decided where the crits landed. `--seed` never reached them.
##
## What this fixes is the meaning of `--seed`: together with the spawner and
## loot generators (both of which called `randomize()` and ignored the run seed
## outright), every combat random now comes from the seed. Verified by
## `--idle`, where a seed repeats exactly and two seeds diverge.
##
## What it does NOT fix, measured: a bot-driven run still varies about ±3% at a
## fixed seed, the same as before this change. The remaining variance is in the
## harness bot, not in randomness — see C6b in TASKS.md. Balance comparisons
## still need seed aggregates, not one seed.
##
## Static rather than passed down: the three callers (AutoWeapon, Summon, Ward)
## are pooled objects built in three different places, and threading a
## generator through all of them would touch far more code than the rolls it is
## meant to fix. Unseeded it behaves the way the global stream did, so headless
## tests and demo harnesses that never start a run still work.

static var _rng: RandomNumberGenerator = null


## Called once per run by the stage, from the same seed the field uses.
static func seed_run(value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = value


## One roll in [0, 1). Auto-seeds on first use so a caller outside a run — a
## test, a weapon demo — is never handed a null.
static func roll() -> float:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng.randf()


## True when `chance` wins this roll. A zero or negative chance never rolls at
## all, which keeps a weapon with no crit stat from consuming the stream and
## shifting every later draw.
static func hits(chance: float) -> bool:
	return chance > 0.0 and roll() < chance
