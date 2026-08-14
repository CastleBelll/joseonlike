class_name LevelUp
extends RefCounted
## Pure choice-pool and description helpers for the power-up popup (N3-6).
## All inputs are plain Dictionaries parsed from data/*.json by the caller,
## so every function here is testable headless with fixture data.
##
## Choice shape: {"kind": "weapon_up"|"new_weapon"|"passive"|"grade_up",
## "id": String}. N4-6 adds {"kind": "weapon_mod", "id": mod_id,
## "mod": Dictionary} — the 개조 choice folded in from the old loot popup.

const KIND_WEAPON_UP := "weapon_up"
const KIND_NEW_WEAPON := "new_weapon"
const KIND_PASSIVE := "passive"
const KIND_GRADE_UP := "grade_up"
const KIND_MOD := "weapon_mod"

const GRADE_KO := {
	"common": "일반", "uncommon": "고급", "rare": "희귀",
	"epic": "영웅", "mythic": "신화"
}
const DEFAULT_GRADE_KO := "일반"
const GRADE_UP_LABEL := "등급↑"
const MOD_LABEL := "변신!"
const MOD_NAME := "개조"

## Only stats the current runtime actually applies may be offered; a card
## that changes nothing would lie to the player.
## ponytail: whitelist, grows as stats get wired into combat.
const OFFERABLE_PASSIVES: Array[String] = [
	"attack_damage", "attack_speed", "move_speed", "max_hp", "magnet_radius"
]

## Mechanics the AutoWeapon runtime implements (N4-4a); a data entry with an
## unknown mechanic must never become a card.
const SUPPORTED_MECHANICS: Array[String] = [
	"straight", "pierce", "explosion", "chain", "melee_arc", "orbit"
]
## Mechanics that fly a Projectile and therefore need a positive speed.
const PROJECTILE_MECHANICS: Array[String] = ["straight", "pierce", "explosion", "chain"]
## At or past this pierce count the card reads "everything on the line".
const PIERCE_ALL := 99


## Every legal choice given the current run: owned weapons below max level,
## unowned non-evolution weapons the AutoWeapon runtime can fire (speed > 0),
## whitelisted passives below their stack cap, and — when a grade ladder is
## configured (N4-2) — a grade raise for each owned weapon below the top rung.
## `replaced` (N4-6) lists weapons a mod swapped away this run: they are out
## of BOTH the new-weapon and the upgrade pool for good.
static func candidates(
	weapons: Dictionary,
	passives: Dictionary,
	owned_levels: Dictionary,
	passive_stacks: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {},
	replaced: Array = []
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var rungs: Array[String] = WeaponGrade.ladder(grades)
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue  # reserved config keys ("_grades") are not weapons
		if replaced.has(weapon_id):
			continue
		var stats: Dictionary = weapons[weapon_id]
		if owned_levels.has(weapon_id):
			if int(owned_levels[weapon_id]) < int(stats.get("max_level", 0)):
				pool.append({"kind": KIND_WEAPON_UP, "id": weapon_id})
			# Grade-up is deliberately independent of the level cap (GDD §33:
			# the two growth axes are separate), so a max-level weapon can
			# still climb the ladder.
			var current: String = current_grade(weapon_id, weapons, owned_grades)
			if not rungs.is_empty() and not WeaponGrade.is_top(rungs, current):
				pool.append({"kind": KIND_GRADE_UP, "id": weapon_id})
		elif not bool(stats.get("evolution_only", false)) and runtime_can_fire(stats):
			pool.append({"kind": KIND_NEW_WEAPON, "id": weapon_id})
	for passive_id: String in passives:
		if not OFFERABLE_PASSIVES.has(passive_id):
			continue
		var passive: Dictionary = passives[passive_id]
		if int(passive_stacks.get(passive_id, 0)) < int(passive.get("max_stacks", 0)):
			pool.append({"kind": KIND_PASSIVE, "id": passive_id})
	return pool


## 개조 candidates (N4-6): one per recipe whose material is held, base weapon
## owned, and result neither owned nor already replaced by an earlier mod.
static func mod_candidates(
	mods: Dictionary,
	inventory: Dictionary,
	owned_levels: Dictionary,
	replaced: Array = []
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		if int(inventory.get(String(mod.get("loot_id", "")), 0)) <= 0:
			continue
		if not owned_levels.has(String(mod.get("weapon_id", ""))):
			continue
		var result_id: String = String(mod.get("result_weapon", ""))
		if owned_levels.has(result_id) or replaced.has(result_id):
			continue
		pool.append({"kind": KIND_MOD, "id": mod_id, "mod": mod})
	return pool


## One level-up screen (N4-6): at most ONE 개조 card — attractive but never
## crowding out the pool — plus regular picks filling up to `count`.
static func assemble(
	pool: Array[Dictionary],
	mod_pool: Array[Dictionary],
	count: int,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	if mod_pool.is_empty():
		return pick(pool, count, rng)
	var cards: Array[Dictionary] = [mod_pool[rng.randi_range(0, mod_pool.size() - 1)]]
	cards.append_array(pick(pool, count - 1, rng))
	return cards


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
## {"owned_levels": Dictionary, "passive_stacks": Dictionary}. Grade raises
## live in the separate owned_grades dict, handled by the stage.
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
		KIND_GRADE_UP:
			pass  # level/stack state untouched; the grade dict is the stage's
		_:
			push_error("level_up: unknown choice kind in " + str(choice))
	return {"owned_levels": owned, "passive_stacks": stacks}


## True when the AutoWeapon runtime can actually drive this data entry
## (N4-4a): the mechanic must be implemented, and projectile mechanics also
## need a positive speed — the old speed-only gate kept for them.
static func runtime_can_fire(stats: Dictionary) -> bool:
	var mechanic: String = String(stats.get("mechanic", "straight"))
	if mechanic not in SUPPORTED_MECHANICS:
		return false
	if mechanic in PROJECTILE_MECHANICS:
		return float(stats.get("speed", 0.0)) > 0.0
	return true


## Mechanic fragment for cards (N4-4a), real numbers from data — how this
## weapon hits, plus any status/seal branch. Empty for a plain straight throw.
static func mechanic_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	match String(stats.get("mechanic", "straight")):
		"explosion":
			parts.append("폭발 반경 %spx" % _fmt(
				float((stats.get("explosion", {}) as Dictionary).get("radius_px", 0.0))
			))
		"chain":
			var chain: Dictionary = stats.get("chain", {})
			parts.append("연쇄 %d회 · 도약당 피해 %d%%" % [
				int(chain.get("jumps", 0)),
				int(round(float(chain.get("falloff", 1.0)) * 100.0)),
			])
		"melee_arc":
			var arc: Dictionary = stats.get("arc", {})
			parts.append("%s° 원호 · 넉백 %s배" % [
				_fmt(float(arc.get("angle_deg", 0.0))),
				_fmt(float(arc.get("knockback_scale", 1.0))),
			])
		"orbit":
			var orbit: Dictionary = stats.get("orbit", {})
			parts.append("선회 구슬 %d개 · 반경 %spx" % [
				int(stats.get("projectile_count", 1)),
				_fmt(float(orbit.get("radius_px", 0.0))),
			])
		"pierce":
			var pierce: int = int(stats.get("pierce", 0))
			parts.append("직선 전원 관통" if pierce >= PIERCE_ALL else "관통 %d" % pierce)
	var status: Dictionary = stats.get("on_hit_status", {})
	match String(status.get("id", "")):
		"burn":
			var burn: String = "화상 초당 %s (%s초)" % [
				_fmt(float(status.get("dps", 0.0))),
				_fmt(float(status.get("duration_sec", 0.0))),
			]
			if float(status.get("spread_radius_px", 0.0)) > 0.0:
				burn += " · 사망 시 전파"
			parts.append(burn)
		"shock":
			parts.append("감전 이동 %d%% (%s초)" % [
				int(round(float(status.get("slow_scale", 1.0)) * 100.0)),
				_fmt(float(status.get("duration_sec", 0.0))),
			])
	var seal: Dictionary = stats.get("on_hit_seal", {})
	if not seal.is_empty():
		parts.append("봉인 %d중첩 시 %s배 폭발" % [
			int(seal.get("burst_at", 0)),
			_fmt(float(seal.get("burst_damage_scale", 0.0))),
		])
	if float(stats.get("lifesteal", 0.0)) > 0.0:
		parts.append("피해의 %d%% 흡혈" % int(round(float(stats.get("lifesteal", 0.0)) * 100.0)))
	return " · ".join(parts)


## A weapon's run grade: the tracked raise if any, else its data base grade.
static func current_grade(
	weapon_id: String, weapons: Dictionary, owned_grades: Dictionary
) -> String:
	var base: String = String((weapons.get(weapon_id, {}) as Dictionary).get("grade", ""))
	return String(owned_grades.get(weapon_id, base))


## Weapon stat at a given level: base + per_level delta per level past 1.
static func weapon_stat_at(stats: Dictionary, field: String, level: int) -> float:
	var base: float = float(stats.get(field, 0.0))
	var per_level: Dictionary = stats.get("per_level", {})
	return base + float(per_level.get(field, 0.0)) * float(level - 1)


static func display_name(
	choice: Dictionary, weapons: Dictionary, passives: Dictionary
) -> String:
	if String(choice.get("kind", "")) == KIND_MOD:
		return MOD_NAME
	var id: String = String(choice.get("id", ""))
	var source: Dictionary = passives if String(choice.get("kind", "")) == KIND_PASSIVE else weapons
	return String((source.get(id, {}) as Dictionary).get("name_ko", id))


## The grade a mod result lands on: the base weapon's run grade carries, but
## never below the result weapon's own data grade (mirrors the stage swap).
static func mod_carried_grade(
	mod: Dictionary, weapons: Dictionary, owned_grades: Dictionary, grades: Dictionary
) -> String:
	return WeaponGrade.highest(
		WeaponGrade.ladder(grades),
		current_grade(String(mod.get("weapon_id", "")), weapons, owned_grades),
		current_grade(String(mod.get("result_weapon", "")), weapons, {})
	)


## Grade pill text — always words, never colour alone (DESIGN.md §2).
## Passives carry no grade in data and read as common. Weapons show their
## run grade; a grade-up card shows the grade it grants (N4-2).
static func grade_text(
	choice: Dictionary,
	weapons: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {}
) -> String:
	if String(choice.get("kind", "")) == KIND_PASSIVE:
		return DEFAULT_GRADE_KO
	if String(choice.get("kind", "")) == KIND_MOD:
		# The pill shows the RESULT weapon's grade after the carry (N4-6).
		var carried: String = mod_carried_grade(
			choice.get("mod", {}) as Dictionary, weapons, owned_grades, grades
		)
		return String(GRADE_KO.get(carried, DEFAULT_GRADE_KO))
	var id: String = String(choice.get("id", ""))
	var grade: String = current_grade(id, weapons, owned_grades)
	if String(choice.get("kind", "")) == KIND_GRADE_UP:
		grade = WeaponGrade.next(WeaponGrade.ladder(grades), grade)
	return String(GRADE_KO.get(grade, DEFAULT_GRADE_KO))


## Small label under the icon well: next level for anything already owned,
## 신규! for a first acquisition (new weapon or first passive stack).
static func well_label(
	choice: Dictionary, owned_levels: Dictionary, passive_stacks: Dictionary
) -> String:
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		KIND_WEAPON_UP:
			return "Lv.%d" % (int(owned_levels.get(id, 0)) + 1)
		KIND_GRADE_UP:
			return GRADE_UP_LABEL
		KIND_MOD:
			return MOD_LABEL
		KIND_PASSIVE:
			var stacks: int = int(passive_stacks.get(id, 0))
			return "신규!" if stacks == 0 else "Lv.%d" % (stacks + 1)
	return "신규!"


## Effect description with real numbers, per the owner's rule — never a bare
## level counter. Weapon-up shows before→after (at the weapon's run grade),
## grade-up shows the grade jump with its damage delta, passives show +N%.
static func describe(
	choice: Dictionary,
	weapons: Dictionary,
	passives: Dictionary,
	owned_levels: Dictionary,
	passive_stacks: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {}
) -> String:
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		KIND_WEAPON_UP:
			var stats: Dictionary = weapons.get(id, {})
			var level: int = int(owned_levels.get(id, 1))
			var grade: String = current_grade(id, weapons, owned_grades)
			return "피해 %s→%s · 쿨다운 %s초→%s초" % [
				_fmt(WeaponGrade.stat_at(stats, "damage", level, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "damage", level + 1, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "cooldown_sec", level, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "cooldown_sec", level + 1, grade, grades)),
			]
		KIND_GRADE_UP:
			var stats: Dictionary = weapons.get(id, {})
			var level: int = int(owned_levels.get(id, 1))
			var grade: String = current_grade(id, weapons, owned_grades)
			var raised: String = WeaponGrade.next(WeaponGrade.ladder(grades), grade)
			return "등급 %s→%s · 피해 %s→%s" % [
				String(GRADE_KO.get(grade, DEFAULT_GRADE_KO)),
				String(GRADE_KO.get(raised, DEFAULT_GRADE_KO)),
				_fmt(WeaponGrade.stat_at(stats, "damage", level, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "damage", level, raised, grades)),
			]
		KIND_MOD:
			# Reads like the old loot popup did: the full transformation, plus
			# the real damage change at the carried level and grade (N4-6).
			var mod: Dictionary = choice.get("mod", {})
			var base_id: String = String(mod.get("weapon_id", ""))
			var result_id: String = String(mod.get("result_weapon", ""))
			var level: int = int(owned_levels.get(base_id, 1))
			var carried: String = mod_carried_grade(mod, weapons, owned_grades, grades)
			var line: String = "%s → %s · 피해 %s→%s (레벨 유지)" % [
				String((weapons.get(base_id, {}) as Dictionary).get("name_ko", base_id)),
				String((weapons.get(result_id, {}) as Dictionary).get("name_ko", result_id)),
				_fmt(WeaponGrade.stat_at(
					weapons.get(base_id, {}) as Dictionary, "damage", level,
					current_grade(base_id, weapons, owned_grades), grades
				)),
				_fmt(WeaponGrade.stat_at(
					weapons.get(result_id, {}) as Dictionary, "damage", level, carried, grades
				)),
			]
			# The branch the mod buys (burn spread, shock, seal…) is the point
			# of the card (N4-4a) — spell it out with the result's numbers.
			var extra: String = mechanic_text(weapons.get(result_id, {}) as Dictionary)
			return line if extra.is_empty() else "%s · %s" % [line, extra]
		KIND_NEW_WEAPON:
			var stats: Dictionary = weapons.get(id, {})
			var line: String = "새 무기 — 피해 %s · 쿨다운 %s초" % [
				_fmt(float(stats.get("damage", 0.0))),
				_fmt(float(stats.get("cooldown_sec", 0.0))),
			]
			var extra: String = mechanic_text(stats)
			return line if extra.is_empty() else "%s · %s" % [line, extra]
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
	passive_stacks: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {}
) -> Dictionary:
	return {
		"name": display_name(choice, weapons, passives),
		"desc": describe(
			choice, weapons, passives, owned_levels, passive_stacks, owned_grades, grades
		),
		"well_label": well_label(choice, owned_levels, passive_stacks),
		"grade": grade_text(choice, weapons, owned_grades, grades),
		"payload": choice,
	}


## Trim trailing zeros so "12.0" reads as 12 but "1.15" stays exact.
static func _fmt(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return String.num(value, 2)
