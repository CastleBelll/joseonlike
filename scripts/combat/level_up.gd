class_name LevelUp
extends RefCounted
## Pure choice-pool and description helpers for the power-up popup (N3-6).
## All inputs are plain Dictionaries parsed from data/*.json by the caller,
## so every function here is testable headless with fixture data.
##
## Choice shape: {"kind": "weapon_up"|"new_weapon"|"passive", "id": String}.

const KIND_WEAPON_UP := "weapon_up"
const KIND_NEW_WEAPON := "new_weapon"
const KIND_PASSIVE := "passive"

const GRADE_KO := {"common": "일반", "rare": "희귀", "epic": "영웅"}
const DEFAULT_GRADE_KO := "일반"

## Only stats the current runtime actually applies may be offered; a card
## that changes nothing would lie to the player.
## ponytail: whitelist, grows as stats get wired into combat.
const OFFERABLE_PASSIVES: Array[String] = [
	"attack_damage", "attack_speed", "move_speed", "max_hp", "magnet_radius"
]


## Every legal choice given the current run: owned weapons below max level,
## unowned non-evolution weapons the AutoWeapon runtime can fire (speed > 0),
## and whitelisted passives below their stack cap.
static func candidates(
	weapons: Dictionary,
	passives: Dictionary,
	owned_levels: Dictionary,
	passive_stacks: Dictionary
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for weapon_id: String in weapons:
		var stats: Dictionary = weapons[weapon_id]
		if owned_levels.has(weapon_id):
			if int(owned_levels[weapon_id]) < int(stats.get("max_level", 0)):
				pool.append({"kind": KIND_WEAPON_UP, "id": weapon_id})
		elif not bool(stats.get("evolution_only", false)) and float(stats.get("speed", 0.0)) > 0.0:
			pool.append({"kind": KIND_NEW_WEAPON, "id": weapon_id})
	for passive_id: String in passives:
		if not OFFERABLE_PASSIVES.has(passive_id):
			continue
		var passive: Dictionary = passives[passive_id]
		if int(passive_stacks.get(passive_id, 0)) < int(passive.get("max_stacks", 0)):
			pool.append({"kind": KIND_PASSIVE, "id": passive_id})
	return pool


## Draw up to `count` distinct choices from the pool without mutating it.
static func pick(
	pool: Array[Dictionary], count: int, rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var shuffled: Array[Dictionary] = pool.duplicate()
	for i: int in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = swap
	return shuffled.slice(0, mini(count, shuffled.size()))


## Pure state transition for one picked card. Returns new copies:
## {"owned_levels": Dictionary, "passive_stacks": Dictionary}.
static func apply_choice(
	choice: Dictionary, owned_levels: Dictionary, passive_stacks: Dictionary
) -> Dictionary:
	var owned: Dictionary = owned_levels.duplicate()
	var stacks: Dictionary = passive_stacks.duplicate()
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		KIND_WEAPON_UP:
			owned[id] = int(owned.get(id, 0)) + 1
		KIND_NEW_WEAPON:
			owned[id] = 1
		KIND_PASSIVE:
			stacks[id] = int(stacks.get(id, 0)) + 1
		_:
			push_error("level_up: unknown choice kind in " + str(choice))
	return {"owned_levels": owned, "passive_stacks": stacks}


## Weapon stat at a given level: base + per_level delta per level past 1.
static func weapon_stat_at(stats: Dictionary, field: String, level: int) -> float:
	var base: float = float(stats.get(field, 0.0))
	var per_level: Dictionary = stats.get("per_level", {})
	return base + float(per_level.get(field, 0.0)) * float(level - 1)


static func display_name(
	choice: Dictionary, weapons: Dictionary, passives: Dictionary
) -> String:
	var id: String = String(choice.get("id", ""))
	var source: Dictionary = passives if String(choice.get("kind", "")) == KIND_PASSIVE else weapons
	return String((source.get(id, {}) as Dictionary).get("name_ko", id))


## Grade pill text — always words, never colour alone (DESIGN.md §2).
## Passives carry no grade in data and read as common.
static func grade_text(choice: Dictionary, weapons: Dictionary) -> String:
	if String(choice.get("kind", "")) == KIND_PASSIVE:
		return DEFAULT_GRADE_KO
	var stats: Dictionary = weapons.get(String(choice.get("id", "")), {})
	return String(GRADE_KO.get(String(stats.get("grade", "")), DEFAULT_GRADE_KO))


## Small label under the icon well: next level for anything already owned,
## 신규! for a first acquisition (new weapon or first passive stack).
static func well_label(
	choice: Dictionary, owned_levels: Dictionary, passive_stacks: Dictionary
) -> String:
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		KIND_WEAPON_UP:
			return "Lv.%d" % (int(owned_levels.get(id, 0)) + 1)
		KIND_PASSIVE:
			var stacks: int = int(passive_stacks.get(id, 0))
			return "신규!" if stacks == 0 else "Lv.%d" % (stacks + 1)
	return "신규!"


## Effect description with real numbers, per the owner's rule — never a bare
## level counter. Weapon-up shows before→after, passives show +N% (next/max).
static func describe(
	choice: Dictionary,
	weapons: Dictionary,
	passives: Dictionary,
	owned_levels: Dictionary,
	passive_stacks: Dictionary
) -> String:
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		KIND_WEAPON_UP:
			var stats: Dictionary = weapons.get(id, {})
			var level: int = int(owned_levels.get(id, 1))
			return "피해 %s→%s · 쿨다운 %s초→%s초" % [
				_fmt(weapon_stat_at(stats, "damage", level)),
				_fmt(weapon_stat_at(stats, "damage", level + 1)),
				_fmt(weapon_stat_at(stats, "cooldown_sec", level)),
				_fmt(weapon_stat_at(stats, "cooldown_sec", level + 1)),
			]
		KIND_NEW_WEAPON:
			var stats: Dictionary = weapons.get(id, {})
			return "새 무기 — 피해 %s · 쿨다운 %s초" % [
				_fmt(float(stats.get("damage", 0.0))),
				_fmt(float(stats.get("cooldown_sec", 0.0))),
			]
		KIND_PASSIVE:
			var passive: Dictionary = passives.get(id, {})
			var per_stack: float = float(passive.get("per_stack", 0.0))
			var next_stack: int = int(passive_stacks.get(id, 0)) + 1
			var max_stacks: int = int(passive.get("max_stacks", 0))
			var amount: String = (
				"+%d" % int(round(per_stack)) if per_stack >= 1.0
				else "+%d%%" % int(round(per_stack * 100.0))
			)
			return "%s %s (%d/%d)" % [
				String(passive.get("name_ko", id)), amount, next_stack, max_stacks
			]
	return ""


## Display dict for the shared paper-panel card component (LevelUpPopup.open):
## {"name", "desc", "well_label", "grade", "payload"} — payload is the raw
## choice routed back through the popup's picked signal.
static func as_card(
	choice: Dictionary,
	weapons: Dictionary,
	passives: Dictionary,
	owned_levels: Dictionary,
	passive_stacks: Dictionary
) -> Dictionary:
	return {
		"name": display_name(choice, weapons, passives),
		"desc": describe(choice, weapons, passives, owned_levels, passive_stacks),
		"well_label": well_label(choice, owned_levels, passive_stacks),
		"grade": grade_text(choice, weapons),
		"payload": choice,
	}


## Trim trailing zeros so "12.0" reads as 12 but "1.15" stays exact.
static func _fmt(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return String.num(value, 2)
