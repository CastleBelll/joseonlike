extends RefCounted
## N9-168 참격: the warrior's second art. A cleave is a SWING — what it hits
## has to depend on where he faces, or it is a smaller 벽사진 wearing a
## warrior's name. Guards the data contract and the cone itself.

const CHARACTERS_PATH := "res://data/characters.json"
const CLEAVE_ID := "chamgyeok"


func _characters() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	return data if data is Dictionary else {}


func _warrior_active(active_id: String) -> Dictionary:
	for active: Dictionary in (_characters().get("warrior", {}) as Dictionary).get("actives", []):
		if String(active.get("id", "")) == active_id:
			return active
	return {}


func test_the_warrior_carries_two_arts() -> bool:
	var actives: Array = (_characters().get("warrior", {}) as Dictionary).get("actives", [])
	var passed: bool = actives.size() >= 2
	if not passed:
		push_error("test_warrior_actives: the warrior has only %d active(s)" % actives.size())
		return false
	# Two arts that do the same thing are one art with two buttons.
	var kinds: Dictionary = {}
	for active: Dictionary in actives:
		kinds[String(active.get("type", ""))] = true
	if kinds.size() < 2:
		push_error("test_warrior_actives: both warrior arts share one type %s" % str(kinds.keys()))
		passed = false
	return passed


func test_the_cleave_declares_its_swing() -> bool:
	var cleave: Dictionary = _warrior_active(CLEAVE_ID)
	if cleave.is_empty():
		push_error("test_warrior_actives: 참격 is gone from the warrior's kit")
		return false
	var passed: bool = String(cleave.get("type", "")) == "cleave"
	for key: String in ["radius_px", "arc_deg", "damage", "cooldown_sec"]:
		if float(cleave.get(key, 0.0)) <= 0.0:
			push_error("test_warrior_actives: cleave.%s is missing or not positive" % key)
			passed = false
	# A 360-degree "cleave" is a burst; a slit is unusable in a melee scrum.
	var arc: float = float(cleave.get("arc_deg", 0.0))
	if arc < 60.0 or arc > 200.0:
		push_error("test_warrior_actives: cleave arc %.0f is not a swing" % arc)
		passed = false
	return passed


## The cone is the whole point: an enemy behind the warrior must survive a
## swing that an enemy in front of him does not.
func test_the_swing_only_reaches_what_it_faces() -> bool:
	var cleave: Dictionary = _warrior_active(CLEAVE_ID)
	var radius: float = float(cleave.get("radius_px", 150.0))
	var arc: float = deg_to_rad(float(cleave.get("arc_deg", 130.0)))
	var origin := Vector2.ZERO
	var aim: float = 0.0  # facing +x
	var positions: Array[Vector2] = [
		Vector2(radius * 0.5, 0.0),  # in front
		Vector2(-radius * 0.5, 0.0),  # behind
		Vector2(radius * 2.0, 0.0),  # out of reach
	]
	var radii: Array[float] = [8.0, 8.0, 8.0]
	var hits: Array[int] = WeaponMath.arc_hits(origin, aim, arc, radius, positions, radii)
	var passed: bool = hits.has(0) and not hits.has(1) and not hits.has(2)
	if not passed:
		push_error("test_warrior_actives: the swing hit %s, expected only the front" % str(hits))
	return passed
