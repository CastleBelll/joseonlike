extends RefCounted
## N2-1 수행자 선택: pure card view-model, selection transitions, and the
## locked-character guard, plus a structural build check of the scene.
## N9-76 relayout: one detail panel plus a tile per character. Viewing a locked
## character is allowed — the panel is where its unlock condition is written —
## while selecting one still is not.

const SELECT_SCENE := "res://scenes/character_select.tscn"

## Synthetic roster: one open character, one locked (gold unlock).
const FAKE_CHARACTERS := {
	"open": {"unlock": {"type": "default"}},
	"locked": {"unlock": {"type": "gold", "cost": 500}},
}


func test_card_model_from_taoist_data() -> bool:
	UiLocale.current_locale = "ko"
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	if not characters.has("taoist"):
		push_error("test_character_select: taoist missing from characters.json")
		return false
	var model: Dictionary = CharacterSelectScreen.card_model(
		"taoist", characters["taoist"], "taoist"
	)
	return (
		model["name"] == "우치"
		and model["hanja"] == "雨池"
		and not String(model["title"]).is_empty()
		and String(model["quote"]).begins_with("\"")
		and String(model["quote"]).ends_with("\"")
		and model["accent"] == UiPalette.ACCENT_TAOIST
		and model["locked"] == false
		and model["selected"] == true
		and String(model["portrait_path"]).ends_with("taoist/portrait.png")
	)


## The detail panel's body. The taoist has a backstory, so the panel shows it
## rather than the one-line quote the old row card had room for.
func test_description_prefers_backstory_and_falls_back_to_quote() -> bool:
	UiLocale.current_locale = "ko"
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	var taoist: Dictionary = CharacterSelectScreen.card_model(
		"taoist", characters["taoist"], "taoist"
	)
	var backstory: String = String(characters["taoist"].get("backstory_ko", ""))
	if backstory.is_empty():
		push_error("test_character_select: taoist backstory_ko is empty")
		return false
	# A roster entry with no backstory must still fill the panel.
	var quote_only: Dictionary = CharacterSelectScreen.card_model(
		"ghost", {"quote_ko": "말", "unlock": {"type": "default"}}, ""
	)
	return (
		String(taoist["description"]) == backstory
		and String(quote_only["description"]) == "\"말\""
	)


func test_locked_card_model_shows_unlock_condition() -> bool:
	UiLocale.current_locale = "ko"
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	var model: Dictionary = CharacterSelectScreen.card_model(
		"warrior", characters["warrior"], "warrior"
	)
	# Even a stale save pointing at a locked character never renders 선택됨.
	return (
		model["locked"] == true
		and model["selected"] == false
		and not String(model["unlock_text"]).is_empty()
	)


func test_select_transitions() -> bool:
	var to_open: String = CharacterSelectScreen.select("open", "open", FAKE_CHARACTERS)
	var to_locked: String = CharacterSelectScreen.select("open", "locked", FAKE_CHARACTERS)
	var to_unknown: String = CharacterSelectScreen.select("open", "ghost", FAKE_CHARACTERS)
	return to_open == "open" and to_locked == "open" and to_unknown == "open"


## Viewing is deliberately more permissive than selecting: a locked character
## can be read, an unknown id still cannot.
func test_view_allows_locked_but_not_unknown() -> bool:
	var to_locked: String = CharacterSelectScreen.view("open", "locked", FAKE_CHARACTERS)
	var to_unknown: String = CharacterSelectScreen.view("open", "ghost", FAKE_CHARACTERS)
	return to_locked == "locked" and to_unknown == "open"


func test_locked_characters_are_locked_in_real_data() -> bool:
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	return (
		not CharacterSelectScreen.is_locked(characters["taoist"])
		and CharacterSelectScreen.is_locked(characters["warrior"])
		and CharacterSelectScreen.is_locked(characters["archer"])
	)


func test_screen_builds_one_tile_per_character_and_one_detail_panel() -> bool:
	UiLocale.current_locale = "ko"
	var scene: PackedScene = load(SELECT_SCENE)
	var screen: CharacterSelectScreen = scene.instantiate()
	screen.build_ui()

	var characters: Dictionary = CharacterSelectScreen.load_characters()
	var tiles: HBoxContainer = screen.find_child("Tiles", true, false)
	var passed: bool = tiles != null and tiles.get_child_count() == characters.size()
	# Exactly one detail panel, showing the default (taoist) selection.
	passed = passed and screen.get_node_or_null("Detail") != null
	passed = passed and screen.find_child("SelectedBadge", true, false) != null
	passed = passed and screen.find_child("Tile_taoist", true, false) != null
	# Every tile stays tappable on a phone as the roster grows.
	if tiles != null:
		for tile: Node in tiles.get_children():
			passed = passed and (tile as Control).custom_minimum_size.x >= UiPalette.TOUCH_TARGET_MIN
			passed = passed and (tile as Control).custom_minimum_size.y >= UiPalette.TOUCH_TARGET_MIN
	var back: Button = screen.get_node("BackButton")
	passed = passed and back.custom_minimum_size.y >= UiPalette.TOUCH_TARGET_MIN

	screen.free()
	return passed


## The layout's whole point: the strip grows sideways instead of the screen
## running out of room. Three characters must not already fill the width.
func test_tile_strip_has_room_for_more_characters() -> bool:
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	var used: int = characters.size() * CharacterSelectScreen.TILE_SIZE
	used += (characters.size() - 1) * UiPalette.SPACE_MD
	# Read the real viewport width rather than restating 540 here: a test that
	# hard-codes the design size stops testing the layout the moment it changes.
	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 540))
	return used < width
