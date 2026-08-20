extends RefCounted
## N9-83: the ground has to actually be ground.
##
## The shipped tiles were 99.4% one colour and the four of them sat within
## 5/255 of each other, so GroundLayer's density noise, per-tile rotation and
## 68%-alpha variant blend were all invisible work — you cannot rotate a flat
## colour into a different flat colour. Nothing failed, because nothing looked.
## These tests look.

const BASE := "res://asset/stages/bamboo_forest/ground_tile.png"
const VARIANTS: Array[String] = [
	"res://asset/stages/bamboo_forest/ground_variants/dirt.png",
	"res://asset/stages/bamboo_forest/ground_variants/moss.png",
	"res://asset/stages/bamboo_forest/ground_variants/patchy_grass.png",
]

## A tile needs enough steps to read as a surface at 32px.
const MIN_COLOURS := 3
## No single value may own the tile. 70% still leaves an obvious dominant tone;
## the old tiles were at 99.4%.
const MAX_DOMINANT_SHARE := 0.7
## Channel distance a variant must keep from the base, summed over RGB. The old
## variants were 5 apart in total and were invisible under a 68% blend.
const MIN_VARIANT_DISTANCE := 24
## How far the fallback fill may drift from the tile it stands in for.
const MAX_FALLBACK_DRIFT := 6


## Logical-size colour histogram: the files are 16x exports, so they are read
## down to the 32x32 the art actually is before counting.
func _histogram(path: String) -> Dictionary:
	var image: Image = (load(path) as Texture2D).get_image()
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var counts: Dictionary = {}
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var key: int = image.get_pixel(x, y).to_rgba32()
			counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _dominant(path: String) -> Color:
	var counts: Dictionary = _histogram(path)
	var best_key: int = 0
	var best: int = -1
	for key: int in counts:
		if int(counts[key]) > best:
			best = int(counts[key])
			best_key = key
	return Color(best_key)


func _channel_distance(a: Color, b: Color) -> int:
	return (
		absi(int(a.r8) - int(b.r8))
		+ absi(int(a.g8) - int(b.g8))
		+ absi(int(a.b8) - int(b.b8))
	)


func test_every_tile_carries_more_than_one_value() -> bool:
	var passed: bool = true
	for path: String in ([BASE] + VARIANTS):
		var counts: Dictionary = _histogram(path)
		if counts.size() < MIN_COLOURS:
			push_error("test_ground_tiles: %s has only %d colours" % [path, counts.size()])
			passed = false
	return passed


func test_no_tile_is_a_flat_fill() -> bool:
	var passed: bool = true
	for path: String in ([BASE] + VARIANTS):
		var counts: Dictionary = _histogram(path)
		var total: float = 0.0
		var top: float = 0.0
		for key: int in counts:
			total += float(counts[key])
			top = maxf(top, float(counts[key]))
		if total <= 0.0 or top / total > MAX_DOMINANT_SHARE:
			push_error(
				"test_ground_tiles: %s is %.0f%% one colour" % [path, top / total * 100.0]
			)
			passed = false
	return passed


## Variants exist so a patch reads as a different SURFACE. Two tones a few units
## apart, blended at 68% alpha, make a patch nobody can see — which is what
## shipped.
func test_variants_are_distinguishable_from_the_base() -> bool:
	var base: Color = _dominant(BASE)
	var passed: bool = true
	for path: String in VARIANTS:
		var distance: int = _channel_distance(base, _dominant(path))
		if distance < MIN_VARIANT_DISTANCE:
			push_error(
				"test_ground_tiles: %s is only %d from the base tile" % [path, distance]
			)
			passed = false
	return passed


## The fallback fill has to be the floor's colour. It only draws when the tile
## art fails to load, so a drift between the two shows up as the ground changing
## hue at exactly the moment nobody is watching.
func test_palette_fallback_matches_the_shipped_tile() -> bool:
	var distance: int = _channel_distance(_dominant(BASE), UiPalette.FOREST_GROUND)
	if distance > MAX_FALLBACK_DRIFT:
		push_error(
			"test_ground_tiles: FOREST_GROUND is %d from the tile's dominant value"
			% distance
		)
		return false
	return true
