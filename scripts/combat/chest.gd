class_name Chest
extends Node2D
## Elite reward chest (N5-5). Dropped where an elite dies; opens when the
## player walks over it (no magnet pull — the walk IS the interaction, VS
## chest grammar). Pooled by the stage; the reward roll and the popup
## sequence live in the stage. Code-drawn placeholder until chest art ships
## (registered in ASSET_REQUIREMENTS.md).

signal opened(chest: Chest)

const GLOW_RADIUS := 16.0
const GLOW_ALPHA_MAX := 0.3
const PULSE_HZ := 1.6
## N9-5d: the authored 반닫이 chest sprite replaces the code-drawn box.
const CHEST_TEXTURE := "res://asset/pickups/chest.png"

var _player: Player
var _open_radius_squared: float = 0.0
var _phase: float = 0.0
## One-shot latch: opened must fire exactly once per placement, even if the
## handler ever stops releasing this node synchronously.
var _opened: bool = false
const CHEST_DRAW_PX := 40.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "ChestSprite"
	# HD art draws at a fixed logical size — the owner's 1254px chest rendered
	# 1:1 as a building (owner: 보물상자 애셋이 너무 크게 나와). LANCZOS-cached
	# to size so the downscale stays clean.
	_sprite.texture = UiIcons.badge(load(CHEST_TEXTURE), int(CHEST_DRAW_PX))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Feet on the drop point: shift up by half the sprite height.
	_sprite.position = Vector2(0.0, -_sprite.texture.get_height() / 2.0)
	add_child(_sprite)


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
	# Gold pulse under the sprite so the payoff reads across the dark field.
	var pulse: float = 0.5 + 0.5 * sin(_phase * TAU)
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(UiPalette.GOLD, GLOW_ALPHA_MAX * pulse))
