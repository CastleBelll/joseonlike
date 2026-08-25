extends RefCounted
## N10-1a 야광귀: the thief takes what is lying on the field and runs with it.
## The maths it runs on is pure, so the parts that decide whether a run loses a
## passive are tested here rather than left to a playtest that may not spawn one.

const MONSTERS_PATH := "res://data/monsters.json"
const STAGES_PATH := "res://data/stages.json"
const THIEF_ID := "yagwanggwi"


func _load(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _thief() -> Dictionary:
	return _load(MONSTERS_PATH).get(THIEF_ID, {})


## The nearest thing on the ground is what it goes for — not the first one
## spawned, which is what a naive loop would pick.
func test_the_thief_walks_to_the_nearest_loot() -> bool:
	var loot := PackedVector2Array([
		Vector2(400.0, 0.0), Vector2(60.0, 20.0), Vector2(-300.0, 90.0)
	])
	var picked: int = CombatMath.thief_target(Vector2.ZERO, loot)
	if picked != 1:
		push_error("test_thief_monster: picked %d, expected the nearest" % picked)
		return false
	return true


## An empty field has to answer "nothing", because the caller's fallback to
## plain chasing is what keeps the thief from standing still.
func test_an_empty_field_offers_nothing_to_steal() -> bool:
	var picked: int = CombatMath.thief_target(Vector2.ZERO, PackedVector2Array())
	if picked != -1:
		push_error("test_thief_monster: empty field returned %d" % picked)
		return false
	return true


## Reach is a boundary: standing exactly on the edge counts as a grab, and a
## missing number can never grab at all.
func test_the_grab_needs_a_declared_reach() -> bool:
	var passed: bool = (
		CombatMath.thief_takes(26.0, 26.0)
		and CombatMath.thief_takes(4.0, 26.0)
		and not CombatMath.thief_takes(26.1, 26.0)
		and not CombatMath.thief_takes(0.0, 0.0)
	)
	if not passed:
		push_error("test_thief_monster: the grab boundary is wrong")
	return passed


## Escape is measured from the PLAYER. A thief that has run a long way while
## the player kept pace has not got away with anything.
func test_the_escape_is_measured_from_the_player() -> bool:
	var passed: bool = (
		CombatMath.thief_escaped(1150.0, 1150.0)
		and CombatMath.thief_escaped(2000.0, 1150.0)
		and not CombatMath.thief_escaped(1149.0, 1150.0)
		and not CombatMath.thief_escaped(9999.0, 0.0)
	)
	if not passed:
		push_error("test_thief_monster: the escape boundary is wrong")
	return passed


## The data contract: a thief carries its four numbers, and its contact damage
## is zero. A thief that hurts on touch is a chaser in a costume — chasing it
## has to stay the player's own choice.
func test_the_thief_declares_a_complete_and_harmless_raid() -> bool:
	var monster: Dictionary = _thief()
	if monster.is_empty():
		push_error("test_thief_monster: %s is not in monsters.json" % THIEF_ID)
		return false
	var passed: bool = String(monster.get("behaviour", "")) == "thief"
	if not is_zero_approx(float(monster.get("damage", 1.0))):
		push_error("test_thief_monster: the thief deals contact damage")
		passed = false
	var theft: Dictionary = monster.get("theft", {})
	for field: String in ["seek_px", "grab_px", "escape_px", "flee_speed_mult"]:
		if float(theft.get(field, 0.0)) <= 0.0:
			push_error("test_thief_monster: theft.%s is missing or not positive" % field)
			passed = false
	# Running away has to outpace the walk in, or the player just strolls after
	# it and the theft is never a decision.
	if float(theft.get("flee_speed_mult", 0.0)) <= 1.0:
		push_error("test_thief_monster: the thief flees no faster than it walks")
		passed = false
	# It must be able to reach what it saw: a seek range under the grab reach
	# would mean it only ever takes what it is already standing on.
	if float(theft.get("seek_px", 0.0)) <= float(theft.get("grab_px", 0.0)):
		push_error("test_thief_monster: seek_px does not clear grab_px")
		passed = false
	return passed


## It has to actually appear in a run, and sparsely: the field lays down a
## passive every 22 seconds, so thieves arriving faster than that would tax
## every one of them instead of interrupting now and then.
func test_the_thief_arrives_rarely_in_the_ruined_village() -> bool:
	var waves: Array = _load(STAGES_PATH).get("ruined_village", {}).get("waves", [])
	var found: int = 0
	var passed: bool = true
	for wave: Variant in waves:
		var entry: Dictionary = wave
		if String(entry.get("monster_id", "")) != THIEF_ID:
			continue
		found += 1
		if float(entry.get("interval_sec", 0.0)) < 22.0:
			push_error("test_thief_monster: thieves arrive faster than the field lays loot")
			passed = false
	if found == 0:
		push_error("test_thief_monster: no stage ever spawns the thief")
		passed = false
	return passed


## 체 (N10-1b): a sieve is a full stop, and the boundary is the radius itself.
func test_a_sieve_holds_the_thief_at_its_edge() -> bool:
	var sieves: Array[Dictionary] = [
		{"position": Vector2(200.0, 0.0), "radius": 150.0},
		{"position": Vector2(-800.0, 0.0), "radius": 0.0},
	]
	var passed: bool = (
		CombatMath.thief_stalled(Vector2(200.0, 0.0), sieves)
		and CombatMath.thief_stalled(Vector2(350.0, 0.0), sieves)
		and not CombatMath.thief_stalled(Vector2(351.0, 0.0), sieves)
		# A sieve with no radius holds nothing, the same rule the lights use.
		and not CombatMath.thief_stalled(Vector2(-800.0, 0.0), sieves)
		and not CombatMath.thief_stalled(Vector2.ZERO, [])
	)
	if not passed:
		push_error("test_thief_monster: the sieve boundary is wrong")
	return passed


## The counterplay has to be reachable: a sieve that no theme ever places is a
## rule the player can never use.
func test_some_theme_actually_places_a_sieve() -> bool:
	var props: Dictionary = _load("res://data/props.json")
	var catalog: Dictionary = props.get("props", {})
	var sieve_ids: Array[String] = []
	for prop_id: String in catalog:
		if float((catalog[prop_id] as Dictionary).get("sieve_radius_px", 0.0)) > 0.0:
			sieve_ids.append(prop_id)
	if sieve_ids.is_empty():
		push_error("test_thief_monster: no prop declares sieve_radius_px")
		return false
	var themes: Array = props.get("field", {}).get("themes", [])
	for theme: Variant in themes:
		for prop_id: String in sieve_ids:
			if (theme as Dictionary).get("props", {}).has(prop_id):
				return true
	push_error("test_thief_monster: a sieve exists but no theme ever places one")
	return false
