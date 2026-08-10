extends RefCounted
## Tests LevelUpChoiceController.build_choice_view_models() (pure -- no scene
## tree needed) against tests/ui/fixtures/level_up_choices_{1,2,3}.json.

const FIXTURES_DIR := "res://tests/ui/fixtures"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_choice_count(1))
	failures.append_array(_test_choice_count(2))
	failures.append_array(_test_choice_count(3))
	failures.append_array(_test_kind_labels())
	return failures


func _load_fixture(name: String) -> Array[Dictionary]:
	var path: String = "%s/%s.json" % [FIXTURES_DIR, name]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("test_level_up_choice: missing fixture %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var typed: Array[Dictionary] = []
	if parsed is Array:
		for entry in parsed:
			typed.append(entry)
	return typed


func _test_choice_count(count: int) -> Array[String]:
	var failures: Array[String] = []
	var choices: Array[Dictionary] = _load_fixture("level_up_choices_%d" % count)
	if choices.size() != count:
		failures.append("fixture level_up_choices_%d.json has %d entries, expected %d" % [count, choices.size(), count])
		return failures

	var models: Array[Dictionary] = LevelUpChoiceController.build_choice_view_models(choices)
	if models.size() != count:
		failures.append("build_choice_view_models() returned %d models for %d choices" % [models.size(), count])
		return failures

	for model in models:
		if String(model.get("id", "")).is_empty():
			failures.append("%d-choice case: model missing id (%s)" % [count, model])
		var name: String = String(model.get("name", ""))
		if name.is_empty() or name == "???":
			failures.append("%d-choice case: model missing localized name (%s)" % [count, model])

	return failures


func _test_kind_labels() -> Array[String]:
	var failures: Array[String] = []
	var choices: Array[Dictionary] = [
		{"id": "w", "kind": "weapon_new", "name_ko": "a", "name_en": "a", "description_ko": "d"},
		{"id": "u", "kind": "weapon_upgrade", "name_ko": "b", "name_en": "b", "description_ko": "d"},
		{"id": "p", "kind": "passive", "name_ko": "c", "name_en": "c", "description_ko": "d"},
		{"id": "x", "kind": "unknown_kind", "name_ko": "e", "name_en": "e", "description_ko": "d"},
	]
	var models: Array[Dictionary] = LevelUpChoiceController.build_choice_view_models(choices)
	var by_id: Dictionary = {}
	for model in models:
		by_id[String(model.get("id", ""))] = model

	for expected_id in ["w", "u", "p"]:
		if String(by_id.get(expected_id, {}).get("kind_label", "")).is_empty():
			failures.append("choice '%s' should have a non-empty kind_label" % expected_id)

	if not String(by_id.get("x", {}).get("kind_label", "")).is_empty():
		failures.append("unrecognized kind should map to an empty kind_label, got '%s'" % by_id.get("x", {}).get("kind_label"))

	return failures
