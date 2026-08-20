class_name Minimap
extends Control
## Corner map (N9-59), drawn only when the 지도 unlock is owned.
##
## Shows the player at the centre and what is lying around them. It is a
## RADAR, not a chart: there is no terrain, because the field is procedurally
## scattered and a picture of bamboo would tell the player nothing they cannot
## already see out the window. What they cannot see is where the drops are,
## and that is all this draws.
##
## The projection is static and node-free so the suite can check it; the node
## only draws, and never takes input.

const SIZE := 112.0
## How much of the world fits inside the disc. Wide enough to cover the field
## passive spawn ring (up to 1100px) so a fresh drop appears the moment it is
## placed rather than only once the player has walked toward it.
const WORLD_RADIUS := 1250.0
const BORDER_WIDTH := 2.0
const BG_ALPHA := 0.42
const BLIP_RADIUS := 3.0
const PLAYER_RADIUS := 3.5
const RING_POINTS := 32
## Blips past the radius are clamped to the rim rather than dropped, so
## something just outside still reads as "over there" instead of vanishing.
const RIM_INSET := 5.0

## Blip kinds, in draw order — later ones sit on top where they overlap.
const KIND_LOOT := "loot"
const KIND_CHEST := "chest"
const KIND_PASSIVE := "passive"

var _player_pos := Vector2.ZERO
var _blips: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)


## Projects a world point into map-local coordinates, with the map's centre at
## `map_radius`. Returns {"at": Vector2, "clamped": bool} — `clamped` marks a
## point that was outside the radius and pulled to the rim, which the caller
## draws differently so "at the edge" never looks like "right here".
static func to_map(
	world: Vector2, centre: Vector2, world_radius: float, map_radius: float
) -> Dictionary:
	var middle := Vector2(map_radius, map_radius)
	if world_radius <= 0.0:
		return {"at": middle, "clamped": false}
	var usable: float = maxf(map_radius - RIM_INSET, 1.0)
	var scaled: Vector2 = (world - centre) / world_radius * usable
	if scaled.length() <= usable:
		return {"at": middle + scaled, "clamped": false}
	return {"at": middle + scaled.normalized() * usable, "clamped": true}


## Called by the stage with the player's position and the things to mark, as
## {kind: Array[Vector2]}. Empty arrays clear the map.
func show_blips(player_pos: Vector2, blips: Dictionary) -> void:
	_player_pos = player_pos
	_blips = blips
	queue_redraw()


func _draw() -> void:
	var radius: float = SIZE / 2.0
	var middle := Vector2(radius, radius)
	draw_circle(middle, radius, Color(UiPalette.NIGHT, BG_ALPHA))
	draw_arc(
		middle, radius - BORDER_WIDTH / 2.0, 0.0, TAU, RING_POINTS,
		UiPalette.GOLD_BORDER, BORDER_WIDTH
	)
	for kind: String in [KIND_LOOT, KIND_CHEST, KIND_PASSIVE]:
		var color: Color = _blip_color(kind)
		for world: Variant in _blips.get(kind, []):
			var mapped: Dictionary = to_map(world, _player_pos, WORLD_RADIUS, radius)
			# A clamped blip is hollow: it says "this direction", not "here".
			if bool(mapped["clamped"]):
				draw_arc(mapped["at"], BLIP_RADIUS, 0.0, TAU, 10, color, 1.5)
			else:
				draw_circle(mapped["at"], BLIP_RADIUS, color)
	# The player last, so nothing can hide them on their own map, and as a
	# DIAMOND rather than another dot. Loot draws in near-white and the player
	# used to draw in a slightly different near-white, which at three pixels
	# was no difference at all — on a map bought for 900 gold, the one marker
	# that must never be ambiguous is where you are standing.
	_draw_player(middle)


func _draw_player(at: Vector2) -> void:
	var points := PackedVector2Array([
		at + Vector2(0.0, -PLAYER_RADIUS - 1.5),
		at + Vector2(PLAYER_RADIUS + 1.5, 0.0),
		at + Vector2(0.0, PLAYER_RADIUS + 1.5),
		at + Vector2(-PLAYER_RADIUS - 1.5, 0.0),
	])
	draw_colored_polygon(points, UiPalette.GOLD)
	draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
		UiPalette.INK, 1.0
	)


## Kinds are told apart by colour AND by the rim rule above (hollow = at the
## edge); the colours match what each thing looks like in the world, so the
## map needs no legend.
func _blip_color(kind: String) -> Color:
	match kind:
		KIND_PASSIVE:
			return UiPalette.LOOT_RARE
		KIND_CHEST:
			return UiPalette.GOLD
		_:
			return UiPalette.LOOT_CORE
