extends Node
## N9-1a BGM runtime proof: the data contract says the files exist, but only a
## running engine can say whether they decode, loop, and land on the Music bus
## where the settings slider controls them. Also proves the no-restart rule,
## which is the whole reason callers name a track instead of a file.
## Run: godot --headless --path . res://tools/music_check.tscn

const TRACK_IDS: Array[String] = ["title", "camp", "bamboo_forest"]

var _failed: bool = false


func _ready() -> void:
	if MusicService.instance == null:
		_fail("MusicManager autoload is not running")
		_finish()
		return
	_check_each_track_plays()
	_check_same_track_does_not_restart()
	_check_stop_clears_everything()
	_finish()


func _check_each_track_plays() -> void:
	for track_id: String in TRACK_IDS:
		MusicService.instance.play(track_id)
		if MusicService.instance.current_track() != track_id:
			_fail("play('%s') did not become the current track" % track_id)
			continue
		var player: AudioStreamPlayer = _playing_player()
		if player == null:
			_fail("no player is playing after play('%s')" % track_id)
			continue
		if player.bus != SaveService.BUS_MUSIC:
			_fail("'%s' plays on bus '%s', not %s" % [
				track_id, player.bus, SaveService.BUS_MUSIC
			])
		# A track that does not loop falls silent partway through a run and
		# reads as a bug in the game, not in the audio.
		if not _is_looping(player.stream):
			_fail("'%s' is not set to loop" % track_id)
		var length: float = player.stream.get_length() if player.stream != null else 0.0
		print("MUSIC %s: playing on %s, loop ok, %.1fs" % [track_id, player.bus, length])


## Re-asking for the current track must not restart it — that is what keeps the
## music continuous across scene changes that share a track.
func _check_same_track_does_not_restart() -> void:
	MusicService.instance.play("title")
	var before: AudioStreamPlayer = _playing_player()
	if before == null:
		_fail("nothing playing before the restart probe")
		return
	var position_before: float = before.get_playback_position()
	MusicService.instance.play("title")
	var after: AudioStreamPlayer = _playing_player()
	if after != before:
		_fail("re-asking for the current track swapped players")
		return
	if after.get_playback_position() < position_before:
		_fail("re-asking for the current track restarted it")
		return
	print("MUSIC same-track replay: no restart")


func _check_stop_clears_everything() -> void:
	MusicService.instance.stop()
	if not MusicService.instance.current_track().is_empty():
		_fail("stop() left a current track behind")
	if _playing_player() != null:
		_fail("stop() left a player running")
	else:
		print("MUSIC stop: silent")


func _playing_player() -> AudioStreamPlayer:
	for child: Node in MusicService.instance.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			return player
	return null


func _is_looping(stream: AudioStream) -> bool:
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error("music_check: " + message)


func _finish() -> void:
	print("MUSIC CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)
