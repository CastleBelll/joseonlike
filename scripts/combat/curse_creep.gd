class_name CurseCreep
extends Node2D
## Pooled 살 spread visual (N9-30). The curse used to borrow 뇌부's ChainBolt
## with a purple tint, so it read as lightning — a thing that STRIKES. A curse
## does not strike, it creeps: this draws a sagging thread of beads that crawls
## from the dying carrier to its new host, then blooms a mark where it lands.
##
## Geometry is pure static maths so the headless suite covers it, and the bead
## wobble array is reused across spreads, so a death that infects seven
## neighbours at max level allocates nothing per jump.

signal finished(creep: CurseCreep)

## Beads along the thread. Enough to read as a crawl, few enough to stay cheap
## when one death spreads to every neighbour in range.
const BEADS := 7
const BEAD_RADIUS := 3.2
const BEAD_MIN_SCALE := 0.45
const THREAD_WIDTH := 1.5
const THREAD_ALPHA := 0.5
## Share of the animation spent crawling; the rest blooms at the destination.
const BLOOM_START := 0.55
const BLOOM_RADIUS := 11.0
const FADE_TAIL := 0.34

var _age: float = 0.0
var _duration: float = 0.0
var _color: Color = UiPalette.WEAPON_CURSE
var _to := Vector2.ZERO
var _sag_px: float = 0.0
var _wobble: Array[float] = []


func _init() -> void:
	_wobble.resize(BEADS)


## Point `t` (0..1) along the creep path: a straight line pulled sideways by a
## sine sag, so the thread hangs and curls instead of running dead straight
## like a bolt. `wobble` nudges each bead a little off that curve.
## The sag is zero at both ends, so the thread stays anchored on both corpses
## no matter how far apart they are.
static func bead_point(
	from: Vector2, to: Vector2, t: float, sag_px: float, wobble: float
) -> Vector2:
	var span: Vector2 = to - from
	var perpendicular: Vector2 = span.orthogonal().normalized()
	return from + span * t + perpendicular * (sin(t * PI) * sag_px + wobble)


func show_creep(
	from: Vector2, to: Vector2, color: Color, duration: float, sag_px: float
) -> void:
	global_position = from
	_to = to - from
	_color = color
	_duration = maxf(duration, 0.01)
	_sag_px = sag_px * (1.0 if randf() < 0.5 else -1.0)  # curls either way
	_age = 0.0
	for i: int in range(_wobble.size()):
		_wobble[i] = randf_range(-1.5, 1.5)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		finished.emit(self)
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / _duration, 0.0, 1.0)
	# Fades over the last third so the thread lingers long enough to follow by
	# eye before it clears.
	var fade: float = 1.0 - maxf(progress - (1.0 - FADE_TAIL), 0.0) / FADE_TAIL
	var reached: int = 0
	var previous := Vector2.ZERO
	for i: int in range(BEADS):
		var t: float = float(i + 1) / float(BEADS)
		# A bead exists only once the crawl has passed it. That staggering IS
		# the difference between creeping and striking.
		if progress < t * BLOOM_START:
			break
		reached = i + 1
		var point: Vector2 = bead_point(Vector2.ZERO, _to, t, _sag_px, _wobble[i])
		var thread: Color = _color
		thread.a = THREAD_ALPHA * fade
		draw_line(previous, point, thread, THREAD_WIDTH)
		# Beads shrink toward the far end, so the thread reads directionally.
		var bead: Color = _color
		bead.a = fade
		draw_circle(point, BEAD_RADIUS * lerpf(1.0, BEAD_MIN_SCALE, t), bead)
		previous = point
	if reached < BEADS:
		return
	# Landed: the new host takes the mark. An expanding ring rather than a
	# flash, so it reads as something settling in, not as a hit.
	var bloom: float = clampf((progress - BLOOM_START) / (1.0 - BLOOM_START), 0.0, 1.0)
	var ring: Color = _color
	ring.a = (1.0 - bloom) * fade
	draw_arc(_to, BLOOM_RADIUS * bloom, 0.0, TAU, 16, ring, 2.0)
