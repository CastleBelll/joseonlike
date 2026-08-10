extends RefCounted
## Pickup-to-XP flow: an orb reports its value exactly once, and the listener
## (Stage, which forwards to RunState.add_xp) accumulates it.
##
## RunState is an autoload and therefore unavailable to the headless runner, so
## the test stands in a local accumulator with the same add_xp contract.

const XpPickupScript = preload("res://scripts/combat/xp_pickup.gd")
const Fixtures = preload("res://tests/combat/fixtures/combat_fixtures.gd")

var _granted_xp: int = 0
var _grant_count: int = 0


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_single_collection())
	failures.append_array(_test_double_collection_is_ignored())
	failures.append_array(_test_monster_drop_value())
	return failures


func _test_single_collection() -> Array[String]:
	_reset()
	var pickup: Area2D = _make_pickup(7, Vector2(120, 40))
	var returned: int = pickup.collect()
	var failures: Array[String] = []
	if returned != 7:
		failures.append("collect() should return the orb value, got %d" % returned)
	if _granted_xp != 7:
		failures.append("listener should receive 7 xp, got %d" % _granted_xp)
	if not pickup.is_collected():
		failures.append("orb should be marked collected")
	pickup.free()
	return failures


func _test_double_collection_is_ignored() -> Array[String]:
	_reset()
	var pickup: Area2D = _make_pickup(5, Vector2.ZERO)
	pickup.collect()
	# Overlap and the magnet radius can both fire in the same frame; the orb must
	# not pay out twice.
	var second: int = pickup.collect()
	var failures: Array[String] = []
	if second != 0:
		failures.append("second collect() should return 0, got %d" % second)
	if _grant_count != 1:
		failures.append("listener should be notified once, got %d times" % _grant_count)
	if _granted_xp != 5:
		failures.append("total xp should stay 5, got %d" % _granted_xp)
	pickup.free()
	return failures


func _test_monster_drop_value() -> Array[String]:
	_reset()
	var monster: Dictionary = Fixtures.chase_monster()
	var pickup: Area2D = _make_pickup(int(monster["xp_drop"]), Vector2.ZERO)
	pickup.collect()
	var failures: Array[String] = []
	if _granted_xp != int(monster["xp_drop"]):
		failures.append("orb should carry the monster xp_drop, got %d" % _granted_xp)
	pickup.free()

	# A monster with no xp must not mint a zero-value orb that still notifies.
	_reset()
	var empty_pickup: Area2D = _make_pickup(0, Vector2.ZERO)
	empty_pickup.collect()
	if _granted_xp != 0:
		failures.append("a zero drop must grant no xp, got %d" % _granted_xp)
	empty_pickup.free()
	return failures


func _make_pickup(amount: int, position: Vector2) -> Area2D:
	var pickup: Area2D = XpPickupScript.new()
	pickup.collected.connect(_on_collected)
	pickup.setup(amount, position)
	return pickup


func _on_collected(amount: int) -> void:
	_granted_xp += amount
	_grant_count += 1


func _reset() -> void:
	_granted_xp = 0
	_grant_count = 0
