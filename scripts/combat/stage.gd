class_name Stage
extends Node2D
## Combat stage root (N3-1). The ground is a code-drawn dark-forest placeholder
## in the DESIGN.md §5 palette until the AC-4 tiles land.

const GROUND_SIZE := Vector2(2048.0, 2048.0)
const PATCH_COUNT := 60
const PATCH_RADIUS_MIN := 40.0
const PATCH_RADIUS_MAX := 140.0
const PATCH_SEED := 20260814  # fixed so the placeholder ground is deterministic

@onready var _player: Player = $Player
@onready var _joystick: TouchJoystick = $Hud/VirtualJoystick


func _ready() -> void:
	_player.bounds = Rect2(-GROUND_SIZE / 2.0, GROUND_SIZE)


func _physics_process(_delta: float) -> void:
	_player.joystick_input = _joystick.output


func _draw() -> void:
	var ground := Rect2(-GROUND_SIZE / 2.0, GROUND_SIZE)
	draw_rect(ground, UiPalette.FOREST_GROUND)
	var rng := RandomNumberGenerator.new()
	rng.seed = PATCH_SEED
	for i: int in range(PATCH_COUNT):
		var patch_center := Vector2(
			rng.randf_range(ground.position.x, ground.end.x),
			rng.randf_range(ground.position.y, ground.end.y)
		)
		var patch_radius: float = rng.randf_range(PATCH_RADIUS_MIN, PATCH_RADIUS_MAX)
		draw_circle(patch_center, patch_radius, UiPalette.FOREST_SHADOW)
