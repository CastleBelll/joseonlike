extends Node
## N10-1a evidence harness: boots the real stage and proves the 그슨대 rule at
## runtime, not just in the pure helpers — that a shadow standing in the dark
## absorbs a real weapon hit and swells, that no weapon will even target it
## there, and that the same shadow inside a real field light takes damage,
## shrinks and dies. Also reports how far a player has to walk to find a light.
## Run (headless is enough): godot --headless --path . res://tools/shadow_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const SHADOW_ID := "geuseundae"
## Beside the player, not across the map: an enemy parked far off-screen is
## despawned by the spawner, which would silently void the whole probe. The
## exact spot is searched for rather than fixed, because the field seed is
## fresh every process and a campfire may well be sitting right there.
const PROBE_RADII: Array[float] = [70.0, 140.0, 210.0, 280.0]
const PROBE_ANGLES := 8
const SHOT_CUE := "user://shadow_cue.png"
const SHOT_DARK := "user://shadow_dark.png"
const SHOT_LIT := "user://shadow_lit.png"
const SETTLE_FRAMES := 4
const GROW_FRAMES := 60
const TEST_DAMAGE := 25.0

var _stage: Stage
var _player: Player
var _spawner: Spawner
var _field: StageField
var _shadow: Enemy
var _step: int = 0
var _hp_in_dark: float = 0.0
var _scale_before: float = 0.0
var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")
	_spawner = _stage.get_node("World/Spawner")
	_field = _stage.get_node("World/StageField")
	# No waves: the only enemy on the field is the one this harness spawns.
	_spawner._pending_waves.clear()
	_spawner._running_waves.clear()


func _physics_process(_delta: float) -> void:
	_step += 1
	match _step:
		SETTLE_FRAMES:
			_report_lights()
			_shadow = _spawner._spawn_one(SHADOW_ID)
			if _shadow == null:
				_fail("spawner refused to spawn " + SHADOW_ID)
				return
			var dark: Vector2 = _find_dark_spot()
			if dark == Vector2.INF:
				_fail("no unlit spot near the player — cannot probe the dark rule")
				return
			_shadow.global_position = dark
		SETTLE_FRAMES + 2:
			_check_dark()
		# The cue label lives 0.6s; late enough for the first render to settle,
		# early enough that the label has not faded out.
		SETTLE_FRAMES + 14:
			_capture(SHOT_CUE)
		SETTLE_FRAMES + 2 + GROW_FRAMES:
			_capture(SHOT_DARK)
			_check_growth_then_move_into_light()
		SETTLE_FRAMES + 4 + GROW_FRAMES:
			_check_lit()
		SETTLE_FRAMES + 30 + GROW_FRAMES:
			# Late enough for the smoothed camera to catch up with the teleport,
			# otherwise the shot is of empty ground.
			_capture(SHOT_LIT)
		SETTLE_FRAMES + 32 + GROW_FRAMES:
			_finish()


## How reachable is a light? A shadow that swells for a full minute before the
## player can find a lantern is a different feature than the one intended.
func _report_lights() -> void:
	var lights: Array[Dictionary] = _field.lights
	print("SHADOW lights on the origin field: %d" % lights.size())
	if lights.is_empty():
		_fail("the origin field generated no light at all")
		return
	var nearest: float = INF
	for light: Dictionary in lights:
		nearest = minf(nearest, Vector2.ZERO.distance_to(light["position"]))
	print("SHADOW nearest light from spawn: %.0f px" % nearest)


## Nearest unlit point around the player, inside despawn range.
## Vector2.INF when the player is standing in a very well-lit clearing.
func _find_dark_spot() -> Vector2:
	for radius: float in PROBE_RADII:
		for step: int in range(PROBE_ANGLES):
			var candidate: Vector2 = _player.global_position + Vector2.RIGHT.rotated(
				TAU * float(step) / float(PROBE_ANGLES)
			) * radius
			if not CombatMath.is_lit(candidate, _field.lights):
				return candidate
	return Vector2.INF


func _check_dark() -> void:
	if not _shadow.absorbs_damage():
		_fail("shadow in the dark reports itself damageable")
	if _spawner.active_enemies().has(_shadow):
		_fail("shadow in the dark is still offered to weapons as a target")
	_hp_in_dark = _shadow.hp
	_scale_before = _shadow.get_node("Visual").scale.y
	_shadow.take_damage(TEST_DAMAGE, Vector2.RIGHT)
	if not is_equal_approx(_shadow.hp, _hp_in_dark):
		_fail("shadow lost hp in the dark: %.1f -> %.1f" % [_hp_in_dark, _shadow.hp])
	else:
		print("SHADOW dark: absorbed %.0f damage, hp still %.1f" % [TEST_DAMAGE, _shadow.hp])


func _check_growth_then_move_into_light() -> void:
	var grown: float = _shadow.get_node("Visual").scale.y
	if grown <= _scale_before:
		_fail("shadow did not grow in the dark: %.3f -> %.3f" % [_scale_before, grown])
	else:
		print("SHADOW dark: grew %.3f -> %.3f over %d frames" % [
			_scale_before, grown, GROW_FRAMES
		])
	_scale_before = grown
	# Walk the pair into a real field light — the player has to bring it there,
	# so the player moves too and the shadow stays inside despawn range.
	var lit_point: Vector2 = _field.lights[0]["position"]
	_player.global_position = lit_point
	_shadow.global_position = lit_point


func _check_lit() -> void:
	if _shadow.absorbs_damage():
		_fail("shadow standing on a light still absorbs damage")
	if not _spawner.active_enemies().has(_shadow):
		_fail("shadow standing on a light is still hidden from weapons")
	var before: float = _shadow.hp
	_shadow.take_damage(TEST_DAMAGE, Vector2.RIGHT)
	if _shadow.hp >= before:
		_fail("shadow in the light took no damage: hp %.1f" % _shadow.hp)
	else:
		print("SHADOW lit: took damage, hp %.1f -> %.1f" % [before, _shadow.hp])
	var shrunk: float = _shadow.get_node("Visual").scale.y
	if shrunk >= _scale_before:
		_fail("shadow did not shrink in the light: %.3f -> %.3f" % [_scale_before, shrunk])
	else:
		print("SHADOW lit: shrank %.3f -> %.3f" % [_scale_before, shrunk])


func _finish() -> void:
	# It must actually be killable where it is vulnerable.
	_shadow.take_damage(_shadow.hp + 1.0, Vector2.RIGHT)
	if not CombatMath.is_dead(_shadow.hp):
		_fail("shadow survived a lethal hit inside a light")
	else:
		print("SHADOW lit: killed by a lethal hit")
	print("SHADOW CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


## Rendered runs only — the tint rule (dark = untouchable, pale = hittable)
## is the player's entire read on this monster, so it gets an eye check.
func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("SHADOW shot: " + ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error("shadow_check: " + message)
