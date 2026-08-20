extends Node
## Camp navigation check (N9-61). Guards the failure this repo actually
## shipped: a screen that existed, with data and a harness of its own, and no
## way to reach it — the camp entry that routes to it was left uncommitted, so
## every test stayed green while the feature was unreachable.
##
## For every building the camp offers it asserts one of two things:
##   ready     -> its scene exists, instantiates, and BUILDS something,
##   not ready -> it answers 준비 중 and routes nowhere.
##
## The scenes are instantiated rather than navigated to: change_scene_to_file
## would replace this harness with the screen and end the run. Instantiating
## still executes _ready, which is where a missing locale key or a bad node
## path would blow up.
## Run: godot --headless --path . res://tools/nav_check.tscn

const SETTLE_FRAMES := 3

var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SaveService.instance != null:
		# A returning profile with gold, so screens that read progress have
		# something to draw. In memory only.
		var profile: Dictionary = SaveProfile.default_profile()
		profile["gold"] = 5000
		(profile["stats"] as Dictionary)["runs_played"] = 3
		SaveService.instance.profile = profile
		SaveService.instance._write_locked = true
		SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
	await _check_buildings()
	print("NAV CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


func _check_buildings() -> void:
	var buildings: Array[Dictionary] = Camp.buildings()
	if buildings.is_empty():
		_fail("the camp offers no buildings at all")
		return
	for building: Dictionary in buildings:
		var label: String = String(building.get("label", "?"))
		var notice: String = Camp.building_notice(building)
		var scene: String = Camp.building_scene(building)
		if not notice.is_empty():
			# A placeholder must not also route, or the notice is a lie.
			if not scene.is_empty():
				_fail("%s says '%s' but also routes to %s" % [label, notice, scene])
			else:
				print("NAV %s: 준비 중 (no route)" % label)
			continue
		if scene.is_empty():
			_fail("%s is ready but routes nowhere" % label)
			continue
		if not ResourceLoader.exists(scene):
			_fail("%s routes to a scene that is not in the build: %s" % [label, scene])
			continue
		await _open(label, scene)


## Instantiates a destination and lets it build. A screen that errors in
## _ready still returns a node, so the assertion is that it actually PRODUCED
## something — an empty screen is the shape a failed build leaves behind.
func _open(label: String, scene_path: String) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_fail("%s: %s did not load" % [label, scene_path])
		return
	var screen: Node = packed.instantiate()
	add_child(screen)
	for _i: int in range(SETTLE_FRAMES):
		await get_tree().process_frame
	var labels: int = _visible_labels(screen)
	if labels == 0:
		_fail("%s opened but drew no text at all" % label)
	else:
		print("NAV %s: %s built %d text nodes" % [label, scene_path, labels])
	screen.queue_free()
	await get_tree().process_frame


func _visible_labels(node: Node) -> int:
	var found: int = 0
	if node is Label and not (node as Label).text.is_empty():
		found += 1
	if node is Button and not (node as Button).text.is_empty():
		found += 1
	for child: Node in node.get_children():
		found += _visible_labels(child)
	return found


func _fail(message: String) -> void:
	_failed = true
	push_error("nav_check: " + message)
