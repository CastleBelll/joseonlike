class_name Pickup
extends XpOrb
## Prop-break pickup (N5-5): gold / health / nuke / magnet. Inherits the XP
## orb's magnet/collect physics wholesale — same progression.json "orb"
## numbers, same passive magnet bonus path — and swaps the visual per kind.
## Shape AND color differ per kind (DESIGN.md §2: never color alone). Pooled
## by the stage; the effect itself is applied by the stage on collection.

const RADIUS := 7.0
const OUTLINE_WIDTH := 1.0
const CROSS_ARM := 4.0
const CROSS_THICK := 3.0
const SPARK_POINTS := 4

var kind: String = Pickups.KIND_GOLD


func launch_pickup(
	at: Vector2, pickup_kind: String, player: Player, orb_config: Dictionary
) -> void:
	launch(at, 0, player, orb_config)
	kind = pickup_kind
	queue_redraw()


func _draw() -> void:
	match kind:
		Pickups.KIND_GOLD:
			# 엽전: gold disc with the square hole.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.GOLD)
			draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), UiPalette.INK)
		Pickups.KIND_HEALTH:
			# Green cross on a pale disc.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.LOOT_CORE)
			draw_rect(
				Rect2(-CROSS_ARM, -CROSS_THICK / 2.0, CROSS_ARM * 2.0, CROSS_THICK),
				UiPalette.SUCCESS
			)
			draw_rect(
				Rect2(-CROSS_THICK / 2.0, -CROSS_ARM, CROSS_THICK, CROSS_ARM * 2.0),
				UiPalette.SUCCESS
			)
		Pickups.KIND_NUKE:
			# Vermilion burst star — the "everything dies" pickup.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.VERMILION)
			for i: int in range(SPARK_POINTS):
				var angle: float = TAU * float(i) / float(SPARK_POINTS)
				draw_line(
					Vector2.ZERO, Vector2.from_angle(angle) * (RADIUS - 2.0),
					UiPalette.GOLD, 2.0
				)
			draw_circle(Vector2.ZERO, 2.0, UiPalette.LOOT_CORE)
		Pickups.KIND_MAGNET:
			# Blue horseshoe magnet.
			draw_circle(Vector2.ZERO, RADIUS, UiPalette.INK)
			draw_circle(Vector2.ZERO, RADIUS - OUTLINE_WIDTH, UiPalette.LOOT_RARE)
			draw_arc(Vector2(0.0, 1.0), 4.0, PI, TAU, 10, UiPalette.LOOT_CORE, 3.0)
			draw_rect(Rect2(-5.5, 1.0, 3.0, 3.0), UiPalette.LOOT_CORE)
			draw_rect(Rect2(2.5, 1.0, 3.0, 3.0), UiPalette.LOOT_CORE)
