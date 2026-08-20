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

## N9-72 wavefront flares: small sprites ON the expanding rim, at native size.
## A single sheet stretched to a 200px blast becomes an opaque band that hides
## whatever is inside it (tried and reverted in N9-70); a scatter of authored-
## size marks says "the front is here" and hides nothing.
const FRONT_EFFECT := "hit_lightning"
const FRONT_FLARES := 7
const FRONT_FLARE_PX := 30.0
const FRONT_ALPHA := 0.85
const RIM_WIDTH_MAX := 5.0
const RIM_WIDTH_MIN := 1.5
const RIM_POINTS := 32
const FILL_ALPHA_MAX := 0.3
const CORE_ALPHA_MAX := 0.9
const CORE_RADIUS_SCALE := 0.4
## The core flash burns out inside the first slice of the duration; the rest
## of the animation is the expanding wave/smoke read.
const FLASH_PHASE := 0.35
const SPARK_COUNT := 10
## Sparks fly from the core out to this share of the blast radius.
const SPARK_REACH := 0.85
## N9-5d fireball tongues: per-tongue deterministic jitter (angle share of a
## slot, reach share, size share) so the blast reads as licking fire, not a
## perfect disc — fixed tables keep pooled redraws allocation-free.
const TONGUE_JITTER: Array[Vector3] = [
	Vector3(0.10, 0.94, 0.30), Vector3(0.62, 0.78, 0.42), Vector3(0.31, 0.99, 0.26),
	Vector3(0.85, 0.70, 0.36), Vector3(0.48, 0.88, 0.33), Vector3(0.05, 0.75, 0.44),
	Vector3(0.71, 0.96, 0.28), Vector3(0.24, 0.82, 0.38), Vector3(0.93, 0.90, 0.31),
	Vector3(0.55, 0.72, 0.40),
]
## Effect-local fire shades (rim/smoke); the hot heart keeps palette tokens.
const DEEP_RED := Color("#8c1f10")
const SMOKE := Color("#3a3028")
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
## N9-72: wavefront flares, built once and reused by this pooled ring.
var _front_art: Array[EffectSprite] = []


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
	if style == Style.WAVE:
		_flare_front()
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


## N9-72 (owner: 진언 reads as thin). Marks scattered around the wave's own
## radius when it fires. Only for WAVE — an explosion already has its fire fill
## and core, and adding sparks there would just be noise on top of noise.
##
## The angles are offset by the blast's position so two shockwaves in the same
## place do not print identical rings.
func _flare_front() -> void:
	if not EffectSprite.available(FRONT_EFFECT) or _radius <= 0.0:
		return
	var phase: float = global_position.angle()
	for i: int in range(FRONT_FLARES):
		if i >= _front_art.size():
			var sprite := EffectSprite.new()
			sprite.name = "Front%d" % i
			add_child(sprite)
			_front_art.append(sprite)
		var angle: float = phase + TAU * float(i) / float(FRONT_FLARES)
		var at: Vector2 = global_position + Vector2.from_angle(angle) * _radius
		_front_art[i].play_effect(
			FRONT_EFFECT, at, FRONT_FLARE_PX, Color(_color, FRONT_ALPHA)
		)
		_front_art[i].global_position = at
		_front_art[i].rotation = angle


## Ease-out expansion: fast opening, soft landing at the true blast radius so
## the visual edge matches where the damage actually reached.
func _eased_reach(progress: float) -> float:
	return _radius * (1.0 - (1.0 - progress) * (1.0 - progress))


## N9-5d fireball (owner report: the flat disc + perfect ring read as a
## debug circle, not a detonation): irregular flame tongues in three fire
## layers (deep-red rim, weapon-color body, gold heart) ride the blast
## front, the disc fill turns to smoke as it fades, and the rim breaks
## into short arcs instead of one perfect circle. The damage edge still
## lands exactly on the data radius via the tongue reach cap.
func _draw_explosion(progress: float) -> void:
	var reach: float = _eased_reach(progress)
	var fade: float = 1.0 - progress
	# Interior: fire fill early, cooling into smoke as the burst ages.
	var interior: Color = _color.lerp(SMOKE, progress)
	draw_circle(Vector2.ZERO, reach * 0.92, Color(interior, FILL_ALPHA_MAX * fade))
	# Flame tongues on the blast front — deterministic jitter per tongue.
	var slot: float = TAU / float(TONGUE_JITTER.size())
	for i: int in range(TONGUE_JITTER.size()):
		var jitter: Vector3 = TONGUE_JITTER[i]
		var angle: float = slot * (float(i) + jitter.x)
		var at: Vector2 = Vector2.from_angle(angle) * reach * jitter.y
		var size: float = _radius * jitter.z * (0.5 + 0.5 * fade)
		draw_circle(at, size, Color(DEEP_RED, 0.85 * fade))
		draw_circle(at, size * 0.62, Color(_color, fade))
		draw_circle(at, size * 0.3, Color(UiPalette.GOLD, fade))
	# Broken rim: short arcs at the true blast radius, gaps between them.
	var rim_width: float = lerpf(RIM_WIDTH_MAX, RIM_WIDTH_MIN, progress)
	for i: int in range(SPARK_COUNT):
		var from: float = TAU * float(i) / float(SPARK_COUNT)
		draw_arc(
			Vector2.ZERO, reach, from, from + TAU / float(SPARK_COUNT) * 0.55,
			6, Color(DEEP_RED, fade), rim_width
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
	# Ember sparks riding the blast front toward the edge.
	var spark_px: float = WeaponEffects.value("explosion_spark_px")
	for i: int in range(SPARK_COUNT):
		var jitter: Vector3 = TONGUE_JITTER[i]
		var angle: float = TAU * (float(i) + jitter.x * 0.8) / float(SPARK_COUNT)
		var spark_at: Vector2 = Vector2.from_angle(angle) * reach * SPARK_REACH * jitter.y
		draw_circle(spark_at, spark_px * fade * (0.7 + jitter.z), Color(UiPalette.GOLD, fade))


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
