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

var _age: float = 0.0
var _duration: float = 0.0
var _color: Color = UiPalette.WEAPON_LIGHTNING
var _points: PackedVector2Array = PackedVector2Array()
var _noise: Array[float] = []


func _init() -> void:
	_points.resize(SEGMENTS + 1)
	_noise.resize(SEGMENTS + 1)


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
	from: Vector2, to: Vector2, color: Color, duration: float, jitter_px: float
) -> void:
	global_position = from
	_color = color
	_duration = maxf(duration, 0.01)
	_age = 0.0
	for i: int in range(_noise.size()):
		_noise[i] = randf_range(-1.0, 1.0)
	fill_bolt_points(_points, Vector2.ZERO, to - from, jitter_px, _noise)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		finished.emit(self)
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / _duration, 0.0, 1.0)
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
