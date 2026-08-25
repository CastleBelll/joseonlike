extends RefCounted
## N10-3a 삼두구미: a monster that has to be taken apart. The rule the fight
## rests on is that the BODY takes nothing while a part still stands, so that is
## what these pin — a regression there turns the armoured phase into either an
## ordinary monster or an unkillable one.

const MONSTERS_PATH := "res://data/monsters.json"
const MONSTER_ID := "samdugumi"


func _monster() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).get(MONSTER_ID, {})
	return {}


## Hits land on the first part still standing, in declaration order, so the
## fight reads as taking the thing apart rather than as scattered damage.
func test_a_hit_lands_on_the_first_standing_part() -> bool:
	var parts := PackedFloat32Array([0.0, 12.0, 30.0])
	var picked: int = CombatMath.part_target(parts)
	if picked != 1:
		push_error("test_multipart: hit went to part %d, expected the first standing" % picked)
		return false
	return true


## With every part down the body is finally the target — the same question
## asked the other way, and the pair is what the enemy branches on.
func test_the_body_is_only_exposed_once_every_part_is_down() -> bool:
	var passed: bool = (
		not CombatMath.parts_cleared(PackedFloat32Array([0.0, 0.0, 1.0]))
		and CombatMath.parts_cleared(PackedFloat32Array([0.0, 0.0, 0.0]))
	)
	if not passed:
		push_error("test_multipart: the body's exposure does not follow the parts")
	return passed


## A monster with no parts is an ordinary monster. If an empty list read as
## "not cleared", every existing enemy in the game would turn invulnerable.
func test_no_parts_means_an_ordinary_monster() -> bool:
	if not CombatMath.parts_cleared(PackedFloat32Array()):
		push_error("test_multipart: an enemy with no parts came out armoured")
		return false
	return true


## The data contract: parts that can actually be broken, and breaking one has to
## cost the monster something — otherwise the phase is a wall with nothing on
## the other side of it.
func test_the_parts_are_breakable_and_each_costs_it_something() -> bool:
	var monster: Dictionary = _monster()
	if monster.is_empty():
		push_error("test_multipart: %s is not in monsters.json" % MONSTER_ID)
		return false
	var passed: bool = String(monster.get("behaviour", "")) == "multipart"
	var parts: Array = monster.get("parts", [])
	if parts.size() < 2:
		push_error("test_multipart: %s declares %d parts" % [MONSTER_ID, parts.size()])
		return false
	for part: Variant in parts:
		var entry: Dictionary = part
		if float(entry.get("hp", 0.0)) <= 0.0:
			push_error("test_multipart: a part has no hp and could never be broken")
			passed = false
		var on_break: Dictionary = entry.get("on_break", {})
		if on_break.is_empty():
			push_error("test_multipart: breaking a part changes nothing")
			passed = false
		for key: String in on_break:
			var value: float = float(on_break[key])
			if value <= 0.0 or value > 1.0:
				push_error("test_multipart: on_break.%s is not a reduction" % key)
				passed = false
	return passed


## The parts have to be worth more than a bite of the body, or the armoured
## phase is over before the player notices it happened.
func test_the_parts_outweigh_a_single_bite_of_the_body() -> bool:
	var monster: Dictionary = _monster()
	var parts_total: float = 0.0
	for part: Variant in monster.get("parts", []):
		parts_total += float((part as Dictionary).get("hp", 0.0))
	if parts_total < float(monster.get("hp", 0.0)) * 0.5:
		push_error("test_multipart: the parts are a formality next to the body")
		return false
	return true
