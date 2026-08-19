extends Node
## N9-30 evidence harness: a curse spread is a 0.45s animation that only fires
## when a cursed enemy dies, so an ordinary playtest screenshot almost never
## lands on one — the visual could ship unseen. This stages the moment
## deliberately: several neighbours, one cursed carrier, killed on cue, and
## captured across the creep so the crawl is judged by eye rather than only by
## its unit tests.
## Run (rendered): godot --path . res://tools/creep_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const MONSTER_ID := "forest_goblin"
const NEIGHBOURS := 5
const RING_PX := 96.0
const CURSE_DPS := 4.0
const CURSE_DURATION := 5.0
const SPREAD_PX := 160.0
const SPREAD_COUNT := 4
const SETTLE_FRAMES := 6
## Frames after the kill to capture at — early, mid and late in the crawl.
const SHOT_FRAMES: Array[int] = [3, 9, 16, 24]

var _stage: Stage
var _player: Player
var _spawner: Spawner
var _step: int = 0
var _kill_frame: int = -1
var _shots: int = 0
var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_spawner = _stage.get_node("World/Spawner")
	# No waves: the only enemies on the field are the ones staged here, so the
	# shot cannot be muddied by an unrelated crowd wandering through.
	_spawner._pending_waves.clear()
	_spawner._running_waves.clear()


func _physics_process(_delta: float) -> void:
	_step += 1
	if _step == SETTLE_FRAMES:
		_stage_the_spread()
		return
	if _kill_frame < 0:
		return
	var since: int = _step - _kill_frame
	if since in SHOT_FRAMES:
		_capture("user://creep_%d.png" % since)
	if since > SHOT_FRAMES[SHOT_FRAMES.size() - 1]:
		_finish()


func _stage_the_spread() -> void:
	var centre: Vector2 = _player.global_position + Vector2(0.0, -120.0)
	var carrier: Enemy = _spawner._spawn_one(MONSTER_ID)
	if carrier == null:
		_fail("spawner refused to spawn " + MONSTER_ID)
		_finish()
		return
	carrier.global_position = centre
	# Uncursed neighbours in a ring, all inside spread range: the creep should
	# reach several at once, which is what a levelled 살 actually does.
	for i: int in range(NEIGHBOURS):
		var neighbour: Enemy = _spawner._spawn_one(MONSTER_ID)
		if neighbour == null:
			continue
		neighbour.global_position = centre + Vector2.RIGHT.rotated(
			TAU * float(i) / float(NEIGHBOURS)
		) * RING_PX
	carrier.apply_curse(CURSE_DPS, CURSE_DURATION, SPREAD_PX, SPREAD_COUNT)
	if not carrier.is_cursed():
		_fail("carrier did not take the curse")
	# Killing it is what triggers the spread (Spawner._spread_curse).
	carrier.take_damage(carrier.hp + 1.0)
	_kill_frame = _step
	print("CREEP staged: 1 carrier + %d neighbours at %.0fpx" % [NEIGHBOURS, RING_PX])


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(path)
	_shots += 1
	print("CREEP shot: " + ProjectSettings.globalize_path(path))


func _finish() -> void:
	var infected: int = 0
	for enemy: Enemy in _spawner.active_enemies():
		if enemy.is_cursed():
			infected += 1
	# The visual is the point, but a creep drawn between enemies that were
	# never actually infected would be a lie the screenshots could not show.
	if infected <= 0:
		_fail("the spread infected nobody — the creep would be decorative")
	else:
		print("CREEP infected %d neighbours" % infected)
	print("CREEP CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


func _fail(message: String) -> void:
	_failed = true
	push_error("creep_check: " + message)
