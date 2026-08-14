class_name ChoiceText
extends RefCounted
## Builds the level-up choice descriptions from data numbers, per locale.
##
## Owner feedback 2026-08-14: "1/5" alone says nothing — every choice must
## say what actually grows and by how much. All numbers come straight from
## data/*.json; this file only formats them (no Korean copy beyond stat
## labels, which are UI chrome like LocaleText.UI_STRINGS).

## weapons.json stat keys worth showing, in display order, with unit info.
const WEAPON_STAT_LABELS: Array[Dictionary] = [
	{"key": "damage", "ko": "피해", "en": "DMG", "seconds": false},
	{"key": "cooldown_sec", "ko": "쿨다운", "en": "CD", "seconds": true},
	{"key": "projectile_count", "ko": "투사체", "en": "Shots", "seconds": false},
	{"key": "pierce", "ko": "관통", "en": "Pierce", "seconds": false},
	{"key": "area_scale", "ko": "범위", "en": "Area", "seconds": false},
	{"key": "speed", "ko": "탄속", "en": "Speed", "seconds": false},
]

const SEPARATOR := " · "


## "피해 +3.5 · 쿨다운 -0.05초" from a weapons.json per_level object.
static func weapon_upgrade_description(per_level: Dictionary, locale: String) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in WEAPON_STAT_LABELS:
		var key: String = entry["key"]
		if not per_level.has(key):
			continue
		var delta: float = float(per_level[key])
		if is_zero_approx(delta):
			continue
		parts.append("%s %s" % [entry[locale], _signed(delta, bool(entry["seconds"]), locale)])
	return SEPARATOR.join(parts)


## "피해 12 · 쿨다운 1.2초 · 관통 1" for a brand-new weapon's base numbers.
static func weapon_base_description(weapon_data: Dictionary, locale: String) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in WEAPON_STAT_LABELS:
		var key: String = entry["key"]
		if not weapon_data.has(key):
			continue
		var value: float = float(weapon_data[key])
		# Zero-value stats (0 pierce, 0 melee speed) are noise on a card.
		if is_zero_approx(value):
			continue
		parts.append("%s %s" % [entry[locale], _plain(value, bool(entry["seconds"]), locale)])
	return SEPARATOR.join(parts)


## "+8% (2/5)" — or "+1 (1/2)" for flat stats such as projectile_count.
static func passive_description(per_stack: float, next_stacks: int, max_stacks: int) -> String:
	var bonus: String
	if per_stack >= 1.0:
		bonus = "+%d" % int(round(per_stack))
	else:
		bonus = "+%d%%" % int(round(per_stack * 100.0))
	return "%s (%d/%d)" % [bonus, next_stacks, max_stacks]


static func _signed(value: float, seconds: bool, locale: String) -> String:
	var text: String = ("+" if value > 0.0 else "") + _trim(value)
	return text + _seconds_suffix(locale) if seconds else text


static func _plain(value: float, seconds: bool, locale: String) -> String:
	var text: String = _trim(value)
	return text + _seconds_suffix(locale) if seconds else text


static func _seconds_suffix(locale: String) -> String:
	return "초" if locale == "ko" else "s"


## "3.0" -> "3", "0.05" -> "0.05": integers read cleaner on a small card.
static func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % value).rstrip("0")
