extends SceneTree
## N4-8 growth-curve table: per-level effective dps model for every 도사
## (spiritual) weapon, milestones folded in via LevelUp.stats_at_level — the
## same merge the runtime uses, so the table cannot drift from the game.
## Run: godot --headless --path . --script tools/growth_table.gd
##
## The dps column is a MODEL (single-target unless stated), for comparing a
## weapon against itself across levels and weapons against each other at the
## same level — not absolute in-run dps:
##   straight/pierce/explosion/curse  damage x projectiles / cooldown
##   chain                            damage / cooldown x sum(falloff^j)
##   melee_arc / shockwave            damage / cooldown (area constant)
##   orbit                            damage x orbs / cooldown (per-enemy gate)
##   ward                             damage / tick x uptime(duration/cooldown)
##   summon                           damage / attack_cd x lifetime uptime

const WEAPONS_PATH := "res://data/weapons.json"


func _init() -> void:
	var weapons: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(WEAPONS_PATH)
	)
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var base: Dictionary = weapons[weapon_id]
		if String(base.get("category", "")) != "spiritual":
			continue
		var max_level: int = int(base.get("max_level", 1))
		print("\n### %s (%s)" % [weapon_id, String(base.get("name_ko", ""))])
		print("| level | damage | cooldown | mechanic | est dps |")
		print("|---|---|---|---|---|")
		var first_dps: float = 0.0
		var last_dps: float = 0.0
		for level: int in range(1, max_level + 1):
			var stats: Dictionary = LevelUp.stats_at_level(base, level)
			var damage: float = LevelUp.weapon_stat_at(stats, "damage", level)
			var cooldown: float = LevelUp.weapon_stat_at(stats, "cooldown_sec", level)
			var dps: float = _model_dps(stats, damage, cooldown)
			if level == 1:
				first_dps = dps
			last_dps = dps
			var mark: String = ""
			if not LevelUp.milestone_delta(base, level).is_empty():
				mark = " " + LevelUp.MILESTONE_MARK + LevelUp.milestone_text(
					LevelUp.milestone_delta(base, level)
				)
			print("| %d | %.1f | %.2f | %s%s | %.1f |" % [
				level, damage, cooldown, _mechanic_summary(stats), mark, dps
			])
		print("headroom L1/Lmax: %.2f (x%.1f growth)" % [
			first_dps / maxf(last_dps, 0.001), last_dps / maxf(first_dps, 0.001)
		])
	quit(0)


func _model_dps(stats: Dictionary, damage: float, cooldown: float) -> float:
	var safe_cooldown: float = maxf(cooldown, 0.05)
	var count: float = maxf(float(stats.get("projectile_count", 1)), 1.0)
	match String(stats.get("mechanic", "straight")):
		"chain":
			var chain: Dictionary = stats.get("chain", {})
			var jumps: int = int(chain.get("jumps", 0))
			var falloff: float = float(chain.get("falloff", 1.0))
			var total: float = 0.0
			for jump: int in range(jumps + 1):
				total += pow(falloff, float(jump))
			return damage * total / safe_cooldown
		"orbit":
			return damage * count / safe_cooldown
		"ward":
			var ward: Dictionary = stats.get("ward", {})
			var uptime: float = minf(
				float(ward.get("duration_sec", 0.0)) / safe_cooldown, 1.0
			)
			return damage / maxf(float(ward.get("tick_sec", 1.0)), 0.05) * uptime
		"summon":
			var summon: Dictionary = stats.get("summon", {})
			var lifetime: float = float(summon.get("lifetime_sec", 0.0))
			var uptime: float = lifetime / maxf(lifetime + safe_cooldown, 0.05)
			return damage / maxf(
				float(summon.get("attack_cooldown_sec", 1.0)), 0.05
			) * uptime
	return damage * count / safe_cooldown


## Compact live-mechanic numbers so a milestone's qualitative change is
## visible in the row itself.
func _mechanic_summary(stats: Dictionary) -> String:
	match String(stats.get("mechanic", "straight")):
		"straight", "curse", "pierce", "explosion":
			var parts: Array[String] = ["proj %d" % int(stats.get("projectile_count", 1))]
			if int(stats.get("pierce", 0)) > 0:
				parts.append("pierce %d" % int(stats.get("pierce", 0)))
			if stats.has("explosion"):
				parts.append("radius %d" % int(
					(stats.get("explosion", {}) as Dictionary).get("radius_px", 0.0)
				))
			var status: Dictionary = stats.get("on_hit_status", {})
			if not status.is_empty():
				parts.append("%s %.0f/%.1fs" % [
					String(status.get("id", "")), float(status.get("dps", 0.0)),
					float(status.get("duration_sec", 0.0)),
				])
				if status.has("spread_count"):
					parts.append("spread %d" % int(status.get("spread_count", 0)))
			return " ".join(parts)
		"chain":
			var chain: Dictionary = stats.get("chain", {})
			return "jumps %d falloff %.2f" % [
				int(chain.get("jumps", 0)), float(chain.get("falloff", 0.0))
			]
		"melee_arc":
			var arc: Dictionary = stats.get("arc", {})
			return "arc %d° kb %.1f" % [
				int(arc.get("angle_deg", 0.0)), float(arc.get("knockback_scale", 0.0))
			]
		"orbit":
			return "orbs %d" % int(stats.get("projectile_count", 1))
		"ward":
			var ward: Dictionary = stats.get("ward", {})
			return "radius %d dur %.1f slow %.2f" % [
				int(ward.get("radius_px", 0.0)), float(ward.get("duration_sec", 0.0)),
				float(ward.get("slow_scale", 0.0)),
			]
		"summon":
			var summon: Dictionary = stats.get("summon", {})
			return "life %.1f atk %.2f" % [
				float(summon.get("lifetime_sec", 0.0)),
				float(summon.get("attack_cooldown_sec", 0.0)),
			]
		"shockwave":
			var wave: Dictionary = stats.get("shockwave", {})
			return "radius %d stun %.1f kb %.1f" % [
				int(wave.get("radius_px", 0.0)), float(wave.get("stun_sec", 0.0)),
				float(wave.get("knockback_scale", 0.0)),
			]
	return ""
