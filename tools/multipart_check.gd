extends Node
## N10-3a probe: is 삼두구미 actually untouchable until it comes apart?
##
## The rule is invisible from outside — a body that ignores damage looks exactly
## like a broken hitbox — so this drives it directly: hit it once and read where
## the damage went, break the parts in order, then confirm the body finally
## takes a hit.
##
## Run: godot --headless --path . res://tools/multipart_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const MONSTER_ID := "samdugumi"
const SETTLE_SEC := 0.8

var _stage: Stage
var _enemy: Enemy
var _failures: PackedStringArray = []
var _breaks: PackedStringArray = []
var _wait: float = SETTLE_SEC
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("multipart_check: " + message)


func _process(delta: float) -> void:
	_wait -= delta
	if _done or _wait > 0.0:
		return
	_done = true
	_run()


func _run() -> void:
	var spawner: Spawner = _stage.get("_spawner")
	_enemy = spawner.call("_spawn_one", MONSTER_ID)
	if _enemy == null:
		_fail("the spawner would not place one")
		_finish()
		return
	_enemy.part_broken.connect(
		func(_e: Enemy, part_name: String, broken: int, total: int) -> void:
			_breaks.append("%s (%d/%d)" % [part_name, broken, total])
	)
	var body_hp: float = _enemy.hp
	var parts: int = _enemy.part_hp.size()
	if parts < 2:
		_fail("it arrived with %d parts" % parts)
		_finish()
		return

	# One hit while armoured: the body must not feel it, the part must.
	var first_before: float = _enemy.part_hp[0]
	_enemy.take_damage(25.0)
	if not is_equal_approx(_enemy.hp, body_hp):
		_fail("the body took damage while a part was still standing")
	if _enemy.part_hp[0] >= first_before:
		_fail("the part did not take the hit either")
	print("MULTIPART armoured: body %.0f untouched, first part %.0f -> %.0f" % [
		_enemy.hp, first_before, _enemy.part_hp[0]
	])

	# Break them in order, watching the speed and the bite fall as declared.
	var speed_before: float = _enemy.get("_speed")
	var damage_before: float = _enemy.get("_damage")
	for index: int in range(parts):
		var guard: int = 0
		while _enemy.part_hp[index] > 0.0 and guard < 200:
			_enemy.take_damage(20.0)
			guard += 1
	if _breaks.size() != parts:
		_fail("broke %d parts but heard %d" % [parts, _breaks.size()])
	print("MULTIPART broke: " + ", ".join(_breaks))
	print("MULTIPART cost: speed %.0f -> %.0f, bite %.0f -> %.0f" % [
		speed_before, _enemy.get("_speed"), damage_before, _enemy.get("_damage")
	])
	if _enemy.get("_speed") >= speed_before:
		_fail("breaking its tails cost it no speed")
	if _enemy.get("_damage") >= damage_before:
		_fail("breaking its heads cost it no bite")
	if not is_equal_approx(_enemy.hp, body_hp):
		_fail("the body lost health before the last part fell")

	# Now the body is the target.
	_enemy.take_damage(30.0)
	if _enemy.hp >= body_hp:
		_fail("the body still ignores damage with every part down")
	print("MULTIPART exposed: body %.0f -> %.0f" % [body_hp, _enemy.hp])
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("MULTIPART CHECK PASS: armoured, taken apart, then killable")
	else:
		print("MULTIPART CHECK FAIL: " + ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
