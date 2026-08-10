class_name PlayerInput
extends Node
## Movement input adapter for the player.
##
## Two sources feed the same vector: keyboard/gamepad (ui_* actions) and a screen
## drag vector pushed in by whoever owns the touch UI. meta-ui can call
## set_drag_vector() from a virtual joystick, or swap this node for any Node that
## exposes get_move_vector() -> Vector2, without combat code changing.

## Below this the stick is treated as centred; raw touch deltas jitter around zero.
const DEAD_ZONE: float = 0.15

@export var keyboard_enabled: bool = true

var _drag_vector: Vector2 = Vector2.ZERO


## Normalized stick vector, magnitude 0..1. Values longer than 1 are clamped so a
## far drag cannot outrun the character's speed stat.
func set_drag_vector(vector: Vector2) -> void:
	_drag_vector = vector if vector.length_squared() <= 1.0 else vector.normalized()


func clear_drag() -> void:
	_drag_vector = Vector2.ZERO


func get_move_vector() -> Vector2:
	if _drag_vector.length() >= DEAD_ZONE:
		return _drag_vector
	if not keyboard_enabled:
		return Vector2.ZERO
	return Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
