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
##   --runs=<n>      (N4-9) n seeded free-play runs (seed, seed+1, …) on an
##                   in-memory RETURNING profile, ending in a RARITY TABLE of
##                   specials dropped and evolutions performed per run.
##   --meta=gold:<n> (N9-54) spend <n> gold on the tree first, always buying the
##                   cheapest available node — measures what PARTIAL ladder
##                   progress buys, which --meta=max cannot say.
##   --luck=max      (N4-9) only the 천운 node at max rank, in memory only —
##                   isolates the luck stat's effect on special drops.
##   --fresh         (N4-9) run on a brand-new in-memory profile: the FTUE
##                   first-run guarantee path (scripted drops + free 개조).
## Screenshots are skipped in headless mode (no frames to grab).
## Every timing below derives from data/stages.json duration_sec/boss_at_sec/
## surge_at_sec — nothing here hardcodes the run length.

const STAGE_SCENE := "res://scenes/stage.tscn"
const SURGE_SHOT_PATH := "user://playtest_surge.png"
const RESULT_SHOT_PATH := "user://playtest_result.png"
const MOD_SHOT_PATH := "user://playtest_mod_card.png"
const MIDRUN_SHOT_PATH := "user://playtest_midrun.png"
## N4-8: first level-up card that crosses a milestone (★ in its description).
const MILESTONE_SHOT_PATH := "user://playtest_milestone_card.png"
const MIDRUN_SHOT_AT_SEC := 75.0
## N9-49: the boss telegraphs are the only thing on screen the player must read
## and react to, so the run has to prove they actually drew, not just that the
## scheduler ran. Fires on the first warning shape of each shape kind (disc and
## band) — one shot each, because a band that looks like a disc is the failure.
const BOSS_DISC_SHOT_PATH := "user://playtest_boss_disc.png"
const BOSS_BAND_SHOT_PATH := "user://playtest_boss_band.png"
## N6-1: capture the move hint before the bot's first input dismisses it.
const HINT_SHOT_PATH := "user://playtest_move_hint.png"
const HINT_SHOT_AT_SEC := 0.6
## N6-2: the opening rush mid-swarm and the low-HP warning the moment it fires.
const OPENING_SHOT_PATH := "user://playtest_opening.png"
const OPENING_SHOT_AT_SEC := 12.0
const LOW_HP_SHOT_PATH := "user://playtest_low_hp.png"
## N6-3: the first heal landing (elite kill or health pickup).
const HEAL_SHOT_PATH := "user://playtest_heal.png"
## N6-4 rush/level-up separation metric: the rush counts as "converged" the
## first second this many enemies stand inside the radius around the player.
const CONVERGE_RADIUS_PX := 250.0
const CONVERGE_COUNT := 8
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
## N6-2 opening metrics: damage-taken window and the standing-still bot's
## early stop (the opening is proven by then; a full idle run adds nothing).
## N6-3 widened to 30s: the first level-up popup (~23s) and the rush
## convergence both sit inside the measured window.
const DAMAGE_WINDOW_SEC := 30.0
## N6-3 recovery evidence: player HP sampled at the first-elite second and at
## the boss spawn second (mirrors the shipped 120s elite wave).
const ELITE_SAMPLE_SEC := 120.0
const IDLE_QUIT_SEC := 45.0
## N4-3: the base taoist weapons a run can start on (non-evolution_only).
## N9-5e: 화부/뇌부/살 became exclusive talisman branches (evolution_only),
## so the startable roster is seven.
const BATCH_WEAPONS: Array[String] = [
	"old_talisman", "seokjang", "honbul",
	"beopgeom", "gyeolgye", "sinjang", "jineon",
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
var _boss_disc_shot_done: bool = false
var _boss_band_shot_done: bool = false
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
## N4-8: --level=<n> starts the forced weapon at level n (with --nopick this
## pins a run to one exact growth point for per-level measurement).
var _start_level: int = 1
var _milestone_shot_done: bool = false
var _batch: bool = false
var _batch_index: int = 0
var _no_pick: bool = false
var _run_seed: int = 0  # 0 = unseeded (default free-play behaviour)
var _speed: float = 1.0
var _grants: Array[String] = []
var _meta_max: bool = false
# N4-9 rarity batch state.
var _runs_total: int = 0
var _run_index: int = 0
var _luck_max: bool = false
var _fresh: bool = false
## N9-54: gold budget to spend on the meta tree before the run, for measuring
## what PARTIAL progress buys. "--meta=max" answers what the end of the ladder
## feels like; it cannot say whether the middle of it is worth walking.
var _meta_gold: int = 0
var _rarity_rows: Array[Dictionary] = []
var _headless: bool = false
var _damage_total: float = 0.0
# N6-2: --idle holds the bot still; the opening must hurt it but not kill a
# moving player. Both modes report first level-up time and 0-20s damage taken.
var _idle: bool = false
var _first_level_up_at: float = -1.0
# N6-3: HP snapshots at the elite/boss beats (-1 = never reached), the heal
# screenshot latch, and the elite-kill count the heal budget prices.
var _hp_at_elite: float = -1.0
var _hp_at_boss: float = -1.0
var _heal_shot_done: bool = false
var _elite_kills: int = 0
# N6-4: rush-convergence timestamp, the first popup's close time, and how
# many enemies stood near the player at that close (the ambush measure).
var _converge_at: float = -1.0
var _first_popup_closed_at: float = -1.0
var _near_at_popup_close: int = -1
var _damage_taken_open: float = 0.0
var _prev_hp: float = 0.0
var _opening_shot_done: bool = false
var _low_hp_shot_done: bool = false
var _low_hp_threshold: float = 0.0
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
	var effects: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Spawner.EFFECTS_PATH)
	)
	_low_hp_threshold = float(
		(effects.get("hit_feedback", {}) as Dictionary).get("low_hp_threshold", 0.0)
	)
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
	if _runs_total > 0 and _run_seed == 0:
		_run_seed = DEFAULT_BATCH_SEED
	_start_run()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--grant="):
			for weapon_id: String in arg.get_slice("=", 1).split(","):
				_grants.append(weapon_id)
		elif arg.begins_with("--weapon="):
			_forced = arg.get_slice("=", 1)
		elif arg.begins_with("--level="):
			_start_level = maxi(int(arg.get_slice("=", 1)), 1)
		elif arg.begins_with("--seed="):
			_run_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--speed="):
			_speed = maxf(float(arg.get_slice("=", 1)), 0.1)
		elif arg == "--batch":
			_batch = true
		elif arg == "--nopick":
			_no_pick = true
		elif arg == "--idle":
			_idle = true
		elif arg == "--meta=max":
			_meta_max = true
		elif arg.begins_with("--meta=gold:"):
			_meta_gold = maxi(int(arg.get_slice(":", 1)), 0)
		elif arg.begins_with("--runs="):
			_runs_total = maxi(int(arg.get_slice("=", 1)), 0)
		elif arg == "--luck=max":
			_luck_max = true
		elif arg == "--fresh":
			_fresh = true


## Spends `budget` gold on the cheapest available node each step — the way a
## player actually climbs, taking what they can afford rather than saving for
## one expensive thing. Reports what the budget bought so a measurement can be
## read back later without re-deriving it.
func _tree_bought_with(budget: int) -> Dictionary:
	var tree: Dictionary = MetaTree.load_tree()
	var profile: Dictionary = SaveService.instance.profile.duplicate(true)
	profile["gold"] = budget
	profile["meta_tree"] = {}
	var unlocked: Array[String] = MetaTree.unlocked_characters(MetaTree.load_characters())
	var bought: int = 0
	while true:
		var state: Dictionary = profile.get("meta_tree", {})
		var gold: int = int(profile.get("gold", 0))
		var best_id: String = ""
		var best_cost: int = 0
		for entry: Dictionary in MetaTree.nodes(tree):
			var id: String = String(entry.get("id", ""))
			if MetaTree.can_purchase(tree, state, gold, id, unlocked) != MetaTree.REASON_OK:
				continue
			var cost: int = MetaTree.next_cost(entry, MetaTree.rank_of(state, id))
			if best_id.is_empty() or cost < best_cost:
				best_id = id
				best_cost = cost
		if best_id.is_empty():
			break
		var result: Dictionary = MetaTree.purchase(profile, tree, best_id, unlocked)
		if not bool(result.get("ok", false)):
			break
		profile = result["profile"]
		bought += 1
	print("PLAYTEST meta budget %d gold: %d ranks bought, %d unspent" % [
		budget, bought, int(profile.get("gold", 0))
	])
	return profile


## Boot one run: fresh stage, seeded streams, forced/granted weapons, and the
## damage-total hooks the balance table reads.
func _start_run() -> void:
	_reset_run_metrics()
	if _fresh and SaveService.instance != null:
		# N4-9 FTUE probe: a brand-new profile, in memory only.
		SaveService.instance.profile = SaveProfile.default_profile()
		SaveService.instance._write_locked = true
	elif _runs_total > 0 and SaveService.instance != null:
		# N4-9 rarity batch: a RETURNING profile (runs_played > 0, FTUE spent)
		# so the scripted first-run guarantees stay out of the measurement.
		var returning: Dictionary = SaveProfile.default_profile()
		(returning["stats"] as Dictionary)["runs_played"] = 1
		returning[Ftue.FTUE_KEY] = {Ftue.MOVE_HINT_SEEN: true, Ftue.MOD_EXPLAINED: true}
		SaveService.instance.profile = returning
		SaveService.instance._write_locked = true
	if _meta_max and SaveService.instance != null:
		# In-memory maxed tree; the write lock keeps it off the dev's disk.
		SaveService.instance.profile["meta_tree"] = MetaTree.maxed_state(
			MetaTree.load_tree()
		)
		SaveService.instance._write_locked = true
	elif _meta_gold > 0 and SaveService.instance != null:
		SaveService.instance.profile = _tree_bought_with(_meta_gold)
		SaveService.instance._write_locked = true
	elif _luck_max and SaveService.instance != null:
		# N4-9: ONLY the luck node maxed, so the batch isolates its effect.
		var maxed: Dictionary = MetaTree.maxed_state(MetaTree.load_tree())
		SaveService.instance.profile["meta_tree"] = {"luck": int(maxed.get("luck", 0))}
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
		if _start_level > 1:
			_stage._owned_levels[_forced] = _start_level
			(_stage._weapon_nodes[_forced] as AutoWeapon).set_level(_start_level)
	# N4-4b: --grant hands the run extra weapons at start, so a surge can be
	# load-tested with specific mechanics the picker bot might never draw.
	for weapon_id: String in _grants:
		_grant_weapon(weapon_id)
	_spawner.burn_damaged.connect(
		func(amount: float, _at: Vector2) -> void: _damage_total += amount
	)
	# N6-3: elite kills price the run's heal budget (Pickups.heal_budget).
	_spawner.enemy_killed.connect(
		func(enemy: Enemy) -> void:
			if enemy.is_elite:
				_elite_kills += 1
	)
	# N6-1: hold the bot still until the hint shot lands (no hint = no hold).
	_hint_shown = _stage._move_hint != null
	_hint_shot_done = not _hint_shown
	_prev_hp = _player.hp
	_stage._run_state.level_reached.connect(
		func(_new_level: int) -> void:
			if _first_level_up_at < 0.0:
				_first_level_up_at = _stage._run_elapsed
	)
	if not _stage._meta_effects.is_empty():
		# N7-1 evidence line: an owned tree must be visible in the run's
		# actual starting stats, not just in the profile.
		print("META applied: hp_max=%.1f effects=%s" % [
			_player.hp_max, str(_stage._meta_effects)
		])
	# N7-2 evidence line: the forced weapon's LIVE mechanic config, so a 술법
	# branch node's change (chain jumps, burn duration…) is measurable.
	if _forced != "" and _stage._weapon_nodes.has(_forced):
		var stats: Dictionary = (_stage._weapon_nodes[_forced] as AutoWeapon)._stats
		for key: String in ["chain", "ward", "on_hit_status", "on_hit_seal"]:
			if stats.has(key):
				print("PLAYTEST weapon %s %s: %s" % [_forced, key, str(stats[key])])
		if String(stats.get("mechanic", "")) == "orbit":
			print("PLAYTEST weapon %s orbs: %d" % [
				_forced, int(stats.get("projectile_count", 1))
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
	_first_level_up_at = -1.0
	_hp_at_elite = -1.0
	_hp_at_boss = -1.0
	_heal_shot_done = false
	_elite_kills = 0
	_converge_at = -1.0
	_first_popup_closed_at = -1.0
	_near_at_popup_close = -1
	_damage_taken_open = 0.0
	_opening_shot_done = false
	_low_hp_shot_done = false
	_tracked_weapons = []
	_skipped_screens = 0
	_evo_violations = 0
	_milestone_shot_done = false


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
	_clear_guide()
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
	# N6-2: the standing-still probe has proven its point once the opening
	# window is well past — report and stop instead of idling to a sure death.
	if _idle and elapsed >= IDLE_QUIT_SEC and _stage._outcome == RunFlow.OUTCOME_NONE \
			and not _result_shot_done:
		print("PLAYTEST idle probe stopped at %.1fs" % elapsed)
		_result_shot_done = true
		_finish()
		return
	if not _hint_shot_done and elapsed >= HINT_SHOT_AT_SEC:
		_hint_shot_done = true
		_capture(HINT_SHOT_PATH)
	if not _opening_shot_done and elapsed >= OPENING_SHOT_AT_SEC:
		_opening_shot_done = true
		_capture(OPENING_SHOT_PATH)
	if not _heal_shot_done and _stage._heal_events > 0:
		_heal_shot_done = true
		_capture(HEAL_SHOT_PATH)
	if not _low_hp_shot_done and _player != null and CombatMath.is_low_hp(
		_player.hp, _player.hp_max, _low_hp_threshold
	):
		_low_hp_shot_done = true
		_capture(LOW_HP_SHOT_PATH)
	if not _midrun_shot_done and elapsed >= MIDRUN_SHOT_AT_SEC:
		_midrun_shot_done = true
		_capture(MIDRUN_SHOT_PATH)
	_watch_boss_telegraphs()
	if not _surge_shot_done and elapsed >= _surge_at + SURGE_SHOT_DELAY_SEC:
		_surge_shot_done = true
		_capture(SURGE_SHOT_PATH)
	if _stage._outcome != RunFlow.OUTCOME_NONE and not _result_shot_done:
		_result_shot_done = true
		_finish()


func _physics_process(delta: float) -> void:
	if _stage == null or _result_shot_done:
		return
	# N6-2: hp lost inside the opening window (increases from passives/meta
	# never count — only drops do).
	var hp_drop: float = maxf(_prev_hp - _player.hp, 0.0)
	_prev_hp = _player.hp
	if _stage._run_elapsed <= DAMAGE_WINDOW_SEC:
		_damage_taken_open += hp_drop
	_track_weapon_damage()
	_track_convergence()
	# N6-3: first sample at or past each beat second (physics cadence).
	if _hp_at_elite < 0.0 and _stage._run_elapsed >= ELITE_SAMPLE_SEC:
		_hp_at_elite = _player.hp
	if _hp_at_boss < 0.0 and _stage._run_elapsed >= _boss_at:
		_hp_at_boss = _player.hp
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
	if _idle or not _hint_shot_done:
		_release_moves()
		return
	_pick_wait = PICK_COOLDOWN_SEC
	_peak_live = maxi(_peak_live, _spawner.active_enemies().size())
	_overlap_timer -= delta
	if _overlap_timer <= 0.0:
		_overlap_timer = OVERLAP_SAMPLE_SEC
		_sample_overlap()
	_steer()


## N6-4: rush-convergence timestamp (first frame CONVERGE_COUNT enemies stand
## within CONVERGE_RADIUS_PX) and the enemy pressure at the moment the first
## popup releases the pause — the two beats the schedule must keep apart.
func _track_convergence() -> void:
	if _converge_at >= 0.0 and _first_popup_closed_at >= 0.0:
		return
	var near: int = 0
	var reach_squared: float = CONVERGE_RADIUS_PX * CONVERGE_RADIUS_PX
	for enemy: Enemy in _spawner.active_enemies():
		if _player.global_position.distance_squared_to(enemy.global_position) <= reach_squared:
			near += 1
	if _converge_at < 0.0 and near >= CONVERGE_COUNT:
		_converge_at = _stage._run_elapsed
	if _first_popup_closed_at < 0.0 and _first_level_up_at >= 0.0 \
			and not get_tree().paused:
		_first_popup_closed_at = _stage._run_elapsed
		_near_at_popup_close = near


## N4-3: every weapon node (including mod swaps appearing mid-run) reports
## its landed damage into the run total; DoT ticks arrive via burn_damaged.
func _track_weapon_damage() -> void:
	for weapon_id: String in _stage._weapon_nodes:
		if weapon_id in _tracked_weapons:
			continue
		_tracked_weapons.append(weapon_id)
		(_stage._weapon_nodes[weapon_id] as AutoWeapon).hit_landed.connect(
			func(amount: float, _at: Vector2, _boss: bool, _crit: bool) -> void:
				_damage_total += amount
		)


## N9-36: the first-run guide now HOLDS the world until it reaches its combat
## page, so a bot that ignores the dialog never gets a run at all — --fresh
## measured a 420s timeout with zero kills before this. The bot answers each
## page the way a player would: tap pages get the button, await pages get the
## action they wait for. The kill page needs no help — the world is already
## released there, so the bot's own weapon satisfies it.
func _clear_guide() -> void:
	var guide: GuideDialog = _stage.get_node_or_null("GuideDialog")
	if guide == null:
		return
	var awaiting: String = guide.awaiting()
	if awaiting.is_empty():
		guide._on_next_pressed()
	elif awaiting != Ftue.AWAIT_KILL:
		# Everything except the kill page is answered directly. The bot cannot
		# be relied on to satisfy the MOVE page: with the world held there are
		# no enemies and no orbs, so its steering resolves to zero and it stands
		# still — the guide waits for a step that never comes and the run never
		# starts (observed: 420s, zero kills). The kill page is left alone
		# because by then the world IS running and the bot's own weapon earns
		# it, which is the thing worth measuring.
		guide.notify_action(awaiting)


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
		# N5-5: chests count as seek targets too — walking over one opens it.
		if (child is XpOrb or child is Chest) and (child as Node2D).visible:
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
	# N4-8: capture the first card whose description crosses a milestone —
	# the ★ mark is LevelUp's own milestone glyph, so text and shot agree.
	if not _milestone_shot_done:
		for button: Button in buttons:
			var labels: Array[Label] = []
			for child: Node in button.get_children():
				if child is Label:
					labels.append(child)
			if labels.size() >= 3 and labels[2].text.contains(LevelUp.MILESTONE_MARK):
				_milestone_shot_done = true
				await _capture(MILESTONE_SHOT_PATH)
				break
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
		# N4-9: free-play priority mirrors an evolution-chasing player — the
		# 개조 card first, then LEVEL investment (the level_required gate),
		# then grade raises. Forced-build metrics (_choose_forced) unchanged.
		for wanted: String in [LevelUp.MOD_LABEL, "Lv.", LevelUp.GRADE_UP_LABEL]:
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


## Reports and captures each boss telegraph shape the first time it appears, so
## a run that never reaches the boss says so instead of quietly passing.
func _watch_boss_telegraphs() -> void:
	if _boss_disc_shot_done and _boss_band_shot_done:
		return
	for child: Node in _stage.get_children():
		var telegraph := child as BossTelegraph
		if telegraph == null or not telegraph.visible:
			continue
		if telegraph.is_band():
			if _boss_band_shot_done:
				continue
			_boss_band_shot_done = true
			print("PLAYTEST boss telegraph: band")
			_capture(BOSS_BAND_SHOT_PATH)
		else:
			if _boss_disc_shot_done:
				continue
			_boss_disc_shot_done = true
			print("PLAYTEST boss telegraph: disc")
			_capture(BOSS_DISC_SHOT_PATH)


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
	print("PLAYTEST boss patterns seen: disc=%s band=%s" % [
		_boss_disc_shot_done, _boss_band_shot_done
	])
	print("PLAYTEST level: %d (level-ups: %d, skipped screens: %d)" % [
		_stage._run_state.level, _stage._run_state.level - 1, _skipped_screens
	])
	# N9-25: exercise the pause character sheet against the REAL run state. The
	# panel is only ever built when a human pauses, so without this a bad format
	# string or a null read would ship and surface as a crash on the pause tap.
	var sheet: Array = _stage._pause_build_summary().get("stats", [])
	var moved: int = 0
	for line: Dictionary in sheet:
		if bool(line.get("modified", false)):
			moved += 1
	print("PLAYTEST stat sheet: %d lines, %d moved off base, sample %s" % [
		sheet.size(), moved,
		"none" if sheet.is_empty() else "%s %s" % [sheet[1]["name"], sheet[1]["value"]],
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
	print("PLAYTEST specials dropped: %d at %s" % [
		_stage._special_drop_times.size(), str(_stage._special_drop_times)
	])
	print("PLAYTEST mod results offered as new weapon: %d" % _evo_violations)
	print("PLAYTEST fps floor (whole run): %.0f" % (
		_fps_min_all if _fps_min_all < 1e9 else 0.0
	))
	print("PLAYTEST crowd: peak live %d, avg stacked %.2f over %d samples" % [
		_peak_live, _overlap_sum / float(maxi(_overlap_samples, 1)), _overlap_samples
	])
	print("PLAYTEST kills: %d gold: %d" % [_stage._kills, _stage._gold])
	# N5-5 evidence: prop breaks by rolled kind, and each opened chest's count.
	var breaks_total: int = 0
	for kind: String in _stage._break_stats:
		breaks_total += int(_stage._break_stats[kind])
	print("PLAYTEST breaks: %d %s" % [breaks_total, str(_stage._break_stats)])
	print("PLAYTEST chests opened: %d counts: %s" % [
		_stage._chest_counts.size(), str(_stage._chest_counts)
	])
	print("PLAYTEST first level-up: %.1fs (idle=%s)" % [_first_level_up_at, str(_idle)])
	print("PLAYTEST rush converge: %.1fs (>=%d within %.0fpx); first popup closed %.1fs with %d near" % [
		_converge_at, CONVERGE_COUNT, CONVERGE_RADIUS_PX,
		_first_popup_closed_at, _near_at_popup_close
	])
	print("PLAYTEST damage taken 0-%.0fs: %.1f (hp now %.1f/%.1f)" % [
		DAMAGE_WINDOW_SEC, _damage_taken_open, _player.hp, _player.hp_max
	])
	print("PLAYTEST hp at %.0fs elite: %.1f, at boss %.0fs: %.1f (max %.1f)" % [
		ELITE_SAMPLE_SEC, _hp_at_elite, _boss_at, _hp_at_boss, _player.hp_max
	])
	# N6-3 recovery evidence: heals actually landed vs the budget the data
	# prices for this run's measured breaks and elite kills.
	var budget_hp: float = Pickups.heal_budget(
		_stage._pickups_data, breaks_total, _elite_kills
	) * _player.hp_max
	print("PLAYTEST heals: %d landed for %.1f hp (budget %.1f hp at %d breaks, %d elite kills)" % [
		_stage._heal_events, _stage._heal_total, budget_hp, breaks_total, _elite_kills
	])
	if _stage._outcome == RunFlow.OUTCOME_DEFEAT:
		print("PLAYTEST death cause: %s" % RunFlow.death_cause_text(_player.last_hit_source))
	print("PLAYTEST first-run: hint shown %s, guarantees %d, fired %s" % [
		str(_hint_shown), _stage._first_run_drops.size(), str(_stage._first_run_log)
	])
	if _stage._boss != null:
		print("PLAYTEST boss hp left: %.0f / %.0f" % [_stage._boss.hp, _stage._boss_hp_max])
	elif _spawner._boss_spawn_done:
		print("PLAYTEST boss killed")
	else:
		print("PLAYTEST boss never spawned (run ended before boss_at_sec)")
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
	if _runs_total > 0:
		_rarity_rows.append({
			"seed": _run_seed,
			"outcome": _stage._outcome,
			"specials": _stage._special_drop_times.size(),
			"offers": _mod_offers,
			"evolutions": _special_times.size(),
		})
		if _run_index < _runs_total - 1:
			_run_index += 1
			_run_seed += 1
			await _next_run()
			return
		_print_rarity_table()
		get_tree().quit(0)
		return
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


## N4-9 rarity evidence: per seeded free-play run, the specials that dropped
## (boss trophy excluded) and the evolutions actually performed.
func _print_rarity_table() -> void:
	print("RARITY TABLE runs=%d base_seed=%d luck_max=%s" % [
		_runs_total, _run_seed - _runs_total + 1, str(_luck_max)
	])
	print("| seed | outcome | specials | mod offers | evolutions |")
	print("|---|---|---|---|---|")
	var special_total: int = 0
	var evo_total: int = 0
	var runs_with_special: int = 0
	var runs_with_evo: int = 0
	for row: Dictionary in _rarity_rows:
		print("| %d | %s | %d | %d | %d |" % [
			int(row["seed"]), String(row["outcome"]), int(row["specials"]),
			int(row["offers"]), int(row["evolutions"]),
		])
		special_total += int(row["specials"])
		evo_total += int(row["evolutions"])
		if int(row["specials"]) > 0:
			runs_with_special += 1
		if int(row["evolutions"]) > 0:
			runs_with_evo += 1
	print("RARITY totals: specials %d (%d/%d runs with any), evolutions %d (%d/%d runs)" % [
		special_total, runs_with_special, _rarity_rows.size(),
		evo_total, runs_with_evo, _rarity_rows.size(),
	])


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
