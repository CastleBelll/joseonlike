extends RefCounted
## Guards the N9-49 boss attack contract: the shipped patterns are legal, the
## scheduler is fair between a short and a long cooldown, placement leads the
## player, and a band spares its middle.

const EPSILON := 0.01


func _shipped_boss() -> Dictionary:
	var monsters: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/monsters.json")
	)
	var stages: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	var boss_id: String = String((stages["bamboo_forest"] as Dictionary)["boss_id"])
	return monsters[boss_id]


func test_the_shipped_boss_patterns_are_legal() -> bool:
	return BossPatterns.data_issues(_shipped_boss(), "boss").is_empty()


func test_the_boss_actually_has_two_patterns() -> bool:
	# The owner asked for two. One would still validate, which is exactly why
	# the count is asserted rather than assumed.
	return BossPatterns.attacks(_shipped_boss()).size() == 2


func test_a_pattern_fires_only_once_its_cooldown_has_passed() -> bool:
	var list: Array[Dictionary] = [{"cooldown_sec": 5.0}]
	return BossPatterns.due_index(list, [4.9]) == -1 \
		and BossPatterns.due_index(list, [5.0]) == 0


func test_the_longest_overdue_pattern_wins_a_tie() -> bool:
	# Both due on the same frame: the long-cooldown pattern is further past its
	# own bar, so it goes first. Taking the list order instead would let a
	# short cooldown starve a long one forever.
	var list: Array[Dictionary] = [{"cooldown_sec": 5.0}, {"cooldown_sec": 10.0}]
	return BossPatterns.due_index(list, [6.0, 12.0]) == 1


func test_placement_leads_a_moving_player() -> bool:
	var attack := {"count": 1, "lead_sec": 0.5, "spread_px": 0.0}
	var points: Array[Vector2] = BossPatterns.surge_points(
		Vector2.ZERO, Vector2(100.0, 0.0), attack, 0.0
	)
	# 100 px/s for half a second lands 50px ahead, not on the player.
	return points.size() == 1 and absf(points[0].x - 50.0) < EPSILON


func test_extra_discs_ring_the_predicted_spot() -> bool:
	var attack := {"count": 3, "lead_sec": 0.0, "spread_px": 80.0}
	var points: Array[Vector2] = BossPatterns.surge_points(
		Vector2.ZERO, Vector2.ZERO, attack, 0.0
	)
	if points.size() != 3:
		return false
	# The first sits on the player; the others sit exactly one spread away, so
	# standing still is never the safe answer.
	return points[0].is_equal_approx(Vector2.ZERO) \
		and absf(points[1].length() - 80.0) < EPSILON \
		and absf(points[2].length() - 80.0) < EPSILON


func test_a_band_spares_its_middle_and_a_disc_does_not() -> bool:
	var centre := Vector2.ZERO
	# Band: safe at the boss's feet, hit in the ring, safe beyond it.
	var band_safe_in: bool = not BossPatterns.covers(Vector2(50.0, 0.0), centre, 260.0, 110.0)
	var band_hit: bool = BossPatterns.covers(Vector2(180.0, 0.0), centre, 260.0, 110.0)
	var band_safe_out: bool = not BossPatterns.covers(Vector2(300.0, 0.0), centre, 260.0, 110.0)
	# Disc: nowhere inside is safe.
	var disc_hit: bool = BossPatterns.covers(Vector2(10.0, 0.0), centre, 62.0, 0.0)
	return band_safe_in and band_hit and band_safe_out and disc_hit


func test_an_unreactable_warning_is_rejected() -> bool:
	var bad := {"attacks": [{
		"id": "flash", "name_ko": "번쩍", "cooldown_sec": 5.0, "warn_sec": 0.1,
		"radius_px": 100.0, "damage": 10.0,
	}]}
	for issue: String in BossPatterns.data_issues(bad, "x"):
		if issue.contains("warn_sec"):
			return true
	return false


func test_a_band_wider_than_its_own_radius_is_rejected() -> bool:
	var bad := {"attacks": [{
		"id": "ring", "name_ko": "고리", "cooldown_sec": 5.0, "warn_sec": 1.0,
		"radius_px": 100.0, "inner_px": 100.0, "damage": 10.0,
	}]}
	for issue: String in BossPatterns.data_issues(bad, "x"):
		if issue.contains("inner_px"):
			return true
	return false
