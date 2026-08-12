extends Control
## Base camp: a small walkable map, not a menu. The player character (combat's
## scenes/actors/player.tscn, instanced and read only -- never edited) stands
## in it and moves with the same keyboard/gamepad/touch-drag input it already
## supports. combat_enabled is set false on this instance -- there is nothing
## to fight in camp, and a player reported weapons firing here.
##
## Interaction is proximity-only, not click: walking up to a building or the
## gate and pressing ui_accept (or tapping the single InteractButton, which
## stays disabled until something is in range) triggers it. That single
## always-present, focusable, minimum-44x44 button IS the keyboard/touch
## fallback the base camp task required -- it never lets a click bypass
## proximity, but it does mean a player who cannot walk precisely still only
## needs to get close enough for it to enable, not land on an exact spot.

const PlayerScene := preload("res://scenes/actors/player.tscn")

const SPRITE_WORKSHOP := "res://asset/structure/workshop.png"
const SPRITE_ARCHIVE := "res://asset/structure/archive.png"
const SPRITE_TRAINING_GROUND := "res://asset/structure/training_ground.png"
const SPRITE_SHRINE := "res://asset/structure/camp_shrine.png"
const SPRITE_GATE := "res://asset/structure/joseon_gate.png"
const ICON_DIR := "res://asset/ui/camp/icons"
const INTERIOR_DIR := "res://asset/ui/camp/interiors"
const INTERIOR_PANEL: Texture2D = preload("res://asset/ui/camp/interior_panel_9slice.png")

const SPRITE_STONE_LANTERN := "res://asset/structure/stone_lantern.png"
const SPRITE_JANGSEUNG_PAIR := "res://asset/structure/jangseung_pair.png"
const GROUND_TEXTURE := "res://asset/camp/ground/courtyard.png"
const BOUNDARY_TEXTURE := "res://asset/camp/transition/boundary_north.png"

const INTERACT_RADIUS := 56.0
const DEFAULT_CHARACTER_ID := "taoist"
const GATE_ID := "gate"

## id -> {position, label_key, sprite}. World-space layout of the four GDD
## buildings (JOSEONLIKE_GDD.md section 13) plus the exit gate.
const BUILDINGS := [
	{"id": "workshop", "label_key": "building_workshop", "sprite": SPRITE_WORKSHOP, "position": Vector2(150, 260)},
	{"id": "archive", "label_key": "building_archive", "sprite": SPRITE_ARCHIVE, "position": Vector2(390, 260)},
	{"id": "training_ground", "label_key": "building_training_ground", "sprite": SPRITE_TRAINING_GROUND, "position": Vector2(150, 470)},
	{"id": "shrine", "label_key": "building_shrine", "sprite": SPRITE_SHRINE, "position": Vector2(390, 470)},
]
const GATE := {"id": GATE_ID, "label_key": "start_run", "sprite": SPRITE_GATE, "position": Vector2(270, 860)}
const PLAYER_START := Vector2(270, 610)

@onready var _title_label: Label = $CampTitle
@onready var _world: Node2D = $World
@onready var _ground: Sprite2D = $World/Ground
@onready var _building_panel: Panel = $BuildingPanel
@onready var _panel_icon: TextureRect = $BuildingPanel/PanelMargin/PanelBox/PanelHeader/PanelIcon
@onready var _panel_title: Label = $BuildingPanel/PanelMargin/PanelBox/PanelHeader/PanelTitle
@onready var _panel_body: Label = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelBody
@onready var _panel_close: Button = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelClose
@onready var _hint_label: Label = $HintLabel
@onready var _interact_button: Button = $InteractButton

var _interaction_points: Array[Dictionary] = []
var _return_focus_target: Control = null
var _nearby_id: String = ""
var _player: CharacterBody2D = null


func _ready() -> void:
	MusicDirector.play("camp")

	_interaction_points = []
	_interaction_points.append_array(BUILDINGS)
	_interaction_points.append(GATE)

	_title_label.text = LocaleText.ui("camp_title")
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_setup_ground()
	_setup_scenery()
	_setup_buildings()
	_setup_gate()
	_setup_player()

	_panel_close.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_panel_close)
	_panel_close.pressed.connect(_close_building_panel)
	_panel_title.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_title.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	_panel_body.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_body.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_style_interior_panel(_building_panel)
	_building_panel.visible = false

	_hint_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_hint_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)

	_interact_button.text = LocaleText.ui("camp_interact_button")
	UiPalette.apply_button_style(_interact_button)
	_interact_button.focus_mode = Control.FOCUS_ALL
	_interact_button.pressed.connect(_on_interact_pressed)
	_set_nearby("")
	_interact_button.grab_focus()


func _process(_delta: float) -> void:
	if _building_panel.visible or _player == null:
		return
	var closest_id: String = ""
	var closest_distance: float = INTERACT_RADIUS
	for point in _interaction_points:
		var distance: float = _player.global_position.distance_to(point["position"])
		if distance <= closest_distance:
			closest_distance = distance
			closest_id = String(point["id"])
	if closest_id != _nearby_id:
		_set_nearby(closest_id)
	if not closest_id.is_empty() and Input.is_action_just_pressed("ui_accept"):
		_interact(closest_id)


func _set_nearby(id: String) -> void:
	_nearby_id = id
	_interact_button.disabled = id.is_empty()
	_hint_label.visible = not id.is_empty()
	if id.is_empty():
		return
	for point in _interaction_points:
		if String(point["id"]) == id:
			_hint_label.text = LocaleText.ui(String(point["label_key"]))
			return


func _on_interact_pressed() -> void:
	if not _nearby_id.is_empty():
		_interact(_nearby_id)


func _interact(id: String) -> void:
	if id == GATE_ID:
		UiSound.play_click(self)
		SceneRouter.goto_character_select()
		return
	_open_building_panel(id)


func _setup_ground() -> void:
	var texture: Texture2D = load(GROUND_TEXTURE) if ResourceLoader.exists(GROUND_TEXTURE) else null
	if texture == null:
		return
	_ground.texture = texture
	_ground.centered = false
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		_ground.scale = Vector2(540.0 / texture_size.x, 960.0 / texture_size.y)

	# Marks the camp's north edge so it reads as a bounded place rather than
	# open ground continuing off-screen (asset/UI_ART_REPORT.md follow-up).
	# Aspect-correct (unlike Ground's stretch-to-fill) since it is a
	# recognisable fence line, not a tileable dirt pattern.
	if ResourceLoader.exists(BOUNDARY_TEXTURE):
		var boundary := Sprite2D.new()
		boundary.texture = load(BOUNDARY_TEXTURE)
		boundary.centered = false
		var boundary_size: Vector2 = boundary.texture.get_size()
		if boundary_size.x > 0.0:
			boundary.scale = Vector2.ONE * (540.0 / boundary_size.x)
		_world.add_child(boundary)


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


func _setup_gate() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Gate"
	sprite.texture = load(SPRITE_GATE) if ResourceLoader.exists(SPRITE_GATE) else null
	sprite.position = GATE["position"]
	_world.add_child(sprite)


func _setup_player() -> void:
	_player = PlayerScene.instantiate()
	_player.character_id_override = RunState.character_id if not RunState.character_id.is_empty() else DEFAULT_CHARACTER_ID
	_player.combat_enabled = false
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

	_return_focus_target = _interact_button
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


func _unhandled_input(event: InputEvent) -> void:
	if _building_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_building_panel()
		get_viewport().set_input_as_handled()
