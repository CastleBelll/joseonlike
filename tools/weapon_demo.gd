extends Node
## Windowed weapon showcase (N4-4a): boots the real combat stage, grants one
## weapon by id from the command line, dismisses every level-up popup (so the
## granted weapon stays the whole show), and captures timed screenshots for
## eyeball verification of each mechanic.
## Run: godot --path . res://tools/weapon_demo.tscn -- --weapon=hwabu

const STAGE_SCENE := "res://scenes/stage.tscn"
const SHOT_TIMES: Array[float] = [6.0, 8.0, 10.0, 12.0, 14.0, 16.0]
const QUIT_AT_SEC := 18.0
## The demo watches mechanics, not survival — the player must outlive the swarm.
const HUGE_HP := 99999.0

const HIT_SHOT_MAX := 3
const HIT_SHOT_GAP_SEC := 2.0

var _stage: Stage
var _weapon_id: String = ""
var _shots_done: int = 0
var _hit_shots: int = 0
var _last_hit_shot: float = -HIT_SHOT_GAP_SEC


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			_weapon_id = arg.get_slice("=", 1)
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	var player: Player = _stage.get_node("World/Player")
	player.hp = HUGE_HP
	player.hp_max = HUGE_HP
	if _weapon_id.is_empty() or not _stage._weapons_data.has(_weapon_id):
		push_error("weapon_demo: pass -- --weapon=<id from data/weapons.json>")
		get_tree().quit(1)
		return
	# Show ONLY the requested weapon — the starter would otherwise kill
	# everything at range before it ever reaches a melee/orbit weapon.
	for id: String in _stage._weapon_nodes.keys():
		if id == _weapon_id:
			continue
		(_stage._weapon_nodes[id] as AutoWeapon).queue_free()
		_stage._weapon_nodes.erase(id)
		_stage._owned_levels.erase(id)
	_stage._owned_levels[_weapon_id] = 1
	_stage._owned_grades[_weapon_id] = LevelUp.current_grade(
		_weapon_id, _stage._weapons_data, {}
	)
	if not _stage._weapon_nodes.has(_weapon_id):
		_stage._add_weapon_node(_weapon_id)
	# Timed shots miss sub-0.2s flashes (arc swing, explosion ring); capturing
	# on the landed hit gets the effect the same frame it draws.
	(_stage._weapon_nodes[_weapon_id] as AutoWeapon).hit_landed.connect(_on_weapon_hit)


func _on_weapon_hit(_amount: float, _at: Vector2, _boss: bool) -> void:
	var elapsed: float = _stage._run_elapsed
	if _hit_shots >= HIT_SHOT_MAX or elapsed - _last_hit_shot < HIT_SHOT_GAP_SEC:
		return
	_hit_shots += 1
	_last_hit_shot = elapsed
	_capture("user://demo_%s_hit%d.png" % [_weapon_id, _hit_shots])


func _process(_delta: float) -> void:
	if get_tree().paused and _stage._popup.visible:
		_stage._popup.dismissed.emit()  # skip cards; keep the build fixed
	var elapsed: float = _stage._run_elapsed
	if _shots_done < SHOT_TIMES.size() and elapsed >= SHOT_TIMES[_shots_done]:
		_shots_done += 1
		_capture("user://demo_%s_%d.png" % [_weapon_id, _shots_done])
	if elapsed >= QUIT_AT_SEC:
		get_tree().quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("DEMO shot: " + ProjectSettings.globalize_path(path))
