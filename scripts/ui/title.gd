extends Control
## Title screen -- JOSEONLIKE's boot destination (SceneRouter.goto_title(),
## core-engine). Start routes into the existing, unchanged camp flow via
## SceneRouter.goto_camp().

const TITLE_EN: Texture2D = preload("res://asset/title/joseonlike_en.png")
const TITLE_KO: Texture2D = preload("res://asset/title/joseonlike_ko.png")
const BACKDROP: Texture2D = preload("res://asset/stage/backdrops/main_menu.png")

@onready var _backdrop: TextureRect = $Backdrop
@onready var _logo: TextureRect = $Logo
@onready var _start_button: Button = $StartButton


func _ready() -> void:
	_backdrop.texture = BACKDROP
	_logo.texture = LocaleText.texture(TITLE_KO, TITLE_EN)

	_start_button.text = LocaleText.ui("start_button")
	UiPalette.apply_button_style(_start_button)
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_camp()
