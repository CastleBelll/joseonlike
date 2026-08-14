class_name Stage
extends Node2D
## Combat stage root (N3-1). The ground is a code-drawn dark-forest placeholder
## in the DESIGN.md §5 palette until the AC-4 tiles land.

const GROUND_SIZE := Vector2(2048.0, 2048.0)
const PATCH_COUNT := 60
const PATCH_RADIUS_MIN := 40.0
const PATCH_RADIUS_MAX := 140.0
const PATCH_SEED := 20260814  # fixed so the placeholder ground is deterministic

const WEAPONS_PATH := "res://data/weapons.json"
const PASSIVES_PATH := "res://data/passives.json"
const CHOICES_PER_LEVEL := 3

@onready var _player: Player = $Player
@onready var _joystick: TouchJoystick = $Hud/VirtualJoystick
@onready var _spawner: Spawner = $Spawner

var _run_state: RunState
var _orb_pool: NodePool
var _number_pool: NodePool
var _orb_config: Dictionary = {}
var _orb_config_base: Dictionary = {}

# N3-6 run build state: weapon levels, passive stacks and their nodes/effects.
var _weapons_data: Dictionary = {}
var _passives_data: Dictionary = {}
var _owned_levels: Dictionary = {}
var _passive_stacks: Dictionary = {}
var _weapon_nodes: Dictionary = {}
var _popup: LevelUpPopup
var _pending_level_ups: int = 0
var _choice_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player.bounds = Rect2(-GROUND_SIZE / 2.0, GROUND_SIZE)
	_player.died.connect(_on_player_died)
	_spawner.setup(_player)
	_spawner.enemy_killed.connect(_on_enemy_killed)
	_run_state = RunState.new()
	_run_state.level_reached.connect(_on_level_reached)
	_orb_config_base = RunState.load_orb_config()
	_orb_config = _orb_config_base.duplicate()
	_orb_pool = NodePool.new(self, _create_orb)
	_number_pool = NodePool.new(self, _create_damage_number)
	_weapons_data = _load_json(WEAPONS_PATH)
	_passives_data = _load_json(PASSIVES_PATH)
	var starting_weapon: String = Player.load_starting_weapon()
	_owned_levels[starting_weapon] = 1
	_add_weapon_node(starting_weapon)
	_popup = LevelUpPopup.new()
	_popup.picked.connect(_on_choice_picked)
	_popup.dismissed.connect(_on_popup_dismissed)
	add_child(_popup)


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


## One grant can cross several levels; each one earns a choice screen, shown
## one after another while the tree stays paused.
func _on_level_reached(_new_level: int) -> void:
	_pending_level_ups += 1
	if _pending_level_ups == 1:
		_show_next_level_up()


func _show_next_level_up() -> void:
	get_tree().paused = true
	var pool: Array[Dictionary] = LevelUp.candidates(
		_weapons_data, _passives_data, _owned_levels, _passive_stacks
	)
	var choices: Array[Dictionary] = LevelUp.pick(pool, CHOICES_PER_LEVEL, _choice_rng)
	_popup.open(choices, _weapons_data, _passives_data, _owned_levels, _passive_stacks)


func _on_choice_picked(choice: Dictionary) -> void:
	var result: Dictionary = LevelUp.apply_choice(choice, _owned_levels, _passive_stacks)
	_owned_levels = result["owned_levels"]
	_passive_stacks = result["passive_stacks"]
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		LevelUp.KIND_NEW_WEAPON:
			_add_weapon_node(id)
		LevelUp.KIND_WEAPON_UP:
			(_weapon_nodes[id] as AutoWeapon).set_level(int(_owned_levels[id]))
		LevelUp.KIND_PASSIVE:
			_apply_passive_effects(id)
	_close_or_show_next()


func _on_popup_dismissed() -> void:
	_close_or_show_next()


func _close_or_show_next() -> void:
	_pending_level_ups -= 1
	if _pending_level_ups > 0:
		_show_next_level_up()
		return
	_popup.close()
	get_tree().paused = false


func _add_weapon_node(weapon_id: String) -> void:
	var weapon := AutoWeapon.new()
	add_child(weapon)
	weapon.setup(weapon_id, _player, _spawner)
	weapon.hit_landed.connect(_on_hit_landed)
	_weapon_nodes[weapon_id] = weapon
	_refresh_weapon_scales()


func _passive_bonus(passive_id: String) -> float:
	var per_stack: float = float(
		(_passives_data.get(passive_id, {}) as Dictionary).get("per_stack", 0.0)
	)
	return per_stack * float(_passive_stacks.get(passive_id, 0))


## Recompute every run-wide passive effect from the stack counts, then apply
## the one-shot effects for the stack that was just gained.
func _apply_passive_effects(gained_id: String) -> void:
	_refresh_weapon_scales()
	_player.set_speed_scale(1.0 + _passive_bonus("move_speed"))
	_orb_config = _orb_config_base.duplicate()
	_orb_config["magnet_radius_px"] = (
		float(_orb_config_base.get("magnet_radius_px", 0.0))
		* (1.0 + _passive_bonus("magnet_radius"))
	)
	# Max HP has no separate cap yet; each stack grants its slice of base HP.
	if gained_id == "max_hp":
		var per_stack: float = float(
			(_passives_data.get("max_hp", {}) as Dictionary).get("per_stack", 0.0)
		)
		_player.hp += Player.load_base_hp() * per_stack


func _refresh_weapon_scales() -> void:
	var damage_scale: float = 1.0 + _passive_bonus("attack_damage")
	var cooldown_scale: float = 1.0 / (1.0 + _passive_bonus("attack_speed"))
	for weapon: AutoWeapon in _weapon_nodes.values():
		weapon.set_scales(damage_scale, cooldown_scale)


func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_error("stage: cannot parse " + path)
		return {}
	return data


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
