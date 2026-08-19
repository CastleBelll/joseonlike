class_name MusicService
extends Node
## BGM autoload (N9-1a), registered as MusicManager. One looping track at a
## time, routed through the Music bus so the settings slider already controls
## it without this class knowing the setting exists.
##
## Callers name a track id from data/audio.json, never a file. Asking for the
## track already playing is a no-op, so walking 타이틀 → 본거지 → 타이틀 does
## not restart the music; asking for a different one cross-fades.
##
## A missing or unreadable audio file is never fatal: the game runs silent and
## says so once. Music must never be the reason a build fails to start.

const PATH := "res://data/audio.json"

## Fade floor in decibels. NOT SILENT_DB: that is -inf, and tweening a
## volume from -inf produces NaN on the first interpolation step, which Godot
## rejects with "Volume can't be set to NaN" once per frame of every fade.
const SILENT_DB := -60.0

## The one live autoload instance; null in node-free headless tests.
static var instance: MusicService

var _config: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
## Index of the player currently holding the foreground track.
var _active: int = 0
var _current_id: String = ""
var _fade: Tween
## Tracks whose file failed to load — warned once, then silently skipped.
var _missing: Dictionary = {}


func _init() -> void:
	instance = self


func _ready() -> void:
	# Music keeps playing while the tree is paused: the pause screen and every
	# level-up choice pause the tree, and silence on every popup would be worse
	# than no music at all.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = load_config()
	# Two players so a cross-fade can overlap; more would just be idle nodes.
	for i: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Track%d" % i
		player.bus = SaveService.BUS_MUSIC
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


static func load_config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary:
		push_error("music_player: cannot parse " + PATH)
		return {}
	return data


static func track(config: Dictionary, track_id: String) -> Dictionary:
	return (config.get("tracks", {}) as Dictionary).get(track_id, {})


## Plays `track_id`, cross-fading from whatever is playing. Re-asking for the
## current track is a no-op — that is what keeps the music continuous across
## scene changes that share a track.
func play(track_id: String) -> void:
	if track_id == _current_id:
		return
	var entry: Dictionary = track(_config, track_id)
	if entry.is_empty():
		push_warning("music_player: unknown track '%s'" % track_id)
		return
	var stream: AudioStream = _stream_for(track_id, String(entry.get("file", "")))
	if stream == null:
		# Nothing to play: stop what is there so the previous screen's music
		# does not linger under the new one.
		stop()
		return
	_current_id = track_id
	var target_db: float = linear_to_db(clampf(
		float(entry.get("volume", _default_volume())), 0.0, 1.0
	))
	var next: int = 1 - _active
	var incoming: AudioStreamPlayer = _players[next]
	var outgoing: AudioStreamPlayer = _players[_active]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_active = next

	var fade_sec: float = _fade_sec()
	if _fade != null:
		_fade.kill()
		_fade = null
	if fade_sec <= 0.0 or not is_inside_tree():
		incoming.volume_db = target_db
		outgoing.stop()
		return
	# Parallel so the two curves overlap instead of leaving a silent gap; the
	# outgoing player only stops once its own fade has finished.
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", target_db, fade_sec)
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", SILENT_DB, fade_sec)
		_fade.chain().tween_callback(outgoing.stop)


func stop() -> void:
	_current_id = ""
	if _fade != null:
		_fade.kill()
		_fade = null
	for player: AudioStreamPlayer in _players:
		player.stop()
		# Release the stream too, not just the playback: a stopped player that
		# still holds its stream keeps the whole decoded track resident, and
		# Godot reports it as a resource still in use at exit. play() reloads.
		player.stream = null


func current_track() -> String:
	return _current_id


## Shutdown release. Without it a harness that quits mid-track leaves the
## decoded stream referenced and Godot prints "resources still in use at exit"
## — an ERROR line in every runtime check, which is exactly the noise the
## check is supposed to be free of.
func _exit_tree() -> void:
	stop()


## Looping is set on the stream rather than in the .import sidecar because this
## project does not track generated sidecars (QA-2 policy) — a fresh clone would
## otherwise reimport without the loop flag and every track would play once and
## fall silent.
func _stream_for(track_id: String, file_path: String) -> AudioStream:
	if _missing.has(track_id):
		return null
	if file_path.is_empty() or not ResourceLoader.exists(file_path):
		_missing[track_id] = true
		push_warning("music_player: missing audio file for '%s' — running silent" % track_id)
		return null
	# CACHE_MODE_IGNORE on purpose, for two reasons: a cached stream outlives
	# stop() and Godot reports it as "resources still in use at exit" (an ERROR
	# line in every runtime check), and the loop flag below would be written
	# onto the shared cached resource rather than this playback's own copy.
	# Only the current track stays resident, which also matters on mobile —
	# the three tracks are ~17MB together.
	var stream: AudioStream = ResourceLoader.load(
		file_path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	if stream == null:
		_missing[track_id] = true
		push_warning("music_player: cannot load '%s' — running silent" % track_id)
		return null
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _fade_sec() -> float:
	return float((_config.get("_config", {}) as Dictionary).get("fade_sec", 0.0))


func _default_volume() -> float:
	return float((_config.get("_config", {}) as Dictionary).get("default_volume", 1.0))


## Data contract for validate_data: a fade that is not negative, volumes inside
## (0, 1], and every declared file actually present — a track pointing at a file
## that is not in the build is silence nobody would notice until release.
static func data_issues(config: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var settings: Dictionary = config.get("_config", {})
	if float(settings.get("fade_sec", -1.0)) < 0.0:
		issues.append("_config.fade_sec missing or negative")
	var default_volume: float = float(settings.get("default_volume", 0.0))
	if default_volume <= 0.0 or default_volume > 1.0:
		issues.append("_config.default_volume must be in (0, 1]")
	var tracks: Dictionary = config.get("tracks", {})
	if tracks.is_empty():
		issues.append("tracks is missing or empty")
	for track_id: String in tracks:
		var entry: Dictionary = tracks[track_id]
		var label: String = "tracks." + track_id
		var volume: float = float(entry.get("volume", 0.0))
		if volume <= 0.0 or volume > 1.0:
			issues.append(label + ".volume must be in (0, 1]")
		if String(entry.get("name_ko", "")).is_empty():
			issues.append(label + ".name_ko missing")
		var file_path: String = String(entry.get("file", ""))
		if not file_path.begins_with("res://"):
			issues.append(label + ".file must be a res:// path")
		elif not FileAccess.file_exists(file_path):
			issues.append(label + ".file does not exist: " + file_path)
	return issues
