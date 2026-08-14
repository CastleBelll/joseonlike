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


func setup(player: Player) -> void:
	_player = player
	_pool = EnemyPool.new(self)
	_rng.randomize()
	var stage_data: Dictionary = _load_json(STAGES_PATH)
	_monsters = _load_json(MONSTERS_PATH)
	_feedback = _load_json(EFFECTS_PATH).get("hit_feedback", {})
	var stage: Dictionary = stage_data.get(STAGE_ID, {})
	_spawning = stage.get("spawning", {})
	_boss_id = String(stage.get("boss_id", ""))
	_boss_at_sec = RunFlow.boss_spawn_time(stage)
	if _spawning.is_empty() or _monsters.is_empty():
		push_error("spawner: missing spawning config or monsters for " + STAGE_ID)
		return
	for wave: Dictionary in stage.get("waves", []):
		_pending_waves.append(wave)


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
	enemy.setup(
		monster_id,
		_monsters[monster_id],
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
