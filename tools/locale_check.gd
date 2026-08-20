extends Node
## N9-87 evidence: with the language set to English, the combat cards must not
## still be printing Korean.
##
## The unit suite runs in the default locale, so it can prove the table is
## self-consistent but never that the toggle reaches the screen. This walks the
## real card writer with `current_locale = "en"` and reports any string that
## still holds Hangul — the failure the owner would see, found where it happens.
##
## Run: godot --headless --path . res://tools/locale_check.tscn

const HANGUL_FIRST := 0xAC00
const HANGUL_LAST := 0xD7A3

var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiLocale.current_locale = "en"
	_check_table()
	_check_call_sites()
	_check_cards()
	_finish()


## Every entry has to survive `%` with the arguments the Korean would take,
## because format specifiers fill positionally: a translation that dropped or
## reordered one prints the wrong number instead of failing.
func _check_table() -> void:
	var mismatched: int = 0
	for korean: String in UiLocale.INLINE_EN:
		var english: String = String(UiLocale.INLINE_EN[korean])
		if _specifiers(korean) != _specifiers(english):
			push_error(
				"locale_check: '%s' -> '%s' changes its format specifiers"
				% [korean, english]
			)
			mismatched += 1
	if mismatched > 0:
		_failed = true
	print("LOCALE table: %d entries, %d with mismatched specifiers" % [
		UiLocale.INLINE_EN.size(), mismatched
	])



## Every string handed to UiLocale.t() must have a row, or the toggle silently
## leaves that one in Korean. Read from the SOURCE rather than by playing: a
## card branch that needs a maxed pierce weapon to appear would otherwise go
## unchecked, which is exactly what happened the first time this ran.
func _check_call_sites() -> void:
	var missing: int = 0
	var checked: int = 0
	for path: String in [
		"res://scripts/combat/stage.gd",
		"res://scripts/combat/level_up.gd",
		"res://scripts/combat/run_flow.gd",
		"res://scripts/ui/combat_hud.gd",
		"res://scripts/ui/level_up_popup.gd",
		"res://scripts/core/camp.gd",
		"res://scripts/core/ftue.gd",
		"res://scripts/ui/camp_screen.gd",
		"res://scripts/ui/result_screen.gd",
		"res://scripts/ui/guide_dialog.gd",
		"res://scripts/ui/move_hint.gd",
		"res://scripts/ui/achievements_screen.gd",
	]:
		var source: String = FileAccess.get_file_as_string(path)
		var cursor: int = 0
		while true:
			var call_at: int = source.find('UiLocale.t("', cursor)
			if call_at < 0:
				break
			var start: int = call_at + 'UiLocale.t("'.length()
			var end: int = source.find('"', start)
			cursor = end + 1
			if end < 0:
				break
			var literal: String = source.substr(start, end - start)
			if not _has_hangul(literal):
				continue
			checked += 1
			if not UiLocale.INLINE_EN.has(literal):
				push_error("locale_check: no translation for '%s' (%s)" % [literal, path])
				missing += 1
	print("LOCALE call sites: %d Korean literals, %d untranslated" % [checked, missing])
	if missing > 0:
		_failed = true

func _specifiers(text: String) -> Array[String]:
	var found: Array[String] = []
	var i: int = 0
	while i < text.length() - 1:
		if text[i] == "%":
			if text[i + 1] == "%":
				i += 2
				continue
			found.append("%" + text[i + 1])
		i += 1
	return found


## Drives the real card writer over every weapon the game can offer, which is
## where the bulk of the translated text is produced. No name exemption any
## more: since data_name resolves name_en for every catalogue, a Korean name
## on an English card is a gap rather than a fact of life.
func _check_cards() -> void:
	var weapons: Dictionary = _load("res://data/weapons.json")
	var passives: Dictionary = _load("res://data/passives.json")
	var grades: Dictionary = weapons.get("_grades", {})
	var leaked: int = 0
	var checked: int = 0
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var choice: Dictionary = {"kind": "weapon", "id": weapon_id}
		var card: Dictionary = LevelUp.as_card(
			choice, weapons, passives, {}, {}, {}, grades
		)
		for field: String in ["body", "well_label", "grade_label"]:
			var text: String = String(card.get(field, ""))
			if text.is_empty():
				continue
			checked += 1
			if _has_hangul(text):
				push_error("locale_check: %s.%s still Korean: %s" % [weapon_id, field, text])
				leaked += 1
	print("LOCALE cards: %d strings checked, %d still Korean" % [checked, leaked])
	if leaked > 0:
		_failed = true


func _has_hangul(text: String) -> bool:
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code >= HANGUL_FIRST and code <= HANGUL_LAST:
			return true
	return false


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _finish() -> void:
	UiLocale.current_locale = UiLocale.DEFAULT_LOCALE
	print("LOCALE CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)
