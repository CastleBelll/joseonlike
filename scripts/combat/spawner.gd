class_name Spawner
extends Node2D
## Drives a stage's waves against the run clock and places monsters just outside
## the visible area around the player.
##
## Wave timing lives in WaveSchedule (pure, tested); this node only owns the
## cursor, the placement ring and the pool.

const ENEMY_SCENE: PackedScene = preload("res://scenes/actors/enemy_base.tscn")

const PLAYER_GROUP: StringName = &"player"
const KEY_WAVES: String = "waves"
const KEY_MONSTER_ID: String = "monster_id"

## Spawn ring sits outside the 540x960 portrait viewport so monsters walk in
## rather than popping into view.
const SPAWN_MARGIN_PX: float = 80.0
const SPAWN_JITTER_PX: float = 40.0
const FALLBACK_SPAWN_RADIUS_PX: float = 620.0

var _pool: EnemyPool = null
var _events: Array[Dictionary] = []
var _cursor: int = 0
var _clock_sec: float = 0.0
var _rng: RandomNumberGenerator = null

@onready var _container: Node2D = $Enemies


func _ready() -> void:
	_rng = CombatRng.create()
	_pool = EnemyPool.new()
	_pool.name = "EnemyPool"
	add_child(_pool)
	_pool.setup(ENEMY_SCENE, _container)


## Loads the wave table. Safe to call with {} — the spawner simply stays idle.
func configure(stage_data: Dictionary) -> void:
	_events = WaveSchedule.expand(stage_data.get(KEY_WAVES, []))
	_cursor = 0
	_clock_sec = 0.0
	if _events.is_empty():
		push_warning("Spawner: stage has no waves, nothing will spawn")


## Advances the schedule to an absolute run-clock time and spawns what is due.
## Returns how many monsters actually entered the field.
func advance_to(time_sec: float) -> int:
	if time_sec <= _clock_sec:
		return 0
	var spawned: int = 0
	var due: int = WaveSchedule.count_due(_events, _cursor, time_sec)
	for _index in due:
		var event: Dictionary = _events[_cursor]
		_cursor += 1
		if spawn(String(event.get(KEY_MONSTER_ID, ""))) != null:
			spawned += 1
	_clock_sec = time_sec
	return spawned


func active_count() -> int:
	return _pool.active_count() if _pool != null else 0


func pending_count() -> int:
	return maxi(_events.size() - _cursor, 0)


## Spawns one monster on the off-screen ring around the player.
func spawn(monster_id: String) -> Enemy:
	return spawn_at(monster_id, _ring_position())


func spawn_at(monster_id: String, spawn_position: Vector2) -> Enemy:
	if monster_id.is_empty() or _pool == null:
		return null
	var data: Dictionary = GameData.monster(monster_id)
	if data.is_empty():
		push_warning("Spawner: unknown monster '%s'" % monster_id)
		return null
	return _pool.acquire(monster_id, data, spawn_position)


func release_all() -> void:
	if _pool != null:
		_pool.release_all()


func _ring_position() -> Vector2:
	var origin: Vector2 = global_position
	var player: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null:
		origin = player.global_position
	var radius: float = _spawn_radius() + _rng.randf_range(0.0, SPAWN_JITTER_PX)
	return origin + Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * radius


func _spawn_radius() -> float:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return FALLBACK_SPAWN_RADIUS_PX
	# Half the diagonal clears the screen corners regardless of orientation.
	return viewport.get_visible_rect().size.length() * 0.5 + SPAWN_MARGIN_PX
