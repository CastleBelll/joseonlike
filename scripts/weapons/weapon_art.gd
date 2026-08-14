class_name WeaponArt
extends RefCounted
## Which art a weapon uses in flight, on the swing, and on arrival.
##
## The travel and melee sprites are authored pointing EAST (+X) so one sprite
## covers every angle by rotation, instead of shipping eight variants per
## projectile (asset/ASSET_SET_GAPS_REPORT.md). Callers rotate local +X onto the
## velocity; nothing here scales or tints the art.
##
## The travel-to-impact pairing is quoted from that report rather than guessed
## from filenames, which is what the previous mapping had to do.

const TRAVEL_PATH: String = "res://asset/weapon/travel/%s.png"
const MELEE_PATH: String = "res://asset/weapon/melee/%s.png"

## Arrival art per travel sprite, exactly as the report's pairing table states.
const TRAVEL_IMPACTS: Dictionary = {
	&"spinning_talisman": &"talisman_burst",
	&"fireball": &"fireball_impact",
	&"spirit_bolt": &"spirit_bolt_impact",
	&"arrow": &"impact_hit",
	&"throwing_knife": &"impact_hit",
}

## Weapon to in-flight sprite. Melee weapons have no travel art.
const WEAPON_TRAVEL: Dictionary = {
	"old_talisman": &"spinning_talisman",
	"fire_talisman": &"fireball",
	"phoenix_talisman": &"spirit_bolt",
	# Lightning mod reuses the spirit bolt travel/impact pair until its own
	# art lands (asset/ASSET_REQUIREMENTS.md).
	"lightning_talisman": &"spirit_bolt",
	"beopgeom": &"spirit_bolt",
	"bow": &"arrow",
	"divine_bow": &"arrow",
}

## Weapon to swing art. Ranged and spiritual weapons have no melee art.
const WEAPON_MELEE: Dictionary = {
	"sword": &"wide_sword_arc",
	"twin_sword": &"dual_blade_cross",
	# R2-4 mod results reuse the base swings until their own art lands
	# (asset/ASSET_REQUIREMENTS.md).
	"sharp_sword": &"wide_sword_arc",
	"ghost_sword": &"heavy_overhead",
	"flame_sword": &"wide_sword_arc",
}

const GENERIC_IMPACT: StringName = &"impact_hit"


static func travel_id(weapon_id: String) -> StringName:
	return WEAPON_TRAVEL.get(weapon_id, &"")


static func melee_id(weapon_id: String) -> StringName:
	return WEAPON_MELEE.get(weapon_id, &"")


## Arrival effect for a weapon, via its travel art. Falls back to the generic
## hit so a weapon with no travel sprite still marks its landing.
static func impact_for_weapon(weapon_id: String) -> StringName:
	return TRAVEL_IMPACTS.get(travel_id(weapon_id), GENERIC_IMPACT)


static func travel_texture(weapon_id: String) -> Texture2D:
	return _load(TRAVEL_PATH, travel_id(weapon_id))


static func melee_texture(weapon_id: String) -> Texture2D:
	return _load(MELEE_PATH, melee_id(weapon_id))


static func _load(path_template: String, art_id: StringName) -> Texture2D:
	if art_id.is_empty():
		return null
	var path: String = path_template % art_id
	if not ResourceLoader.exists(path):
		push_warning("WeaponArt: missing %s" % path)
		return null
	return ResourceLoader.load(path) as Texture2D
