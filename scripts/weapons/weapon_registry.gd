class_name WeaponRegistry
extends RefCounted
## Maps a weapon's data-declared category onto the script that implements it, so
## adding a weapon is a data edit and only a brand new *behaviour* needs code.

const CATEGORY_MELEE: String = "melee"
const CATEGORY_RANGED: String = "ranged"
const CATEGORY_SPIRITUAL: String = "spiritual"

const SCRIPTS: Dictionary = {
	CATEGORY_MELEE: preload("res://scripts/weapons/sword_weapon.gd"),
	CATEGORY_RANGED: preload("res://scripts/weapons/bow_weapon.gd"),
	CATEGORY_SPIRITUAL: preload("res://scripts/weapons/talisman_weapon.gd"),
}

const FALLBACK_CATEGORY: String = CATEGORY_SPIRITUAL


static func create(category: String) -> WeaponBase:
	var script_key: String = category
	if not SCRIPTS.has(script_key):
		push_warning("WeaponRegistry: unknown category '%s', falling back to %s" % [category, FALLBACK_CATEGORY])
		script_key = FALLBACK_CATEGORY
	var weapon_script: GDScript = SCRIPTS[script_key]
	return weapon_script.new() as WeaponBase
