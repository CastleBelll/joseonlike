extends Node
## Windowed weapon showcase (N4-4a): boots the real combat stage, grants one
## weapon by id from the command line, dismisses every level-up popup (so the
## granted weapon stays the whole show), and captures timed screenshots for
## eyeball verification of each mechanic.
## Run: godot --path . res://tools/weapon_demo.tscn -- --weapon=hwabu
## N4-4b: --active=<id from the character's actives> additionally fires that
## active on a fixed demo clock (cooldown bypassed) and screenshots each cast.
## Run: godot --path . res://tools/weapon_demo.tscn -- --weapon=old_talisman --active=chukji

const STAGE_SCENE := "res://scenes/stage.tscn"
const SHOT_TIMES: Array[float] = [6.0, 8.0, 10.0, 12.0, 14.0, 16.0]
const QUIT_AT_SEC := 18.0
## N9-69: the mark count is sampled through the show and reported at the end.
## Zero for a weapon that lands hits is the bug this exists to catch — the
## non-projectile weapons had exactly that, and no screenshot at a fixed second
## is guaranteed to catch a mark that lives a fraction of one.
const MARK_SAMPLE_SEC := 0.05
## The demo watches mechanics, not survival — the player must outlive the swarm.
const HUGE_HP := 99999.0

const HIT_SHOT_MAX := 3
const HIT_SHOT_GAP_SEC := 2.0

const ACTIVE_FIRE_TIMES: Array[float] = [5.0, 9.0, 13.0]

var _stage: Stage
var _weapon_id: String = ""
var _active_id: String = ""
var _active_fires: int = 0
var _shots_done: int = 0
var _peak_marks: int = 0
var _mark_shot_done: bool = false
var _hits_seen: int = 0
var _hit_shots: int = 0
var _last_hit_shot: float = -HIT_SHOT_GAP_SEC


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			_weapon_id = arg.get_slice("=", 1)
		if arg.begins_with("--active="):
			_active_id = arg.get_slice("=", 1)
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


func _on_weapon_hit(_amount: float, _at: Vector2, _boss: bool, _crit: bool) -> void:
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
	if not _active_id.is_empty() and _active_fires < ACTIVE_FIRE_TIMES.size() \
			and elapsed >= ACTIVE_FIRE_TIMES[_active_fires]:
		_active_fires += 1
		_fire_active()
	_sample_marks()
	if elapsed >= QUIT_AT_SEC:
		print("DEMO %s: hits %d, peak impact marks %d" % [
			_weapon_id, _hits_seen, _peak_marks
		])
		if _hits_seen > 0 and _peak_marks == 0:
			push_error(
				"weapon_demo: %s landed %d hits and never showed a mark"
				% [_weapon_id, _hits_seen]
			)
		get_tree().quit(0)


## N9-69: samples the weapon's live mark count. A screenshot at a fixed second
## can miss a mark that lives a fraction of one, so the count is watched
## continuously instead of inferred from a picture.
func _sample_marks() -> void:
	for weapon: AutoWeapon in _stage._weapon_nodes.values():
		if weapon.weapon_id != _weapon_id:
			continue
		if not weapon.hit_landed.is_connected(_count_hit):
			weapon.hit_landed.connect(_count_hit)
		_peak_marks = maxi(_peak_marks, weapon._live_marks)
		# Captured on a frame that HAS a mark, rather than at a fixed second and
		# hoping: a mark lives a fraction of a second and a timed shot mostly
		# lands between them.
		if weapon._live_marks > 0 and not _mark_shot_done:
			_mark_shot_done = true
			_capture("user://demo_%s_mark.png" % _weapon_id)


func _count_hit(_amount: float, _at: Vector2, _boss: bool, _crit: bool) -> void:
	_hits_seen += 1


## Demo bypass: call the effect directly so a 45s-cooldown emergency button
## still shows several casts inside the 18s demo window.
func _fire_active() -> void:
	for active: Dictionary in _stage._actives:
		if String(active.get("id", "")) == _active_id:
			_stage._execute_active(active)
			_capture("user://demo_active_%s_%d.png" % [_active_id, _active_fires])
			return
	push_error("weapon_demo: unknown active id " + _active_id)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("DEMO shot: " + ProjectSettings.globalize_path(path))
