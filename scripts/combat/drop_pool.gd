class_name DropPool
extends Node2D
## Ground drops: pooled pickups that sit on the field with their idle art and
## play a four-frame collect sequence when taken.
##
## Same discipline as EffectPool, CombatAudio and EnemyPool, for the same reason:
## a 200-death wave allocating a node per pickup is where the frame rate goes.
## Sprites are allocated once and recycled; when every slot is busy a further
## drop is skipped rather than allowed to allocate.
##
## Paths and frame order come from asset/LOOT_AND_BOSS_REPORT.md: a 24x24 idle
## and four 32x32 collect frames, 0 anticipation through 3 completion, played in
## ascending order before the pickup is freed.

signal drop_collected(xp_amount: int, gold_amount: int)

const IDLE_PATH: String = "res://asset/drop/%s/idle.png"
const COLLECT_PATH: String = "res://asset/drop/%s/collect/%d.png"
const COLLECT_FRAMES: int = 4

const PLAYER_GROUP: StringName = &"player"

## Grade thresholds for the experience drops, so a spirit worth 5 reads
## differently on the ground from a goblin worth 1.
const XP_MEDIUM_MIN: int = 3
const XP_LARGE_MIN: int = 8

## A handful of coins is a coin; a real payout is a pile.
const GOLD_PILE_MIN: int = 4

## Chests are earned, not random. monsters.json carries no grade field, so the
## mapping from a monster to its chest grade lives here with the code that uses
## it; content-data adding a grade would move it to data unchanged in meaning.
const BEHAVIOUR_BOSS: String = "boss"
const BEHAVIOUR_ELITE: String = "charger"
const BOSS_CHEST: StringName = &"chest_mythic"
const ELITE_CHEST: StringName = &"chest_rare"

const MAX_CONCURRENT_DROPS: int = 128
const DROP_Z_INDEX: int = 10

const MAGNET_RADIUS_PX: float = 90.0
const MAGNET_SPEED_PX_SEC: float = 420.0
const COLLECT_RADIUS_PX: float = 12.0
const COLLECT_FRAME_SEC: float = 0.06
## Uncollected drops do not accumulate for a whole run.
const LIFETIME_SEC: float = 60.0

static var _instance: DropPool = null

var _idle: Array[Sprite2D] = []
var _active: Array[Dictionary] = []
var _textures: Dictionary = {}


func _ready() -> void:
	for index in MAX_CONCURRENT_DROPS:
		var sprite := Sprite2D.new()
		sprite.name = "Drop%d" % index
		sprite.visible = false
		sprite.z_index = DROP_Z_INDEX
		add_child(sprite)
		_idle.append(sprite)
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


## Everything a monster leaves behind. Experience and gold come from its data;
## a chest is added for a boss or an elite.
static func spawn_for_kill(monster_data: Dictionary, world_position: Vector2) -> void:
	if _instance == null:
		return
	var xp: int = maxi(int(monster_data.get("xp_drop", 0)), 0)
	var gold: int = maxi(int(monster_data.get("gold_drop", 0)), 0)
	var behaviour: String = String(monster_data.get("behaviour", ""))

	if xp > 0:
		_instance._spawn(xp_drop_id(xp), world_position, xp, 0)
	if gold > 0:
		# Offset so the coin does not sit exactly under the experience orb.
		_instance._spawn(gold_drop_id(gold), world_position + Vector2(9, 5), 0, gold)
	var chest: StringName = chest_id_for(behaviour)
	if not chest.is_empty():
		_instance._spawn(chest, world_position + Vector2(-9, 5), 0, 0)


static func xp_drop_id(amount: int) -> StringName:
	if amount >= XP_LARGE_MIN:
		return &"xp_large"
	if amount >= XP_MEDIUM_MIN:
		return &"xp_medium"
	return &"xp_small"


static func gold_drop_id(amount: int) -> StringName:
	return &"gold_pile" if amount >= GOLD_PILE_MIN else &"gold_coin"


## "" when the kill earns no chest.
static func chest_id_for(behaviour: String) -> StringName:
	if behaviour == BEHAVIOUR_BOSS:
		return BOSS_CHEST
	if behaviour == BEHAVIOUR_ELITE:
		return ELITE_CHEST
	return &""


## Sweeps every drop still on the field and returns what it was worth, as
## {"xp": int, "gold": int}. Called when a run ends: a pickup left behind was
## previously just lost, which measured at about 9% of a run's gold.
##
## Deliberately silent rather than routed through drop_collected, because the
## run is already over: crediting experience at that point could fire a
## level-up behind the results screen. The caller decides what each total means.
##
## The authored collect frames are NOT played here. The results screen is not
## delayed for this, so there is no frame on which they could be seen -- see the
## note in Stage._end_run.
func collect_remaining() -> Dictionary:
	var totals: Dictionary = {"xp": 0, "gold": 0}
	for index in range(_active.size() - 1, -1, -1):
		var drop: Dictionary = _active[index]
		if not bool(drop["collecting"]):
			totals["xp"] = int(totals["xp"]) + int(drop["xp"])
			totals["gold"] = int(totals["gold"]) + int(drop["gold"])
		_release(index)
	return totals


func active_count() -> int:
	return _active.size()


func _spawn(drop_id: StringName, world_position: Vector2, xp: int, gold: int) -> void:
	var idle: Texture2D = _texture(IDLE_PATH % drop_id)
	if idle == null or _idle.is_empty():
		return
	var sprite: Sprite2D = _idle.pop_back()
	sprite.texture = idle
	sprite.global_position = world_position
	sprite.visible = true
	_active.append({
		"sprite": sprite, "id": drop_id, "xp": xp, "gold": gold,
		"age": 0.0, "collecting": false, "collect_elapsed": 0.0,
	})


func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	for index in range(_active.size() - 1, -1, -1):
		var drop: Dictionary = _active[index]
		if bool(drop["collecting"]):
			if _advance_collect(drop, delta):
				_release(index)
			continue
		drop["age"] = float(drop["age"]) + delta
		if float(drop["age"]) >= LIFETIME_SEC:
			_release(index)
			continue
		if player != null:
			_attract(drop, player, delta)


func _attract(drop: Dictionary, player: Node2D, delta: float) -> void:
	var sprite: Sprite2D = drop["sprite"]
	var offset: Vector2 = player.global_position - sprite.global_position
	var distance: float = offset.length()
	if distance > MAGNET_RADIUS_PX:
		return
	if distance <= COLLECT_RADIUS_PX:
		_begin_collect(drop)
		return
	sprite.global_position += offset / distance * MAGNET_SPEED_PX_SEC * delta


## The payout happens as collection starts, so the run is credited even if the
## player dies during the four frames.
func _begin_collect(drop: Dictionary) -> void:
	drop["collecting"] = true
	drop["collect_elapsed"] = 0.0
	drop_collected.emit(int(drop["xp"]), int(drop["gold"]))


## Returns true once the sequence has finished and the slot can be recycled.
func _advance_collect(drop: Dictionary, delta: float) -> bool:
	var elapsed: float = float(drop["collect_elapsed"]) + delta
	drop["collect_elapsed"] = elapsed
	var frame: int = int(elapsed / COLLECT_FRAME_SEC)
	if frame >= COLLECT_FRAMES:
		return true
	var texture: Texture2D = _texture(COLLECT_PATH % [drop["id"], frame])
	if texture == null:
		return true
	var sprite: Sprite2D = drop["sprite"]
	sprite.texture = texture
	return false


func _release(index: int) -> void:
	var sprite: Sprite2D = _active[index]["sprite"]
	sprite.visible = false
	_idle.append(sprite)
	_active.remove_at(index)


func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = ResourceLoader.load(path) as Texture2D
	else:
		push_warning("DropPool: missing drop art %s" % path)
	_textures[path] = texture
	return texture
