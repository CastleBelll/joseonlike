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
	var run_seed: int = _seed_from_args()
	_rng.seed = run_seed
	# Crit rolls and spawn placement too, or the run is not reproducible and
	# a boss-only change can appear to move a death five minutes earlier.
	CombatRng.begin_deterministic(run_seed)
	print("SOAK seed=%d" % run_seed)
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
	_audio_trace = OS.get_cmdline_user_args().has("audio")
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
	var drops: Node = _stage.get_node_or_null(^"Drops")
	if drops != null:
		drops.drop_collected.connect(_on_drop_collected)
	print("SOAK: start weapons=%s" % [RunState.weapons])


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_clock += delta
	_kite()
	_sample_boss()
	_observe_effects()
	_observe_orientation()
	_observe_drops()
	_observe_audio()
	_trace_motion()
	_sample_presentation()
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
	# Drops moved from the Pickups node to the pooled Drops node.
	var pickups: Node = _stage.get_node_or_null(^"Drops")
	if pickups == null:
		return found
	for child in pickups.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null and sprite.visible:
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
	_report_effects()
	_report_orientation()
	_report_drops()
	_report_audio()
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
	_report_effects()
	_report_audio()
	_report_death_state(result)
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


var _presentation_reported: bool = false

## One-shot audit that the art actually reached the tree: ground texture and
## region, the players authored rotation and its whole-pixel offset, and the
## textures on live projectile and melee VFX.
func _sample_presentation() -> void:
	if _presentation_reported or _clock < 3.0:
		return
	_presentation_reported = true
	var ground: Sprite2D = _stage.get_node_or_null(^"Ground") as Sprite2D
	if ground != null:
		print("SOAK ground texture=%s size=%s repeat=%d region=%s z=%d" % [
			ground.texture.resource_path if ground.texture != null else "<null>",
			ground.texture.get_size() if ground.texture != null else Vector2.ZERO,
			ground.texture_repeat, ground.region_rect.size, ground.z_index,
		])
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		var sprite: Sprite2D = player.get_node_or_null(^"Sprite2D") as Sprite2D
		if sprite != null:
			print("SOAK player texture=%s offset=%s integer=%s scale=%s rot=%.1f" % [
				sprite.texture.resource_path if sprite.texture != null else "<null>",
				sprite.position,
				sprite.position == sprite.position.round(),
				sprite.scale, sprite.rotation,
			])
	var projectiles: Node = _stage.get_node_or_null(^"Projectiles")
	if projectiles == null:
		return
	for child in projectiles.get_children():
		var vfx: Node = child.get_node_or_null(^"Sprite2D")
		if vfx == null:
			vfx = child.get_node_or_null(^"Visual")
		var texture: Texture2D = vfx.get(&"texture") if vfx != null else null
		print("SOAK vfx %s node=%s texture=%s" % [
			child.get_class(), vfx.name if vfx != null else "<none>",
			texture.resource_path if texture != null else "<placeholder>",
		])


## --- motion trace: is the walk cycle running, or just invisible? ------------

const MOTION_TRACE_START_SEC: float = 2.0
const MOTION_TRACE_END_SEC: float = 5.0

var _motion_frames: int = 0
var _motion_offsets_seen: Dictionary = {}
var _motion_rotations_seen: Dictionary = {}
var _motion_walking_frames: int = 0
var _motion_trace_done: bool = false


## Logs the real sprite offset and rotation every physics frame for a few
## seconds of movement, so "the walk does not appear" can be answered with
## whether the values change rather than by eyeballing a headless run.
func _trace_motion() -> void:
	if _motion_trace_done or not OS.get_cmdline_user_args().has("motion"):
		return
	if _clock < MOTION_TRACE_START_SEC:
		return
	if _clock > MOTION_TRACE_END_SEC:
		_motion_trace_done = true
		print("SOAK motion frames=%d walking_frames=%d distinct_offsets=%s rotations=%s" % [
			_motion_frames, _motion_walking_frames,
			_motion_offsets_seen.keys(), _motion_rotations_seen.keys(),
		])
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var sprite: Sprite2D = player.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite == null:
		return
	_motion_frames += 1
	var moving: bool = player.velocity.length_squared() > 0.0
	if moving:
		_motion_walking_frames += 1
	_motion_offsets_seen[str(sprite.position)] = true
	var rotation_name: String = ""
	if sprite.texture != null:
		rotation_name = sprite.texture.resource_path.get_file()
	_motion_rotations_seen[rotation_name] = true
	if _motion_frames % 6 == 0:
		print("SOAK motion t=%.2f moving=%s offset=%s rot=%s vel=%.0f" % [
			_clock, moving, sprite.position, rotation_name, player.velocity.length(),
		])


## Where the run stood when it ended.
##
## The weighted passive pool can only help a run that has already taken a weapon
## to its rule's min_weapon_level -- that is the condition the weighting keys on.
## A run that dies before then never draws against an evolution at all, and is a
## survivability problem rather than a pool problem. This reports which of the
## two each run was.
func _report_death_state(result: Dictionary) -> void:
	var eligible_rules: Array[String] = []
	var states: Array[String] = []
	for rule_key: Variant in _rules.keys():
		var rule: Dictionary = _rules[rule_key]
		var weapon_id: String = String(rule.get("requires_weapon", ""))
		var passive_id: String = String(rule.get("requires_passive", ""))
		var need_level: int = int(rule.get("min_weapon_level", 1))
		var need_stacks: int = int(rule.get("min_passive_stacks", 1))
		var have_level: int = RunState.weapon_level(weapon_id)
		var have_stacks: int = RunState.passive_stacks(passive_id)
		if have_level >= need_level:
			eligible_rules.append(String(rule_key))
		states.append("%s(%s %d/%d, %s %d/%d)" % [
			rule_key, weapon_id, have_level, need_level, passive_id, have_stacks, need_stacks,
		])
	print("SOAK death t=%.1f minute=%d level=%d levelups=%d victory=%s eligible=%s" % [
		_clock, int(ceil(_clock / SAMPLE_SEC)), RunState.level, _levelups,
		bool(result.get("victory", false)), eligible_rules,
	])
	print("SOAK death_state %s" % [states])


## Which effect sets actually played, read off the live pool sprites rather than
## from a counter inside production code.
var _effects_seen: Dictionary = {}
var _effect_peak: int = 0


func _observe_effects() -> void:
	var pool: Node = _stage.get_node_or_null(^"Effects")
	if pool == null:
		return
	_effect_peak = maxi(_effect_peak, int(pool.call(&"active_count")))
	for child in pool.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null or not sprite.visible or sprite.texture == null:
			continue
		var dir: String = sprite.texture.resource_path.get_base_dir()
		var label: String = dir.get_file()
		if label == "death" or label == "Death":
			label = "death:" + dir.get_base_dir().get_file()
		_effects_seen[label] = true


func _report_effects() -> void:
	print("SOAK effects seen=%s peak_concurrent=%d/%d" % [
		_effects_seen.keys(), _effect_peak, EffectPool.MAX_CONCURRENT_EFFECTS,
	])


## Direct evidence for the three things that can only be judged in a live run:
## travel art pointing along its velocity, swing art oriented to the swing, and
## monsters bobbing on whole pixels.
var _travel_samples: Array[String] = []
var _melee_samples: Array[String] = []
var _bob_offsets: Dictionary = {}


func _observe_orientation() -> void:
	var projectiles: Node = _stage.get_node_or_null(^"Projectiles")
	if projectiles != null:
		for child in projectiles.get_children():
			var sprite: Sprite2D = child.get_node_or_null(^"Sprite2D") as Sprite2D
			var heading: Variant = child.get(&"direction")
			if sprite != null and sprite.texture != null and heading is Vector2 and _travel_samples.size() < 6:
				var art: String = sprite.texture.resource_path.get_file()
				var delta: float = rad_to_deg(absf(angle_difference(sprite.rotation, (heading as Vector2).angle())))
				_travel_samples.append("%s heading=%.0fdeg sprite=%.0fdeg err=%.2fdeg" % [
					art, rad_to_deg((heading as Vector2).angle()), rad_to_deg(sprite.rotation), delta])
			var visual: Sprite2D = child.get_node_or_null(^"Visual") as Sprite2D
			var facing: Variant = child.get(&"facing")
			if visual != null and visual.texture != null and facing is Vector2 and _melee_samples.size() < 4:
				_melee_samples.append("%s facing=%.0fdeg sprite=%.0fdeg body=%.0fdeg" % [
					visual.texture.resource_path.get_file(), rad_to_deg((facing as Vector2).angle()),
					rad_to_deg(visual.rotation), rad_to_deg((child as Node2D).rotation)])
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		var esprite: Sprite2D = enemy.get_node_or_null(^"Sprite2D") as Sprite2D
		if esprite != null:
			_bob_offsets[str(esprite.position)] = true


func _report_orientation() -> void:
	for line in _travel_samples:
		print("SOAK travel %s" % line)
	for line in _melee_samples:
		print("SOAK melee  %s" % line)
	print("SOAK monster_bob offsets=%s" % [_bob_offsets.keys()])


## Which drop sets actually reached the ground, and which played their collect
## sequence rather than vanishing.
var _drop_idle_seen: Dictionary = {}
var _drop_collect_seen: Dictionary = {}
var _drop_peak: int = 0


func _observe_drops() -> void:
	var pool: Node = _stage.get_node_or_null(^"Drops")
	if pool == null:
		return
	_drop_peak = maxi(_drop_peak, int(pool.call(&"active_count")))
	for child in pool.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null or not sprite.visible or sprite.texture == null:
			continue
		var dir: String = sprite.texture.resource_path.get_base_dir()
		if dir.get_file() == "collect":
			_drop_collect_seen[dir.get_base_dir().get_file()] = true
		else:
			_drop_idle_seen[dir.get_file()] = true


func _report_drops() -> void:
	print("SOAK drops idle=%s collect=%s peak=%d" % [
		_drop_idle_seen.keys(), _drop_collect_seen.keys(), _drop_peak])


## --- pickup voice budget: does energy_sound survive the round-robin? ---------
##
## CombatAudio runs VOICE_COUNT voices round-robin and admits each distinct sound
## at most once per physics frame, so the voice taken by admitted play N is
## overwritten by admitted play N + VOICE_COUNT. The cut point is therefore pure
## arithmetic on the admitted-play timeline and needs no audio driver, which
## matters: --headless mixes through the dummy driver and playback positions
## there are not evidence about what a player hears.
##
## _played_this_frame is read one frame late on purpose. The harness is an
## ancestor of CombatAudio, so it runs first and sees the set before CombatAudio
## clears it — that is the previous frame's admissions. 16.7 ms against a 510 ms
## sound does not move any conclusion.
##
##   godot --headless --path . tests/combat/soak_harness.tscn --fixed-fps 60 \
##       --quit-after 620000 -- audio

const PICKUP_PATH: String = "res://asset/audio/sfx/energy_sound.wav"
## Measured length of energy_sound.wav, per the coordinator's brief.
const PICKUP_LENGTH_SEC: float = 0.510
const BURST_WINDOW_SEC: float = 1.0

var _audio_trace: bool = false
var _audio_node: Node = null
var _plays_total: int = 0
var _plays_by_sound: Dictionary = {}
var _collects: int = 0
var _pickup_plays: int = 0
## Pickup voices assigned but not yet proven finished or recycled.
var _pending_pickups: Array[Dictionary] = []
var _pickup_lifetimes: Array[float] = []
var _pickup_cut: int = 0
var _live_peak: int = 0
var _burst_run: int = 0
var _burst_run_max: int = 0
var _collect_stamps: Array[float] = []
var _collects_peak_window: int = 0
## Timestamps of the most recent VOICE_COUNT admissions, so the tightest window
## in which the whole pool turned over can be reported. That window is the real
## recycle interval; ASSET_SPEC's 0.13 s figure is the saturated case, not a
## measurement of this stage.
var _play_stamps: Array[float] = []
var _tightest_pool_turnover: float = INF
## Most admissions any one pickup voice had to survive. Cutting needs more than
## VOICE_COUNT; this counts the same headroom forwards from each pickup, so it
## and _tightest_pool_turnover must agree.
var _busiest_life: int = 0
## How many pickups survived exactly n admissions, so "0 cut" can be reported
## with its margin instead of as a bare pass.
var _life_histogram: Dictionary = {}


func _on_drop_collected(_xp_amount: int, _gold_amount: int) -> void:
	_collects += 1
	_collect_stamps.append(_clock)


func _observe_audio() -> void:
	if _audio_node == null:
		_audio_node = _stage.get_node_or_null(^"CombatAudio")
		if _audio_node == null:
			return

	while not _collect_stamps.is_empty() and _clock - _collect_stamps[0] > BURST_WINDOW_SEC:
		_collect_stamps.remove_at(0)
	_collects_peak_window = maxi(_collects_peak_window, _collect_stamps.size())

	var plays_before: int = _plays_total
	var admitted: Dictionary = _audio_node.get(&"_played_this_frame")
	var pickup_admitted: bool = false
	for path: Variant in admitted.keys():
		_plays_total += 1
		var name: String = String(path).get_file()
		_plays_by_sound[name] = int(_plays_by_sound.get(name, 0)) + 1
		if String(path) == PICKUP_PATH:
			pickup_admitted = true
		_play_stamps.append(_clock)
		if _play_stamps.size() > CombatAudio.VOICE_COUNT:
			_play_stamps.remove_at(0)
		if _play_stamps.size() == CombatAudio.VOICE_COUNT:
			_tightest_pool_turnover = minf(_tightest_pool_turnover, _clock - _play_stamps[0])

	if pickup_admitted:
		_pickup_plays += 1
		_burst_run += 1
		_burst_run_max = maxi(_burst_run_max, _burst_run)
		# Assume the pickup was the FIRST admission of its frame. That is the
		# earliest slot it can hold, so the recycle lands earliest and the
		# reported lifetime is the shortest one consistent with the data —
		# the conservative direction for a question about being cut off.
		_pending_pickups.append({
			"expires_at_play": plays_before + 1 + CombatAudio.VOICE_COUNT,
			"plays_at_start": plays_before,
			"at": _clock,
		})
	else:
		_burst_run = 0

	_retire_pickups()


## A pending voice leaves the list one of two ways: recycled by a later play
## (cut, if that happened before the sound ended) or outliving the sound (clean).
func _retire_pickups() -> void:
	var live: int = 0
	for index in range(_pending_pickups.size() - 1, -1, -1):
		var entry: Dictionary = _pending_pickups[index]
		var age: float = _clock - float(entry["at"])
		var during: int = _plays_total - int(entry["plays_at_start"])
		if _plays_total >= int(entry["expires_at_play"]):
			_pickup_lifetimes.append(age)
			if age < PICKUP_LENGTH_SEC:
				_pickup_cut += 1
			_busiest_life = maxi(_busiest_life, during)
			_life_histogram[during] = int(_life_histogram.get(during, 0)) + 1
			_pending_pickups.remove_at(index)
			continue
		if age >= PICKUP_LENGTH_SEC:
			_pickup_lifetimes.append(PICKUP_LENGTH_SEC)
			# Plays that landed while the sound was still audible. Cutting needs
			# VOICE_COUNT + 1 of them; this is the same headroom counted forwards.
			_busiest_life = maxi(_busiest_life, during)
			_life_histogram[during] = int(_life_histogram.get(during, 0)) + 1
			_pending_pickups.remove_at(index)
			continue
		live += 1
	_live_peak = maxi(_live_peak, live)
	if _audio_trace and live > 1:
		print("SOAK audio t=%.2f live_pickup_voices=%d burst_frames=%d plays=%d" % [
			_clock, live, _burst_run, _plays_total,
		])


## Live counterpart to test_combat_audio.gd, which cannot reach a real tree: in
## a running stage, report the bus every CombatAudio player actually ended up on.
## The ambience player only exists here, so this is the only place it is checked.
func _report_audio_buses() -> void:
	if _audio_node == null:
		return
	var by_bus: Dictionary = {}
	for child in _audio_node.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player == null:
			continue
		by_bus[player.bus] = int(by_bus.get(player.bus, 0)) + 1
	print("SOAK audio buses=%s expected all on %s" % [by_bus, CombatAudio.EFFECTS_BUS])


func _report_audio() -> void:
	_report_audio_buses()
	var suppressed: int = _collects - _pickup_plays
	var suppressed_pct: float = 100.0 * float(suppressed) / maxf(float(_collects), 1.0)
	print("SOAK audio collects=%d pickup_plays=%d suppressed_by_dedupe=%d (%.1f%%) plays_all=%d by_sound=%s" % [
		_collects, _pickup_plays, suppressed, suppressed_pct, _plays_total, _plays_by_sound,
	])

	var lifetimes: Array[float] = _pickup_lifetimes.duplicate()
	lifetimes.sort()
	var count: int = lifetimes.size()
	if count == 0:
		print("SOAK audio voice_lifetime n=0 (no pickup ever played)")
		return
	var total: float = 0.0
	var shortest_delivered: float = 1.0
	for value: float in lifetimes:
		total += value
		shortest_delivered = minf(shortest_delivered, value / PICKUP_LENGTH_SEC)
	print("SOAK audio voice_lifetime n=%d cut=%d (%.1f%%) min=%.3f p50=%.3f mean=%.3f max=%.3f sound=%.3fs" % [
		count, _pickup_cut, 100.0 * float(_pickup_cut) / float(count),
		lifetimes[0], lifetimes[count / 2], total / float(count),
		lifetimes[count - 1], PICKUP_LENGTH_SEC,
	])
	print("SOAK audio worst_delivered=%.1f%% live_pickup_voices_peak=%d longest_burst_frames=%d peak_collects_per_%.0fs=%d" % [
		100.0 * shortest_delivered, _live_peak, _burst_run_max,
		BURST_WINDOW_SEC, _collects_peak_window,
	])
	# Headroom, not a verdict: cutting starts only once the pool turns over
	# faster than the sound is long.
	var near_miss: int = 0
	for plays: Variant in _life_histogram.keys():
		if int(plays) >= CombatAudio.VOICE_COUNT:
			near_miss += int(_life_histogram[plays])
	print("SOAK audio tightest_pool_turnover=%.3fs vs sound=%.3fs busiest_pickup_life=%d plays (cut needs >%d) within_1_play=%d/%d hist=%s" % [
		_tightest_pool_turnover, PICKUP_LENGTH_SEC, _busiest_life, CombatAudio.VOICE_COUNT,
		near_miss, count, _life_histogram,
	])
