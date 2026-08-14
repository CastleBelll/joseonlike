class_name Stage
extends Node2D
## Combat stage root (N3-1). Ground and props render the AC-4 night-bamboo-
## forest art (N3-10) via Ground/StageField, falling back to palette-token
## placeholders when a texture is missing.

const WEAPONS_PATH := "res://data/weapons.json"
const PASSIVES_PATH := "res://data/passives.json"
const LOOT_PATH := "res://data/loot.json"
const DROP_TABLES_PATH := "res://data/drop_tables.json"
const WEAPON_MODS_PATH := "res://data/weapon_mods.json"
const CHOICES_PER_LEVEL := 3
const POWER_UP_HEADER := "파워 업!"
const LOOT_SCATTER_PX := 14.0

@onready var _player: Player = $World/Player
@onready var _joystick: TouchJoystick = $Hud/VirtualJoystick
@onready var _spawner: Spawner = $World/Spawner
@onready var _hud: CombatHud = $Hud/CombatHud
@onready var _field: StageField = $World/StageField
@onready var _ground: GroundLayer = $Ground
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
# N4-2 grade axis: per-weapon run grade plus the data ladder/steps config.
var _owned_grades: Dictionary = {}
var _grades_config: Dictionary = {}
var _grade_ladder: Array[String] = []
var _popup: LevelUpPopup
var _pending_level_ups: int = 0
var _choice_rng := RandomNumberGenerator.new()
var _kills: int = 0
var _ground_size := Vector2.ZERO  # from data/props.json "field" block

# N4-1 loot state: data tables, pooled drops, run-seeded RNG, special queue.
var _loot_data: Dictionary = {}
var _drop_tables: Dictionary = {}
var _mods_data: Dictionary = {}
var _loot_pool: NodePool
var _loot_rng := RandomNumberGenerator.new()
var _special_queue: Array[String] = []

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
	# Ground and props share one seed so a run's tiles and prop scatter match.
	var field_seed: int = randi()
	_ground.build(field_config, field_seed)
	_field.build(
		props_config.get("props", {}) as Dictionary, field_config, _decor_layer, field_seed
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
	_grades_config = WeaponGrade.config(_weapons_data)
	_grade_ladder = WeaponGrade.ladder(_grades_config)
	_passives_data = _load_json(PASSIVES_PATH)
	_loot_data = _load_json(LOOT_PATH)
	_drop_tables = _load_json(DROP_TABLES_PATH)
	_mods_data = _load_json(WEAPON_MODS_PATH)
	_loot_pool = NodePool.new(self, _create_loot_drop)
	_loot_rng.randomize()  # the run RNG: one seed replays a run's drops
	var starting_weapon: String = Player.load_starting_weapon()
	_owned_levels[starting_weapon] = 1
	_owned_grades[starting_weapon] = LevelUp.current_grade(starting_weapon, _weapons_data, {})
	_add_weapon_node(starting_weapon)
	_popup = LevelUpPopup.new()
	_popup.picked.connect(_on_choice_picked)
	_popup.dismissed.connect(_on_popup_dismissed)
	add_child(_popup)
	_hud.set_gold(0)  # run gold; banked into the profile at run end (N5-2)
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
	_spawn_loot(enemy)
	if enemy.is_boss:
		_boss = null
		_hud.hide_boss_bar()
		_end_run(RunFlow.resolve_outcome(false, true, false), true)


func _on_boss_spawned(boss: Enemy) -> void:
	_boss = boss
	_boss_hp_max = boss.hp
	_hud.show_boss_bar()
	_hud.set_boss_hp(boss.hp, _boss_hp_max)


## Single exit point for the three end conditions; the first one wins.
## N5-2: the run's gold banks into the permanent profile here — the one
## run-end autosave — and the result screen shows the new total.
func _end_run(outcome: String, boss_killed: bool = false) -> void:
	if _outcome != RunFlow.OUTCOME_NONE or outcome == RunFlow.OUTCOME_NONE:
		return
	_outcome = outcome
	get_tree().paused = true
	var summary: Dictionary = RunFlow.build_summary(_run_elapsed, _kills, _gold)
	summary["total_gold"] = SaveService.instance.bank_run(_run_elapsed, _kills, _gold, boss_killed)
	_result.open(outcome, summary)


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


## One grant can cross several levels; each one earns a choice screen. Level-up
## screens and special-loot screens share one popup and one queue discipline:
## a single panel at a time, level-ups first, then pending special materials.
func _on_level_reached(_new_level: int) -> void:
	_pending_level_ups += 1
	if not _popup.visible:
		_advance_popup_queue()


func _show_next_level_up() -> void:
	get_tree().paused = true
	var pool: Array[Dictionary] = LevelUp.candidates(
		_weapons_data, _passives_data, _owned_levels, _passive_stacks,
		_owned_grades, _grades_config
	)
	var choices: Array[Dictionary] = LevelUp.pick(pool, CHOICES_PER_LEVEL, _choice_rng)
	var cards: Array[Dictionary] = []
	for choice: Dictionary in choices:
		cards.append(LevelUp.as_card(
			choice, _weapons_data, _passives_data, _owned_levels, _passive_stacks,
			_owned_grades, _grades_config
		))
	_popup.open(POWER_UP_HEADER, cards, _owned_levels, _weapons_data)


## The special-material 3-choice screen (N4-1): built at show time so a queued
## material sees the weapon state left by the previous choice.
func _show_next_special() -> void:
	get_tree().paused = true
	var loot_id: String = _special_queue[0]
	var choices: Array[Dictionary] = Loot.build_choices(loot_id, _mods_data, _owned_levels)
	var cards: Array[Dictionary] = []
	for choice: Dictionary in choices:
		cards.append(Loot.as_card(choice, _loot_data, _weapons_data, _run_state.inventory))
	var header: String = "%s 획득!" % String(
		(_loot_data.get(loot_id, {}) as Dictionary).get("name_ko", loot_id)
	)
	_popup.open(header, cards, _owned_levels, _weapons_data)


func _on_choice_picked(payload: Dictionary) -> void:
	match String(payload.get("kind", "")):
		LevelUp.KIND_NEW_WEAPON, LevelUp.KIND_WEAPON_UP, LevelUp.KIND_PASSIVE, \
		LevelUp.KIND_GRADE_UP:
			_apply_level_up_choice(payload)
			_pending_level_ups -= 1
		Loot.KIND_USE, Loot.KIND_KEEP, Loot.KIND_SALVAGE:
			_apply_loot_choice(payload)
			_special_queue.pop_front()
		_:
			push_error("stage: unknown popup payload " + str(payload))
	_advance_popup_queue()


func _apply_level_up_choice(choice: Dictionary) -> void:
	var result: Dictionary = LevelUp.apply_choice(choice, _owned_levels, _passive_stacks)
	_owned_levels = result["owned_levels"]
	_passive_stacks = result["passive_stacks"]
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		LevelUp.KIND_NEW_WEAPON:
			# Seed the base grade directly — the callout is for earned raises
			# only, so a weapon whose data grade is already the top rung must
			# not fire it on acquisition. AutoWeapon.setup reads the same base.
			_owned_grades[id] = LevelUp.current_grade(id, _weapons_data, {})
			_add_weapon_node(id)
		LevelUp.KIND_WEAPON_UP:
			(_weapon_nodes[id] as AutoWeapon).set_level(int(_owned_levels[id]))
		LevelUp.KIND_GRADE_UP:
			_set_owned_grade(id, WeaponGrade.next(
				_grade_ladder, LevelUp.current_grade(id, _weapons_data, _owned_grades)
			))
		LevelUp.KIND_PASSIVE:
			_apply_passive_effects(id)


func _apply_loot_choice(choice: Dictionary) -> void:
	var loot_id: String = String(choice.get("loot_id", ""))
	match String(choice.get("kind", "")):
		Loot.KIND_USE:
			_apply_weapon_mod(choice.get("mod", {}) as Dictionary)
		Loot.KIND_KEEP:
			_run_state.inventory = Loot.add(_run_state.inventory, loot_id)
		Loot.KIND_SALVAGE:
			_gold += Loot.salvage_gold(_loot_data, loot_id)
			_hud.set_gold(_gold)


## Swap the owned base weapon node for the recipe result, carrying its level.
## N4-2: the run grade carries too (GDD §33), floored at the result weapon's
## own base grade — a mod can raise the grade, never lower it.
func _apply_weapon_mod(mod: Dictionary) -> void:
	var base_id: String = String(mod.get("weapon_id", ""))
	var result_id: String = String(mod.get("result_weapon", ""))
	var old_node: AutoWeapon = _weapon_nodes.get(base_id)
	if old_node == null:
		push_error("stage: weapon mod base '%s' has no node" % base_id)
		return
	var carried: String = WeaponGrade.highest(
		_grade_ladder,
		LevelUp.current_grade(base_id, _weapons_data, _owned_grades),
		LevelUp.current_grade(result_id, _weapons_data, {})
	)
	_owned_levels = Loot.apply_mod(_owned_levels, mod)
	_owned_grades.erase(base_id)
	_weapon_nodes.erase(base_id)
	old_node.queue_free()
	_add_weapon_node(result_id)
	(_weapon_nodes[result_id] as AutoWeapon).set_level(int(_owned_levels[result_id]))
	_set_owned_grade(result_id, carried)


## Single write point for a weapon's run grade: updates the dict, retunes the
## live weapon node, and fires the one-off top-grade callout (N4-2) in the
## damage-number style the moment any weapon first reaches the top rung.
func _set_owned_grade(weapon_id: String, grade: String) -> void:
	var was_top: bool = WeaponGrade.is_top(
		_grade_ladder, String(_owned_grades.get(weapon_id, ""))
	)
	_owned_grades[weapon_id] = grade
	var node: AutoWeapon = _weapon_nodes.get(weapon_id)
	if node != null:
		node.set_grade(grade)
	if WeaponGrade.is_top(_grade_ladder, grade) and not was_top:
		var number: DamageNumber = _number_pool.acquire()
		number.show_text(
			"%s %s 등급!" % [
				String((_weapons_data.get(weapon_id, {}) as Dictionary).get("name_ko", weapon_id)),
				String(LevelUp.GRADE_KO.get(grade, grade)),
			],
			_player.global_position
		)


func _on_popup_dismissed() -> void:
	_pending_level_ups -= 1
	_advance_popup_queue()


func _advance_popup_queue() -> void:
	if _pending_level_ups > 0:
		_show_next_level_up()
		return
	if not _special_queue.is_empty():
		_show_next_special()
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


## Roll the dead monster's drop table and scatter tier-tinted drops around
## the corpse so they never hide under the XP orb.
func _spawn_loot(enemy: Enemy) -> void:
	var table: Dictionary = _drop_tables.get(enemy.monster_id, {})
	for loot_id: String in Loot.roll_drops(table, _loot_rng):
		var drop: LootDrop = _loot_pool.acquire()
		var scatter := Vector2(
			_loot_rng.randf_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX),
			_loot_rng.randf_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX)
		)
		drop.launch_loot(
			enemy.global_position + scatter, loot_id,
			Loot.tier_color(_loot_data, loot_id), _player, _orb_config
		)


## Ordinary materials bank silently; special ones queue the 3-choice screen.
func _on_loot_collected(orb: XpOrb) -> void:
	var loot_id: String = (orb as LootDrop).loot_id
	_loot_pool.release(orb)
	if bool((_loot_data.get(loot_id, {}) as Dictionary).get("special", false)):
		_special_queue.append(loot_id)
		if not _popup.visible:
			_advance_popup_queue()
		return
	_run_state.inventory = Loot.add(_run_state.inventory, loot_id)


func _create_loot_drop() -> LootDrop:
	var drop := LootDrop.new()
	drop.collected.connect(_on_loot_collected)
	return drop


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
