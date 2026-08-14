extends RefCounted
## N3-10/N3-11 headless coverage: seeded ground-tile layout is deterministic,
## covers the field with no gaps, and (N3-11) variants land as a sparse,
## spatially-clustered patch pattern rather than an even per-tile scatter —
## through the pure GroundLayer static.

const SEED_A := 12345
const SEED_B := 54321
## Loose bound around the task's "roughly 10-20%" target: real noise density
## drifts a little seed to seed, so this checks the mechanism stays sparse,
## not a tight calibration re-check (see tools/_tmp_density.gd for that).
const MIN_DENSITY := 0.05
const MAX_DENSITY := 0.30
## An i.i.d. per-tile scatter at ~15% density gives each variant tile only
## a ~1-0.85^4=48% chance of touching another variant tile. Clustered noise
## patches push this well above that; this is the line that actually
## distinguishes "clustered" from "evenly sprinkled" (density alone does not).
const MIN_CLUSTER_ADJACENCY := 0.65


func _field() -> Dictionary:
	return StageField.load_config()["field"]


func test_same_seed_reproduces_identical_tile_layout() -> bool:
	var field: Dictionary = _field()
	var a: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	var b: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	if a.is_empty() or a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if (
			a[i]["position"] != b[i]["position"]
			or a[i]["variant"] != b[i]["variant"]
			or a[i]["rotation"] != b[i]["rotation"]
		):
			return false
	return true


func test_variant_density_is_sparse() -> bool:
	var field: Dictionary = _field()
	for seed_value: int in [SEED_A, SEED_B]:
		var layout: Array[Dictionary] = GroundLayer.generate_layout(field, seed_value)
		var variant_count: int = 0
		for tile: Dictionary in layout:
			if int(tile["variant"]) >= 0:
				variant_count += 1
		var density: float = float(variant_count) / float(layout.size())
		if density < MIN_DENSITY or density > MAX_DENSITY:
			return false
	return true


## Grid-indexes one seed's layout and checks that most variant tiles touch
## another variant tile — the signature of clustered noise patches, absent
## from an i.i.d. per-tile scatter at the same density.
func test_variant_tiles_are_clustered_not_scattered() -> bool:
	var field: Dictionary = _field()
	var layout: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	var cols: int = int(float(field["width_px"]) / GroundLayer.TILE_SIZE_PX)
	var rows: int = int(float(field["height_px"]) / GroundLayer.TILE_SIZE_PX)
	var grid: Array = []
	grid.resize(layout.size())
	for i: int in range(layout.size()):
		grid[i] = int(layout[i]["variant"]) >= 0
	var touching: int = 0
	var total: int = 0
	for row: int in range(rows):
		for col: int in range(cols):
			var index: int = row * cols + col
			if not grid[index]:
				continue
			total += 1
			var neighbors: Array[int] = [
				index - 1 if col > 0 else -1,
				index + 1 if col < cols - 1 else -1,
				index - cols if row > 0 else -1,
				index + cols if row < rows - 1 else -1,
			]
			for neighbor: int in neighbors:
				if neighbor >= 0 and grid[neighbor]:
					touching += 1
					break
	if total == 0:
		return false
	return float(touching) / float(total) >= MIN_CLUSTER_ADJACENCY


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
