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

var character_id: String = ""
var stage_id: String = ""
var level: int = FIRST_LEVEL
var xp: int = 0
var elapsed_sec: float = 0.0
var kills: int = 0
var weapons: Array[Dictionary] = []
var passives: Dictionary = {}

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
	_pending_choices = []


func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	xp += amount
	EventBus.xp_gained.emit(amount)

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

	pool.shuffle()
	return pool.slice(0, CHOICES_PER_LEVEL)


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

		var name_ko: String = String(data.get(FIELD_NAME_KO, weapon_id))
		choices.append({
			CHOICE_ID: weapon_id,
			CHOICE_KIND: KIND_WEAPON_UPGRADE,
			CHOICE_NAME_KO: name_ko,
			CHOICE_NAME_EN: String(data.get(FIELD_NAME_EN, weapon_id)),
			# Display text is assembled from data-authored names plus numbers, so
			# no Korean copy is hardcoded here (ARCHITECTURE.md section 4).
			CHOICE_DESCRIPTION_KO: "%s Lv.%d / %d" % [name_ko, current + 1, max_level],
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

		var name_ko: String = String(data.get(FIELD_NAME_KO, weapon_id))
		choices.append({
			CHOICE_ID: weapon_id,
			CHOICE_KIND: KIND_WEAPON_NEW,
			CHOICE_NAME_KO: name_ko,
			CHOICE_NAME_EN: String(data.get(FIELD_NAME_EN, weapon_id)),
			CHOICE_DESCRIPTION_KO: "%s Lv.%d" % [name_ko, WEAPON_START_LEVEL],
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

		var name_ko: String = String(data.get(FIELD_NAME_KO, passive_id))
		choices.append({
			CHOICE_ID: passive_id,
			CHOICE_KIND: KIND_PASSIVE,
			CHOICE_NAME_KO: name_ko,
			CHOICE_NAME_EN: String(data.get(FIELD_NAME_EN, passive_id)),
			CHOICE_DESCRIPTION_KO: "%s %d / %d" % [name_ko, current + PASSIVE_START_STACKS, max_stacks],
		})
	return choices


func _content() -> Node:
	return content if content != null else GameData
