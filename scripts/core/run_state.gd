extends Node
## Mutable state of a single run. Reset between runs; nothing here survives to
## the profile save.
##
## STUB — owned by the core-engine worktree. Signatures frozen, see
## ARCHITECTURE.md section 3.3.

var character_id: String = ""
var stage_id: String = ""
var level: int = 1
var xp: int = 0
var elapsed_sec: float = 0.0
var kills: int = 0
var weapons: Array[Dictionary] = []
var passives: Dictionary = {}


func begin(new_character_id: String, new_stage_id: String) -> void:
	reset()
	character_id = new_character_id
	stage_id = new_stage_id
	EventBus.run_started.emit(character_id, stage_id)


func reset() -> void:
	character_id = ""
	stage_id = ""
	level = 1
	xp = 0
	elapsed_sec = 0.0
	kills = 0
	weapons = []
	passives = {}


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	EventBus.xp_gained.emit(amount)


## Aggregated passive value for a stat key, e.g. "attack_speed".
func stat_total(key: String) -> float:
	return 0.0
