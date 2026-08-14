class_name Player
extends CharacterBody2D
## Stage player (N3-1). The rect visual is a placeholder — N3-2 replaces it
## with the AC-1 taoist sprite; the facing-flip contract on Visual.scale.x stays.

const CHARACTERS_PATH := "res://data/characters.json"
const CHARACTER_ID := "taoist"
const BODY_SIZE := Vector2(20.0, 30.0)  # ~30px logical height, DESIGN.md §5
const EYE_SIZE := Vector2(4.0, 4.0)
const EYE_OFFSET := Vector2(5.0, -9.0)  # upper body, toward the facing side

## Widest body half-extent; enemies use it for contact-range checks.
const CONTACT_RADIUS := 15.0
const INVULN_FLASH_ALPHA := 0.5

## Set by the stage each physics frame from the virtual joystick; zero means
## "no touch input", which falls back to the keyboard actions.
var joystick_input := Vector2.ZERO
var facing: int = PlayerMotion.FACING_RIGHT
var bounds := Rect2()  # zero-size = unclamped; the stage sets the ground rect
var hp: float = 0.0

var _speed: float = 0.0
var _invuln_window: float = 0.0
var _time_since_hit: float = 0.0
var _visual: Node2D

signal died


static func load_move_speed() -> float:
	return _load_character_number("base_speed")


static func load_base_hp() -> float:
	return _load_character_number("base_hp")


static func load_hit_invuln_sec() -> float:
	return _load_character_number("hit_invuln_sec")


static func load_starting_weapon() -> String:
	var text: String = FileAccess.get_file_as_string(CHARACTERS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary or not (data as Dictionary).has(CHARACTER_ID):
		push_error("player: cannot read '%s' from %s" % [CHARACTER_ID, CHARACTERS_PATH])
		return ""
	return String((data[CHARACTER_ID] as Dictionary).get("starting_weapon", ""))


static func _load_character_number(field: String) -> float:
	var text: String = FileAccess.get_file_as_string(CHARACTERS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary or not (data as Dictionary).has(CHARACTER_ID):
		push_error("player: cannot read '%s' from %s" % [CHARACTER_ID, CHARACTERS_PATH])
		return 0.0
	var character: Dictionary = data[CHARACTER_ID]
	return float(character.get(field, 0.0))


func _ready() -> void:
	_speed = load_move_speed()
	hp = load_base_hp()
	_invuln_window = load_hit_invuln_sec()
	_time_since_hit = _invuln_window  # spawn vulnerable, not mid-window
	_build_placeholder_visual()


func _physics_process(delta: float) -> void:
	_time_since_hit += delta
	var move_input: Vector2 = joystick_input
	if move_input == Vector2.ZERO:
		move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = PlayerMotion.velocity_for(move_input, _speed)
	facing = PlayerMotion.facing_sign(velocity.x, facing)
	_visual.scale.x = float(facing)
	var invulnerable: bool = not CombatMath.can_hit(_time_since_hit, _invuln_window)
	_visual.modulate.a = INVULN_FLASH_ALPHA if invulnerable else 1.0
	move_and_slide()
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)


## Returns true when the hit landed; false while the invulnerability window
## from the previous hit is still open.
func take_hit(damage: float) -> bool:
	if not CombatMath.can_hit(_time_since_hit, _invuln_window):
		return false
	_time_since_hit = 0.0
	hp = CombatMath.apply_damage(hp, damage)
	if CombatMath.is_dead(hp):
		died.emit()
	return true


func _build_placeholder_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	var body := ColorRect.new()
	body.name = "Body"
	body.color = UiPalette.ACCENT_TAOIST
	body.size = BODY_SIZE
	body.position = -BODY_SIZE / 2.0
	_visual.add_child(body)
	var eye := ColorRect.new()
	eye.name = "Eye"
	eye.color = UiPalette.INK
	eye.size = EYE_SIZE
	eye.position = EYE_OFFSET - EYE_SIZE / 2.0
	_visual.add_child(eye)
	add_child(_visual)
