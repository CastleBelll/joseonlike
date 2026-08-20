class_name Minimap
extends Control
## Corner map (N9-59), drawn only when the 지도 unlock is owned. Redrawn in the
## 대동여지도 manner for N9-66 (owner: "그런 화풍으로", not the fine detail).
##
## What that style is, reduced to what a 112px panel can carry: a hanji ground
## rather than a dark screen, a double ink rule for the sheet border, and
## terrain drawn as short chevron strokes — the 산줄기 mark that woodblock maps
## use for a ridge. Everything is ink on paper; nothing glows.
##
## The chevrons are drawn from REAL prop positions, not scattered for looks. A
## decorative ridge would tell the player something is there when nothing is,
## and this map was earned rather than bought — it has to be true.
##
## The projection is static and node-free so the suite can check it; the node
## only draws, and never takes input.

const SIZE := 112.0
## Half of SIZE — the map's centre, and the clamp bound on each axis. A sheet,
## not a radar dish: 대동여지도 is printed on rectangular blocks, and a square
## panel reads as a map where a circle reads as an instrument.
const HALF := SIZE / 2.0
## How much of the world fits inside the disc. Wide enough to cover the field
## passive spawn ring (up to 1100px) so a fresh drop appears the moment it is
## placed rather than only once the player has walked toward it.
const WORLD_RADIUS := 1250.0
## The woodblock frame: a heavy outer rule with a hairline inside it.
const BORDER_WIDTH := 2.0
const INNER_RULE_WIDTH := 1.0
const INNER_RULE_INSET := 4.0
const PAPER_ALPHA := 0.86
const BLIP_RADIUS := 2.6
const PLAYER_RADIUS := 3.2
## Ridge strokes: small, thin and faint, so terrain stays underneath the marks
## that matter instead of competing with them.
const RIDGE_WIDTH := 5.0
const RIDGE_HEIGHT := 3.4
const RIDGE_LINE := 1.0
const RIDGE_ALPHA := 0.5
## Past this many the panel turns into a smudge; the field can hold hundreds.
const RIDGE_LIMIT := 26
## Blips past the radius are clamped to the rim rather than dropped, so
## something just outside still reads as "over there" instead of vanishing.
const RIM_INSET := 5.0

## Blip kinds, in draw order — later ones sit on top where they overlap.
const KIND_LOOT := "loot"
const KIND_CHEST := "chest"
const KIND_PASSIVE := "passive"
## Solid props. Drawn as ridges under everything else.
const KIND_TERRAIN := "terrain"

var _player_pos := Vector2.ZERO
var _blips: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)


## Projects a world point into map-local coordinates on a SQUARE sheet whose
## centre sits at `half_extent`. Returns {"at": Vector2, "clamped": bool} —
## `clamped` marks a point that fell outside the sheet and was pulled to its
## edge, which the caller draws differently so "off the sheet" never looks
## like "right here".
static func to_map(
	world: Vector2, centre: Vector2, world_radius: float, half_extent: float
) -> Dictionary:
	var middle := Vector2(half_extent, half_extent)
	if world_radius <= 0.0:
		return {"at": middle, "clamped": false}
	var usable: float = maxf(half_extent - RIM_INSET, 1.0)
	var scaled: Vector2 = (world - centre) / world_radius * usable
	if absf(scaled.x) <= usable and absf(scaled.y) <= usable:
		return {"at": middle + scaled, "clamped": false}
	# Pulled along its own bearing until it meets the border, so a clamped mark
	# still says which way to walk.
	var reach: float = maxf(absf(scaled.x), absf(scaled.y))
	return {"at": middle + scaled * (usable / reach), "clamped": true}


## Called by the stage with the player's position and the things to mark, as
## {kind: Array[Vector2]}. Empty arrays clear the map.
func show_blips(player_pos: Vector2, blips: Dictionary) -> void:
	_player_pos = player_pos
	_blips = blips
	queue_redraw()


func _draw() -> void:
	_draw_sheet()
	# Ridges first: terrain is the ground the marks sit on, and a chevron drawn
	# over a drop would hide the thing the map exists to show.
	_draw_ridges()
	for kind: String in [KIND_LOOT, KIND_CHEST, KIND_PASSIVE]:
		for world: Variant in _blips.get(kind, []):
			var mapped: Dictionary = to_map(world, _player_pos, WORLD_RADIUS, HALF)
			_draw_blip(mapped["at"], kind, bool(mapped["clamped"]))
	# The player last, so nothing can stand on top of them on their own map.
	_draw_player(Vector2(HALF, HALF))


## Hanji ground and the woodblock frame: a heavy rule with a hairline inside
## it, which is what makes a printed sheet read as a sheet.
func _draw_sheet() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(rect, Color(UiPalette.PAPER, PAPER_ALPHA))
	draw_rect(rect, UiPalette.INK, false, BORDER_WIDTH)
	draw_rect(
		rect.grow(-INNER_RULE_INSET), Color(UiPalette.INK, 0.55), false, INNER_RULE_WIDTH
	)


## 산줄기: each solid prop becomes one small chevron, the mark a woodblock map
## uses for a ridge. They are capped — the field can hold hundreds, and past a
## couple of dozen the sheet is a smudge rather than a map.
func _draw_ridges() -> void:
	# Nearest first, then capped. Taking them in whatever order the field hands
	# them over would print ridges from across the map while leaving out the
	# ones the player is about to walk into.
	var near: Array = []
	for world: Variant in _blips.get(KIND_TERRAIN, []):
		near.append(world)
	near.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return a.distance_squared_to(_player_pos) < b.distance_squared_to(_player_pos)
	)
	var drawn: int = 0
	for world: Variant in near:
		if drawn >= RIDGE_LIMIT:
			return
		var mapped: Dictionary = to_map(world, _player_pos, WORLD_RADIUS, HALF)
		# Only what is actually on the sheet: a clamped ridge would pile every
		# distant prop along the border as a solid black rim.
		if bool(mapped["clamped"]):
			continue
		var at: Vector2 = mapped["at"]
		draw_polyline(
			PackedVector2Array([
				at + Vector2(-RIDGE_WIDTH / 2.0, RIDGE_HEIGHT / 2.0),
				at + Vector2(0.0, -RIDGE_HEIGHT / 2.0),
				at + Vector2(RIDGE_WIDTH / 2.0, RIDGE_HEIGHT / 2.0),
			]),
			Color(UiPalette.INK, RIDGE_ALPHA), RIDGE_LINE
		)
		drawn += 1


## Marks are told apart by SHAPE, because everything on this sheet is ink and
## a colour-only difference would vanish the moment it was printed dark.
## A clamped mark is hollow: it says "that way", not "here".
func _draw_blip(at: Vector2, kind: String, clamped: bool) -> void:
	var color: Color = _blip_color(kind)
	match kind:
		KIND_CHEST:
			var box := Rect2(
				at - Vector2.ONE * BLIP_RADIUS, Vector2.ONE * BLIP_RADIUS * 2.0
			)
			# A filled rect takes no width, and passing one warns every frame.
			if not clamped:
				draw_rect(box, color)
			draw_rect(box, UiPalette.INK, false, RIDGE_LINE)
		KIND_PASSIVE:
			draw_circle(at, BLIP_RADIUS + 1.0, UiPalette.INK)
			if clamped:
				draw_circle(at, BLIP_RADIUS, Color(UiPalette.PAPER, PAPER_ALPHA))
			else:
				draw_circle(at, BLIP_RADIUS, color)
		_:
			draw_circle(at, BLIP_RADIUS, UiPalette.INK)
			if clamped:
				draw_circle(at, BLIP_RADIUS - RIDGE_LINE, Color(UiPalette.PAPER, PAPER_ALPHA))


## The reader's own position, as the crossed mark a printed map uses for the
## seat of a district. Ink on paper like everything else, and the only mark
## with lines through it, so it is never mistaken for a thing to walk to.
func _draw_player(at: Vector2) -> void:
	var arm: float = PLAYER_RADIUS + 2.5
	draw_circle(at, PLAYER_RADIUS, Color(UiPalette.PAPER, PAPER_ALPHA))
	draw_arc(at, PLAYER_RADIUS, 0.0, TAU, 16, UiPalette.INK, RIDGE_LINE + 0.4)
	draw_line(at + Vector2(-arm, 0.0), at + Vector2(arm, 0.0), UiPalette.INK, RIDGE_LINE)
	draw_line(at + Vector2(0.0, -arm), at + Vector2(0.0, arm), UiPalette.INK, RIDGE_LINE)


## Muted enough to sit on paper: the bright screen colours the drops use in the
## world would read as stickers on a printed sheet.
func _blip_color(kind: String) -> Color:
	match kind:
		KIND_PASSIVE:
			return UiPalette.LOOT_RARE.darkened(0.25)
		KIND_CHEST:
			return UiPalette.WOOD.darkened(0.1)
		_:
			return UiPalette.INK
