extends RefCounted
## N9-91: contracts for the pooled combat nodes that had no unit coverage.
##
## These three carry the invariants a harness only exercises by accident:
## NodePool is under every projectile, orb, ward and chest in the game, a
## Breakable that double-emits corrupts the drop roll, and a Chest that fires
## twice pays its reward twice. Each is checked off-tree — _ready never runs,
## which is exactly the deal the classes already honour (arm/place carry all
## the state a test needs).

const BREAK_HP := 3.0


func test_node_pool_reuses_released_nodes() -> bool:
	var parent := Node.new()
	var made: Array[int] = []
	var pool := NodePool.new(parent, func() -> CanvasItem:
		var node := Node2D.new()
		made.append(node.get_instance_id())
		return node
	)
	var first: CanvasItem = pool.acquire()
	var passed: bool = first.get_parent() == parent and first.visible
	passed = passed and first.process_mode == Node.PROCESS_MODE_INHERIT
	pool.release(first)
	# Parked: invisible and out of the process loops, but still parented —
	# release must never orphan a node or the next acquire would re-add it.
	passed = passed and not first.visible
	passed = passed and first.process_mode == Node.PROCESS_MODE_DISABLED
	passed = passed and first.get_parent() == parent
	var second: CanvasItem = pool.acquire()
	# The whole point of the pool: the parked node comes back, re-lit.
	passed = passed and second == first and second.visible
	passed = passed and made.size() == 1
	# A second acquire with the pool dry builds a NEW node via the factory.
	var third: CanvasItem = pool.acquire()
	passed = passed and third != first and made.size() == 2
	parent.free()
	return passed


func test_breakable_flashes_below_lethal_and_breaks_once() -> bool:
	var body := Breakable.new()
	var shape := CollisionShape2D.new()
	body.add_child(shape)
	body.arm("rock_small", BREAK_HP, 8.0, shape)
	var breaks: Array[int] = []
	body.broke.connect(func(b: Breakable) -> void: breaks.append(b.get_instance_id()))

	var passed: bool = body.alive() and body.hit_radius == 8.0
	body.take_weapon_damage(1.0)
	# A survivable hit flashes and stays solid — no signal, still alive.
	passed = passed and body.alive() and breaks.is_empty()
	passed = passed and body.modulate == UiPalette.SPRITE_HIT_FLASH
	body.take_weapon_damage(99.0)
	# The killing hit: exactly one broke, hp floored, hidden in place.
	passed = passed and not body.alive() and breaks.size() == 1
	passed = passed and body.hp == 0.0 and not body.visible
	body.take_weapon_damage(5.0)
	# Dead props swallow further damage silently — a second emit here would
	# roll the break drop table twice for one prop.
	passed = passed and breaks.size() == 1 and body.hp == 0.0
	body.free()
	return passed


func test_chest_opens_exactly_once_and_replacement_rearms() -> bool:
	var chest := Chest.new()
	var player := Player.new()
	var opens: Array[int] = []
	chest.opened.connect(func(c: Chest) -> void: opens.append(c.get_instance_id()))

	player.global_position = Vector2(100.0, 0.0)
	chest.place(Vector2.ZERO, player, 20.0)
	chest._physics_process(0.016)
	# Out of reach: the walk IS the interaction, so distance is the whole rule.
	var passed: bool = opens.is_empty()
	player.global_position = Vector2(12.0, 0.0)
	chest._physics_process(0.016)
	passed = passed and opens.size() == 1
	chest._physics_process(0.016)
	# The latch: standing on an opened chest must not pay its reward again.
	passed = passed and opens.size() == 1
	# Pooled reuse: place() re-arms the latch for the next elite's drop.
	chest.place(Vector2(500.0, 500.0), player, 20.0)
	player.global_position = Vector2(505.0, 500.0)
	chest._physics_process(0.016)
	passed = passed and opens.size() == 2
	chest.free()
	player.free()
	return passed
