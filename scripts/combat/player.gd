class_name Player
extends CharacterBody2D
## Stage player. Renders the AC-1 taoist sprite set (N3-2): right-facing idle
## frame plus a 4-frame walk strip, mirrored left through Visual.scale.x.

const CHARACTERS_PATH := "res://data/characters.json"

## AC-1 art only exists for the taoist; locked characters cannot be selected
## (N2-1), so the sprite set stays taoist until another roster entry ships art.
const IDLE_TEXTURE_PATH := "res://asset/characters/taoist/idle.png"
const WALK_TEXTURE_PATH := "res://asset/characters/taoist/walk.png"
## AC-1 export contract (asset/characters/taoist/README.md): PNGs are exact
## 16x nearest-neighbor blocks of 40x40 logical frames, figure 38px tall,
## which is the intended in-world read on the 540px viewport.
const SPRITE_EXPORT_SCALE := SpriteSheet.EXPORT_SCALE
const WALK_FRAME_COUNT := 4
const WALK_FPS := 8.0
const IDLE_FPS := 1.0  # single idle frame; the speed value is inert
const ANIM_IDLE := SpriteSheet.ANIM_IDLE
const ANIM_WALK := SpriteSheet.ANIM_WALK

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
## Last non-zero travel direction — the 축지 blink heading (N4-4b); defaults
## to facing-right so a blink from standstill still goes somewhere.
var last_move_direction := Vector2.RIGHT
## N6-2: display name of whatever landed the last hit — the killing blow's
## source by the time `died` fires. Empty when nothing attributable ever hit.
var last_hit_source := ""

var _speed: float = 0.0
var _invuln_window: float = 0.0
## N7-2 명부수: incoming-hit multiplier (철피) and invulnerability-window
## scale (긴 호흡), both set once by the stage from the capped meta aggregate.
var _damage_taken_scale: float = 1.0
var _time_since_hit: float = 0.0
var _bonus_invuln_left: float = 0.0  # granted by actives, on top of hit i-frames
var _visual: Node2D
var _sprite: AnimatedSprite2D

signal died
## N3-8: fired on every landed hit so the HUD can pulse the damage vignette.
signal hit_taken


## The run starts with the profile's selected character (N2-1); node-free
## headless tests have no SaveService instance and fall back to the default.
static func _character_id() -> String:
	if SaveService.instance != null:
		return SaveService.instance.selected_character()
	return SaveProfile.DEFAULT_CHARACTER


static func load_move_speed() -> float:
	return _load_character_number("base_speed")


static func load_base_hp() -> float:
	return _load_character_number("base_hp")


static func load_hit_invuln_sec() -> float:
	return _load_character_number("hit_invuln_sec")


static func load_starting_weapon() -> String:
	var character_id: String = _character_id()
	var text: String = FileAccess.get_file_as_string(CHARACTERS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary or not (data as Dictionary).has(character_id):
		push_error("player: cannot read '%s' from %s" % [character_id, CHARACTERS_PATH])
		return ""
	return String((data[character_id] as Dictionary).get("starting_weapon", ""))


## N4-4b: the selected character's active skills (empty for characters that
## have none yet — the HUD then shows no active buttons).
static func load_actives() -> Array[Dictionary]:
	var character_id: String = _character_id()
	var text: String = FileAccess.get_file_as_string(CHARACTERS_PATH)
	var data: Variant = JSON.parse_string(text)
	var actives: Array[Dictionary] = []
	if data is not Dictionary or not (data as Dictionary).has(character_id):
		push_error("player: cannot read '%s' from %s" % [character_id, CHARACTERS_PATH])
		return actives
	for entry: Variant in (data[character_id] as Dictionary).get("actives", []):
		if entry is Dictionary:
			actives.append(entry)
	return actives


static func _load_character_number(field: String) -> float:
	var character_id: String = _character_id()
	var text: String = FileAccess.get_file_as_string(CHARACTERS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary or not (data as Dictionary).has(character_id):
		push_error("player: cannot read '%s' from %s" % [character_id, CHARACTERS_PATH])
		return 0.0
	var character: Dictionary = data[character_id]
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
	_bonus_invuln_left = CombatMath.grace_tick(_bonus_invuln_left, delta)
	var move_input: Vector2 = joystick_input
	if move_input == Vector2.ZERO:
		move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = PlayerMotion.velocity_for(move_input, _speed)
	if velocity != Vector2.ZERO:
		last_move_direction = velocity.normalized()
	facing = PlayerMotion.facing_sign(velocity.x, facing)
	_visual.scale.x = float(facing)
	_update_animation()
	var invulnerable: bool = (
		_bonus_invuln_left > 0.0
		or not CombatMath.can_hit(_time_since_hit, _invuln_window)
	)
	_visual.modulate.a = INVULN_FLASH_ALPHA if invulnerable else 1.0
	move_and_slide()
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)


## N3-6 move-speed passive: rescale from the data base so stacks never compound.
func set_speed_scale(scale: float) -> void:
	_speed = load_move_speed() * scale


## N7-2 철피: scales every incoming hit; rescaled from 1.0 so it can never
## compound with itself across refreshes.
func set_damage_taken_scale(scale: float) -> void:
	_damage_taken_scale = clampf(scale, 0.0, 1.0)


## N7-2 긴 호흡: post-hit invulnerability window, rescaled from the data base.
func set_invuln_scale(scale: float) -> void:
	_invuln_window = load_hit_invuln_sec() * maxf(scale, 1.0)


## 축지 (N4-4b) and the N6-3 post-popup grace: a timed shield on top of the
## post-hit i-frames; repeats refresh, never shorten or stack. The same alpha
## flash telegraphs it.
func grant_invulnerability(duration: float) -> void:
	_bonus_invuln_left = CombatMath.grace_extend(_bonus_invuln_left, duration)


## Returns true when the hit landed; false while the invulnerability window
## from the previous hit is still open. `source_name` is the attacker's
## localized display name for killer attribution (N6-2).
func take_hit(damage: float, source_name: String = "") -> bool:
	if _bonus_invuln_left > 0.0:
		return false
	if not CombatMath.can_hit(_time_since_hit, _invuln_window):
		return false
	_time_since_hit = 0.0
	last_hit_source = source_name
	hp = CombatMath.apply_damage(hp, damage * _damage_taken_scale)
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
## without a SceneTree (same pattern as TitleScreen.build_ui). The actual
## strip slicing lives in SpriteSheet, shared with the monster path (N3-12).
static func build_sprite_frames() -> SpriteFrames:
	return SpriteSheet.build_frames(IDLE_TEXTURE_PATH, WALK_TEXTURE_PATH, WALK_FPS, IDLE_FPS)


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
