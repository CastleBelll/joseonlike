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
		"explosion_ring_sec", "explosion_spark_px", "chain_bolt_sec",
		"chain_bolt_jitter_px", "chain_bolt_width_px", "chain_first_leg_px",
		"arc_sweep_sec", "blade_trail_sec", "paper_width_px", "paper_length_px",
		"paper_trail_sec", "blade_width_px", "blade_length_px", "orbit_trail_sec",
		"ward_pulse_sec", "ward_spin_deg_s", "summon_strike_sec",
		"summon_strike_px", "shockwave_ring_sec", "shockwave_nudge_px",
		"shockwave_nudge_sec", "curse_jump_sec", "status_flicker_hz",
		"blink_puff_sec", "screen_flash_sec", "burst_ring_sec",
	]:
		if WeaponEffects.value(field) <= 0.0:
			push_error("test_weapon_effects: missing or non-positive " + field)
			passed = false
	return passed and not config.is_empty()


func test_sprite_effects_resolve() -> bool:
	# N9-3f adds elemental hit strips beside the retained blink mist.
	var passed: bool = true
	for effect_id: String in [
		"blink_puff", "hit_fire", "hit_lightning", "hit_curse", "hit_neutral",
	]:
		var config: Dictionary = WeaponEffects.sprite_config(effect_id)
		if not EffectSprite.available(effect_id):
			push_error("test_weapon_effects: sprite effect unavailable: " + effect_id)
			passed = false
			continue
		if float(config.get("fps", 0.0)) <= 0.0 or float(config.get("logical_px", 0.0)) <= 0.0:
			push_error("test_weapon_effects: bad sprite numbers for " + effect_id)
			passed = false
	return passed


func test_projectile_travel_art_resolves_with_missing_fallback() -> bool:
	var weapons: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapons.json")
	)
	if weapons is not Dictionary:
		push_error("test_weapon_effects: weapons.json did not parse")
		return false
	var passed: bool = true
	# N9-43: derived from the data rather than a hardcoded roster. The old list
	# still named 봉황 부적 after it was removed, so the test failed for the one
	# reason a data-driven check should never fail — it was describing weapons
	# that no longer exist. Every weapon that DECLARES travel art must ship it;
	# weapons without the field are simply not in scope.
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var path: String = String(
			(weapons[weapon_id] as Dictionary).get("travel_sprite", "")
		)
		if path.is_empty():
			continue
		if not Projectile.travel_available(path):
			push_error("test_weapon_effects: travel art unavailable: " + weapon_id)
			passed = false
	# False is the gate into the procedural fallback, not an error condition.
	passed = passed and not Projectile.travel_available("")
	passed = passed and not Projectile.travel_available(
		"res://asset/weapon/travel/missing.png"
	)
	return passed


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
