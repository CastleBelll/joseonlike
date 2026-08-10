class_name PlaceholderArt
extends RefCounted
## Sprite fallback: load the authored texture when it exists, otherwise generate
## a flat colour swatch. Combat must never block on the art pass, and a missing
## res://assets/... path must not crash a run.
##
## Autoload-free on purpose (see CombatMath).

const PLACEHOLDER_SIZE_PX: int = 16

static var _cache: Dictionary = {}


## Returns the texture at `path`, or a `tint` coloured placeholder when the file
## is absent or is not a Texture2D.
static func texture_or_placeholder(path: String, tint: Color) -> Texture2D:
	if not path.is_empty() and ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
		push_warning("PlaceholderArt: %s is not a Texture2D, using placeholder" % path)
	return placeholder(tint)


## Cached solid-colour texture. Cached because dozens of pooled enemies would
## otherwise each allocate an identical image.
static func placeholder(tint: Color) -> Texture2D:
	var key: String = tint.to_html(true)
	var cached: Variant = _cache.get(key)
	if cached is Texture2D:
		return cached as Texture2D
	var image := Image.create_empty(PLACEHOLDER_SIZE_PX, PLACEHOLDER_SIZE_PX, false, Image.FORMAT_RGBA8)
	image.fill(tint)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
