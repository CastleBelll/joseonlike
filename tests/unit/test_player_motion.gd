extends RefCounted
## Guards the N3-1 player movement math and the data-driven speed contract.

const EPSILON := 0.001
const SPEED := 90.0


func test_diagonal_input_is_normalized() -> bool:
	var velocity: Vector2 = PlayerMotion.velocity_for(Vector2(1.0, 1.0), SPEED)
	return absf(velocity.length() - SPEED) < EPSILON


func test_zero_input_yields_zero_velocity() -> bool:
	return PlayerMotion.velocity_for(Vector2.ZERO, SPEED) == Vector2.ZERO


func test_sub_unit_input_scales_speed() -> bool:
	var velocity: Vector2 = PlayerMotion.velocity_for(Vector2(0.5, 0.0), SPEED)
	return absf(velocity.x - SPEED * 0.5) < EPSILON and velocity.y == 0.0


func test_facing_flips_with_horizontal_direction() -> bool:
	var to_left: int = PlayerMotion.facing_sign(-12.0, PlayerMotion.FACING_RIGHT)
	var to_right: int = PlayerMotion.facing_sign(30.0, PlayerMotion.FACING_LEFT)
	return to_left == PlayerMotion.FACING_LEFT and to_right == PlayerMotion.FACING_RIGHT


func test_facing_held_when_moving_vertically_only() -> bool:
	return PlayerMotion.facing_sign(0.0, PlayerMotion.FACING_LEFT) == PlayerMotion.FACING_LEFT


## N10-12: pinned to the literal speed before, so it broke on every class
## rebalance. The contract is that the loader reads the file — so the test reads
## it too rather than carrying a copy of the number that has to be maintained.
func test_player_speed_reads_characters_json() -> bool:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/characters.json")
	)
	if parsed is not Dictionary:
		return false
	var entry: Dictionary = (parsed as Dictionary).get(SaveProfile.DEFAULT_CHARACTER, {})
	var declared: float = float(entry.get("base_speed", 0.0))
	return declared > 0.0 and absf(Player.load_move_speed() - declared) < EPSILON
