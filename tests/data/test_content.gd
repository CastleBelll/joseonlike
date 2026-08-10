extends RefCounted
## Data-content checks for the standard headless sweep (tests/run_tests.gd).
## Reuses tools/validate_data.gd's static validate_all() so the CI sweep and the
## standalone `godot --headless --script tools/validate_data.gd` invocation agree
## on what counts as valid content.

func run() -> Array[String]:
	return preload("res://tools/validate_data.gd").validate_all()
