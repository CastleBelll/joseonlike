class_name EffectPool
extends Node2D
## Shared, fixed-size player for the four-frame effect sets.
##
## Same discipline as CombatAudio and EnemyPool, for the same reason: at 200
## pooled enemies a wave lands dozens of hits a second, and instancing a node
## per hit is where the frame rate goes. Sprites are allocated once and
## recycled; when every slot is busy a new request is dropped rather than
## allowed to allocate.
##
## Frame order is fixed by asset/SECOND_ASSET_BATCH_REPORT.md: 0 anticipation,
## 1 expansion, 2 peak, 3 dissipation, played once and stopped. Timing is the
## caller's choice, per the same handoff.

const FRAME_PATH: String = "res://asset/effect/%s/%d.png"
## Death sequences live outside asset/effect but play by the same rules.
const MONSTER_DEATH_PATH: String = "res://asset/monster/%s/death/%d.png"
const CHARACTER_DEATH_PATH: String = "res://asset/character/%s/Death/%d.png"
const FRAME_COUNT: int = 4

## Effect ids shipped in the second asset batch.
const HIT: StringName = &"impact_hit"
const SLASH: StringName = &"slash"
const LEVEL_UP: StringName = &"level_up"
const EVOLUTION: StringName = &"evolution_flourish"

## Impacts are brief so they do not smear over a busy background; the two
## progression cues linger long enough to be noticed.
const IMPACT_FRAME_SEC: float = 0.05
const CUE_FRAME_SEC: float = 0.09
## A death has to be legible mid-fight, then leave a corpse for a beat.
const DEATH_FRAME_SEC: float = 0.12
const DEATH_REST_SEC: float = 0.8

## Deaths share these slots with impacts and last far longer, so the ceiling
## is higher than it was when only impacts used the pool.
const MAX_CONCURRENT_EFFECTS: int = 96
const EFFECT_Z_INDEX: int = 50

static var _instance: EffectPool = null

var _idle: Array[Sprite2D] = []
var _active: Array[Dictionary] = []
var _frames: Dictionary = {}


func _ready() -> void:
	for index in MAX_CONCURRENT_EFFECTS:
		var sprite := Sprite2D.new()
		sprite.name = "Effect%d" % index
		sprite.visible = false
		sprite.z_index = EFFECT_Z_INDEX
		sprite.z_as_relative = false
		add_child(sprite)
		_idle.append(sprite)
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


static func play(effect_id: StringName, world_position: Vector2, rotation_rad: float = 0.0) -> void:
	_play(effect_id, world_position, rotation_rad, IMPACT_FRAME_SEC)


## Progression cues run slower than impacts: they are the moments a player is
## most likely to miss.
static func play_cue(effect_id: StringName, world_position: Vector2) -> void:
	_play(effect_id, world_position, 0.0, CUE_FRAME_SEC)


static func _play(effect_id: StringName, world_position: Vector2, rotation_rad: float, frame_sec: float) -> void:
	if _instance != null:
		_instance._spawn(effect_id, world_position, rotation_rad, frame_sec, 0.0, FRAME_PATH)


## Death sequences play once and hold their resting frame; they never loop,
## because frame 3 is the corpse rather than a cycle position.
static func play_monster_death(monster_id: String, world_position: Vector2) -> void:
	if _instance != null:
		_instance._spawn(StringName(monster_id), world_position, 0.0, DEATH_FRAME_SEC, DEATH_REST_SEC, MONSTER_DEATH_PATH)


static func play_character_death(character_folder: String, world_position: Vector2) -> void:
	if _instance != null:
		_instance._spawn(StringName(character_folder), world_position, 0.0, DEATH_FRAME_SEC, DEATH_REST_SEC, CHARACTER_DEATH_PATH)


func active_count() -> int:
	return _active.size()


func _spawn(
	effect_id: StringName,
	world_position: Vector2,
	rotation_rad: float,
	frame_sec: float,
	hold_last_sec: float,
	path_template: String
) -> void:
	var frames: Array[Texture2D] = _load_frames(effect_id, path_template)
	if frames.is_empty() or _idle.is_empty():
		return
	var sprite: Sprite2D = _idle.pop_back()
	sprite.texture = frames[0]
	sprite.global_position = world_position
	sprite.rotation = rotation_rad
	sprite.visible = true
	_active.append({
		"sprite": sprite, "frames": frames, "elapsed": 0.0,
		"frame_sec": frame_sec, "hold_last_sec": hold_last_sec,
	})


func _process(delta: float) -> void:
	for index in range(_active.size() - 1, -1, -1):
		var record: Dictionary = _active[index]
		var elapsed: float = float(record["elapsed"]) + delta
		record["elapsed"] = elapsed
		var frames: Array[Texture2D] = record["frames"]
		var frame: int = int(elapsed / float(record["frame_sec"]))
		var sprite: Sprite2D = record["sprite"]
		if frame >= frames.size():
			# Hold the resting frame rather than looping back to the start.
			var hold: float = float(record["hold_last_sec"])
			if hold > 0.0 and elapsed < float(frames.size()) * float(record["frame_sec"]) + hold:
				sprite.texture = frames[frames.size() - 1]
				continue
			# Played once and stopped, as the handoff specifies.
			sprite.visible = false
			_idle.append(sprite)
			_active.remove_at(index)
			continue
		sprite.texture = frames[frame]


## Frames are cached on first use: the same four textures are replayed for every
## hit of that kind for the rest of the run.
func _load_frames(effect_id: StringName, path_template: String = FRAME_PATH) -> Array[Texture2D]:
	var cache_key: String = "%s|%s" % [path_template, effect_id]
	if _frames.has(cache_key):
		return _frames[cache_key]
	var frames: Array[Texture2D] = []
	for index in FRAME_COUNT:
		var path: String = path_template % [effect_id, index]
		if not ResourceLoader.exists(path):
			push_warning("EffectPool: missing effect frame %s" % path)
			frames.clear()
			break
		frames.append(ResourceLoader.load(path) as Texture2D)
	_frames[cache_key] = frames
	return frames
