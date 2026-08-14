extends SceneTree
## Minimal data validator: every data/*.json must parse as valid JSON.
## Cross-reference rules return together with the systems that consume the data.
## Contract (see docs/CI.md): godot --headless --path . --script tools/validate_data.gd

const DATA_DIR := "res://data"


func _init() -> void:
	var checked: int = 0
	var invalid: int = 0
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("validate_data: cannot open " + DATA_DIR)
		quit(1)
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		checked += 1
		var text: String = FileAccess.get_file_as_string(DATA_DIR + "/" + file_name)
		if JSON.parse_string(text) == null:
			push_error("validate_data: invalid JSON in " + file_name)
			invalid += 1
	if invalid > 0:
		print("FAIL %d/%d data files invalid" % [invalid, checked])
		quit(1)
		return
	print("PASS data validation: %d json files ok" % checked)
	quit(0)
