class_name BossController
extends Node
## Owns the stage boss: schedules its entrance, announces it, and reports its
## defeat. The stage decides what a defeat means for the run.

const KEY_BOSS_ID: String = "boss_id"
const KEY_DURATION_SEC: String = "duration_sec"
const DEFAULT_DURATION_SEC: float = 600.0
## The boss walks in from the same off-screen ring as everything else.
const SPAWN_DISTANCE_PX: float = 260.0

signal boss_defeated_locally(boss_id: String)

var boss_id: String = ""
var spawn_at_sec: float = DEFAULT_DURATION_SEC
var has_spawned: bool = false
var has_been_defeated: bool = false

var _spawner: Spawner = null


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)


func configure(stage_data: Dictionary, spawner: Spawner) -> void:
	_spawner = spawner
	boss_id = String(stage_data.get(KEY_BOSS_ID, ""))
	spawn_at_sec = maxf(float(stage_data.get(KEY_DURATION_SEC, DEFAULT_DURATION_SEC)), 0.0)
	has_spawned = false
	has_been_defeated = false
	if boss_id.is_empty():
		push_warning("BossController: stage has no boss_id, the run has no win condition")


## Called with the absolute run clock; spawns the boss once its time arrives.
func advance_to(time_sec: float) -> void:
	if has_spawned or boss_id.is_empty() or time_sec < spawn_at_sec:
		return
	spawn_now()


func spawn_now() -> Enemy:
	if has_spawned or boss_id.is_empty() or _spawner == null:
		return null
	has_spawned = true
	var boss: Enemy = _spawner.spawn(boss_id)
	if boss == null:
		push_error("BossController: could not spawn boss '%s'" % boss_id)
		return null
	EventBus.boss_spawned.emit(boss_id)
	EventBus.stat_recorded.emit("boss_spawned", 1)
	return boss


func _on_enemy_killed(monster_id: String, _position: Vector2) -> void:
	if has_been_defeated or monster_id.is_empty() or monster_id != boss_id:
		return
	has_been_defeated = true
	EventBus.boss_defeated.emit(boss_id)
	EventBus.stat_recorded.emit("boss_defeated", 1)
	boss_defeated_locally.emit(boss_id)
