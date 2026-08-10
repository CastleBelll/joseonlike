class_name CombatRng
extends RefCounted
## Central source of combat randomness, so a measurement run can be reproduced.
##
## Crit rolls and spawn placement used to call randomize() directly, which meant
## two runs of the same build diverged. That made balance sweeps uncontrolled:
## a change confined to the boss fight could appear to move deaths at t=450s,
## because the two runs were never the same run. Gameplay behaviour is
## unchanged -- with no override set every stream still randomizes.

## -1 means "real randomness". A harness sets this before the stage is built to
## make a run reproducible; nothing in shipped code assigns it.
static var override_seed: int = -1

## Distinguishes streams created under the same override, so the spawner and a
## weapon do not roll identical sequences.
static var _stream_count: int = 0


## Fresh generator: seeded deterministically under an override, random otherwise.
static func create() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if override_seed < 0:
		rng.randomize()
		return rng
	_stream_count += 1
	rng.seed = hash([override_seed, _stream_count])
	return rng


## Called by a harness before building the stage. Resets the stream counter so
## the same seed always produces the same sequence of streams.
static func begin_deterministic(seed_value: int) -> void:
	override_seed = seed_value
	_stream_count = 0
	# Godot's global randf() backs anything that did not take its own generator.
	seed(hash([seed_value, "global"]))
