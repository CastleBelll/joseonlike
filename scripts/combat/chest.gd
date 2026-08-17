class_name Chest
extends Node2D
## Elite reward chest (N5-5). Dropped where an elite dies; opens when the
## player walks over it (no magnet pull — the walk IS the interaction, VS
## chest grammar). Pooled by the stage; the reward roll and the popup
## sequence live in the stage. Code-drawn placeholder until chest art ships
## (registered in ASSET_REQUIREMENTS.md).

signal opened(chest: Chest)

const BODY_W := 18.0
const BODY_H := 13.0
const LID_H := 5.0
const OUTLINE_PX := 1.0
const GLOW_RADIUS := 16.0
const GLOW_ALPHA_MAX := 0.3
const PULSE_HZ := 1.6

var _player: Player
var _open_radius_squared: float = 0.0
var _phase: float = 0.0
## One-shot latch: opened must fire exactly once per placement, even if the
## handler ever stops releasing this node synchronously.
var _opened: bool = false


func place(at: Vector2, player: Player, open_radius: float) -> void:
	global_position = at
	_player = player
	_open_radius_squared = open_radius * open_radius
	_phase = 0.0
	_opened = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _player == null or _opened:
		return
	_phase += delta * PULSE_HZ
	queue_redraw()
	var distance_squared: float = global_position.distance_squared_to(
		_player.global_position
	)
	if distance_squared <= _open_radius_squared:
		_opened = true
		opened.emit(self)


func _draw() -> void:
	# Gold pulse under the box so the payoff reads across the dark field.
	var pulse: float = 0.5 + 0.5 * sin(_phase * TAU)
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(UiPalette.GOLD, GLOW_ALPHA_MAX * pulse))
	var body := Rect2(-BODY_W / 2.0, -BODY_H + LID_H, BODY_W, BODY_H)
	draw_rect(body.grow(OUTLINE_PX), UiPalette.INK)
	draw_rect(body, UiPalette.WOOD)
	# Darker lid band + gold clasp: reads "chest", not "crate".
	draw_rect(
		Rect2(-BODY_W / 2.0, -BODY_H + LID_H, BODY_W, LID_H), UiPalette.WOOD_BORDER
	)
	draw_rect(Rect2(-2.0, -BODY_H / 2.0 + 2.0, 4.0, 5.0), UiPalette.GOLD)
