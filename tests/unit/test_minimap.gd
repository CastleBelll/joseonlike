extends RefCounted
## Guards the N9-59 map projection (Minimap.to_map). The map is earned, and a
## mark in the wrong place is worse than no map at all: the player walks where
## it points.

const EPSILON := 0.01
## Half the sheet: the map is a square woodblock page, not a radar disc.
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


func test_a_distant_point_is_clamped_to_the_edge_not_dropped() -> bool:
	# Something out of range still has to say which way it is.
	var mapped: Dictionary = Minimap.to_map(
		Vector2(90000.0, 0.0), Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
	)
	var offset: Vector2 = mapped["at"] - Vector2(MAP_RADIUS, MAP_RADIUS)
	return bool(mapped["clamped"]) \
		and absf(offset.length() - (MAP_RADIUS - Minimap.RIM_INSET)) < EPSILON \
		and offset.x > 0.0


func test_every_blip_stays_inside_the_sheet() -> bool:
	# 64 directions at absurd range: a mark drawn outside the printed border
	# reads as a rendering bug and covers whatever sits beside the map.
	var limit: float = MAP_RADIUS - Minimap.RIM_INSET + EPSILON
	var middle := Vector2(MAP_RADIUS, MAP_RADIUS)
	for i: int in range(64):
		var world: Vector2 = Vector2.from_angle(TAU * float(i) / 64.0) * 50000.0
		var at: Vector2 = Minimap.to_map(
			world, Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
		)["at"]
		var offset: Vector2 = at - middle
		if absf(offset.x) > limit or absf(offset.y) > limit:
			return false
	return true


func test_a_corner_bearing_survives_the_square_clamp() -> bool:
	# A diagonal target must still point diagonally after clamping. Clamping
	# each axis on its own would flatten it against one edge and send the
	# player along a wall.
	var mapped: Dictionary = Minimap.to_map(
		Vector2(9000.0, 9000.0), Vector2.ZERO, WORLD_RADIUS, MAP_RADIUS
	)
	var offset: Vector2 = mapped["at"] - Vector2(MAP_RADIUS, MAP_RADIUS)
	return bool(mapped["clamped"]) and absf(offset.x - offset.y) < EPSILON


func test_a_point_exactly_at_the_edge_is_not_clamped() -> bool:
	# The boundary belongs to the inside, so a mark does not flicker between
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
