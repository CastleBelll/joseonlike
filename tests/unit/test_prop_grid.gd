extends RefCounted
## The index that keeps a per-frame proximity question from getting slower the
## longer the night runs. What matters is that it answers the SAME thing a full
## scan would, while touching only what is nearby.


func _entry(at: Vector2, radius: float) -> Dictionary:
	return {"position": at, "radius": radius}


## An entry has to be found from anywhere its own radius covers, including the
## far side of a cell boundary — that is the whole reason it is written into
## every cell it touches instead of just the one its centre lands in.
func test_an_entry_is_found_across_the_cells_it_covers() -> bool:
	var grid := PropGrid.new()
	var edge: float = PropGrid.CELL_PX
	var light: Dictionary = _entry(Vector2(edge, 0.0), 200.0)
	grid.add(light)
	var passed: bool = (
		grid.near(Vector2(edge - 150.0, 0.0)).has(light)
		and grid.near(Vector2(edge + 150.0, 0.0)).has(light)
	)
	if not passed:
		push_error("test_prop_grid: an entry went missing on the far side of a cell edge")
	return passed


## The point of the thing: a query does not drag in entries from across the
## world. A far one must not even be a candidate.
func test_a_distant_entry_is_not_even_a_candidate() -> bool:
	var grid := PropGrid.new()
	grid.add(_entry(Vector2(50.0, 50.0), 150.0))
	grid.add(_entry(Vector2(PropGrid.CELL_PX * 40.0, 0.0), 150.0))
	var here: Array[Dictionary] = grid.near(Vector2(60.0, 60.0))
	if here.size() != 1:
		push_error(
			"test_prop_grid: a query saw %d entries, expected only the local one" % here.size()
		)
		return false
	return true


## An empty cell answers with an empty array rather than null, so every caller
## keeps its ordinary loop and no query needs a guard.
func test_an_empty_cell_answers_with_an_empty_list() -> bool:
	var grid := PropGrid.new()
	var answer: Array[Dictionary] = grid.near(Vector2(1234.0, -5678.0))
	if not answer.is_empty():
		push_error("test_prop_grid: an empty cell answered with something")
		return false
	return true


## The index must agree with the honest full scan it replaces, everywhere —
## including the boundary, which CombatMath compares with <=.
func test_the_index_agrees_with_a_full_scan() -> bool:
	var grid := PropGrid.new()
	var all: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260825
	for i: int in range(60):
		var entry: Dictionary = _entry(
			Vector2(rng.randf_range(-4000.0, 4000.0), rng.randf_range(-4000.0, 4000.0)),
			rng.randf_range(80.0, 200.0)
		)
		all.append(entry)
		grid.add(entry)
	for i: int in range(400):
		var at := Vector2(
			rng.randf_range(-4200.0, 4200.0), rng.randf_range(-4200.0, 4200.0)
		)
		if CombatMath.is_lit(at, all) != CombatMath.is_lit(at, grid.near(at)):
			push_error("test_prop_grid: the index and a full scan disagree at %s" % str(at))
			return false
	return true


## Entries spread across cells instead of piling into one bucket — a grid that
## put everything in a single cell would pass every test above and still be the
## full scan it was meant to replace.
func test_entries_spread_across_cells() -> bool:
	var grid := PropGrid.new()
	for i: int in range(20):
		grid.add(_entry(Vector2(PropGrid.CELL_PX * 3.0 * float(i), 0.0), 100.0))
	if grid.cell_count() < 20:
		push_error("test_prop_grid: 20 spread entries landed in %d cells" % grid.cell_count())
		return false
	return true
