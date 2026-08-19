extends RefCounted
## N3-10/N3-11 headless coverage: seeded ground-tile layout is deterministic,
## covers the field with no gaps, and (N3-11) variants land as a sparse,
## spatially-clustered patch pattern rather than an even per-tile scatter —
## through the pure GroundLayer static.

const SEED_A := 12345
const SEED_B := 54321
## N6-5 quiet-floor bound: measured 4.0-5.3% across three seeds at the 0.42
## threshold — loose bound so the check pins "sparse", not one calibration.
const MIN_DENSITY := 0.08
const MAX_DENSITY := 0.24
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


## N3-16: the drawn tile window must always contain the camera view rect —
## this is the invariant whose absence showed as the grey bottom band. Checked
## far from spawn, at the old field edge, and with a non-tile-aligned view.
func test_tile_window_covers_camera_view_anywhere() -> bool:
	var view_size := Vector2(540.0, 960.0)
	var centers: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(1000.0, 1000.0),  # old field edge: view extends past 1024
		Vector2(-3277.5, 5121.3),  # far off-field, unaligned to the tile grid
		Vector2(0.0, 1024.0),  # bottom edge, where the band showed
	]
	for center: Vector2 in centers:
		var view := Rect2(center - view_size / 2.0, view_size)
		var covered: Rect2 = GroundLayer.window_rect(
			GroundLayer.tile_window(view.grow(GroundLayer.VIEW_MARGIN_PX))
		)
		if not covered.encloses(view):
			return false
	return true


## Variant and rotation are pure functions of world tile coordinate + seed, so
## any two windows overlapping the same tile agree on its look.
func test_per_tile_pattern_is_seed_stable() -> bool:
	var density: FastNoiseLite = GroundLayer.make_density_noise(SEED_A)
	var type_noise: FastNoiseLite = GroundLayer.make_type_noise(SEED_A)
	var density_b: FastNoiseLite = GroundLayer.make_density_noise(SEED_A)
	var type_b: FastNoiseLite = GroundLayer.make_type_noise(SEED_A)
	for tile: Vector2i in [Vector2i(-40, 77), Vector2i(0, 0), Vector2i(999, -1234)]:
		if (
			GroundLayer.tile_variant(density, type_noise, tile.x, tile.y)
			!= GroundLayer.tile_variant(density_b, type_b, tile.x, tile.y)
		):
			return false
		if (
			GroundLayer.tile_rotation(SEED_A, tile.x, tile.y)
			!= GroundLayer.tile_rotation(SEED_A, tile.x, tile.y)
		):
			return false
	return true


func test_tiles_cover_the_field_with_no_gap() -> bool:
	var field: Dictionary = _field()
	var tiles: Array[Dictionary] = GroundLayer.generate_layout(field, SEED_A)
	var expected: int = int(
		(float(field["width_px"]) / GroundLayer.TILE_SIZE_PX)
		* (float(field["height_px"]) / GroundLayer.TILE_SIZE_PX)
	)
	return tiles.size() == expected
