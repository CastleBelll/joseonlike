extends Node
## Profile persistence. Stores meta progression only — never PII, and profile
## contents are never logged, only key names, paths, and schema versions.
##
## Frozen contract: ARCHITECTURE.md section 3.4.

const SAVE_PATH := "user://profile.save"
const TEMP_SUFFIX := ".tmp"
const SCHEMA_KEY := "schema"
const SCHEMA_VERSION := 1

## Writes are batched: a camp screen can set a dozen values in one frame and we
## only want one disk round-trip out of it.
const AUTOSAVE_DEBOUNCE_SEC := 2.0

## Override point for tests; production always uses SAVE_PATH.
var save_path: String = SAVE_PATH

var _profile: Dictionary = {SCHEMA_KEY: SCHEMA_VERSION}
var _dirty: bool = false

## Set when the file on disk was written by a newer build. We keep serving the
## in-memory defaults but refuse to write, so a downgrade cannot destroy a save
## whose fields this build does not understand.
var _read_only: bool = false

var _autosave_timer: Timer = null


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DEBOUNCE_SEC
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)


func _notification(what: int) -> void:
	# Flush on shutdown, otherwise a pending debounced write is lost.
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_EXIT_TREE:
		return
	if _dirty:
		save_profile()


func load_profile() -> Dictionary:
	_read_only = false

	if not FileAccess.file_exists(save_path):
		# First launch: a fresh profile is expected, not an error.
		return _reset_profile()

	var text: String = FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		push_error("SaveManager: %s is empty or unreadable (error %d); starting a fresh profile" % [save_path, FileAccess.get_open_error()])
		return _reset_profile()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: %s is corrupt at line %d; starting a fresh profile" % [save_path, json.get_error_line()])
		return _reset_profile()

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not a JSON object; starting a fresh profile" % save_path)
		return _reset_profile()

	var loaded: Dictionary = json.data
	var version: int = int(loaded.get(SCHEMA_KEY, 0))

	if version > SCHEMA_VERSION:
		push_error("SaveManager: %s has schema %d, newer than the supported %d; refusing to load or overwrite it" % [save_path, version, SCHEMA_VERSION])
		_read_only = true
		return _reset_profile()

	if version < SCHEMA_VERSION:
		loaded = _migrate(loaded, version)

	_profile = loaded
	_dirty = false
	return _profile.duplicate(true)


func save_profile() -> Error:
	if _read_only:
		push_error("SaveManager: refusing to overwrite the newer profile schema at %s" % save_path)
		return ERR_FILE_CANT_WRITE

	var temp_path: String = save_path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("SaveManager: cannot open %s for writing (error %d)" % [temp_path, open_error])
		return open_error

	file.store_string(JSON.stringify(_profile))
	file.close()

	# Write to a temp file and rename over the real one: a crash mid-write leaves
	# the previous profile intact instead of a truncated file.
	# ponytail: rename is atomic on POSIX; on Windows Godot deletes-then-renames,
	# so a crash inside that microsecond window still loses the old file. Good
	# enough for a local profile; revisit if purchases ever live here.
	var base_dir: String = save_path.get_base_dir()
	var dir := DirAccess.open(base_dir)
	if dir == null:
		var dir_error: Error = DirAccess.get_open_error()
		push_error("SaveManager: cannot open %s (error %d)" % [base_dir, dir_error])
		return dir_error

	var rename_error: Error = dir.rename(temp_path, save_path)
	if rename_error != OK:
		push_error("SaveManager: cannot replace %s (error %d)" % [save_path, rename_error])
		return rename_error

	_dirty = false
	return OK


func get_value(key: String, default_value: Variant) -> Variant:
	return _profile.get(key, default_value)


func set_value(key: String, value: Variant) -> void:
	if key == SCHEMA_KEY:
		push_error("SaveManager: \"%s\" is reserved and cannot be set" % SCHEMA_KEY)
		return

	_profile[key] = value
	_dirty = true

	if _autosave_timer == null:
		# Outside the scene tree (tests); the caller drives save_profile() itself.
		return
	_autosave_timer.start(AUTOSAVE_DEBOUNCE_SEC)


func _on_autosave_timeout() -> void:
	if not _dirty:
		return
	save_profile()


func _reset_profile() -> Dictionary:
	_profile = {SCHEMA_KEY: SCHEMA_VERSION}
	_dirty = false
	return _profile.duplicate(true)


## Upgrades an older profile to SCHEMA_VERSION. Add one branch per schema bump;
## every branch must be able to run on top of the previous one.
func _migrate(profile: Dictionary, from_version: int) -> Dictionary:
	var migrated: Dictionary = profile.duplicate(true)

	if from_version < 1:
		# Pre-versioning saves: keep their keys, stamp the version they now match.
		migrated[SCHEMA_KEY] = 1

	push_warning("SaveManager: migrated profile from schema %d to %d" % [from_version, SCHEMA_VERSION])
	return migrated
