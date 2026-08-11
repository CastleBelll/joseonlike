extends RefCounted
## Keeps tests/ui/layout_audit.gd part of the suite. tests/run_tests.gd calls
## every suite's run() synchronously inside its own _initialize() and never
## reaches a real process frame in between -- but Control/Container layout
## resolution needs one (see layout_audit.gd's header for the proof). So
## this shells out to the exact same godot binary already running this test
## (OS.get_executable_path(), never a hardcoded "godot") as a fresh headless
## process, letting the audit get its own real frame, and turns a non-zero
## exit into a suite failure with the audit's own findings as the message.

func run() -> Array[String]:
	var godot_path: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(
		godot_path,
		["--headless", "--path", project_path, "--script", "res://tests/ui/layout_audit.gd"],
		output,
		true,
	)

	if exit_code == 0:
		return []

	var text: String = "\n".join(output)
	return ["layout_audit.gd exited %d:\n%s" % [exit_code, text]]
