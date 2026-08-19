class_name SfxService
extends Node
## Sound-effect autoload (N9-52), registered as SfxManager. Routed through the
## Effects bus, so the settings slider that already exists controls it without
## this class knowing the setting exists — the same arrangement as MusicService.
##
## Callers name an effect id from data/audio.json, never a file.
##
## Two things this has that the music player does not:
##
## - A THROTTLE per id. A hit sound fires several times a second at a surge;
##   letting every one through stacks a dozen copies of the same waveform,
##   which is both louder than intended and mushier than one clean hit. The
##   interval lives in data because the right value differs per sound.
## - A POOL with stealing. When every voice is busy the oldest is taken rather
##   than dropping the new sound: the most recent event is the one the player
##   is looking at.
##
## A missing file is never fatal — the game runs silent and says so once.

## Simultaneous voices. Enough for a hit, a crit, a death, a pickup and a
## level-up to overlap; past that the mix is mud whatever the count.
const VOICES := 8

## The one live autoload instance; null in node-free headless tests.
static var instance: SfxService

var _config: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
## Round-robin cursor, so a stolen voice is always the least recently started.
var _next: int = 0
var _streams: Dictionary = {}
## Effect ids whose file failed to load — warned once, then silently skipped.
var _missing: Dictionary = {}
## Effect id -> engine time (seconds) of its last play, for the throttle.
var _last_played: Dictionary = {}


func _init() -> void:
	instance = self


func _ready() -> void:
	# Effects keep playing while the tree is paused: the level-up sound fires
	# on the frame the card screen opens, which pauses the tree, and it would
	# never be heard otherwise.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# One config file, one parser: a second copy of the JSON loading would be
	# a second place for the path to go stale.
	_config = MusicService.load_config()
	for i: int in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = SaveService.BUS_EFFECTS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


static func sfx(config: Dictionary, sound_id: String) -> Dictionary:
	return (config.get("sfx", {}) as Dictionary).get(sound_id, {})


## Plays `sound_id` unless its throttle window is still open. Unknown ids warn
## once rather than every frame — a mis-wired call site would otherwise bury
## the log it needs to be found in.
func play(sound_id: String) -> void:
	if _missing.has(sound_id):
		return
	var entry: Dictionary = sfx(_config, sound_id)
	if entry.is_empty():
		_missing[sound_id] = true
		push_warning("sfx_player: unknown effect '%s'" % sound_id)
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var interval: float = float(entry.get("min_interval_sec", 0.0))
	if now - float(_last_played.get(sound_id, -INF)) < interval:
		return
	var stream: AudioStream = _stream_for(sound_id, String(entry.get("file", "")))
	if stream == null:
		return
	_last_played[sound_id] = now
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = linear_to_db(clampf(float(entry.get("volume", 1.0)), 0.0001, 1.0))
	player.play()


func stop_all() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()


## Unlike music, effects are tiny and replayed constantly, so each stream is
## loaded once and kept. Reloading per play would hitch the frame that a crit
## lands on, which is the worst possible frame to hitch.
func _stream_for(sound_id: String, file_path: String) -> AudioStream:
	if _streams.has(sound_id):
		return _streams[sound_id]
	if file_path.is_empty() or not ResourceLoader.exists(file_path):
		_missing[sound_id] = true
		push_warning("sfx_player: missing file for '%s' — running silent" % sound_id)
		return null
	var stream: AudioStream = load(file_path)
	if stream == null:
		_missing[sound_id] = true
		push_warning("sfx_player: cannot load '%s' — running silent" % sound_id)
		return null
	if stream is AudioStreamWAV:
		# One-shots: a looping effect would never stop, and generated .import
		# sidecars are untracked in this repo (QA-2), so a fresh clone would
		# reimport with whatever the defaults happen to be.
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_streams[sound_id] = stream
	return stream


## Shutdown release, for the same reason MusicService has one: a harness that
## quits mid-sound otherwise leaves the stream referenced and Godot prints
## "resources still in use at exit" — an ERROR line in every runtime check.
func _exit_tree() -> void:
	stop_all()
	for player: AudioStreamPlayer in _players:
		player.stream = null
	_streams.clear()


## Data contract for validate_data: every declared effect needs a real file, a
## usable volume, and a throttle that is not negative. An effect pointing at a
## file that is not in the build is silence nobody notices until release.
static func data_issues(config: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var sounds: Dictionary = config.get("sfx", {})
	if sounds.is_empty():
		issues.append("sfx is missing or empty")
	for sound_id: String in sounds:
		var entry: Dictionary = sounds[sound_id]
		var label: String = "sfx." + sound_id
		var volume: float = float(entry.get("volume", 0.0))
		if volume <= 0.0 or volume > 1.0:
			issues.append(label + ".volume must be in (0, 1]")
		if float(entry.get("min_interval_sec", -1.0)) < 0.0:
			issues.append(label + ".min_interval_sec missing or negative")
		var file_path: String = String(entry.get("file", ""))
		if not file_path.begins_with("res://"):
			issues.append(label + ".file must be a res:// path")
		elif not FileAccess.file_exists(file_path):
			issues.append(label + ".file does not exist: " + file_path)
	return issues
