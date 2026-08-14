class_name ActiveSkill
extends RefCounted
## Pure math for the player-triggered actives (N4-4b, GDD §11.1): blink
## destination clamping and cooldown display fractions. Node-free so the
## headless suite drives it directly; the stage consumes the same functions.
## Cooldown gating itself reuses CombatMath.can_hit — one window rule
## everywhere.


## 축지 blink destination: travel `distance` along `direction`, stopped early
## at `blocked_at` (distance to the first solid prop on the path, INF when
## clear) and clamped into the field bounds. A zero-size bounds means
## unclamped, same contract as Player.bounds.
static func blink_destination(
	from: Vector2, direction: Vector2, distance: float, blocked_at: float, bounds: Rect2
) -> Vector2:
	if direction == Vector2.ZERO:
		return from
	var travel: float = minf(distance, maxf(blocked_at, 0.0))
	var destination: Vector2 = from + direction.normalized() * travel
	if bounds.has_area():
		destination = destination.clamp(bounds.position, bounds.end)
	return destination


## Remaining-cooldown fraction for the HUD button fill: 1.0 = just used,
## 0.0 = ready. Total <= 0 counts as always ready.
static func cooldown_fraction(left_sec: float, total_sec: float) -> float:
	if total_sec <= 0.0:
		return 0.0
	return clampf(left_sec / total_sec, 0.0, 1.0)
