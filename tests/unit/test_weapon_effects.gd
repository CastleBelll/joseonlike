extends RefCounted
## Guards the N3-17 weapon-effect data contract and the pure chain-bolt
## geometry: every timing the visuals consume exists and is positive, and the
## bolt keeps its endpoints anchored while jittering only mid-bolt.


func test_config_has_every_field() -> bool:
	var config: Dictionary = WeaponEffects.config()
	var passed: bool = true
	# Same field list validate_data enforces — kept in the runtime helper's
	# terms so a renamed key fails here even before the validator runs.
	for field: String in [
		"explosion_ring_sec", "chain_bolt_sec", "chain_bolt_jitter_px",
		"arc_sweep_sec", "blade_trail_sec", "orbit_trail_sec", "ward_pulse_sec",
		"summon_strike_sec", "shockwave_ring_sec", "shockwave_nudge_px",
		"shockwave_nudge_sec", "curse_jump_sec", "status_flicker_hz",
		"blink_puff_sec", "screen_flash_sec",
	]:
		if WeaponEffects.value(field) <= 0.0:
			push_error("test_weapon_effects: missing or non-positive " + field)
			passed = false
	return passed and not config.is_empty()


func test_bolt_points_anchor_endpoints() -> bool:
	var from := Vector2(10.0, 20.0)
	var to := Vector2(110.0, 20.0)
	var noise: Array[float] = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0]
	var points := PackedVector2Array()
	points.resize(noise.size())
	ChainBolt.fill_bolt_points(points, from, to, 8.0, noise)
	var passed: bool = points[0].is_equal_approx(from)
	passed = passed and points[points.size() - 1].is_equal_approx(to)
	# Interior points stay on the segment axis within the jitter budget.
	for i: int in range(1, points.size() - 1):
		passed = passed and absf(points[i].y - from.y) <= 8.0
		passed = passed and absf(points[i].y - from.y) > 0.0
	if not passed:
		push_error("test_weapon_effects: bolt geometry broken")
	return passed
