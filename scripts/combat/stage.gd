class_name Stage
extends Node2D
## Combat stage root (N3-1). The ground is a code-drawn dark-forest placeholder
## in the DESIGN.md §5 palette until the AC-4 tiles land.

const PATCH_COUNT := 60
const PATCH_RADIUS_MIN := 40.0
const PATCH_RADIUS_MAX := 140.0
const PATCH_SEED := 20260814  # fixed so the placeholder ground is deterministic

const WEAPONS_PATH := "res://data/weapons.json"
const PASSIVES_PATH := "res://data/passives.json"
const CHOICES_PER_LEVEL := 3

@onready var _player: Player = $World/Player
@onready var _joystick: TouchJoystick = $Hud/VirtualJoystick
@onready var _spawner: Spawner = $World/Spawner
@onready var _hud: CombatHud = $Hud/CombatHud
@onready var _field: StageField = $World/StageField
@onready var _decor_layer: Node2D = $DecorLayer

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
var _kills: int = 0
var _ground_size := Vector2.ZERO  # from data/props.json "field" block

# N3-8 feedback + N5-1 run flow state.
var _feedback: Dictionary = {}
var _puff_pool: NodePool
var _gold: int = 0
var _run_elapsed: float = 0.0
var _duration_sec: float = 0.0
var _boss: Enemy
var _boss_hp_max: float = 0.0
var _outcome: String = RunFlow.OUTCOME_NONE
var _result: ResultScreen


func _ready() -> void:
	var props_config: Dictionary = StageField.load_config()
	var field_config: Dictionary = props_config.get("field", {})
	_ground_size = Vector2(
		float(field_config.get("width_px", 0.0)),
		float(field_config.get("height_px", 0.0))
	)
	_player.bounds = Rect2(-_ground_size / 2.0, _ground_size)
	# randi() is auto-seeded per process start, so every run scatters a fresh
	# field layout; tests drive StageField.generate with fixed seeds instead.
	_field.build(
		props_config.get("props", {}) as Dictionary, field_config, _decor_layer, randi()
	)
	_player.died.connect(_on_player_died)
	_player.hit_taken.connect(_on_player_hit)
	_spawner.setup(_player)
	_spawner.enemy_killed.connect(_on_enemy_killed)
	_spawner.boss_spawned.connect(_on_boss_spawned)
	_feedback = _load_json(Spawner.EFFECTS_PATH).get("hit_feedback", {})
	_duration_sec = float(
		(_load_json(Spawner.STAGES_PATH).get(Spawner.STAGE_ID, {}) as Dictionary)
		.get("duration_sec", 0.0)
	)
	_puff_pool = NodePool.new(self, _create_puff)
	_result = ResultScreen.new()
	add_child(_result)
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
	_hud.set_gold(0)  # run gold is display-only until the workshop economy phase
	_refresh_progress_hud()


func _physics_process(delta: float) -> void:
	_player.joystick_input = _joystick.output
	_run_elapsed += delta
	if _duration_sec > 0.0 and _run_elapsed >= _duration_sec:
		_end_run(RunFlow.resolve_outcome(false, false, true))
	if _boss != null and not CombatMath.is_dead(_boss.hp):
		_hud.set_boss_hp(_boss.hp, _boss_hp_max)


func _on_player_died() -> void:
	_end_run(RunFlow.resolve_outcome(true, false, false))


## N3-8: the invulnerability blink lives on the player; the HUD adds the
## screen-edge red pulse so a hit is legible even off-center.
func _on_player_hit() -> void:
	_hud.pulse_damage(float(_feedback.get("player_vignette_sec", 0.0)))


## The enemy reference is only valid during this synchronous call — it goes
## back to its pool right after (see Spawner.enemy_killed).
func _on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	_gold += enemy.gold_drop
	_hud.set_kills(_kills)
	_hud.set_gold(_gold)
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		enemy.global_position,
		enemy.contact_radius * float(_feedback.get("death_puff_radius_scale", 1.0)),
		float(_feedback.get("death_puff_sec", 0.0))
	)
	var orb: XpOrb = _orb_pool.acquire()
	orb.launch(enemy.global_position, enemy.xp_drop, _player, _orb_config)
	if enemy.is_boss:
		_boss = null
		_hud.hide_boss_bar()
		_end_run(RunFlow.resolve_outcome(false, true, false))


func _on_boss_spawned(boss: Enemy) -> void:
	_boss = boss
	_boss_hp_max = boss.hp
	_hud.show_boss_bar()
	_hud.set_boss_hp(boss.hp, _boss_hp_max)


## Single exit point for the three end conditions; the first one wins.
func _end_run(outcome: String) -> void:
	if _outcome != RunFlow.OUTCOME_NONE or outcome == RunFlow.OUTCOME_NONE:
		return
	_outcome = outcome
	get_tree().paused = true
	_result.open(outcome, RunFlow.build_summary(_run_elapsed, _kills, _gold))


func _on_orb_collected(orb: XpOrb) -> void:
	_run_state.add_xp(orb.xp_value)
	_refresh_progress_hud()
	_orb_pool.release(orb)


func _refresh_progress_hud() -> void:
	_hud.set_level(_run_state.level)
	_hud.set_xp(_run_state.xp, _run_state.xp_needed())


func _on_hit_landed(amount: float, at: Vector2, boss_hit: bool) -> void:
	var number: DamageNumber = _number_pool.acquire()
	number.show_amount(amount, at, boss_hit)


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
		var grant: float = Player.load_base_hp() * per_stack
		_player.hp += grant
		_player.hp_max += grant


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


func _create_puff() -> DeathPuff:
	var puff := DeathPuff.new()
	puff.finished.connect(
		func(done: DeathPuff) -> void: _puff_pool.release(done)
	)
	return puff


func _draw() -> void:
	if _ground_size == Vector2.ZERO:
		return
	var ground := Rect2(-_ground_size / 2.0, _ground_size)
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
