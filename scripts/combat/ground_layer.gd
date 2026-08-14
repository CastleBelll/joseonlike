class_name GroundLayer
extends Node2D
## Tiles the play area with the delivered night-bamboo-forest ground art
## (N3-10). Variant choice is driven by the same per-run seed as the prop
## field, so a run's ground and props are both reproducible from one seed.
## The tile grid is built once in build(); _draw() replays a static command
## list (no per-frame allocation, no queue_redraw() after the first).

const TILE_PATH := "res://asset/stages/bamboo_forest/ground_tile.png"
const VARIANT_PATHS: Array[String] = [
	"res://asset/stages/bamboo_forest/ground_variants/patchy_grass.png",
	"res://asset/stages/bamboo_forest/ground_variants/dirt.png",
	"res://asset/stages/bamboo_forest/ground_variants/moss.png",
]
const TILE_SIZE_PX := 32.0
const VARIANT_CHANCE := 0.12

var _tiles: Array[Dictionary] = []
var _base_texture: Texture2D
var _variant_textures: Array[Texture2D] = []
var _fallback_size := Vector2.ZERO


## Pure per-tile layout: position plus a variant index (-1 = base tile), so
## the seeded reproducibility can be unit-tested without loading textures.
static func generate_layout(field: Dictionary, field_seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var width: float = float(field.get("width_px", 0.0))
	var height: float = float(field.get("height_px", 0.0))
	var half := Vector2(width, height) / 2.0
	var cols: int = int(width / TILE_SIZE_PX)
	var rows: int = int(height / TILE_SIZE_PX)
	var layout: Array[Dictionary] = []
	for row: int in range(rows):
		for col: int in range(cols):
			var pos := Vector2(
				-half.x + float(col) * TILE_SIZE_PX, -half.y + float(row) * TILE_SIZE_PX
			)
			var variant: int = -1
			if rng.randf() < VARIANT_CHANCE:
				variant = rng.randi_range(0, VARIANT_PATHS.size() - 1)
			layout.append({"position": pos, "variant": variant})
	return layout


## Loads the ground textures and builds the static tile list once. Falls
## back to a flat FOREST_GROUND rect if the art is missing, same contract as
## StageField's prop placeholders: a missing texture never blocks the stage.
func build(field: Dictionary, field_seed: int) -> void:
	_fallback_size = Vector2(float(field.get("width_px", 0.0)), float(field.get("height_px", 0.0)))
	if not ResourceLoader.exists(TILE_PATH, "Texture2D"):
		queue_redraw()
		return
	_base_texture = load(TILE_PATH)
	_variant_textures = []
	for path: String in VARIANT_PATHS:
		_variant_textures.append(load(path) if ResourceLoader.exists(path, "Texture2D") else null)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tiles = generate_layout(field, field_seed)
	queue_redraw()


func _draw() -> void:
	if _base_texture == null:
		if _fallback_size != Vector2.ZERO:
			draw_rect(Rect2(-_fallback_size / 2.0, _fallback_size), UiPalette.FOREST_GROUND)
		return
	var tile_size := Vector2(TILE_SIZE_PX, TILE_SIZE_PX)
	for tile: Dictionary in _tiles:
		var variant: int = int(tile["variant"])
		var texture: Texture2D = _base_texture
		if variant >= 0 and _variant_textures[variant] != null:
			texture = _variant_textures[variant]
		draw_texture_rect(texture, Rect2(tile["position"], tile_size), false)
