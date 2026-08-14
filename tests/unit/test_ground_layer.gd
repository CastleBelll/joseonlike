extends RefCounted
## N3-10 headless coverage: seeded ground-tile layout is deterministic and
## covers the field with no gaps, through the pure GroundLayer static.

const SEED_A := 12345
const SEED_B := 54321


func _field() -> Dictionary:
	return StageField.load_config()["field"]


func test_same_seed_reproduces_identical_tile_layout() -> bool:
	var field: Dictionary = _field()
	var a: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	var b: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	if a.is_empty() or a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i]["position"] != b[i]["position"] or a[i]["variant"] != b[i]["variant"]:
			return false
	return true


func test_different_seeds_can_change_variant_choice() -> bool:
	var field: Dictionary = _field()
	var a: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	var b: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_B)
	for i: int in range(a.size()):
		if a[i]["variant"] != b[i]["variant"]:
			return true
	return false


func test_tiles_cover_the_field_with_no_gap() -> bool:
	var field: Dictionary = _field()
	var tiles: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	var expected: int = int(
		(float(field["width_px"]) / GroundLayer.TILE_SIZE_PX)
		* (float(field["height_px"]) / GroundLayer.TILE_SIZE_PX)
	)
	return tiles.size() == expected
