extends Button
## Single character grid cell. Locked characters render a visible lock icon
## plus their unlock-condition text -- never a plain greyed-out button with
## no explanation (color alone never carries the locked state). Unlocked
## cards get a matching check icon for the same reason, symmetric with lock.
##
## asset/UI_ART_REPORT.md item 3: portrait, class mark, and the
## unselected/selected card frame replace the flat gameplay sprite and
## generic button chrome.

const PORTRAIT_DIR := "res://asset/ui/character/portraits"
const CLASS_DIR := "res://asset/ui/character/classes"
const CARD_UNSELECTED: Texture2D = preload("res://asset/ui/character/card_unselected_9slice.png")
const CARD_SELECTED: Texture2D = preload("res://asset/ui/character/card_selected_9slice.png")
const CARD_MARGIN := 12

signal character_selected(character_id: String)

@onready var _icon: TextureRect = $Margin/Box/Icon
@onready var _class_icon: TextureRect = $ClassBadge
@onready var _name_label: Label = $Margin/Box/NameLabel
@onready var _lock_row: HBoxContainer = $Margin/Box/LockRow
@onready var _lock_icon: TextureRect = $Margin/Box/LockRow/LockIcon
@onready var _lock_reason_label: Label = $Margin/Box/LockRow/LockReasonLabel
@onready var _check_badge: TextureRect = $CheckBadge

var _character_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(236, 200)
	focus_mode = Control.FOCUS_ALL
	pressed.connect(_on_pressed)
	_lock_icon.texture = UiPalette.ICON_LOCK
	_check_badge.texture = UiPalette.ICON_CHECK
	_style_card()


func configure(character: Dictionary, is_unlocked: bool, unlock_reason: String) -> void:
	_character_id = String(character.get("id", ""))
	_name_label.text = LocaleText.field(character, "name")
	_name_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)

	var portrait: Texture2D = _load(PORTRAIT_DIR, _character_id)
	_icon.texture = portrait
	_icon.visible = portrait != null

	var class_mark: Texture2D = _load(CLASS_DIR, _character_id)
	_class_icon.texture = class_mark
	_class_icon.visible = class_mark != null and is_unlocked

	disabled = not is_unlocked
	_lock_row.visible = not is_unlocked
	_check_badge.visible = is_unlocked
	_lock_reason_label.text = unlock_reason
	_lock_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lock_reason_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)


func _style_card() -> void:
	var normal := _nine_slice(CARD_UNSELECTED)
	var focused := _nine_slice(CARD_SELECTED)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", focused)
	add_theme_stylebox_override("pressed", focused)
	add_theme_stylebox_override("focus", focused)
	var disabled_style := _nine_slice(CARD_UNSELECTED)
	disabled_style.modulate_color = UiPalette.DISABLED_TINT
	add_theme_stylebox_override("disabled", disabled_style)
	custom_minimum_size.x = max(custom_minimum_size.x, UiPalette.TOUCH_TARGET_MIN)
	custom_minimum_size.y = max(custom_minimum_size.y, UiPalette.TOUCH_TARGET_MIN)


func _nine_slice(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = CARD_MARGIN
	style.texture_margin_right = CARD_MARGIN
	style.texture_margin_top = CARD_MARGIN
	style.texture_margin_bottom = CARD_MARGIN
	return style


func _load(dir: String, id: String) -> Texture2D:
	var path: String = "%s/%s.png" % [dir, id]
	return load(path) if not id.is_empty() and ResourceLoader.exists(path) else null


func _on_pressed() -> void:
	if _character_id.is_empty():
		return
	UiSound.play_click(self)
	character_selected.emit(_character_id)
