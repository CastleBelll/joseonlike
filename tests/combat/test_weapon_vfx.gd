extends RefCounted
## Weapon VFX wiring.
##
## The projectile and swing art is resolved in code from the weapon id, not from
## data, so nothing else would catch a renamed or missing file. This also pins
## the melee rule from the asset report: the collision circle is placed along the
## facing and never rotated, only the visual is.

const MeleeArcScript = preload("res://scripts/weapons/melee_arc.gd")

const SWORD_VFX: String = "res://asset/weapon/melee/wide_sword_arc.png"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_melee_arc_uses_authored_texture())
	failures.append_array(_test_melee_arc_falls_back())
	failures.append_array(_test_arc_owns_its_collider())
	return failures


## A node built outside the tree must own its collider outright. Attaching it
## with call_deferred here would drop the callable when the arc is freed and
## leave the shape with no owner -- a silent RID leak rather than a test
## failure, which is exactly the kind of noise that hides the next real one.
func _test_arc_owns_its_collider() -> Array[String]:
	var arc: Area2D = MeleeArcScript.new()
	arc.facing = Vector2.RIGHT
	arc._ready()
	var failures: Array[String] = []
	var collider: Node = arc.get_node_or_null(^"CollisionShape2D")
	if collider == null:
		failures.append("arc built outside the tree should parent its collider immediately")
	elif collider.get_parent() != arc:
		failures.append("collider is not owned by the arc, so freeing the arc leaks it")
	arc.free()
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
