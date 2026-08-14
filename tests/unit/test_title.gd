extends RefCounted
## Guards the N1-1 token foundation and title screen construction.

const TITLE_SCENE := "res://scenes/title.tscn"
const REQUIRED_TOKENS: Array[String] = [
	"NIGHT", "NIGHT_BROWN", "PAPER", "PAPER_CARD", "WOOD", "WOOD_HOVER",
	"WOOD_PRESSED", "WOOD_BORDER", "WOOD_TEXT", "INK", "GOLD", "VERMILION",
	"SUCCESS", "TEXT_ON_DARK",
]


func test_palette_tokens_exist() -> bool:
	var constants: Dictionary = (UiPalette as GDScript).get_script_constant_map()
	for token: String in REQUIRED_TOKENS:
		if not constants.has(token) or not constants[token] is Color:
			push_error("test_title: missing palette token " + token)
			return false
	return UiPalette.TOUCH_TARGET_MIN == 44


func test_title_builds_menu_from_locale() -> bool:
	# N5-2 owner direction: exactly one primary action on the title.
	var defs: Array[Dictionary] = TitleScreen.menu_button_defs()
	if defs.size() != 1 or defs[0]["label"] != UiLocale.text("title.start"):
		push_error("test_title: menu defs not built from locale")
		return false

	var scene: PackedScene = load(TITLE_SCENE)
	var title: TitleScreen = scene.instantiate()
	title.build_ui()

	var stack: VBoxContainer = title.get_node("MenuButtons")
	var passed: bool = stack.get_child_count() == defs.size()
	for i: int in range(defs.size()):
		var button: Button = stack.get_child(i)
		passed = passed and button.text == String(defs[i]["label"])
		passed = passed and button.custom_minimum_size.y >= UiPalette.TOUCH_TARGET_MIN

	title.free()
	return passed


func test_title_logo_texture_follows_locale() -> bool:
	# N1-2: the signboard logo is baked art per locale, swapped by refresh_texts.
	var scene: PackedScene = load(TITLE_SCENE)
	var title: TitleScreen = scene.instantiate()
	title.build_ui()
	var logo: TextureRect = title.get_node("Logo")

	var original_locale: String = UiLocale.current_locale
	UiLocale.current_locale = "en"
	title.refresh_texts()
	var en_texture: Texture2D = logo.texture
	UiLocale.current_locale = "ko"
	title.refresh_texts()
	var passed: bool = logo.texture != null and en_texture != null \
		and logo.texture != en_texture

	UiLocale.current_locale = original_locale
	title.free()
	return passed
