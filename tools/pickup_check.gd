extends Node
## N5-5 screenshot harness: boots the real stage, force-breaks destructible
## props with each pickup kind pinned (break_table overridden in memory),
## collects each pickup, then spawns a low-count and a high-count elite chest
## and walks the reward sequence — capturing every beat. The player is made
## unhittable so the scripted tour survives the open field.
## Run (rendered): godot --path . res://tools/pickup_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const STEP_GAP_SEC := 0.9
const BREAK_SHOT_DELAY_SEC := 0.15
const COLLECT_SHOT_DELAY_SEC := 0.2
const HEALTH_TEST_HP_RATIO := 0.4

var _stage: Stage
var _player: Player
var _step: int = 0
var _wait: float = 1.2
var _pickup: Pickup
var _waiting_collect: bool = false
var _pick_wait: float = 0.0
## _process keeps firing while a step's await is suspended — this gate keeps
## a long step (the chest sequences) from being re-entered mid-flight.
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_player.set_damage_taken_scale(0.0)


func _process(delta: float) -> void:
	if _busy:
		return
	# A power-up popup from stray XP would stall the tour — auto-press through
	# any screen that is not one of the scripted chest screens.
	if get_tree().paused and _stage._popup.visible and not _step_is_chest():
		_pick_wait -= delta
		if _pick_wait <= 0.0:
			_pick_wait = 0.4
			_press_first_card()
		return
	if _waiting_collect:
		if _pickup != null and _pickup.visible:
			return
		_waiting_collect = false
		_wait = COLLECT_SHOT_DELAY_SEC
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = STEP_GAP_SEC
	_busy = true
	match _step:
		0:
			_break_with("gold")
		1:
			await _shot("pickup_break")  # shattered prop + the spawned pickup
			_attract()
		2:
			await _shot("pickup_gold")
			_player.hp = _player.hp_max * HEALTH_TEST_HP_RATIO
			_break_with("health")
			_attract()
		3:
			await _shot("pickup_health")
			# Full-HP rule check: the same pickup must convert to gold instead.
			_player.hp = _player.hp_max
			print("PICKUP full-hp gold before: %d" % _stage._gold)
			_break_with("health")
			_attract()
		4:
			print("PICKUP full-hp gold after: %d" % _stage._gold)
			await _shot("pickup_health_full")
			_break_with("nuke")
			_attract()
		5:
			await _shot("pickup_nuke")
			_break_with("magnet")
			_attract()
		6:
			await _shot("pickup_magnet")
			_elite_heal_probe()
		7:
			await _shot("elite_heal")
			_force_chest_weights({"1": 100.0})
			_spawn_chest()
		8:
			await _chest_sequence("chest_1")
			_force_chest_weights({"5": 100.0})
			_spawn_chest()
		9:
			await _chest_sequence("chest_5")
			_nuke_cap_probe()
		10:
			await _shot("nuke_boss_cap")
			# Awaited: the probe suspends on a timer, and without the await the
			# step machine walks on and quits before its assertion ever runs.
			await _field_passive_probe()
		11:
			await _minimap_probe()
		12:
			await _magnet_scope_probe()
		13:
			await _impact_probe()
		14:
			print("PICKUP CHECK done")
			get_tree().quit(0)
			return
	_step += 1
	_busy = false


## N9-55: proves the found-passive rule that no unit test can — that a pickup
## placed on the map registers even when the four passive slots are already
## spent. The slot budget is what the level-up screen enforces; walking to
## something visible is meant to get past it.
func _field_passive_probe() -> void:
	var passives: Dictionary = _stage._passives_data
	var ids: Array[String] = Pickups.field_passive_ids(passives, {})
	if ids.size() < LevelUp.PASSIVE_SLOTS + 1:
		push_error("pickup_check: not enough passives to test the slot overflow")
		return
	# Fill every slot with DIFFERENT passives, then drop a fifth one.
	_stage._passive_stacks = {}
	for i: int in range(LevelUp.PASSIVE_SLOTS):
		_stage._passive_stacks[ids[i]] = 1
	var granted: String = ids[LevelUp.PASSIVE_SLOTS]
	var taken_before: int = _stage._passive_stacks.size()
	_pickup = _stage._pickup_pool.acquire()
	_pickup.launch_pickup(
		_player.global_position + Vector2(0.0, -40.0),
		Pickups.KIND_PASSIVE, _player, _stage._orb_config, granted
	)
	# N9-57: place a SECOND one far off-screen first, so the same frame proves
	# both halves of the feature — the badge you can see, and the arrow that
	# says another one is out there.
	var distant: Pickup = _stage._pickup_pool.acquire()
	distant.launch_pickup(
		_player.global_position + Vector2(1400.0, -900.0),
		Pickups.KIND_PASSIVE, _player, _stage._orb_config, ids[0]
	)
	_stage._live_field_passives.append(distant)
	_stage._refresh_markers()
	# Captured BEFORE the magnet takes it: the point of the shot is what the
	# thing looks like lying on the ground, which is the only state a player
	# ever has to spot from a distance.
	await _shot("field_passive")
	# N9-63: a second frame after the sway has moved on, so the two shots
	# together are the proof the arrows animate — a still image cannot show it
	# and a numeric test cannot show it reaching the screen.
	# The pixel diff between two frames cannot separate a moving arrow from a
	# moving monster behind it, so the clock the animation runs on is checked
	# directly: if it never advances, the arrows are frozen whatever the
	# sway math says.
	var markers: OffscreenMarkers = _stage.get_node_or_null("Hud/OffscreenMarkers")
	var before: float = 0.0 if markers == null else markers._elapsed
	await get_tree().create_timer(0.55).timeout
	if markers == null:
		push_error("pickup_check: no arrow layer to animate")
	elif markers._elapsed <= before:
		push_error("pickup_check: the arrow animation clock never advanced")
	else:
		print("PICKUP arrows animating: clock %.2fs -> %.2fs" % [before, markers._elapsed])
	await _shot("field_passive_moved")
	_attract()
	await get_tree().create_timer(0.6).timeout
	var taken_after: int = _stage._passive_stacks.size()
	if int(_stage._passive_stacks.get(granted, 0)) < 1:
		push_error("pickup_check: a found passive did not register at all")
	elif taken_after != taken_before + 1:
		push_error("pickup_check: found passive did not get past the slot budget (%d -> %d)" % [
			taken_before, taken_after
		])
	else:
		print("PICKUP field passive: %d taken -> %d with %d slots, gained '%s'" % [
			taken_before, taken_after, LevelUp.PASSIVE_SLOTS, granted
		])


## N9-59: the map is a PURCHASE, so the run must not draw one until it is
## owned. Both halves are checked here — absent while locked, present with
## blips once bought — because "it appeared" and "it appeared for the right
## reason" are different claims.
func _minimap_probe() -> void:
	if _stage.get_node_or_null("Hud/Minimap") != null:
		push_error("pickup_check: the map exists without the unlock")
	# N9-65: the map is EARNED, not bought. Granted here the way a finished run
	# grants it — through the achievement — so this probe still exercises the
	# real path rather than writing the id in by hand.
	SaveService.instance._write_locked = true
	SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
	var profile: Dictionary = SaveService.instance.profile.duplicate(true)
	profile[Achievements.COUNTERS_KEY] = {"victories": 1.0, "taoist.victories": 1.0}
	profile["selected_character"] = "taoist"
	var awarded: Dictionary = Achievements.evaluate(
		profile, SaveService.instance.achievement_data()
	)
	SaveService.instance.profile = awarded["profile"]
	if not Unlocks.is_unlocked(SaveService.instance.profile, Unlocks.MAP):
		push_error("pickup_check: the achievement did not grant the map")
		return
	# Something to actually mark: a drop placed away from the player.
	var far: Pickup = _stage._pickup_pool.acquire()
	far.launch_pickup(
		_player.global_position + Vector2(700.0, -500.0),
		Pickups.KIND_PASSIVE, _player, _stage._orb_config, "max_hp"
	)
	_stage._live_field_passives.append(far)
	_stage._minimap_wait = 0.0
	await get_tree().create_timer(0.4).timeout
	var map: Minimap = _stage.get_node_or_null("Hud/Minimap")
	if map == null:
		push_error("pickup_check: the map did not appear after the unlock (outcome=%s paused=%s)" % [
			_stage._outcome, str(get_tree().paused)
		])
		return
	print("PICKUP minimap: drawn at %s with the unlock owned" % str(map.position))
	await _shot("minimap")


## N9-62 (owner: "자석 아이템 먹었을 때 다른 오브젝트 파괴하고 나온 아이템들은
## 딸려오면 안되고 경험치만 딸려와야지"). Pickup and LootDrop both extend XpOrb,
## so the magnet's `is XpOrb` sweep took them too. The check has to be by
## BEHAVIOUR, not by reading the branch: place one of each far away, fire the
## magnet, and see which ones moved.
func _magnet_scope_probe() -> void:
	var away: Vector2 = _player.global_position + Vector2(520.0, 0.0)
	var orb: XpOrb = _stage._orb_pool.acquire()
	orb.launch(away, 1, _player, _stage._orb_config)
	var drop: LootDrop = _stage._loot_pool.acquire()
	drop.launch_loot(
		away + Vector2(0.0, 40.0), "talisman_paper", UiPalette.LOOT_CORE,
		_player, _stage._orb_config
	)
	var coin: Pickup = _stage._pickup_pool.acquire()
	coin.launch_pickup(away + Vector2(0.0, 80.0), Pickups.KIND_GOLD, _player, _stage._orb_config)
	var drop_at: Vector2 = drop.global_position
	var coin_at: Vector2 = coin.global_position
	_stage._execute_magnet()
	await get_tree().create_timer(0.5).timeout
	# The orb either flew in or was already collected; both mean it answered.
	var orb_moved: bool = not orb.visible 		or orb.global_position.distance_to(away) > 40.0
	var drop_moved: bool = not drop.visible 		or drop.global_position.distance_to(drop_at) > 40.0
	var coin_moved: bool = not coin.visible 		or coin.global_position.distance_to(coin_at) > 40.0
	if not orb_moved:
		push_error("pickup_check: the magnet left an XP orb behind")
	if drop_moved or coin_moved:
		push_error("pickup_check: the magnet pulled loot=%s pickup=%s — XP only" % [
			str(drop_moved), str(coin_moved)
		])
	else:
		print("PICKUP magnet scope: xp pulled, loot and pickups stayed put")
	for node: XpOrb in [drop, coin]:
		if node.visible:
			node.visible = false


## N9-67: hitstop and shake are felt, not read, so what is checked here is that
## they actually FIRE and actually STOP. A freeze that never lifts is the worst
## possible failure — the game would simply hang — and no unit test can see it,
## because the timer runs on real milliseconds outside the frozen world.
func _impact_probe() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	_stage._punch(Impact.NUKE)
	if _stage._shake <= 0.0:
		push_error("pickup_check: a nuke left the camera unshaken")
	if not is_zero_approx(Engine.time_scale):
		push_error("pickup_check: a nuke did not freeze the world")
	var shaken_at: float = _stage._shake
	# Real time, because the world is stopped: waiting on the scene tree here
	# would wait forever.
	var deadline: int = Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < deadline and not is_equal_approx(Engine.time_scale, 1.0):
		await get_tree().process_frame
	if not is_equal_approx(Engine.time_scale, 1.0):
		push_error("pickup_check: the hitstop never lifted — the game is frozen")
		Engine.time_scale = 1.0
		return
	await get_tree().create_timer(0.6).timeout
	if _stage._shake > 0.0:
		push_error("pickup_check: the shake never decayed away")
	elif camera != null and camera.offset.length() > 0.01:
		push_error("pickup_check: the camera kept its shake offset")
	else:
		print("PICKUP impact: froze and lifted, shake %.1f -> 0" % shaken_at)



func _step_is_chest() -> bool:
	return _step >= 8


## N6-3 proof: an elite kill at reduced HP heals the data elite_heal slice
## through the shared heal path (float label + green pulse); the chest the
## elite drops is independent and stays where it fell.
func _elite_heal_probe() -> void:
	var spawner: Spawner = _stage.get_node("World/Spawner")
	var elite: Enemy = spawner._spawn_one("bamboo_brute_elite")
	elite.global_position = _player.global_position + Vector2(90.0, 0.0)
	_player.hp = _player.hp_max * HEALTH_TEST_HP_RATIO
	var before: float = _player.hp
	elite.take_damage(elite.hp + 1.0)
	print("PICKUP elite heal: hp %.1f -> %.1f (max %.1f)" % [
		before, _player.hp, _player.hp_max
	])


## Edge-case proof: a nuke with the boss and an elite alive on screen — both
## take exactly the capped damage and survive (trash beside them dies).
func _nuke_cap_probe() -> void:
	var spawner: Spawner = _stage.get_node("World/Spawner")
	var boss: Enemy = spawner._spawn_one(spawner._boss_id)
	var elite: Enemy = spawner._spawn_one("bamboo_brute_elite")
	boss.global_position = _player.global_position + Vector2(120.0, 0.0)
	elite.global_position = _player.global_position + Vector2(-120.0, 0.0)
	var boss_before: float = boss.hp
	var elite_before: float = elite.hp
	_stage._execute_nuke()
	print("PICKUP nuke cap: boss %s -> %s, elite %s -> %s" % [
		boss_before, boss.hp, elite_before, elite.hp
	])


## Pin the break roll to one kind, then smash the breakable nearest the player.
func _break_with(kind: String) -> void:
	_stage._pickups_data = _stage._pickups_data.duplicate(true)
	_stage._pickups_data["break_table"] = [{"kind": kind, "weight": 1.0}]
	var target: Breakable = null
	var best: float = INF
	for breakable: Breakable in _stage._field.breakables:
		if not breakable.alive():
			continue
		var distance: float = _player.global_position.distance_squared_to(
			breakable.global_position
		)
		if distance < best:
			best = distance
			target = breakable
	if target == null:
		push_error("pickup_check: no breakable left to smash")
		get_tree().quit(1)
		return
	target.take_weapon_damage(9999.0)
	_pickup = null
	for child: Node in _stage.get_children():
		if child is Pickup and (child as Pickup).visible:
			_pickup = child
	_wait = BREAK_SHOT_DELAY_SEC


func _attract() -> void:
	if _pickup != null:
		_pickup.attract_now()
	_waiting_collect = true


func _force_chest_weights(weights: Dictionary) -> void:
	_stage._pickups_data = _stage._pickups_data.duplicate(true)
	(_stage._pickups_data["chest"] as Dictionary)["weights"] = weights
	(_stage._pickups_data["chest"] as Dictionary)["luck_shift"] = {}


func _spawn_chest() -> void:
	var chest: Chest = _stage._chest_pool.acquire()
	# Placed on the player: the walk-over open fires on the next physics tick.
	chest.place(
		_player.global_position, _player,
		float((_stage._pickups_data.get("chest", {}) as Dictionary).get("open_radius_px", 0.0))
	)


## Capture the first reward card, then tap through the whole sequence,
## capturing one mid-sequence screen for the high-count chest.
func _chest_sequence(prefix: String) -> void:
	var guard: int = 0
	var mid_shot_done: bool = false
	while not (_stage._popup.visible and get_tree().paused) and guard < 300:
		guard += 1
		await get_tree().process_frame
	await _shot(prefix + "_first")
	while _stage._popup.visible and guard < 600:
		guard += 1
		_press_first_card()
		await get_tree().process_frame
		await get_tree().process_frame
		if _stage._popup.visible and not mid_shot_done:
			mid_shot_done = true
			await _shot(prefix + "_mid")
		# Give the popup a few frames to settle on the next reward screen.
		for i: int in range(6):
			await get_tree().process_frame


func _press_first_card() -> void:
	var buttons: Array[Button] = []
	_collect_buttons(_stage._popup, buttons)
	if not buttons.is_empty():
		buttons[0].pressed.emit()


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			found.append(child)
		_collect_buttons(child, found)


func _shot(name_part: String) -> void:
	# N9-51: frame_post_draw never fires without a rendering device, so this
	# await hung the whole probe forever headless — the assertions below it
	# could not run at all, and CI had no way to execute this check.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "user://pickup_check_%s.png" % name_part
	get_viewport().get_texture().get_image().save_png(path)
	print("PICKUP shot: " + ProjectSettings.globalize_path(path))
