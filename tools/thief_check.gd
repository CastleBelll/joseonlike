extends Node
## N10-1a probe: does the 야광귀 actually take a field passive and leave with it?
##
## The spawn table puts a thief in the ruined village at 2:30, which a run would
## take minutes to reach and might still miss. This drives the case directly:
## place a passive on the field, put a thief beside it, and report the three
## moments the feature is made of — the grab, the flight, and what a kill gives
## back.
##
## Run: godot --headless --path . res://tools/thief_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const SETTLE_SEC := 0.8
const GRAB_TIMEOUT_SEC := 12.0
const FLIGHT_SAMPLE_SEC := 1.5
const THIEF_ID := "yagwanggwi"
const ESCAPE_TIMEOUT_SEC := 40.0

var _stage: Stage
var _player: Player
var _thief: Enemy
var _elapsed: float = 0.0
var _phase: int = 0
var _wait: float = SETTLE_SEC
var _distance_at_grab: float = 0.0
## The exact pickup this probe planted. The stage keeps laying new ones down
## while the probe runs, so "the field is empty" proves nothing — what has to
## be gone is THIS one.
var _marked: Pickup
var _failures: PackedStringArray = []
var _escape_mode: bool = false
var _carried_id: String = ""
var _probe_log: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_escape_mode = OS.get_cmdline_user_args().has("--escape")
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("thief_check: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("THIEF CHECK PASS: grabbed, fled, and dropped what it carried")
	else:
		print("THIEF CHECK FAIL: " + ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _live_passives() -> Array:
	return _stage.get("_live_field_passives")


func _process(delta: float) -> void:
	_elapsed += delta
	_wait -= delta
	if _wait > 0.0:
		return
	_player = _stage.get("_player")
	if _player == null:
		_fail("the stage never built a player")
		_finish()
		return
	match _phase:
		0:
			_place_scene()
		1:
			_await_grab()
		2:
			_watch_flight()
		3:
			if _escape_mode:
				_watch_escape()
			else:
				_kill_and_check_drop()


## A passive on the ground and a thief a step beyond it.
func _place_scene() -> void:
	var here: Vector2 = _player.global_position
	# The stage places one per interval; a wait longer than the interval makes
	# it place one on this very tick instead of waiting out the run.
	_stage.call("_tick_field_passives", 999.0)
	var passives: Array = _live_passives()
	if passives.is_empty():
		_fail("no field passive was placed to steal")
		_finish()
		return
	var loot: Pickup = passives[0]
	loot.global_position = here + Vector2(260.0, 0.0)
	_marked = loot
	var spawner: Spawner = _stage.get("_spawner")
	_thief = spawner.call("_spawn_one", THIEF_ID)
	if _thief == null:
		_fail("the spawner would not place a thief")
		_finish()
		return
	_thief.global_position = loot.global_position + Vector2(110.0, 0.0)
	_phase = 1


func _await_grab() -> void:
	if not is_instance_valid(_thief):
		_fail("the thief vanished before it could steal anything")
		_finish()
		return
	if not _thief.carried_passive.is_empty():
		_distance_at_grab = _thief.global_position.distance_to(_player.global_position)
		print("THIEF CHECK grab: took '%s' at %.0fpx" % [
			_thief.carried_passive, _distance_at_grab
		])
		if _live_passives().has(_marked):
			_fail("the stolen passive is still lying on the field")
		_phase = 2
		_wait = FLIGHT_SAMPLE_SEC
		return
	if _elapsed > GRAB_TIMEOUT_SEC:
		_fail("the thief never reached the passive")
		_finish()


func _watch_flight() -> void:
	if not is_instance_valid(_thief) or _thief.carried_passive.is_empty():
		_fail("the thief lost its loot mid-flight")
		_finish()
		return
	var now: float = _thief.global_position.distance_to(_player.global_position)
	print("THIEF CHECK flight: %.0fpx -> %.0fpx" % [_distance_at_grab, now])
	if now <= _distance_at_grab:
		_fail("the thief did not run away with it")
	if _player.hp < _player.hp_max:
		_fail("the thief damaged the player")
	_phase = 3


## The other half of the rule: let it get clear and the passive is GONE. Run
## with `-- --escape` to take this path instead of killing it.
func _watch_escape() -> void:
	var spawner: Spawner = _stage.get("_spawner")
	var still_on_field: bool = (
		is_instance_valid(_thief) and spawner.active_enemies().has(_thief)
	)
	if not still_on_field or _thief.carried_passive.is_empty():
		var still_there: bool = false
		for pickup: Pickup in _live_passives():
			if pickup.passive_id == _carried_id:
				still_there = true
		print("THIEF CHECK escape: gone with '%s' after %.1fs" % [_carried_id, _elapsed])
		if still_there:
			_fail("the escaped passive came back to the field")
		_finish()
		return
	_carried_id = _thief.carried_passive
	# Nothing chases it here, so walking the player the other way is what puts
	# the escape distance between them.
	_player.global_position -= (
		_thief.global_position - _player.global_position
	).normalized() * 24.0
	_probe_log -= 1
	if _probe_log <= 0:
		_probe_log = 60
		print("THIEF CHECK escaping: %.0fpx carried='%s'" % [
			_thief.global_position.distance_to(_player.global_position),
			_thief.carried_passive
		])
	if _elapsed > ESCAPE_TIMEOUT_SEC:
		_fail("the thief never got away even with the player fleeing")
		_finish()


func _kill_and_check_drop() -> void:
	var at: Vector2 = _thief.global_position
	var carried: String = _thief.carried_passive
	_thief.take_damage(_thief.hp + 1.0)
	await get_tree().process_frame
	var dropped: Pickup = null
	for pickup: Pickup in _live_passives():
		if pickup.passive_id == carried and pickup.global_position.distance_to(at) < 8.0:
			dropped = pickup
			break
	if dropped == null:
		_fail("killing the thief did not put '%s' back where it fell" % carried)
	else:
		print("THIEF CHECK drop: '%s' back on the field %.0fpx from the kill" % [
			dropped.passive_id, dropped.global_position.distance_to(at)
		])
	_finish()
