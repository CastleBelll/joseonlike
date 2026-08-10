extends Node
## Manual balance telemetry harness for Bamboo Forest. Not part of the automated
## suite (run_tests.gd only discovers test_*.gd) and never loaded by the game.
##
##   godot --headless --path . tests/combat/soak_harness.tscn --fixed-fps 60 --quit-after 55000
##   ... -- greedy     drive one weapon + its evolution passive
##   ... -- forceevo   seed the evolutions.json thresholds, to exercise the swap
##
## --fixed-fps makes the engine advance a fixed 1/60s per iteration as fast as
## the CPU allows, so a 10-minute run measures in a few minutes of wall clock.
##
## print() is deliberate here and is the reason this file exists: it is a
## measurement tool whose output is the deliverable. No shipped code path
## prints.

const STAGE_SCENE: PackedScene = preload("res://scenes/combat/stage.tscn")
const CHARACTER_ID := "taoist"
const STAGE_ID := "bamboo_forest"
const SAMPLE_SEC := 60.0
const DEFAULT_SEED := 20260810
const EVOLUTIONS_PATH := "res://data/evolutions.json"

var _stage: Node = null
var _rng := RandomNumberGenerator.new()
var _cleared_hp: float = 0.0
var _cleared_hp_at_sample: float = 0.0
var _kills_at_sample: int = 0
var _next_sample: float = SAMPLE_SEC
var _damage_taken: float = 0.0
var _damage_at_sample: float = 0.0
var _boss_spawn_sec: float = -1.0
var _boss_kill_sec: float = -1.0
var _levelups: int = 0
var _evolutions: Array[String] = []
var _clock: float = 0.0
var _pool_min: int = 99
var _pool_counts: Dictionary = {}
var _empty_weapon_new_levels: int = 0
var _rules: Dictionary = {}
var _closest: Dictionary = {}


func _ready() -> void:
	_rng.seed = _seed_from_args()
	print("SOAK seed=%d" % _rng.seed)
	if GameData.load_all() != OK:
		print("SOAK: data load failed")
		get_tree().quit(1)
		return
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.level_reached.connect(_on_level_reached)
	EventBus.weapon_evolved.connect(_on_weapon_evolved)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.run_ended.connect(_on_run_ended)
	_rules = _load_rules()
	RunState.begin(CHARACTER_ID, STAGE_ID)
	if OS.get_cmdline_user_args().has("forceevo"):
		# Seed the evolutions.json thresholds for bow + attack_speed directly, so
		# the next natural level-up exercises the real evolution trigger.
		for _i in 5:
			RunState.grant_weapon("bow")
		for _i in 3:
			RunState.grant_passive("attack_speed")
		print("SOAK seeded %s %s" % [RunState.weapons, RunState.passives])
	_stage = STAGE_SCENE.instantiate()
	add_child(_stage)
	print("SOAK: start weapons=%s" % [RunState.weapons])


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_clock += delta
	_kite()
	_sample_boss()
	if _clock >= _next_sample:
		_sample()
		_next_sample += SAMPLE_SEC


## Player model: back off when something is in melee range, otherwise walk to
## the nearest XP orb. A player who only ever flees never picks XP up, which
## would understate the level curve; a player who ignores enemies dies early.
const FLEE_RADIUS_PX := 110.0

func _kite() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var adapter: Node = player.get_node_or_null(^"PlayerInput")
	if adapter == null:
		return

	var threat: Vector2 = _nearest_offset(player, get_tree().get_nodes_in_group(&"enemy"))
	if threat != Vector2.INF and threat.length() < FLEE_RADIUS_PX:
		adapter.set_drag_vector(threat.normalized())
		return

	var orb: Vector2 = _nearest_offset(player, _orbs())
	if orb != Vector2.INF:
		adapter.set_drag_vector(-orb.normalized())
		return

	adapter.set_drag_vector(Vector2.RIGHT.rotated(_clock))


func _orbs() -> Array[Node]:
	var found: Array[Node] = []
	var pickups: Node = _stage.get_node_or_null(^"Pickups")
	if pickups == null:
		return found
	for child in pickups.get_children():
		found.append(child)
	return found


## Offset from the nearest node to the player, or Vector2.INF when the list is empty.
func _nearest_offset(player: Node2D, nodes: Array[Node]) -> Vector2:
	var best := Vector2.INF
	var best_sq := INF
	for node in nodes:
		var node2d: Node2D = node as Node2D
		if node2d == null:
			continue
		var offset: Vector2 = player.global_position - node2d.global_position
		var d: float = offset.length_squared()
		if d < best_sq:
			best_sq = d
			best = offset
	return best


func _sample() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var hp: float = float(player.get(&"hp")) if player != null else -1.0
	var max_hp: float = float(player.get(&"max_hp")) if player != null else -1.0
	var alive: int = get_tree().get_nodes_in_group(&"enemy").size()
	print("SOAK min=%d level=%d kills=%d (+%d) clearedHP=%.0f (+%.0f => %.2f hp/s) hp=%.0f/%.0f dmg_taken=+%.0f alive=%d weapons=%s passives=%s" % [
		int(round(_clock / SAMPLE_SEC)),
		RunState.level,
		RunState.kills,
		RunState.kills - _kills_at_sample,
		_cleared_hp,
		_cleared_hp - _cleared_hp_at_sample,
		(_cleared_hp - _cleared_hp_at_sample) / SAMPLE_SEC,
		hp, max_hp,
		_damage_taken - _damage_at_sample,
		alive,
		_loadout(),
		RunState.passives,
	])
	_kills_at_sample = RunState.kills
	_cleared_hp_at_sample = _cleared_hp
	_damage_at_sample = _damage_taken


func _loadout() -> Array:
	var out: Array = []
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return out
	for weapon in player.call(&"weapons"):
		out.append("%s@%d" % [weapon.weapon_id, weapon.level])
	return out


func _on_enemy_killed(monster_id: String, _position: Vector2) -> void:
	_cleared_hp += float(GameData.monster(monster_id).get("hp", 0.0))


func _on_player_damaged(amount: float, _hp_left: float) -> void:
	_damage_taken += amount


func _on_level_reached(level: int, choices: Array[Dictionary]) -> void:
	_levelups += 1
	if choices.is_empty():
		return
	# Agnostic player: uniform pick among the offered options, matching the
	# model data/BALANCE.md uses.
	_record_pool(level, choices)
	_record_closest()
	var pick: Dictionary = _choose(choices)
	_pick.call_deferred(String(pick.get("id", "")), level)


## Agnostic: uniform pick (the model data/BALANCE.md assumes).
## Greedy (pass "-- greedy"): drive one weapon and its evolution passive to the
## evolutions.json thresholds, to prove the evolution trigger actually fires.
const GREEDY_PRIORITY: Array[String] = ["bow", "attack_speed", "attack_damage"]

func _choose(choices: Array[Dictionary]) -> Dictionary:
	if OS.get_cmdline_user_args().has("greedy"):
		for wanted: String in GREEDY_PRIORITY:
			for choice: Dictionary in choices:
				if String(choice.get("id", "")) == wanted:
					return choice
	return choices[_rng.randi_range(0, choices.size() - 1)]


func _pick(choice_id: String, level: int) -> void:
	print("SOAK levelup=%d t=%.1f pick=%s" % [level, _clock, choice_id])
	EventBus.upgrade_chosen.emit(choice_id)


func _on_weapon_evolved(from_id: String, to_id: String) -> void:
	_evolutions.append("%s->%s@%.1fs" % [from_id, to_id, _clock])
	print("SOAK EVOLVED %s -> %s at t=%.1f" % [from_id, to_id, _clock])


var _boss: Node2D = null
var _boss_next_sample: float = 0.0

func _on_boss_spawned(boss_id: String) -> void:
	_boss_spawn_sec = _clock
	_boss_next_sample = _clock + 10.0
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if String(enemy.get(&"monster_id")) == boss_id:
			_boss = enemy as Node2D
	print("SOAK BOSS SPAWNED %s at t=%.1f hp=%.0f" % [boss_id, _clock, float(_boss.get(&"hp")) if _boss != null else -1.0])


func _sample_boss() -> void:
	if _boss == null or not is_instance_valid(_boss) or _clock < _boss_next_sample:
		return
	_boss_next_sample += 10.0
	print("SOAK boss t=%.1f (+%.1fs) hp=%.0f" % [_clock, _clock - _boss_spawn_sec, float(_boss.get(&"hp"))])


func _on_boss_defeated(boss_id: String) -> void:
	_boss_kill_sec = _clock
	print("SOAK BOSS DEFEATED %s at t=%.1f (ttk=%.1f)" % [boss_id, _clock, _clock - _boss_spawn_sec])


func _on_run_ended(result: Dictionary) -> void:
	print("SOAK RUN_ENDED payload=%s" % [result])
	print("SOAK totals levelups=%d evolutions=%s clearedHP=%.0f dmg_taken=%.0f RunState.kills=%d RunState.level=%d" % [
		_levelups, _evolutions, _cleared_hp, _damage_taken, RunState.kills, RunState.level,
	])
	_report_pool_and_closest()
	_report_router.call_deferred()


func _report_router() -> void:
	print("SOAK SceneRouter.last_result=%s" % [SceneRouter.last_result])


## --- question 4: is the weapon_new pool starved by evolution_only? ----------

func _seed_from_args() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			return int(arg.substr(5))
	return DEFAULT_SEED


func _record_pool(level: int, choices: Array[Dictionary]) -> void:
	var by_kind: Dictionary = {}
	for choice: Dictionary in choices:
		var kind: String = String(choice.get("kind", "?"))
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
	_pool_min = mini(_pool_min, choices.size())
	for kind: Variant in by_kind.keys():
		_pool_counts[kind] = int(_pool_counts.get(kind, 0)) + int(by_kind[kind])
	if not by_kind.has("weapon_new"):
		_empty_weapon_new_levels += 1
	var flag: String = "  THIN" if choices.size() < 3 else ""
	print("SOAK pool level=%d offered=%d %s%s" % [level, choices.size(), by_kind, flag])


## --- question 2: if no evolution fires, how close did the run get? ----------

func _load_rules() -> Dictionary:
	if not FileAccess.file_exists(EVOLUTIONS_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(EVOLUTIONS_PATH)) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}


## Tracks the best progress toward every evolutions.json rule, so a negative
## result reports "one stack short" instead of just "it did not fire".
func _record_closest() -> void:
	for rule_key: Variant in _rules.keys():
		var rule: Dictionary = _rules[rule_key]
		var weapon_id: String = String(rule.get("requires_weapon", ""))
		var passive_id: String = String(rule.get("requires_passive", ""))
		var need_level: int = int(rule.get("min_weapon_level", 1))
		var need_stacks: int = int(rule.get("min_passive_stacks", 1))
		var have_level: int = RunState.weapon_level(weapon_id)
		var have_stacks: int = RunState.passive_stacks(passive_id)
		# Distance to the rule, counted in picks still required.
		var gap: int = maxi(need_level - have_level, 0) + maxi(need_stacks - have_stacks, 0)
		var prior: Dictionary = _closest.get(rule_key, {"gap": 999})
		if gap >= int(prior["gap"]):
			continue
		_closest[rule_key] = {
			"gap": gap,
			"text": "%s@%d/%d + %s x%d/%d at t=%.0f" % [
				weapon_id, have_level, need_level, passive_id, have_stacks, need_stacks, _clock,
			],
		}


func _report_pool_and_closest() -> void:
	print("SOAK pool_summary min_offered=%d totals=%s levels_without_weapon_new=%d" % [
		_pool_min, _pool_counts, _empty_weapon_new_levels,
	])
	for rule_key: Variant in _closest.keys():
		print("SOAK closest %s: gap=%d %s" % [rule_key, int(_closest[rule_key]["gap"]), _closest[rule_key]["text"]])
