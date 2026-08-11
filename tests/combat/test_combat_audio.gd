extends RefCounted
## Combat audio routing.
##
## Two failures this pins have both already shipped once. A sound with no caller
## is silent and looks exactly like a wiring bug, and a player left on the
## default bus lands on Master — which is what made the settings screen's
## effects slider persist a value and change nothing audible (§3.7).
##
## What is NOT checked here, and why: nothing that needs a sound to actually
## play. run_tests.gd drives suites from SceneTree._initialize(), where the root
## window is not yet inside the tree — so _ready never fires for a node added
## there and AudioStreamPlayer.play() refuses outright. The live half (ambience
## on the right bus, pickups firing on real collects, voice recycling) is
## measured by tests/combat/soak_harness.gd in a real tree instead.

const CombatAudioScript = preload("res://scripts/combat/combat_audio.gd")
const StageScript = preload("res://scripts/combat/stage.gd")
const MusicDirectorScript = preload("res://scripts/services/music_director.gd")

const EXPECTED_BUSES: Array[String] = ["Master", "Music", "Effects"]


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_every_sound_exists())
	failures.append_array(_test_buses_exist())
	failures.append_array(_test_stage_track_resolves())
	failures.append_array(_test_voices_are_on_effects())
	return failures


func _test_every_sound_exists() -> Array[String]:
	var failures: Array[String] = []
	var sounds: Dictionary = {
		"hit": CombatAudioScript.HIT_SFX,
		"death": CombatAudioScript.DEATH_SFX,
		"boss_spawn": CombatAudioScript.BOSS_SPAWN_SFX,
		"pickup": CombatAudioScript.PICKUP_SFX,
		"ambience": CombatAudioScript.AMBIENCE,
	}
	for label: Variant in sounds.keys():
		if not ResourceLoader.exists(String(sounds[label])):
			failures.append("%s sound missing: %s" % [label, sounds[label]])
	return failures


func _test_buses_exist() -> Array[String]:
	var failures: Array[String] = []
	for bus_name: String in EXPECTED_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			failures.append("bus %s is not in the layout, so nothing can name it" % bus_name)
	return failures


## Stage passes a track id, so the id must be one MusicDirector actually knows
## and the file behind it must be on disk. A typo here is silence, not an error.
func _test_stage_track_resolves() -> Array[String]:
	var failures: Array[String] = []
	var tracks: Dictionary = MusicDirectorScript.TRACKS
	if not tracks.has(StageScript.STAGE_TRACK):
		failures.append("MusicDirector has no track id \"%s\"" % StageScript.STAGE_TRACK)
		return failures
	var path: String = String(tracks[StageScript.STAGE_TRACK])
	if not ResourceLoader.exists(path):
		failures.append("track \"%s\" points at missing file %s" % [StageScript.STAGE_TRACK, path])
	return failures


## The pool is built in _ready, which the engine will not dispatch here (see the
## header), so it is notified explicitly. No tree, no playback — only the bus
## each voice was born naming, which is the property that regressed.
func _test_voices_are_on_effects() -> Array[String]:
	var failures: Array[String] = []
	var audio: Node = CombatAudioScript.new()
	audio.notification(Node.NOTIFICATION_READY)

	var voices: Array = audio.get(&"_voices")
	if voices.size() != CombatAudioScript.VOICE_COUNT:
		failures.append("pool built %d voices, expected %d" % [
			voices.size(), CombatAudioScript.VOICE_COUNT,
		])
	for voice: AudioStreamPlayer in voices:
		if voice.bus != CombatAudioScript.EFFECTS_BUS:
			failures.append("%s is on bus \"%s\", not %s" % [
				voice.name, voice.bus, CombatAudioScript.EFFECTS_BUS,
			])

	audio.free()
	return failures
