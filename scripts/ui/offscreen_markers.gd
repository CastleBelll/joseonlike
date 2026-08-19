class_name OffscreenMarkers
extends Control
## Edge arrows for things worth walking to (N9-57).
##
## Field passives are placed beyond the screen edge on purpose — the walk is
## the point. That also makes them invisible, and an invisible reward is the
## same as no reward, so each one off-screen gets an arrow pinned to the edge
## nearest it.
##
## The placement math is static and node-free so the headless suite can check
## it; the node only draws. Input is never accepted: an arrow that swallowed a
## tap would break the joystick it sits on top of.

## Distance from the screen edge to the arrow. Large enough to clear the
## rounded corners of a phone screen and the HUD's own margin.
const EDGE_MARGIN := 26.0
## Extra inset at the bottom, where the active-skill buttons live — an arrow
## there would sit on top of a control the player is trying to press.
const BOTTOM_INSET := 96.0
const TOP_INSET := 74.0
const ARROW_LENGTH := 15.0
const ARROW_WIDTH := 11.0
const FILL_ALPHA := 0.85
const OUTLINE_WIDTH := 1.5
## The arrow fades with distance but never below this: "far away" must stay
## legible, or the marker reads as a rendering glitch.
const MIN_ALPHA := 0.35
const FADE_START_PX := 700.0
const FADE_END_PX := 2000.0

var _targets: Array[Vector2] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Where an arrow for `target` belongs, in the same screen space as `bounds`.
## Returns {"at": Vector2, "angle": float, "needed": bool}; `needed` is false
## when the target is already inside the bounds and can simply be looked at.
##
## The arrow is placed by walking OUT from the centre along the direction to
## the target and stopping at whichever bound is reached first. Clamping the
## target's own position instead would slide arrows along the edges as the
## player moves, which reads as jitter rather than as direction.
static func edge_marker(target: Vector2, bounds: Rect2) -> Dictionary:
	var centre: Vector2 = bounds.position + bounds.size / 2.0
	if bounds.has_point(target):
		return {"at": target, "angle": 0.0, "needed": false}
	var delta: Vector2 = target - centre
	if delta == Vector2.ZERO or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {"at": centre, "angle": 0.0, "needed": false}
	var half: Vector2 = bounds.size / 2.0
	# How far along `delta` the centre can travel before leaving each axis.
	var scale_x: float = INF if is_zero_approx(delta.x) else half.x / absf(delta.x)
	var scale_y: float = INF if is_zero_approx(delta.y) else half.y / absf(delta.y)
	var travel: float = minf(scale_x, scale_y)
	return {
		"at": centre + delta * travel,
		"angle": delta.angle(),
		"needed": true,
	}


## The rect arrows may occupy: the screen minus the margins that keep them off
## the HUD.
static func marker_bounds(screen: Vector2) -> Rect2:
	var width: float = maxf(screen.x - EDGE_MARGIN * 2.0, 1.0)
	var height: float = maxf(screen.y - TOP_INSET - BOTTOM_INSET, 1.0)
	return Rect2(Vector2(EDGE_MARGIN, TOP_INSET), Vector2(width, height))


## Opacity for a target `distance` away, so an arrow says roughly how far the
## walk is rather than only which way.
static func distance_alpha(distance: float) -> float:
	var span: float = maxf(FADE_END_PX - FADE_START_PX, 1.0)
	var faded: float = clampf((distance - FADE_START_PX) / span, 0.0, 1.0)
	return lerpf(1.0, MIN_ALPHA, faded)


## Called by the stage with the world positions worth pointing at. An empty
## array clears the arrows, which is what collecting the last one does.
func track(world_positions: Array[Vector2]) -> void:
	_targets = world_positions
	queue_redraw()


func _draw() -> void:
	if _targets.is_empty():
		return
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var bounds: Rect2 = marker_bounds(size)
	var player_at: Vector2 = bounds.position + bounds.size / 2.0
	for world: Vector2 in _targets:
		var on_screen: Vector2 = canvas * world
		var marker: Dictionary = edge_marker(on_screen, bounds)
		if not bool(marker["needed"]):
			continue
		# Distance is measured to the TARGET, not to the clamped arrow: the
		# arrow is always at the edge, so its own distance says nothing.
		_draw_arrow(
			marker["at"], float(marker["angle"]),
			distance_alpha(player_at.distance_to(on_screen))
		)


func _draw_arrow(at: Vector2, angle: float, alpha: float) -> void:
	var forward: Vector2 = Vector2.from_angle(angle)
	var side: Vector2 = forward.orthogonal()
	var points := PackedVector2Array([
		at + forward * ARROW_LENGTH,
		at - forward * ARROW_LENGTH * 0.35 + side * (ARROW_WIDTH / 2.0),
		at - forward * ARROW_LENGTH * 0.35 - side * (ARROW_WIDTH / 2.0),
	])
	# Outlined, because the field is dark in places and lit in others and a
	# single flat colour disappears into one of them.
	draw_colored_polygon(points, Color(UiPalette.GOLD, FILL_ALPHA * alpha))
	draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[0]]),
		Color(UiPalette.INK, alpha), OUTLINE_WIDTH
	)
