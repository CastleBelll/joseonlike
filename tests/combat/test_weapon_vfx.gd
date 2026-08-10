extends RefCounted
## Weapon VFX wiring.
##
## The projectile and swing art is resolved in code from the weapon id, not from
## data, so nothing else would catch a renamed or missing file. This also pins
## the melee rule from the asset report: the collision circle is placed along the
## facing and never rotated, only the visual is.

const MeleeArcScript = preload("res://scripts/weapons/melee_arc.gd")

const VFX_DIR: String = "res://asset/weapon/projectiles/%s.png"
const WEAPONS_PATH: String = "res://data/weapons.json"
const SWORD_VFX: String = "res://asset/weapon/projectiles/sword.png"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_every_weapon_has_vfx())
	failures.append_array(_test_melee_arc_uses_authored_texture())
	failures.append_array(_test_melee_arc_falls_back())
	return failures


## Every id in weapons.json must have gameplay art, because WeaponBase builds the
## path from the id alone.
func _test_every_weapon_has_vfx() -> Array[String]:
	if not FileAccess.file_exists(WEAPONS_PATH):
		return ["could not read %s" % WEAPONS_PATH]
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(WEAPONS_PATH)) != OK:
		return ["%s is not valid JSON" % WEAPONS_PATH]
	var weapons: Dictionary = json.data
	var failures: Array[String] = []
	for weapon_key: Variant in weapons.keys():
		var path: String = VFX_DIR % String(weapon_key)
		if not ResourceLoader.exists(path):
			failures.append("weapon %s has no gameplay art at %s" % [weapon_key, path])
	return failures


func _test_melee_arc_uses_authored_texture() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists(SWORD_VFX):
		return ["missing %s" % SWORD_VFX]

	var arc: Area2D = MeleeArcScript.new()
	arc.facing = Vector2.UP
	arc.texture = ResourceLoader.load(SWORD_VFX)
	arc._ready()

	var visual: Node = arc.get_node_or_null(^"Visual")
	if visual == null:
		failures.append("arc should build a Visual node")
	elif not (visual is Sprite2D):
		failures.append("an authored arc should use a Sprite2D, got %s" % visual.get_class())
	else:
		var sprite: Sprite2D = visual
		if sprite.texture == null or sprite.texture.resource_path != SWORD_VFX:
			failures.append("Visual should carry the authored sword texture")
		if not is_equal_approx(sprite.rotation, Vector2.UP.angle()):
			failures.append("only the visual rotates to facing, expected %f got %f" % [
				Vector2.UP.angle(), sprite.rotation,
			])
	# The body must stay unrotated so the collision circle keeps its geometry.
	if not is_zero_approx(arc.rotation):
		failures.append("the arc body must not rotate, got %f" % arc.rotation)
	arc.free()
	return failures


## A weapon with no authored swing art must still present something.
func _test_melee_arc_falls_back() -> Array[String]:
	var arc: Area2D = MeleeArcScript.new()
	arc.facing = Vector2.RIGHT
	arc._ready()
	var failures: Array[String] = []
	var visual: Node = arc.get_node_or_null(^"Visual")
	if visual == null:
		failures.append("arc without a texture should still build a placeholder Visual")
	elif not (visual is Polygon2D):
		failures.append("placeholder arc should be a Polygon2D, got %s" % visual.get_class())
	arc.free()
	return failures
