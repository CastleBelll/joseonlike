extends Node
## N9-60 evidence: an endless night cannot be played to its interesting part in
## a test, and dying early proves nothing about the mode. So this makes the
## player unkillable, fast-forwards past the point an ordinary night would have
## ended, and asserts the three things that make it endless:
##
##   1. the clock never fires — the run is still going past duration_sec,
##   2. the loop keeps arming waves, so the field never falls silent,
##   3. killing the boss pays out and schedules the next one instead of
##      ending the run.
##
## Run: godot --headless --path . res://tools/endless_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const TIME_SCALE := 24.0
## Comfortably past bamboo_forest's 420s duration and its 340s boss.
const WATCH_UNTIL_SEC := 560.0

var _stage: Stage
var _spawner: Spawner
var _player: Player
var _failed: bool = false
var _boss_kills: int = 0
var _peak_loop: int = 0
var _quiet_sec: float = 0.0
var _worst_quiet: float = 0.0
var _done: bool = false
## N9-61 coexistence: the map, the arrows and the drops all live in the same
## HUD during the same run.
var _map_seen: bool = false
var _markers_seen: bool = false
var _peak_passives: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SaveService.instance != null:
		var profile: Dictionary = SaveProfile.default_profile()
		(profile["stats"] as Dictionary)["runs_played"] = 1
		profile[Ftue.FTUE_KEY] = {Ftue.MOVE_HINT_SEEN: true, Ftue.MOD_EXPLAINED: true}
		(profile["settings"] as Dictionary)[Difficulty.RUN_LENGTH_KEY] = "endless"
		# N9-61: the map, the field passives and their arrows have only ever
		# been checked one at a time. An endless night is where all of them run
		# longest, so it is the right place to prove they coexist.
		profile[Unlocks.PROFILE_KEY] = [Unlocks.MAP]
		SaveService.instance.profile = profile
		SaveService.instance._write_locked = true
		SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_spawner = _stage.get_node("World/Spawner")
	# Unkillable: the mode is what is under test, not the bot's survival.
	_player.set_damage_taken_scale(0.0)
	Engine.time_scale = TIME_SCALE
	if not _spawner.is_endless_run():
		_fail("the endless run length did not reach the spawner")
		_finish()


func _process(delta: float) -> void:
	if _done:
		return
	# Level-up screens pause the tree and would stall the whole probe.
	if get_tree().paused and _stage._popup.visible:
		_press_first_card()
		return
	_peak_loop = maxi(_peak_loop, _spawner.endless_loop())
	if _spawner.active_enemies().is_empty():
		_quiet_sec += delta
		_worst_quiet = maxf(_worst_quiet, _quiet_sec)
	else:
		_quiet_sec = 0.0
	# The boss is the one thing that must come BACK; kill it on sight so the
	# return path is exercised rather than assumed.
	if _stage._boss != null and not CombatMath.is_dead(_stage._boss.hp):
		_stage._boss.take_damage(_stage._boss.hp + 1.0)
		_boss_kills += 1
	if _stage.get_node_or_null("Hud/Minimap") != null:
		_map_seen = true
	if _stage.get_node_or_null("Hud/OffscreenMarkers") != null:
		_markers_seen = true
	_peak_passives = maxi(_peak_passives, _stage._field_passives_placed)
	if _stage._run_elapsed >= WATCH_UNTIL_SEC:
		_finish()


func _press_first_card() -> void:
	for button: Node in _stage._popup.find_children("*", "Button", true, false):
		if button is Button and not (button as Button).disabled:
			(button as Button).pressed.emit()
			return


func _finish() -> void:
	_done = true
	Engine.time_scale = 1.0
	await _capture()
	print("ENDLESS elapsed %.0fs, outcome '%s', loops %d, boss kills %d, longest quiet %.1fs" % [
		_stage._run_elapsed, _stage._outcome, _peak_loop, _boss_kills, _worst_quiet
	])
	if _stage._outcome != RunFlow.OUTCOME_NONE:
		_fail("the run ended on its own (outcome '%s')" % _stage._outcome)
	if _peak_loop < 2:
		_fail("only %d loop(s) armed by %.0fs" % [_peak_loop, WATCH_UNTIL_SEC])
	if _boss_kills < 2:
		_fail("the boss came back %d time(s) — it must recur" % maxi(_boss_kills - 1, 0))
	# A long silence means the loop stopped feeding the field, which plays as a
	# crash rather than as a mode.
	if _worst_quiet > 20.0:
		_fail("the field was empty for %.1fs" % _worst_quiet)
	print("ENDLESS map=%s arrows=%s field passives placed=%d" % [
		str(_map_seen), str(_markers_seen), _peak_passives
	])
	if not _map_seen:
		_fail("the 지도 unlock was owned but no map was drawn")
	if not _markers_seen:
		_fail("drops were placed but no off-screen arrows layer appeared")
	if _peak_passives <= 0:
		_fail("no field passive was placed in %.0fs" % WATCH_UNTIL_SEC)
	print("ENDLESS CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


## Rendered runs only: one frame with the map, the arrows and the drops all on
## screen at once, which no single-feature harness can show.
func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := "user://endless_check.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("ENDLESS shot: " + ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error("endless_check: " + message)
