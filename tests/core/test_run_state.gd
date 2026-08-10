extends RefCounted
## RunState: XP curve, multi-level-up, level-up choice validity and exhaustion,
## and passive stat aggregation.

const GAME_DATA_SCRIPT := preload("res://scripts/core/game_data.gd")
const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")

const FIXTURES_DIR := "res://tests/core/fixtures"

const VALID_KINDS: Array[String] = [
	RUN_STATE_SCRIPT.KIND_WEAPON_NEW,
	RUN_STATE_SCRIPT.KIND_WEAPON_UPGRADE,
	RUN_STATE_SCRIPT.KIND_PASSIVE,
]
const REQUIRED_CHOICE_KEYS: Array[String] = [
	"id", "kind", "name_ko", "name_en", "description_ko",
]

const ATTACK_SPEED_PER_STACK := 0.08
const FLOAT_TOLERANCE := 0.0001


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_xp_curve_shape())
	failures.append_array(_test_multi_level_up_from_one_pickup())
	failures.append_array(_test_level_reached_offers_valid_choices())
	failures.append_array(_test_exhausted_pool_shrinks_choices())
	failures.append_array(_test_apply_choice_mutates_run())
	failures.append_array(_test_weapon_slot_cap_holds())
	failures.append_array(_test_stat_total_aggregates_stacks())
	return failures


func _test_xp_curve_shape() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()

	var first_cost: int = run.xp_to_next(RUN_STATE_SCRIPT.FIRST_LEVEL)
	if first_cost != RUN_STATE_SCRIPT.XP_CURVE_BASE:
		failures.append("xp_to_next(1) is %d, expected the curve base %d" % [
			first_cost, RUN_STATE_SCRIPT.XP_CURVE_BASE,
		])

	for level: int in range(1, 12):
		if run.xp_to_next(level + 1) < run.xp_to_next(level):
			failures.append("xp_to_next is not monotonic between level %d and %d" % [level, level + 1])
			break

	_drop(run)
	return failures


func _test_multi_level_up_from_one_pickup() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()

	var three_levels: int = run.xp_to_next(1) + run.xp_to_next(2) + run.xp_to_next(3)
	var levels_seen: Array[int] = []
	var handler := func(new_level: int, _choices: Array) -> void:
		levels_seen.append(new_level)

	EventBus.level_reached.connect(handler)
	_mute_expected_errors(true)
	run.add_xp(three_levels)
	_mute_expected_errors(false)
	EventBus.level_reached.disconnect(handler)

	if run.level != 4:
		failures.append("one pickup worth three levels left level at %d, expected 4" % run.level)
	if run.xp != 0:
		failures.append("exact three-level pickup left %d spare xp, expected 0" % run.xp)
	if str(levels_seen) != str([2, 3, 4]):
		failures.append("level_reached fired for %s, expected [2, 3, 4]" % str(levels_seen))

	_drop(run)
	return failures


func _test_level_reached_offers_valid_choices() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()
	run.begin("taoist", "bamboo_forest")

	var captured: Array[Dictionary] = []
	var handler := func(_new_level: int, choices: Array) -> void:
		for choice: Dictionary in choices:
			captured.append(choice)

	EventBus.level_reached.connect(handler)
	run.add_xp(run.xp_to_next(run.level))
	EventBus.level_reached.disconnect(handler)

	if captured.size() != RUN_STATE_SCRIPT.CHOICES_PER_LEVEL:
		failures.append("a fresh run offered %d choices, expected %d" % [
			captured.size(), RUN_STATE_SCRIPT.CHOICES_PER_LEVEL,
		])

	var seen_ids: Dictionary = {}
	for choice: Dictionary in captured:
		for key: String in REQUIRED_CHOICE_KEYS:
			if not choice.has(key):
				failures.append("a choice is missing the \"%s\" key" % key)

		var kind: String = String(choice.get("kind", ""))
		if not VALID_KINDS.has(kind):
			failures.append("choice kind \"%s\" is outside the frozen set" % kind)

		var choice_id: String = String(choice.get("id", ""))
		if seen_ids.has(choice_id):
			failures.append("choice id \"%s\" was offered twice in one level" % choice_id)
		seen_ids[choice_id] = true

		failures.append_array(_check_choice_is_not_exhausted(run, choice_id, kind))

	_drop(run)
	return failures


func _test_exhausted_pool_shrinks_choices() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()
	_max_out_everything(run)

	# One attack_speed stack short of the cap: exactly one option must survive.
	run.passives["attack_speed"] = int(run.passives["attack_speed"]) - 1

	var captured: Array[Dictionary] = []
	var handler := func(_new_level: int, choices: Array) -> void:
		for choice: Dictionary in choices:
			captured.append(choice)

	EventBus.level_reached.connect(handler)
	run.add_xp(run.xp_to_next(run.level))
	EventBus.level_reached.disconnect(handler)

	if captured.size() != 1:
		failures.append("a near-exhausted pool offered %d choices, expected 1" % captured.size())
	elif String(captured[0].get("id", "")) != "attack_speed":
		failures.append("the only remaining option was \"%s\", expected attack_speed" % String(captured[0].get("id", "")))

	# Fully exhausted: no options at all, and still no crash.
	run.grant_passive("attack_speed")
	captured.clear()
	EventBus.level_reached.connect(handler)
	_mute_expected_errors(true)
	run.add_xp(run.xp_to_next(run.level))
	_mute_expected_errors(false)
	EventBus.level_reached.disconnect(handler)

	if not captured.is_empty():
		failures.append("a fully exhausted pool still offered %d choices" % captured.size())

	_drop(run)
	return failures


func _test_apply_choice_mutates_run() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()
	run.begin("taoist", "bamboo_forest")

	var captured: Array[Dictionary] = []
	var handler := func(_new_level: int, choices: Array) -> void:
		for choice: Dictionary in choices:
			captured.append(choice)

	EventBus.level_reached.connect(handler)
	run.add_xp(run.xp_to_next(run.level))
	EventBus.level_reached.disconnect(handler)

	if captured.is_empty():
		failures.append("no choices were offered to apply")
		_drop(run)
		return failures

	var choice: Dictionary = captured[0]
	var choice_id: String = String(choice.get("id", ""))
	var kind: String = String(choice.get("kind", ""))
	var before: int = _owned_amount(run, choice_id, kind)
	run.apply_choice(choice_id)
	var after: int = _owned_amount(run, choice_id, kind)

	if after != before + 1:
		failures.append("apply_choice(\"%s\") moved the count from %d to %d" % [choice_id, before, after])

	# An id that was never offered must be rejected, not silently applied.
	_mute_expected_errors(true)
	run.apply_choice("not_offered")
	_mute_expected_errors(false)
	if run.weapon_level("not_offered") != 0 or run.passive_stacks("not_offered") != 0:
		failures.append("apply_choice accepted an id that was never offered")

	_drop(run)
	return failures


## content-data balanced the stage against at most four concurrent weapons, so
## a regression here silently changes the difficulty of the whole run.
func _test_weapon_slot_cap_holds() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()
	var cap: int = RUN_STATE_SCRIPT.MAX_WEAPON_SLOTS

	var weapon_ids: Array[String] = []
	for weapon_data: Dictionary in run.content.all_weapons():
		weapon_ids.append(String(weapon_data.get("id", "")))

	if weapon_ids.size() <= cap:
		failures.append("the fixture pool holds %d weapons; the cap test needs more than %d" % [
			weapon_ids.size(), cap,
		])
		_drop(run)
		return failures

	for slot: int in range(cap - 1):
		run.grant_weapon(weapon_ids[slot])

	# One slot still free: new weapons must remain on offer.
	if run._new_weapon_choices().is_empty():
		failures.append("no weapon_new candidates with %d of %d slots filled" % [cap - 1, cap])

	run.grant_weapon(weapon_ids[cap - 1])
	if run.weapons.size() != cap:
		failures.append("filling %d slots produced %d weapons" % [cap, run.weapons.size()])

	# Asserted on the candidate list, not on an emitted level-up: _build_choices
	# shuffles and slices to three, so a sampled check would pass by luck.
	var new_weapon_candidates: Array[Dictionary] = run._new_weapon_choices()
	if not new_weapon_candidates.is_empty():
		failures.append("%d weapon_new candidate(s) survived with all %d slots full" % [
			new_weapon_candidates.size(), cap,
		])

	# A further distinct weapon must be refused outright, not appended.
	var overflow_id: String = weapon_ids[cap]
	_mute_expected_errors(true)
	run.grant_weapon(overflow_id)
	_mute_expected_errors(false)

	if run.weapons.size() != cap:
		failures.append("grant_weapon pushed past the cap to %d weapons" % run.weapons.size())
	if run.weapon_level(overflow_id) != 0:
		failures.append("\"%s\" was taken despite every slot being full" % overflow_id)

	# With the slots full the pool must collapse to upgrades and passives.
	var captured: Array[Dictionary] = []
	var handler := func(_new_level: int, choices: Array) -> void:
		for choice: Dictionary in choices:
			captured.append(choice)

	EventBus.level_reached.connect(handler)
	run.add_xp(run.xp_to_next(run.level))
	EventBus.level_reached.disconnect(handler)

	if captured.is_empty():
		failures.append("a full-slot run offered no choices at all")

	_drop(run)
	return failures


func _test_stat_total_aggregates_stacks() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()

	if not is_zero_approx(run.stat_total("attack_speed")):
		failures.append("stat_total on an empty run is %f, expected 0" % run.stat_total("attack_speed"))

	for _stack: int in range(3):
		run.grant_passive("attack_speed")

	var expected: float = 3.0 * ATTACK_SPEED_PER_STACK
	var actual: float = run.stat_total("attack_speed")
	if absf(actual - expected) > FLOAT_TOLERANCE:
		failures.append("stat_total(\"attack_speed\") is %f, expected %f" % [actual, expected])

	if not is_zero_approx(run.stat_total("move_speed")):
		failures.append("a stat with no matching passive returned %f, expected 0" % run.stat_total("move_speed"))

	_drop(run)
	return failures


func _check_choice_is_not_exhausted(run: Node, choice_id: String, kind: String) -> Array[String]:
	var failures: Array[String] = []
	var content: Node = run.content

	match kind:
		RUN_STATE_SCRIPT.KIND_WEAPON_NEW:
			if run.weapon_level(choice_id) > 0:
				failures.append("weapon_new offered \"%s\", which the run already owns" % choice_id)
		RUN_STATE_SCRIPT.KIND_WEAPON_UPGRADE:
			var max_level: int = int(content.weapon(choice_id).get("max_level", 0))
			if run.weapon_level(choice_id) >= max_level:
				failures.append("weapon_upgrade offered \"%s\" at max level %d" % [choice_id, max_level])
		RUN_STATE_SCRIPT.KIND_PASSIVE:
			var max_stacks: int = int(content.passive(choice_id).get("max_stacks", 0))
			if run.passive_stacks(choice_id) >= max_stacks:
				failures.append("passive offered \"%s\" at max stacks %d" % [choice_id, max_stacks])

	return failures


func _owned_amount(run: Node, choice_id: String, kind: String) -> int:
	if kind == RUN_STATE_SCRIPT.KIND_PASSIVE:
		return run.passive_stacks(choice_id)
	return run.weapon_level(choice_id)


func _max_out_everything(run: Node) -> void:
	var content: Node = run.content
	# Filling past the slot cap is expected here and warns; mute that noise.
	_mute_expected_errors(true)
	for weapon_data: Dictionary in content.all_weapons():
		var weapon_id: String = String(weapon_data.get("id", ""))
		for _step: int in range(int(weapon_data.get("max_level", 1))):
			run.grant_weapon(weapon_id)
	_mute_expected_errors(false)
	for passive_data: Dictionary in content.all_passives():
		var passive_id: String = String(passive_data.get("id", ""))
		for _step: int in range(int(passive_data.get("max_stacks", 1))):
			run.grant_passive(passive_id)


func _new_run() -> Node:
	var data: Node = GAME_DATA_SCRIPT.new()
	var result: Error = data.load_from_dir(FIXTURES_DIR)
	if result != OK:
		push_error("test_run_state: fixtures failed to load (error %d)" % result)

	var run: Node = RUN_STATE_SCRIPT.new()
	run.content = data
	data.run_state = run
	return run


func _drop(run: Node) -> void:
	var content: Node = run.content
	run.free()
	if content != null:
		content.free()


## Exhaustion cases deliberately trip push_warning/push_error; mute them so the
## runner output only carries real problems.
func _mute_expected_errors(muted: bool) -> void:
	Engine.print_error_messages = not muted
