extends Node
## Profile persistence. Stores meta progression only — never PII, never logged.
##
## STUB — owned by the core-engine worktree. Signatures frozen, see
## ARCHITECTURE.md section 3.4.

const SAVE_PATH := "user://profile.save"
const SCHEMA_VERSION := 1

var _profile: Dictionary = {"schema": SCHEMA_VERSION}


func load_profile() -> Dictionary:
	return _profile.duplicate(true)


func save_profile() -> Error:
	push_warning("SaveManager.save_profile is not implemented yet")
	return OK


func get_value(key: String, default_value: Variant) -> Variant:
	return _profile.get(key, default_value)


func set_value(key: String, value: Variant) -> void:
	_profile[key] = value
