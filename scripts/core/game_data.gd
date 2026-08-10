extends Node
## Read-only access to JSON content under res://data.
##
## STUB — owned by the core-engine worktree, which implements loading, caching,
## and validation. Signatures are frozen (ARCHITECTURE.md section 3.2) so other
## worktrees can compile and test against them today.

func load_all() -> Error:
	push_warning("GameData.load_all is not implemented yet")
	return OK


func character(id: String) -> Dictionary:
	return _lookup("characters", id)


func weapon(id: String) -> Dictionary:
	return _lookup("weapons", id)


func monster(id: String) -> Dictionary:
	return _lookup("monsters", id)


func stage(id: String) -> Dictionary:
	return _lookup("stages", id)


func passive(id: String) -> Dictionary:
	return _lookup("passives", id)


## Returns the evolved weapon id, or "" when the pair has no evolution.
func evolution_for(weapon_id: String, passive_id: String) -> String:
	return ""


func all_characters() -> Array[Dictionary]:
	return []


func all_achievements() -> Array[Dictionary]:
	return []


func _lookup(collection: String, id: String) -> Dictionary:
	push_warning("GameData.%s(%s) called before data loading is implemented" % [collection, id])
	return {}
