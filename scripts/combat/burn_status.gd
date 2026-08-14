class_name BurnStatus
extends RefCounted
## Pure burn damage-over-time state (GDD v2 section 11, the fire talisman
## line). Autoload-free (see CombatMath) so the headless runner can test the
## tick arithmetic without a scene tree; the enemy owns when the returned
## damage is actually applied.

## Damage is released in chunks, not per frame: a per-frame take_damage call
## would replay the hit audio and flash sixty times a second.
const TICK_SEC: float = 0.5


var dps: float = 0.0
var left_sec: float = 0.0

var _pending_damage: float = 0.0
var _since_tick_sec: float = 0.0


## Re-application refreshes rather than stacks: the strongest burn wins on
## damage and the longest on duration, so two sources cannot multiply.
func apply(new_dps: float, duration_sec: float) -> void:
	if new_dps <= 0.0 or duration_sec <= 0.0:
		return
	dps = maxf(dps, new_dps)
	left_sec = maxf(left_sec, duration_sec)


func is_active() -> bool:
	return left_sec > 0.0 and dps > 0.0


## Advances the clock and returns the damage due this step — 0.0 between
## ticks, a chunk on each TICK_SEC boundary, and the remainder when the burn
## expires mid-interval.
func advance(delta: float) -> float:
	if not is_active() or delta <= 0.0:
		return 0.0

	var burning_sec: float = minf(delta, left_sec)
	left_sec -= delta
	_pending_damage += dps * burning_sec
	_since_tick_sec += delta

	if _since_tick_sec < TICK_SEC and left_sec > 0.0:
		return 0.0

	_since_tick_sec = 0.0
	var due: float = _pending_damage
	_pending_damage = 0.0
	if left_sec <= 0.0:
		dps = 0.0
	return due
