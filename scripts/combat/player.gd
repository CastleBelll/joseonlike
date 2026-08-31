class_name Player
extends CharacterBody2D
## Stage player. Renders the AC-1 taoist sprite set (N3-2): right-facing idle
## frame plus a 4-frame walk strip, mirrored left through Visual.scale.x.

const CHARACTERS_PATH := "res://data/characters.json"

## N9-148: sprite sets are per-character now — characters.json carries a
## "sprite" directory per roster entry; taoist stays the fallback for data
## without one so a broken entry still renders a player.
const DEFAULT_SPRITE_DIR := "res://asset/characters/taoist"
## AC-1 export contract (asset/characters/taoist/README.md): PNGs are exact
## 16x nearest-neighbor blocks of 40x40 logical frames, figure 38px tall,
## which is the intended in-world read on the 540px viewport.
const SPRITE_EXPORT_SCALE := SpriteSheet.EXPORT_SCALE
## N9-37: the owner's run sheet ships sixteen frames (N9-134). SpriteSheet
## derives the count from the strip itself; this constant exists so a test can
## assert the art and the code still agree — which is exactly what caught the
## mismatch when the new sheet landed.
## Smallest cycle that still reads as movement. The real count comes from the
## sheet — the owner has shipped 16, 24 and 25 frame walks — so pinning a number
## here only breaks the suite on legitimate art, which is exactly what happened
## when the 5x5 re-set landed.
const WALK_FRAME_MIN := 8
## Doubled with the frame count so the 16-frame run keeps the 8-frame cadence.
const WALK_FPS := 16.0
## The idle is a sixteen-frame breath now, so this value stopped being inert:
## 8 fps gives one breath every two seconds, which is the cadence the sheets
## were drawn to (inhale over frames 1-8, exhale over 9-16).
const IDLE_FPS := 8.0
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
## Emitted when 그림자 걸음 turns a hit aside, so the HUD can say so.
signal dodged

var _invuln_window: float = 0.0
## N7-2 명부수: incoming-hit multiplier (철피) and invulnerability-window
## scale (긴 호흡), both set once by the stage from the capped meta aggregate.
const MAX_DODGE_CHANCE := 0.5

var _damage_taken_scale: float = 1.0
## N11-19c 그림자 걸음: the odds a hit is avoided outright.
var _dodge_chance: float = 0.0
var _time_since_hit: float = 0.0
var _bonus_invuln_left: float = 0.0  # granted by actives, on top of hit i-frames
## N9-148 철벽 guard: timed incoming-damage multiplier on top of the meta
## scale. 1.0 = no guard; the timer restores it.
var _guard_left: float = 0.0
var _guard_scale: float = 1.0
var _visual: Node2D
var _sprite: AnimatedSprite2D

signal died
## N3-8: fired on every landed hit so the HUD can pulse the damage vignette.
signal hit_taken


## The run starts with the profile's selected character (N2-1); node-free
## headless tests have no SaveService instance and fall back to the default.
## N11-20: the selected character, for callers outside the player node (the
## stage reads it to weight the run's build pool).
static func character_id() -> String:
	return _character_id()


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


## N9-5d weapon identity (GDD §3): the selected character's weapon
## categories — the level-up pool only offers NEW weapons from these.
## Empty (missing data) means no filter, never an empty pool.
static func load_weapon_categories() -> Array:
	var character_id: String = _character_id()
	var text: String = FileAccess.get_file_as_string(CHARACTERS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is not Dictionary or not (data as Dictionary).has(character_id):
		push_error("player: cannot read '%s' from %s" % [character_id, CHARACTERS_PATH])
		return []
	return (data[character_id] as Dictionary).get("weapon_categories", [])


## N10-12 기본 스킬: one permanent trait per character — 음양 widens every art,
## 철심 thins every hit, 보사 speeds every arrow. It is what makes a class read
## as a class before the first level-up card, and it is deliberately a stat the
## passive pool already uses, so nothing downstream has to learn a new concept.
static func load_innate(character_id: String = "") -> Dictionary:
	var id: String = character_id if not character_id.is_empty() else _character_id()
	var entry: Dictionary = _character_entry(id)
	var innate: Variant = entry.get("innate", {})
	return innate if innate is Dictionary else {}


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
	_guard_left = CombatMath.grace_tick(_guard_left, delta)
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
## N11-19c: the archer's dodge odds, clamped so no build becomes untouchable.
func set_dodge_chance(chance: float) -> void:
	_dodge_chance = clampf(chance, 0.0, MAX_DODGE_CHANCE)


func set_damage_taken_scale(scale: float) -> void:
	_damage_taken_scale = clampf(scale, 0.0, 1.0)


## N7-2 긴 호흡: post-hit invulnerability window, rescaled from the data base.
func set_invuln_scale(scale: float) -> void:
	_invuln_window = load_hit_invuln_sec() * maxf(scale, 1.0)


## N9-148 철벽: a timed incoming-damage reduction (guard), stacking
## multiplicatively with the permanent meta scale. Re-triggering refreshes
## rather than compounds — scale is absolute, never multiplied onto itself.
func grant_guard(duration_sec: float, scale: float) -> void:
	_guard_left = maxf(_guard_left, duration_sec)
	_guard_scale = clampf(scale, 0.0, 1.0)


## 축지 (N4-4b) and the 회생부 revive (N7-2): a timed shield on top of the
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
	# N11-19c 그림자 걸음: a roll to take no hit at all. The dodge still opens
	# the invulnerability window, so a dodged hit is not a free extra hit.
	if _dodge_chance > 0.0 and CombatRng.hits(_dodge_chance):
		_time_since_hit = 0.0
		dodged.emit()
		return false
	_time_since_hit = 0.0
	last_hit_source = source_name
	var guard: float = _guard_scale if _guard_left > 0.0 else 1.0
	hp = CombatMath.apply_damage(hp, damage * _damage_taken_scale * guard)
	hit_taken.emit()
	if CombatMath.is_dead(hp):
		died.emit()
	return true


## Owner (본거지에서만 걷고 출정은 뛰어야지): the split is by PLACE, not by how
## hard the stick is pushed. On a run you are being chased — nobody strolls
## through that — and the camp is the one place there is nothing to run from.
##
## Off by default so a scene that never says which it is gets the walk, which is
## the safe half: a walking character in combat reads as odd, a running one in
## the camp reads as broken.
var running: bool = false


func _update_animation() -> void:
	if velocity == Vector2.ZERO:
		_sprite.play(ANIM_IDLE)
		_sprite.speed_scale = 1.0
		return
	if running and _has_run():
		_sprite.play(SpriteSheet.ANIM_RUN)
		_sprite.speed_scale = 1.0
		return
	# Walking still follows travel speed, so easing off the stick in the camp
	# reads as slowing down rather than as a different animation.
	_sprite.play(ANIM_WALK)
	_sprite.speed_scale = velocity.length() / _speed if _speed > 0.0 else 1.0


func _has_run() -> bool:
	return _sprite.sprite_frames != null 		and _sprite.sprite_frames.has_animation(SpriteSheet.ANIM_RUN)


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
static func build_sprite_frames(character_id: String = "") -> SpriteFrames:
	var id: String = character_id if not character_id.is_empty() else _character_id()
	var entry: Dictionary = _character_entry(id)
	var sprite_dir: String = String(entry.get("sprite", DEFAULT_SPRITE_DIR))
	var frames: SpriteFrames = SpriteSheet.build_frames(
		SpriteSheet.strip_path(sprite_dir, SpriteSheet.IDLE_STRIP, "idle.png"),
		SpriteSheet.strip_path(sprite_dir, SpriteSheet.WALK_STRIP, "walk.png"),
		WALK_FPS, IDLE_FPS
	)
	# The owner split movement in two on 2026-08-27; without the art this is a
	# quiet no and the walk keeps doing both jobs.
	SpriteSheet.add_run(frames, sprite_dir, WALK_FPS)
	# N9-64 took the standing pose from the walk cycle because the separate idle
	# drawing read as a different character the moment the player stopped. That
	# is fixed at the source now: the breath sheet is generated FROM the idle
	# reference, so the standing pose and the walk agree, and idle.png carries a
	# real sixteen-frame breath. Overriding it here would throw that away.
	return frames


static func _character_entry(character_id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	if data is Dictionary and (data as Dictionary).has(character_id):
		return data[character_id]
	push_error("player: cannot read '%s' from %s" % [character_id, CHARACTERS_PATH])
	return {}


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
