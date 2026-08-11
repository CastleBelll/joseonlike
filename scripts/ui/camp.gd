extends Control
## Base camp: a small walkable map, not a menu. The player character (combat's
## scenes/actors/player.tscn, instanced and read only -- never edited) stands
## in it and moves with the same keyboard/gamepad input it already supports;
## walking up to a building and pressing ui_accept opens its panel. Every
## building is also a focusable, tappable hotspot at its world position, so
## the camp stays fully operable without precise movement -- required
## accessibility fallback, not a nice-to-have (a walkable camp nobody can
## reach without analog movement is worse than the menu it replaces).

const PlayerScene := preload("res://scenes/actors/player.tscn")

const SPRITE_WORKSHOP := "res://asset/structure/workshop.png"
const SPRITE_ARCHIVE := "res://asset/structure/archive.png"
const SPRITE_TRAINING_GROUND := "res://asset/structure/training_ground.png"
const SPRITE_SHRINE := "res://asset/structure/camp_shrine.png"
const ICON_DIR := "res://asset/ui/camp/icons"
const INTERIOR_DIR := "res://asset/ui/camp/interiors"
const INTERIOR_PANEL: Texture2D = preload("res://asset/ui/camp/interior_panel_9slice.png")

const SPRITE_STONE_LANTERN := "res://asset/structure/stone_lantern.png"
const SPRITE_JANGSEUNG_PAIR := "res://asset/structure/jangseung_pair.png"
const GROUND_TEXTURE := "res://asset/stage/bamboo_forest_ground.png"

const INTERACT_RADIUS := 46.0
const DEFAULT_CHARACTER_ID := "taoist"

## id -> {position, label_key, sprite}. World-space layout of the four GDD
## buildings (JOSEONLIKE_GDD.md section 13).
const BUILDINGS := [
	{"id": "workshop", "label_key": "building_workshop", "sprite": SPRITE_WORKSHOP, "position": Vector2(150, 260)},
	{"id": "archive", "label_key": "building_archive", "sprite": SPRITE_ARCHIVE, "position": Vector2(390, 260)},
	{"id": "training_ground", "label_key": "building_training_ground", "sprite": SPRITE_TRAINING_GROUND, "position": Vector2(150, 470)},
	{"id": "shrine", "label_key": "building_shrine", "sprite": SPRITE_SHRINE, "position": Vector2(390, 470)},
]
const PLAYER_START := Vector2(270, 660)

@onready var _title_label: Label = $CampTitle
@onready var _world: Node2D = $World
@onready var _ground: Sprite2D = $World/Ground
@onready var _start_run_button: Button = $StartRunButton
@onready var _building_panel: Panel = $BuildingPanel
@onready var _panel_icon: TextureRect = $BuildingPanel/PanelMargin/PanelBox/PanelHeader/PanelIcon
@onready var _panel_title: Label = $BuildingPanel/PanelMargin/PanelBox/PanelHeader/PanelTitle
@onready var _panel_body: Label = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelBody
@onready var _panel_close: Button = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelClose
@onready var _hint_label: Label = $HintLabel

var _return_focus_target: Control = null
var _hotspots: Dictionary = {}         ## id -> Button (accessibility fallback / tap target)
var _triggers: Dictionary = {}         ## id -> Area2D (walk-up proximity)
var _nearby_building_id: String = ""
var _player: CharacterBody2D = null


func _ready() -> void:
	_title_label.text = LocaleText.ui("camp_title")
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_setup_ground()
	_setup_scenery()
	_setup_buildings()
	_setup_player()

	_start_run_button.text = LocaleText.ui("start_run")
	UiPalette.apply_button_style(_start_run_button)
	_start_run_button.pressed.connect(_on_start_run_pressed)

	_panel_close.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_panel_close)
	_panel_close.pressed.connect(_close_building_panel)
	_panel_title.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_title.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	_panel_body.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_body.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_style_interior_panel(_building_panel)
	_building_panel.visible = false

	_hint_label.text = LocaleText.ui("camp_walk_hint")
	_hint_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_hint_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)

	_hotspots[BUILDINGS[0]["id"]].grab_focus()


func _process(_delta: float) -> void:
	if _building_panel.visible or _player == null:
		return
	var closest_id: String = ""
	var closest_distance: float = INTERACT_RADIUS
	for building in BUILDINGS:
		var distance: float = _player.global_position.distance_to(building["position"])
		if distance <= closest_distance:
			closest_distance = distance
			closest_id = String(building["id"])
	if closest_id != _nearby_building_id:
		_nearby_building_id = closest_id
		_hint_label.visible = not closest_id.is_empty()
	if not closest_id.is_empty() and Input.is_action_just_pressed("ui_accept"):
		_open_building_panel(closest_id)


func _setup_ground() -> void:
	var texture: Texture2D = load(GROUND_TEXTURE) if ResourceLoader.exists(GROUND_TEXTURE) else null
	if texture == null:
		return
	_ground.texture = texture
	_ground.centered = false
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		_ground.scale = Vector2(540.0 / texture_size.x, 960.0 / texture_size.y)


func _setup_scenery() -> void:
	_place_sprite(SPRITE_STONE_LANTERN, Vector2(60, 620))
	_place_sprite(SPRITE_JANGSEUNG_PAIR, Vector2(480, 620))


func _place_sprite(sprite_path: String, position: Vector2) -> void:
	if not ResourceLoader.exists(sprite_path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(sprite_path)
	sprite.position = position
	_world.add_child(sprite)


func _setup_buildings() -> void:
	for building in BUILDINGS:
		var id: String = String(building["id"])
		var position: Vector2 = building["position"]

		var sprite := Sprite2D.new()
		sprite.name = "Building_%s" % id
		sprite.texture = load(String(building["sprite"])) if ResourceLoader.exists(String(building["sprite"])) else null
		sprite.position = position
		_world.add_child(sprite)

		var trigger := Area2D.new()
		trigger.collision_layer = 0
		trigger.collision_mask = 1  # player's collision_layer (project.godot)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = INTERACT_RADIUS
		shape.shape = circle
		trigger.add_child(shape)
		trigger.position = position
		_world.add_child(trigger)
		_triggers[id] = trigger

		_hotspots[id] = _build_hotspot(building)


## Accessibility fallback: a real, focusable, tappable button positioned at
## the building's world location (world == viewport here, no camera scroll,
## so world and screen coordinates match 1:1). Tab/gamepad focus and touch
## taps open the panel exactly like walking up to it and pressing ui_accept.
func _build_hotspot(building: Dictionary) -> Button:
	var id: String = String(building["id"])
	var position: Vector2 = building["position"]

	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(UiPalette.TOUCH_TARGET_MIN, UiPalette.TOUCH_TARGET_MIN)
	button.size = Vector2(88, 44)
	button.position = position - button.size * 0.5
	UiPalette.apply_button_style(button)

	var label := Label.new()
	label.text = LocaleText.ui(String(building["label_key"]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	button.add_child(label)

	button.pressed.connect(_open_building_panel.bind(id))
	add_child(button)
	return button


func _setup_player() -> void:
	_player = PlayerScene.instantiate()
	_player.character_id_override = RunState.character_id if not RunState.character_id.is_empty() else DEFAULT_CHARACTER_ID
	_player.position = PLAYER_START
	var camera: Node = _player.get_node_or_null("Camera2D")
	if camera != null:
		camera.enabled = false  # camp is one static screen; the run camera is not needed here.
	_world.add_child(_player)


func _style_interior_panel(panel: Panel) -> void:
	var style := StyleBoxTexture.new()
	style.texture = INTERIOR_PANEL
	style.texture_margin_left = 12
	style.texture_margin_right = 12
	style.texture_margin_top = 12
	style.texture_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)


func _open_building_panel(id: String) -> void:
	UiSound.play_click(self)
	# Archive is the accomplishments building -- it routes straight to the
	# achievements/quests screen instead of the shared interior placeholder.
	if id == "archive":
		SceneRouter.goto_achievements_quests()
		return

	_return_focus_target = _hotspots.get(id)
	var label_key: String = ""
	for building in BUILDINGS:
		if String(building["id"]) == id:
			label_key = String(building["label_key"])
			break

	_panel_title.text = LocaleText.ui(label_key)
	_panel_body.text = LocaleText.ui("building_placeholder_body")
	var icon_path: String = "%s/%s.png" % [ICON_DIR, id]
	_panel_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_panel_icon.visible = _panel_icon.texture != null

	var interior_path: String = "%s/%s.png" % [INTERIOR_DIR, id]
	var interior_node: TextureRect = _building_panel.get_node("PanelMargin/PanelBox/InteriorArt")
	interior_node.texture = load(interior_path) if ResourceLoader.exists(interior_path) else null
	interior_node.visible = interior_node.texture != null

	_building_panel.visible = true
	_panel_close.grab_focus()


func _close_building_panel() -> void:
	if not _building_panel.visible:
		return
	UiSound.play_click(self)
	_building_panel.visible = false
	if is_instance_valid(_return_focus_target):
		_return_focus_target.grab_focus()
	_return_focus_target = null


func _on_start_run_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_character_select()


func _unhandled_input(event: InputEvent) -> void:
	if _building_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_building_panel()
		get_viewport().set_input_as_handled()
