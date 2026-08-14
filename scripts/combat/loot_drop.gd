class_name LootDrop
extends XpOrb
## Material drop (N4-1). Inherits the XP orb's magnet/collect physics wholesale
## — same progression.json "orb" numbers, same passive magnet bonus path —
## and only swaps the visual for a tier-tinted diamond. Pooled by the stage.

const DIAMOND_RADIUS := 6.0
const CORE_SCALE := 0.45
const OUTLINE_WIDTH := 1.0

var loot_id: String = ""

var _tint: Color = UiPalette.LOOT_COMMON


func launch_loot(
	at: Vector2, id: String, tint: Color, player: Player, orb_config: Dictionary
) -> void:
	launch(at, 0, player, orb_config)
	loot_id = id
	_tint = tint
	queue_redraw()


func _draw() -> void:
	var outer: PackedVector2Array = _diamond(DIAMOND_RADIUS)
	draw_colored_polygon(outer, _tint)
	draw_colored_polygon(_diamond(DIAMOND_RADIUS * CORE_SCALE), UiPalette.LOOT_CORE)
	draw_polyline(outer + PackedVector2Array([outer[0]]), UiPalette.INK, OUTLINE_WIDTH)


func _diamond(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -radius), Vector2(radius, 0.0),
		Vector2(0.0, radius), Vector2(-radius, 0.0),
	])
