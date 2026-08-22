class_name Ward
extends Node2D
## Persistent ground ward (결계, N4-4b GDD §11.1): enemies inside the circle
## take a damage tick and a slow every tick_sec until the lifetime runs out.
## Pooled by AutoWeapon (NodePool) — the pool disables processing while parked.
## All numbers come from the weapon's data "ward" block.

signal ticked(amount: float, at: Vector2, boss_hit: bool, crit: bool)
signal finished(ward: Ward)

## N9-71 rim flare: small sprites placed ON the ward's edge each time a tick
## lands. Native size, never stretched — a 46px sheet blown up to a 200px ward
## turns into an opaque band that hides the enemies standing in it, which is
## the one thing the player has to see (tried and reverted in N9-70).
const RIM_EFFECT := "hit_paper"
const RIM_FLARES := 6
const RIM_FLARE_PX := 26.0
const RIM_ALPHA := 0.9
const FILL_ALPHA := 0.1
const RING_WIDTH := 2.5
const RING_POINTS := 40
## N9-5c: the formation is the authored 부적진 texture (double ring, eight
## trigram clusters, center swirl), drawn in luminance and modulated by the
## ward color. It rotates with _spin; only the soft fill and the damage-tick
## pulse stay code-drawn.
const SIGIL_TEXTURE := "res://asset/weapon/fx/ward_sigil.png"
## N9-144: the ward now renders under the entities (DecorLayer), so the
## formation can be rich again — figures walk OVER the floor markings.
const SIGIL_ALPHA := 0.85
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
var _crit_chance: float = 0.0
var _crit_multiplier: float = 1.0
var _pulse_age: float = INF
var _caught: Array[Enemy] = []  # per-tick scratch, reused without alloc
var _positions: Array[Vector2] = []
var _sigil: Sprite2D
## N9-71: the rim flares, built once and reused for the ward's whole life.
var _rim_art: Array[EffectSprite] = []


func _ready() -> void:
	_sigil = Sprite2D.new()
	_sigil.name = "Sigil"
	_sigil.texture = load(SIGIL_TEXTURE)
	_sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sigil)


## (Re)arms a pooled instance; first tick lands on the next physics frame so
## dropping a ward on a pack bites immediately.
## N9-19: crit rolls per TICK (owner direction) — the ward is a slow drip,
## so a crit on a single tick reads as a spike, not a damage explosion.
func arm(
	at: Vector2,
	spawner: Spawner,
	ward_config: Dictionary,
	damage: float,
	status: Dictionary,
	color: Color,
	crit_chance: float = 0.0,
	crit_multiplier: float = 1.0
) -> void:
	global_position = at
	_spawner = spawner
	_crit_chance = crit_chance
	_crit_multiplier = crit_multiplier
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
	if _sigil != null:
		var native: float = maxf(_sigil.texture.get_width(), 1.0)
		_sigil.scale = Vector2.ONE * (_radius * 2.0 / native)
		_sigil.modulate = Color(_color, SIGIL_ALPHA)
		_sigil.rotation = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		finished.emit(self)
		return
	_spin += deg_to_rad(WeaponEffects.value("ward_spin_deg_s")) * delta
	if _sigil != null:
		_sigil.rotation = _spin
	queue_redraw()  # fill + pulse ring animate while live
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
		_flare_rim()
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
		# N9-19: one crit roll per enemy per tick.
		var tick_damage: float = _damage
		var crit: bool = _crit_chance > 0.0 and randf() < _crit_chance
		if crit:
			tick_damage *= _crit_multiplier
		enemy.take_damage(tick_damage)
		ticked.emit(tick_damage, at, boss_hit, crit)


## N9-71 (owner: the ward reads as thin). Six small flares around the rim on
## every tick that bites, spun a little each time so they never land on the
## same six spots twice.
##
## Placed at the TRUE radius, so the flare ring is the damage boundary rather
## than a decoration near it. They are pooled per ward and reused; a tick every
## half second across a long ward would otherwise allocate steadily.
func _flare_rim() -> void:
	if not EffectSprite.available(RIM_EFFECT) or _radius <= 0.0:
		return
	for i: int in range(RIM_FLARES):
		if i >= _rim_art.size():
			var sprite := EffectSprite.new()
			sprite.name = "Rim%d" % i
			add_child(sprite)
			_rim_art.append(sprite)
		var angle: float = _spin + TAU * float(i) / float(RIM_FLARES)
		_rim_art[i].play_effect(
			RIM_EFFECT, global_position + Vector2.from_angle(angle) * _radius,
			RIM_FLARE_PX, Color(_color, RIM_ALPHA)
		)
		_rim_art[i].global_position = (
			global_position + Vector2.from_angle(angle) * _radius
		)


## N9-5c 결계 look: the authored 부적진 texture (Sigil child) carries the
## formation; here only the soft interior fill and the N3-17 damage-tick
## pulse (a ring expanding to the edge) are code-drawn.
func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(_color, FILL_ALPHA))
	var pulse_sec: float = WeaponEffects.value("ward_pulse_sec")
	if _pulse_age >= pulse_sec or pulse_sec <= 0.0:
		return
	var progress: float = clampf(_pulse_age / pulse_sec, 0.0, 1.0)
	draw_arc(
		Vector2.ZERO, _radius * progress, 0.0, TAU, RING_POINTS,
		Color(_color, 1.0 - progress), RING_WIDTH * 1.5
	)
