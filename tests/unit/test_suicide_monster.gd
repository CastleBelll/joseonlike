extends RefCounted
## 화약 도깨비 (N9-165): the bomb's contract. The fuse lights once at arm's
## length and never re-lights, the blast covers exactly its radius, and the
## data carries the four numbers the stage reads.

const MONSTERS_PATH := "res://data/monsters.json"
const BOMB_ID := "powder_dokkaebi"


func _monsters() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))
	return data if data is Dictionary else {}


func test_the_bomb_declares_its_blast() -> bool:
	var bomb: Dictionary = _monsters().get(BOMB_ID, {})
	var passed: bool = String(bomb.get("behaviour", "")) == "suicide"
	if not passed:
		push_error("test_suicide_monster: %s no longer behaves as a suicide" % BOMB_ID)
		return false
	var blast: Dictionary = bomb.get("suicide", {})
	for key: String in ["trigger_px", "fuse_sec", "radius_px", "damage"]:
		if float(blast.get(key, 0.0)) <= 0.0:
			push_error("test_suicide_monster: suicide.%s is missing or not positive" % key)
			passed = false
	# The warning has to be worth reacting to: a blast the player cannot leave
	# is just damage. Running out of a lit fuse must be physically possible.
	var reach: float = float(blast.get("radius_px", 0.0)) - float(blast.get("trigger_px", 0.0))
	var escape_speed: float = reach / maxf(float(blast.get("fuse_sec", 0.0)), 0.001)
	if escape_speed > 120.0:
		push_error(
			"test_suicide_monster: escaping needs %.0f px/s, past what a player runs"
			% escape_speed
		)
		passed = false
	return passed


func test_fuse_lights_once_at_arms_length() -> bool:
	var trigger: float = 44.0
	var passed: bool = (
		CombatMath.fuse_lights(trigger - 1.0, trigger, false)
		and CombatMath.fuse_lights(trigger, trigger, false)
		and not CombatMath.fuse_lights(trigger + 1.0, trigger, false)
	)
	# A lit fuse is a commitment: backing off must not put it out, or the bomb
	# would flicker in and out of its warning while it chases.
	passed = passed and not CombatMath.fuse_lights(trigger - 1.0, trigger, true)
	passed = passed and not CombatMath.fuse_lights(999.0, trigger, true)
	# No trigger distance means no fuse at all.
	passed = passed and not CombatMath.fuse_lights(0.0, 0.0, false)
	if not passed:
		push_error("test_suicide_monster: fuse_lights no longer lights once, at reach")
	return passed


## One fuse, one blast. A probe caught 71 detonations from a single fuse
## before this guard landed: the body lives a frame past its own death, so the
## countdown kept firing every pass once it had emptied.
func test_one_fuse_makes_one_blast() -> bool:
	var passed: bool = (
		CombatMath.fuse_fires(0.0, false)
		and CombatMath.fuse_fires(-0.4, false)
		and not CombatMath.fuse_fires(0.2, false)
		and not CombatMath.fuse_fires(-0.4, true)
		and not CombatMath.fuse_fires(0.0, true)
	)
	if not passed:
		push_error("test_suicide_monster: the fuse fires twice or never")
	return passed


func test_blast_covers_exactly_its_radius() -> bool:
	var radius: float = 98.0
	var passed: bool = (
		CombatMath.blast_covers(0.0, radius)
		and CombatMath.blast_covers(radius, radius)
		and not CombatMath.blast_covers(radius + 0.5, radius)
		and not CombatMath.blast_covers(1.0, 0.0)
	)
	if not passed:
		push_error("test_suicide_monster: blast_covers disagrees with its own radius")
	return passed
