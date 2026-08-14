class_name DeathPuff
extends Node2D
## Enemy death puff (N3-8): one pooled code-drawn ring that expands and fades.
## Particle-free by design; the stage reuses instances through NodePool, so a
## death never allocates. Timings come from data/effects.json.

signal finished(puff: DeathPuff)

const RING_WIDTH := 3.0

var _age: float = 0.0
var _duration: float = 0.0
var _radius: float = 0.0
var _color: Color = UiPalette.DEATH_PUFF


## `radius` is the enemy's contact radius scaled by death_puff_radius_scale.
## N4-4a reuses the same pooled ring as the 화부 explosion flash via `color`.
func puff(
	at: Vector2, radius: float, duration: float, color: Color = UiPalette.DEATH_PUFF
) -> void:
	global_position = at
	_radius = radius
	_duration = maxf(duration, 0.01)
	_age = 0.0
	_color = color
	modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		finished.emit(self)
		return
	modulate.a = 1.0 - _age / _duration
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / _duration, 0.0, 1.0)
	var ring_radius: float = _radius * progress
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 24, _color, RING_WIDTH)
	# A shrinking core disc keeps the puff readable at small radii.
	draw_circle(Vector2.ZERO, _radius * (1.0 - progress) * 0.5, _color)
