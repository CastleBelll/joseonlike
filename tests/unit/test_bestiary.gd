extends RefCounted
## Guards the N5-4 괴이록: discovery folding (idempotent, order-independent),
## profile migration from a record-less save, unknown-id pruning, data-derived
## rosters/totals, the ???-masked view-model rows and the screen construction.

const BESTIARY_SCENE := "res://scenes/bestiary.tscn"

const FIXTURE_STAGES := {
	"bamboo_forest": {
		"name_ko": "대나무 숲", "name_en": "Bamboo Forest",
		"boss_id": "boss_lord",
		"waves": [
			{"at_sec": 0, "monster_id": "goblin"},
			{"at_sec": 30, "monster_id": "goblin"},
			{"at_sec": 60, "monster_id": "spirit"},
			{"at_sec": 90, "monster_id": "ghost_of_removed_data"},
		],
	},
}
const FIXTURE_MONSTERS := {
	"goblin": {"name_ko": "도깨비", "name_en": "Goblin", "sprite": "res://x/goblin"},
	"spirit": {"name_ko": "정령", "name_en": "Spirit", "sprite": "res://x/spirit"},
	"boss_lord": {"name_ko": "정령왕", "name_en": "Spirit Lord", "sprite": "res://x/lord"},
}
const FIXTURE_WEAPONS := {
	"_grades": {},
	"talisman": {"name_ko": "부적", "mechanic": "straight", "speed": 200.0,
		"evolution_only": false},
	"fire_talisman": {"name_ko": "화염 부적", "mechanic": "straight", "speed": 200.0,
		"evolution_only": true},
	"phoenix_talisman": {"name_ko": "불사조 부적", "mechanic": "straight", "speed": 200.0,
		"evolution_only": true},
	"sword": {"name_ko": "검", "speed": 0.0, "evolution_only": false},
	"sharp_sword": {"name_ko": "예리한 검", "mechanic": "melee_arc", "evolution_only": true},
}
const FIXTURE_MODS := {
	"fire_mod": {"weapon_id": "talisman", "loot_id": "ember", "result_weapon": "fire_talisman"},
	"phoenix_mod": {"weapon_id": "fire_talisman", "loot_id": "ember",
		"result_weapon": "phoenix_talisman"},
	"sword_mod": {"weapon_id": "sword", "loot_id": "stone", "result_weapon": "sharp_sword"},
}
const FIXTURE_LOOT := {
	"ember": {"name_ko": "불씨", "tier": "rare", "special": true},
	"stone": {"name_ko": "숫돌", "tier": "common", "special": false},
}


func test_migration_fills_empty_record_and_keeps_discoveries() -> bool:
	# A record-less v2 save (pre-N5-4) must migrate to the empty record shape.
	var old: Dictionary = SaveProfile.default_profile()
	old.erase("bestiary")
	var migrated: Dictionary = SaveProfile.migrate(old)
	if migrated["bestiary"] != Bestiary.default_record():
		push_error("test_bestiary: record-less profile must gain the empty record")
		return false
	# An existing record survives migration intact.
	var owned: Dictionary = SaveProfile.default_profile()
	owned["bestiary"] = {"monsters": ["goblin"], "loot": [], "weapons": ["talisman"], "unseen": 2}
	var kept: Dictionary = SaveProfile.migrate(owned)
	var record: Dictionary = kept["bestiary"]
	return (record["monsters"] as Array).has("goblin") \
		and (record["weapons"] as Array).has("talisman") and int(record["unseen"]) == 2


func test_normalized_record_coerces_garbage() -> bool:
	var junk: Variant = {
		"monsters": ["a", "a", ""], "loot": "not-an-array", "unseen": -3, "extra": true
	}
	var record: Dictionary = Bestiary.normalized_record(junk)
	var passed: bool = record["monsters"] == ["a"]
	passed = passed and record["loot"] == [] and record["weapons"] == []
	passed = passed and int(record["unseen"]) == 0 and not record.has("extra")
	if not passed:
		push_error("test_bestiary: garbage record must coerce to shape")
	if Bestiary.normalized_record("junk") != Bestiary.default_record():
		push_error("test_bestiary: non-dict record must fall back to default")
		return false
	return passed


func test_record_discovery_is_idempotent_and_order_independent() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	var first: Dictionary = Bestiary.record_discovery(profile, Bestiary.KIND_MONSTERS, "goblin")
	if not bool(first["new"]):
		push_error("test_bestiary: first sighting must be new")
		return false
	# The input profile is never mutated.
	if (profile["bestiary"]["monsters"] as Array).size() != 0:
		push_error("test_bestiary: record_discovery must not mutate its input")
		return false
	var again: Dictionary = Bestiary.record_discovery(
		first["profile"], Bestiary.KIND_MONSTERS, "goblin"
	)
	if bool(again["new"]) or (again["profile"]["bestiary"]["monsters"] as Array).size() != 1:
		push_error("test_bestiary: repeat sighting must be a no-op")
		return false
	# Order independence: A then B equals B then A as sets.
	var ab: Dictionary = Bestiary.record_discovery(
		Bestiary.record_discovery(profile, Bestiary.KIND_LOOT, "a")["profile"],
		Bestiary.KIND_LOOT, "b"
	)["profile"]
	var ba: Dictionary = Bestiary.record_discovery(
		Bestiary.record_discovery(profile, Bestiary.KIND_LOOT, "b")["profile"],
		Bestiary.KIND_LOOT, "a"
	)["profile"]
	for id: String in ["a", "b"]:
		if not (ab["bestiary"]["loot"] as Array).has(id) \
				or not (ba["bestiary"]["loot"] as Array).has(id):
			push_error("test_bestiary: discovery must be order-independent")
			return false
	return int(ab["bestiary"]["unseen"]) == 2


func test_record_discovery_rejects_bad_input() -> bool:
	var profile: Dictionary = SaveProfile.default_profile()
	var bad_kind: Dictionary = Bestiary.record_discovery(profile, "characters", "x")
	var empty_id: Dictionary = Bestiary.record_discovery(profile, Bestiary.KIND_LOOT, "")
	return not bool(bad_kind["new"]) and not bool(empty_id["new"])


func test_mark_seen_clears_the_hint_once() -> bool:
	var profile: Dictionary = Bestiary.record_discovery(
		SaveProfile.default_profile(), Bestiary.KIND_MONSTERS, "goblin"
	)["profile"]
	if Bestiary.camp_hint(profile).is_empty() or Bestiary.unseen_count(profile) != 1:
		push_error("test_bestiary: a new discovery must raise the camp hint")
		return false
	var seen: Dictionary = Bestiary.mark_seen(profile)
	if not bool(seen["changed"]) or Bestiary.unseen_count(seen["profile"]) != 0:
		push_error("test_bestiary: mark_seen must clear the counter")
		return false
	if not Bestiary.camp_hint(seen["profile"]).is_empty():
		push_error("test_bestiary: hint must be empty once seen")
		return false
	# Already-seen record: no change, so the caller skips the disk write.
	return not bool(Bestiary.mark_seen(seen["profile"])["changed"])


func test_prune_drops_unknown_ids_with_count() -> bool:
	var record: Dictionary = {
		"monsters": ["goblin", "removed_monster"],
		"loot": ["ember"],
		"weapons": ["talisman", "removed_weapon"],
		"unseen": 1,
	}
	var valid: Dictionary = {
		"monsters": ["goblin"], "loot": ["ember"], "weapons": ["talisman"]
	}
	var pruned: Dictionary = Bestiary.prune_record(record, valid)
	var clean: Dictionary = pruned["record"]
	var passed: bool = int(pruned["dropped"]) == 2
	passed = passed and clean["monsters"] == ["goblin"] and clean["weapons"] == ["talisman"]
	passed = passed and clean["loot"] == ["ember"] and int(clean["unseen"]) == 1
	if not passed:
		push_error("test_bestiary: prune must drop exactly the unknown ids")
	return passed


func test_monster_roster_derives_from_stage_spawns() -> bool:
	var roster: Array[Dictionary] = Bestiary.monster_roster(FIXTURE_STAGES, FIXTURE_MONSTERS)
	# goblin deduped, spirit next, boss last; the id missing from monsters.json
	# is skipped instead of rendering a broken row.
	if roster.size() != 3:
		push_error("test_bestiary: roster must dedupe waves and skip unknown ids")
		return false
	var passed: bool = String(roster[0]["id"]) == "goblin" and not bool(roster[0]["boss"])
	passed = passed and String(roster[1]["id"]) == "spirit"
	passed = passed and String(roster[2]["id"]) == "boss_lord" and bool(roster[2]["boss"])
	if not passed:
		push_error("test_bestiary: roster order must follow encounter order then boss")
	return passed


func test_weapon_roster_is_the_reachable_closure() -> bool:
	var roster: Array[String] = Bestiary.weapon_roster(FIXTURE_WEAPONS, FIXTURE_MODS)
	# talisman fires; its mod chain (fire → phoenix) is reachable. The sword
	# cannot fire, so the sword and its mod result stay out — and so does the
	# reserved "_grades" config key.
	var passed: bool = roster.has("talisman") and roster.has("fire_talisman") \
		and roster.has("phoenix_talisman")
	passed = passed and not roster.has("sword") and not roster.has("sharp_sword") \
		and not roster.has("_grades")
	if not passed:
		push_error("test_bestiary: weapon roster must be the reachable closure, got %s" % [roster])
	return passed


func test_progress_derives_from_data_not_the_record() -> bool:
	# A hand-edited profile claiming everything (plus bogus ids) still counts
	# only what the data roster contains — the totals stay consistent.
	var record: Dictionary = {
		"monsters": ["goblin", "spirit", "boss_lord", "fake_a", "fake_b"], "unseen": 0
	}
	var progress: Dictionary = Bestiary.progress(
		record, Bestiary.KIND_MONSTERS, ["goblin", "spirit", "boss_lord"]
	)
	if int(progress["found"]) != 3 or int(progress["total"]) != 3:
		push_error("test_bestiary: claimed bogus ids must not inflate the counts")
		return false
	# A new data entry appears in the totals automatically as undiscovered.
	var grown: Dictionary = Bestiary.progress(
		record, Bestiary.KIND_MONSTERS, ["goblin", "spirit", "boss_lord", "new_monster"]
	)
	return int(grown["found"]) == 3 and int(grown["total"]) == 4


func test_rows_mask_undiscovered_entries() -> bool:
	var record: Dictionary = {"monsters": ["goblin"], "loot": ["ember"], "weapons": ["talisman"]}
	var roster: Array[Dictionary] = Bestiary.monster_roster(FIXTURE_STAGES, FIXTURE_MONSTERS)
	var rows: Array[Dictionary] = Bestiary.monster_rows(
		roster, FIXTURE_MONSTERS, FIXTURE_STAGES, record, "ko"
	)
	# Discovered: real name plus where it appears. Undiscovered: ??? and
	# nothing else — the player sees how much is left, not what it is.
	var goblin: Dictionary = rows[0]
	var passed: bool = bool(goblin["discovered"]) and String(goblin["name"]) == "도깨비"
	passed = passed and (goblin["lines"] as Array).size() == 1 \
		and String((goblin["lines"] as Array)[0]).contains("대나무 숲")
	var hidden: Dictionary = rows[1]
	passed = passed and not bool(hidden["discovered"]) \
		and String(hidden["name"]) == Bestiary.UNKNOWN_NAME
	passed = passed and (hidden["lines"] as Array).is_empty() \
		and String(hidden["pill"]).is_empty()
	if not passed:
		push_error("test_bestiary: monster rows must mask undiscovered entries")
		return false
	# The undiscovered boss must not reveal its 보스 pill either.
	if not String(rows[2]["pill"]).is_empty():
		push_error("test_bestiary: undiscovered boss must not show the boss pill")
		return false
	return true


func test_recipe_lines_mask_each_undiscovered_end() -> bool:
	var record: Dictionary = {"loot": ["ember"], "weapons": ["talisman"]}
	var loot_rows: Array[Dictionary] = Bestiary.loot_rows(
		["ember"], FIXTURE_LOOT, FIXTURE_MODS, FIXTURE_WEAPONS, record, "ko"
	)
	# ember transforms 부적 → fire_talisman (undiscovered → masked) and
	# fire_talisman → phoenix (both masked).
	var lines: Array = loot_rows[0]["lines"]
	var passed: bool = lines.size() == 2
	passed = passed and String(lines[0]) == "부적 → ???" and String(lines[1]) == "??? → ???"
	if not passed:
		push_error("test_bestiary: loot recipe lines must mask undiscovered ends, got %s" % [lines])
		return false
	var weapon_rows: Array[Dictionary] = Bestiary.weapon_rows(
		["talisman"], FIXTURE_WEAPONS, FIXTURE_MODS, record, "ko"
	)
	var weapon_lines: Array = weapon_rows[0]["lines"]
	# Mechanic line first, then the masked branch.
	passed = weapon_lines.size() == 2
	passed = passed and String(weapon_lines[0]) == Bestiary.mechanic_line("straight", "ko")
	passed = passed and String(weapon_lines[1]).contains("부적 → ???")
	if not passed:
		push_error("test_bestiary: weapon rows must lead with the mechanic line")
	return passed


func test_mechanic_lines_cover_every_supported_mechanic() -> bool:
	for mechanic: String in LevelUp.SUPPORTED_MECHANICS:
		if Bestiary.mechanic_line(mechanic, "ko").is_empty() \
				or Bestiary.mechanic_line(mechanic, "en").is_empty():
			push_error("test_bestiary: mechanic '%s' missing a bestiary line" % mechanic)
			return false
	return true


func test_real_data_rosters_are_consistent() -> bool:
	var stages: Dictionary = _load_json("res://data/stages.json")
	var monsters: Dictionary = _load_json("res://data/monsters.json")
	var weapons: Dictionary = _load_json("res://data/weapons.json")
	var mods: Dictionary = _load_json("res://data/weapon_mods.json")
	var loot: Dictionary = _load_json("res://data/loot.json")
	var roster: Array[Dictionary] = Bestiary.monster_roster(stages, monsters)
	if roster.is_empty() or Bestiary.loot_roster(loot).is_empty():
		push_error("test_bestiary: real data rosters must not be empty")
		return false
	var weapon_ids: Array[String] = Bestiary.weapon_roster(weapons, mods)
	# Both starting weapons are reachable now — the taoist's talisman and,
	# since the warrior became playable (N9-148), the sword line too.
	if not weapon_ids.has("old_talisman") or not weapon_ids.has("sword"):
		push_error("test_bestiary: real weapon roster reachability broke")
		return false
	# Every mod whose base is reachable must land its result in the roster —
	# a completed mod is always recordable against the totals.
	for mod_id: String in mods:
		var mod: Dictionary = mods[mod_id]
		if weapon_ids.has(String(mod["weapon_id"])) \
				and not weapon_ids.has(String(mod["result_weapon"])):
			push_error("test_bestiary: mod result '%s' missing from roster" % mod["result_weapon"])
			return false
	# Every roster id must carry a Korean name — the discovered row shows it.
	for entry: Dictionary in roster:
		if String((monsters[entry["id"]] as Dictionary).get("name_ko", "")).is_empty():
			push_error("test_bestiary: monster '%s' has no name_ko" % entry["id"])
			return false
	return true


func test_screen_builds_with_mixed_record() -> bool:
	var screen: BestiaryScreen = (load(BESTIARY_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	var rows: VBoxContainer = screen.get_node("Layout/Column/Scroll/Rows")
	var monsters: Dictionary = _load_json("res://data/monsters.json")
	var stages: Dictionary = _load_json("res://data/stages.json")
	var expected: int = Bestiary.monster_roster(stages, monsters).size()
	var passed: bool = rows.get_child_count() == expected
	# With no SaveService (headless), everything is undiscovered: every row
	# must read ??? and the progress pill must say 0 of the data total.
	for row: Node in rows.get_children():
		var name_label: Label = row.get_node("Content/Texts/Name")
		passed = passed and name_label.text == Bestiary.UNKNOWN_NAME
	var progress: Label = screen.get_node("Layout/Column/Header/ProgressPill/ProgressValue")
	passed = passed and progress.text.begins_with("0/")
	if not passed:
		push_error("test_bestiary: screen must render one masked row per roster entry")
	screen.free()
	return passed


## N9-11 NEW badge: mark_viewed is a pure idempotent fold and is_new flips
## exactly on the viewed transition; old records without a viewed block
## backfill through normalized_record.
func test_mark_viewed_fold_and_is_new() -> bool:
	var profile: Dictionary = {"bestiary": {Bestiary.KIND_MONSTERS: ["forest_goblin"]}}
	if not Bestiary.is_new(profile["bestiary"], Bestiary.KIND_MONSTERS, "forest_goblin"):
		return false
	# Undiscovered ids are never NEW.
	if Bestiary.is_new(profile["bestiary"], Bestiary.KIND_MONSTERS, "forest_spirit"):
		return false
	var marked: Dictionary = Bestiary.mark_viewed(
		profile, Bestiary.KIND_MONSTERS, ["forest_goblin"]
	)
	if not bool(marked["changed"]):
		return false
	var next: Dictionary = marked["profile"]
	if Bestiary.is_new(next["bestiary"], Bestiary.KIND_MONSTERS, "forest_goblin"):
		return false
	# Idempotent: a second fold reports no change and skips the write.
	var again: Dictionary = Bestiary.mark_viewed(
		next, Bestiary.KIND_MONSTERS, ["forest_goblin"]
	)
	return not bool(again["changed"]) and not profile["bestiary"].has(Bestiary.VIEWED_KEY)


func test_rows_carry_is_new_flag() -> bool:
	var record: Dictionary = {
		Bestiary.KIND_LOOT: ["bamboo", "whetstone"],
		Bestiary.VIEWED_KEY: {Bestiary.KIND_LOOT: ["bamboo"]},
	}
	var loot: Dictionary = _load_json("res://data/loot.json")
	var ids: Array[String] = ["bamboo", "whetstone", "cinnabar"]
	var rows: Array[Dictionary] = Bestiary.loot_rows(ids, loot, {}, {}, record, "ko")
	return not bool(rows[0]["is_new"]) \
		and bool(rows[1]["is_new"]) \
		and not bool(rows[2]["is_new"])


static func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		return {}
	return data
