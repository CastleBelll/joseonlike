class_name PropGrid
extends RefCounted
## Uniform-grid index over the static things a monster asks about every frame —
## lantern light (N9-86) and hung sieves (N10-1b).
##
## Both registries are appended to as the world streams new chunks and nothing
## ever removes an entry, so scanning the whole list costs more the further the
## player walks: on a long night the same question gets slower every minute.
## This is the standard answer — bucket by cell and ask only the cell the
## querying point stands in, so cost follows local density instead of world
## size.
##
## An entry is inserted into EVERY cell its radius touches, which makes a point
## query a single bucket lookup rather than a neighbourhood sweep. That is the
## right trade here: entries are written once, when a chunk generates, and read
## many times a second by everything alive.
##
## `Separation` also buckets by cell, and is deliberately NOT reused: it rebuilds
## every physics frame from moving enemies, while this holds static props that
## are appended once and never move. Sharing one class would mean either
## rebuilding this index 60 times a second for nothing, or teaching that one a
## lifecycle it does not want.

## Comfortably wider than the largest radius in the data (lantern 200, sieve
## 150), so an entry lands in at most a 2x2 block of cells.
const CELL_PX := 512.0

var _cells: Dictionary = {}


static func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i((at / CELL_PX).floor())


## Index one entry, in the {"position": Vector2, "radius": float} shape the
## registries already use.
func add(entry: Dictionary) -> void:
	var at: Vector2 = entry.get("position", Vector2.ZERO)
	var radius: float = float(entry.get("radius", 0.0))
	var low: Vector2i = _cell_of(at - Vector2(radius, radius))
	var high: Vector2i = _cell_of(at + Vector2(radius, radius))
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			var key := Vector2i(x, y)
			if not _cells.has(key):
				_cells[key] = [] as Array[Dictionary]
			(_cells[key] as Array[Dictionary]).append(entry)


## Every entry that could possibly cover `at`. Never null: an empty cell answers
## with an empty array, so callers keep their ordinary loop.
func near(at: Vector2) -> Array[Dictionary]:
	# The typed empty must be built here rather than returned from the Variant:
	# a bucket read back out of a Dictionary loses its element type, and
	# CombatMath.is_lit takes a typed array — which failed at runtime while
	# every test passed, because the tests build the array in typed code.
	var out: Array[Dictionary] = []
	var bucket: Variant = _cells.get(_cell_of(at))
	if bucket is Array:
		out.assign(bucket)
	return out


## Cells currently holding anything. A probe watches this to see the index is
## actually spreading entries rather than piling them into one bucket.
func cell_count() -> int:
	return _cells.size()
