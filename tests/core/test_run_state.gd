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
	failures.append_array(_test_evolution_only_weapons_are_not_offered())
	failures.append_array(_test_chained_evolution_is_reachable())
	failures.append_array(_test_gating_passive_is_favoured())
	failures.append_array(_test_weighting_never_guarantees_or_breaks_caps())
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


## An evolution result handed out as an ordinary pick makes the evolution
## requirements worthless, so combat sees evolution never pay off.
func _test_evolution_only_weapons_are_not_offered() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()

	var evolution_only_ids: Array[String] = []
	for weapon_data: Dictionary in run.content.all_weapons():
		if bool(weapon_data.get(RUN_STATE_SCRIPT.FIELD_EVOLUTION_ONLY, false)):
			evolution_only_ids.append(String(weapon_data.get("id", "")))

	if evolution_only_ids.is_empty():
		failures.append("the fixture pool has no evolution_only weapon, so this test cannot catch a regression")
		_drop(run)
		return failures

	# Asserted on the candidate list, not on an emitted level-up: _build_choices
	# shuffles and slices to three, so a sampled check would pass by luck.
	var candidate_ids: Array[String] = []
	for choice: Dictionary in run._new_weapon_choices():
		candidate_ids.append(String(choice.get("id", "")))

	for blocked_id: String in evolution_only_ids:
		if candidate_ids.has(blocked_id):
			failures.append("evolution_only weapon \"%s\" was offered as weapon_new" % blocked_id)

	if candidate_ids.is_empty():
		failures.append("excluding evolution_only weapons emptied the weapon_new pool")

	# The exclusion is about acquiring, not levelling: once the evolution rule has
	# granted it, its upgrade must still show up.
	var evolved_id: String = evolution_only_ids[0]
	run.grant_weapon(evolved_id)
	if run.weapon_level(evolved_id) != RUN_STATE_SCRIPT.WEAPON_START_LEVEL:
		failures.append("grant_weapon refused the evolution result \"%s\"" % evolved_id)

	var upgrade_offered: bool = false
	for choice: Dictionary in run._weapon_upgrade_choices():
		if String(choice.get("id", "")) == evolved_id:
			upgrade_offered = true

	if not upgrade_offered:
		failures.append("owning \"%s\" did not put its upgrade in the pool" % evolved_id)

	_drop(run)
	return failures


## Combat found the second-stage evolution structurally unreachable: RunState
## kept naming the source weapon, so evolution_for saw the evolved one at level 0
## forever. Asserted on run state, never on a sampled level-up.
func _test_chained_evolution_is_reachable() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()
	var content: Node = run.content

	# Fixture chain, mirroring data/evolutions.json at fixture scale:
	# old_talisman -> fire_talisman -> phoenix_talisman, each needing the weapon
	# at level 2 and skill_power at 2 stacks.
	run.grant_weapon("old_talisman")
	run.grant_weapon("old_talisman")
	run.grant_passive("skill_power")
	run.grant_passive("skill_power")

	var first_stage: String = content.evolution_for("old_talisman", "skill_power")
	if first_stage != "fire_talisman":
		failures.append("stage one resolved to \"%s\", expected fire_talisman" % first_stage)

	var source_level: int = run.weapon_level("old_talisman")
	run.evolve_weapon("old_talisman", first_stage)

	if run.weapon_level("old_talisman") != 0:
		failures.append("the source weapon is still listed at level %d after evolving" % run.weapon_level("old_talisman"))

	# Inherited, not restarted. A restart would strand the chain: the second rule
	# gates on a level the evolved weapon could not reach again inside one run.
	if run.weapon_level("fire_talisman") != source_level:
		failures.append("the evolved weapon sits at level %d, expected the inherited %d" % [
			run.weapon_level("fire_talisman"), source_level,
		])

	if run.weapons.size() != 1:
		failures.append("evolving changed the weapon count to %d; it must replace in place" % run.weapons.size())

	# The reported bug: with the source id still listed this returned "".
	var second_stage: String = content.evolution_for("fire_talisman", "skill_power")
	if second_stage != "phoenix_talisman":
		failures.append("the chained evolution resolved to \"%s\", expected phoenix_talisman" % second_stage)

	# The evolved weapon must keep levelling, which is what the old design bought.
	var upgrade_offered: bool = false
	for choice: Dictionary in run._weapon_upgrade_choices():
		if String(choice.get("id", "")) == "fire_talisman":
			upgrade_offered = true

	if not upgrade_offered:
		failures.append("the evolved weapon lost its upgrade path")

	# Chain all the way through, so a two-step run really lands on the end weapon.
	run.evolve_weapon("fire_talisman", second_stage)
	if run.weapon_level("phoenix_talisman") != source_level:
		failures.append("the second evolution left phoenix_talisman at level %d" % run.weapon_level("phoenix_talisman"))

	# A swap the run does not hold must be refused, not fabricated.
	_mute_expected_errors(true)
	run.evolve_weapon("short_bow", "fire_talisman")
	_mute_expected_errors(false)
	if run.weapon_level("fire_talisman") != 0 or run.weapons.size() != 1:
		failures.append("evolving an unowned weapon mutated the run")

	_drop(run)

	# The signal path itself, not just the method. Autoload _ready() never fires
	# under the headless runner -- the nodes are parented to root but the tree is
	# never processed -- so wire a throwaway instance by hand and emit the real
	# signal combat emits. Freeing the instance drops the connection again.
	var wired := _new_run()
	wired._ready()
	wired.grant_weapon("old_talisman")
	wired.grant_weapon("old_talisman")
	EventBus.weapon_evolved.emit("old_talisman", "fire_talisman")

	if wired.weapon_level("fire_talisman") != 2:
		failures.append("EventBus.weapon_evolved never reached RunState; fire_talisman sits at %d" % wired.weapon_level("fire_talisman"))

	_drop(wired)
	return failures


## Draws needed before a frequency comparison means anything. At weight 4 the
## gap is wide, so this is far more than enough to separate the two rates well
## outside sampling noise.
const DISTRIBUTION_DRAWS := 2000

## The gating passive must beat a non-gating one by a clear margin, not by a
## hair that random drift could produce on its own.
const MIN_FAVOUR_RATIO := 1.5


## The ten-seed sweep showed winning tracks reaching the phoenix chain, and the
## chain stalls on one specific passive never being offered. Weighting must make
## that passive measurably likelier -- measured over many draws, because
## _build_choices slices to three and any single level-up proves nothing.
func _test_gating_passive_is_favoured() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()

	# Fixture rule: old_talisman + skill_power -> fire_talisman. Holding the
	# weapon with no stacks yet makes skill_power the gating passive; every other
	# passive is a control.
	run.grant_weapon("old_talisman")

	var gating_hits: int = 0
	var control_hits: int = 0
	for _draw: int in range(DISTRIBUTION_DRAWS):
		for choice: Dictionary in run._build_choices():
			match String(choice.get("id", "")):
				"skill_power":
					gating_hits += 1
				"attack_speed":
					control_hits += 1

	if control_hits == 0:
		failures.append("the control passive was never offered; the fixture pool cannot show a difference")
	elif float(gating_hits) < float(control_hits) * MIN_FAVOUR_RATIO:
		failures.append("the gating passive was offered %d times against the control's %d, short of the %.1fx margin" % [
			gating_hits, control_hits, MIN_FAVOUR_RATIO,
		])

	# A passive gating nothing this run must not inherit the bonus.
	var idle := _new_run()
	var idle_gating: int = 0
	var idle_control: int = 0
	for _draw: int in range(DISTRIBUTION_DRAWS):
		for choice: Dictionary in idle._build_choices():
			match String(choice.get("id", "")):
				"skill_power":
					idle_gating += 1
				"attack_speed":
					idle_control += 1

	# No weapon held, so no rule is reachable and the two rates should be level.
	if float(idle_gating) > float(idle_control) * MIN_FAVOUR_RATIO:
		failures.append("skill_power was favoured %d to %d with no weapon held, so the bonus is not gated on a reachable rule" % [
			idle_gating, idle_control,
		])

	_drop(idle)
	_drop(run)
	return failures


## Weighting must tilt the odds without ever becoming a guarantee, and must not
## resurrect a passive the exhaustion rules already removed.
func _test_weighting_never_guarantees_or_breaks_caps() -> Array[String]:
	var failures: Array[String] = []
	var run := _new_run()
	run.grant_weapon("old_talisman")

	var offers: int = 0
	var duplicate_seen: bool = false
	for _draw: int in range(DISTRIBUTION_DRAWS):
		var choices: Array[Dictionary] = run._build_choices()
		if choices.size() > RUN_STATE_SCRIPT.CHOICES_PER_LEVEL:
			failures.append("a draw returned %d choices, over the %d cap" % [
				choices.size(), RUN_STATE_SCRIPT.CHOICES_PER_LEVEL,
			])
			break

		var seen: Dictionary = {}
		for choice: Dictionary in choices:
			var choice_id: String = String(choice.get("id", ""))
			if seen.has(choice_id):
				duplicate_seen = true
			seen[choice_id] = true
			if choice_id == "skill_power":
				offers += 1

	if duplicate_seen:
		failures.append("weighted sampling offered the same option twice in one level-up")
	if offers == 0:
		failures.append("the gating passive was never offered across %d draws" % DISTRIBUTION_DRAWS)
	if offers >= DISTRIBUTION_DRAWS:
		failures.append("the gating passive was offered in every one of %d draws; weighting became a guarantee" % DISTRIBUTION_DRAWS)

	# Stack it to the cap: exhaustion outranks weighting, so it must vanish.
	var max_stacks: int = int(run.content.passive("skill_power").get("max_stacks", 0))
	_mute_expected_errors(true)
	while run.passive_stacks("skill_power") < max_stacks:
		run.grant_passive("skill_power")
	_mute_expected_errors(false)

	if run.passive_stacks("skill_power") != max_stacks:
		failures.append("could not stack the gating passive to its cap of %d" % max_stacks)

	for _draw: int in range(DISTRIBUTION_DRAWS):
		for choice: Dictionary in run._build_choices():
			if String(choice.get("id", "")) == "skill_power":
				failures.append("a fully stacked passive was offered again because it gates an evolution")
				break
		if not failures.is_empty() and failures[failures.size() - 1].begins_with("a fully stacked"):
			break

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
