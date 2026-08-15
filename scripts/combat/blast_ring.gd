class_name BlastRing
extends Node2D
## Pooled explosion/shockwave visual (N3-17): a hot core that collapses while
## a filled disc and its rim ring expand to the blast radius and fade. Poolable
## via NodePool like DeathPuff; colors are palette tokens passed by the caller,
## duration comes from data/effects.json (weapon_effects).

signal finished(ring: BlastRing)

const RIM_WIDTH_MAX := 5.0
const RIM_WIDTH_MIN := 1.5
const RIM_POINTS := 32
const FILL_ALPHA_MAX := 0.3
const CORE_ALPHA_MAX := 0.85
const CORE_RADIUS_SCALE := 0.35

var _age: float = 0.0
var _duration: float = 0.0
var _radius: float = 0.0
var _color: Color = UiPalette.WEAPON_FIRE


func burst(at: Vector2, radius: float, duration: float, color: Color) -> void:
	global_position = at
	_radius = radius
	_duration = maxf(duration, 0.01)
	_age = 0.0
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		finished.emit(self)
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / _duration, 0.0, 1.0)
	# Ease-out expansion: fast opening, soft landing at the true blast radius
	# so the visual edge matches where the damage actually reached.
	var reach: float = _radius * (1.0 - (1.0 - progress) * (1.0 - progress))
	var fade: float = 1.0 - progress
	draw_circle(Vector2.ZERO, reach, Color(_color, FILL_ALPHA_MAX * fade))
	draw_arc(
		Vector2.ZERO, reach, 0.0, TAU, RIM_POINTS, Color(_color, fade),
		lerpf(RIM_WIDTH_MAX, RIM_WIDTH_MIN, progress)
	)
	# The collapsing white-hot core sells the detonation in the first frames.
	draw_circle(
		Vector2.ZERO, _radius * CORE_RADIUS_SCALE * fade,
		Color(UiPalette.LOOT_CORE, CORE_ALPHA_MAX * fade)
	)
