class_name Player
extends CharacterBody2D
## Stage player. Renders the AC-1 taoist sprite set (N3-2): right-facing idle
## frame plus a 4-frame walk strip, mirrored left through Visual.scale.x.

const CHARACTERS_PATH := "res://data/characters.json"
const CHARACTER_ID := "taoist"

const IDLE_TEXTURE_PATH := "res://asset/characters/taoist/idle.png"
const WALK_TEXTURE_PATH := "res://asset/characters/taoist/walk.png"
## AC-1 export contract (asset/characters/taoist/README.md): PNGs are exact
## 16x nearest-neighbor blocks of 40x40 logical frames, figure 38px tall,
## which is the intended in-world read on the 540px viewport.
const SPRITE_EXPORT_SCALE := 16.0
const WALK_FRAME_COUNT := 4
const WALK_FPS := 8.0
const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"

## Widest body half-extent; enemies use it for contact-range checks.
const CONTACT_RADIUS := 15.0
const INVULN_FLASH_ALPHA := 0.5

## Set by the stage each physics frame from the virtual joystick; zero means
## "no touch input", which falls back to the keyboard actions.
var joystick_input := Vector2.ZERO
var facing: int = PlayerMotion.FACING_RIGHT
var bounds := Rect2()  # zero-size = unclamped; the stage sets the ground rect
var hp: float = 0.0
var hp_max: float = 0.0  # raised with hp by the max_hp passive (stage)

var _speed: float = 0.0
var _invuln_window: float = 0.0
var _time_since_hit: float = 0.0
var _visual: Node2D
var _sprite: AnimatedSprite2D

signal died
## N3-8: fired on every landed hit so the HUD can pulse the damage vignette.
signal hit_taken


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
	# Solid stage props (N3-9) block the player on top of the default layer.
	collision_mask |= StageField.LAYER_OBSTACLE
	_speed = load_move_speed()
	hp = load_base_hp()
	hp_max = hp
	_invuln_window = load_hit_invuln_sec()
	_time_since_hit = _invuln_window  # spawn vulnerable, not mid-window
	_build_sprite_visual()
	_build_hp_bar()


func _physics_process(delta: float) -> void:
	_time_since_hit += delta
	var move_input: Vector2 = joystick_input
	if move_input == Vector2.ZERO:
		move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = PlayerMotion.velocity_for(move_input, _speed)
	facing = PlayerMotion.facing_sign(velocity.x, facing)
	_visual.scale.x = float(facing)
	_update_animation()
	var invulnerable: bool = not CombatMath.can_hit(_time_since_hit, _invuln_window)
	_visual.modulate.a = INVULN_FLASH_ALPHA if invulnerable else 1.0
	move_and_slide()
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)


## N3-6 move-speed passive: rescale from the data base so stacks never compound.
func set_speed_scale(scale: float) -> void:
	_speed = load_move_speed() * scale


## Returns true when the hit landed; false while the invulnerability window
## from the previous hit is still open.
func take_hit(damage: float) -> bool:
	if not CombatMath.can_hit(_time_since_hit, _invuln_window):
		return false
	_time_since_hit = 0.0
	hp = CombatMath.apply_damage(hp, damage)
	hit_taken.emit()
	if CombatMath.is_dead(hp):
		died.emit()
	return true


## Walk speed_scale follows actual travel speed so slow joystick pushes read
## as a slower stride around the WALK_FPS baseline.
func _update_animation() -> void:
	if velocity != Vector2.ZERO:
		_sprite.play(ANIM_WALK)
		_sprite.speed_scale = velocity.length() / _speed if _speed > 0.0 else 1.0
	else:
		_sprite.play(ANIM_IDLE)
		_sprite.speed_scale = 1.0


## The wrapper keeps the facing flip on Visual.scale.x = ±1 while the sprite
## child holds the 1/16 export downscale back to logical pixels.
func _build_sprite_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = build_sprite_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE / SPRITE_EXPORT_SCALE
	_sprite.play(ANIM_IDLE)
	_visual.add_child(_sprite)
	add_child(_visual)


## Public and static so the headless suite can verify the frame contract
## without a SceneTree (same pattern as TitleScreen.build_ui).
static func build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.rename_animation("default", ANIM_IDLE)
	frames.add_frame(ANIM_IDLE, load(IDLE_TEXTURE_PATH))
	frames.add_animation(ANIM_WALK)
	frames.set_animation_speed(ANIM_WALK, WALK_FPS)
	var walk: Texture2D = load(WALK_TEXTURE_PATH)
	var frame_size := Vector2(walk.get_size().x / float(WALK_FRAME_COUNT), walk.get_size().y)
	for i: int in range(WALK_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = walk
		frame.region = Rect2(Vector2(frame_size.x * float(i), 0.0), frame_size)
		frames.add_frame(ANIM_WALK, frame)
	return frames


func _build_hp_bar() -> void:
	var bar := HpBar.new()
	bar.name = "HpBar"
	bar.player = self
	add_child(bar)


## Near-invisible HP readout per DESIGN.md §3 ("HP는 최소 표시"): a thin bar
## under the figure, drawn only after the player has actually taken damage.
## Kept outside Visual so the facing flip and invuln alpha flash skip it.
class HpBar:
	extends Node2D

	const BAR_SIZE := Vector2(26.0, 3.0)
	const BAR_OFFSET_Y := 22.0

	var player: Player

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if player.hp_max <= 0.0 or player.hp >= player.hp_max:
			return
		var origin := Vector2(-BAR_SIZE.x / 2.0, BAR_OFFSET_Y)
		draw_rect(Rect2(origin, BAR_SIZE), UiPalette.INK)
		var ratio: float = clampf(player.hp / player.hp_max, 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), UiPalette.SUCCESS)
