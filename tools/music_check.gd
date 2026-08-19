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
	_check_effects()
	_finish()


## N9-52: the effects have a data contract the unit suite checks, but only a
## running engine can say whether they decode, reach the Effects bus, and
## honour the throttle that keeps a surge from stacking a dozen copies of the
## same waveform.
func _check_effects() -> void:
	if SfxService.instance == null:
		_fail("SfxManager autoload is not running")
		return
	var config: Dictionary = MusicService.load_config()
	for sound_id: String in (config.get("sfx", {}) as Dictionary):
		SfxService.instance.stop_all()
		SfxService.instance.play(sound_id)
		var voice: AudioStreamPlayer = _playing_voice()
		if voice == null:
			_fail("no voice is playing after play('%s')" % sound_id)
			continue
		if voice.bus != SaveService.BUS_EFFECTS:
			_fail("'%s' plays on bus '%s', not %s" % [
				sound_id, voice.bus, SaveService.BUS_EFFECTS
			])
		# A looping effect would never stop; every one of these is a one-shot.
		if _is_looping(voice.stream):
			_fail("effect '%s' is set to loop" % sound_id)
		print("SFX %s: playing on %s, %.3fs" % [
			sound_id, voice.bus, voice.stream.get_length() if voice.stream != null else 0.0
		])
	_check_throttle()
	SfxService.instance.stop_all()


## Two plays inside the throttle window must produce one sound, not two.
func _check_throttle() -> void:
	SfxService.instance.stop_all()
	SfxService.instance.play("hit")
	SfxService.instance.play("hit")
	if _playing_voices() != 1:
		_fail("the throttle let %d voices through for one repeated hit" % _playing_voices())
	else:
		print("SFX throttle: repeated hit collapsed to one voice")


func _playing_voice() -> AudioStreamPlayer:
	for child: Node in SfxService.instance.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			return player
	return null


func _playing_voices() -> int:
	var count: int = 0
	for child: Node in SfxService.instance.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing:
			count += 1
	return count


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
