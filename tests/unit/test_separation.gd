extends RefCounted
## Guards the N3-14 separation steering math (scripts/combat/separation.gd)
## and its data contract in data/effects.json. Runtime callers of the same
## API: spawner.gd (grid + push) and enemy.gd (blend).

const EPSILON := 0.001
const PAD := 6.0
const RADIUS := 10.0
const CELL := 96.0
const SAMPLE_COUNT := 40
const SAMPLE_SEED := 20260814


func test_push_zero_with_no_neighbours() -> bool:
	var push: Vector2 = Separation.separation_push(
		Vector2(5.0, 5.0), RADIUS, [] as Array[Vector2], [] as Array[float],
		PAD, Vector2.RIGHT
	)
	return push == Vector2.ZERO


func test_push_points_away_from_single_neighbour() -> bool:
	# Neighbour to the left inside the limit must push right.
	var push: Vector2 = Separation.separation_push(
		Vector2.ZERO, RADIUS, [Vector2(-8.0, 0.0)] as Array[Vector2],
		[RADIUS] as Array[float], PAD, Vector2.UP
	)
	return push.x > 0.0 and absf(push.y) < EPSILON


func test_push_fades_to_zero_at_pair_limit() -> bool:
	var limit: float = RADIUS + RADIUS + PAD
	var at_limit: Vector2 = Separation.separation_push(
		Vector2.ZERO, RADIUS, [Vector2(limit, 0.0)] as Array[Vector2],
		[RADIUS] as Array[float], PAD, Vector2.UP
	)
	var inside: Vector2 = Separation.separation_push(
		Vector2.ZERO, RADIUS, [Vector2(limit * 0.5, 0.0)] as Array[Vector2],
		[RADIUS] as Array[float], PAD, Vector2.UP
	)
	return at_limit == Vector2.ZERO and inside.length() > EPSILON


func test_push_is_stronger_when_closer() -> bool:
	var near: Vector2 = Separation.separation_push(
		Vector2.ZERO, RADIUS, [Vector2(4.0, 0.0)] as Array[Vector2],
		[RADIUS] as Array[float], PAD, Vector2.UP
	)
	var far: Vector2 = Separation.separation_push(
		Vector2.ZERO, RADIUS, [Vector2(20.0, 0.0)] as Array[Vector2],
		[RADIUS] as Array[float], PAD, Vector2.UP
	)
	return near.length() > far.length()


func test_exactly_stacked_neighbour_uses_fallback() -> bool:
	var push: Vector2 = Separation.separation_push(
		Vector2(3.0, 4.0), RADIUS, [Vector2(3.0, 4.0)] as Array[Vector2],
		[RADIUS] as Array[float], PAD, Vector2.LEFT
	)
	return push == Vector2.LEFT


func test_blended_direction_stays_normalised() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = SAMPLE_SEED
	for i: int in range(50):
		var chase: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU))
		var push: Vector2 = (
			Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 3.0)
		)
		var blended: Vector2 = Separation.blended_direction(chase, push)
		if blended != Vector2.ZERO and absf(blended.length() - 1.0) > EPSILON:
			return false
	return true


func test_blended_direction_zero_when_inputs_cancel() -> bool:
	var cancelled: Vector2 = Separation.blended_direction(Vector2.RIGHT, Vector2.LEFT)
	var idle: Vector2 = Separation.blended_direction(Vector2.ZERO, Vector2.ZERO)
	return cancelled == Vector2.ZERO and idle == Vector2.ZERO


## Grid completeness: filtered at one cell edge, the 3x3 lookup must return
## exactly the brute-force neighbour set for every index of a random sample.
func test_grid_matches_brute_force_scan() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = SAMPLE_SEED
	var positions: Array[Vector2] = []
	for i: int in range(SAMPLE_COUNT):
		positions.append(Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-400.0, 400.0)))
	var grid := Separation.new()
	grid.configure(CELL)
	grid.rebuild(positions)
	var collected: Array[int] = []
	for i: int in range(positions.size()):
		var brute: Dictionary = {}
		for j: int in range(positions.size()):
			if j != i and positions[i].distance_to(positions[j]) <= CELL:
				brute[j] = true
		collected.clear()
		grid.collect_neighbours(positions, i, collected)
		var from_grid: Dictionary = {}
		for j: int in collected:
			if positions[i].distance_to(positions[j]) <= CELL:
				from_grid[j] = true
		if from_grid.size() != brute.size():
			return false
		for j: int in brute:
			if not from_grid.has(j):
				return false
	return true


## Data contract: tuning must exist in effects.json and the grid cell must
## cover the largest possible pair limit (two biggest bodies touching plus
## the pad), or the 3x3 lookup could miss a valid neighbour.
func test_separation_tuning_in_effects_json() -> bool:
	var effects: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/effects.json")
	)
	if effects is not Dictionary:
		return false
	var sep: Dictionary = (effects as Dictionary).get("separation", {})
	var weight: float = float(sep.get("weight", 0.0))
	var pad: float = float(sep.get("pad_px", -1.0))
	var cell: float = float(sep.get("cell_px", 0.0))
	if weight <= 0.0 or pad < 0.0 or cell <= 0.0:
		return false
	var monsters: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/monsters.json")
	)
	if monsters is not Dictionary:
		return false
	var largest: float = 0.0
	for monster_id: String in monsters as Dictionary:
		var entry: Dictionary = (monsters as Dictionary)[monster_id]
		var radius: float = float(entry.get("collision_radius", 0.0))
		if entry.has("elite_of"):
			var base: Dictionary = (monsters as Dictionary).get(
				String(entry.get("elite_of", "")), {}
			)
			radius = (
				float(base.get("collision_radius", 0.0)) * float(entry.get("size_mult", 1.0))
			)
		largest = maxf(largest, radius)
	return largest > 0.0 and cell >= largest * 2.0 + pad
