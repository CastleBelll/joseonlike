class_name StageGround
extends Sprite2D
## Repeating ground tile drawn behind every actor.
##
## The tiles are 256x256 with bit-identical opposite edges, so any visible seam
## is a repeat-setup bug rather than an art bug. The node follows the camera and
## snaps to whole pixels; a fractional position is what produces seam shimmer at
## this art scale.

const GROUND_PATH: String = "res://asset/stage/%s_ground.png"
const TILE_PX: int = 256
## One tile of slack on every side, so a fast camera never outruns the fill.
const MARGIN_TILES: int = 1
const FALLBACK_SIZE: Vector2i = Vector2i(540, 960)
const GROUND_Z_INDEX: int = -100
const PLACEHOLDER_TINT: Color = Color(0.10, 0.16, 0.12)


func _ready() -> void:
	centered = true
	region_enabled = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = GROUND_Z_INDEX
	z_as_relative = false


## Picks the tile for a stage. An unknown stage keeps a flat fallback colour
## rather than leaving the field empty.
func setup(stage_id: String) -> void:
	var path: String = GROUND_PATH % stage_id
	if not stage_id.is_empty() and ResourceLoader.exists(path):
		texture = ResourceLoader.load(path) as Texture2D
	if texture == null:
		push_warning("StageGround: no ground tile for stage %s" % stage_id)
		texture = PlaceholderArt.placeholder(PLACEHOLDER_TINT)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## Keeps the quad centred on the camera while the region scrolls with the world,
## so the tiling reads as ground rather than as a texture stuck to the screen.
func _refresh() -> void:
	var size: Vector2i = _covered_size()
	var centre: Vector2i = Vector2i(_camera_centre().round())
	position = Vector2(centre)
	region_rect = Rect2(Vector2(centre - size / 2), Vector2(size))


func _covered_size() -> Vector2i:
	var viewport: Viewport = get_viewport()
	var view: Vector2i = FALLBACK_SIZE
	if viewport != null:
		view = Vector2i(viewport.get_visible_rect().size.ceil())
	return view + Vector2i.ONE * (TILE_PX * MARGIN_TILES * 2)


func _camera_centre() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return global_position
	var half_screen: Vector2 = viewport.get_visible_rect().size * 0.5
	return viewport.get_canvas_transform().affine_inverse() * half_screen
