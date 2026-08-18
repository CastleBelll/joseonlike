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
			print("PICKUP CHECK done")
			get_tree().quit(0)
			return
	_step += 1
	_busy = false


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
	await RenderingServer.frame_post_draw
	var path: String = "user://pickup_check_%s.png" % name_part
	get_viewport().get_texture().get_image().save_png(path)
	print("PICKUP shot: " + ProjectSettings.globalize_path(path))
