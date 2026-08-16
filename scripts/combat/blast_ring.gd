class_name BlastRing
extends Node2D
## Pooled radial burst visual (N3-17, reworked N3-18): two styles sharing one
## pooled node. STYLE_EXPLOSION (화부) opens a hot core flash, expands a filled
## disc whose rim lands exactly on the true blast radius, and throws ember
## sparks to the edge so the covered area reads as fire. STYLE_WAVE (진언 pulse,
## 벽사진 burst) is a clean double ring with no fill — a control wave, not a
## detonation. Colors are palette tokens passed by the caller; durations and
## spark size come from data/effects.json (weapon_effects).

signal finished(ring: BlastRing)

enum Style { EXPLOSION, WAVE }

const RIM_WIDTH_MAX := 5.0
const RIM_WIDTH_MIN := 1.5
const RIM_POINTS := 32
const FILL_ALPHA_MAX := 0.3
const CORE_ALPHA_MAX := 0.9
const CORE_RADIUS_SCALE := 0.4
## The core flash burns out inside the first slice of the duration; the rest
## of the animation is the expanding wave/smoke read.
const FLASH_PHASE := 0.35
const SPARK_COUNT := 8
## Sparks fly from the core out to this share of the blast radius.
const SPARK_REACH := 0.85
const WAVE_RIM_WIDTH_MAX := 6.0
const WAVE_RIM_WIDTH_MIN := 2.0
## The trailing second ring of a wave follows at this share of the lead ring.
const WAVE_TRAIL_SCALE := 0.62
const WAVE_TRAIL_ALPHA := 0.5

var _age: float = 0.0
var _duration: float = 0.0
var _radius: float = 0.0
var _color: Color = UiPalette.WEAPON_FIRE
var _style: Style = Style.EXPLOSION


func burst(
	at: Vector2, radius: float, duration: float, color: Color,
	style: Style = Style.EXPLOSION
) -> void:
	global_position = at
	_radius = radius
	_duration = maxf(duration, 0.01)
	_age = 0.0
	_color = color
	_style = style
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		finished.emit(self)
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / _duration, 0.0, 1.0)
	if _style == Style.WAVE:
		_draw_wave(progress)
	else:
		_draw_explosion(progress)


## Ease-out expansion: fast opening, soft landing at the true blast radius so
## the visual edge matches where the damage actually reached.
func _eased_reach(progress: float) -> float:
	return _radius * (1.0 - (1.0 - progress) * (1.0 - progress))


func _draw_explosion(progress: float) -> void:
	var reach: float = _eased_reach(progress)
	var fade: float = 1.0 - progress
	draw_circle(Vector2.ZERO, reach, Color(_color, FILL_ALPHA_MAX * fade))
	draw_arc(
		Vector2.ZERO, reach, 0.0, TAU, RIM_POINTS, Color(_color, fade),
		lerpf(RIM_WIDTH_MAX, RIM_WIDTH_MIN, progress)
	)
	# Hot flash phase: a white-gold core that sells the detonation, gone early
	# so the lingering read is the covered area, not a bright blob.
	if progress < FLASH_PHASE:
		var flash_fade: float = 1.0 - progress / FLASH_PHASE
		draw_circle(
			Vector2.ZERO, _radius * CORE_RADIUS_SCALE * flash_fade,
			Color(UiPalette.GOLD, CORE_ALPHA_MAX * flash_fade)
		)
		draw_circle(
			Vector2.ZERO, _radius * CORE_RADIUS_SCALE * 0.5 * flash_fade,
			Color(UiPalette.LOOT_CORE, CORE_ALPHA_MAX * flash_fade)
		)
	# Ember sparks riding the blast front toward the edge. Fixed angles keep
	# the draw deterministic and allocation-free on pooled reuse.
	var spark_px: float = WeaponEffects.value("explosion_spark_px")
	for i: int in range(SPARK_COUNT):
		var angle: float = TAU * float(i) / float(SPARK_COUNT)
		var spark_at: Vector2 = Vector2.from_angle(angle) * reach * SPARK_REACH
		draw_circle(spark_at, spark_px * fade, Color(UiPalette.GOLD, fade))


func _draw_wave(progress: float) -> void:
	var reach: float = _eased_reach(progress)
	var fade: float = 1.0 - progress
	var width: float = lerpf(WAVE_RIM_WIDTH_MAX, WAVE_RIM_WIDTH_MIN, progress)
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, RIM_POINTS, Color(_color, fade), width)
	draw_arc(
		Vector2.ZERO, reach, 0.0, TAU, RIM_POINTS,
		Color(UiPalette.LOOT_CORE, 0.7 * fade), width * 0.4
	)
	# A trailing inner ring gives the pulse depth without filling the disc —
	# enemies inside stay fully readable.
	draw_arc(
		Vector2.ZERO, reach * WAVE_TRAIL_SCALE, 0.0, TAU, RIM_POINTS,
		Color(_color, WAVE_TRAIL_ALPHA * fade), width * 0.6
	)
