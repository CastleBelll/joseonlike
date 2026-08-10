extends SceneTree
## Headless test runner: godot --headless --path . --script tests/run_tests.gd
##
## Discovers every res://tests/**/test_*.gd, calls its `run() -> Array[String]`,
## and exits nonzero when any file reports failures or cannot be run at all.
## Owned by core-engine; other worktrees only add test files.
##
## A suite that fails to compile, cannot be instantiated, or has no run() counts
## as an ERROR, never a skip. Hiding a broken suite behind a green summary is
## worse than the failure it hides. Note that `load()` returns a non-null but
## invalid GDScript for a file with a parse error, so the null check alone is
## not enough — can_instantiate() is what actually catches it.
##
## PRECONDITION — bare `class_name` references in test files:
## They do work here, but only when res://.godot/global_script_class_cache.cfg
## exists. That cache is written by an import pass and is gitignored, so a fresh
## checkout (CI included) must run
##     godot --headless --path . --import
## once before this runner. Without it, every suite that names a global class
## fails to compile with "Identifier not found", which looks like a broken test
## rather than a missing cache. The runner warns up front when it is absent.

const TESTS_ROOT := "res://tests"
const GLOBAL_CLASS_CACHE := "res://.godot/global_script_class_cache.cfg"
const IMPORT_HINT := "run `godot --headless --path . --import` once to generate it"

const EXIT_OK := 0
const EXIT_FAILURE := 1

## Cleared once _initialize() reaches its own quit(). See _process().
var _finished: bool = false


## Runs in _initialize(), not _init(): SceneTree attaches the autoloads to the
## root between those two calls, and test files are allowed to use them.
func _initialize() -> void:
	if not FileAccess.file_exists(GLOBAL_CLASS_CACHE):
		push_warning("run_tests: %s is missing, so suites naming a global class will not compile; %s" % [
			GLOBAL_CLASS_CACHE, IMPORT_HINT,
		])

	var errors: Array[String] = []
	var failures: Array[String] = []
	var passed: int = 0
	var failed: int = 0

	for path: String in _discover(TESTS_ROOT):
		var suite: Object = _instantiate(path, errors)
		if suite == null:
			continue

		var result: Variant = suite.run()
		if typeof(result) != TYPE_ARRAY:
			errors.append("%s: run() returned %s, expected Array[String]" % [
				path, type_string(typeof(result)),
			])
			continue

		var messages: Array = result
		if messages.is_empty():
			passed += 1
			continue

		failed += 1
		for message: Variant in messages:
			failures.append("%s: %s" % [path, message])

	_report(passed, failed, errors, failures)


## An aborted GDScript call unwinds the whole stack, so a suite whose run() hits
## a runtime error kills _initialize() before it can quit — the process would
## otherwise idle forever and CI would hang instead of failing.
func _process(_delta: float) -> bool:
	if _finished:
		return true

	push_error("run_tests: a suite aborted before the run finished; see the errors above")
	print_rich("[color=red]ERROR[/color] run_tests: aborted mid-run, no summary produced")
	_quit_with(EXIT_FAILURE)
	return true


## Returns the suite object, or null after recording why the file is unusable.
func _instantiate(path: String, errors: Array[String]) -> Object:
	var script: GDScript = load(path)
	if script == null:
		errors.append("%s: failed to load" % path)
		return null

	if not script.can_instantiate():
		errors.append("%s: did not compile (parse error, or a global class_name with no class cache; %s)" % [
			path, IMPORT_HINT,
		])
		return null

	var suite: Object = script.new()
	if suite == null:
		errors.append("%s: could not be instantiated" % path)
		return null

	if not suite.has_method("run"):
		errors.append("%s: missing run() -> Array[String]" % path)
		return null

	return suite


func _report(passed: int, failed: int, errors: Array[String], failures: Array[String]) -> void:
	var errored: int = errors.size()
	var total: int = passed + failed + errored

	if failed == 0 and errored == 0:
		print_rich("[color=green]PASS[/color] %d file(s): %d passed, 0 failed, 0 errored" % [total, passed])
		_quit_with(EXIT_OK)
		return

	for message: String in errors:
		print_rich("[color=red]ERROR[/color] %s" % message)
	for message: String in failures:
		print_rich("[color=red]FAIL[/color] %s" % message)

	print_rich("[color=red]%d file(s): %d passed, %d failed, %d errored — %d assertion failure(s)[/color]" % [
		total, passed, failed, errored, failures.size(),
	])
	_quit_with(EXIT_FAILURE)


func _quit_with(exit_code: int) -> void:
	_finished = true
	quit(exit_code)


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
