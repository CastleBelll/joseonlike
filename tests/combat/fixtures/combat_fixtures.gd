class_name CombatFixtures
extends RefCounted
## Synthetic content for combat tests.
##
## These mirror the schemas in ARCHITECTURE.md section 4 but are owned by this
## worktree, so combat tests never wait on data/*.json from content-data.
## Numbers here are chosen to make arithmetic obvious, not to be balanced.


## Spiritual weapon: 10 damage, +3 per level, 1.0s cooldown, -0.1s per level.
static func spiritual_weapon() -> Dictionary:
	return {
		"name_en": "Test Talisman",
		"category": "spiritual",
		"grade": "common",
		"damage": 10.0,
		"cooldown_sec": 1.0,
		"projectile_count": 1,
		"pierce": 0,
		"area_scale": 1.0,
		"speed": 260.0,
		"max_level": 8,
		"per_level": {"damage": 3.0, "cooldown_sec": -0.1, "projectile_count": 0.5},
	}


## Melee weapon with no per_level table, to cover the "missing key" path.
static func melee_weapon() -> Dictionary:
	return {
		"name_en": "Test Sword",
		"category": "melee",
		"grade": "common",
		"damage": 20.0,
		"cooldown_sec": 2.0,
		"max_level": 3,
	}


static func chase_monster() -> Dictionary:
	return {
		"name_en": "Test Goblin",
		"hp": 20.0,
		"damage": 6.0,
		"speed": 55.0,
		"xp_drop": 3,
		"gold_drop": 1,
		"behaviour": "chase",
		"sprite": "res://assets/monsters/does_not_exist.png",
	}


## Two waves that overlap in time, so scheduling tests exercise the sort.
static func stage_with_waves() -> Dictionary:
	return {
		"name_en": "Test Forest",
		"duration_sec": 60.0,
		"boss_id": "test_boss",
		"waves": [
			{"at_sec": 10.0, "monster_id": "late_goblin", "count": 2, "interval_sec": 5.0},
			{"at_sec": 0.0, "monster_id": "test_goblin", "count": 3, "interval_sec": 2.0},
		],
	}


## evolution_for-shaped lookup: (weapon_id, passive_id) -> evolved weapon id.
static func evolution_table() -> Dictionary:
	return {
		"test_talisman|skill_power": "test_phoenix_talisman",
		"test_bow|attack_speed": "test_divine_bow",
	}


## Builds a resolver Callable with the same signature as GameData.evolution_for.
static func evolution_resolver(table: Dictionary) -> Callable:
	return func(weapon_id: String, passive_id: String) -> String:
		return String(table.get("%s|%s" % [weapon_id, passive_id], ""))
