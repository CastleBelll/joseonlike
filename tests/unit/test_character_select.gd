extends RefCounted
## N2-1 수행자 선택: pure card view-model, selection transitions, and the
## locked-character guard, plus a structural build check of the scene.

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


func test_locked_characters_are_locked_in_real_data() -> bool:
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	return (
		not CharacterSelectScreen.is_locked(characters["taoist"])
		and CharacterSelectScreen.is_locked(characters["warrior"])
		and CharacterSelectScreen.is_locked(characters["archer"])
	)


func test_screen_builds_one_card_per_character() -> bool:
	UiLocale.current_locale = "ko"
	var scene: PackedScene = load(SELECT_SCENE)
	var screen: CharacterSelectScreen = scene.instantiate()
	screen.build_ui()

	var cards: VBoxContainer = screen.get_node("Cards")
	var characters: Dictionary = CharacterSelectScreen.load_characters()
	var passed: bool = cards.get_child_count() == characters.size()
	# The default profile selects the taoist, so its card carries the badge.
	passed = passed and screen.find_child("SelectedBadge", true, false) != null
	var taoist_card: Button = cards.get_node("Card_taoist")
	passed = passed and taoist_card.find_child("SelectedBadge", true, false) != null
	var back: Button = screen.get_node("BackButton")
	passed = passed and back.custom_minimum_size.y >= UiPalette.TOUCH_TARGET_MIN

	screen.free()
	return passed
