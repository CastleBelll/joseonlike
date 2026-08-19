extends RefCounted
## Guards the N9-59 map projection (Minimap.to_map). The map is a purchase, so
## a blip in the wrong place is worse than no map: the player paid for it and
## will walk where it points.

const EPSILON := 0.01
const MAP_RADIUS := 56.0
const WORLD_RADIUS := 1250.0


func test_the_player_position_lands_dead_centre() -> bool:
	var at: Vector2 = Minimap.to_map(
		Vector2(400.0, -900.0), Vector2(400.0, -900.0), WORLD_RADIUS, MAP_RADIUS
	)["at"]
	return at.distance_to(Vector2(MAP_RADIUS, MAP_RADIUS)) < EPSILON


func test_a_point_keeps_its_bearing() -> bool:
	# Due east in the world must read as due east on the map, or the map lies
	# about which way to walk.
	var centre := Vector2(100.0, 100.0)
	var mapped: Dictionary = Minimap.to_map(
		centre + Vector2(500.0, 0.0), centre, WORLD_RADIUS, MAP_RADIUS
	)
	var offset: Vector2 = mapped["at"] - Vector2(MAP_RADIUS, MAP_RADIUS)
	return absf(offset.y) < EPSILON and offset.x > 0.0 and not bool(mapped["clamped"])


func test_distance_scales_proportionally() -> bool:
	# Twice as far in the world is twice as far on the map, inside the radius.
	var near: Vector2 = Minimap.to_map(
		Vector2(300.0, 0.0), Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
	)["at"]
	var far: Vector2 = Minimap.to_map(
		Vector2(600.0, 0.0), Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
	)["at"]
	var middle := Vector2(MAP_RADIUS, MAP_RADIUS)
	return absf((far - middle).x - (near - middle).x * 2.0) < EPSILON


func test_a_distant_point_is_clamped_to_the_rim_not_dropped() -> bool:
	# Something out of range still has to say which way it is.
	var mapped: Dictionary = Minimap.to_map(
		Vector2(90000.0, 0.0), Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
	)
	var offset: Vector2 = mapped["at"] - Vector2(MAP_RADIUS, MAP_RADIUS)
	return bool(mapped["clamped"]) \
		and absf(offset.length() - (MAP_RADIUS - Minimap.RIM_INSET)) < EPSILON \
		and offset.x > 0.0


func test_every_blip_stays_inside_the_disc() -> bool:
	# 64 directions at absurd range: a blip drawn outside the border reads as a
	# rendering bug and covers whatever sits next to the map.
	var limit: float = MAP_RADIUS - Minimap.RIM_INSET + EPSILON
	for i: int in range(64):
		var world: Vector2 = Vector2.from_angle(TAU * float(i) / 64.0) * 50000.0
		var at: Vector2 = Minimap.to_map(
			world, Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
		)["at"]
		if at.distance_to(Vector2(MAP_RADIUS, MAP_RADIUS)) > limit:
			return false
	return true


func test_a_point_exactly_at_the_radius_is_not_clamped() -> bool:
	# The boundary belongs to the inside, so a blip does not flicker between
	# hollow and solid while the player circles it.
	var mapped: Dictionary = Minimap.to_map(
		Vector2(WORLD_RADIUS, 0.0), Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
	)
	return not bool(mapped["clamped"])


func test_a_degenerate_world_radius_does_not_divide_by_zero() -> bool:
	var mapped: Dictionary = Minimap.to_map(
		Vector2(10.0, 10.0), Vector2.ZERO, 0.0, MAP_RADIUS
	)
	return mapped["at"] == Vector2(MAP_RADIUS, MAP_RADIUS)


func test_world_radius_covers_the_field_passive_spawn_ring() -> bool:
	# A drop is placed up to spawn_max_px away. If the map cannot reach that
	# far, the newest thing it exists to show is the one thing it never shows.
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/pickups.json")
	)
	if data is not Dictionary:
		return false
	var block: Dictionary = (data as Dictionary).get("field_passive", {})
	return Minimap.WORLD_RADIUS >= float(block.get("spawn_max_px", 0.0))
