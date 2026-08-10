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
	var character_data: Dictionary = _load_character()
	_apply_stats(character_data)
	_apply_sprite(character_data)
	_build_weapons(character_data)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)


func _physics_process(delta: float) -> void:
	_tick_invulnerability(delta)
	var direction: Vector2 = _read_input()
	if direction.length_squared() > 0.0:
		facing = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	_apply_contact_damage()


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
	weapon.level_changed.connect(_on_weapon_level_changed)
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
	if _sprite == null:
		return
	if _invulnerable_left <= 0.0:
		_sprite.modulate.a = 1.0
		return
	var blink: bool = fmod(_invulnerable_left * HIT_FLASH_HZ, 1.0) < 0.5
	_sprite.modulate.a = HIT_FLASH_ALPHA if blink else 1.0


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


func _apply_stats(character_data: Dictionary) -> void:
	var base_hp: float = float(character_data.get(KEY_BASE_HP, DEFAULT_BASE_HP))
	var base_speed: float = float(character_data.get(KEY_BASE_SPEED, DEFAULT_BASE_SPEED))
	max_hp = maxf(base_hp + RunState.stat_total(STAT_MAX_HP), 1.0)
	hp = max_hp
	move_speed = maxf(base_speed + RunState.stat_total(STAT_MOVE_SPEED), 0.0)


func _apply_sprite(character_data: Dictionary) -> void:
	if _sprite == null or _sprite.texture != null:
		return
	_sprite.texture = PlaceholderArt.texture_or_placeholder(
		String(character_data.get(SPRITE_KEY, "")), PLACEHOLDER_TINT
	)


func _build_weapons(character_data: Dictionary) -> void:
	var entries: Array[Dictionary] = RunState.weapons.duplicate()
	if entries.is_empty():
		var starting_weapon: String = String(character_data.get(KEY_STARTING_WEAPON, ""))
		if starting_weapon.is_empty():
			push_warning("Player: character has no starting_weapon, entering the stage unarmed")
			return
		entries.append({KEY_ID: starting_weapon, KEY_LEVEL: CombatMath.MIN_LEVEL})
	for entry in entries:
		add_weapon(String(entry.get(KEY_ID, "")), int(entry.get(KEY_LEVEL, CombatMath.MIN_LEVEL)))


## A level-up choice is either a weapon the hunter owns (level it), a new weapon
## (add it), or a passive (which may unlock an evolution).
func _on_upgrade_chosen(choice_id: String) -> void:
	var owned: WeaponBase = find_weapon(choice_id)
	if owned != null:
		owned.level_up()
		return
	if not GameData.weapon(choice_id).is_empty():
		add_weapon(choice_id)
		return
	_check_evolutions()


func _on_weapon_level_changed(_weapon_id: String, _level: int) -> void:
	_check_evolutions()


func _check_evolutions() -> void:
	if _evolution == null:
		return
	for weapon in _weapons:
		var evolved_id: String = _evolution.evaluate(weapon.weapon_id, weapon.level, RunState.passives)
		if evolved_id.is_empty():
			continue
		_replace_weapon(weapon, evolved_id)
		return


## An evolution may cross categories (a talisman into a blade), so the node is
## rebuilt through the registry instead of only swapping the id in place.
func _replace_weapon(weapon: WeaponBase, evolved_id: String) -> void:
	_weapons.erase(weapon)
	weapon.queue_free()
	add_weapon(evolved_id)
