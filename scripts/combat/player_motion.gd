class_name PlayerMotion
extends RefCounted
## Pure movement math for the player. Kept free of node/autoload state so the
## headless unit suite can drive it directly (tests/unit/test_player_motion.gd).

const FACING_RIGHT := 1
const FACING_LEFT := -1


## Raw input may exceed unit length (e.g. diagonal key presses); clamp so
## diagonal movement is not faster than cardinal movement.
static func velocity_for(move_input: Vector2, speed: float) -> Vector2:
	return move_input.limit_length(1.0) * speed


## Horizontal travel decides facing; vertical-only travel keeps the last facing.
static func facing_sign(velocity_x: float, current_facing: int) -> int:
	if velocity_x > 0.0:
		return FACING_RIGHT
	if velocity_x < 0.0:
		return FACING_LEFT
	return current_facing
