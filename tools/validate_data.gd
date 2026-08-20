extends SceneTree
## Minimal data validator: every data/*.json must parse as valid JSON, and the
## cross-references the combat systems consume (N3-4) must resolve.
## Contract (see docs/CI.md): godot --headless --path . --script tools/validate_data.gd

const DATA_DIR := "res://data"
const SPAWNING_FIELDS: Array[String] = [
	"live_cap", "spawn_margin_px", "despawn_margin_px", "contact_cooldown_sec"
]
const CHARACTER_FIELDS: Array[String] = ["base_hp", "base_speed", "hit_invuln_sec"]
# N2-1 select-card copy: every roster entry must render a full row card.
const CHARACTER_TEXT_FIELDS: Array[String] = [
	"name_ko", "name_en", "name_hanja", "title_ko", "title_en", "quote_ko", "quote_en"
]
const UNLOCK_TYPES: Array[String] = ["default", "achievement", "gold"]
const UNLOCK_TEXT_FIELDS: Array[String] = ["unlock_text_ko", "unlock_text_en"]
const MONSTER_FIELDS: Array[String] = ["hp", "damage", "speed", "collision_radius", "xp_drop"]
# N3-12: a declared sprite set must ship both animation files.
const MONSTER_SPRITE_FILES: Array[String] = ["idle.png", "walk.png"]
const XP_CURVE_FIELDS: Array[String] = ["base_xp", "growth"]
const PASSIVE_FIELDS: Array[String] = ["per_stack", "max_stacks"]
const ORB_FIELDS: Array[String] = [
	"magnet_radius_px", "collect_radius_px", "magnet_accel_px_s2", "max_speed_px_s"
]
# N3-8 hit feedback contract (data/effects.json).
const HIT_FEEDBACK_FIELDS: Array[String] = [
	"enemy_flash_sec", "knockback_speed_px_s", "knockback_decay_px_s2",
	"boss_knockback_scale", "death_puff_sec", "death_puff_radius_scale",
	"player_vignette_sec"
]
# N3-17 weapon effect contract (data/effects.json weapon_effects): every
# timing/distance the code-side weapon visuals consume.
const WEAPON_EFFECTS_FIELDS: Array[String] = [
	"explosion_ring_sec", "explosion_spark_px", "chain_bolt_sec",
	"chain_bolt_jitter_px", "chain_bolt_width_px", "chain_first_leg_px",
	"arc_sweep_sec", "blade_trail_sec", "paper_width_px", "paper_length_px",
	"paper_trail_sec", "blade_width_px", "blade_length_px", "orbit_trail_sec",
	"ward_pulse_sec", "ward_spin_deg_s", "summon_strike_sec",
	"summon_strike_px", "shockwave_ring_sec", "shockwave_nudge_px",
	"shockwave_nudge_sec", "curse_jump_sec", "status_flicker_hz",
	"blink_puff_sec", "screen_flash_sec", "burst_ring_sec"
]
# N3-9 prop field contract (data/props.json).
const PROP_FIELD_FIELDS: Array[String] = [
	"width_px", "height_px", "edge_margin_px", "solid_count", "decor_count",
	"cluster_count", "cluster_radius_px", "cluster_min_gap_px",
	"min_gap_px", "spawn_clear_radius_px", "max_attempts_per_prop"
]
const PROP_ALLOWED_KEYS: Array[String] = [
	"size", "collision", "solid", "weight", "shape", "texture", "placeholder",
	"breakable", "light_radius_px", "flame"
]
const PROP_SHAPES: Array[String] = ["rect", "round"]
# N4-1 loot contract (data/loot.json, drop_tables.json, weapon_mods.json).
const LOOT_TIERS: Array[String] = ["common", "uncommon", "rare", "epic", "mythic"]
# N4-2 elite variant contract (monsters.json entries with "elite_of").
const ELITE_MULT_FIELDS: Array[String] = [
	"hp_mult", "damage_mult", "speed_mult", "size_mult", "reward_mult"
]
# N4-2 soft enrage contract (stages.json "soft_enrage").
const SOFT_ENRAGE_FIELDS: Array[String] = [
	"start_sec", "ramp_sec", "hp_mult_max", "damage_mult_max", "speed_mult_max"
]
# N4-4a/N4-4b weapon mechanic contract (weapons.json "mechanic" + its blocks).
const STATUS_IDS: Array[String] = ["burn", "shock", "curse"]
# N4-4b character actives contract (characters.json "actives").
const ACTIVE_TYPES: Array[String] = ["blink", "burst"]
# N3-13 icon binding contract (asset/ui/README.md): filenames are data ids.
const WEAPON_ICON_DIR := "res://asset/ui/weapon_icons"
const LOOT_ICON_DIR := "res://asset/ui/loot_icons"
const ACTIVE_TYPE_FIELDS: Dictionary = {
	"blink": ["distance_px", "invulnerable_sec"],
	"burst": ["radius_px", "damage"],
}

var _errors: int = 0


func _init() -> void:
	var checked: int = 0
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("validate_data: cannot open " + DATA_DIR)
		quit(1)
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		checked += 1
		var text: String = FileAccess.get_file_as_string(DATA_DIR + "/" + file_name)
		if JSON.parse_string(text) == null:
			_fail("invalid JSON in " + file_name)
	_check_combat_cross_references()
	if _errors > 0:
		print("FAIL %d data validation error(s) across %d json files" % [_errors, checked])
		quit(1)
		return
	print("PASS data validation: %d json files ok" % checked)
	quit(0)


func _check_combat_cross_references() -> void:
	var monsters: Dictionary = _load(DATA_DIR + "/monsters.json")
	var stages: Dictionary = _load(DATA_DIR + "/stages.json")
	var characters: Dictionary = _load(DATA_DIR + "/characters.json")
	for monster_id: String in monsters:
		# N6-5: monsters pay XP and loot only — gold comes from destructibles,
		# chests and the stage's boss_gold. A resurrected gold_drop field FAILS.
		if (monsters[monster_id] as Dictionary).has("gold_drop"):
			_fail("monsters.%s defines gold_drop — monsters no longer drop gold (N6-5)" % monster_id)
		if (monsters[monster_id] as Dictionary).has("elite_of"):
			_check_elite(monsters, monster_id)
			continue
		_require_positive_numbers(monsters[monster_id], MONSTER_FIELDS, "monsters." + monster_id)
		_check_monster_sprites(monsters[monster_id], "monsters." + monster_id)
		# N9-49 boss patterns: a telegraph nobody can react to is just damage,
		# and a band that swallows its own middle is a disc with a misleading
		# name. Both fail here rather than in play.
		for issue: String in BossPatterns.data_issues(
			monsters[monster_id], "monsters." + monster_id
		):
			_fail(issue)
	var curve: Dictionary = RunState.load_curve()
	for stage_id: String in stages:
		var stage: Dictionary = stages[stage_id]
		if not monsters.has(stage.get("boss_id", "")):
			_fail("stages.%s.boss_id not in monsters.json" % stage_id)
		# N5-1: the boss must arrive inside the run window.
		var boss_at: float = float(stage.get("boss_at_sec", 0.0))
		if boss_at <= 0.0 or boss_at > float(stage.get("duration_sec", 0.0)):
			_fail("stages.%s.boss_at_sec missing or outside duration_sec" % stage_id)
		# N6-5: the boss-kill payout replaced the boss's gold_drop.
		_require_positive_numbers(stage, ["boss_gold"], "stages." + stage_id)
		_require_positive_numbers(
			stage.get("spawning", {}), SPAWNING_FIELDS, "stages.%s.spawning" % stage_id
		)
		for wave: Dictionary in stage.get("waves", []):
			if not monsters.has(wave.get("monster_id", "")):
				_fail("stages.%s wave monster_id '%s' not in monsters.json" % [
					stage_id, wave.get("monster_id", "")
				])
		# N4-2 pacing invariants: monotonic times, boss last, surge peak first.
		for issue: String in RunFlow.schedule_issues(stage):
			_fail("stages.%s %s" % [stage_id, issue])
		# N6-2 opening invariants: rush density + first-level-up XP bound,
		# checked against the stage's own "opening" block.
		# N9-60: an endless loop that arms no waves would leave the field silent
		# forever, which reads as a crash rather than as a mode.
		for issue: String in Endless.data_issues(stage, "stages." + stage_id):
			_fail(issue)
		for issue: String in RunFlow.opening_issues(
			stage, monsters, float(curve.get("base_xp", 0.0)), float(curve.get("growth", 0.0))
		):
			_fail("stages.%s %s" % [stage_id, issue])
		if stage.has("soft_enrage"):
			_require_positive_numbers(
				stage.get("soft_enrage", {}), SOFT_ENRAGE_FIELDS,
				"stages.%s.soft_enrage" % stage_id
			)
	var weapons: Dictionary = _load(DATA_DIR + "/weapons.json")
	_check_weapon_grades(weapons)
	_check_weapon_targeting(weapons)
	_check_weapon_mechanics(weapons)
	var achievements: Dictionary = _load(DATA_DIR + "/achievements.json")
	for character_id: String in characters:
		_require_positive_numbers(
			characters[character_id], CHARACTER_FIELDS, "characters." + character_id
		)
		var starting_weapon: String = String(
			(characters[character_id] as Dictionary).get("starting_weapon", "")
		)
		if not weapons.has(starting_weapon):
			_fail("characters.%s.starting_weapon '%s' not in weapons.json" % [
				character_id, starting_weapon
			])
		_check_character_card(characters[character_id], achievements, character_id)
		_check_character_actives(characters[character_id], character_id)
	# N3-6 power-up pool: every passive needs a display name and a usable
	# stack contract, and every offerable stat id must still exist in the file.
	var passives: Dictionary = _load(DATA_DIR + "/passives.json")
	for passive_id: String in passives:
		var passive: Dictionary = passives[passive_id]
		_require_positive_numbers(passive, PASSIVE_FIELDS, "passives." + passive_id)
		if String(passive.get("name_ko", "")).is_empty():
			_fail("passives.%s.name_ko missing or empty" % passive_id)
	for offered_id: String in LevelUp.OFFERABLE_PASSIVES:
		if not passives.has(offered_id):
			_fail("LevelUp.OFFERABLE_PASSIVES id '%s' not in passives.json" % offered_id)
	var progression: Dictionary = _load(DATA_DIR + "/progression.json")
	_require_positive_numbers(
		progression.get("xp_curve", {}), XP_CURVE_FIELDS, "progression.xp_curve"
	)
	_require_positive_numbers(progression.get("orb", {}), ORB_FIELDS, "progression.orb")
	# growth 1.0 or below would make the level-up loop free or non-terminating.
	if float((progression.get("xp_curve", {}) as Dictionary).get("growth", 0.0)) <= 1.0:
		_fail("progression.xp_curve.growth must be greater than 1.0")
	var effects: Dictionary = _load(DATA_DIR + "/effects.json")
	_require_positive_numbers(
		effects.get("hit_feedback", {}), HIT_FEEDBACK_FIELDS, "effects.hit_feedback"
	)
	_require_positive_numbers(
		effects.get("weapon_effects", {}), WEAPON_EFFECTS_FIELDS, "effects.weapon_effects"
	)
	var sprite_effects: Dictionary = effects.get("sprite_effects", {})
	_check_sprite_effects(sprite_effects)
	_check_weapon_art(weapons, sprite_effects)
	_check_props()
	_check_shadow_monsters()
	_check_loot(monsters, weapons, stages)
	_check_audio()
	_check_unlocks()
	_check_impact()
	_check_field_passives()
	_check_difficulties()
	_check_meta_tree()
	_check_pickups(monsters, stages)


## N7-1 명부수 tree: the full MetaTree data contract (stat vocabulary, costs,
## prerequisites, cycles/reachability, duplicate ids, caps) plus icon binding
## — every node icon must exist in the loot icon set until dedicated art ships.
## N7-2 adds: wired-effect stat vocabulary (a node whose effect nothing
## consumes FAILS), per-character branch ownership against characters.json,
## and the strictly-increasing cost curve.
func _check_audio() -> void:
	var config: Dictionary = _load(DATA_DIR + "/audio.json")
	for issue: String in MusicService.data_issues(config):
		_fail("audio " + issue)
	# N9-52: the effects share the file and the bus contract with the music but
	# have their own rules (a throttle, per-effect loudness), so they are
	# checked by the class that reads them.
	for issue: String in SfxService.data_issues(config):
		_fail("audio " + issue)


## N9-58/N9-65: an unlock the screen cannot draw, and — the rule that matters —
## an unlock no achievement grants, which is content the player can never
## reach.
func _check_unlocks() -> void:
	var unlocks: Dictionary = _load(DATA_DIR + "/unlocks.json")
	for issue: String in Unlocks.data_issues(unlocks):
		_fail("unlocks " + issue)
	for issue: String in Achievements.data_issues(
		_load(DATA_DIR + "/achievements.json"), unlocks,
		_load(DATA_DIR + "/characters.json")
	):
		_fail("achievements " + issue)


## N9-67: hit feel is data, and its ceilings are the part that only shows up in
## play — a hitstop long enough to hang, or shake that throws the field away.
func _check_impact() -> void:
	for issue: String in Impact.data_issues(
		(_load(DATA_DIR + "/effects.json") as Dictionary).get("hit_feedback", {}),
		"effects.hit_feedback"
	):
		_fail(issue)


func _check_field_passives() -> void:
	for issue: String in Pickups.field_passive_issues(_load(DATA_DIR + "/pickups.json")):
		_fail("pickups " + issue)


func _check_difficulties() -> void:
	for issue: String in Difficulty.data_issues(_load(DATA_DIR + "/difficulties.json")):
		_fail("difficulties " + issue)


func _check_meta_tree() -> void:
	var tree: Dictionary = _load(DATA_DIR + "/meta_tree.json")
	var characters: Dictionary = _load(DATA_DIR + "/characters.json")
	for issue: String in MetaTree.data_issues(tree, characters):
		_fail("meta_tree " + issue)
	for entry: Dictionary in MetaTree.nodes(tree):
		var icon: String = String(entry.get("icon", ""))
		if not FileAccess.file_exists(LOOT_ICON_DIR.path_join(icon + ".png")):
			_fail("meta_tree node '%s' icon '%s' not in %s" % [
				entry.get("id", "?"), icon, LOOT_ICON_DIR
			])


## N2-1 select-card contract: full card copy, an accent the screen can
## resolve, a known unlock type, and unlock text on every locked character.
func _check_character_card(
	character: Dictionary, achievements: Dictionary, character_id: String
) -> void:
	var label: String = "characters." + character_id
	for field: String in CHARACTER_TEXT_FIELDS:
		if String(character.get(field, "")).is_empty():
			_fail("%s.%s missing or empty" % [label, field])
	if not CharacterSelectScreen.ACCENT_COLORS.has(String(character.get("accent", ""))):
		_fail(label + ".accent not a known accent token")
	var unlock: Dictionary = character.get("unlock", {})
	var unlock_type: String = String(unlock.get("type", ""))
	if unlock_type not in UNLOCK_TYPES:
		_fail(label + ".unlock.type must be one of " + str(UNLOCK_TYPES))
		return
	if unlock_type == "achievement" and not achievements.has(unlock.get("achievement_id", "")):
		_fail(label + ".unlock.achievement_id not in achievements.json")
	if unlock_type == "gold":
		_require_positive_numbers(unlock, ["cost"], label + ".unlock")
	if unlock_type != "default":
		for field: String in UNLOCK_TEXT_FIELDS:
			if String(character.get(field, "")).is_empty():
				_fail("%s.%s missing or empty" % [label, field])


## N4-4b actives: optional per character, but every declared entry must be a
## complete skill the stage runtime can execute — unique id, display name, a
## positive cooldown, a known type, and that type's numeric fields.
func _check_character_actives(character: Dictionary, character_id: String) -> void:
	var seen_ids: Array[String] = []
	for entry: Variant in character.get("actives", []):
		if entry is not Dictionary:
			_fail("characters.%s.actives entry is not an object" % character_id)
			continue
		var active: Dictionary = entry
		var active_id: String = String(active.get("id", ""))
		var label: String = "characters.%s.actives.%s" % [character_id, active_id]
		if active_id.is_empty():
			_fail("characters.%s.actives entry missing id" % character_id)
			continue
		if seen_ids.has(active_id):
			_fail(label + " duplicated id")
		seen_ids.append(active_id)
		if String(active.get("name_ko", "")).is_empty():
			_fail(label + ".name_ko missing or empty")
		_require_positive_numbers(active, ["cooldown_sec"], label)
		var type: String = String(active.get("type", ""))
		if type not in ACTIVE_TYPES:
			_fail(label + ".type must be one of " + str(ACTIVE_TYPES))
			continue
		var fields: Array = ACTIVE_TYPE_FIELDS[type]
		var typed_fields: Array[String] = []
		for field: Variant in fields:
			typed_fields.append(String(field))
		_require_positive_numbers(active, typed_fields, label)


## N4-2 elite variants: multipliers over a real, non-elite base monster.
func _check_elite(monsters: Dictionary, monster_id: String) -> void:
	var elite: Dictionary = monsters[monster_id]
	var label: String = "monsters." + monster_id
	var base_id: String = String(elite.get("elite_of", ""))
	if not monsters.has(base_id):
		_fail(label + ".elite_of not in monsters.json")
	elif (monsters[base_id] as Dictionary).has("elite_of"):
		_fail(label + ".elite_of must reference a non-elite base monster")
	if String(elite.get("name_ko", "")).is_empty():
		_fail(label + ".name_ko missing or empty")
	_require_positive_numbers(elite, ELITE_MULT_FIELDS, label)


## N4-2 grade ladder: the reserved "_grades" block must define an ordered
## ladder of unique names, a mult step for every rung above the first, and
## every weapon's base grade must sit on the ladder.
func _check_weapon_grades(weapons: Dictionary) -> void:
	var grades: Dictionary = WeaponGrade.config(weapons)
	var rungs: Array[String] = WeaponGrade.ladder(grades)
	if rungs.size() < 2:
		_fail("weapons._grades.ladder missing or shorter than 2 rungs")
		return
	for rung: String in rungs:
		if rungs.count(rung) > 1:
			_fail("weapons._grades.ladder rung '%s' duplicated" % rung)
	var steps: Dictionary = grades.get("steps", {})
	for step_id: String in steps:
		if step_id not in rungs:
			_fail("weapons._grades.steps.%s not on the ladder" % step_id)
	# N9-27: a rung may scale stats ("mult") or grant additive effects ("add"),
	# but it must do SOMETHING — a rung granting nothing is a card the player
	# spends a level-up on for no reason. `add` fields are whitelisted to the
	# ones the runtime actually reads, so a typo fails here instead of silently
	# doing nothing (the same rule milestones already live under).
	for rung: String in rungs.slice(1):
		var step: Dictionary = steps.get(rung, {})
		var mult: Dictionary = step.get("mult", {})
		var add: Dictionary = step.get("add", {})
		if mult.is_empty() and add.is_empty():
			_fail("weapons._grades.steps.%s grants nothing (needs mult or add)" % rung)
			continue
		for field: String in mult:
			if float(mult[field]) <= 0.0:
				_fail("weapons._grades.steps.%s.mult.%s must be positive" % [rung, field])
		for field: String in add:
			if field not in LevelUp.GRADE_EFFECT_LABELS:
				_fail(
					"weapons._grades.steps.%s.add.%s is not a wired grade effect %s"
					% [rung, field, str(LevelUp.GRADE_EFFECT_LABELS.keys())]
				)
			elif float(add[field]) <= 0.0:
				_fail("weapons._grades.steps.%s.add.%s must be positive" % [rung, field])
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var grade: String = String((weapons[weapon_id] as Dictionary).get("grade", ""))
		if grade not in rungs:
			_fail("weapons.%s.grade '%s' not on the _grades ladder" % [weapon_id, grade])


## N4-4a mechanic contract: every weapon's mechanic must be one the runtime
## implements, its mechanic block must carry sane numbers, and the optional
## status/seal/lifesteal branches must be well-formed.
func _check_weapon_mechanics(weapons: Dictionary) -> void:
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var weapon: Dictionary = weapons[weapon_id]
		var label: String = "weapons." + weapon_id
		_check_weapon_milestones(weapon, label)
		_check_mechanic_blocks(weapon, label)
		# N4-8: the merged milestone stats at max level must satisfy the same
		# mechanic contract — a delta cannot push falloff past 1, an arc past
		# 360°, or a seal below its floor.
		if weapon.has("milestones"):
			_check_mechanic_blocks(
				LevelUp.stats_at_level(weapon, int(weapon.get("max_level", 1))),
				label + "@max"
			)


func _check_mechanic_blocks(weapon: Dictionary, label: String) -> void:
	var mechanic: String = String(weapon.get("mechanic", "straight"))
	if mechanic not in LevelUp.SUPPORTED_MECHANICS:
		_fail("%s.mechanic '%s' not implemented by the runtime" % [label, mechanic])
		return
	# Only entries that declare a mechanic promise the runtime can fire
	# them; legacy speed-0 melee data (환도 family) stays exempt until its
	# character ships.
	if weapon.has("mechanic") and mechanic in LevelUp.PROJECTILE_MECHANICS \
			and float(weapon.get("speed", 0.0)) <= 0.0:
		_fail(label + " projectile mechanic needs a positive speed")
	match mechanic:
		"pierce":
			if int(weapon.get("pierce", 0)) < 1:
				_fail(label + ".pierce must be at least 1 for the pierce mechanic")
			# N4-3: optional damage retention per pierced enemy.
			if weapon.has("pierce_retention"):
				var retention: float = float(weapon.get("pierce_retention", 0.0))
				if retention <= 0.0 or retention > 1.0:
					_fail(label + ".pierce_retention must be in (0, 1]")
		"explosion":
			_require_positive_numbers(
				weapon.get("explosion", {}), ["radius_px"], label + ".explosion"
			)
			# N4-3: optional damage share kept at the blast edge.
			var explosion: Dictionary = weapon.get("explosion", {})
			if explosion.has("edge_falloff"):
				var edge: float = float(explosion.get("edge_falloff", 0.0))
				if edge <= 0.0 or edge > 1.0:
					_fail(label + ".explosion.edge_falloff must be in (0, 1]")
		"chain":
			var chain: Dictionary = weapon.get("chain", {})
			_require_positive_numbers(chain, ["jumps", "range_px"], label + ".chain")
			var falloff: float = float(chain.get("falloff", 0.0))
			if falloff <= 0.0 or falloff > 1.0:
				_fail(label + ".chain.falloff must be in (0, 1]")
		"melee_arc":
			var arc: Dictionary = weapon.get("arc", {})
			_require_positive_numbers(arc, ["knockback_scale"], label + ".arc")
			var angle: float = float(arc.get("angle_deg", 0.0))
			if angle <= 0.0 or angle > 360.0:
				_fail(label + ".arc.angle_deg must be in (0, 360]")
		"orbit":
			_require_positive_numbers(
				weapon.get("orbit", {}), ["radius_px", "speed_deg_s"], label + ".orbit"
			)
			# N4-3: optional orb hit/visual radius (falls back to the code default).
			if (weapon.get("orbit", {}) as Dictionary).has("orb_radius_px"):
				_require_positive_numbers(
					weapon.get("orbit", {}), ["orb_radius_px"], label + ".orbit"
				)
			if int(weapon.get("projectile_count", 0)) < 1:
				_fail(label + ".projectile_count must be at least 1 for orbit")
		"ward":
			var ward: Dictionary = weapon.get("ward", {})
			_require_positive_numbers(
				ward, ["radius_px", "duration_sec", "tick_sec"], label + ".ward"
			)
			var ward_slow: float = float(ward.get("slow_scale", 0.0))
			if ward_slow <= 0.0 or ward_slow >= 1.0:
				_fail(label + ".ward.slow_scale must be in (0, 1)")
		"summon":
			_require_positive_numbers(
				weapon.get("summon", {}),
				["lifetime_sec", "speed", "leash_px", "attack_cooldown_sec"],
				label + ".summon"
			)
		"shockwave":
			_require_positive_numbers(
				weapon.get("shockwave", {}),
				["radius_px", "stun_sec", "knockback_scale"],
				label + ".shockwave"
			)
		"curse":
			# The curse mechanic IS its status — without it the weapon
			# degenerates to a plain straight throw.
			if String(
				(weapon.get("on_hit_status", {}) as Dictionary).get("id", "")
			) != "curse":
				_fail(label + " curse mechanic needs on_hit_status.id 'curse'")
	_check_weapon_status(weapon, label)
	if weapon.has("on_hit_seal"):
		var seal: Dictionary = weapon.get("on_hit_seal", {})
		_require_positive_numbers(seal, ["burst_damage_scale"], label + ".on_hit_seal")
		if int(seal.get("burst_at", 0)) < 2:
			_fail(label + ".on_hit_seal.burst_at must be at least 2")
	if weapon.has("lifesteal"):
		var lifesteal: float = float(weapon.get("lifesteal", 0.0))
		if lifesteal <= 0.0 or lifesteal > 1.0:
			_fail(label + ".lifesteal must be in (0, 1]")


## N4-8 milestone growth contract: every 도사 (spiritual) weapon must define
## qualitative milestones — at least one below max level and one at max — and
## every delta path must be in LevelUp.MILESTONE_LABELS (so the card can
## always describe it) and numeric. damage/cooldown_sec belong to per_level,
## never to a milestone.
func _check_weapon_milestones(weapon: Dictionary, label: String) -> void:
	var max_level: int = int(weapon.get("max_level", 1))
	var milestones: Dictionary = weapon.get("milestones", {})
	if String(weapon.get("category", "")) == "spiritual":
		var has_mid: bool = false
		var has_max: bool = false
		for key: String in milestones:
			if int(key) == max_level:
				has_max = true
			elif int(key) < max_level:
				has_mid = true
		if not has_mid or not has_max:
			_fail(label + ".milestones must define one below max_level and one at it")
	for key: String in milestones:
		if not key.is_valid_int() or int(key) < 2 or int(key) > max_level:
			_fail("%s.milestones key '%s' must be an int in [2, max_level]" % [label, key])
			continue
		var delta: Variant = milestones[key]
		if delta is not Dictionary or (delta as Dictionary).is_empty():
			_fail("%s.milestones.%s must be a non-empty object" % [label, key])
			continue
		_check_milestone_delta(delta, "", "%s.milestones.%s" % [label, key])


func _check_milestone_delta(delta: Dictionary, path: String, label: String) -> void:
	for field: String in delta:
		var full: String = field if path.is_empty() else path + "." + field
		if delta[field] is Dictionary:
			_check_milestone_delta(delta[field] as Dictionary, full, label)
			continue
		if delta[field] is not float and delta[field] is not int:
			_fail("%s.%s must be a number" % [label, full])
			continue
		if not LevelUp.MILESTONE_LABELS.has(full):
			_fail("%s.%s not a known milestone field" % [label, full])


func _check_weapon_status(weapon: Dictionary, label: String) -> void:
	if not weapon.has("on_hit_status"):
		return
	var status: Dictionary = weapon.get("on_hit_status", {})
	var status_id: String = String(status.get("id", ""))
	if status_id not in STATUS_IDS:
		_fail(label + ".on_hit_status.id must be one of " + str(STATUS_IDS))
		return
	_require_positive_numbers(status, ["duration_sec"], label + ".on_hit_status")
	if status_id == "burn":
		_require_positive_numbers(status, ["dps"], label + ".on_hit_status")
		if status.has("spread_radius_px"):
			_require_positive_numbers(
				status, ["spread_radius_px"], label + ".on_hit_status"
			)
	if status_id == "shock":
		var slow: float = float(status.get("slow_scale", 0.0))
		if slow <= 0.0 or slow >= 1.0:
			_fail(label + ".on_hit_status.slow_scale must be in (0, 1)")
	if status_id == "curse":
		_require_positive_numbers(
			status, ["dps", "spread_radius_px"], label + ".on_hit_status"
		)
		if int(status.get("spread_count", 0)) < 1:
			_fail(label + ".on_hit_status.spread_count must be at least 1")


## N3-15 targeting contract: a shared positive view margin and a positive
## per-weapon range, so no weapon can ever fall back to "target anywhere".
func _check_weapon_targeting(weapons: Dictionary) -> void:
	var targeting: Dictionary = weapons.get("_targeting", {})
	if float(targeting.get("view_margin_px", 0.0)) <= 0.0:
		_fail("weapons._targeting.view_margin_px missing or not positive")
	# N4-8 multishot fan: optional, but a declared spread must be positive.
	if targeting.has("multishot_spread_deg") \
			and float(targeting.get("multishot_spread_deg", 0.0)) <= 0.0:
		_fail("weapons._targeting.multishot_spread_deg must be positive")
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		if float((weapons[weapon_id] as Dictionary).get("range_px", 0.0)) <= 0.0:
			_fail("weapons.%s.range_px missing or not positive" % weapon_id)


## N4-1 loot chain: every drop table points at a real monster and real loot,
## every mod recipe joins real weapons to real loot, chances stay in (0, 1].
## N6-1 adds the first-run guarantee tables (stages.json "first_run_drops").
func _check_loot(monsters: Dictionary, weapons: Dictionary, stages: Dictionary) -> void:
	var loot: Dictionary = _load(DATA_DIR + "/loot.json")
	if loot.is_empty():
		_fail("loot.json missing or empty")
	for loot_id: String in loot:
		var entry: Dictionary = loot[loot_id]
		var label: String = "loot." + loot_id
		if String(entry.get("name_ko", "")).is_empty():
			_fail(label + ".name_ko missing or empty")
		if String(entry.get("tier", "")) not in LOOT_TIERS:
			_fail(label + ".tier must be one of " + str(LOOT_TIERS))
		if entry.get("special") is not bool:
			_fail(label + ".special missing or not a bool")
		_require_positive_numbers(entry, ["salvage_gold"], label)
	var drop_tables: Dictionary = _load(DATA_DIR + "/drop_tables.json")
	for monster_id: String in drop_tables:
		if monster_id.begins_with("_"):
			continue  # reserved config keys ("_config") are not monsters
		if not monsters.has(monster_id):
			_fail("drop_tables.%s not in monsters.json" % monster_id)
		for drop: Dictionary in (drop_tables[monster_id] as Dictionary).get("drops", []):
			var drop_label: String = "drop_tables.%s.%s" % [monster_id, drop.get("loot_id", "?")]
			if not loot.has(drop.get("loot_id", "")):
				_fail(drop_label + " loot_id not in loot.json")
			var chance: float = float(drop.get("chance", 0.0))
			if chance <= 0.0 or chance > 1.0:
				_fail(drop_label + ".chance must be in (0, 1]")
	_check_special_rarity(drop_tables, monsters, stages, loot)
	for stage_id: String in stages:
		var stage: Dictionary = stages[stage_id]
		for issue: String in Ftue.first_run_issues(
			stage.get("first_run_drops", []), loot, float(stage.get("duration_sec", 0.0))
		):
			_fail("stages.%s %s" % [stage_id, issue])
	var mods: Dictionary = _load(DATA_DIR + "/weapon_mods.json")
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		var mod_label: String = "weapon_mods." + mod_id
		if not weapons.has(mod.get("weapon_id", "")):
			_fail(mod_label + ".weapon_id not in weapons.json")
		else:
			_check_mod_level_gate(mod, weapons, mod_label)
		var result_id: String = String(mod.get("result_weapon", ""))
		if not weapons.has(result_id):
			_fail(mod_label + ".result_weapon not in weapons.json")
		# N4-7: a mod result is obtainable ONLY through its recipe — without the
		# flag it would leak into the new-weapon pool as a plain random pick.
		elif not bool((weapons[result_id] as Dictionary).get("evolution_only", false)):
			_fail(mod_label + ".result_weapon '%s' must be evolution_only" % result_id)
		if not loot.has(mod.get("loot_id", "")):
			_fail(mod_label + ".loot_id not in loot.json")
	_check_ui_icons(weapons, loot)


## N4-9 rarity guard: the summed SPECIAL-material chance per kill must respect
## the intent caps declared in drop_tables._config.special_chance_max — a
## trash table loaded with special weight would quietly bring back every-run
## evolutions. Monsters classify as boss (a stages.json boss_id), elite
## ("elite_of" entries) or trash.
func _check_special_rarity(
	drop_tables: Dictionary, monsters: Dictionary, stages: Dictionary, loot: Dictionary
) -> void:
	var caps: Dictionary = (
		drop_tables.get("_config", {}) as Dictionary
	).get("special_chance_max", {})
	var cap_fields: Array[String] = ["trash", "elite", "boss"]
	_require_positive_numbers(caps, cap_fields, "drop_tables._config.special_chance_max")
	var boss_ids: Array[String] = []
	for stage_id: String in stages:
		boss_ids.append(String((stages[stage_id] as Dictionary).get("boss_id", "")))
	for monster_id: String in drop_tables:
		if monster_id.begins_with("_") or not monsters.has(monster_id):
			continue
		var special_sum: float = 0.0
		for drop: Dictionary in (drop_tables[monster_id] as Dictionary).get("drops", []):
			if bool((loot.get(drop.get("loot_id", ""), {}) as Dictionary).get("special", false)):
				special_sum += float(drop.get("chance", 0.0))
		var kind: String = "trash"
		if boss_ids.has(monster_id):
			kind = "boss"
		elif (monsters[monster_id] as Dictionary).has("elite_of"):
			kind = "elite"
		if special_sum > float(caps.get(kind, 0.0)) + 0.0001:
			_fail("drop_tables.%s special chance sum %.3f exceeds %s cap %.3f" % [
				monster_id, special_sum, kind, float(caps.get(kind, 0.0))
			])


## N4-9 earned evolution: every recipe must name a level gate the base weapon
## can actually reach — at least 2 (never a just-picked weapon), never past
## max_level, and on the base's milestone ladder when it defines one.
func _check_mod_level_gate(mod: Dictionary, weapons: Dictionary, mod_label: String) -> void:
	var base: Dictionary = weapons.get(mod.get("weapon_id", ""), {})
	var required: int = int(mod.get("level_required", 0))
	if required < 2:
		_fail(mod_label + ".level_required missing or below 2")
		return
	if required > int(base.get("max_level", 0)):
		_fail(mod_label + ".level_required exceeds the base weapon's max_level")
	var milestones: Dictionary = base.get("milestones", {})
	if not milestones.is_empty() and not milestones.has(str(required)):
		_fail(mod_label + ".level_required is not a milestone level of the base weapon")


## N3-13 icon binding: every weapon and loot id binds by filename to
## asset/ui — an id without an icon file would silently letter-render.
func _check_ui_icons(weapons: Dictionary, loot: Dictionary) -> void:
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		if not FileAccess.file_exists(WEAPON_ICON_DIR.path_join(weapon_id + ".png")):
			_fail("weapons.%s has no icon in %s" % [weapon_id, WEAPON_ICON_DIR])
	for loot_id: String in loot:
		if not FileAccess.file_exists(LOOT_ICON_DIR.path_join(loot_id + ".png")):
			_fail("loot.%s has no icon in %s" % [loot_id, LOOT_ICON_DIR])


## N3-9 prop catalogue: sizes positive, collision boxes inside sprite bounds,
## weights positive, unknown keys/placeholders/shapes rejected.
## N10-1a 그슨대 contract: a shadow monster can only be damaged inside a
## light, so a build that ships one without a single light-bearing prop ships
## an immortal enemy. Also guards the growth numbers themselves — a shadow that
## never shrinks in the light is the same bug wearing a different hat.
## N9-32 theme contract. A theme naming a prop id that does not exist is
## silently dropped by _theme_table, and a theme with no solid (or no decor)
## entry makes that whole scatter pass come up empty for every cluster it owns
## — both are invisible in play and would only show as a field that looks
## slightly wrong.
func _check_prop_themes(catalog: Dictionary, field: Dictionary) -> void:
	var themes: Array = field.get("themes", [])
	if themes.is_empty():
		return  # no themes is legal: the scatter falls back to the catalogue
	var seen: Array[String] = []
	for raw: Variant in themes:
		if raw is not Dictionary:
			_fail("props.field.themes entry is not an object")
			continue
		var theme: Dictionary = raw
		var theme_id: String = String(theme.get("id", ""))
		var label: String = "props.field.themes." + theme_id
		if theme_id.is_empty() or seen.has(theme_id):
			_fail("props.field.themes id '%s' missing or duplicated" % theme_id)
		seen.append(theme_id)
		if String(theme.get("name_ko", "")).is_empty():
			_fail(label + ".name_ko missing")
		if float(theme.get("weight", 0.0)) <= 0.0:
			_fail(label + ".weight must be positive")
		var props: Dictionary = theme.get("props", {})
		var solids: int = 0
		var decor: int = 0
		for prop_id: String in props:
			if not catalog.has(prop_id):
				_fail("%s names unknown prop '%s'" % [label, prop_id])
				continue
			if float(props[prop_id]) <= 0.0:
				_fail("%s.%s weight must be positive" % [label, prop_id])
			if bool((catalog[prop_id] as Dictionary).get("solid", false)):
				solids += 1
			else:
				decor += 1
		if solids <= 0 or decor <= 0:
			_fail(
				"%s must offer at least one solid and one decor prop (has %d/%d)"
				% [label, solids, decor]
			)


func _check_shadow_monsters() -> void:
	var monsters: Dictionary = _load(DATA_DIR + "/monsters.json")
	var shadow_ids: Array[String] = []
	for monster_id: String in monsters:
		var monster: Dictionary = monsters[monster_id]
		if not monster.has("shadow"):
			continue
		shadow_ids.append(monster_id)
		var label: String = "monsters." + monster_id + ".shadow"
		if monster.get("shadow") is not Dictionary:
			_fail(label + " must be an object")
			continue
		var shadow: Dictionary = monster["shadow"]
		for key: String in [
			"grow_per_sec", "max_scale", "lit_shrink_per_sec", "leash_px",
			"leash_fade_sec",
		]:
			if float(shadow.get(key, 0.0)) <= 0.0:
				_fail("%s.%s missing or not positive" % [label, key])
		if float(shadow.get("max_scale", 0.0)) <= 1.0:
			_fail(label + ".max_scale must be greater than 1.0 to read as growth")
		if float(shadow.get("damage_per_scale", -1.0)) < 0.0:
			_fail(label + ".damage_per_scale must not be negative")
	if shadow_ids.is_empty():
		return
	var catalog: Dictionary = (_load(DATA_DIR + "/props.json")).get("props", {})
	for prop_id: String in catalog:
		if float((catalog[prop_id] as Dictionary).get("light_radius_px", 0.0)) > 0.0:
			return
	_fail(
		"monsters %s need light: no prop declares light_radius_px, so they can never be damaged"
		% str(shadow_ids)
	)


func _check_props() -> void:
	var data: Dictionary = _load(DATA_DIR + "/props.json")
	_require_positive_numbers(data.get("field", {}), PROP_FIELD_FIELDS, "props.field")
	var catalog: Dictionary = data.get("props", {})
	if catalog.is_empty():
		_fail("props.json 'props' missing or empty")
	for prop_id: String in catalog:
		var prop: Dictionary = catalog[prop_id]
		var label: String = "props." + prop_id
		for key: String in prop:
			if key not in PROP_ALLOWED_KEYS:
				_fail("%s has unknown key '%s'" % [label, key])
		if prop.get("solid") is not bool:
			_fail(label + ".solid missing or not a bool")
		if float(prop.get("weight", 0.0)) <= 0.0:
			_fail(label + ".weight missing or not positive")
		if String(prop.get("shape", "")) not in PROP_SHAPES:
			_fail(label + ".shape must be one of " + str(PROP_SHAPES))
		# N5-5: only SOLID props may be breakable (decor never breaks), and a
		# breakable block must carry a positive hp.
		if prop.has("breakable"):
			if not bool(prop.get("solid", false)):
				_fail(label + " is decor and must not be breakable")
			if prop.get("breakable") is not Dictionary \
					or float((prop.get("breakable") as Dictionary).get("hp", 0.0)) <= 0.0:
				_fail(label + ".breakable.hp missing or not positive")
		if not String(prop.get("texture", "")).begins_with("res://"):
			_fail(label + ".texture must be a res:// path")
		if not StageField.PLACEHOLDER_COLORS.has(String(prop.get("placeholder", ""))):
			_fail(label + ".placeholder not a known palette token")
		var size: Array = prop.get("size", [])
		if size.size() != 2 or float(size[0]) <= 0.0 or float(size[1]) <= 0.0:
			_fail(label + ".size must be [width, height] with positive numbers")
			continue
		_check_prop_collision(prop, label, float(size[0]), float(size[1]))
	_check_prop_themes(catalog, data.get("field", {}))


## Collision boxes are relative to the bottom-center origin: the sprite spans
## x in [-w/2, w/2] and y in [-h, 0], and the box must sit inside that.
func _check_prop_collision(
	prop: Dictionary, label: String, width: float, height: float
) -> void:
	if not bool(prop.get("solid", false)):
		if prop.has("collision"):
			_fail(label + " is decor and must not define a collision box")
		return
	var box: Array = prop.get("collision", [])
	if box.size() != 4:
		_fail(label + ".collision must be [x, y, width, height]")
		return
	var box_w: float = float(box[2])
	var box_h: float = float(box[3])
	if box_w <= 0.0 or box_h <= 0.0:
		_fail(label + ".collision width/height must be positive")
		return
	var inside: bool = (
		float(box[0]) >= -width / 2.0
		and float(box[0]) + box_w <= width / 2.0
		and float(box[1]) >= -height
		and float(box[1]) + box_h <= 0.0
	)
	if not inside:
		_fail(label + ".collision box exceeds the sprite bounds")


## Art is optional — artless monsters fall back to the placeholder rect — but
## a declared sprite directory must exist on disk with every animation file.
func _check_monster_sprites(monster: Dictionary, label: String) -> void:
	if not monster.has("sprite"):
		return
	var sprite_dir: String = String(monster.get("sprite", ""))
	if not sprite_dir.begins_with("res://"):
		_fail(label + ".sprite must be a res:// directory path")
		return
	for file_name: String in MONSTER_SPRITE_FILES:
		if not FileAccess.file_exists(sprite_dir.path_join(file_name)):
			_fail("%s.sprite file missing: %s" % [label, sprite_dir.path_join(file_name)])


# N3-17 art integration: every sprite_effects entry must point at a real
# sheet with positive playback numbers, or the effect silently never shows.
func _check_sprite_effects(sprites: Dictionary) -> void:
	for effect_id: String in sprites:
		var entry: Dictionary = sprites[effect_id]
		_require_positive_numbers(
			entry, ["fps", "logical_px"], "effects.sprite_effects." + effect_id
		)
		var file: String = String(entry.get("file", ""))
		if not FileAccess.file_exists(file):
			_fail("effects.sprite_effects.%s file missing: %s" % [effect_id, file])


## N9-3f optional projectile art contract. Optional is intentional: weapons
## without these keys keep Projectile's procedural paper/blade fallback.
func _check_weapon_art(weapons: Dictionary, sprite_effects: Dictionary) -> void:
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var weapon: Dictionary = weapons[weapon_id]
		if weapon.has("travel_sprite"):
			var travel: String = String(weapon.get("travel_sprite", ""))
			if travel.is_empty() or not FileAccess.file_exists(travel):
				_fail("weapons.%s.travel_sprite file missing: %s" % [weapon_id, travel])
		if weapon.has("hit_effect"):
			var hit_effect: String = String(weapon.get("hit_effect", ""))
			if not sprite_effects.has(hit_effect):
				_fail("weapons.%s.hit_effect unknown: %s" % [weapon_id, hit_effect])


## N5-5 pickup/chest contract: the pure Pickups.data_issues rules (table
## completeness, plain-share floor, chest weight escalation, luck bend bounds
## at the meta tree's luck cap) plus the cross-file nuke cap — the capped nuke
## damage must never one-shot any boss or any derived elite.
func _check_pickups(monsters: Dictionary, stages: Dictionary) -> void:
	var pickups: Dictionary = _load(DATA_DIR + "/pickups.json")
	var meta: Dictionary = _load(DATA_DIR + "/meta_tree.json")
	var luck_cap: float = float((
		(meta.get("config", {}) as Dictionary).get("stat_caps", {}) as Dictionary
	).get("luck", 0.0))
	for issue: String in Pickups.data_issues(pickups, luck_cap):
		_fail("pickups " + issue)
	var capped: float = float((pickups.get("nuke", {}) as Dictionary).get("elite_boss_damage", 0.0))
	var boss_ids: Array[String] = []
	for stage_id: String in stages:
		boss_ids.append(String((stages[stage_id] as Dictionary).get("boss_id", "")))
	for monster_id: String in monsters:
		var monster: Dictionary = monsters[monster_id]
		var hp: float = 0.0
		if monster.has("elite_of") and monsters.has(monster.get("elite_of", "")):
			hp = float(Enemy.derive_elite_stats(
				monsters[monster.get("elite_of", "")], monster
			).get("hp", 0.0))
		elif boss_ids.has(monster_id):
			hp = float(monster.get("hp", 0.0))
		else:
			continue
		if capped >= hp:
			_fail("pickups nuke.elite_boss_damage %.0f one-shots monsters.%s (hp %.0f)" % [
				capped, monster_id, hp
			])


func _require_positive_numbers(entry: Dictionary, fields: Array[String], label: String) -> void:
	for field: String in fields:
		var value: Variant = entry.get(field)
		if (value is not float and value is not int) or float(value) <= 0.0:
			_fail("%s.%s missing or not a positive number" % [label, field])


func _fail(message: String) -> void:
	push_error("validate_data: " + message)
	_errors += 1


func _load(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
