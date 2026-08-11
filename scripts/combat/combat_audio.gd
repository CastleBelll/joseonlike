class_name CombatAudio
extends Node
## Shared, limited-voice SFX pool for combat, plus the stage ambience bed.
##
## With up to 200 pooled enemies a wave can produce dozens of hits in one
## physics frame. Playing them all would clip instantly, so each distinct sound
## fires at most once per physics frame and voices are recycled round-robin.
##
## Reached through static helpers rather than node lookups: enemies call this on
## every hit, and a per-hit tree search would be the wrong cost.

const HIT_SFX: String = "res://asset/audio/sfx/combat_hit.wav"
const DEATH_SFX: String = "res://asset/audio/sfx/enemy_death.wav"
const BOSS_SPAWN_SFX: String = "res://asset/audio/sfx/boss_spawn.wav"
const PICKUP_SFX: String = "res://asset/audio/sfx/energy_sound.wav"
const AMBIENCE: String = "res://asset/audio/ambience/bamboo_forest_loop.wav"

## Every player names its bus (ARCHITECTURE.md §3.7). Left on the default these
## land on Master, which is what makes the settings screen's effects slider
## persist a value and change nothing audible.
const EFFECTS_BUS: String = "Effects"

const VOICE_COUNT: int = 8
const SFX_VOLUME_DB: float = -6.0
const AMBIENCE_VOLUME_DB: float = -14.0

static var _instance: CombatAudio = null

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _played_this_frame: Dictionary = {}
var _stream_cache: Dictionary = {}
var _ambience_player: AudioStreamPlayer = null


func _ready() -> void:
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		voice.volume_db = SFX_VOLUME_DB
		voice.bus = EFFECTS_BUS
		add_child(voice)
		_voices.append(voice)
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _physics_process(_delta: float) -> void:
	_played_this_frame.clear()


static func play_hit() -> void:
	_play(HIT_SFX)


static func play_enemy_death() -> void:
	_play(DEATH_SFX)


static func play_boss_spawn() -> void:
	_play(BOSS_SPAWN_SFX)


## A drop being taken. Shares the pool deliberately: the per-frame dedupe is
## what stops one magnet pull collecting a clump from firing a voice per orb.
static func play_pickup() -> void:
	_play(PICKUP_SFX)


static func _play(path: String) -> void:
	if _instance != null:
		_instance._play_once(path)


## Ambience is an exact-cycle loop, so it is flagged LOOP_FORWARD over the whole
## sample; the duplicate keeps that flag off the shared imported resource.
func start_ambience() -> void:
	var stream: AudioStream = _load_stream(AMBIENCE)
	if stream == null:
		return
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav != null:
		wav = wav.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		stream = wav
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "Ambience"
	_ambience_player.stream = stream
	_ambience_player.volume_db = AMBIENCE_VOLUME_DB
	_ambience_player.bus = EFFECTS_BUS
	add_child(_ambience_player)
	_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player != null:
		_ambience_player.stop()


func _play_once(path: String) -> void:
	if _played_this_frame.has(path):
		return
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return
	_played_this_frame[path] = true
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.play()


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("CombatAudio: missing audio file %s" % path)
		_stream_cache[path] = null
		return null
	var stream: AudioStream = ResourceLoader.load(path) as AudioStream
	_stream_cache[path] = stream
	return stream
