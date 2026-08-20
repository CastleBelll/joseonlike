extends SceneTree
## N9-29 one-shot probe: prints each weapon's mechanic block at level 1 vs max,
## so the authored milestone table can be read as end-state numbers rather than
## deltas. Run: godot --headless --path . --script tools/growth_probe.gd
func _init() -> void:
	var weapons: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/weapons.json")
	)
	var fields: Array[String] = [
		"projectile_count", "pierce", "pierce_retention", "chain", "explosion",
		"arc", "orbit", "ward", "summon", "shockwave", "on_hit_status", "on_hit_seal",
	]
	for id: String in weapons:
		if id.begins_with("_"):
			continue
		var stats: Dictionary = weapons[id]
		if not stats.has("milestones"):
			continue
		var maxed: Dictionary = LevelUp.stats_at_level(stats, int(stats.get("max_level", 1)))
		var parts: PackedStringArray = []
		for field: String in fields:
			if not stats.has(field) and not maxed.has(field):
				continue
			var before: Variant = stats.get(field)
			var after: Variant = maxed.get(field)
			if str(before) != str(after):
				parts.append("%s %s -> %s" % [field, str(before), str(after)])
		print("%s: %s" % [String(stats.get("name_ko", id)), " | ".join(parts)])
	quit()
