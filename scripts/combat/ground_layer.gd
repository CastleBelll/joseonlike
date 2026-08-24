class_name GroundLayer
extends Node2D
## Tiles the ground with the delivered night-bamboo-forest art (N3-10).
## N3-16: the tile grid follows the CAMERA, not a fixed field rect — the old
## build-once field grid left grey bands wherever the view outran the field
## (every screenshot showed the bottom third bare). Each frame the visible
## world rect is derived from the canvas transform; tiles are (re)drawn only
## when the covered tile window actually changes, so steady state allocates
## nothing and redraws only while the camera crosses a tile boundary.
##
## Every tile's variant and rotation is a pure function of its world tile
## coordinate and the run seed, so the pattern is reproducible and stable no
## matter which window first draws it. Variants land as sparse, soft-edged
## noise patches (N3-11) and every tile gets a seeded 90-degree-step rotation
## so identical stamps don't line up.

## N9-167: the floor belongs to the NIGHT, not to the engine. Each stage names
## its own art directory; a night whose set has not shipped falls back to the
## bamboo forest's, so a new stage is playable the day it is declared.
const STAGE_ART_DIR := "res://asset/stages/"
const FALLBACK_STAGE := "bamboo_forest"
const TILE_FILE := "ground_tile.png"
const VARIANT_FILES: Array[String] = [
	"patchy_grass.png", "dirt.png", "moss.png",
]
const TILE_SIZE_PX := 32.0
## Extra ground beyond the view edge so camera smoothing never exposes a bare
## strip between window updates.
const VIEW_MARGIN_PX := 64.0

## Density noise: high frequency relative to the field so patches span a
## handful of tiles ("large soft patches"), not single scattered cells.
const DENSITY_FREQUENCY := 0.09
## N9-33 (owner direction): N6-5 pushed this to 0.42 (~4-8% of tiles) to quiet
## the floor, but with the props now clustered into themed places the gaps
## between them read as black void rather than ground, which made each prop
## look dropped at random. Back down to ~12-18% coverage — enough that the
## floor is a PLACE, still far from the pre-N6-5 jumble.
## Measured bound lives in tests/unit/test_ground_layer.gd.
const DENSITY_THRESHOLD := 0.30
## Variants draw OVER the base tile rather than replacing it, so a patch stays
## close to the base tone. Raised with the density: at 0.55 the larger coverage
## was still too faint to register as ground.
const VARIANT_ALPHA := 0.68
## Much lower frequency so one patch reads as one variant flavor, not a
## jumble of three.
const TYPE_FREQUENCY := 0.015
const ROTATIONS: Array[float] = [0.0, PI / 2.0, PI, PI * 1.5]

var _base_texture: Texture2D
var _variant_textures: Array[Texture2D] = []
var _density_noise: FastNoiseLite
var _type_noise: FastNoiseLite
var _seed: int = 0
var _window := Rect2i()
var _built := false


## Where one stage's ground art lives, with the bamboo forest standing in for
## a night that has not shipped its own set yet. Static so the test can check
## the fallback without building a layer.
static func ground_path(stage_id: String, file_name: String) -> String:
	if not stage_id.is_empty():
		var own: String = STAGE_ART_DIR + stage_id + "/" + file_name
		if ResourceLoader.exists(own, "Texture2D"):
			return own
	return STAGE_ART_DIR + FALLBACK_STAGE + "/" + file_name


## Tile window (in tile coordinates) whose tiles fully cover `view` — the
## covered rect always contains the view rect by construction (tested).
static func tile_window(view: Rect2) -> Rect2i:
	var min_col: int = floori(view.position.x / TILE_SIZE_PX)
	var min_row: int = floori(view.position.y / TILE_SIZE_PX)
	var max_col: int = ceili(view.end.x / TILE_SIZE_PX)
	var max_row: int = ceili(view.end.y / TILE_SIZE_PX)
	return Rect2i(min_col, min_row, max_col - min_col, max_row - min_row)


## World rect the tile window covers.
static func window_rect(window: Rect2i) -> Rect2:
	return Rect2(
		Vector2(window.position) * TILE_SIZE_PX, Vector2(window.size) * TILE_SIZE_PX
	)


static func make_density_noise(field_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = field_seed
	noise.frequency = DENSITY_FREQUENCY
	return noise


static func make_type_noise(field_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = field_seed + 1
	noise.frequency = TYPE_FREQUENCY
	return noise


## Variant index for one world tile (-1 = base tile). Pure per-tile function
## of the seeded noises, so any window reproduces the same pattern.
static func tile_variant(
	density_noise: FastNoiseLite, type_noise: FastNoiseLite, col: int, row: int
) -> int:
	if density_noise.get_noise_2d(float(col), float(row)) <= DENSITY_THRESHOLD:
		return -1
	var type_value: float = (type_noise.get_noise_2d(float(col), float(row)) + 1.0) / 2.0
	return clampi(int(type_value * VARIANT_FILES.size()), 0, VARIANT_FILES.size() - 1)


## Seeded 90-degree-step rotation, a pure hash of the world tile coordinate —
## stable regardless of draw order or which window first contains the tile.
static func tile_rotation(field_seed: int, col: int, row: int) -> float:
	return ROTATIONS[hash(Vector3i(col, row, field_seed)) % ROTATIONS.size()]


## Pure field-rect layout kept for the headless suite: position, variant and
## rotation for every tile of a centered field, via the same per-tile
## functions the camera window draws with.
static func generate_layout(field: Dictionary, field_seed: int) -> Array[Dictionary]:
	var density_noise := make_density_noise(field_seed)
	var type_noise := make_type_noise(field_seed)
	var width: float = float(field.get("width_px", 0.0))
	var height: float = float(field.get("height_px", 0.0))
	var window := tile_window(Rect2(-width / 2.0, -height / 2.0, width, height))
	var layout: Array[Dictionary] = []
	for row: int in range(window.position.y, window.end.y):
		for col: int in range(window.position.x, window.end.x):
			layout.append({
				"position": Vector2(float(col), float(row)) * TILE_SIZE_PX,
				"variant": tile_variant(density_noise, type_noise, col, row),
				"rotation": tile_rotation(field_seed, col, row),
			})
	return layout


## Loads the ground textures and arms the seeded per-tile functions. Falls
## back to a flat FOREST_GROUND fill if the art is missing, same contract as
## StageField's prop placeholders: a missing texture never blocks the stage.
## The field dict is no longer consumed — coverage follows the camera — but
## the signature stays so the stage call site reads the same as StageField's.
func build(_field: Dictionary, field_seed: int, stage_id: String = "") -> void:
	_seed = field_seed
	_density_noise = make_density_noise(field_seed)
	_type_noise = make_type_noise(field_seed)
	_built = true
	var tile_path: String = ground_path(stage_id, TILE_FILE)
	if ResourceLoader.exists(tile_path, "Texture2D"):
		_base_texture = load(tile_path)
		_variant_textures = []
		for file_name: String in VARIANT_FILES:
			var path: String = ground_path(stage_id, "ground_variants/" + file_name)
			_variant_textures.append(load(path) if ResourceLoader.exists(path, "Texture2D") else null)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(_delta: float) -> void:
	if not _built:
		return
	var view: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var window := tile_window(view.grow(VIEW_MARGIN_PX))
	if window != _window:
		_window = window
		queue_redraw()


func _draw() -> void:
	if not _built or _window.size.x <= 0:
		return
	if _base_texture == null:
		draw_rect(window_rect(_window), UiPalette.FOREST_GROUND)
		return
	var tile_size := Vector2(TILE_SIZE_PX, TILE_SIZE_PX)
	var variant_tint := Color(1.0, 1.0, 1.0, VARIANT_ALPHA)
	for row: int in range(_window.position.y, _window.end.y):
		for col: int in range(_window.position.x, _window.end.x):
			var variant: int = tile_variant(_density_noise, _type_noise, col, row)
			var center: Vector2 = Vector2(float(col), float(row)) * TILE_SIZE_PX + tile_size / 2.0
			draw_set_transform(center, tile_rotation(_seed, col, row), Vector2.ONE)
			draw_texture_rect(_base_texture, Rect2(-tile_size / 2.0, tile_size), false)
			if variant >= 0 and _variant_textures[variant] != null:
				draw_texture_rect(
					_variant_textures[variant], Rect2(-tile_size / 2.0, tile_size),
					false, variant_tint
				)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
