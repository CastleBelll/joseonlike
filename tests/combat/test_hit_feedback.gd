extends RefCounted
## Hit feedback must stay inside the sprite it belongs to.
##
## A human found the original bug by watching the screen: hitting a goblin
## whitened the background. Nothing headless caught it, so these pin the two
## structural properties that make the bleed possible in the first place.
##
## Godot propagates CanvasItem.modulate down the tree, so "the flash cannot
## reach the background" is a statement about ancestry and about the flash
## target having no children - both checkable without rendering.

const ENEMY_SCENE: String = "res://scenes/actors/enemy_base.tscn"
const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const STAGE_SCENE: String = "res://scenes/combat/stage.tscn"
const GROUND_NAME: StringName = &"Ground"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_flash_target_is_a_leaf(ENEMY_SCENE))
	failures.append_array(_test_flash_target_is_a_leaf(PLAYER_SCENE))
	failures.append_array(_test_background_is_not_below_any_actor())
	return failures


## The flash writes to $Sprite2D. If that node ever gains children, modulate
## starts propagating into them, which is exactly how tinting escapes a sprite.
func _test_flash_target_is_a_leaf(scene_path: String) -> Array[String]:
	var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		return ["could not load %s" % scene_path]
	var root: Node = packed.instantiate()
	var failures: Array[String] = []

	var sprite: Node = root.get_node_or_null(^"Sprite2D")
	if sprite == null:
		failures.append("%s has no Sprite2D for hit feedback to target" % scene_path)
	else:
		if not (sprite is Sprite2D):
			failures.append("%s: flash target is %s, not a Sprite2D" % [scene_path, sprite.get_class()])
		if sprite.get_child_count() != 0:
			failures.append("%s: flash target has %d children, so modulate would propagate into them" % [
				scene_path, sprite.get_child_count(),
			])
		var item: CanvasItem = sprite as CanvasItem
		if item != null and item.modulate != Color.WHITE:
			failures.append("%s: flash target ships pre-tinted at %s" % [scene_path, item.modulate])

	# The root carries collision and children; tinting it would tint everything
	# under it, so it must start clean and never be the flash target.
	var root_item: CanvasItem = root as CanvasItem
	if root_item != null and root_item.modulate != Color.WHITE:
		failures.append("%s: root ships pre-tinted at %s" % [scene_path, root_item.modulate])
	root.free()
	return failures


## The ground must not sit under anything that gets tinted. As a sibling of the
## actor branches it is unreachable by any actor's modulate, whatever that
## actor does to itself.
func _test_background_is_not_below_any_actor() -> Array[String]:
	var packed: PackedScene = ResourceLoader.load(STAGE_SCENE) as PackedScene
	if packed == null:
		return ["could not load %s" % STAGE_SCENE]
	var stage: Node = packed.instantiate()
	var failures: Array[String] = []

	var ground: Node = stage.get_node_or_null(NodePath(GROUND_NAME))
	if ground == null:
		failures.append("stage has no %s layer" % GROUND_NAME)
		stage.free()
		return failures
	if ground.get_parent() != stage:
		failures.append("%s should hang directly off the stage, not under %s" % [
			GROUND_NAME, ground.get_parent().name,
		])
	for branch: StringName in [&"Actors", &"Spawner", &"Projectiles", &"Effects", &"Pickups"]:
		var node: Node = stage.get_node_or_null(NodePath(branch))
		if node != null and ground.is_ancestor_of(node):
			failures.append("%s is an ancestor of %s, so its tint would reach the actors" % [GROUND_NAME, branch])
		if node != null and node.is_ancestor_of(ground):
			failures.append("%s sits under %s, so that branch's tint would reach the background" % [GROUND_NAME, branch])
	stage.free()
	return failures
