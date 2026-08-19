class_name BossPatterns
extends RefCounted
## Pure boss-attack scheduling and placement (N9-49). Node-free so the headless
## suite drives it directly; Stage owns the telegraph pool and applies damage.
##
## A boss attack is data (data/monsters.json "attacks"):
##   {"id", "name_ko", "cooldown_sec", "warn_sec", "radius_px",
##    "inner_px" (band patterns), "count", "spread_px", "damage",
##    "lead_sec" (aim ahead of the player), "knockback_scale"}


static func attacks(stats: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in stats.get("attacks", []):
		if raw is Dictionary:
			out.append(raw)
	return out


## Index of the attack whose cooldown has expired, or -1. Ties go to the
## LONGEST-overdue attack rather than the first in the list, so a short-cooldown
## pattern cannot starve a long one when both come due on the same frame.
static func due_index(attacks_list: Array[Dictionary], since: Array[float]) -> int:
	var best: int = -1
	var best_overdue: float = 0.0
	for i: int in range(attacks_list.size()):
		if i >= since.size():
			break
		var cooldown: float = float(attacks_list[i].get("cooldown_sec", 0.0))
		if cooldown <= 0.0:
			continue
		var overdue: float = since[i] - cooldown
		if overdue >= 0.0 and (best < 0 or overdue > best_overdue):
			best = i
			best_overdue = overdue
	return best


## Where the discs of a multi-spot pattern land. The first always sits on the
## predicted player position; the rest ring it at `spread_px`, so standing
## still is never safe and one step is never punished twice.
## `lead_sec` aims where the player is HEADING — a pattern that always lands
## where they already are is dodged by walking in any direction at all.
static func surge_points(
	player_pos: Vector2, player_velocity: Vector2, attack: Dictionary, angle: float
) -> Array[Vector2]:
	var centre: Vector2 = player_pos + player_velocity * float(attack.get("lead_sec", 0.0))
	var points: Array[Vector2] = [centre]
	var count: int = maxi(int(attack.get("count", 1)), 1)
	var spread: float = float(attack.get("spread_px", 0.0))
	for i: int in range(count - 1):
		var step: float = angle + TAU * float(i) / float(maxi(count - 1, 1))
		points.append(centre + Vector2.from_angle(step) * spread)
	return points


## True when `point` is inside the attack's area. A disc covers everything to
## radius; a band spares the middle, which is what makes 목랑의 진노 a "step in
## or step out" decision rather than a flat tax on being nearby.
static func covers(point: Vector2, at: Vector2, radius: float, inner: float) -> bool:
	var distance: float = point.distance_to(at)
	return distance <= radius and distance >= inner


## Data contract for validate_data: every attack needs a positive cooldown, a
## warning the player can actually react to, a real area, and damage. A band
## must leave a gap, or it is a disc wearing a misleading name.
static func data_issues(stats: Dictionary, label: String) -> Array[String]:
	var issues: Array[String] = []
	var list: Array[Dictionary] = attacks(stats)
	if list.is_empty():
		return issues
	var ids: Array[String] = []
	for attack: Dictionary in list:
		var id: String = String(attack.get("id", ""))
		var where: String = "%s.attacks.%s" % [label, id]
		if id.is_empty() or ids.has(id):
			issues.append("%s.attacks has a missing or duplicated id '%s'" % [label, id])
		ids.append(id)
		if String(attack.get("name_ko", "")).is_empty():
			issues.append(where + ".name_ko missing")
		for key: String in ["cooldown_sec", "warn_sec", "radius_px", "damage"]:
			if float(attack.get(key, 0.0)) <= 0.0:
				issues.append("%s.%s must be positive" % [where, key])
		# A telegraph the player cannot see and react to is just damage.
		if float(attack.get("warn_sec", 0.0)) < 0.4:
			issues.append(where + ".warn_sec is too short to react to (min 0.4)")
		var inner: float = float(attack.get("inner_px", 0.0))
		if inner < 0.0 or inner >= float(attack.get("radius_px", 0.0)):
			issues.append(where + ".inner_px must be inside radius_px")
		if int(attack.get("count", 1)) > 1 and float(attack.get("spread_px", 0.0)) <= 0.0:
			issues.append(where + ".spread_px must be positive when count > 1")
	return issues
