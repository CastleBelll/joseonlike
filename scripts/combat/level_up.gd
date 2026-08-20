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
const DEFAULT_GRADE_ID := "common"
const GRADE_UP_LABEL := "등급↑"
## N9-27: what a grade rung actually grants, for card copy. Grades no longer
## touch damage or cooldown — describing them that way would print an
## unchanged number and read as a card that does nothing.
const GRADE_EFFECT_LABELS: Dictionary = {
	"crit_chance": "치명타 확률",
	"crit_damage": "치명타 피해",
}
const MOD_LABEL := "변신!"
const MOD_NAME := "개조"
## N4-9 knowledge rule: a mod result the 괴이록 has not recorded yet shows as
## this mask — performing the evolution is what makes the recipe legible.
const UNKNOWN_RESULT := "???"

## Only stats the current runtime actually applies may be offered; a card
## that changes nothing would lie to the player.
## ponytail: whitelist, grows as stats get wired into combat.
## N9-3: xp_gain (orb pickup), luck (special-drop odds) and
## projectile_speed (AutoWeapon speed scale) wired and offered; N9-3g adds
## defense (damage-taken scale, floored) and projectile_count (flat bonus
## folded into effective weapon stats).
const OFFERABLE_PASSIVES: Array[String] = [
	"attack_damage", "attack_speed", "move_speed", "max_hp", "magnet_radius",
	"xp_gain", "luck", "projectile_speed", "defense", "projectile_count",
	"crit_chance", "crit_damage"
]

## Mechanics the AutoWeapon runtime implements (N4-4a); a data entry with an
## unknown mechanic must never become a card.
const SUPPORTED_MECHANICS: Array[String] = [
	"straight", "pierce", "explosion", "chain", "melee_arc", "orbit",
	"ward", "summon", "shockwave", "curse"
]
## Mechanics that fly a Projectile and therefore need a positive speed.
const PROJECTILE_MECHANICS: Array[String] = [
	"straight", "pierce", "explosion", "chain", "curse"
]
## At or past this pierce count the card reads "everything on the line".
## N9-20: weapon levels gained per level-up card.
const LEVEL_STEP := 1

## N9-23 build slots (owner direction 2026-08-19). Without a cap the choice
## pool grows with everything the player has NOT taken, so a given weapon's
## upgrade card surfaced roughly three times in a whole run and level 5 — the
## 개조 gate — was unreachable no matter how hard the player focused. Capping
## the build narrows the pool to what is already in it, which is what makes
## investment reach the gate and what stops the run reading as a grab bag.
const WEAPON_SLOTS := 4
const PASSIVE_SLOTS := 4
const PIERCE_ALL := 99

## N4-8 milestone vocabulary: every field a weapons.json "milestones" delta
## may touch, mapped to its card fragment. validate_data rejects any other
## path, so a typo'd milestone fails CI instead of silently doing nothing.
## Labels without %s cover fields whose delta is negative (a reduction the
## player reads as a buff).
const MILESTONE_LABELS: Dictionary = {
	"projectile_count": "투사체 +%s",
	"pierce": "관통 +%s",
	"pierce_retention": "관통 피해 유지 +%s",
	"chain.jumps": "연쇄 +%s회",
	"chain.falloff": "도약 피해 유지 +%s",
	"chain.range_px": "연쇄 범위 +%s",
	"explosion.radius_px": "폭발 반경 +%s",
	"explosion.edge_falloff": "가장자리 피해 +%s",
	"arc.angle_deg": "원호 +%s°",
	"arc.knockback_scale": "넉백 +%s배",
	"orbit.speed_deg_s": "선회 속도 +%s",
	"orbit.radius_px": "선회 반경 +%s",
	"orbit.orb_radius_px": "구슬 크기 +%s",
	"ward.radius_px": "장판 반경 +%s",
	"ward.duration_sec": "장판 지속 +%s초",
	"ward.slow_scale": "감속 강화",
	"summon.lifetime_sec": "소환 지속 +%s초",
	"summon.attack_cooldown_sec": "소환수 공격 가속",
	"summon.speed": "소환수 이동 +%s",
	"shockwave.radius_px": "파동 반경 +%s",
	"shockwave.stun_sec": "기절 +%s초",
	"shockwave.knockback_scale": "넉백 +%s배",
	"on_hit_status.spread_count": "전염 +%s마리",
	"on_hit_status.dps": "지속 피해 +%s",
	"on_hit_status.spread_radius_px": "전파 반경 +%s",
	"on_hit_status.duration_sec": "상태 지속 +%s초",
	"on_hit_seal.burst_at": "봉인 폭발 조건 완화",
}
## Card marker for a level that crosses a milestone — the playtest harness
## keys its screenshot off this glyph, so keep the two in sync.
const MILESTONE_MARK := "★"


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
	replaced: Array = [],
	allowed_categories: Array = [],
	ignore_slots: bool = false
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var rungs: Array[String] = WeaponGrade.ladder(grades)
	var weapon_slots_left: bool = ignore_slots or owned_levels.size() < WEAPON_SLOTS
	var passive_slots_left: bool = (
		ignore_slots or _taken_passives(passive_stacks) < PASSIVE_SLOTS
	)
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue  # reserved config keys ("_grades") are not weapons
		if replaced.has(weapon_id):
			continue
		var stats: Dictionary = weapons[weapon_id]
		if owned_levels.has(weapon_id):
			if int(owned_levels[weapon_id]) < int(stats.get("max_level", 0)):
				pool.append({"kind": KIND_WEAPON_UP, "id": weapon_id})
			# N9-28 (owner direction): grade is what a MAXED weapon does next,
			# not a rival to levelling it. While both were offered they fought
			# for the same card slot — one card per subject id (N4-7) — so a
			# grade card silently cost that weapon a level, working against the
			# level-5 evolution gate. Offering it only at max level makes the
			# order explicit: level the weapon out, then specialise it.
			if int(owned_levels[weapon_id]) >= int(stats.get("max_level", 0)):
				var current: String = current_grade(weapon_id, weapons, owned_grades)
				if not rungs.is_empty() and not WeaponGrade.is_top(rungs, current):
					pool.append({"kind": KIND_GRADE_UP, "id": weapon_id})
		elif weapon_slots_left and not bool(stats.get("evolution_only", false)) \
				and runtime_can_fire(stats):
			# N9-5d weapon identity (GDD §3, owner report: the taoist was
			# offered the 각궁): a NEW weapon must belong to the character's
			# weapon_categories. Owned weapons upgrade regardless — identity
			# is enforced at acquisition, never retroactively.
			if not allowed_categories.is_empty() \
					and not allowed_categories.has(String(stats.get("category", ""))):
				continue
			pool.append({"kind": KIND_NEW_WEAPON, "id": weapon_id})
	for passive_id: String in passives:
		if not OFFERABLE_PASSIVES.has(passive_id):
			continue
		var passive: Dictionary = passives[passive_id]
		var stacks: int = int(passive_stacks.get(passive_id, 0))
		if stacks >= int(passive.get("max_stacks", 0)):
			continue
		# A passive already in the build always keeps growing; a NEW one only
		# while a slot is free.
		if stacks == 0 and not passive_slots_left:
			continue
		pool.append({"kind": KIND_PASSIVE, "id": passive_id})
	if not pool.is_empty():
		return pool
	# Safety net: a full build whose every weapon and passive is maxed would
	# otherwise hand back an empty screen. Re-open the slots rather than show
	# the player nothing.
	if weapon_slots_left and passive_slots_left:
		return pool  # genuinely nothing left to offer; caller falls back
	return candidates(
		weapons, passives, owned_levels, passive_stacks, owned_grades, grades,
		replaced, allowed_categories, true
	)


## Passives actually in the build — a zero-stack entry is not taken.
static func _taken_passives(passive_stacks: Dictionary) -> int:
	var count: int = 0
	for passive_id: String in passive_stacks:
		if int(passive_stacks[passive_id]) > 0:
			count += 1
	return count


## 개조 candidates (N4-6): one per recipe whose material is held, base weapon
## owned AND invested to the recipe's milestone level (N4-9 "level_required"),
## and result neither owned nor already replaced by an earlier mod.
## `waive_level_gate` exists for probes and harnesses that need to reach a
## recipe without staging the levels. It is NOT used in play any more: the FTUE
## once waived the gate on the first run, which taught a rule the second run
## contradicts (N9-31).
static func mod_candidates(
	mods: Dictionary,
	inventory: Dictionary,
	owned_levels: Dictionary,
	replaced: Array = [],
	waive_level_gate: bool = false
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		if int(inventory.get(String(mod.get("loot_id", "")), 0)) <= 0:
			continue
		var base_id: String = String(mod.get("weapon_id", ""))
		if not owned_levels.has(base_id):
			continue
		if not waive_level_gate \
				and int(owned_levels[base_id]) < int(mod.get("level_required", 1)):
			continue
		var result_id: String = String(mod.get("result_weapon", ""))
		if owned_levels.has(result_id) or replaced.has(result_id):
			continue
		pool.append({"kind": KIND_MOD, "id": mod_id, "mod": mod})
	return pool


## One level-up screen (N4-6): at most ONE 개조 card — attractive but never
## crowding out the pool — plus regular picks filling up to `count`. The mod
## card's weapons seed the distinctness set (N4-7), so the same weapon can
## never appear twice on one screen.
static func assemble(
	pool: Array[Dictionary],
	mod_pool: Array[Dictionary],
	count: int,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	if mod_pool.is_empty():
		return pick(pool, count, rng)
	var mod_choice: Dictionary = mod_pool[rng.randi_range(0, mod_pool.size() - 1)]
	var cards: Array[Dictionary] = [mod_choice]
	cards.append_array(pick(pool, count - 1, rng, subject_ids(mod_choice)))
	return cards


## The weapon/passive ids one card visibly represents — the distinctness key
## for a screen (N4-7). A mod card stands for both its base and its result.
static func subject_ids(choice: Dictionary) -> Array[String]:
	if String(choice.get("kind", "")) == KIND_MOD:
		var mod: Dictionary = choice.get("mod", {})
		return [String(mod.get("weapon_id", "")), String(mod.get("result_weapon", ""))]
	return [String(choice.get("id", ""))]


## Draw up to `count` choices from the pool without mutating it, guaranteed
## distinct by subject id (N4-7): the pool legitimately holds a level card AND
## a grade card for the same weapon, and one screen must never show both.
static func pick(
	pool: Array[Dictionary],
	count: int,
	rng: RandomNumberGenerator,
	excluded_ids: Array[String] = []
) -> Array[Dictionary]:
	var shuffled: Array[Dictionary] = pool.duplicate()
	for i: int in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = swap
	var taken: Array[String] = excluded_ids.duplicate()
	var picked: Array[Dictionary] = []
	for choice: Dictionary in shuffled:
		if picked.size() >= count:
			break
		var ids: Array[String] = subject_ids(choice)
		if ids.any(func(id: String) -> bool: return taken.has(id)):
			continue
		taken.append_array(ids)
		picked.append(choice)
	return picked


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
			# N9-21 (owner direction): one card = one weapon level.
			owned[id] = int(owned.get(id, 0)) + LEVEL_STEP
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


## Plain-language mechanic line (reuses Bestiary.MECHANIC_LINES — owner
## report: level-up cards were pure numbers, no reminder of what a weapon
## you already own actually does once your build has several of them).
static func _weapon_mechanic_line(stats: Dictionary) -> String:
	return Bestiary.mechanic_line(String(stats.get("mechanic", "straight")), "ko")


## Mechanic fragment for cards (N4-4a), real numbers from data — how this
## weapon hits, plus any status/seal branch. Empty for a plain straight throw.
static func mechanic_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	match String(stats.get("mechanic", "straight")):
		"explosion":
			# Player-facing copy: no "px" — engine units are dev jargon (QA-2).
			parts.append(UiLocale.t("폭발 반경 %s") % _fmt(
				float((stats.get("explosion", {}) as Dictionary).get("radius_px", 0.0))
			))
		"chain":
			var chain: Dictionary = stats.get("chain", {})
			parts.append(UiLocale.t("연쇄 %d회 · 도약당 피해 %d%%") % [
				int(chain.get("jumps", 0)),
				int(round(float(chain.get("falloff", 1.0)) * 100.0)),
			])
		"melee_arc":
			var arc: Dictionary = stats.get("arc", {})
			parts.append(UiLocale.t("%s° 원호 · 넉백 %s배") % [
				_fmt(float(arc.get("angle_deg", 0.0))),
				_fmt(float(arc.get("knockback_scale", 1.0))),
			])
		"orbit":
			var orbit: Dictionary = stats.get("orbit", {})
			parts.append(UiLocale.t("선회 구슬 %d개 · 반경 %s") % [
				int(stats.get("projectile_count", 1)),
				_fmt(float(orbit.get("radius_px", 0.0))),
			])
		"pierce":
			var pierce: int = int(stats.get("pierce", 0))
			parts.append(UiLocale.t("직선 전원 관통") if pierce >= PIERCE_ALL else UiLocale.t("관통 %d") % pierce)
		"ward":
			var ward: Dictionary = stats.get("ward", {})
			parts.append(UiLocale.t("장판 반경 %s · %s초 지속 · 이동 %d%%") % [
				_fmt(float(ward.get("radius_px", 0.0))),
				_fmt(float(ward.get("duration_sec", 0.0))),
				int(round(float(ward.get("slow_scale", 1.0)) * 100.0)),
			])
		"summon":
			var summon: Dictionary = stats.get("summon", {})
			parts.append(UiLocale.t("소환수 %s초 · %s초마다 공격") % [
				_fmt(float(summon.get("lifetime_sec", 0.0))),
				_fmt(float(summon.get("attack_cooldown_sec", 0.0))),
			])
		"shockwave":
			var shockwave: Dictionary = stats.get("shockwave", {})
			parts.append(UiLocale.t("파동 반경 %s · 기절 %s초 · 넉백 %s배") % [
				_fmt(float(shockwave.get("radius_px", 0.0))),
				_fmt(float(shockwave.get("stun_sec", 0.0))),
				_fmt(float(shockwave.get("knockback_scale", 1.0))),
			])
	var status: Dictionary = stats.get("on_hit_status", {})
	match String(status.get("id", "")):
		"burn":
			var burn: String = UiLocale.t("화상 초당 %s (%s초)") % [
				_fmt(float(status.get("dps", 0.0))),
				_fmt(float(status.get("duration_sec", 0.0))),
			]
			if float(status.get("spread_radius_px", 0.0)) > 0.0:
				burn += UiLocale.t(" · 사망 시 전파")
			parts.append(burn)
		"shock":
			parts.append(UiLocale.t("감전 이동 %d%% (%s초)") % [
				int(round(float(status.get("slow_scale", 1.0)) * 100.0)),
				_fmt(float(status.get("duration_sec", 0.0))),
			])
		"curse":
			parts.append(UiLocale.t("저주 초당 %s (%s초) · 사망 시 %d마리 전염") % [
				_fmt(float(status.get("dps", 0.0))),
				_fmt(float(status.get("duration_sec", 0.0))),
				int(status.get("spread_count", 0)),
			])
	var seal: Dictionary = stats.get("on_hit_seal", {})
	if not seal.is_empty():
		parts.append(UiLocale.t("봉인 %d중첩 시 %s배 폭발") % [
			int(seal.get("burst_at", 0)),
			_fmt(float(seal.get("burst_damage_scale", 0.0))),
		])
	if float(stats.get("lifesteal", 0.0)) > 0.0:
		parts.append(UiLocale.t("피해의 %d%% 흡혈") % int(round(float(stats.get("lifesteal", 0.0)) * 100.0)))
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


## N4-8 milestone growth: effective stats at `level` — every "milestones"
## delta at or below the level folded in additively (numbers add, nested
## dicts recurse). damage/cooldown_sec stay per_level's job (validated), so
## WeaponGrade.stat_at reads the same base either way. Additive deltas
## compose with the 명부수 branch bonuses MetaTree already folded in.
static func stats_at_level(stats: Dictionary, level: int) -> Dictionary:
	var milestones: Dictionary = stats.get("milestones", {})
	if milestones.is_empty():
		return stats
	var result: Dictionary = stats.duplicate(true)
	for key: String in milestones:
		if int(key) <= level:
			_merge_delta(result, milestones[key] as Dictionary)
	return result


## The single milestone delta a weapon gains AT exactly `level` (empty when
## the level is not a milestone) — the card and screenshot hook read this.
static func milestone_delta(stats: Dictionary, level: int) -> Dictionary:
	return (stats.get("milestones", {}) as Dictionary).get(str(level), {})


## Card fragment for one milestone delta, e.g. "투사체 +1 · 관통 +1".
## Unknown paths render nothing here; validate_data already rejects them.
static func milestone_text(delta: Dictionary, path: String = "") -> String:
	var parts: Array[String] = []
	for field: String in delta:
		var full: String = field if path.is_empty() else path + "." + field
		if delta[field] is Dictionary:
			var nested: String = milestone_text(delta[field] as Dictionary, full)
			if not nested.is_empty():
				parts.append(nested)
			continue
		var label: String = UiLocale.t(String(MILESTONE_LABELS.get(full, "")))
		if label.is_empty():
			continue
		parts.append(label % _fmt(float(delta[field])) if label.contains("%s") else label)
	return " · ".join(parts)


## GRADE_EFFECT_LABELS is a const, so it is built once at load and cannot hold
## translated text. step_summary prints its values straight onto the card, so
## they are translated here, at the moment the card is written.
static func _localized_grade_effects() -> Dictionary:
	var localized: Dictionary = {}
	for stat: String in GRADE_EFFECT_LABELS:
		localized[stat] = UiLocale.t(String(GRADE_EFFECT_LABELS[stat]))
	return localized


static func _merge_delta(target: Dictionary, delta: Dictionary) -> void:
	for field: String in delta:
		if delta[field] is Dictionary:
			if target.get(field) is not Dictionary:
				target[field] = {}
			_merge_delta(target[field] as Dictionary, delta[field] as Dictionary)
		else:
			target[field] = float(target.get(field, 0.0)) + float(delta[field])


static func display_name(
	choice: Dictionary, weapons: Dictionary, passives: Dictionary
) -> String:
	if String(choice.get("kind", "")) == KIND_MOD:
		return UiLocale.t(MOD_NAME)
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


## Resolved grade key for a card — drives the pill tint (QA-3); the words on
## the pill stay the primary signal, never colour alone (DESIGN.md §2).
## Passives carry no grade in data and read as common. Weapons show their
## run grade; a grade-up card shows the grade it grants (N4-2).
static func grade_id(
	choice: Dictionary,
	weapons: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {}
) -> String:
	if String(choice.get("kind", "")) == KIND_PASSIVE:
		return DEFAULT_GRADE_ID
	if String(choice.get("kind", "")) == KIND_MOD:
		# The pill shows the RESULT weapon's grade after the carry (N4-6).
		return mod_carried_grade(
			choice.get("mod", {}) as Dictionary, weapons, owned_grades, grades
		)
	var id: String = String(choice.get("id", ""))
	var grade: String = current_grade(id, weapons, owned_grades)
	if String(choice.get("kind", "")) == KIND_GRADE_UP:
		grade = WeaponGrade.next(WeaponGrade.ladder(grades), grade)
	return grade


## Grade pill text — the localized word for grade_id.
static func grade_text(
	choice: Dictionary,
	weapons: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {}
) -> String:
	return UiLocale.t(
		String(GRADE_KO.get(grade_id(choice, weapons, owned_grades, grades), DEFAULT_GRADE_KO))
	)


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
			return UiLocale.t(GRADE_UP_LABEL)
		KIND_MOD:
			return UiLocale.t(MOD_LABEL)
		KIND_PASSIVE:
			var stacks: int = int(passive_stacks.get(id, 0))
			return UiLocale.t("신규!") if stacks == 0 else "Lv.%d" % (stacks + 1)
	return UiLocale.t("신규!")


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
	grades: Dictionary = {},
	masked_results: Array = []
) -> String:
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		KIND_WEAPON_UP:
			var stats: Dictionary = weapons.get(id, {})
			var level: int = int(owned_levels.get(id, 1))
			var grade: String = current_grade(id, weapons, owned_grades)
			var numbers: String = UiLocale.t("피해 %s→%s · 쿨다운 %s초→%s초") % [
				_fmt(WeaponGrade.stat_at(stats, "damage", level, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "damage", level + 1, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "cooldown_sec", level, grade, grades)),
				_fmt(WeaponGrade.stat_at(stats, "cooldown_sec", level + 1, grade, grades)),
			]
			# N4-8: a level that crosses a milestone sells the mechanic change,
			# not just the numbers — that IS the reason to pick this card.
			var extra: String = milestone_text(milestone_delta(stats, level + 1))
			if not extra.is_empty():
				return "%s · %s%s" % [numbers, MILESTONE_MARK, extra]
			# No milestone this level — lead with the plain-language mechanic
			# reminder instead (owner report: pure numbers read as noise once
			# a build has several weapons and you forget which does what).
			return "%s · %s" % [_weapon_mechanic_line(stats), numbers]
		KIND_GRADE_UP:
			var stats: Dictionary = weapons.get(id, {})
			var grade: String = current_grade(id, weapons, owned_grades)
			var raised: String = WeaponGrade.next(WeaponGrade.ladder(grades), grade)
			var granted: String = WeaponGrade.step_summary(
				grades, raised, _localized_grade_effects()
			)
			if granted.is_empty():
				granted = UiLocale.t("등급 상승")
			return UiLocale.t("%s · 등급 %s→%s · %s") % [
				_weapon_mechanic_line(stats),
				UiLocale.t(String(GRADE_KO.get(grade, DEFAULT_GRADE_KO))),
				UiLocale.t(String(GRADE_KO.get(raised, DEFAULT_GRADE_KO))),
				granted,
			]
		KIND_MOD:
			# Reads like the old loot popup did: the full transformation, plus
			# the real damage change at the carried level and grade (N4-6).
			var mod: Dictionary = choice.get("mod", {})
			var base_id: String = String(mod.get("weapon_id", ""))
			var result_id: String = String(mod.get("result_weapon", ""))
			# N4-9: an evolution this profile has never performed stays a
			# mystery — no result name, numbers or mechanic until the 괴이록
			# records it. Knowledge is earned by doing it once.
			if masked_results.has(result_id):
				return UiLocale.t("%s → %s (레벨 유지)") % [
					String((weapons.get(base_id, {}) as Dictionary).get("name_ko", base_id)),
					UNKNOWN_RESULT,
				]
			var level: int = int(owned_levels.get(base_id, 1))
			var carried: String = mod_carried_grade(mod, weapons, owned_grades, grades)
			var line: String = UiLocale.t("%s → %s · 피해 %s→%s (레벨 유지)") % [
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
			# The plain-language mechanic line now covers what mechanic_text's
			# raw numbers used to be the ONLY explanation for — keeping both
			# doubled the card length for no added clarity.
			return UiLocale.t("%s — 피해 %s · 쿨다운 %s초") % [
				_weapon_mechanic_line(stats),
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


## Weapon id whose icon the card's well shows (N3-13): the weapon itself for
## every weapon kind, the RESULT weapon for a mod (the card sells the
## transformation), and none for passives — they keep the letter glyph until
## passive icons exist.
static func icon_weapon_id(choice: Dictionary) -> String:
	match String(choice.get("kind", "")):
		KIND_PASSIVE:
			return ""
		KIND_MOD:
			return String((choice.get("mod", {}) as Dictionary).get("result_weapon", ""))
	return String(choice.get("id", ""))


## Loot id whose icon the card shows (N3-13): only the mod card shows a
## material — the one the recipe consumes.
static func icon_loot_id(choice: Dictionary) -> String:
	if String(choice.get("kind", "")) != KIND_MOD:
		return ""
	return String((choice.get("mod", {}) as Dictionary).get("loot_id", ""))


## Display dict for the shared paper-panel card component (LevelUpPopup.open):
## {"name", "desc", "well_label", "grade", "grade_id", "icon_weapon_id",
## "icon_loot_id", "payload"} — payload is the raw choice routed back through
## the popup's picked signal.
static func as_card(
	choice: Dictionary,
	weapons: Dictionary,
	passives: Dictionary,
	owned_levels: Dictionary,
	passive_stacks: Dictionary,
	owned_grades: Dictionary = {},
	grades: Dictionary = {},
	masked_results: Array = []
) -> Dictionary:
	# N4-9: a masked mod result must not leak through its icon either — the
	# well falls back to the material icon the card already shows.
	var icon_id: String = icon_weapon_id(choice)
	if masked_results.has(icon_id):
		icon_id = ""
	return {
		"name": display_name(choice, weapons, passives),
		"desc": describe(
			choice, weapons, passives, owned_levels, passive_stacks, owned_grades,
			grades, masked_results
		),
		"well_label": well_label(choice, owned_levels, passive_stacks),
		"grade": grade_text(choice, weapons, owned_grades, grades),
		"grade_id": grade_id(choice, weapons, owned_grades, grades),
		"icon_weapon_id": icon_id,
		"icon_loot_id": icon_loot_id(choice),
		"icon_passive_id": (
			String(choice.get("id", ""))
			if String(choice.get("kind", "")) == KIND_PASSIVE else ""
		),
		"payload": choice,
	}


## Trim trailing zeros so "12.0" reads as 12 but "1.15" stays exact.
static func _fmt(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return String.num(value, 2)
