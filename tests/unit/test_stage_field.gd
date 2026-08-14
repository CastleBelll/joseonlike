extends RefCounted
## N3-9 headless coverage: deterministic generation, solid spacing, the
## spawn-clear rule, weighted selection and the data/props.json collision
## contract, all through the pure StageField/CombatMath statics.

const SEED_A := 12345
const SEED_B := 54321
const WEIGHT_SAMPLES := 10000
const WEIGHT_TOLERANCE := 0.05
const DISTANCE_EPSILON := 0.001


func _config() -> Dictionary:
	return StageField.load_config()


func test_same_seed_reproduces_identical_layout() -> bool:
	var config: Dictionary = _config()
	var a: Array[Dictionary] = StageField.generate(config["props"], config["field"], SEED_A)
	var b: Array[Dictionary] = StageField.generate(config["props"], config["field"], SEED_A)
	if a.is_empty() or a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i]["id"] != b[i]["id"] or a[i]["position"] != b[i]["position"]:
			return false
	return true


func test_different_seeds_produce_different_layouts() -> bool:
	var config: Dictionary = _config()
	var a: Array[Dictionary] = StageField.generate(config["props"], config["field"], SEED_A)
	var b: Array[Dictionary] = StageField.generate(config["props"], config["field"], SEED_B)
	if a.is_empty() or b.is_empty():
		return false
	if a.size() != b.size():
		return true
	for i: int in range(a.size()):
		if a[i]["position"] != b[i]["position"]:
			return true
	return false


func test_layout_contains_solids_and_decor() -> bool:
	var config: Dictionary = _config()
	var placements: Array[Dictionary] = StageField.generate(
		config["props"], config["field"], SEED_A
	)
	var solids: int = 0
	var decor: int = 0
	for placement: Dictionary in placements:
		if bool(placement["solid"]):
			solids += 1
		else:
			decor += 1
	return solids > 0 and decor > 0


func test_no_two_solids_violate_min_distance() -> bool:
	var config: Dictionary = _config()
	var catalog: Dictionary = config["props"]
	var field: Dictionary = config["field"]
	var gap: float = float(field["min_gap_px"])
	var solids: Array[Dictionary] = StageField.generate(catalog, field, SEED_A).filter(
		func(placement: Dictionary) -> bool: return bool(placement["solid"])
	)
	for i: int in range(solids.size()):
		for j: int in range(i + 1, solids.size()):
			var minimum: float = (
				StageField.spacing_radius(catalog[solids[i]["id"]])
				+ StageField.spacing_radius(catalog[solids[j]["id"]])
				+ gap
			)
			var apart: float = (
				(solids[i]["position"] as Vector2).distance_to(solids[j]["position"])
			)
			if apart < minimum - DISTANCE_EPSILON:
				return false
	return true


func test_spawn_clear_radius_holds_no_solid() -> bool:
	var config: Dictionary = _config()
	var clear_radius: float = float((config["field"] as Dictionary)["spawn_clear_radius_px"])
	for placement: Dictionary in StageField.generate(config["props"], config["field"], SEED_A):
		if not bool(placement["solid"]):
			continue
		if (placement["position"] as Vector2).length() < clear_radius:
			return false
	return true


func test_weighted_pick_respects_weights() -> bool:
	var weights: Array[float] = [1.0, 3.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_A
	var hits: Array[int] = [0, 0]
	for i: int in range(WEIGHT_SAMPLES):
		hits[StageField.pick_weighted(weights, rng.randf())] += 1
	var first_share: float = float(hits[0]) / float(WEIGHT_SAMPLES)
	return absf(first_share - 0.25) < WEIGHT_TOLERANCE


func test_collision_boxes_stay_inside_sprite_bounds() -> bool:
	var catalog: Dictionary = _config()["props"]
	for prop_id: String in catalog:
		var prop: Dictionary = catalog[prop_id]
		if not bool(prop.get("solid", false)):
			continue
		var size: Array = prop["size"]
		var box: Array = prop["collision"]
		var inside: bool = (
			float(box[0]) >= -float(size[0]) / 2.0
			and float(box[0]) + float(box[2]) <= float(size[0]) / 2.0
			and float(box[1]) >= -float(size[1])
			and float(box[1]) + float(box[3]) <= 0.0
		)
		if not inside:
			return false
	return true


func test_avoid_direction_slides_and_walks_tangent() -> bool:
	# No wall: desired passes through untouched.
	if CombatMath.avoid_direction(Vector2.RIGHT, Vector2.ZERO, 1.0) != Vector2.RIGHT:
		return false
	# Angled block against a wall facing left: only the downward slide remains.
	var angled: Vector2 = CombatMath.avoid_direction(
		Vector2(1.0, 0.5).normalized(), Vector2.LEFT, 1.0
	)
	if not angled.is_equal_approx(Vector2(0.0, 1.0)):
		return false
	# Head-on block: walks the wall tangent instead of stalling.
	var head_on: Vector2 = CombatMath.avoid_direction(Vector2.RIGHT, Vector2.LEFT, 1.0)
	return head_on.length() > 0.9 and absf(head_on.dot(Vector2.LEFT)) < 0.001
