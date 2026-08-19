class_name BossTelegraph
extends Node2D
## Pooled boss-attack telegraph (N9-49): a warning shape that fills over
## `warn_sec`, then erupts and reports the area it actually covered.
##
## One node serves both of 두두리's patterns — a filled disc for 뿌리 솟구침 and
## a band for 목랑의 진노 — because the honest requirement is identical for
## both: what the player sees during the warning has to be exactly what the
## eruption hits. Drawing both from the same numbers is how that stays true
## when either pattern is retuned.
##
## The node only draws and times. The stage applies the damage, in one place,
## the same way it owns every other pool.

## Fired once when the warning completes. The stage decides who is inside.
signal erupted(at: Vector2, radius: float, inner: float)
signal finished(telegraph: BossTelegraph)

## The brief flash of the eruption itself, after the warning fills.
const BURST_SEC := 0.22
const WARN_FILL_ALPHA := 0.22
const WARN_EDGE_ALPHA := 0.7
const EDGE_WIDTH := 2.0
const BURST_ALPHA := 0.55
const ARC_POINTS := 32

var _radius: float = 0.0
## Inner radius for a band; zero for a filled disc.
var _inner: float = 0.0
var _warn_sec: float = 0.0
var _age: float = 0.0
var _erupted: bool = false
var _color: Color = UiPalette.VERMILION


func warn(
	at: Vector2, radius: float, inner: float, warn_sec: float, color: Color
) -> void:
	global_position = at
	_radius = maxf(radius, 1.0)
	_inner = clampf(inner, 0.0, _radius - 1.0)
	_warn_sec = maxf(warn_sec, 0.05)
	_age = 0.0
	_erupted = false
	_color = color
	visible = true
	queue_redraw()


## True while this telegraph is warning about a band (a ring that spares the
## middle) rather than a filled disc.
func is_band() -> bool:
	return _inner > 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if not _erupted and _age >= _warn_sec:
		_erupted = true
		erupted.emit(global_position, _radius, _inner)
	if _age >= _warn_sec + BURST_SEC:
		visible = false
		finished.emit(self)
		return
	queue_redraw()


func _draw() -> void:
	if _erupted:
		_draw_burst()
		return
	# The fill grows over the warning so the eye can read how much time is
	# left, while the OUTLINE sits on the true edge from the very first frame —
	# the player has to be able to judge the real area immediately, not once
	# the fill catches up to it.
	var progress: float = clampf(_age / _warn_sec, 0.0, 1.0)
	if _inner <= 0.0:
		draw_circle(Vector2.ZERO, _radius * progress, Color(_color, WARN_FILL_ALPHA))
	else:
		var band: float = (_radius - _inner) * progress
		draw_arc(
			Vector2.ZERO, (_inner + _radius) / 2.0, 0.0, TAU, ARC_POINTS,
			Color(_color, WARN_FILL_ALPHA), maxf(band, 1.0)
		)
		draw_arc(
			Vector2.ZERO, _inner, 0.0, TAU, ARC_POINTS,
			Color(_color, WARN_EDGE_ALPHA), EDGE_WIDTH
		)
	draw_arc(
		Vector2.ZERO, _radius, 0.0, TAU, ARC_POINTS,
		Color(_color, WARN_EDGE_ALPHA), EDGE_WIDTH
	)


func _draw_burst() -> void:
	var fade: float = 1.0 - clampf((_age - _warn_sec) / BURST_SEC, 0.0, 1.0)
	var burst := Color(_color, BURST_ALPHA * fade)
	if _inner <= 0.0:
		draw_circle(Vector2.ZERO, _radius, burst)
		return
	draw_arc(
		Vector2.ZERO, (_inner + _radius) / 2.0, 0.0, TAU, ARC_POINTS,
		burst, maxf(_radius - _inner, 1.0)
	)
