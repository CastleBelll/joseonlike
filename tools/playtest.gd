extends Node
## Autoplay verification harness (N4-2b): boots the real combat stage, kites
## with a simple steering bot, auto-picks popup cards (개조 card first, then
## grade line), and reports the run — outcome, level-ups, grade climb,
## surge-window fps, mod cards offered/taken — plus surge/result/mod-card
## screenshots.
## Run: godot --path . res://tools/playtest.tscn
##
## N4-3 balance modes (all optional, combined after "--"):
##   --weapon=<id>   forced single-weapon build: the bot starts with <id>
##                   instead of the character's starting weapon and only ever
##                   picks cards for it (level, grade, its 개조) or passives —
##                   never a second weapon. Unusable screens are skipped.
##   --batch         run every weapon in BATCH_WEAPONS once (forced build
##                   each) and print a measurement table at the end.
##   --seed=<n>      seed the field/choice/loot RNG streams so runs compare;
##                   --batch defaults to DEFAULT_BATCH_SEED when unset.
##   --speed=<x>     Engine.time_scale for faster headless sweeps. Simulation
##                   granularity is unchanged (same physics delta, more steps
##                   per real second); fps columns are meaningless above 1.
##   --nopick        dismiss every level-up screen: the deliberately-bad
##                   build for the "can a run be lost" check.
##   --grant=a,b,c   (N4-4b) hand the run extra weapons at start for surge
##                   load tests.
##   --meta=max      (N7-1) run with every 명부수 node at max rank, injected
##                   in memory only — the profile save is locked so the dev
##                   profile on disk is never polluted.
## Screenshots are skipped in headless mode (no frames to grab).
## Every timing below derives from data/stages.json duration_sec/boss_at_sec/
## surge_at_sec — nothing here hardcodes the run length.

const STAGE_SCENE := "res://scenes/stage.tscn"
const SURGE_SHOT_PATH := "user://playtest_surge.png"
const RESULT_SHOT_PATH := "user://playtest_result.png"
const MOD_SHOT_PATH := "user://playtest_mod_card.png"
const MIDRUN_SHOT_PATH := "user://playtest_midrun.png"
const MIDRUN_SHOT_AT_SEC := 75.0
## N6-1: capture the move hint before the bot's first input dismisses it.
const HINT_SHOT_PATH := "user://playtest_move_hint.png"
const HINT_SHOT_AT_SEC := 0.6
## N3-14 crowd metric: an enemy counts as "stacked" when another enemy's
## center sits closer than half the pair's combined contact radii.
const OVERLAP_SAMPLE_SEC := 1.0
const OVERLAP_RATIO := 0.5
const SURGE_SHOT_DELAY_SEC := 10.0
const PICK_COOLDOWN_SEC := 0.4
const DANGER_RADIUS := 120.0
const ORB_RADIUS := 320.0
const BOUNDS_MARGIN := 90.0
const TIMEOUT_GRACE_SEC := 90.0
const MOVE_ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down"]
## N4-3: the ten base taoist weapons a run can start on (non-evolution_only).
const BATCH_WEAPONS: Array[String] = [
	"old_talisman", "hwabu", "noebu", "seokjang", "honbul",
	"beopgeom", "gyeolgye", "sinjang", "jineon", "sal",
]
## Fixed default so every batch weapon faces the same waves/drops/choices.
const DEFAULT_BATCH_SEED := 20260814

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
var _midrun_shot_done: bool = false
var _hint_shown: bool = false
var _hint_shot_done: bool = true
var _fps_min_all: float = 1e9
var _peak_live: int = 0
var _overlap_sum: float = 0.0
var _overlap_samples: int = 0
var _overlap_timer: float = 0.0

# N4-3 balance harness state.
var _forced: String = ""
var _batch: bool = false
var _batch_index: int = 0
var _no_pick: bool = false
var _run_seed: int = 0  # 0 = unseeded (default free-play behaviour)
var _speed: float = 1.0
var _grants: Array[String] = []
var _meta_max: bool = false
var _headless: bool = false
var _damage_total: float = 0.0
var _tracked_weapons: Array[String] = []
var _rows: Array[Dictionary] = []
var _weapons_json: Dictionary = {}
var _passive_names: Array[String] = []
var _skipped_screens: int = 0
# N4-7 guard metric: display names of every mod result — a card offering one
# of these as 신규! is the bug the exclusion exists to prevent.
var _evo_result_names: Array[String] = []
var _evo_violations: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	var stage_data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Spawner.STAGES_PATH)
	)
	var stage_entry: Dictionary = stage_data.get(Spawner.STAGE_ID, {})
	_duration = float(stage_entry.get("duration_sec", 0.0))
	_surge_at = float(stage_entry.get("surge_at_sec", 0.0))
	_boss_at = RunFlow.boss_spawn_time(stage_entry)
	_weapons_json = JSON.parse_string(FileAccess.get_file_as_string(AutoWeapon.WEAPONS_PATH))
	var passives: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Stage.PASSIVES_PATH)
	)
	for passive_id: String in passives:
		_passive_names.append(String((passives[passive_id] as Dictionary).get("name_ko", "")))
	var mods: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Stage.WEAPON_MODS_PATH)
	)
	for mod_id: String in mods:
		var result_id: String = String((mods[mod_id] as Dictionary).get("result_weapon", ""))
		_evo_result_names.append(String(
			(_weapons_json.get(result_id, {}) as Dictionary).get("name_ko", result_id)
		))
	_parse_args()
	Engine.time_scale = _speed
	if _batch:
		if _run_seed == 0:
			_run_seed = DEFAULT_BATCH_SEED
		_forced = BATCH_WEAPONS[0]
	_start_run()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--grant="):
			for weapon_id: String in arg.get_slice("=", 1).split(","):
				_grants.append(weapon_id)
		elif arg.begins_with("--weapon="):
			_forced = arg.get_slice("=", 1)
		elif arg.begins_with("--seed="):
			_run_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--speed="):
			_speed = maxf(float(arg.get_slice("=", 1)), 0.1)
		elif arg == "--batch":
			_batch = true
		elif arg == "--nopick":
			_no_pick = true
		elif arg == "--meta=max":
			_meta_max = true


## Boot one run: fresh stage, seeded streams, forced/granted weapons, and the
## damage-total hooks the balance table reads.
func _start_run() -> void:
	_reset_run_metrics()
	if _meta_max and SaveService.instance != null:
		# In-memory maxed tree; the write lock keeps it off the dev's disk.
		SaveService.instance.profile["meta_tree"] = MetaTree.maxed_state(
			MetaTree.load_tree()
		)
		SaveService.instance._write_locked = true
	if _run_seed != 0:
		seed(_run_seed)  # drives the stage's randi() field seed
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_spawner = _stage.get_node("World/Spawner")
	if _run_seed != 0:
		# The stage seeds these from entropy in _ready; override before the
		# first level-up / drop so a seed replays choices and loot too.
		_stage._choice_rng.seed = _run_seed + 1
		_stage._loot_rng.seed = _run_seed + 2
	if _forced != "":
		_force_build(_forced)
	# N4-4b: --grant hands the run extra weapons at start, so a surge can be
	# load-tested with specific mechanics the picker bot might never draw.
	for weapon_id: String in _grants:
		_grant_weapon(weapon_id)
	_spawner.burn_damaged.connect(
		func(amount: float, _at: Vector2) -> void: _damage_total += amount
	)
	# N6-1: hold the bot still until the hint shot lands (no hint = no hold).
	_hint_shown = _stage._move_hint != null
	_hint_shot_done = not _hint_shown
	if not _stage._meta_effects.is_empty():
		# N7-1 evidence line: an owned tree must be visible in the run's
		# actual starting stats, not just in the profile.
		print("META applied: hp_max=%.1f effects=%s" % [
			_player.hp_max, str(_stage._meta_effects)
		])


func _reset_run_metrics() -> void:
	_pick_wait = 0.0
	_surge_shot_done = false
	_result_shot_done = false
	_fps_min = 1e9
	_fps_sum = 0.0
	_fps_samples = 0
	_special_times = []
	_grade_picks = 0
	_mod_offers = 0
	_mod_shot_done = false
	_real_elapsed = 0.0
	_midrun_shot_done = false
	_fps_min_all = 1e9
	_peak_live = 0
	_overlap_sum = 0.0
	_overlap_samples = 0
	_overlap_timer = 0.0
	_damage_total = 0.0
	_tracked_weapons = []
	_skipped_screens = 0
	_evo_violations = 0


## N4-3 forced build: swap the character's starting weapon for the named one
## so a run measures exactly one weapon's output.
func _force_build(weapon_id: String) -> void:
	var start_id: String = Player.load_starting_weapon()
	if weapon_id == start_id:
		return
	_stage._owned_levels.erase(start_id)
	_stage._owned_grades.erase(start_id)
	var node: AutoWeapon = _stage._weapon_nodes.get(start_id)
	_stage._weapon_nodes.erase(start_id)
	if node != null:
		node.queue_free()
	_grant_weapon(weapon_id)


func _grant_weapon(weapon_id: String) -> void:
	if _stage._owned_levels.has(weapon_id):
		return
	_stage._owned_levels[weapon_id] = 1
	_stage._owned_grades[weapon_id] = LevelUp.current_grade(
		weapon_id, _stage._weapons_data, {}
	)
	_stage._add_weapon_node(weapon_id)


func _process(delta: float) -> void:
	if _stage == null:
		return
	_real_elapsed += delta
	if _real_elapsed > _duration + TIMEOUT_GRACE_SEC:
		print("PLAYTEST FAIL: run did not finish within grace window")
		get_tree().quit(1)
		return
	var elapsed: float = _stage._run_elapsed
	if not get_tree().paused:
		if elapsed >= _surge_at and elapsed < _boss_at:
			var fps: float = Engine.get_frames_per_second()
			_fps_min = minf(_fps_min, fps)
			_fps_sum += fps
			_fps_samples += 1
		# Whole-run fps floor; skip the first second while the scene warms up.
		if _real_elapsed > 1.0:
			_fps_min_all = minf(_fps_min_all, Engine.get_frames_per_second())
	if not _hint_shot_done and elapsed >= HINT_SHOT_AT_SEC:
		_hint_shot_done = true
		_capture(HINT_SHOT_PATH)
	if not _midrun_shot_done and elapsed >= MIDRUN_SHOT_AT_SEC:
		_midrun_shot_done = true
		_capture(MIDRUN_SHOT_PATH)
	if not _surge_shot_done and elapsed >= _surge_at + SURGE_SHOT_DELAY_SEC:
		_surge_shot_done = true
		_capture(SURGE_SHOT_PATH)
	if _stage._outcome != RunFlow.OUTCOME_NONE and not _result_shot_done:
		_result_shot_done = true
		_finish()


func _physics_process(delta: float) -> void:
	if _stage == null or _result_shot_done:
		return
	_track_weapon_damage()
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
	if not _hint_shot_done:
		_release_moves()
		return
	_pick_wait = PICK_COOLDOWN_SEC
	_peak_live = maxi(_peak_live, _spawner.active_enemies().size())
	_overlap_timer -= delta
	if _overlap_timer <= 0.0:
		_overlap_timer = OVERLAP_SAMPLE_SEC
		_sample_overlap()
	_steer()


## N4-3: every weapon node (including mod swaps appearing mid-run) reports
## its landed damage into the run total; DoT ticks arrive via burn_damaged.
func _track_weapon_damage() -> void:
	for weapon_id: String in _stage._weapon_nodes:
		if weapon_id in _tracked_weapons:
			continue
		_tracked_weapons.append(weapon_id)
		(_stage._weapon_nodes[weapon_id] as AutoWeapon).hit_landed.connect(
			func(amount: float, _at: Vector2, _boss: bool) -> void:
				_damage_total += amount
		)


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


## Brute-force is fine here: a once-per-second diagnostic in a tool script,
## never game code.
func _sample_overlap() -> void:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var stacked: int = 0
	for i: int in range(enemies.size()):
		for j: int in range(enemies.size()):
			if i == j:
				continue
			var limit: float = (
				(enemies[i].contact_radius + enemies[j].contact_radius) * OVERLAP_RATIO
			)
			var distance_squared: float = enemies[i].global_position.distance_squared_to(
				enemies[j].global_position
			)
			if distance_squared < limit * limit:
				stacked += 1
				break
	_overlap_sum += float(stacked)
	_overlap_samples += 1


func _release_moves() -> void:
	for action: String in MOVE_ACTIONS:
		Input.action_release(action)


## Card priority proves the N4-6 targets: the 개조 card first (folded-in mod
## flow, screenshot on first sight), then grade raises, then weapon levels,
## then whatever is left. N4-3 adds the forced single-weapon policy and the
## deliberately-bad --nopick policy on top.
func _pick_card() -> void:
	if _no_pick:
		_stage._popup.dismissed.emit()
		return
	var buttons: Array[Button] = []
	_collect_buttons(_stage._popup, buttons)
	if buttons.is_empty():
		return
	var mod_on_screen: bool = false
	for button: Button in buttons:
		if _button_has_label(button, LevelUp.MOD_LABEL):
			mod_on_screen = true
			break
	# N4-7: a mod result showing up as a 신규! card means the evolution_only
	# exclusion regressed — count it so the report proves the run stayed clean.
	for button: Button in buttons:
		var labels: Array[Label] = []
		for child: Node in button.get_children():
			if child is Label:
				labels.append(child)
		if labels.size() >= 2 and labels[0].text == LevelUpPopup.NEW_LABEL \
				and labels[1].text in _evo_result_names:
			_evo_violations += 1
	if mod_on_screen:
		_mod_offers += 1
	var chosen: Button = null
	if _forced != "":
		chosen = _choose_forced(buttons)
		if chosen == null:
			# No card for the forced weapon (and no passive) — skip the screen
			# rather than pollute the single-weapon build.
			_skipped_screens += 1
			_stage._popup.dismissed.emit()
			return
	else:
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


## N4-3 forced policy: only cards that grow the forced weapon (its 개조,
## grade raise, level) or a passive. Never a second weapon.
func _choose_forced(buttons: Array[Button]) -> Button:
	# The single owned weapon's display name — follows the 개조 swap too.
	var owned_name: String = ""
	for weapon_id: String in _stage._owned_levels:
		owned_name = String(
			(_weapons_json.get(weapon_id, {}) as Dictionary).get("name_ko", weapon_id)
		)
	var passive_pick: Button = null
	var grade_pick: Button = null
	var level_pick: Button = null
	for button: Button in buttons:
		var labels: Array[Label] = []
		for child: Node in button.get_children():
			if child is Label:
				labels.append(child)
		if labels.size() < 3:
			continue
		# Card layout (LevelUpPopup._make_card): [well_label, name, desc].
		var well: String = labels[0].text
		var card_name: String = labels[1].text
		var desc: String = labels[2].text
		if well == LevelUp.MOD_LABEL and desc.begins_with(owned_name + " "):
			return button  # the forced weapon's 개조 outranks everything
		if card_name == owned_name and well.begins_with("Lv."):
			level_pick = button
		elif card_name == owned_name and well == LevelUp.GRADE_UP_LABEL:
			grade_pick = button
		elif card_name in _passive_names and passive_pick == null:
			passive_pick = button
	if grade_pick != null:
		return grade_pick
	if level_pick != null:
		return level_pick
	return passive_pick


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
	if _headless:
		return  # no frames to grab without a rendering device
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("PLAYTEST shot: " + ProjectSettings.globalize_path(path))


func _finish() -> void:
	await _capture(RESULT_SHOT_PATH)
	var fps_avg: float = _fps_sum / float(maxi(_fps_samples, 1))
	var elapsed: float = _stage._run_elapsed
	print("PLAYTEST outcome: %s at %.1fs" % [_stage._outcome, elapsed])
	print("PLAYTEST level: %d (level-ups: %d, skipped screens: %d)" % [
		_stage._run_state.level, _stage._run_state.level - 1, _skipped_screens
	])
	print("PLAYTEST weapons: %s (replaced: %s)" % [
		str(_stage._owned_levels), str(_stage._replaced_weapons)
	])
	print("PLAYTEST grades: %s (grade picks: %d)" % [str(_stage._owned_grades), _grade_picks])
	print("PLAYTEST surge fps: min %.0f avg %.0f over %d samples" % [
		_fps_min if _fps_samples > 0 else 0.0, fps_avg, _fps_samples
	])
	print("PLAYTEST mod cards: offered on %d screens, taken %d at %s" % [
		_mod_offers, _special_times.size(), str(_special_times)
	])
	print("PLAYTEST mod results offered as new weapon: %d" % _evo_violations)
	print("PLAYTEST fps floor (whole run): %.0f" % (
		_fps_min_all if _fps_min_all < 1e9 else 0.0
	))
	print("PLAYTEST crowd: peak live %d, avg stacked %.2f over %d samples" % [
		_peak_live, _overlap_sum / float(maxi(_overlap_samples, 1)), _overlap_samples
	])
	print("PLAYTEST kills: %d gold: %d" % [_stage._kills, _stage._gold])
	print("PLAYTEST first-run: hint shown %s, guarantees %d, fired %s" % [
		str(_hint_shown), _stage._first_run_drops.size(), str(_stage._first_run_log)
	])
	if _stage._boss != null:
		print("PLAYTEST boss hp left: %.0f / %.0f" % [_stage._boss.hp, _stage._boss_hp_max])
	else:
		print("PLAYTEST boss killed")
	print("PLAYTEST damage total: %.0f (%.1f dps over %.1fs)" % [
		_damage_total, _damage_total / maxf(elapsed, 0.001), elapsed
	])
	if _forced != "":
		_rows.append({
			"weapon": _forced,
			"outcome": _stage._outcome,
			"time": elapsed,
			"level": _stage._run_state.level,
			"kills": _stage._kills,
			"damage": _damage_total,
			"dps": _damage_total / maxf(elapsed, 0.001),
			"fps_min": _fps_min_all if _fps_min_all < 1e9 else 0.0,
			"final_build": str(_stage._owned_levels),
		})
	if _batch and _batch_index < BATCH_WEAPONS.size() - 1:
		_batch_index += 1
		_forced = BATCH_WEAPONS[_batch_index]
		await _next_run()
		return
	if _batch:
		_print_table()
	get_tree().quit(0)


## Tear the finished stage down and boot the next batch weapon's run.
func _next_run() -> void:
	get_tree().paused = false
	_release_moves()
	_stage.queue_free()
	_stage = null
	_player = null
	_spawner = null
	await get_tree().process_frame
	await get_tree().process_frame
	_start_run()


## The measurement table N4-3 tunes against. Columns per forced 5-minute run:
## total damage dealt, kills, run-averaged dps, time survived, level reached,
## and the whole-run fps floor (only meaningful in a rendered 1x run).
func _print_table() -> void:
	print("BALANCE TABLE seed=%d speed=%.1f headless=%s" % [
		_run_seed, _speed, str(_headless)
	])
	print("| weapon | outcome | time_s | level | kills | damage | dps | fps_min | final build |")
	print("|---|---|---|---|---|---|---|---|---|")
	for row: Dictionary in _rows:
		print("| %s | %s | %.1f | %d | %d | %.0f | %.1f | %.0f | %s |" % [
			String(row["weapon"]), String(row["outcome"]), float(row["time"]),
			int(row["level"]), int(row["kills"]), float(row["damage"]),
			float(row["dps"]), float(row["fps_min"]), String(row["final_build"]),
		])
