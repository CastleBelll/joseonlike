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

var _run_state: RunState
var _weapon: AutoWeapon
var _orb_pool: NodePool
var _number_pool: NodePool
var _orb_config: Dictionary = {}


func _ready() -> void:
	_player.bounds = Rect2(-GROUND_SIZE / 2.0, GROUND_SIZE)
	_player.died.connect(_on_player_died)
	_spawner.setup(_player)
	_spawner.enemy_killed.connect(_on_enemy_killed)
	_run_state = RunState.new()
	_run_state.level_reached.connect(_on_level_reached)
	_orb_config = RunState.load_orb_config()
	_orb_pool = NodePool.new(self, _create_orb)
	_number_pool = NodePool.new(self, _create_damage_number)
	_weapon = AutoWeapon.new()
	add_child(_weapon)
	_weapon.setup(Player.load_starting_weapon(), _player, _spawner)
	_weapon.hit_landed.connect(_on_hit_landed)


func _physics_process(_delta: float) -> void:
	_player.joystick_input = _joystick.output


## N3-4 run-over is a clean freeze; the results screen is a later feature.
func _on_player_died() -> void:
	get_tree().paused = true


func _on_enemy_killed(at: Vector2, xp: int) -> void:
	var orb: XpOrb = _orb_pool.acquire()
	orb.launch(at, xp, _player, _orb_config)


func _on_orb_collected(orb: XpOrb) -> void:
	_run_state.add_xp(orb.xp_value)
	_orb_pool.release(orb)


func _on_hit_landed(amount: float, at: Vector2) -> void:
	var number: DamageNumber = _number_pool.acquire()
	number.show_amount(amount, at)


func _on_number_finished(number: DamageNumber) -> void:
	_number_pool.release(number)


## Leveling grants nothing yet — the N3-6 power-up choice popup hooks in here.
func _on_level_reached(_new_level: int) -> void:
	pass


func _create_orb() -> XpOrb:
	var orb := XpOrb.new()
	orb.collected.connect(_on_orb_collected)
	return orb


func _create_damage_number() -> DamageNumber:
	var number := DamageNumber.new()
	number.finished.connect(_on_number_finished)
	return number


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
