class_name Player
extends CharacterBody2D
## The hunter. Movement is the only thing the player controls (GDD section 6);
## weapons fire themselves.
##
## Stats come from GameData.character() plus RunState passive totals. Input comes
## from an exported adapter node so a touch joystick can be wired in later
## without touching combat code.

const PLAYER_GROUP: StringName = &"player"

const DEFAULT_BASE_HP: float = 100.0
const DEFAULT_BASE_SPEED: float = 90.0

const STAT_MOVE_SPEED: String = "move_speed"
const STAT_MAX_HP: String = "max_hp"

## Grace window after a hit. Without it, standing inside a swarm drains the bar
## in a single frame instead of giving the player time to walk out.
const INVULNERABLE_SEC: float = 0.6
const HIT_FLASH_ALPHA: float = 0.35
const HIT_FLASH_HZ: float = 12.0

const PLACEHOLDER_TINT: Color = Color(0.42, 0.78, 1.0)
const SPRITE_KEY: String = "sprite"

## One authored sprite per direction (asset/M1_ASSET_REPORT.md). Warrior and
## Archer only ship "south" for M1, so a missing rotation falls back rather
## than leaving the hunter invisible.
const ROTATION_PATH: String = "res://asset/character/%s/Idle/rotations/%s.png"
const CHARACTER_FOLDERS: Dictionary = {
	"taoist": "Taoist",
	"warrior": "Warrior",
	"archer": "Archer",
}

## Attack presentation. The body never redraws: the VFX carries the attack, the
## body only flashes briefly and may recoil a single pixel for one tick.
const ATTACK_FLASH_SEC: float = 0.06
const ATTACK_FLASH_TINT: Color = Color(1.7, 1.7, 1.7)
const RECOIL_TICKS: int = 1
const KEY_BASE_HP: String = "base_hp"
const KEY_BASE_SPEED: String = "base_speed"
const KEY_STARTING_WEAPON: String = "starting_weapon"
const KEY_CATEGORY: String = "category"
const KEY_ID: String = "id"
const KEY_LEVEL: String = "level"

## Any Node exposing get_move_vector() -> Vector2. meta-ui may replace the
## default keyboard adapter with a virtual stick by re-pointing this path.
@export var input_adapter_path: NodePath = ^"PlayerInput"
## Editor/debug escape hatch when the scene is run without a RunState.
@export var character_id_override: String = ""

var max_hp: float = DEFAULT_BASE_HP
var hp: float = DEFAULT_BASE_HP
var move_speed: float = DEFAULT_BASE_SPEED
var facing: Vector2 = Vector2.RIGHT

var _invulnerable_left: float = 0.0
var _input_adapter: Node = null
var _weapons: Array[WeaponBase] = []
var _character_data: Dictionary = {}
## source weapon id -> evolved weapon id, for weapons that have already evolved.
var _evolution_swaps: Dictionary = {}

## Motion state. `_motion_time` restarts on every state change so a cycle always
## begins on its first frame instead of mid-stride.
var _is_walking: bool = false
var _motion_time: float = 0.0
var _attack_flash_left: float = 0.0
var _recoil_ticks_left: int = 0
var _recoil_offset: Vector2i = Vector2i.ZERO
var _direction_name: String = CharacterMotion.DEFAULT_DIRECTION
var _rotation_cache: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hurt_box: Area2D = $HurtBox
@onready var _weapon_root: Node2D = $Weapons
@onready var _evolution: WeaponEvolution = $WeaponEvolution


func _ready() -> void:
	add_to_group(PLAYER_GROUP)
	_input_adapter = get_node_or_null(input_adapter_path)
	if _input_adapter == null or not _input_adapter.has_method(&"get_move_vector"):
		push_warning("Player: input adapter missing get_move_vector(), the hunter will not move")
		_input_adapter = null
	_character_data = _load_character()
	_apply_stats(_character_data)
	hp = max_hp
	_apply_sprite(_character_data)
	_sync_weapons()
	if _weapons.is_empty():
		push_warning("Player: no weapons in RunState and no starting_weapon, entering the stage unarmed")
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)


func _physics_process(delta: float) -> void:
	_tick_invulnerability(delta)
	var direction: Vector2 = _read_input()
	if direction.length_squared() > 0.0:
		facing = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	_apply_contact_damage()
	_advance_motion(direction, delta)


func is_alive() -> bool:
	return hp > 0.0


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func take_damage(amount: float, _is_crit: bool = false) -> void:
	if amount <= 0.0 or not is_alive() or is_invulnerable():
		return
	hp = maxf(hp - amount, 0.0)
	_invulnerable_left = INVULNERABLE_SEC
	EventBus.player_damaged.emit(amount, hp)
	if hp > 0.0:
		return
	EffectPool.play_character_death(String(CHARACTER_FOLDERS.get(_character_id(), "")), global_position)
	EventBus.player_died.emit()
	EventBus.stat_recorded.emit("player_died", 1)


func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	hp = minf(hp + amount, max_hp)


func weapons() -> Array[WeaponBase]:
	return _weapons


func add_weapon(id: String, start_level: int = CombatMath.MIN_LEVEL) -> WeaponBase:
	if id.is_empty():
		return null
	var weapon_data: Dictionary = GameData.weapon(id)
	var weapon: WeaponBase = WeaponRegistry.create(String(weapon_data.get(KEY_CATEGORY, "")))
	weapon.name = "Weapon_%s" % id
	_weapon_root.add_child(weapon)
	weapon.setup(id, start_level)
	weapon.fired.connect(_on_weapon_fired)
	_weapons.append(weapon)
	return weapon


func find_weapon(id: String) -> WeaponBase:
	for weapon in _weapons:
		if weapon.weapon_id == id:
			return weapon
	return null


func _read_input() -> Vector2:
	if _input_adapter == null:
		return Vector2.ZERO
	var raw: Variant = _input_adapter.call(&"get_move_vector")
	if not (raw is Vector2):
		return Vector2.ZERO
	var vector: Vector2 = raw
	return vector if vector.length() <= 1.0 else vector.normalized()


func _tick_invulnerability(delta: float) -> void:
	if _invulnerable_left <= 0.0:
		return
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


## Enemies damage on touch. Polled instead of signal-driven because contact is a
## sustained state, and the i-frame window is what rate-limits it.
func _apply_contact_damage() -> void:
	if _hurt_box == null or is_invulnerable() or not is_alive():
		return
	for body in _hurt_box.get_overlapping_bodies():
		var damage: Variant = body.get(&"contact_damage")
		if damage is float and float(damage) > 0.0:
			take_damage(float(damage))
			return


func _load_character() -> Dictionary:
	var character_id: String = character_id_override
	if character_id.is_empty():
		character_id = RunState.character_id
	if character_id.is_empty():
		return {}
	return GameData.character(character_id)


## max_hp and move_speed passives are fractional in data/passives.json
## (0.10 and 0.05 per stack), so they scale the character base rather than being
## added to it; scripts/ui/hud.gd reads max_hp the same way.
func _apply_stats(character_data: Dictionary) -> void:
	var base_hp: float = float(character_data.get(KEY_BASE_HP, DEFAULT_BASE_HP))
	var base_speed: float = float(character_data.get(KEY_BASE_SPEED, DEFAULT_BASE_SPEED))
	max_hp = maxf(base_hp * (1.0 + RunState.stat_total(STAT_MAX_HP)), 1.0)
	move_speed = maxf(base_speed * (1.0 + RunState.stat_total(STAT_MOVE_SPEED)), 0.0)


## Recomputed after every pick: max_hp and move_speed passives taken mid-run
## were otherwise dead stats, because _ready() ran before they existed. The
## damage already taken is preserved so a level-up is not a free heal.
func _refresh_stats() -> void:
	var missing_hp: float = max_hp - hp
	_apply_stats(_character_data)
	hp = clampf(max_hp - missing_hp, 0.0, max_hp)


func _apply_sprite(_character_data_unused: Dictionary) -> void:
	if _sprite == null:
		return
	_sprite.centered = true
	_apply_direction(CharacterMotion.DEFAULT_DIRECTION)


## Swaps in the authored rotation for `direction`, caching loads because this is
## queried every time the movement vector crosses a 45 degree boundary.
func _apply_direction(direction: String) -> void:
	if _sprite == null or (direction == _direction_name and _sprite.texture != null):
		return
	_direction_name = direction
	_sprite.texture = _rotation_texture(direction)


func _rotation_texture(direction: String) -> Texture2D:
	if _rotation_cache.has(direction):
		return _rotation_cache[direction]
	var folder: String = String(CHARACTER_FOLDERS.get(_character_id(), ""))
	var texture: Texture2D = null
	if not folder.is_empty():
		texture = _load_rotation(folder, direction)
		if texture == null and direction != CharacterMotion.DEFAULT_DIRECTION:
			# Warrior and Archer ship one direction for M1.
			texture = _load_rotation(folder, CharacterMotion.DEFAULT_DIRECTION)
	if texture == null:
		texture = PlaceholderArt.placeholder(PLACEHOLDER_TINT)
	_rotation_cache[direction] = texture
	return texture


func _load_rotation(folder: String, direction: String) -> Texture2D:
	var path: String = ROTATION_PATH % [folder, direction]
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	return resource as Texture2D


func _character_id() -> String:
	if not character_id_override.is_empty():
		return character_id_override
	return RunState.character_id


## Deferred so RunState has already applied the pick: both this node and
## RunState listen to upgrade_chosen, and only RunState knows whether the id was
## a weapon or a passive.
func _on_upgrade_chosen(_choice_id: String) -> void:
	_apply_run_state.call_deferred()


func _apply_run_state() -> void:
	_refresh_stats()
	_check_evolutions()
	_sync_weapons()


## Records any evolution that has become available. Both triggers -- a weapon
## level-up and a passive stack gain -- arrive through upgrade_chosen, and
## GameData.evolution_for() decides whether the thresholds are met.
func _check_evolutions() -> void:
	if _evolution == null:
		return
	for entry: Dictionary in _run_state_loadout():
		var source_id: String = String(entry.get(KEY_ID, ""))
		# Already evolved: the source id still sits in RunState.weapons, and
		# re-querying it would re-fire the swap on every later level-up.
		if source_id.is_empty() or _evolution_swaps.has(source_id):
			continue
		var evolved_id: String = _evolution.evaluate(source_id, RunState.passives)
		if evolved_id.is_empty():
			continue
		_evolution_swaps[source_id] = evolved_id


## Rebuilds the weapon nodes so they match RunState (with evolutions applied).
## Idempotent, so it is safe to call after every upgrade.
func _sync_weapons() -> void:
	var wanted: Dictionary = _wanted_loadout()
	for weapon: WeaponBase in _weapons.duplicate():
		if wanted.has(weapon.weapon_id):
			weapon.set_level(int(wanted[weapon.weapon_id]))
			continue
		_weapons.erase(weapon)
		weapon.queue_free()
	for weapon_key: Variant in wanted.keys():
		var weapon_id: String = String(weapon_key)
		if find_weapon(weapon_id) == null:
			add_weapon(weapon_id, int(wanted[weapon_key]))


## Owned weapon ids mapped to their level, with evolved weapons substituted for
## their source. An evolved weapon inherits the source level so a level-up spent
## before the swap is not thrown away.
func _wanted_loadout() -> Dictionary:
	var loadout: Dictionary = {}
	for entry: Dictionary in _run_state_loadout():
		var source_id: String = String(entry.get(KEY_ID, ""))
		if source_id.is_empty():
			continue
		var target_id: String = String(_evolution_swaps.get(source_id, source_id))
		loadout[target_id] = int(entry.get(KEY_LEVEL, CombatMath.MIN_LEVEL))
	return loadout


## RunState is authoritative once a run has begun. The character fallback only
## matters when scenes/combat/stage.tscn is played directly during development.
func _run_state_loadout() -> Array[Dictionary]:
	if not RunState.weapons.is_empty():
		return RunState.weapons
	var starting_weapon: String = String(_character_data.get(KEY_STARTING_WEAPON, ""))
	if starting_weapon.is_empty():
		return []
	return [{KEY_ID: starting_weapon, KEY_LEVEL: CombatMath.MIN_LEVEL}]


## --- procedural motion (asset/M1_ASSET_REPORT.md) ---------------------------

## Chooses the rotation and the whole-pixel sprite offset for this tick. The
## CharacterBody2D itself never moves here, so collision placement is untouched.
func _advance_motion(direction: Vector2, delta: float) -> void:
	if _sprite == null:
		return

	var walking: bool = direction.length_squared() > 0.0
	if walking != _is_walking:
		# State change resets the cycle and the offset, so motion cannot leak
		# into the next state or into collision placement.
		_is_walking = walking
		_motion_time = 0.0
		_sprite.position = Vector2.ZERO
	_motion_time += delta

	if walking:
		_apply_direction(CharacterMotion.direction_name(direction))

	var is_recoiling: bool = _recoil_ticks_left > 0
	if is_recoiling:
		_recoil_ticks_left -= 1

	var offset: Vector2i = CharacterMotion.sprite_offset(
		_motion_time, walking, _recoil_offset, is_recoiling
	)
	if not is_recoiling:
		_recoil_offset = Vector2i.ZERO

	_sprite.position = Vector2(offset)
	_tick_attack_flash(delta)


func _tick_attack_flash(delta: float) -> void:
	if _attack_flash_left > 0.0:
		_attack_flash_left = maxf(_attack_flash_left - delta, 0.0)
	_sprite.modulate = ATTACK_FLASH_TINT if _attack_flash_left > 0.0 else Color.WHITE
	_sprite.modulate.a = _invulnerability_alpha()


func _invulnerability_alpha() -> float:
	if _invulnerable_left <= 0.0:
		return 1.0
	var blink: bool = fmod(_invulnerable_left * HIT_FLASH_HZ, 1.0) < 0.5
	return HIT_FLASH_ALPHA if blink else 1.0


## A weapon fired: the VFX carries the attack, the body only flashes and may
## recoil one pixel for a single tick. It never leaves its authored pose.
func _on_weapon_fired(_weapon_id: String) -> void:
	_attack_flash_left = ATTACK_FLASH_SEC
	_recoil_offset = CharacterMotion.recoil_offset(facing)
	_recoil_ticks_left = RECOIL_TICKS
	if _sprite != null:
		_sprite.position = Vector2.ZERO
