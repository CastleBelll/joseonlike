class_name Separation
extends RefCounted
## N3-14 crowd separation: pure steering math plus a bucketed neighbour grid
## so 60+ chasing enemies spread into a crowd instead of stacking on the
## player. Node-free so the headless suite drives it directly
## (tests/unit/test_separation.gd). Tuning lives in data/effects.json
## ("separation": weight / pad_px / cell_px), never here.

## Below this distance two enemies count as exactly stacked and the push
## falls back to a caller-supplied deterministic direction.
const STACKED_EPSILON := 0.001

## Grid cell edge in px. A single 3x3 cell query is guaranteed to see every
## neighbour within one cell edge, so cell_px must stay >= the largest
## possible pair limit (biggest radius pair + pad).
var _cell_px: float = 0.0
## Vector2i cell -> Array[int] of enemy indices. Buckets are cleared, never
## freed, between rebuilds so steady-state frames allocate nothing.
## ponytail: keeps one empty Array per visited cell for the whole run;
## bounded by field area / cell area, prune if it ever shows in profiles.
var _cells: Dictionary = {}
var _used_cells: Array[Vector2i] = []


func configure(cell_px: float) -> void:
	_cell_px = cell_px
	_cells.clear()
	_used_cells.clear()


## Rebuckets every position; call once per physics frame before queries.
func rebuild(positions: Array[Vector2]) -> void:
	for cell: Vector2i in _used_cells:
		(_cells[cell] as Array).clear()
	_used_cells.clear()
	for i: int in range(positions.size()):
		var cell: Vector2i = _cell_of(positions[i])
		if not _cells.has(cell):
			_cells[cell] = [] as Array[int]
		var bucket: Array[int] = _cells[cell]
		if bucket.is_empty():
			_used_cells.append(cell)
		bucket.append(i)


## Appends into `out` (cleared by the caller) every index whose cell touches
## the 3x3 block around `index`'s cell, excluding `index` itself. Complete for
## any pair distance <= cell_px; may include farther indices — the push math
## distance-filters per pair.
func collect_neighbours(positions: Array[Vector2], index: int, out: Array[int]) -> void:
	var center: Vector2i = _cell_of(positions[index])
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var bucket: Variant = _cells.get(center + Vector2i(dx, dy))
			if bucket == null:
				continue
			for neighbour: int in bucket as Array[int]:
				if neighbour != index:
					out.append(neighbour)


func _cell_of(position: Vector2) -> Vector2i:
	return Vector2i((position / _cell_px).floor())


## Sum of pushes away from each neighbour, each fading linearly from full
## strength at zero distance to nothing at the pair limit
## (self_radius + neighbour_radius + pad_px). A neighbour exactly on top of
## us contributes the caller's deterministic `fallback` direction instead of
## an undefined normal, so two perfectly stacked enemies split apart.
static func separation_push(
	position: Vector2,
	self_radius: float,
	neighbour_positions: Array[Vector2],
	neighbour_radii: Array[float],
	pad_px: float,
	fallback: Vector2
) -> Vector2:
	var push := Vector2.ZERO
	for i: int in range(neighbour_positions.size()):
		var limit: float = self_radius + neighbour_radii[i] + pad_px
		var away: Vector2 = position - neighbour_positions[i]
		var distance: float = away.length()
		if distance >= limit:
			continue
		if distance < STACKED_EPSILON:
			push += fallback
			continue
		push += away / distance * (1.0 - distance / limit)
	return push


## Chase blended with an already-weighted push; unit length so the enemy's
## speed stays authoritative, ZERO only when both inputs cancel or vanish
## (which reads as idle, same as before this feature).
static func blended_direction(chase: Vector2, weighted_push: Vector2) -> Vector2:
	var combined: Vector2 = chase + weighted_push
	if combined == Vector2.ZERO:
		return Vector2.ZERO
	return combined.normalized()
