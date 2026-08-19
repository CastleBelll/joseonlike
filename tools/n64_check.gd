extends Node
## N6-4 evidence harness: boots the real stage with the wave schedule cleared
## (an empty field, no enemies ever), then proves the two owner asks on
## screen — the targeting fallback chain (a weapon shoots a visible
## destructible with no enemy anywhere, and fires along the player's facing
## with nothing in view at all) and the floating joystick (a touch far from
## the old bottom-left pad anchors and drives the stick, HUD buttons keep tap
## priority, and a second finger never cancels movement).
## Run (rendered): godot --path . res://tools/n64_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const STEP_GAP_SEC := 0.6
const PROBE_TIMEOUT_SEC := 6.0
const BREAKABLE_STANDOFF_PX := 120.0
## Long enough for every shot fired before the field was cleared to expire.
const STALE_SHOT_SEC := 2.0
const TOUCH_POINT := Vector2(400.0, 350.0)
const DRAG_POINT := Vector2(450.0, 400.0)

var _stage: Stage
var _player: Player
var _spawner: Spawner
var _joystick: TouchJoystick
var _step: int = 0
var _wait: float = 1.0
var _probe_left: float = 0.0
## instance id -> hp at the previous poll. A TOTAL is useless here: props are
## streamed in and out as the camera moves, so the sum changes for reasons that
## have nothing to do with damage — in both directions.
var _prop_hp: Dictionary = {}
## While true, every breakable that streams in is smashed on sight, which is
## what "nothing in view" has to mean for the forward-shot probe.
var _keep_field_clear: bool = false
## Seconds left to ignore projectiles after the field is cleared. A shot
## already in the air was aimed at a prop that is now rubble, and reading its
## heading as "the forward shot" is how this probe reported a shot flying
## downward while the player faced up.
##
## It is a TIMER rather than "wait for an empty sky", because when the feature
## under test works the sky never empties — the weapon keeps firing forward —
## and waiting for it deadlocked every run into a false red. Identity is no
## help either: projectiles are pooled, so a reused one returns with the same
## instance id.
var _ignore_shots_left: float = 0.0
var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# N9-51: a RETURNING profile, in memory only (the dev's save on disk is
	# never touched). Without it the first-run guide opens and holds every
	# weapon's fire until its combat page — this probe fires at one second and
	# saw nothing, so it had been reporting "no projectile fired" ever since
	# the staged tutorial landed. It tests targeting, not the tutorial.
	if SaveService.instance != null:
		var returning: Dictionary = SaveProfile.default_profile()
		(returning["stats"] as Dictionary)["runs_played"] = 1
		returning[Ftue.FTUE_KEY] = {Ftue.MOVE_HINT_SEEN: true, Ftue.MOD_EXPLAINED: true}
		SaveService.instance.profile = returning
		SaveService.instance._write_locked = true
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_spawner = _stage.get_node("World/Spawner")
	_joystick = _stage.get_node("Hud/VirtualJoystick")
	# Empty field: no wave may ever start, so "no enemies around" holds for
	# the whole tour without fighting the spawner.
	_spawner._pending_waves.clear()
	_spawner._running_waves.clear()


func _process(delta: float) -> void:
	_ignore_shots_left -= delta
	# Both probe budgets tick in REAL time here. They used to be decremented by
	# STEP_GAP_SEC once per poll while the polls ran every 0.05s, so a six-second
	# allowance ran out in half a second — the probe was timing out long before
	# the thing it waits for could reasonably happen.
	_probe_left -= delta
	if _keep_field_clear:
		for breakable: Breakable in _spawner.breakables:
			if breakable.alive():
				breakable.take_weapon_damage(99999.0)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = STEP_GAP_SEC
	match _step:
		0:
			_place_next_to_breakable()
		1:
			await _probe_projectile("n64_target_breakable")
			return
		2:
			_verify_breakable_hit()
			return
		3:
			_clear_field_and_face_up()
		4:
			await _probe_forward_shot()
			return
		5:
			_keep_field_clear = false
		6:
			await _drive_joystick()
		7:
			_verify_button_priority()
		8:
			print("N64 CHECK %s" % ("FAIL" if _failed else "PASS"))
			get_tree().quit(1 if _failed else 0)
	_step += 1


## Step 0: stand off a live prop, facing AWAY from it — the destructible must
## win the fallback over the facing direction, not ride along with it. The
## weapon aims at the NEAREST visible prop (not necessarily the one stood
## next to), so the assertion tracks total field prop HP instead of one prop.
func _place_next_to_breakable() -> void:
	var anchor: Breakable
	for breakable: Breakable in _spawner.breakables:
		if breakable.alive():
			anchor = breakable
			break
	if anchor == null:
		_fail("no live breakable on the field")
		return
	_prop_hp = _prop_hp_snapshot()
	var spot: Vector2 = anchor.global_position + Vector2(-BREAKABLE_STANDOFF_PX, 0.0)
	# An empty bounds rect means UNCLAMPED — that is how Player reads it. The
	# clamp here was unguarded, so it pinned the probe to (0, 0) on every run
	# and never actually stood next to the prop. It passed locally only because
	# a prop happened to sit within weapon range of the origin; on a machine
	# whose scatter put the nearest one 600px away it failed, which is how the
	# bug finally surfaced.
	if _player.bounds.has_area():
		spot = spot.clamp(_player.bounds.position, _player.bounds.end)
	_player.global_position = spot
	_snap_camera()
	_player.last_move_direction = Vector2.LEFT
	_probe_left = PROBE_TIMEOUT_SEC
	print("N64 breakable probe: prop at %s, %d live props, player at %s facing LEFT" % [
		str(anchor.global_position), _prop_hp.size(), str(_player.global_position)
	])


func _prop_hp_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for breakable: Breakable in _spawner.breakables:
		if breakable.alive():
			snapshot[breakable.get_instance_id()] = breakable.hp
	return snapshot


## True when a prop that existed at the previous poll has lost HP since. Props
## appearing or disappearing never count — only one that was there and got hit.
func _damaged_prop() -> String:
	for breakable: Breakable in _spawner.breakables:
		var id: int = breakable.get_instance_id()
		if not _prop_hp.has(id):
			continue
		var before: float = float(_prop_hp[id])
		if breakable.hp < before:
			return "%.0f -> %.0f" % [before, breakable.hp]
	return ""


## Steps 1/4: wait for a live projectile, then capture it in flight. Repeats
## the same step until one shows up or the probe times out.
func _probe_projectile(shot_name: String) -> void:
	var projectile: Projectile = _live_projectile()
	if projectile == null:
		_wait = 0.05
		if _probe_left <= 0.0:
			_fail("no projectile fired during " + shot_name)
			_step += 1
		return
	await _shot(shot_name)
	_wait = STEP_GAP_SEC
	_step += 1


func _live_projectile() -> Projectile:
	if _ignore_shots_left > 0.0:
		return null
	var flying: Array[Projectile] = _live_projectiles()
	return flying[0] if not flying.is_empty() else null


func _live_projectiles() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for weapon: AutoWeapon in _stage._weapon_nodes.values():
		for child: Node in weapon.get_children():
			if child is Projectile and (child as Projectile).visible:
				out.append(child)
	return out


## Teleporting the player leaves the smoothed camera behind, and targeting is
## ON-SCREEN ONLY (N3-15): a prop 120px away is invisible to the weapon while
## the camera is still drifting toward it, so the probe would be measuring the
## camera rather than the fallback chain it means to test.
func _snap_camera() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.reset_smoothing()


## Polled rather than sampled once: a projectile that exists is not yet a
## projectile that has ARRIVED, and how much of its flight fits in one fixed
## gap depends on where the weapon's cooldown happened to be. Checking once
## made this probe pass about one run in four — worse than no check, because
## the red looked like a game regression every time.
func _verify_breakable_hit() -> void:
	var hit: String = _damaged_prop()
	if not hit.is_empty():
		print("N64 breakable hit: prop hp %s with zero enemies" % hit)
		_wait = STEP_GAP_SEC
		_step += 1
		return
	_wait = 0.05
	if _probe_left <= 0.0:
		_fail("no breakable took weapon damage")
		_step += 1


## Step 3: smash every prop so NOTHING remains in view, then face up — the
## next shot must fly the facing direction.
func _clear_field_and_face_up() -> void:
	var smashed: int = 0
	for breakable: Breakable in _spawner.breakables:
		if breakable.alive():
			breakable.take_weapon_damage(99999.0)
			smashed += 1
	_player.global_position = Vector2.ZERO
	_snap_camera()
	_player.last_move_direction = Vector2.UP
	_probe_left = PROBE_TIMEOUT_SEC
	# Props keep STREAMING in as the camera settles, and a freshly arrived one
	# is a target — that is why this probe used to see the "forward" shot fly
	# downward at a prop nobody had cleared yet.
	_keep_field_clear = true
	_ignore_shots_left = STALE_SHOT_SEC
	print("N64 forward probe: %d props cleared, player centered facing UP" % smashed)


## Polls for a shot fired along the facing rather than judging the first one
## seen. Props STREAM in as the camera settles, and one that exists for a single
## frame before _keep_field_clear smashes it is a legitimate target — failing on
## that would be failing the probe's own premise, not the game. A timeout is the
## only real failure: it means no forward shot was ever fired.
func _probe_forward_shot() -> void:
	var projectile: Projectile = _live_projectile()
	if projectile != null:
		# The velocity is the heading. Position minus the player's is not: a shot
		# that has barely left is a near-zero vector pointing anywhere.
		var heading: Vector2 = projectile._velocity.normalized()
		if heading.dot(Vector2.UP) > 0.7:
			print("N64 forward shot: projectile heading %s matches facing UP" % str(heading))
			await _shot("n64_fire_forward")
			_wait = STEP_GAP_SEC
			_step += 1
			return
	_wait = 0.05
	if _probe_left <= 0.0:
		_fail("no shot was fired along the facing direction")
		_step += 1


## Step 6: a touch far from the old bottom-left pad must anchor and drive the
## stick from that exact point.
func _drive_joystick() -> void:
	_send_touch(0, TOUCH_POINT, true)
	_send_drag(0, DRAG_POINT)
	await get_tree().process_frame
	var expected: Vector2 = TouchJoystick.output_vector(
		TOUCH_POINT, DRAG_POINT, TouchJoystick.BASE_RADIUS
	)
	if (_joystick.output - expected).length() < 0.01 and _joystick.output != Vector2.ZERO:
		print("N64 joystick: anchored at %s, output %s" % [
			str(TOUCH_POINT), str(_joystick.output)
		])
	else:
		_fail("joystick output %s, expected %s" % [str(_joystick.output), str(expected)])
	await _shot("n64_joystick_floating")


## Step 7: a second finger on an interactive HUD button must be refused by
## the stick (button priority) and must not cancel the live drag.
func _verify_button_priority() -> void:
	var button_point: Vector2 = _first_button_point()
	if button_point == Vector2.INF:
		print("N64 button priority: no interactive button visible, skipped")
	else:
		var before: Vector2 = _joystick.output
		_send_touch(1, button_point, true)
		if not bool(_stage._hud.blocks_point(button_point)):
			_fail("blocks_point false on a visible button at " + str(button_point))
		if _joystick.output != before or _joystick._touch_index != 0:
			_fail("second finger on a button disturbed the stick")
		else:
			print("N64 button priority: second finger at %s left movement intact" % [
				str(button_point)
			])
		_send_touch(1, button_point, false)
	_send_touch(0, DRAG_POINT, false)
	if _joystick.output == Vector2.ZERO:
		print("N64 joystick release: output back to ZERO")
	else:
		_fail("joystick output stuck after release")


func _first_button_point() -> Vector2:
	var found: Array[Button] = []
	_collect_buttons(_stage._hud, found)
	for button: Button in found:
		if button.is_visible_in_tree() and not button.disabled:
			return button.get_global_rect().get_center()
	return Vector2.INF


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			found.append(child)
		_collect_buttons(child, found)


## parse_input_event buffers until the next frame; flushing makes each
## injected event observable immediately, so the assertions right after a
## press/release actually see its effect.
func _send_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _fail(reason: String) -> void:
	_failed = true
	print("N64 CHECK FAIL: " + reason)


func _shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://%s.png" % shot_name
	image.save_png(path)
	print("N64 shot: " + ProjectSettings.globalize_path(path))
