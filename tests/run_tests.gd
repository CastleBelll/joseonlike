extends SceneTree
## Headless test runner: godot --headless --path . --script tests/run_tests.gd
##
## Discovers every res://tests/**/test_*.gd, calls its `run() -> Array[String]`,
## and exits nonzero when any file reports failures. Owned by core-engine;
## other worktrees only add test files.

const TESTS_ROOT := "res://tests"


## Runs in _initialize(), not _init(): SceneTree attaches the autoloads to the
## root between those two calls, and test files are allowed to use them.
func _initialize() -> void:
	var failures: Array[String] = []
	var file_count: int = 0

	for path in _discover(TESTS_ROOT):
		file_count += 1
		var script: GDScript = load(path)
		if script == null:
			failures.append("%s: failed to load" % path)
			continue

		var suite: Object = script.new()
		if not suite.has_method("run"):
			failures.append("%s: missing run() -> Array[String]" % path)
			continue

		for message in suite.run():
			failures.append("%s: %s" % [path, message])

	if failures.is_empty():
		print_rich("[color=green]PASS[/color] %d test file(s)" % file_count)
		quit(0)
		return

	for message in failures:
		print_rich("[color=red]FAIL[/color] %s" % message)
	print_rich("[color=red]%d failure(s) across %d file(s)[/color]" % [failures.size(), file_count])
	quit(1)


func _discover(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			found.append_array(_discover(full_path))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
