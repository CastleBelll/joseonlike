class_name ChainBolt
extends Node2D
## Pooled lightning-jump visual (N3-17): a jagged, tapering polyline drawn
## between two hit points for a few frames. Serves the 뇌부 chain jump and the
## 살 death-spread jump — the caller picks the palette token. Geometry is a
## pure static function so the headless suite covers it; the per-segment
## noise array is reused across arms (no per-hit allocation).

signal finished(bolt: ChainBolt)

const SEGMENTS := 6
## Tip keeps this share of the root width (weapon_effects.chain_bolt_width_px).
const TIP_WIDTH_SCALE := 0.3
const CORE_WIDTH_SCALE := 0.4
const CORE_ALPHA := 0.9

## N9-116 (owner sheet): four authored bolt-body patterns, each a horizontal
## strip of BOLT_ART_FRAMES cells, stretched between the two chained enemies.
## A missing file keeps that slot on the code-drawn polyline — art never
## blocks the weapon.
const BOLT_ART: Array[String] = [
	"res://asset/weapon/fx/chain_bolt_a.png", "res://asset/weapon/fx/chain_bolt_b.png",
	"res://asset/weapon/fx/chain_bolt_c.png", "res://asset/weapon/fx/chain_bolt_d.png",
]
const BOLT_ART_FRAMES := 4

static var _art_cache: Array[Texture2D] = []

var _age: float = 0.0
var _duration: float = 0.0
var _color: Color = UiPalette.WEAPON_LIGHTNING
var _points: PackedVector2Array = PackedVector2Array()
var _noise: Array[float] = []
var _texture: Texture2D = null
var _target_local := Vector2.ZERO


func _init() -> void:
	_points.resize(SEGMENTS + 1)
	_noise.resize(SEGMENTS + 1)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The strip frame for a bolt `progress` of the way through its life: plays
## once across the duration, clamped so the last frame holds to the end.
static func bolt_frame(progress: float, frames: int) -> int:
	return clampi(int(progress * float(frames)), 0, frames - 1)


static func _pick_art() -> Texture2D:
	if _art_cache.is_empty():
		for path: String in BOLT_ART:
			var texture: Texture2D = load(path) if ResourceLoader.exists(path, "Texture2D") else null
			if texture != null:
				_art_cache.append(texture)
		if _art_cache.is_empty():
			return null
	return _art_cache[randi() % _art_cache.size()]


## Local-space bolt vertices from `from` toward `to`, written into `points`
## in place (pre-sized by the caller — no per-hit allocation): endpoints
## exact, interior points pushed perpendicular by noise[i] (in [-1, 1]) scaled
## by jitter_px and tapered toward both ends so the bolt roots stay anchored
## on the enemies.
static func fill_bolt_points(
	points: PackedVector2Array, from: Vector2, to: Vector2,
	jitter_px: float, noise: Array[float]
) -> void:
	var count: int = mini(points.size(), noise.size())
	var perpendicular: Vector2 = (to - from).orthogonal().normalized()
	for i: int in range(count):
		var t: float = float(i) / float(maxi(count - 1, 1))
		var taper: float = sin(t * PI)  # 0 at both ends, 1 mid-bolt
		points[i] = from + (to - from) * t + perpendicular * (noise[i] * jitter_px * taper)


func show_bolt(
	from: Vector2, to: Vector2, color: Color, duration: float, jitter_px: float,
	use_art: bool = false
) -> void:
	global_position = from
	_color = color
	_duration = maxf(duration, 0.01)
	_age = 0.0
	_target_local = to - from
	_texture = _pick_art() if use_art else null
	if _texture == null:
		for i: int in range(_noise.size()):
			_noise[i] = randf_range(-1.0, 1.0)
		fill_bolt_points(_points, Vector2.ZERO, _target_local, jitter_px, _noise)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		finished.emit(self)
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / _duration, 0.0, 1.0)
	if _texture != null:
		# Authored body: one pattern strip stretched root-to-target; the four
		# frames carry the flicker-and-decay, so no alpha fade on top.
		var frame_w: float = _texture.get_width() / float(BOLT_ART_FRAMES)
		var frame_h: float = float(_texture.get_height())
		var length: float = _target_local.length()
		if length < 1.0:
			return
		var frame: int = bolt_frame(_age / _duration, BOLT_ART_FRAMES)
		draw_set_transform(Vector2.ZERO, _target_local.angle(), Vector2(length / frame_w, 1.0))
		draw_texture_rect_region(
			_texture,
			Rect2(Vector2(0.0, -frame_h / 2.0), Vector2(frame_w, frame_h)),
			Rect2(Vector2(frame_w * float(frame), 0.0), Vector2(frame_w, frame_h))
		)
		return
	# N3-18: root width from data — the 3.5px N3-17 bolt vanished at 540x960.
	var width_root: float = WeaponEffects.value("chain_bolt_width_px")
	for i: int in range(_points.size() - 1):
		var t: float = float(i) / float(_points.size() - 1)
		var width: float = lerpf(width_root, width_root * TIP_WIDTH_SCALE, t)
		draw_line(_points[i], _points[i + 1], Color(_color, fade), width)
		draw_line(
			_points[i], _points[i + 1],
			Color(UiPalette.LOOT_CORE, CORE_ALPHA * fade), width * CORE_WIDTH_SCALE
		)
