extends Node
## Mutable state of a single run. Reset between runs; nothing here survives to
## the profile save.
##
## Frozen contract: ARCHITECTURE.md section 3.3.

## XP curve: xp_to_next(level) = XP_CURVE_BASE * XP_CURVE_GROWTH ^ (level - 1),
## rounded to the nearest int. Geometric growth keeps the first minute fast
## (Vampire-Survivors pacing) while late levels still cost meaningfully more.
const XP_CURVE_BASE := 5
const XP_CURVE_GROWTH := 1.25

const FIRST_LEVEL := 1
const CHOICES_PER_LEVEL := 3
const WEAPON_START_LEVEL := 1
const PASSIVE_START_STACKS := 1

## Concurrent weapon slots (ARCHITECTURE.md section 3.3). content-data balanced
## the stage against this holding, so it is enforced at the single point every
## caller routes through (grant_weapon) as well as in the choice pool.
const MAX_WEAPON_SLOTS := 4

## Schema fallbacks, not balance knobs: content is expected to declare these
## fields, and an entry that omits them must still cap rather than grow forever.
const FALLBACK_WEAPON_MAX_LEVEL := 1
const FALLBACK_PASSIVE_MAX_STACKS := 1

const KIND_WEAPON_NEW := "weapon_new"
const KIND_WEAPON_UPGRADE := "weapon_upgrade"
const KIND_PASSIVE := "passive"

const CHOICE_ID := "id"
const CHOICE_KIND := "kind"
const CHOICE_NAME_KO := "name_ko"
const CHOICE_NAME_EN := "name_en"
const CHOICE_DESCRIPTION_KO := "description_ko"
const CHOICE_DESCRIPTION_EN := "description_en"

const WEAPON_ID := "id"
const WEAPON_LEVEL := "level"

## Content fields read from data/*.json (ARCHITECTURE.md section 4).
const FIELD_NAME_KO := "name_ko"
const FIELD_NAME_EN := "name_en"
const FIELD_MAX_LEVEL := "max_level"
const FIELD_MAX_STACKS := "max_stacks"
const FIELD_PER_STACK := "per_stack"
const FIELD_STAT := "stat"
const FIELD_STARTING_WEAPON := "starting_weapon"
const FIELD_EVOLUTION_ONLY := "evolution_only"

## Evolution rule fields (data/evolutions.json, ARCHITECTURE.md section 4).
const RULE_REQUIRES_WEAPON := "requires_weapon"
const RULE_REQUIRES_PASSIVE := "requires_passive"
const RULE_MIN_WEAPON_LEVEL := "min_weapon_level"
const RULE_MIN_PASSIVE_STACKS := "min_passive_stacks"
const RULE_RESULT_WEAPON := "result_weapon"

## An evolution rule is a conjunction: a weapon at a level AND a passive at a
## stack count. Both halves are weighted, because favouring one alone makes the
## pool reliably deliver half a requirement and never complete it.
##
## The halves are not symmetric in cost. Weapons enter at level 1 and rules ask
## for level 3, so the weapon half needs two accepted picks; min_passive_stacks
## sits at the schema floor of 1, so the passive half needs one. The first sweep
## weighted the two-pick half at 1 and the one-pick half at 4, which is why runs
## ended with every gating passive met or overshot and every gating weapon short
## at 0-2 of 3.
##
## The arithmetic behind these numbers, for a mid-run pool of about 11 options
## where a level-up shows three of them and a random pick takes one in three.
## At base weight a weapon upgrade is offered 3/11 = 27% of level-ups, so across
## fifteen level-ups it is accepted 15 * 0.27 / 3 = 1.4 times against the two it
## needs -- which is exactly the observed "sword at 2/3, bow at 2/3". At weight 4
## it is offered about 64%, giving 3.2 expected picks against 2 needed. The
## passive half drops from 4 to 2 because it was overshooting: at weight 2 it is
## still offered about 37% of level-ups, or 1.9 expected picks against the single
## pick it needs.
##
## Weighting the weapon half up also protects the weak builds rather than
## starving them, since a gating weapon upgrade is damage in its own right. A run
## with no reachable rule has no weighted candidates at all and draws uniformly,
## exactly as it did before any of this.
## Synergy passives only make sense while a weapon can trigger them: a bow
## build gains nothing from burn power. stat key -> weapons.json field that
## must exist on at least one owned weapon before the passive is offered.
const STAT_REQUIRES_WEAPON_FIELD := {
	"burn_power": "on_hit_status",
	"chain_amount": "on_hit_chain",
	"seal_haste": "on_hit_seal",
}

const GATING_WEAPON_WEIGHT := 4.0
const GATING_PASSIVE_WEIGHT := 2.0
const BASE_CHOICE_WEIGHT := 1.0

var character_id: String = ""
var stage_id: String = ""
var level: int = FIRST_LEVEL
var xp: int = 0
var elapsed_sec: float = 0.0
var kills: int = 0
var weapons: Array[Dictionary] = []
var passives: Dictionary = {}
## Run-scoped loot: loot_id -> collected count. Cleared on reset(); loot never
## survives a run (GDD v2 section 32) — what persists is the record, not the item.
var loot_counts: Dictionary = {}

## Content source. Defaults to the GameData autoload; tests inject a
## fixture-backed instance so they never depend on shipped content.
var content: Node = null

## The last set of options handed to the UI. Kept so an incoming
## upgrade_chosen id can be validated instead of trusted.
var _pending_choices: Array[Dictionary] = []


func _ready() -> void:
	# RunState owns run mutation, so it applies the pick itself; the UI only
	# reports which choice id the player took.
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)
	# Combat swaps the weapon node-side and announces it here. Without this the
	# weapons array keeps naming the source, so evolution_for never sees the
	# evolved weapon's level and a chained evolution can never fire.
	EventBus.weapon_evolved.connect(_on_weapon_evolved)


func begin(new_character_id: String, new_stage_id: String) -> void:
	reset()
	character_id = new_character_id
	stage_id = new_stage_id

	var character_data: Dictionary = _content().character(new_character_id)
	var starting_weapon: String = String(character_data.get(FIELD_STARTING_WEAPON, ""))
	if starting_weapon.is_empty():
		push_error("RunState.begin: character \"%s\" declares no starting_weapon" % new_character_id)
	else:
		grant_weapon(starting_weapon)

	EventBus.run_started.emit(character_id, stage_id)


func reset() -> void:
	character_id = ""
	stage_id = ""
	level = FIRST_LEVEL
	xp = 0
	elapsed_sec = 0.0
	kills = 0
	weapons = []
	passives = {}
	loot_counts = {}
	_pending_choices = []


func add_loot(loot_id: String) -> void:
	if loot_id.is_empty():
		push_error("RunState.add_loot called with an empty loot id")
		return
	loot_counts[loot_id] = int(loot_counts.get(loot_id, 0)) + 1


func loot_count(loot_id: String) -> int:
	return int(loot_counts.get(loot_id, 0))


## Spends one unit of `loot_id` to mod `weapon_id` per weapon_mods.json.
## Returns false (with the reason as a warning) when the recipe does not exist,
## the run does not hold the weapon, or the material is not in stock. The
## in-place swap reuses evolve_weapon so level inheritance stays in one place.
func apply_weapon_mod(weapon_id: String, loot_id: String) -> bool:
	var result: String = String(_content().mod_for(weapon_id, loot_id))
	if result.is_empty():
		push_warning("RunState.apply_weapon_mod: no recipe for \"%s\" + \"%s\"" % [weapon_id, loot_id])
		return false
	if weapon_level(weapon_id) <= 0:
		push_warning("RunState.apply_weapon_mod: the run does not hold \"%s\"" % weapon_id)
		return false
	if loot_count(loot_id) <= 0:
		push_warning("RunState.apply_weapon_mod: no \"%s\" in stock" % loot_id)
		return false
	# Without this the material would be spent while evolve_weapon produced a
	# duplicate loadout entry for the already-held result.
	if weapon_level(result) > 0:
		push_warning("RunState.apply_weapon_mod: the run already holds \"%s\"" % result)
		return false

	var remaining: int = int(loot_counts[loot_id]) - 1
	if remaining <= 0:
		loot_counts.erase(loot_id)
	else:
		loot_counts[loot_id] = remaining

	evolve_weapon(weapon_id, result)
	EventBus.weapon_modified.emit(weapon_id, result)
	return true


## Spends one unit of `loot_id` and returns its data-declared salvage gold,
## or 0 when nothing is in stock. The caller routes the gold — RunState only
## owns the loot ledger.
func salvage_loot(loot_id: String) -> int:
	if loot_count(loot_id) <= 0:
		push_warning("RunState.salvage_loot: no \"%s\" in stock" % loot_id)
		return 0

	var gold: int = int(_content().loot(loot_id).get("salvage_gold", 0))
	var remaining: int = int(loot_counts[loot_id]) - 1
	if remaining <= 0:
		loot_counts.erase(loot_id)
	else:
		loot_counts[loot_id] = remaining
	return gold


func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	# xp_gain passive: a fractional bonus on every pickup, rounded per pickup
	# so small gems still visibly benefit.
	var scaled: int = maxi(int(round(float(amount) * (1.0 + stat_total("xp_gain")))), 1)
	xp += scaled
	EventBus.xp_gained.emit(scaled)

	# A single pickup can cross several thresholds at once (late-game gems, boss
	# drops), so drain the pool instead of levelling only once.
	while true:
		var cost: int = xp_to_next(level)
		if cost <= 0:
			push_error("RunState: xp_to_next(%d) returned %d; aborting level-up loop" % [level, cost])
			return
		if xp < cost:
			return

		xp -= cost
		level += 1
		_pending_choices = _build_choices()
		EventBus.level_reached.emit(level, _pending_choices.duplicate(true))


## XP required to advance from `from_level` to the next one.
func xp_to_next(from_level: int) -> int:
	var steps: int = maxi(from_level - FIRST_LEVEL, 0)
	return int(round(XP_CURVE_BASE * pow(XP_CURVE_GROWTH, steps)))


## Aggregated passive value for a stat key, e.g. "attack_speed".
func stat_total(key: String) -> float:
	var total: float = 0.0
	for passive_id: String in passives.keys():
		var data: Dictionary = _content().passive(passive_id)
		if data.is_empty():
			continue
		if String(data.get(FIELD_STAT, "")) != key:
			continue
		total += float(data.get(FIELD_PER_STACK, 0.0)) * float(int(passives[passive_id]))
	return total


func weapon_level(weapon_id: String) -> int:
	for owned: Dictionary in weapons:
		if String(owned.get(WEAPON_ID, "")) == weapon_id:
			return int(owned.get(WEAPON_LEVEL, 0))
	return 0


func passive_stacks(passive_id: String) -> int:
	return int(passives.get(passive_id, 0))


## Adds the weapon at level 1, or levels it up when already owned. Never exceeds
## the content-declared max_level.
func grant_weapon(weapon_id: String) -> void:
	var data: Dictionary = _content().weapon(weapon_id)
	if data.is_empty():
		return

	var max_level: int = int(data.get(FIELD_MAX_LEVEL, FALLBACK_WEAPON_MAX_LEVEL))
	for owned: Dictionary in weapons:
		if String(owned.get(WEAPON_ID, "")) != weapon_id:
			continue
		var current: int = int(owned.get(WEAPON_LEVEL, WEAPON_START_LEVEL))
		if current >= max_level:
			push_warning("RunState: weapon \"%s\" is already at max level %d" % [weapon_id, max_level])
			return
		owned[WEAPON_LEVEL] = current + 1
		return

	if weapons.size() >= MAX_WEAPON_SLOTS:
		push_warning("RunState: cannot take \"%s\"; all %d weapon slots are full" % [weapon_id, MAX_WEAPON_SLOTS])
		return

	weapons.append({WEAPON_ID: weapon_id, WEAPON_LEVEL: WEAPON_START_LEVEL})


## Records that `from_id` has become `to_id`, so the run tracks the weapon the
## player actually wields.
##
## The evolved weapon INHERITS the source's level rather than restarting at 1.
## Two reasons: combat already carries the level across the swap node-side
## (Player._wanted_loadout), so restarting here would leave the two authorities
## disagreeing about the same weapon; and a restart would strand every chained
## evolution, since the second-stage rule gates on the evolved weapon reaching a
## level it could not reach again inside one run. The level is clamped to the
## target's own max_level in case it is shorter than the source's.
##
## The entry is rewritten in place. Evolution transforms a weapon, so it must not
## consume a second slot -- and Player._check_evolutions() emits this signal while
## iterating the live weapons array, where appending or erasing would be unsafe.
func evolve_weapon(from_id: String, to_id: String) -> void:
	if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
		push_warning("RunState.evolve_weapon: ignoring the meaningless swap \"%s\" -> \"%s\"" % [from_id, to_id])
		return

	var target_data: Dictionary = _content().weapon(to_id)
	if target_data.is_empty():
		# GameData already reported the unknown id. Keep the source rather than
		# replacing a real weapon with one the content does not define.
		return

	if weapon_level(to_id) > 0:
		push_warning("RunState.evolve_weapon: \"%s\" is already owned; leaving \"%s\" alone" % [to_id, from_id])
		return

	for owned: Dictionary in weapons:
		if String(owned.get(WEAPON_ID, "")) != from_id:
			continue

		var inherited: int = int(owned.get(WEAPON_LEVEL, WEAPON_START_LEVEL))
		var target_max: int = int(target_data.get(FIELD_MAX_LEVEL, FALLBACK_WEAPON_MAX_LEVEL))
		owned[WEAPON_ID] = to_id
		owned[WEAPON_LEVEL] = mini(inherited, target_max)
		return

	push_warning("RunState.evolve_weapon: the run does not hold \"%s\"" % from_id)


func _on_weapon_evolved(from_id: String, to_id: String) -> void:
	evolve_weapon(from_id, to_id)


## Adds one passive stack, capped by the content-declared max_stacks.
func grant_passive(passive_id: String) -> void:
	var data: Dictionary = _content().passive(passive_id)
	if data.is_empty():
		return

	var max_stacks: int = int(data.get(FIELD_MAX_STACKS, FALLBACK_PASSIVE_MAX_STACKS))
	var current: int = passive_stacks(passive_id)
	if current >= max_stacks:
		push_warning("RunState: passive \"%s\" is already at max stacks %d" % [passive_id, max_stacks])
		return

	passives[passive_id] = current + 1


## Applies one of the options offered by the most recent level_reached.
func apply_choice(choice_id: String) -> void:
	var choice: Dictionary = _find_pending(choice_id)
	if choice.is_empty():
		push_error("RunState.apply_choice: \"%s\" was not offered by the last level-up" % choice_id)
		return

	var kind: String = String(choice.get(CHOICE_KIND, ""))
	match kind:
		KIND_WEAPON_NEW, KIND_WEAPON_UPGRADE:
			grant_weapon(choice_id)
		KIND_PASSIVE:
			grant_passive(choice_id)
		_:
			push_error("RunState.apply_choice: unknown choice kind \"%s\"" % kind)
			return

	_pending_choices = []


func _on_upgrade_chosen(choice_id: String) -> void:
	apply_choice(choice_id)


func _find_pending(choice_id: String) -> Dictionary:
	for choice: Dictionary in _pending_choices:
		if String(choice.get(CHOICE_ID, "")) == choice_id:
			return choice
	return {}


## Builds up to CHOICES_PER_LEVEL options. Exhausted weapons (at max_level) and
## passives (at max_stacks) are excluded, so the pool shrinks late in a run and
## a level can legitimately offer fewer than three.
func _build_choices() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	pool.append_array(_weapon_upgrade_choices())
	pool.append_array(_new_weapon_choices())
	pool.append_array(_passive_choices())

	if pool.is_empty():
		push_warning("RunState: level %d has no upgrade options left" % level)
		return pool

	return _weighted_sample(pool, CHOICES_PER_LEVEL)


## Draws up to `count` distinct options, favouring both halves of a reachable
## evolution's requirement. Sampling is without replacement, so an option can
## never be offered twice in one level-up, and weighting only reorders the odds
## of candidates the pool already contains -- an exhausted passive or a
## max-level weapon was filtered out upstream in _passive_choices() and
## _weapon_upgrade_choices(), and no weight can bring either back.
func _weighted_sample(pool: Array[Dictionary], count: int) -> Array[Dictionary]:
	var gating_passives: Dictionary = _gating_passive_ids()
	var gating_weapons: Dictionary = _gating_weapon_ids()
	var remaining: Array[Dictionary] = pool.duplicate()
	var weights: Array[float] = []
	for choice: Dictionary in remaining:
		weights.append(_choice_weight(choice, gating_passives, gating_weapons))

	var drawn: Array[Dictionary] = []
	while drawn.size() < count and not remaining.is_empty():
		var total: float = 0.0
		for weight: float in weights:
			total += weight

		var roll: float = randf() * total
		# Falls back to the last index, which also covers float drift leaving a
		# sliver of the roll unconsumed.
		var index: int = remaining.size() - 1
		for candidate: int in range(remaining.size()):
			roll -= weights[candidate]
			if roll <= 0.0:
				index = candidate
				break

		drawn.append(remaining[index])
		remaining.remove_at(index)
		weights.remove_at(index)

	return drawn


func _choice_weight(choice: Dictionary, gating_passive_ids: Dictionary, gating_weapon_ids: Dictionary) -> float:
	var choice_id: String = String(choice.get(CHOICE_ID, ""))
	match String(choice.get(CHOICE_KIND, "")):
		KIND_PASSIVE:
			if gating_passive_ids.has(choice_id):
				return GATING_PASSIVE_WEIGHT
		KIND_WEAPON_UPGRADE:
			# Only an upgrade counts. Acquiring the weapon is a separate step and
			# weighting weapon_new here would push the run into spreading itself
			# across weapons instead of deepening the one the rule names.
			if gating_weapon_ids.has(choice_id):
				return GATING_WEAPON_WEIGHT
	return BASE_CHOICE_WEIGHT


## Passives that are the one missing piece of an evolution this run can still
## reach: it already holds the source weapon, has not produced the result yet,
## and is short of the rule's stack threshold. Read off the rules themselves, so
## content can add an evolution without touching this file.
##
## Once the stacks are met the passive drops back to base weight, so the pool
## stops spending draws on a half of the requirement that is already satisfied.
func _gating_passive_ids() -> Dictionary:
	var gating: Dictionary = {}
	for rule: Dictionary in _content().all_evolutions():
		var source_id: String = String(rule.get(RULE_REQUIRES_WEAPON, ""))
		if source_id.is_empty() or weapon_level(source_id) <= 0:
			continue

		var result_id: String = String(rule.get(RULE_RESULT_WEAPON, ""))
		if not result_id.is_empty() and weapon_level(result_id) > 0:
			continue

		var passive_id: String = String(rule.get(RULE_REQUIRES_PASSIVE, ""))
		if passive_id.is_empty():
			continue
		if passive_stacks(passive_id) >= int(rule.get(RULE_MIN_PASSIVE_STACKS, 0)):
			continue

		gating[passive_id] = true

	return gating


## Weapons the run holds below the level an otherwise reachable evolution asks
## for -- the other half of the same requirement _gating_passive_ids() covers.
## Once the level is met the weapon drops back to base weight, mirroring the
## passive side, so a satisfied half stops competing for draws.
func _gating_weapon_ids() -> Dictionary:
	var gating: Dictionary = {}
	for rule: Dictionary in _content().all_evolutions():
		var source_id: String = String(rule.get(RULE_REQUIRES_WEAPON, ""))
		if source_id.is_empty() or weapon_level(source_id) <= 0:
			continue

		var result_id: String = String(rule.get(RULE_RESULT_WEAPON, ""))
		if not result_id.is_empty() and weapon_level(result_id) > 0:
			continue

		if weapon_level(source_id) >= int(rule.get(RULE_MIN_WEAPON_LEVEL, 0)):
			continue

		gating[source_id] = true

	return gating


func _weapon_upgrade_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for owned: Dictionary in weapons:
		var weapon_id: String = String(owned.get(WEAPON_ID, ""))
		var data: Dictionary = _content().weapon(weapon_id)
		if data.is_empty():
			continue

		var max_level: int = int(data.get(FIELD_MAX_LEVEL, FALLBACK_WEAPON_MAX_LEVEL))
		var current: int = int(owned.get(WEAPON_LEVEL, WEAPON_START_LEVEL))
		if current >= max_level:
			continue

		var per_level: Dictionary = data.get("per_level", {}) if data.get("per_level") is Dictionary else {}
		# The description says what actually grows: "Lv.2/8 · 피해 +3.5 · ...".
		var level_prefix: String = "Lv.%d/%d" % [current + 1, max_level]
		choices.append({
			CHOICE_ID: weapon_id,
			CHOICE_KIND: KIND_WEAPON_UPGRADE,
			CHOICE_NAME_KO: String(data.get(FIELD_NAME_KO, weapon_id)),
			CHOICE_NAME_EN: String(data.get(FIELD_NAME_EN, weapon_id)),
			CHOICE_DESCRIPTION_KO: ChoiceText.SEPARATOR.join([level_prefix, ChoiceText.weapon_upgrade_description(per_level, "ko")]),
			CHOICE_DESCRIPTION_EN: ChoiceText.SEPARATOR.join([level_prefix, ChoiceText.weapon_upgrade_description(per_level, "en")]),
		})
	return choices


func _new_weapon_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	# With every slot filled the pool must collapse to upgrades and passives,
	# otherwise the player is offered a weapon that grant_weapon would refuse.
	if weapons.size() >= MAX_WEAPON_SLOTS:
		return choices

	for data: Dictionary in _content().all_weapons():
		var weapon_id: String = String(data.get(CHOICE_ID, ""))
		if weapon_id.is_empty() or weapon_level(weapon_id) > 0:
			continue

		# An evolution result must be earned through its rule, never handed out as
		# a plain pick, or meeting the rule's level and stack requirements buys
		# nothing. Absent flag means false so a not-yet-authored entry still
		# appears rather than the pool silently emptying.
		if bool(data.get(FIELD_EVOLUTION_ONLY, false)):
			continue

		choices.append({
			CHOICE_ID: weapon_id,
			CHOICE_KIND: KIND_WEAPON_NEW,
			CHOICE_NAME_KO: String(data.get(FIELD_NAME_KO, weapon_id)),
			CHOICE_NAME_EN: String(data.get(FIELD_NAME_EN, weapon_id)),
			CHOICE_DESCRIPTION_KO: ChoiceText.weapon_base_description(data, "ko"),
			CHOICE_DESCRIPTION_EN: ChoiceText.weapon_base_description(data, "en"),
		})
	return choices


func _passive_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for data: Dictionary in _content().all_passives():
		var passive_id: String = String(data.get(CHOICE_ID, ""))
		if passive_id.is_empty():
			continue

		var max_stacks: int = int(data.get(FIELD_MAX_STACKS, FALLBACK_PASSIVE_MAX_STACKS))
		var current: int = passive_stacks(passive_id)
		if current >= max_stacks:
			continue

		var required_field: String = String(STAT_REQUIRES_WEAPON_FIELD.get(String(data.get(FIELD_STAT, "")), ""))
		if not required_field.is_empty() and not _owns_weapon_with_field(required_field):
			continue

		# "+8% (2/5)" — the name already carries the stat, the description
		# carries the size of the step.
		var description: String = ChoiceText.passive_description(
			float(data.get(FIELD_PER_STACK, 0.0)), current + PASSIVE_START_STACKS, max_stacks
		)
		choices.append({
			CHOICE_ID: passive_id,
			CHOICE_KIND: KIND_PASSIVE,
			CHOICE_NAME_KO: String(data.get(FIELD_NAME_KO, passive_id)),
			CHOICE_NAME_EN: String(data.get(FIELD_NAME_EN, passive_id)),
			CHOICE_DESCRIPTION_KO: description,
			CHOICE_DESCRIPTION_EN: description,
		})
	return choices


func _owns_weapon_with_field(field: String) -> bool:
	for owned: Dictionary in weapons:
		var data: Dictionary = _content().weapon(String(owned.get(WEAPON_ID, "")))
		if data.has(field):
			return true
	return false


func _content() -> Node:
	return content if content != null else GameData
