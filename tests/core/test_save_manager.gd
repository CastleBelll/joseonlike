extends RefCounted
## SaveManager: round-trip through a throwaway path, atomic write hygiene, and
## explicit handling of corrupt or newer-than-supported profiles.

const SAVE_MANAGER_SCRIPT := preload("res://scripts/core/save_manager.gd")

const TEST_SAVE_PATH := "user://test_profile.save"
const TEST_GOLD := 120
const NEWER_SCHEMA_JSON := "{\"schema\": 999, \"gold\": 7}"
const CORRUPT_JSON := "{ \"gold\": "


func run() -> Array[String]:
	_cleanup()
	var failures: Array[String] = []
	failures.append_array(_test_round_trip())
	failures.append_array(_test_write_leaves_no_temp_file())
	failures.append_array(_test_reserved_schema_key_is_rejected())
	failures.append_array(_test_newer_schema_is_rejected_read_only())
	failures.append_array(_test_corrupt_profile_falls_back())
	failures.append_array(_test_debounced_autosave_defers_then_writes())
	_cleanup()
	return failures


func _test_round_trip() -> Array[String]:
	var failures: Array[String] = []

	var writer := _new_manager()
	writer.load_profile()
	writer.set_value("gold", TEST_GOLD)
	writer.set_value("unlocked_characters", ["taoist"])
	var save_result: Error = writer.save_profile()
	writer.free()

	if save_result != OK:
		failures.append("save_profile returned %d, expected OK" % save_result)

	var reader := _new_manager()
	var profile: Dictionary = reader.load_profile()

	if int(profile.get("schema", 0)) != SAVE_MANAGER_SCRIPT.SCHEMA_VERSION:
		failures.append("loaded profile schema is %s, expected %d" % [
			profile.get("schema", "missing"), SAVE_MANAGER_SCRIPT.SCHEMA_VERSION,
		])
	if int(reader.get_value("gold", 0)) != TEST_GOLD:
		failures.append("gold did not round-trip: got %s" % reader.get_value("gold", 0))

	var unlocked: Array = reader.get_value("unlocked_characters", [])
	if unlocked.size() != 1 or String(unlocked[0]) != "taoist":
		failures.append("unlocked_characters did not round-trip")
	if int(reader.get_value("absent_key", -1)) != -1:
		failures.append("get_value ignored the supplied default for an absent key")

	reader.free()
	return failures


func _test_write_leaves_no_temp_file() -> Array[String]:
	var failures: Array[String] = []

	var manager := _new_manager()
	manager.load_profile()
	manager.set_value("gold", TEST_GOLD)
	manager.save_profile()
	manager.free()

	var temp_path: String = TEST_SAVE_PATH + SAVE_MANAGER_SCRIPT.TEMP_SUFFIX
	if FileAccess.file_exists(temp_path):
		failures.append("the temp file %s survived a successful save" % temp_path)
	if not FileAccess.file_exists(TEST_SAVE_PATH):
		failures.append("no profile at %s after a successful save" % TEST_SAVE_PATH)

	return failures


func _test_reserved_schema_key_is_rejected() -> Array[String]:
	var failures: Array[String] = []

	var manager := _new_manager()
	manager.load_profile()
	_mute_expected_errors(true)
	manager.set_value(SAVE_MANAGER_SCRIPT.SCHEMA_KEY, 42)
	_mute_expected_errors(false)

	if int(manager.get_value(SAVE_MANAGER_SCRIPT.SCHEMA_KEY, 0)) != SAVE_MANAGER_SCRIPT.SCHEMA_VERSION:
		failures.append("set_value overwrote the reserved schema key")

	manager.free()
	return failures


func _test_newer_schema_is_rejected_read_only() -> Array[String]:
	var failures: Array[String] = []
	_write_raw(NEWER_SCHEMA_JSON)

	var manager := _new_manager()
	_mute_expected_errors(true)
	var profile: Dictionary = manager.load_profile()
	var write_result: Error = manager.save_profile()
	_mute_expected_errors(false)

	if int(profile.get("schema", 0)) != SAVE_MANAGER_SCRIPT.SCHEMA_VERSION:
		failures.append("a newer profile was adopted instead of rejected")
	if int(manager.get_value("gold", -1)) != -1:
		failures.append("fields from an unsupported schema leaked into the profile")
	if write_result == OK:
		failures.append("save_profile overwrote a newer profile instead of refusing")

	var on_disk: String = FileAccess.get_file_as_string(TEST_SAVE_PATH)
	if not on_disk.contains("999"):
		failures.append("the newer profile on disk was destroyed")

	manager.free()
	_cleanup()
	return failures


func _test_corrupt_profile_falls_back() -> Array[String]:
	var failures: Array[String] = []
	_write_raw(CORRUPT_JSON)

	var manager := _new_manager()
	_mute_expected_errors(true)
	var profile: Dictionary = manager.load_profile()
	_mute_expected_errors(false)

	if int(profile.get("schema", 0)) != SAVE_MANAGER_SCRIPT.SCHEMA_VERSION:
		failures.append("a corrupt profile did not fall back to a fresh one")

	# A corrupt file is recoverable: the next save must succeed.
	manager.set_value("gold", TEST_GOLD)
	var save_result: Error = manager.save_profile()
	if save_result != OK:
		failures.append("saving over a corrupt profile returned %d, expected OK" % save_result)

	manager.free()
	_cleanup()
	return failures


## The debounce is the one autoload behaviour the headless runner cannot observe:
## _ready() never fires there, so _autosave_timer stays null and set_value takes
## its early return. Timer.start() also refuses to run outside the scene tree, so
## the timer object itself is untestable here -- but its payload is not. This
## drives _on_autosave_timeout() directly, which is exactly what the timer calls.
func _test_debounced_autosave_defers_then_writes() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()

	var manager := _new_manager()
	manager.load_profile()
	manager.set_value("gold", TEST_GOLD)

	# Debounced: the setter must not touch the disk on its own.
	if FileAccess.file_exists(TEST_SAVE_PATH):
		failures.append("set_value wrote %s immediately instead of deferring" % TEST_SAVE_PATH)

	manager._on_autosave_timeout()
	if not FileAccess.file_exists(TEST_SAVE_PATH):
		failures.append("the autosave timeout did not write %s" % TEST_SAVE_PATH)

	var reader := _new_manager()
	reader.load_profile()
	if int(reader.get_value("gold", 0)) != TEST_GOLD:
		failures.append("the autosaved profile did not round-trip gold")
	reader.free()

	# Nothing dirty: a second timeout must not churn the disk.
	_cleanup()
	manager._on_autosave_timeout()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		failures.append("the autosave timeout rewrote a profile with no pending changes")

	manager.free()
	_cleanup()
	return failures


func _new_manager() -> Node:
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	manager.save_path = TEST_SAVE_PATH
	return manager


func _write_raw(contents: String) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("test_save_manager: cannot seed %s (error %d)" % [TEST_SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(contents)
	file.close()


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for path: String in [TEST_SAVE_PATH, TEST_SAVE_PATH + SAVE_MANAGER_SCRIPT.TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			dir.remove(path)


## Corrupt and newer-schema cases deliberately trip push_error; mute them so the
## runner output only carries real problems.
func _mute_expected_errors(muted: bool) -> void:
	Engine.print_error_messages = not muted
