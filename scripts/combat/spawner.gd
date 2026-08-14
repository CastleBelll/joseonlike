class_name Spawner
extends Node2D
## Wave-driven off-screen enemy spawner (N3-4). All numbers come from
## data/stages.json (waves + spawning) and data/monsters.json. Enemies are
## reused through EnemyPool; a run never instances per spawn after warm-up.

## Kills only (not off-screen despawns), so drops never spawn unseen. The
## dying enemy is still valid during this synchronous emit; it returns to the
## pool right after, so handlers must read its fields immediately.
signal enemy_killed(enemy: Enemy)
## N5-1: the single stage boss just entered the field.
signal boss_spawned(boss: Enemy)

const STAGES_PATH := "res://data/stages.json"
const MONSTERS_PATH := "res://data/monsters.json"
const EFFECTS_PATH := "res://data/effects.json"
const STAGE_ID := "bamboo_forest"

var _monsters: Dictionary = {}
var _spawning: Dictionary = {}
var _feedback: Dictionary = {}
var _pending_waves: Array[Dictionary] = []
var _running_waves: Array[Dictionary] = []
var _active: Array[Enemy] = []
var _pool: EnemyPool
var _player: Player
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _boss_id: String = ""
var _boss_at_sec: float = RunFlow.NO_BOSS
var _boss_spawn_done: bool = false
var _soft_enrage: Dictionary = {}
# N3-14 separation state; buffers are reused every frame (clear keeps
# capacity), so steady-state separation allocates nothing.
var _separation := Separation.new()
var _sep_weight: float = 0.0
var _sep_pad: float = 0.0
var _sep_positions: Array[Vector2] = []
var _sep_radii: Array[float] = []
var _sep_neighbours: Array[int] = []
var _sep_neighbour_positions: Array[Vector2] = []
var _sep_neighbour_radii: Array[float] = []


func setup(player: Player) -> void:
	_player = player
	_pool = EnemyPool.new(self)
	_rng.randomize()
	var stage_data: Dictionary = _load_json(STAGES_PATH)
	_monsters = _load_json(MONSTERS_PATH)
	_resolve_elites()
	var effects: Dictionary = _load_json(EFFECTS_PATH)
	_feedback = effects.get("hit_feedback", {})
	var sep: Dictionary = effects.get("separation", {})
	if sep.is_empty():
		push_error("spawner: missing separation tuning in " + EFFECTS_PATH)
	_sep_weight = float(sep.get("weight", 0.0))
	_sep_pad = float(sep.get("pad_px", 0.0))
	_separation.configure(float(sep.get("cell_px", 1.0)))
	var stage: Dictionary = stage_data.get(STAGE_ID, {})
	_spawning = stage.get("spawning", {})
	_boss_id = String(stage.get("boss_id", ""))
	_boss_at_sec = RunFlow.boss_spawn_time(stage)
	_soft_enrage = stage.get("soft_enrage", {})
	if _spawning.is_empty() or _monsters.is_empty():
		push_error("spawner: missing spawning config or monsters for " + STAGE_ID)
		return
	for wave: Dictionary in stage.get("waves", []):
		_pending_waves.append(wave)


## N4-2: "elite_of" entries are multiplier recipes, not full monsters —
## resolve each one into a complete stats dict once at load time.
func _resolve_elites() -> void:
	for monster_id: String in _monsters:
		var entry: Dictionary = _monsters[monster_id]
		if not entry.has("elite_of"):
			continue
		var base_id: String = String(entry.get("elite_of", ""))
		if not _monsters.has(base_id):
			push_error("spawner: elite '%s' references unknown base '%s'" % [monster_id, base_id])
			continue
		_monsters[monster_id] = Enemy.derive_elite_stats(_monsters[base_id], entry)


func active_enemies() -> Array[Enemy]:
	return _active


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_elapsed += delta
	_start_due_waves()
	_run_waves()
	_start_boss_if_due()
	_despawn_far_enemies()
	_apply_separation()


## Writes this frame's weighted push onto every trash enemy (the enemy blends
## it with its chase direction next physics tick — one frame of lag is
## invisible at 60Hz). The boss is present in the grid so trash flows around
## it, but never receives a push itself.
func _apply_separation() -> void:
	if _active.size() < 2 or _sep_weight <= 0.0:
		return
	_sep_positions.clear()
	_sep_radii.clear()
	for enemy: Enemy in _active:
		_sep_positions.append(enemy.global_position)
		_sep_radii.append(enemy.contact_radius)
	_separation.rebuild(_sep_positions)
	for i: int in range(_active.size()):
		var enemy: Enemy = _active[i]
		if enemy.is_boss:
			enemy.separation_push = Vector2.ZERO
			continue
		_sep_neighbours.clear()
		_sep_neighbour_positions.clear()
		_sep_neighbour_radii.clear()
		_separation.collect_neighbours(_sep_positions, i, _sep_neighbours)
		for j: int in _sep_neighbours:
			_sep_neighbour_positions.append(_sep_positions[j])
			_sep_neighbour_radii.append(_sep_radii[j])
		# Index parity picks the split side for exactly stacked pairs, same
		# trick as the enemy's own _avoid_sign.
		var fallback: Vector2 = Vector2.RIGHT if (i & 1) == 0 else Vector2.LEFT
		enemy.separation_push = Separation.separation_push(
			_sep_positions[i], _sep_radii[i],
			_sep_neighbour_positions, _sep_neighbour_radii,
			_sep_pad, fallback
		) * _sep_weight


func _start_due_waves() -> void:
	for wave: Dictionary in _pending_waves.duplicate():
		if _elapsed < float(wave.get("at_sec", 0.0)):
			continue
		_pending_waves.erase(wave)
		_running_waves.append({
			"monster_id": String(wave.get("monster_id", "")),
			"remaining": int(wave.get("count", 0)),
			"interval": float(wave.get("interval_sec", 1.0)),
			"next_at": _elapsed,
		})


func _run_waves() -> void:
	var live_cap: int = int(_spawning.get("live_cap", 0))
	for wave: Dictionary in _running_waves:
		while int(wave["remaining"]) > 0 and _elapsed >= float(wave["next_at"]):
			if _active.size() >= live_cap:
				return  # cap reached; waves resume as enemies die or despawn
			_spawn_one(String(wave["monster_id"]))
			wave["remaining"] = int(wave["remaining"]) - 1
			wave["next_at"] = float(wave["next_at"]) + float(wave["interval"])
	_running_waves = _running_waves.filter(
		func(wave: Dictionary) -> bool: return int(wave["remaining"]) > 0
	)


## The boss ignores the live cap on purpose: its arrival is a timed event,
## not a wave, and it must never be starved out by a full field.
func _start_boss_if_due() -> void:
	if _boss_spawn_done or _boss_at_sec < 0.0 or _elapsed < _boss_at_sec:
		return
	_boss_spawn_done = true
	var boss: Enemy = _spawn_one(_boss_id)
	if boss != null:
		boss_spawned.emit(boss)


func _spawn_one(monster_id: String) -> Enemy:
	if not _monsters.has(monster_id):
		push_error("spawner: unknown monster id " + monster_id)
		return null
	var enemy: Enemy = _pool.acquire()
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	# N4-2 soft enrage: monsters spawned after the ramp start arrive scaled,
	# so a stalled post-boss field turns lethal instead of dragging (GDD §34).
	# The boss spawns at boss_at_sec, before the ramp, and is never scaled.
	var stats: Dictionary = RunFlow.enrage_stats(
		_monsters[monster_id], _soft_enrage, RunFlow.enrage_progress(_elapsed, _soft_enrage)
	)
	enemy.setup(
		monster_id,
		stats,
		_player,
		float(_spawning.get("contact_cooldown_sec", 1.0)),
		_feedback
	)
	# Player position approximates the smoothed camera center; the margin
	# absorbs the few-frame camera lag. Accepted tradeoff for N3-4.
	enemy.global_position = CombatMath.spawn_position(
		_player.global_position,
		get_viewport_rect().size,
		float(_spawning.get("spawn_margin_px", 0.0)),
		_rng.randf_range(0.0, TAU)
	)
	_active.append(enemy)
	return enemy


func _despawn_far_enemies() -> void:
	for enemy: Enemy in _active.duplicate():
		if enemy.is_boss:
			continue  # a kited boss must keep walking, never silently vanish
		var gone: bool = CombatMath.should_despawn(
			enemy.global_position,
			_player.global_position,
			get_viewport_rect().size,
			float(_spawning.get("despawn_margin_px", 0.0))
		)
		if gone:
			_release(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	enemy_killed.emit(enemy)
	_release(enemy)


func _release(enemy: Enemy) -> void:
	_active.erase(enemy)
	_pool.release(enemy)


func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_error("spawner: cannot parse " + path)
		return {}
	return data
