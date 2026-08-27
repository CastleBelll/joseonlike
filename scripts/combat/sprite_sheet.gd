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

## The widest texture the renderer will accept. project.godot runs
## gl_compatibility on desktop AND mobile, and GLES3 refuses anything past this
## with a driver-level "Condition p_width > 16384 is true" and a backtrace that
## names load(), not the sheet. QA (auto, b735bc0 B1) traced one that way:
## dudueori/walk.png at 24320x1520, sixteen 1520px frames in a row.
##
## The guard does not repair the sheet — it names the file, the number and the
## fix, so the next person reads a sentence instead of a driver assertion.
const MAX_STRIP_PX := 16384

## N10-13 (owner: 산출물을 같은 이름으로 저장하지마 ... 너 때매 덮어씌워져서 다시
## 받아왔잖아). Built strips live in their own folder under their own names. The
## owner's drops keep `idle.png` / `walk.png` / `breath.png` in the sprite
## directory and no tool may write there: the bake used to save over `walk.png`,
## and over `breath.png` as `idle.png`, which destroyed the originals and cost
## the owner a re-download of every sheet.
const BUILD_DIR := "build"
const IDLE_STRIP := "idle_strip.png"
const WALK_STRIP := "walk_strip.png"


## The file an animation actually loads from: the built strip when one exists,
## otherwise the legacy drop-in-place name. The fallback is what lets art
## migrate one entity at a time instead of in a single flag day.
static func strip_path(sprite_dir: String, built: String, legacy: String) -> String:
	var path: String = sprite_dir.path_join(BUILD_DIR).path_join(built)
	if ResourceLoader.exists(path):
		return path
	return sprite_dir.path_join(legacy)


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


## N9-38: one looping animation from a single strip, for effect sprites that
## have no idle/walk split (the 혼불 wisp). Same strip contract as the
## character sheets — square frames, count = width / height.
static func loop_frames(path: String, fps: float, anim: String = ANIM_IDLE) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.rename_animation("default", anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	_add_strip_frames(frames, anim, path)
	return frames


## Replaces an already-built idle animation with ONE frame taken from a walk
## strip. Some sheets have a separate idle drawing that does not sit well beside
## its own walk cycle — a pose from the cycle is guaranteed to match it, because
## it came from it.
##
## Out-of-range indices are clamped rather than rejected: a bad number should
## show the wrong pose, never no character at all.
static func idle_from_strip(frames: SpriteFrames, path: String, index: int) -> void:
	var strip: Texture2D = load(path)
	if strip == null:
		push_error("sprite_sheet: cannot load " + path)
		return
	var side: float = strip.get_size().y
	var count: int = maxi(int(strip.get_size().x / side), 1)
	frames.clear(ANIM_IDLE)
	var frame := AtlasTexture.new()
	frame.atlas = strip
	frame.region = Rect2(
		Vector2(side * float(clampi(index, 0, count - 1)), 0.0), Vector2(side, side)
	)
	frames.add_frame(ANIM_IDLE, frame)


static func _add_strip_frames(frames: SpriteFrames, anim: String, path: String) -> void:
	var strip: Texture2D = load(path)
	if strip == null:
		push_error("sprite_sheet: cannot load " + path)
		return
	var side: float = strip.get_size().y
	var count: int = int(strip.get_size().x / side)
	if strip.get_size().x > float(MAX_STRIP_PX):
		# Only the frames inside the limit are addressable; the rest of the
		# texture never reached the GPU. A short cycle beats no character.
		var fits: int = maxi(int(float(MAX_STRIP_PX) / side), 1)
		push_warning(
			"sprite_sheet: %s is %dpx wide, past the %dpx texture limit — using %d of %d frames. Re-export at %d frames or smaller cells."
			% [path, int(strip.get_size().x), MAX_STRIP_PX, fits, count, fits]
		)
		count = fits
	if count <= 1:
		frames.add_frame(anim, strip)
		return
	for i: int in range(count):
		var frame := AtlasTexture.new()
		frame.atlas = strip
		frame.region = Rect2(Vector2(side * float(i), 0.0), Vector2(side, side))
		frames.add_frame(anim, frame)
