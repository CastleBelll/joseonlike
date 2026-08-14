extends SceneTree
## Headless unit test runner skeleton.
## Contract (see docs/CI.md): godot --headless --path . --script tests/run_tests.gd
## Discovers tests/unit/*.gd; every zero-arg method named test_* must return true.
## Prints a final "PASS ..." line and exits 0, or "FAIL ..." and exits 1.

const UNIT_DIR := "res://tests/unit"


func _init() -> void:
	var total: int = 0
	var failed: int = 0
	var dir: DirAccess = DirAccess.open(UNIT_DIR)
	if dir == null:
		push_error("run_tests: cannot open " + UNIT_DIR)
		quit(1)
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var script: GDScript = load(UNIT_DIR + "/" + file_name)
		var case: RefCounted = script.new()
		for method: Dictionary in case.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var passed: bool = case.call(method_name) == true
			if not passed:
				failed += 1
				push_error("FAIL %s::%s" % [file_name, method_name])
	if failed > 0:
		print("FAIL %d/%d tests failed" % [failed, total])
		quit(1)
		return
	print("PASS %d/%d tests" % [total - failed, total])
	quit(0)
