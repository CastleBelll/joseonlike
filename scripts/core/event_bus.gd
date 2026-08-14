extends Node
## Global signal hub. Systems emit and listen here instead of referencing each
## other directly, which keeps combat, UI, and meta progression independently
## testable and merge-safe across worktrees.
##
## Frozen contract — see ARCHITECTURE.md section 3.1.

signal run_started(character_id: String, stage_id: String)
signal run_ended(result: Dictionary)

signal player_damaged(amount: float, hp_left: float)
signal player_died()

signal enemy_killed(monster_id: String, position: Vector2)

signal xp_gained(amount: int)
signal loot_collected(loot_id: String)
signal loot_salvaged(loot_id: String, gold_amount: int)

## Active skill (GDD v2 section 30). The HUD button and the player node talk
## through these so the HUD keeps its no-player-reference contract.
signal active_skill_pressed()
signal active_skill_used(cooldown_sec: float)
signal level_reached(level: int, choices: Array[Dictionary])
signal upgrade_chosen(choice_id: String)
signal weapon_evolved(from_id: String, to_id: String)
## A loot-material mod replaced a weapon (GDD v2 section 33). Distinct from
## weapon_evolved so achievement counters do not conflate the two.
signal weapon_modified(from_id: String, to_id: String)

signal boss_spawned(boss_id: String)
signal boss_defeated(boss_id: String)

## Generic counter feed for achievements and quests.
signal stat_recorded(key: String, amount: int)
