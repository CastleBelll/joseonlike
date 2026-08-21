extends RefCounted
## N9-103: every character the game can put on screen must be drawable by the
## bundled theme font (neodgm + the galmuri fallback subset).
##
## Why this exists: on desktop Godot silently falls back to SYSTEM fonts for
## glyphs the bundled font lacks, so 개조 경로's arrows and the hanja in
## character names looked fine locally for weeks — and rendered as tofu on the
## web build, where no system font exists. Coverage is therefore asserted
## against the theme font alone, exactly what the web player gets.
##
## Scope: all data/*.json text and every string-bearing line of scripts/**.gd
## (comment lines are skipped — they never render). ASCII is assumed covered;
## only the characters above 0x7F are checked.

const THEME_PATH := "res://asset/ui_theme.tres"
const DATA_DIR := "res://data"
const SCRIPTS_DIR := "res://scripts"


func test_theme_font_covers_every_renderable_character() -> bool:
	var theme: Theme = load(THEME_PATH)
	var font: Font = theme.default_font
	if font == null:
		push_error("test_font_coverage: theme has no default_font")
		return false
	var missing: Dictionary = {}
	for path: String in _json_files(DATA_DIR):
		_check(FileAccess.get_file_as_string(path), path, font, missing)
	for path: String in _gd_files(SCRIPTS_DIR):
		_check(_without_comment_lines(FileAccess.get_file_as_string(path)), path, font, missing)
	for ch: String in missing:
		push_error(
			"test_font_coverage: U+%04X '%s' has no glyph in the theme font (seen in %s)"
			% [ch.unicode_at(0), ch, missing[ch]]
		)
	return missing.is_empty()


func _check(text: String, path: String, font: Font, missing: Dictionary) -> void:
	var seen: Dictionary = {}
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		if code < 0x80 or seen.has(code):
			continue
		seen[code] = true
		var ch: String = char(code)
		if not font.has_char(code) and not missing.has(ch):
			missing[ch] = path


## Lines that are pure comments never reach a Label; stripping them keeps the
## check mark in an old comment from failing a check about what players see.
func _without_comment_lines(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


func _json_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".json"):
			out.append(dir_path + "/" + file)
	return out


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path + "/" + file)
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_gd_files(dir_path + "/" + sub))
	return out
