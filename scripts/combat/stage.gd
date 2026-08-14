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
@onready var _spawner: Spawner = $Spawner


func _ready() -> void:
	_player.bounds = Rect2(-GROUND_SIZE / 2.0, GROUND_SIZE)
	_player.died.connect(_on_player_died)
	_spawner.setup(_player)


func _physics_process(_delta: float) -> void:
	_player.joystick_input = _joystick.output


## N3-4 run-over is a clean freeze; the results screen is a later feature.
func _on_player_died() -> void:
	get_tree().paused = true


## Debug kill path until the first weapon (N3-3) lands: K kills the enemy
## nearest to the player. Debug builds only. TODO(N3-3): remove with auto-attack.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.keycode != KEY_K:
		return
	var nearest: Enemy = null
	var nearest_distance: float = INF
	for enemy: Enemy in _spawner.active_enemies():
		var distance: float = enemy.global_position.distance_to(_player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	if nearest != null:
		nearest.take_damage(nearest.hp)


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
