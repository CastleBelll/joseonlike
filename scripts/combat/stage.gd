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
# N7-1: the capped permanent 명부수 bonus, computed ONCE in _ready — the only
# meta input the run ever reads, so tree effects cannot double-apply.
var _meta_effects: Dictionary = {}
# N7-2: meta_tree.json config block (revive ratio, first-find timing) and the
# one-shot revive latch — 회생부 fires at most once per run.
var _meta_config: Dictionary = {}
var _revive_used: bool = false
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

# N4-1 loot state: data tables, pooled drops, run-seeded RNG. N4-6: weapons
# a mod replaced this run — banned from every choice pool for good.
var _loot_data: Dictionary = {}
var _drop_tables: Dictionary = {}
var _mods_data: Dictionary = {}
var _loot_pool: NodePool
var _loot_rng := RandomNumberGenerator.new()
var _replaced_weapons: Array[String] = []

# N3-8 feedback + N5-1 run flow state.
var _feedback: Dictionary = {}
var _puff_pool: NodePool
# N3-17 art integration: pooled sprite puffs for 축지 when the sheet shipped.
var _fx_pool: NodePool
var _gold: int = 0
var _run_elapsed: float = 0.0
var _duration_sec: float = 0.0
var _boss: Enemy
var _boss_hp_max: float = 0.0
var _outcome: String = RunFlow.OUTCOME_NONE
var _result: ResultScreen

# N4-4b actives: data entries from characters.json plus per-id cooldown left.
var _actives: Array[Dictionary] = []
var _active_cooldowns: Dictionary = {}

# N6-1 FTUE state: the one-shot move hint node (null once dismissed or for a
# returning profile) and the first-run guarantee table from stages.json —
# _first_run_log maps each guaranteed loot_id to the second it first dropped.
var _move_hint: MoveHint
var _first_run_drops: Array = []
var _first_run_log: Dictionary = {}
# N6-2: a guaranteed first-run drop lands ahead of the player (data offset),
# not on the corpse — something to walk toward and see, not receive.
var _guarantee_offset_px: float = 0.0


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
	# N4-4a: burn ticks float through the same damage-number pool as hits.
	_spawner.burn_damaged.connect(
		func(amount: float, at: Vector2) -> void: _on_hit_landed(amount, at, false)
	)
	_feedback = _load_json(Spawner.EFFECTS_PATH).get("hit_feedback", {})
	var stage_entry: Dictionary = _load_json(Spawner.STAGES_PATH).get(Spawner.STAGE_ID, {})
	_duration_sec = float(stage_entry.get("duration_sec", 0.0))
	_puff_pool = NodePool.new(self, _create_puff)
	if EffectSprite.available("blink_puff"):
		_fx_pool = NodePool.new(self, _create_effect_sprite)
	_result = ResultScreen.new()
	add_child(_result)
	_run_state = RunState.new()
	_run_state.level_reached.connect(_on_level_reached)
	_orb_config_base = RunState.load_orb_config()
	_orb_config = _orb_config_base.duplicate()
	var meta_data: Dictionary = MetaTree.load_tree()
	var meta_clean: Dictionary = MetaTree.sanitize_state(
		meta_data, _profile().get("meta_tree", {}) as Dictionary
	)
	if int(meta_clean["dropped"]) > 0:
		push_warning(
			"stage: dropped %d invalid meta_tree entries" % int(meta_clean["dropped"])
		)
	# N7-2: only the trunk plus the SELECTED character's branch apply here —
	# another character's branch must never leak into this run.
	_meta_effects = MetaTree.aggregate_effects(
		meta_data, meta_clean["state"] as Dictionary,
		String(_profile().get("selected_character", SaveProfile.DEFAULT_CHARACTER))
	)
	_meta_config = meta_data.get("config", {})
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
	# N7-1 one-shot meta application: scalars fold into the shared refresh
	# below; the flat HP grant lands here exactly once per run.
	_refresh_run_scalars()
	var meta_hp_grant: float = Player.load_base_hp() * _meta_bonus("max_hp")
	_player.hp += meta_hp_grant
	_player.hp_max += meta_hp_grant
	# N7-2 survivability nodes: capped damage reduction (철피) and the longer
	# post-hit invulnerability window (긴 호흡), each applied exactly once.
	_player.set_damage_taken_scale(1.0 - _meta_bonus("damage_reduction"))
	_player.set_invuln_scale(1.0 + _meta_bonus("hit_invuln"))
	_popup = LevelUpPopup.new()
	_popup.picked.connect(_on_choice_picked)
	_popup.dismissed.connect(_on_popup_dismissed)
	add_child(_popup)
	_hud.set_gold(0)  # run gold; banked into the profile at run end (N5-2)
	_actives = Player.load_actives()
	for active: Dictionary in _actives:
		_active_cooldowns[String(active.get("id", ""))] = 0.0
	_hud.build_actives(_actives)
	_hud.active_pressed.connect(_on_active_pressed)
	_refresh_progress_hud()
	# N7-2 조기 수행: a banked head start grants its levels — and their power-up
	# screens — right now, before the first wave lands.
	for i: int in range(int(_meta_bonus("start_level"))):
		_run_state.add_xp(_run_state.xp_needed())
	# N6-1 FTUE: the scripted first-run drop table only arms on a profile that
	# has never finished a run, and the move hint only until first dismissal.
	var profile: Dictionary = _profile()
	if Ftue.is_first_run(profile):
		_first_run_drops = stage_entry.get("first_run_drops", [])
		_guarantee_offset_px = float(
			(stage_entry.get("opening", {}) as Dictionary).get("guarantee_offset_px", 0.0)
		)
	if Ftue.should_show_move_hint(profile):
		_move_hint = MoveHint.new()
		_move_hint.name = "MoveHint"
		_move_hint.target = _joystick
		$Hud.add_child(_move_hint)
	# N7-2 첫 인연: every run guarantees one special material early, through the
	# same guarantee pipeline the FTUE table uses (data timing, run-seeded pick).
	if int(_meta_bonus("first_find")) >= 1:
		_arm_first_find()


## Appends the 첫 인연 guarantee to the run's guarantee table: one random
## special material, due at the data-configured second.
func _arm_first_find() -> void:
	var special_ids: Array[String] = []
	for loot_id: String in _loot_data:
		if bool((_loot_data[loot_id] as Dictionary).get("special", false)):
			special_ids.append(loot_id)
	if special_ids.is_empty():
		return
	var at_sec: float = float(
		(_meta_config.get("first_find", {}) as Dictionary).get("at_sec", 0.0)
	)
	_first_run_drops = _first_run_drops.duplicate()
	_first_run_drops.append({
		"loot_id": special_ids[_loot_rng.randi_range(0, special_ids.size() - 1)],
		"at_sec": at_sec,
	})


func _physics_process(delta: float) -> void:
	_player.joystick_input = _joystick.output
	if _move_hint != null and (
		_joystick.output != Vector2.ZERO
		or Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO
	):
		_dismiss_move_hint()
	_run_elapsed += delta
	_refresh_hp_hud()
	if _duration_sec > 0.0 and _run_elapsed >= _duration_sec:
		_end_run(RunFlow.resolve_outcome(false, false, true))
	if _boss != null and not CombatMath.is_dead(_boss.hp):
		_hud.set_boss_hp(_boss.hp, _boss_hp_max)
	for active: Dictionary in _actives:
		var active_id: String = String(active.get("id", ""))
		var left: float = maxf(float(_active_cooldowns[active_id]) - delta, 0.0)
		_active_cooldowns[active_id] = left
		_hud.set_active_cooldown(active_id, ActiveSkill.cooldown_fraction(
			left, float(active.get("cooldown_sec", 0.0))
		))


## First movement input retires the hint for good (N6-1): the flag persists
## immediately so a crash later in the run cannot bring it back.
func _dismiss_move_hint() -> void:
	_move_hint.queue_free()
	_move_hint = null
	if SaveService.instance != null:
		SaveService.instance.mark_move_hint_seen()


## N5-4 괴이록 funnel: null-guarded so demo tools without the autoload run;
## SaveService only writes on a genuinely new discovery.
func _record_discovery(kind: String, id: String) -> void:
	if SaveService.instance != null:
		SaveService.instance.record_discovery(kind, id)


## The live profile, or the default shape in node-free tests and demo tools
## that boot the stage without the SaveManager autoload.
func _profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _on_player_died() -> void:
	# N7-2 회생부: once per run, the killing blow becomes a second wind instead
	# of the result screen — visible as the HP refill plus the float label.
	var revive: Dictionary = _meta_config.get("revive", {})
	var revive_ratio: float = float(revive.get("hp_ratio", 0.0))
	if not _revive_used and int(_meta_bonus("revive")) >= 1 and revive_ratio > 0.0:
		_revive_used = true
		_player.hp = _player.hp_max * revive_ratio
		_player.grant_invulnerability(float(revive.get("invuln_sec", 0.0)))
		_float_label("회생부 발동!")
		return
	_end_run(RunFlow.resolve_outcome(true, false, false))


## N3-8: the invulnerability blink lives on the player; the HUD adds the
## screen-edge red pulse so a hit is legible even off-center.
func _on_player_hit() -> void:
	_hud.pulse_damage(float(_feedback.get("player_vignette_sec", 0.0)))


## The enemy reference is only valid during this synchronous call — it goes
## back to its pool right after (see Spawner.enemy_killed).
func _on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	_record_discovery(Bestiary.KIND_MONSTERS, enemy.monster_id)
	_add_gold(enemy.gold_drop)
	_hud.set_kills(_kills)
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
	# A timeout victory leaves the boss alive — its HP bar must not sit on top
	# of the result screen (QA-1).
	_hud.hide_boss_bar()
	# A run ending mid shockwave-punch would freeze the camera slightly zoomed
	# for the whole result screen (physics stops while paused) — reset first.
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.zoom = Vector2.ONE
	get_tree().paused = true
	var summary: Dictionary = RunFlow.build_summary(
		_run_elapsed, _kills, _gold, _player.last_hit_source
	)
	summary["total_gold"] = SaveService.instance.bank_run(_run_elapsed, _kills, _gold, boss_killed)
	_result.open(outcome, summary)


## N4-4b active trigger: the HUD button is display-only — this is the
## authoritative cooldown gate (CombatMath window rule, boundary inclusive).
func _on_active_pressed(active_id: String) -> void:
	if float(_active_cooldowns.get(active_id, 0.0)) > 0.0:
		return
	for active: Dictionary in _actives:
		if String(active.get("id", "")) != active_id:
			continue
		_execute_active(active)
		_active_cooldowns[active_id] = float(active.get("cooldown_sec", 0.0))
		return


## Effects live here so demo tools can fire them without touching cooldowns.
func _execute_active(active: Dictionary) -> void:
	match String(active.get("type", "")):
		"blink":
			_execute_blink(active)
		"burst":
			_execute_burst(active)
		_:
			push_error("stage: unknown active type in " + str(active))


## 축지: blink along the movement direction, stopped at the first solid prop
## and clamped to the field, plus a short invulnerability window.
func _execute_blink(active: Dictionary) -> void:
	var from: Vector2 = _player.global_position
	var direction: Vector2 = _player.last_move_direction
	var distance: float = float(active.get("distance_px", 0.0))
	var blocked_at: float = INF
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * distance)
	query.collision_mask = StageField.LAYER_OBSTACLE
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Stop a body-width short of the prop face. ponytail: a center ray can
		# graze past a narrow corner; the body's own collision catches it next
		# frame — full shape cast if that ever reads wrong in play.
		blocked_at = from.distance_to(hit["position"]) - Player.CONTACT_RADIUS
	_player.global_position = ActiveSkill.blink_destination(
		from, direction, distance, blocked_at, _player.bounds
	)
	_player.grant_invulnerability(float(active.get("invulnerable_sec", 0.0)))
	# N3-17: a puff at BOTH ends so the departure and the arrival read. The
	# desaturated smoke sheet plays tinted to the taoist accent when shipped;
	# the code-drawn ring puff is the fallback.
	_blink_puff(from)
	_blink_puff(_player.global_position)


## 벽사진: the emergency button — heavy damage to everything in a large ring
## around the player, through the normal damage-number pipeline.
func _execute_burst(active: Dictionary) -> void:
	var origin: Vector2 = _player.global_position
	var radius: float = float(active.get("radius_px", 0.0))
	var damage: float = float(active.get("damage", 0.0))
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(origin, radius, WeaponEffects.value("screen_flash_sec"), UiPalette.GOLD)
	# N3-17: the emergency button reads across the whole screen, not just a ring.
	_hud.flash_screen(UiPalette.GOLD, WeaponEffects.value("screen_flash_sec"))
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	# Collect refs first: striking mutates the spawner's active list.
	var caught: Array[Enemy] = []
	for i: int in WeaponMath.targets_in_radius(origin, positions, radius):
		caught.append(enemies[i])
	for enemy: Enemy in caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(damage, CombatMath.chase_direction(origin, hit_at))
		_on_hit_landed(damage, hit_at, boss_hit)


func _on_orb_collected(orb: XpOrb) -> void:
	# N7-2 문리: the xp_gain meta bonus scales every orb at pickup.
	_run_state.add_xp(int(round(float(orb.xp_value) * (1.0 + _meta_bonus("xp_gain")))))
	_refresh_progress_hud()
	_orb_pool.release(orb)


func _refresh_progress_hud() -> void:
	_hud.set_level(_run_state.level)
	_hud.set_xp(_run_state.xp, _run_state.xp_needed())


## N6-2: HUD HP bar + low-HP warning, every physics frame — covers hits,
## max-HP passives and the meta grant through one path. Numbers from data.
func _refresh_hp_hud() -> void:
	_hud.set_hp(
		_player.hp, _player.hp_max,
		float(_feedback.get("low_hp_threshold", 0.0)),
		float(_feedback.get("low_hp_pulse_sec", 0.0))
	)


func _on_hit_landed(amount: float, at: Vector2, boss_hit: bool) -> void:
	var number: DamageNumber = _number_pool.acquire()
	number.show_amount(amount, at, boss_hit)


func _on_number_finished(number: DamageNumber) -> void:
	_number_pool.release(number)


## One grant can cross several levels; each one earns a choice screen — the
## only tap a run asks for (DESIGN.md §5.2). Loot never opens a panel (N4-6).
func _on_level_reached(_new_level: int) -> void:
	_pending_level_ups += 1
	if not _popup.visible:
		_advance_popup_queue()


func _show_next_level_up() -> void:
	get_tree().paused = true
	var pool: Array[Dictionary] = LevelUp.candidates(
		_weapons_data, _passives_data, _owned_levels, _passive_stacks,
		_owned_grades, _grades_config, _replaced_weapons
	)
	var mod_pool: Array[Dictionary] = LevelUp.mod_candidates(
		_mods_data, _run_state.inventory, _owned_levels, _replaced_weapons
	)
	# N7-2 혜안: the choice_count meta bonus widens every level-up screen.
	var choices: Array[Dictionary] = LevelUp.assemble(
		pool, mod_pool, CHOICES_PER_LEVEL + int(_meta_bonus("choice_count")), _choice_rng
	)
	var cards: Array[Dictionary] = []
	for choice: Dictionary in choices:
		cards.append(LevelUp.as_card(
			choice, _weapons_data, _passives_data, _owned_levels, _passive_stacks,
			_owned_grades, _grades_config
		))
	# N6-1: the very first 개조 card a profile ever sees carries one extra
	# explanation line — same card, same single tap, never again.
	if Ftue.should_explain_mod(_profile()):
		var explained: Dictionary = Ftue.explain_mod_cards(cards)
		cards = explained["cards"]
		if bool(explained["explained"]) and SaveService.instance != null:
			SaveService.instance.mark_mod_explained()
	_popup.open(POWER_UP_HEADER, cards, _owned_levels, _weapons_data)


func _on_choice_picked(payload: Dictionary) -> void:
	match String(payload.get("kind", "")):
		LevelUp.KIND_NEW_WEAPON, LevelUp.KIND_WEAPON_UP, LevelUp.KIND_PASSIVE, \
		LevelUp.KIND_GRADE_UP:
			_apply_level_up_choice(payload)
		LevelUp.KIND_MOD:
			var mod: Dictionary = payload.get("mod", {})
			_run_state.inventory = Loot.spend(
				_run_state.inventory, String(mod.get("loot_id", ""))
			)
			_apply_weapon_mod(mod)
		_:
			push_error("stage: unknown popup payload " + str(payload))
	_pending_level_ups -= 1
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


## Swap the owned base weapon node for the recipe result, carrying its level.
## N4-2: the run grade carries too (GDD §33), floored at the result weapon's
## own base grade — a mod can raise the grade, never lower it. N4-6: the base
## weapon is banned from every future choice pool, and materials whose every
## recipe just died cash out to gold.
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
	_replaced_weapons.append(base_id)
	var sweep: Dictionary = Loot.salvage_dead(
		_run_state.inventory, _loot_data, _mods_data, _owned_levels, _replaced_weapons
	)
	_run_state.inventory = sweep["inventory"]
	if int(sweep["gold"]) > 0:
		_add_gold(int(sweep["gold"]))


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
		_float_label("%s %s 등급!" % [
			String((_weapons_data.get(weapon_id, {}) as Dictionary).get("name_ko", weapon_id)),
			String(LevelUp.GRADE_KO.get(grade, grade)),
		])


## Non-blocking floating cue in the damage-number style — never pauses,
## never asks for input (DESIGN.md §5.2).
func _float_label(text: String) -> void:
	var number: DamageNumber = _number_pool.acquire()
	number.show_text(text, _player.global_position)


func _on_popup_dismissed() -> void:
	_pending_level_ups -= 1
	_advance_popup_queue()


func _advance_popup_queue() -> void:
	if _pending_level_ups > 0:
		_show_next_level_up()
		return
	_popup.close()
	get_tree().paused = false


func _add_weapon_node(weapon_id: String) -> void:
	# N5-4: owning a weapon is its discovery — covers the starting weapon,
	# level-up picks and mod results (a completed mod) through one funnel.
	_record_discovery(Bestiary.KIND_WEAPONS, weapon_id)
	var weapon := AutoWeapon.new()
	add_child(weapon)
	weapon.setup(weapon_id, _player, _spawner, _meta_effects)
	weapon.hit_landed.connect(_on_hit_landed)
	_weapon_nodes[weapon_id] = weapon
	_refresh_weapon_scales()


func _passive_bonus(passive_id: String) -> float:
	var per_stack: float = float(
		(_passives_data.get(passive_id, {}) as Dictionary).get("per_stack", 0.0)
	)
	return per_stack * float(_passive_stacks.get(passive_id, 0))


func _meta_bonus(stat: String) -> float:
	return float(_meta_effects.get(stat, 0.0))


## N7-2 재물안: every run gold gain routes through here so the gold_gain meta
## bonus applies uniformly (kills, salvage, dead-material cash-outs).
## Returns the amount actually gained for cue labels.
func _add_gold(amount: int) -> int:
	var gained: int = int(round(float(amount) * (1.0 + _meta_bonus("gold_gain"))))
	_gold += gained
	_hud.set_gold(_gold)
	return gained


## Recompute every run-wide passive effect from the stack counts, then apply
## the one-shot effects for the stack that was just gained.
func _apply_passive_effects(gained_id: String) -> void:
	_refresh_run_scalars()
	# Max HP has no separate cap yet; each stack grants its slice of base HP.
	if gained_id == "max_hp":
		var per_stack: float = float(
			(_passives_data.get("max_hp", {}) as Dictionary).get("per_stack", 0.0)
		)
		var grant: float = Player.load_base_hp() * per_stack
		_player.hp += grant
		_player.hp_max += grant


## Every run-wide scalar recomputed from its data base, so neither passive
## stacks nor the meta bonus can ever compound with themselves.
func _refresh_run_scalars() -> void:
	_refresh_weapon_scales()
	_player.set_speed_scale(
		1.0 + _passive_bonus("move_speed") + _meta_bonus("move_speed")
	)
	_orb_config = _orb_config_base.duplicate()
	_orb_config["magnet_radius_px"] = (
		float(_orb_config_base.get("magnet_radius_px", 0.0))
		* (1.0 + _passive_bonus("magnet_radius") + _meta_bonus("magnet_radius"))
	)


func _refresh_weapon_scales() -> void:
	var damage_scale: float = 1.0 + _passive_bonus("attack_damage") + _meta_bonus("attack_damage")
	var cooldown_scale: float = 1.0 / (
		1.0 + _passive_bonus("attack_speed") + _meta_bonus("attack_speed")
	)
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
	var drops: Array[String] = Loot.roll_drops(table, _loot_rng)
	# N6-1 scripted first run: any overdue guarantee rides the next kill; a
	# natural drop of the same loot earlier satisfies it via _first_run_log.
	drops.append_array(Ftue.due_guarantees(_first_run_drops, _run_elapsed, _first_run_log))
	for loot_id: String in drops:
		var at: Vector2 = enemy.global_position
		if Ftue.is_guaranteed(_first_run_drops, loot_id) and not _first_run_log.has(loot_id):
			_first_run_log[loot_id] = _run_elapsed
			# N6-2: place the scripted guarantee ahead of the player's travel
			# direction, clamped to the field — seen and walked toward, never
			# landing in their lap at the corpse.
			if _guarantee_offset_px > 0.0:
				at = _player.global_position + _player.last_move_direction * _guarantee_offset_px
				if _player.bounds.has_area():
					at = at.clamp(_player.bounds.position, _player.bounds.end)
		var drop: LootDrop = _loot_pool.acquire()
		var scatter := Vector2(
			_loot_rng.randf_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX),
			_loot_rng.randf_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX)
		)
		drop.launch_loot(
			at + scatter, loot_id,
			Loot.tier_color(_loot_data, loot_id), _player, _orb_config
		)


## N4-6: every material collects silently, exactly like XP and gold. Useful
## ones (a live recipe exists) bank into the run inventory; dead ones cash
## out to gold on the spot — the player never holds dead inventory. Special
## materials float a small cue label; commons just tick the counters.
func _on_loot_collected(orb: XpOrb) -> void:
	var loot_id: String = (orb as LootDrop).loot_id
	_loot_pool.release(orb)
	_record_discovery(Bestiary.KIND_LOOT, loot_id)
	var stats: Dictionary = _loot_data.get(loot_id, {})
	if Loot.is_material_useful(loot_id, _mods_data, _owned_levels, _replaced_weapons):
		_run_state.inventory = Loot.add(_run_state.inventory, loot_id)
		if bool(stats.get("special", false)):
			_float_label("%s 획득" % String(stats.get("name_ko", loot_id)))
		return
	var gained: int = _add_gold(Loot.salvage_gold(_loot_data, loot_id))
	if bool(stats.get("special", false)):
		_float_label("엽전 +%d" % gained)


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


func _blink_puff(at: Vector2) -> void:
	if _fx_pool != null:
		var sprite: EffectSprite = _fx_pool.acquire()
		sprite.play_effect("blink_puff", at, 0.0, UiPalette.ACCENT_TAOIST)
		return
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		at, Player.CONTACT_RADIUS * 2.0,
		WeaponEffects.value("blink_puff_sec"), UiPalette.ACCENT_TAOIST
	)


func _create_effect_sprite() -> EffectSprite:
	var sprite := EffectSprite.new()
	sprite.finished_effect.connect(
		func(done: EffectSprite) -> void: _fx_pool.release(done)
	)
	return sprite


func _create_puff() -> DeathPuff:
	var puff := DeathPuff.new()
	puff.finished.connect(
		func(done: DeathPuff) -> void: _puff_pool.release(done)
	)
	return puff
