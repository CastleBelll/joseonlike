class_name EffectSprite
extends AnimatedSprite2D
## Pooled one-shot sprite effect (N3-17 art integration): plays one strip
## animation from asset/effect/ (square frames, NEAREST) scaled to a logical
## pixel size, then hides and reports done. Entries live in data/effects.json
## "sprite_effects" ({file, fps, logical_px}); frames are cached per effect id
## so pooled replays never rebuild atlas slices. A missing sheet keeps callers
## on their code-drawn fallback via available().

signal finished_effect(sprite: EffectSprite)

const ANIM := "fx"

static var _frames_cache: Dictionary = {}


## True when the effect has a data entry AND its sheet actually exists — the
## gate every caller checks before preferring the sprite over code drawing.
static func available(effect_id: String) -> bool:
	var config: Dictionary = WeaponEffects.sprite_config(effect_id)
	if config.is_empty():
		return false
	return ResourceLoader.exists(String(config.get("file", "")), "Texture2D")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(_on_animation_finished)


## Plays effect `effect_id` at `at`, scaled so the square frame spans
## `diameter_px` on screen (pass 0 to use the data logical_px), tinted by
## `tint` (WHITE keeps the sheet's own colors; desaturated sheets carry hue).
func play_effect(effect_id: String, at: Vector2, diameter_px: float, tint: Color) -> void:
	var config: Dictionary = WeaponEffects.sprite_config(effect_id)
	sprite_frames = _frames_for(effect_id, config)
	global_position = at
	var side: float = maxf(_frame_side(), 1.0)
	var span: float = diameter_px if diameter_px > 0.0 else float(config.get("logical_px", side))
	scale = Vector2.ONE * (span / side)
	modulate = tint
	visible = true
	play(ANIM)


func _on_animation_finished() -> void:
	visible = false
	finished_effect.emit(self)


func _frame_side() -> float:
	var texture: Texture2D = sprite_frames.get_frame_texture(ANIM, 0)
	return texture.get_size().y if texture != null else 0.0


static func _frames_for(effect_id: String, config: Dictionary) -> SpriteFrames:
	if _frames_cache.has(effect_id):
		return _frames_cache[effect_id]
	var frames := SpriteFrames.new()
	frames.rename_animation("default", ANIM)
	frames.set_animation_speed(ANIM, float(config.get("fps", 1.0)))
	frames.set_animation_loop(ANIM, false)
	var strip: Texture2D = load(String(config.get("file", "")))
	if strip == null:
		push_error("effect_sprite: cannot load sheet for " + effect_id)
	else:
		var side: float = strip.get_size().y
		for i: int in range(int(strip.get_size().x / side)):
			var frame := AtlasTexture.new()
			frame.atlas = strip
			frame.region = Rect2(Vector2(side * float(i), 0.0), Vector2(side, side))
			frames.add_frame(ANIM, frame)
	_frames_cache[effect_id] = frames
	return frames
