class_name Ward
extends Node2D
## Persistent ground ward (결계, N4-4b GDD §11.1): enemies inside the circle
## take a damage tick and a slow every tick_sec until the lifetime runs out.
## Pooled by AutoWeapon (NodePool) — the pool disables processing while parked.
## All numbers come from the weapon's data "ward" block.

signal ticked(amount: float, at: Vector2, boss_hit: bool)
signal finished(ward: Ward)

const FILL_ALPHA := 0.1
const RING_WIDTH := 2.5
const RING_POINTS := 40
## N3-18 sigil look: dashed outer ring + an inner square frame rotated as a
## diamond (팔괘-style 진). Dash count and the inner ratio are style, the spin
## speed comes from data (weapon_effects.ward_spin_deg_s).
const DASH_COUNT := 12
## Lit share of each dash slot.
const DASH_FILL := 0.6
const SIGIL_RATIO := 0.62
const SIGIL_WIDTH := 2.0
const SIGIL_ALPHA := 0.7
## The slow must outlive the gap between ticks or enemies stutter-step;
## twice the tick keeps it seamless while ending soon after the ward does.
const SLOW_CARRY_SCALE := 2.0

var _spawner: Spawner
var _radius: float = 0.0
var _damage: float = 0.0
var _tick_sec: float = 0.0
var _slow_scale: float = 1.0
var _life_left: float = 0.0
var _tick_timer: float = 0.0
var _status: Dictionary = {}
var _color: Color = UiPalette.PAPER
## Accumulated spin phase (radians); advances every physics frame so the 진
## visibly rotates. Reset on (re)arm so pooled reuse never inherits a phase.
var _spin: float = 0.0
## N3-17: seconds since the last damage tick, drawn as an expanding pulse ring
## so the ward visibly "works" on every bite. Past the pulse window nothing
## redraws.
var _pulse_age: float = INF
var _caught: Array[Enemy] = []  # per-tick scratch, reused without alloc
var _positions: Array[Vector2] = []


## (Re)arms a pooled instance; first tick lands on the next physics frame so
## dropping a ward on a pack bites immediately.
func arm(
	at: Vector2,
	spawner: Spawner,
	ward_config: Dictionary,
	damage: float,
	status: Dictionary,
	color: Color
) -> void:
	global_position = at
	_spawner = spawner
	_radius = float(ward_config.get("radius_px", 0.0))
	_tick_sec = float(ward_config.get("tick_sec", 0.5))
	_slow_scale = float(ward_config.get("slow_scale", 1.0))
	_life_left = float(ward_config.get("duration_sec", 0.0))
	_damage = damage
	_status = status
	_color = color
	_tick_timer = 0.0
	_pulse_age = INF
	_spin = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		finished.emit(self)
		return
	_spin += deg_to_rad(WeaponEffects.value("ward_spin_deg_s")) * delta
	queue_redraw()  # the spinning sigil animates every frame while live
	var pulse_sec: float = WeaponEffects.value("ward_pulse_sec")
	if _pulse_age < pulse_sec:
		_pulse_age += delta
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer += _tick_sec
	_tick()


func _tick() -> void:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	_positions.clear()
	for enemy: Enemy in enemies:
		_positions.append(enemy.global_position)
	# Collect refs first: striking mutates the spawner's active list.
	_caught.clear()
	for i: int in WeaponMath.targets_in_radius(global_position, _positions, _radius):
		_caught.append(enemies[i])
	if not _caught.is_empty():
		_pulse_age = 0.0  # N3-17: a landed tick fires the visible pulse
	for enemy: Enemy in _caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		enemy.apply_shock(_slow_scale, _tick_sec * SLOW_CARRY_SCALE)
		if String(_status.get("id", "")) == "burn":
			enemy.apply_burn(
				float(_status.get("dps", 0.0)),
				float(_status.get("duration_sec", 0.0)),
				float(_status.get("spread_radius_px", 0.0))
			)
		var at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(_damage)
		ticked.emit(_damage, at, boss_hit)


## N3-18 결계 look: the N3-17 plain circle read as a debug range ring. Now a
## slowly rotating formation — dashed outer ring, counter-rotating inner
## diamond frame, soft fill — plus the N3-17 tick pulse (a ring expanding to
## the edge and fading over ward_pulse_sec after every landed damage tick).
## Still all palette-token code drawing; real ground-sigil art stays wanted in
## ASSET_REQUIREMENTS.md.
func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(_color, FILL_ALPHA))
	var slot: float = TAU / float(DASH_COUNT)
	for i: int in range(DASH_COUNT):
		var from: float = _spin + slot * float(i)
		draw_arc(
			Vector2.ZERO, _radius, from, from + slot * DASH_FILL, 6,
			_color, RING_WIDTH
		)
	_draw_sigil_square(-_spin)
	_draw_sigil_square(-_spin + TAU / 8.0)
	var pulse_sec: float = WeaponEffects.value("ward_pulse_sec")
	if _pulse_age >= pulse_sec or pulse_sec <= 0.0:
		return
	var progress: float = clampf(_pulse_age / pulse_sec, 0.0, 1.0)
	draw_arc(
		Vector2.ZERO, _radius * progress, 0.0, TAU, RING_POINTS,
		Color(_color, 1.0 - progress), RING_WIDTH * 1.5
	)


## One rotated square of the inner formation; two of them 45° apart make the
## eight-pointed 진 frame.
func _draw_sigil_square(phase: float) -> void:
	var reach: float = _radius * SIGIL_RATIO
	var color := Color(_color, SIGIL_ALPHA)
	for i: int in range(4):
		var a: Vector2 = Vector2.from_angle(phase + TAU * float(i) / 4.0) * reach
		var b: Vector2 = Vector2.from_angle(phase + TAU * float(i + 1) / 4.0) * reach
		draw_line(a, b, color, SIGIL_WIDTH)
