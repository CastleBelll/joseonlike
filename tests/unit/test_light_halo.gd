extends RefCounted
## N9-86: the light a fire draws must end where the rule that uses it ends.
##
## CombatMath.is_lit is a hard circle at `radius` — a shadow monster inside it
## can be hurt, outside it cannot. The shipped halo faded to alpha 0.0001 by
## 0.9R and to nothing past 0.7R, so a monster at 0.8R was damageable while
## looking like it stood in the dark. Nothing failed; the two simply disagreed.
## These tests make them agree.

## Alpha low enough to be indistinguishable from the unlit floor. The old curve
## sat two orders of magnitude under this at 0.9R.
const INVISIBLE := 0.02


func test_the_pool_is_still_visible_at_the_rules_edge() -> bool:
	var passed: bool = true
	for t: float in [0.8, 0.9, 0.95, 0.99]:
		var alpha: float = StageField.LightHalo.pool_alpha(t)
		if alpha <= INVISIBLE:
			push_error(
				"test_light_halo: %.2fR draws alpha %.5f, which reads as unlit"
				% [t, alpha]
			)
			passed = false
	return passed


## And it has to STOP there, or the pool would promise light where a shadow
## monster is safe.
func test_nothing_is_drawn_past_the_radius() -> bool:
	# Exactly 1.0 is still lit: is_lit compares with <=, so the boundary point
	# is one the rule damages and the pool has to show it.
	return (
		StageField.LightHalo.pool_alpha(1.0) > INVISIBLE
		and is_zero_approx(StageField.LightHalo.pool_alpha(1.001))
		and is_zero_approx(StageField.LightHalo.pool_alpha(1.2))
		and is_zero_approx(StageField.LightHalo.pool_alpha(-0.1))
	)


## Brightest at the fire, dimmest at the rim, never rising on the way out — a
## curve that bulged would read as a ring rather than a pool.
func test_the_pool_only_ever_dims_outward() -> bool:
	var previous: float = StageField.LightHalo.pool_alpha(0.0)
	if previous < 0.3:
		push_error("test_light_halo: the core lost its brightness (%.3f)" % previous)
		return false
	for step: int in range(1, 100):
		var alpha: float = StageField.LightHalo.pool_alpha(float(step) / 100.0)
		if alpha > previous:
			push_error("test_light_halo: alpha rises at %.2fR" % (float(step) / 100.0))
			return false
		previous = alpha
	return true


## The pair that must not drift: every point the pool paints is a point is_lit
## calls lit, and every point it leaves dark is one is_lit calls unlit.
func test_the_drawn_pool_and_the_damage_rule_cover_the_same_disc() -> bool:
	var lights: Array[Dictionary] = [{"position": Vector2.ZERO, "radius": 100.0}]
	var passed: bool = true
	for step: int in range(0, 130, 5):
		var point := Vector2(float(step), 0.0)
		var lit: bool = CombatMath.is_lit(point, lights)
		var drawn: bool = StageField.LightHalo.pool_alpha(float(step) / 100.0) > INVISIBLE
		if lit != drawn:
			push_error(
				"test_light_halo: at %dpx the rule says lit=%s but the pool says %s"
				% [step, str(lit), str(drawn)]
			)
			passed = false
	return passed
