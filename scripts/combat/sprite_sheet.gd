class_name SpriteSheet
extends RefCounted
## Shared idle/walk SpriteFrames builder for the 16x NEAREST character exports
## (player N3-2, monsters N3-12). Every strip frame is square, so the frame
## count is simply width / height; a single-frame texture is used as-is.

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
## Export contract (asset/*/README.md): PNGs are exact 16x nearest-neighbor
## blocks of the logical frames, downscaled back in-engine via sprite scale.
const EXPORT_SCALE := 16.0


static func build_frames(
	idle_path: String, walk_path: String, walk_fps: float, idle_fps: float
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.rename_animation("default", ANIM_IDLE)
	frames.set_animation_speed(ANIM_IDLE, idle_fps)
	_add_strip_frames(frames, ANIM_IDLE, idle_path)
	frames.add_animation(ANIM_WALK)
	frames.set_animation_speed(ANIM_WALK, walk_fps)
	_add_strip_frames(frames, ANIM_WALK, walk_path)
	return frames


static func _add_strip_frames(frames: SpriteFrames, anim: String, path: String) -> void:
	var strip: Texture2D = load(path)
	if strip == null:
		push_error("sprite_sheet: cannot load " + path)
		return
	var side: float = strip.get_size().y
	var count: int = int(strip.get_size().x / side)
	if count <= 1:
		frames.add_frame(anim, strip)
		return
	for i: int in range(count):
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(Vector2(side * float(i), 0.0), Vector2(side, side))
		frames.add_frame(anim, frame)
