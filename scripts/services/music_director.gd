class_name MusicDirector
extends Node
## Background music service (ARCHITECTURE.md §3.6). Cross-fades between two
## AudioStreamPlayer voices assigned to the "Music" bus (§3.7).
##
## Callers pass track ids, never res:// paths — asset-forge renames/re-cuts
## files under asset/audio/bgm/ in parallel, and TRACKS is the single place
## that mapping lives. Today's filenames have spaces/capitals because that is
## exactly how the author delivered them; when asset-forge lands the
## snake_case rename this table is the only edit required.

const TRACKS: Dictionary = {
	"title": "res://asset/audio/bgm/joseonlike.mp3",
	"camp": "res://asset/audio/bgm/moonlit_sanctuary.mp3",
	"bamboo_forest": "res://asset/audio/bgm/bamboo_forest_spirits.mp3",
}

const MUSIC_BUS: String = "Music"
const CROSSFADE_DURATION_SEC: float = 1.5
const SILENCE_DB: float = -80.0

## Matches scripts/ui/settings.gd's VOLUME_SAVE_PREFIX ("settings_volume_") + the
## exact bus name "Music" it saves under, and its 1.0 default. Duplicated rather
## than shared because settings.gd is meta-ui's file, not mine to import from.
const VOLUME_SAVE_KEY: String = "settings_volume_Music"
const DEFAULT_VOLUME: float = 1.0

var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_index: int = 0
var _current_track_id: String = ""
var _track_streams: Dictionary = {}
var _fade_tween: Tween = null


func _ready() -> void:
	# The level-up choice pauses the tree; music must keep playing (and
	# in-flight cross-fades must keep ticking) while it is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = _make_player("PlayerA")
	_player_b = _make_player("PlayerB")
	_apply_saved_volume()


func play(track_id: String) -> void:
	if track_id == _current_track_id:
		return
	var stream: AudioStreamMP3 = _get_track_stream(track_id)
	if stream == null:
		return

	var outgoing: AudioStreamPlayer = null
	if not _current_track_id.is_empty():
		outgoing = _active_player()
	var incoming: AudioStreamPlayer = _inactive_player()
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.play()

	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", 0.0, CROSSFADE_DURATION_SEC)
	if outgoing != null:
		_fade_tween.tween_property(outgoing, "volume_db", SILENCE_DB, CROSSFADE_DURATION_SEC)
	_fade_tween.chain().tween_callback(_on_fade_in_finished.bind(outgoing))

	_active_index = 1 - _active_index
	_current_track_id = track_id


func stop() -> void:
	if _current_track_id.is_empty():
		return
	var outgoing: AudioStreamPlayer = _active_player()
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(outgoing, "volume_db", SILENCE_DB, CROSSFADE_DURATION_SEC)
	_fade_tween.finished.connect(outgoing.stop, CONNECT_ONE_SHOT)
	_current_track_id = ""


func _on_fade_in_finished(outgoing: AudioStreamPlayer) -> void:
	if outgoing != null:
		outgoing.stop()


func _active_player() -> AudioStreamPlayer:
	return _player_a if _active_index == 0 else _player_b


func _inactive_player() -> AudioStreamPlayer:
	return _player_b if _active_index == 0 else _player_a


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


func _make_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = MUSIC_BUS
	add_child(player)
	return player


## Loads (or returns the cached) loop-enabled duplicate for track_id. The
## duplicate exists because the shared imported resource carries loop=false
## (asset/*.mp3.import, not owned here) and must not be mutated in place —
## same precedent as CombatAudio.start_ambience()'s AudioStreamWAV duplicate.
func _get_track_stream(track_id: String) -> AudioStreamMP3:
	if _track_streams.has(track_id):
		return _track_streams[track_id]

	if not TRACKS.has(track_id):
		push_warning("MusicDirector: unknown track id \"%s\"" % track_id)
		return null

	var path: String = String(TRACKS[track_id])
	if not ResourceLoader.exists(path):
		push_warning("MusicDirector: missing music file %s" % path)
		return null

	var loaded: AudioStream = ResourceLoader.load(path)
	var mp3: AudioStreamMP3 = loaded as AudioStreamMP3
	if mp3 == null:
		push_warning("MusicDirector: %s did not load as AudioStreamMP3" % path)
		return null

	mp3 = mp3.duplicate() as AudioStreamMP3
	mp3.loop = true
	_track_streams[track_id] = mp3
	return mp3


func _apply_saved_volume() -> void:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0:
		return
	var linear_volume: float = float(SaveManager.get_value(VOLUME_SAVE_KEY, DEFAULT_VOLUME))
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(linear_volume, 0.0001)))
