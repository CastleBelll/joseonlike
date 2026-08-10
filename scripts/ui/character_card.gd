extends Button
## Single character grid cell. Locked characters render a visible lock icon
## plus their unlock-condition text -- never a plain greyed-out button with
## no explanation (color alone never carries the locked state).

signal character_selected(character_id: String)

@onready var _icon: TextureRect = $Margin/Box/Icon
@onready var _name_label: Label = $Margin/Box/NameLabel
@onready var _lock_row: HBoxContainer = $Margin/Box/LockRow
@onready var _lock_icon: Label = $Margin/Box/LockRow/LockIcon
@onready var _lock_reason_label: Label = $Margin/Box/LockRow/LockReasonLabel

var _character_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(236, 200)
	focus_mode = Control.FOCUS_ALL
	pressed.connect(_on_pressed)


func configure(character: Dictionary, is_unlocked: bool, unlock_reason: String) -> void:
	_character_id = String(character.get("id", ""))
	_name_label.text = LocaleText.field(character, "name")

	var sprite_path: String = String(character.get("sprite", ""))
	var texture: Texture2D = load(sprite_path) if sprite_path != "" and ResourceLoader.exists(sprite_path) else null
	_icon.texture = texture
	_icon.visible = texture != null

	disabled = not is_unlocked
	_lock_row.visible = not is_unlocked
	_lock_icon.text = "\U0001F512"
	_lock_reason_label.text = unlock_reason
	_lock_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bg: Color = UiPalette.PAPER_DARK if is_unlocked else UiPalette.LOCKED
	var text_color: Color = UiPalette.TEXT_ON_PAPER if is_unlocked else UiPalette.TEXT_ON_DARK
	UiPalette.apply_button_style(self, bg, text_color)
	_name_label.add_theme_color_override("font_color", text_color)
	_lock_reason_label.add_theme_color_override("font_color", text_color)
	_lock_icon.add_theme_color_override("font_color", UiPalette.VERMILION)


func _on_pressed() -> void:
	if _character_id.is_empty():
		return
	character_selected.emit(_character_id)
