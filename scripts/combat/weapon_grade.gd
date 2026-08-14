class_name WeaponGrade
extends RefCounted
## Pure weapon-grade helpers (N4-2, GDD §5/§33 vertical axis). The ladder and
## per-step stat factors live in data/weapons.json under the reserved
## "_grades" key; weapons themselves keep their base "grade" field as the
## rung a fresh copy starts on. Everything here is node-free and testable
## headless with fixture dicts.

## Reserved weapons.json key holding {"ladder": [...], "steps": {...}}.
## Weapon iterators must skip keys with this prefix.
const CONFIG_KEY := "_grades"


static func config(weapons: Dictionary) -> Dictionary:
	return weapons.get(CONFIG_KEY, {})


static func ladder(grades: Dictionary) -> Array[String]:
	var rungs: Array[String] = []
	for grade: Variant in grades.get("ladder", []):
		rungs.append(String(grade))
	return rungs


## Unknown grades read as the bottom rung so bad data degrades, never crashes.
static func index_of(rungs: Array[String], grade: String) -> int:
	return maxi(rungs.find(grade), 0)


static func is_top(rungs: Array[String], grade: String) -> bool:
	return not rungs.is_empty() and index_of(rungs, grade) == rungs.size() - 1


## One rung up, clamped at the top of the ladder.
static func next(rungs: Array[String], grade: String) -> String:
	if rungs.is_empty():
		return grade
	return rungs[mini(index_of(rungs, grade) + 1, rungs.size() - 1)]


## The higher of two grades — the mod carry rule (GDD §33: 개조해도 현재
## 등급은 승계된다, and a result weapon's own base grade is a floor).
static func highest(rungs: Array[String], a: String, b: String) -> String:
	return a if index_of(rungs, a) >= index_of(rungs, b) else b


## Compound factor for `field` across every step above base_grade up to and
## including current_grade. Steps at or below the base rung never apply —
## a weapon's base stats already price its base grade in.
static func multiplier(
	grades: Dictionary, base_grade: String, current_grade: String, field: String
) -> float:
	var rungs: Array[String] = ladder(grades)
	var steps: Dictionary = grades.get("steps", {})
	var factor: float = 1.0
	for i: int in range(index_of(rungs, base_grade) + 1, index_of(rungs, current_grade) + 1):
		var step: Dictionary = steps.get(rungs[i], {})
		factor *= float((step.get("mult", {}) as Dictionary).get(field, 1.0))
	return factor


## True when any active step (above base, up to current) sets `flag`.
static func has_flag(
	grades: Dictionary, base_grade: String, current_grade: String, flag: String
) -> bool:
	var rungs: Array[String] = ladder(grades)
	var steps: Dictionary = grades.get("steps", {})
	for i: int in range(index_of(rungs, base_grade) + 1, index_of(rungs, current_grade) + 1):
		if bool((steps.get(rungs[i], {}) as Dictionary).get(flag, false)):
			return true
	return false


## Weapon stat with both the level curve and the grade factors applied.
## The base grade comes from the weapon's own data entry.
static func stat_at(
	stats: Dictionary, field: String, level: int, current_grade: String, grades: Dictionary
) -> float:
	return (
		LevelUp.weapon_stat_at(stats, field, level)
		* multiplier(grades, String(stats.get("grade", "")), current_grade, field)
	)
