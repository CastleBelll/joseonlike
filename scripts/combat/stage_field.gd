class_name StageField
extends Node2D
## Procedurally scattered night-bamboo-forest props (N3-9). All layout numbers
## and the prop catalogue live in data/props.json. Generation is static and
## seed-deterministic so the headless suite can verify reproducibility, the
## solid-spacing rule and the spawn-clear rule without a SceneTree. Solid
## props are StaticBody2D obstacles on LAYER_OBSTACLE; decor draws under the
## characters in a separate non-Y-sorted layer. Everything is built once at
## run start — no per-frame allocation.

const PROPS_PATH := "res://data/props.json"

## Physics layer bit for solid props. Player and enemies add it to their
## collision_mask; enemies keep ignoring the player and each other.
const LAYER_OBSTACLE := 4

const OUTLINE_PX := 1.0
const SHAPE_RECT := "rect"
const SHAPE_ROUND := "round"

## Palette tokens a prop's "placeholder" field may name. Also the validator's
## allowlist, so a typo in data fails validate_data instead of drawing ink.
const PLACEHOLDER_COLORS: Dictionary = {
	"bamboo": UiPalette.PROP_BAMBOO,
	"rock": UiPalette.PROP_ROCK,
	"log": UiPalette.PROP_LOG,
	"water": UiPalette.PROP_WATER,
	"grass": UiPalette.DECOR_GRASS,
	"fern": UiPalette.DECOR_FERN,
	"pebble": UiPalette.DECOR_PEBBLE,
	"lantern": UiPalette.PROP_LANTERN,
	"shrine": UiPalette.PROP_SHRINE,
	"fog": UiPalette.DECOR_FOG,
}


static func load_config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROPS_PATH))
	if data is not Dictionary:
		push_error("stage_field: cannot parse " + PROPS_PATH)
		return {}
	return data


## Deterministic scatter around the field center (the player spawn at origin):
## the same seed always yields the identical placement list. Entries are
## {"id": String, "position": Vector2, "solid": bool}, solids first.
static func generate(
	catalog: Dictionary, field: Dictionary, field_seed: int
) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var placements: Array[Dictionary] = []
	_scatter(placements, catalog, field, rng, true, int(field.get("solid_count", 0)))
	_scatter(placements, catalog, field, rng, false, int(field.get("decor_count", 0)))
	return placements


## Cumulative-weight pick; `roll` is in [0, 1). Pure for testability.
static func pick_weighted(weights: Array[float], roll: float) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var target: float = roll * total
	var cumulative: float = 0.0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if target < cumulative:
			return i
	return weights.size() - 1


## Half-footprint used by the spacing and spawn-clear rules: solids measure by
## their collision box, decor by its sprite size.
static func spacing_radius(prop: Dictionary) -> float:
	if bool(prop.get("solid", false)):
		var box: Array = prop.get("collision", [])
		if box.size() == 4:
			return maxf(float(box[2]), float(box[3])) / 2.0
	var size: Array = prop.get("size", [])
	if size.size() == 2:
		return maxf(float(size[0]), float(size[1])) / 2.0
	return 0.0


static func _scatter(
	placements: Array[Dictionary],
	catalog: Dictionary,
	field: Dictionary,
	rng: RandomNumberGenerator,
	solid: bool,
	count: int
) -> void:
	var ids: Array[String] = []
	var weights: Array[float] = []
	for id: String in catalog:
		if bool((catalog[id] as Dictionary).get("solid", false)) == solid:
			ids.append(id)
			weights.append(float((catalog[id] as Dictionary).get("weight", 0.0)))
	if ids.is_empty():
		return
	var margin: float = float(field.get("edge_margin_px", 0.0))
	var half := Vector2(
		float(field.get("width_px", 0.0)) / 2.0 - margin,
		float(field.get("height_px", 0.0)) / 2.0 - margin
	)
	var attempts: int = int(field.get("max_attempts_per_prop", 1))
	for i: int in range(count):
		for attempt: int in range(attempts):
			var id: String = ids[pick_weighted(weights, rng.randf())]
			var pos := Vector2(
				rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y)
			)
			if solid and not _solid_fits(placements, catalog, field, catalog[id], pos):
				continue
			placements.append({"id": id, "position": pos, "solid": solid})
			break


## Solids must stay out of the spawn-clear circle and keep min_gap_px of air
## to every other solid, so the run never starts trapped and props never fuse.
static func _solid_fits(
	placements: Array[Dictionary],
	catalog: Dictionary,
	field: Dictionary,
	prop: Dictionary,
	pos: Vector2
) -> bool:
	var radius: float = spacing_radius(prop)
	if pos.length() < float(field.get("spawn_clear_radius_px", 0.0)) + radius:
		return false
	var gap: float = float(field.get("min_gap_px", 0.0))
	for placed: Dictionary in placements:
		if not bool(placed["solid"]):
			continue
		var other_radius: float = spacing_radius(catalog[placed["id"]])
		if pos.distance_to(placed["position"]) < radius + other_radius + gap:
			return false
	return true


## Instantiates the generated layout: solid props become Y-sorted StaticBody2D
## children of this node, decor becomes plain visuals under `decor_parent`.
func build(
	catalog: Dictionary, field: Dictionary, decor_parent: Node2D, field_seed: int
) -> void:
	y_sort_enabled = true
	for placement: Dictionary in generate(catalog, field, field_seed):
		var prop: Dictionary = catalog[placement["id"]]
		var pos: Vector2 = placement["position"]
		if bool(placement["solid"]):
			var body: StaticBody2D = _make_solid(prop)
			body.position = pos
			add_child(body)
		else:
			var visual: Node2D = _make_visual(prop)
			visual.position = pos
			decor_parent.add_child(visual)


func _make_solid(prop: Dictionary) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = LAYER_OBSTACLE
	body.collision_mask = 0
	var box: Array = prop.get("collision", [])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(box[2]), float(box[3]))
	shape.shape = rect
	shape.position = Vector2(
		float(box[0]) + float(box[2]) / 2.0, float(box[1]) + float(box[3]) / 2.0
	)
	body.add_child(shape)
	body.add_child(_make_visual(prop))
	return body


## Uses the real texture when the AC-4 art exists at the declared path;
## otherwise a palette-token placeholder shape of the same logical size, so
## the art lands later with zero code change.
func _make_visual(prop: Dictionary) -> Node2D:
	var size_field: Array = prop.get("size", [])
	var logical_size := Vector2(float(size_field[0]), float(size_field[1]))
	var texture_path: String = String(prop.get("texture", ""))
	if ResourceLoader.exists(texture_path, "Texture2D"):
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Bottom-center at the node origin so Y-sort reads the prop's base.
		sprite.offset = Vector2(0.0, -sprite.texture.get_size().y / 2.0)
		sprite.scale = logical_size / sprite.texture.get_size()
		return sprite
	var visual := PropVisual.new()
	visual.color = PLACEHOLDER_COLORS.get(String(prop.get("placeholder", "")), UiPalette.INK)
	visual.size = logical_size
	visual.round_shape = String(prop.get("shape", SHAPE_RECT)) == SHAPE_ROUND
	return visual


## Flat placeholder shape with a 1px ink outline, bottom-center at the origin.
class PropVisual:
	extends Node2D

	var color := Color()
	var size := Vector2.ZERO
	var round_shape := false

	func _draw() -> void:
		if round_shape:
			# Squash the circle to the prop's aspect so puddles read flat.
			draw_set_transform(
				Vector2(0.0, -size.y / 2.0), 0.0, Vector2(1.0, size.y / size.x)
			)
			draw_circle(Vector2.ZERO, size.x / 2.0, UiPalette.INK)
			draw_circle(Vector2.ZERO, size.x / 2.0 - OUTLINE_PX, color)
			return
		var rect := Rect2(Vector2(-size.x / 2.0, -size.y), size)
		draw_rect(rect, UiPalette.INK)
		draw_rect(rect.grow(-OUTLINE_PX), color)
