class_name Ward
extends Node2D
## Persistent ground ward (결계, N4-4b GDD §11.1): enemies inside the circle
## take a damage tick and a slow every tick_sec until the lifetime runs out.
## Pooled by AutoWeapon (NodePool) — the pool disables processing while parked.
## All numbers come from the weapon's data "ward" block.

signal ticked(amount: float, at: Vector2, boss_hit: bool)
signal finished(ward: Ward)

const FILL_ALPHA := 0.14
const RING_WIDTH := 2.0
const RING_POINTS := 40
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
	queue_redraw()


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		finished.emit(self)
		return
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


## Placeholder art: translucent tinted disc with a solid ring (palette token
## via the weapon tint; real art registered in ASSET_REQUIREMENTS.md).
func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(_color, FILL_ALPHA))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, RING_POINTS, _color, RING_WIDTH)
