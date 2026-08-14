extends Node
## Autoplay verification harness (N4-2b): boots the real combat stage, kites
## with a simple steering bot, auto-picks popup cards (개조 card first, then
## grade line), and reports the run — outcome, level-ups, grade climb,
## surge-window fps, mod cards offered/taken — plus surge/result/mod-card
## screenshots.
## Run: godot --path . res://tools/playtest.tscn
## Every timing below derives from data/stages.json duration_sec/boss_at_sec/
## surge_at_sec — nothing here hardcodes the run length.

const STAGE_SCENE := "res://scenes/stage.tscn"
const SURGE_SHOT_PATH := "user://playtest_surge.png"
const RESULT_SHOT_PATH := "user://playtest_result.png"
const MOD_SHOT_PATH := "user://playtest_mod_card.png"
const SURGE_SHOT_DELAY_SEC := 10.0
const PICK_COOLDOWN_SEC := 0.4
const DANGER_RADIUS := 120.0
const ORB_RADIUS := 320.0
const BOUNDS_MARGIN := 90.0
const TIMEOUT_GRACE_SEC := 90.0
const MOVE_ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down"]

var _stage: Stage
var _player: Player
var _spawner: Spawner
var _duration: float = 0.0
var _surge_at: float = 0.0
var _boss_at: float = 0.0
var _pick_wait: float = 0.0
var _surge_shot_done: bool = false
var _result_shot_done: bool = false
var _fps_min: float = 1e9
var _fps_sum: float = 0.0
var _fps_samples: int = 0
var _special_times: Array[float] = []
var _grade_picks: int = 0
var _mod_offers: int = 0
var _mod_shot_done: bool = false
var _real_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stage_data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Spawner.STAGES_PATH)
	)
	var stage_entry: Dictionary = stage_data.get(Spawner.STAGE_ID, {})
	_duration = float(stage_entry.get("duration_sec", 0.0))
	_surge_at = float(stage_entry.get("surge_at_sec", 0.0))
	_boss_at = RunFlow.boss_spawn_time(stage_entry)
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_spawner = _stage.get_node("World/Spawner")


func _process(delta: float) -> void:
	_real_elapsed += delta
	if _real_elapsed > _duration + TIMEOUT_GRACE_SEC:
		print("PLAYTEST FAIL: run did not finish within grace window")
		get_tree().quit(1)
		return
	var elapsed: float = _stage._run_elapsed
	if not get_tree().paused and elapsed >= _surge_at and elapsed < _boss_at:
		var fps: float = Engine.get_frames_per_second()
		_fps_min = minf(_fps_min, fps)
		_fps_sum += fps
		_fps_samples += 1
	if not _surge_shot_done and elapsed >= _surge_at + SURGE_SHOT_DELAY_SEC:
		_surge_shot_done = true
		_capture(SURGE_SHOT_PATH)
	if _stage._outcome != RunFlow.OUTCOME_NONE and not _result_shot_done:
		_result_shot_done = true
		_finish()


func _physics_process(delta: float) -> void:
	if _stage._outcome != RunFlow.OUTCOME_NONE:
		_release_moves()
		return
	if get_tree().paused:
		_release_moves()
		_pick_wait -= delta
		if _pick_wait <= 0.0 and _stage._popup.visible:
			_pick_wait = PICK_COOLDOWN_SEC
			_pick_card()
		return
	_pick_wait = PICK_COOLDOWN_SEC
	_steer()


## Steering: repel from close enemies (boss weighted), seek the nearest
## uncollected orb/loot, stay off the field edge, orbit when nothing presses.
func _steer() -> void:
	var pos: Vector2 = _player.global_position
	var repel := Vector2.ZERO
	for enemy: Enemy in _spawner.active_enemies():
		var away: Vector2 = pos - enemy.global_position
		var reach: float = DANGER_RADIUS + enemy.contact_radius
		var dist: float = away.length()
		if dist < reach and dist > 0.001:
			repel += away / dist * (1.0 - dist / reach) * (3.0 if enemy.is_boss else 1.0)
	var seek := Vector2.ZERO
	var best: float = ORB_RADIUS
	for child: Node in _stage.get_children():
		if child is XpOrb and (child as Node2D).visible:
			var dist: float = pos.distance_to((child as Node2D).global_position)
			if dist < best:
				best = dist
				seek = ((child as Node2D).global_position - pos).normalized()
	var push := Vector2.ZERO
	var bounds: Rect2 = _player.bounds
	if bounds.has_area():
		push.x += maxf(0.0, 1.0 - (pos.x - bounds.position.x) / BOUNDS_MARGIN)
		push.x -= maxf(0.0, 1.0 - (bounds.end.x - pos.x) / BOUNDS_MARGIN)
		push.y += maxf(0.0, 1.0 - (pos.y - bounds.position.y) / BOUNDS_MARGIN)
		push.y -= maxf(0.0, 1.0 - (bounds.end.y - pos.y) / BOUNDS_MARGIN)
	var direction: Vector2 = repel * 2.0 + seek * 0.8 + push * 2.5
	if direction.length() < 0.15:
		direction = Vector2(-pos.y, pos.x).normalized() - pos * 0.0005
	direction = direction.normalized()
	_release_moves()
	if direction.x < 0.0:
		Input.action_press("move_left", -direction.x)
	else:
		Input.action_press("move_right", direction.x)
	if direction.y < 0.0:
		Input.action_press("move_up", -direction.y)
	else:
		Input.action_press("move_down", direction.y)


func _release_moves() -> void:
	for action: String in MOVE_ACTIONS:
		Input.action_release(action)


## Card priority proves the N4-6 targets: the 개조 card first (folded-in mod
## flow, screenshot on first sight), then grade raises, then weapon levels,
## then whatever is left.
func _pick_card() -> void:
	var buttons: Array[Button] = []
	_collect_buttons(_stage._popup, buttons)
	if buttons.is_empty():
		return
	var mod_on_screen: bool = false
	for button: Button in buttons:
		if _button_has_label(button, LevelUp.MOD_LABEL):
			mod_on_screen = true
			break
	if mod_on_screen:
		_mod_offers += 1
	var chosen: Button = null
	for wanted: String in [LevelUp.MOD_LABEL, LevelUp.GRADE_UP_LABEL, "Lv."]:
		for button: Button in buttons:
			if _button_has_label(button, wanted):
				chosen = button
				break
		if chosen != null:
			break
	if chosen == null:
		chosen = buttons[0]
	if _button_has_label(chosen, LevelUp.GRADE_UP_LABEL):
		_grade_picks += 1
	if _button_has_label(chosen, LevelUp.MOD_LABEL):
		_special_times.append(_stage._run_elapsed)
	if mod_on_screen and not _mod_shot_done:
		# Capture the 개조 card on the open popup before pressing anything.
		_mod_shot_done = true
		await _capture(MOD_SHOT_PATH)
	chosen.pressed.emit()


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			found.append(child)
		_collect_buttons(child, found)


func _button_has_label(button: Button, text: String) -> bool:
	for child: Node in button.get_children():
		if child is Label and (child as Label).text.begins_with(text):
			return true
	return false


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("PLAYTEST shot: " + ProjectSettings.globalize_path(path))


func _finish() -> void:
	await _capture(RESULT_SHOT_PATH)
	var fps_avg: float = _fps_sum / float(maxi(_fps_samples, 1))
	print("PLAYTEST outcome: %s at %.1fs" % [_stage._outcome, _stage._run_elapsed])
	print("PLAYTEST level: %d (level-ups: %d)" % [
		_stage._run_state.level, _stage._run_state.level - 1
	])
	print("PLAYTEST grades: %s (grade picks: %d)" % [str(_stage._owned_grades), _grade_picks])
	print("PLAYTEST surge fps: min %.0f avg %.0f over %d samples" % [
		_fps_min if _fps_samples > 0 else 0.0, fps_avg, _fps_samples
	])
	print("PLAYTEST mod cards: offered on %d screens, taken %d at %s" % [
		_mod_offers, _special_times.size(), str(_special_times)
	])
	print("PLAYTEST kills: %d gold: %d" % [_stage._kills, _stage._gold])
	if _stage._boss != null:
		print("PLAYTEST boss hp left: %.0f / %.0f" % [_stage._boss.hp, _stage._boss_hp_max])
	else:
		print("PLAYTEST boss killed")
	get_tree().quit(0)
