extends Node
## Level-up popup layout check (N3-17): opens the real LevelUpPopup with the
## worst-case card set the data can produce (tallest 개조 desc with the FTUE
## line + two tallest regular descs), screenshots it, and quits.
## Run: godot --path . res://tools/popup_check.tscn

const SHOT_PATH := "user://popup_check.png"
const WORST_LEVEL := 8
const WORST_GRADE := "mythic"


func _ready() -> void:
	var weapons: Dictionary = _load("res://data/weapons.json")
	var passives: Dictionary = _load("res://data/passives.json")
	var mods: Dictionary = _load("res://data/weapon_mods.json")
	var grades: Dictionary = WeaponGrade.config(weapons)
	var owned: Dictionary = {}
	var owned_grades: Dictionary = {}
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		owned[weapon_id] = WORST_LEVEL
		owned_grades[weapon_id] = WORST_GRADE
	var cards: Array[Dictionary] = [
		_tallest_mod_card(mods, weapons, passives, owned, owned_grades, grades),
		_tallest_regular_card(weapons, passives, owned, owned_grades, grades),
		_tallest_regular_card(weapons, passives, owned, owned_grades, grades),
	]
	var popup := LevelUpPopup.new()
	add_child(popup)
	popup.open("파워 업!", cards, owned, weapons)
	_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("POPUP shot: " + ProjectSettings.globalize_path(SHOT_PATH))
	get_tree().quit(0)


func _tallest_mod_card(
	mods: Dictionary, weapons: Dictionary, passives: Dictionary,
	owned: Dictionary, owned_grades: Dictionary, grades: Dictionary
) -> Dictionary:
	var best: Dictionary = {}
	var best_len: int = -1
	for mod_id: String in mods:
		var choice: Dictionary = {"kind": LevelUp.KIND_MOD, "id": mod_id, "mod": mods[mod_id]}
		var card: Dictionary = LevelUp.as_card(
			choice, weapons, passives, owned, {}, owned_grades, grades
		)
		card["desc"] = Ftue.MOD_EXPLAIN_LINE + "\n" + String(card["desc"])
		if String(card["desc"]).length() > best_len:
			best_len = String(card["desc"]).length()
			best = card
	return best


func _tallest_regular_card(
	weapons: Dictionary, passives: Dictionary,
	owned: Dictionary, owned_grades: Dictionary, grades: Dictionary
) -> Dictionary:
	var best: Dictionary = {}
	var best_len: int = -1
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		for kind: String in [LevelUp.KIND_NEW_WEAPON, LevelUp.KIND_WEAPON_UP]:
			var card: Dictionary = LevelUp.as_card(
				{"kind": kind, "id": weapon_id}, weapons, passives,
				owned, {}, owned_grades, grades
			)
			if String(card["desc"]).length() > best_len:
				best_len = String(card["desc"]).length()
				best = card
	return best


func _load(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_error("popup_check: cannot parse " + path)
		return {}
	return data
