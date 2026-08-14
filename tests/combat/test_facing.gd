extends RefCounted
## CharacterMotion.facing_sign: horizontal component decides, vertical or zero
## movement keeps the current facing.


func run() -> Array[String]:
	var failures: Array[String] = []

	if CharacterMotion.facing_sign(Vector2.RIGHT, CharacterMotion.FACING_LEFT) != CharacterMotion.FACING_RIGHT:
		failures.append("moving right must face right")
	if CharacterMotion.facing_sign(Vector2.LEFT, CharacterMotion.FACING_RIGHT) != CharacterMotion.FACING_LEFT:
		failures.append("moving left must face left")
	if CharacterMotion.facing_sign(Vector2(0.0, -1.0), CharacterMotion.FACING_LEFT) != CharacterMotion.FACING_LEFT:
		failures.append("pure vertical movement must keep the current facing")
	if CharacterMotion.facing_sign(Vector2.ZERO, CharacterMotion.FACING_RIGHT) != CharacterMotion.FACING_RIGHT:
		failures.append("standing still must keep the current facing")
	if CharacterMotion.facing_sign(Vector2(0.3, -0.95), CharacterMotion.FACING_LEFT) != CharacterMotion.FACING_RIGHT:
		failures.append("a diagonal with any rightward component must face right")

	return failures
