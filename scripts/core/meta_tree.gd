class_name MetaTree
extends RefCounted
## Pure, node-free 명부수 permanent-upgrade logic (N7-1, reworked N7-2): tree
## data access, purchase validation as a single profile mutation, corrupt-state
## sanitizing, the capped run-start aggregate, and the per-character branch
## rules (shared trunk + one branch per roster entry). MetaTreeScreen owns the
## nodes; tests/unit/test_meta_tree.gd covers every rule here.

const TREE_PATH := "res://data/meta_tree.json"
const CHARACTERS_PATH := "res://data/characters.json"

## can_purchase / purchase outcome vocabulary the screen turns into feedback.
const REASON_OK := "ok"
const REASON_UNKNOWN := "unknown_node"
const REASON_LOCKED := "locked"
const REASON_MAXED := "maxed"
const REASON_GOLD := "gold"
## N7-2: the node belongs to a character the profile has not unlocked yet.
const REASON_CHARACTER := "character_locked"

const NO_NEXT_COST := -1

## N7-2 wired-stat vocabulary. Every entry is consumed somewhere in the run —
## validate_data fails any node whose effect stat is not on this list, so an
## inert node cannot ship. Grouped by where the run applies it:
## run-wide scalars folded into Stage._refresh_run_scalars / the HP grant.
const SCALAR_STATS: Array[String] = [
	"max_hp", "move_speed", "attack_damage", "attack_speed", "magnet_radius",
	# N9-93 (owner: the tree is too small): three more run-wide scalars, wired
	# into the same _passive_bonus + _meta_bonus expressions the others use.
	"crit_chance", "crit_damage", "projectile_speed"
]
## Run economy multipliers (Stage gold/xp pickup paths; luck scales the
## special-material drop odds in the loot roll — N4-9).
const ECONOMY_STATS: Array[String] = ["gold_gain", "xp_gain", "luck"]
## Start-of-run and choice-quality counters (Stage._ready / level-up screen).
const START_STATS: Array[String] = ["start_level", "choice_count", "first_find"]
## Survivability (Player damage pipeline + Stage revive).
const SURVIVAL_STATS: Array[String] = ["revive", "damage_reduction", "hit_invuln"]
## 술법 weapon-stat modifiers (AutoWeapon via modified_weapon_stats).
const WEAPON_STATS: Array[String] = [
	"burn_duration", "chain_jumps", "ward_radius", "orbit_count", "seal_burst",
	# N9-93: the two fold keys N9-88 added for the field passives — one fold,
	# both suppliers, so a tree node gets them for the price of a data entry.
	"burn_dps", "area_radius"
]
## Fractional stats that MUST declare a positive config.stat_caps entry; the
## integer counters above are capped by their rank ladders instead.
const CAPPED_STATS: Array[String] = [
	"max_hp", "move_speed", "attack_damage", "attack_speed", "magnet_radius",
	"gold_gain", "xp_gain", "luck", "damage_reduction", "hit_invuln",
	"burn_duration", "ward_radius", "crit_chance", "crit_damage",
	"projectile_speed", "burn_dps", "area_radius"
]
## Sealed weapons must always need at least this many stacks to burst.
const MIN_SEAL_BURST := 2


static func wired_stats() -> Array[String]:
	var all: Array[String] = []
	all.append_array(SCALAR_STATS)
	all.append_array(ECONOMY_STATS)
	all.append_array(START_STATS)
	all.append_array(SURVIVAL_STATS)
	all.append_array(WEAPON_STATS)
	return all


static func load_tree() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREE_PATH))
	if data is not Dictionary:
		push_error("meta_tree: cannot parse " + TREE_PATH)
		return {}
	return data


static func load_characters() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	if data is not Dictionary:
		push_error("meta_tree: cannot parse " + CHARACTERS_PATH)
		return {}
	return data


## Characters whose branch is purchasable. Mirrors CharacterSelect's rule:
## only "default" unlocks are playable today; achievement/gold unlocks join
## this list when those systems land.
static func unlocked_characters(characters: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for character_id: String in characters:
		var unlock: Dictionary = (characters[character_id] as Dictionary).get("unlock", {})
		if String(unlock.get("type", "")) == "default":
			result.append(character_id)
	return result


static func nodes(tree: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Variant in tree.get("nodes", []):
		if entry is Dictionary:
			result.append(entry)
	return result


## The branch a node belongs to: a character id, or "" for the shared trunk.
static func node_character(entry: Dictionary) -> String:
	return String(entry.get("character", ""))


## Nodes on one tab: the trunk ("") or one character's branch.
static func branch_nodes(tree: Dictionary, character_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in nodes(tree):
		if node_character(entry) == character_id:
			result.append(entry)
	return result


static func node(tree: Dictionary, node_id: String) -> Dictionary:
	for entry: Dictionary in nodes(tree):
		if String(entry.get("id", "")) == node_id:
			return entry
	return {}


## Max rank is the length of the per-rank cost ladder — one source of truth,
## so cost and rank count can never disagree.
static func max_rank(entry: Dictionary) -> int:
	return (entry.get("costs", []) as Array).size()


static func rank_of(state: Dictionary, node_id: String) -> int:
	return maxi(int(state.get(node_id, 0)), 0)


## A prerequisite is satisfied by owning at least rank 1 of it.
static func is_unlocked(tree: Dictionary, state: Dictionary, node_id: String) -> bool:
	for required: Variant in node(tree, node_id).get("requires", []):
		if rank_of(state, String(required)) < 1:
			return false
	return true


## Display names of the unmet prerequisites, so a locked node can name its
## requirement instead of just refusing.
static func locked_names(
	tree: Dictionary, state: Dictionary, node_id: String, locale: String
) -> Array[String]:
	var result: Array[String] = []
	for required: Variant in node(tree, node_id).get("requires", []):
		if rank_of(state, String(required)) < 1:
			result.append(display_name(node(tree, String(required)), locale))
	return result


static func display_name(entry: Dictionary, locale: String) -> String:
	var key: String = "name_en" if locale == "en" else "name_ko"
	return String(entry.get(key, entry.get("name_ko", "")))


## Per-rank effect copy from data — the numbers live in effect{}, the words
## live here, and validate_data requires both so a node cannot ship blank.
static func display_desc(entry: Dictionary, locale: String) -> String:
	var key: String = "desc_en" if locale == "en" else "desc_ko"
	return String(entry.get(key, entry.get("desc_ko", "")))


## Cost of the NEXT rank after current_rank, or NO_NEXT_COST when maxed.
static func next_cost(entry: Dictionary, current_rank: int) -> int:
	var costs: Array = entry.get("costs", [])
	if current_rank < 0 or current_rank >= costs.size():
		return NO_NEXT_COST
	return int(costs[current_rank])


## Validates one prospective purchase without touching anything. `unlocked`
## lists the purchasable characters (unlocked_characters); trunk nodes skip it.
static func can_purchase(
	tree: Dictionary, state: Dictionary, gold: int, node_id: String,
	unlocked: Array[String]
) -> String:
	var entry: Dictionary = node(tree, node_id)
	if entry.is_empty():
		return REASON_UNKNOWN
	var branch: String = node_character(entry)
	if not branch.is_empty() and branch not in unlocked:
		return REASON_CHARACTER
	if not is_unlocked(tree, state, node_id):
		return REASON_LOCKED
	var cost: int = next_cost(entry, rank_of(state, node_id))
	if cost == NO_NEXT_COST:
		return REASON_MAXED
	# A non-positive cost is corrupt data; refuse rather than grant or refund.
	if cost <= 0 or gold < cost:
		return REASON_GOLD
	return REASON_OK


## The purchase as ONE profile fold: gold and rank change together in a new
## dict, or nothing changes at all — the atomic save write then persists both
## or neither, so they can never diverge. The input profile is never mutated.
static func purchase(
	profile: Dictionary, tree: Dictionary, node_id: String, unlocked: Array[String]
) -> Dictionary:
	# A successful purchase also persists the sanitized state, so a corrupt
	# profile self-heals here instead of carrying junk entries forever.
	var state: Dictionary = sanitize_state(
		tree, profile.get("meta_tree", {}) as Dictionary
	)["state"]
	var gold: int = int(profile.get("gold", 0))
	var reason: String = can_purchase(tree, state, gold, node_id, unlocked)
	if reason != REASON_OK:
		return {"ok": false, "reason": reason, "profile": profile}
	var next: Dictionary = profile.duplicate(true)
	next["gold"] = gold - next_cost(node(tree, node_id), rank_of(state, node_id))
	state[node_id] = rank_of(state, node_id) + 1
	next["meta_tree"] = state
	return {"ok": true, "reason": REASON_OK, "profile": next}


## Hand-edited or stale tree state: unknown ids drop, ranks clamp into
## [1, max_rank] — never crash, never silently grant power beyond the data.
## Returns {"state": Dictionary, "dropped": int} so the caller can warn once.
## N7-2 migration contract: nodes removed by the rework are pruned here with
## the caller's warning and their gold is deliberately NOT refunded — the
## rework is a repricing, not a rollback (data/BALANCE.md N7-2).
static func sanitize_state(tree: Dictionary, state: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	var dropped: int = 0
	for key: Variant in state.keys():
		var node_id: String = String(key)
		var entry: Dictionary = node(tree, node_id)
		var rank: int = int(state[key])
		if entry.is_empty() or rank < 1:
			dropped += 1
			continue
		var capped: int = mini(rank, max_rank(entry))
		if capped != rank:
			dropped += 1
		clean[node_id] = capped
	return {"state": clean, "dropped": dropped}


## The run-start bonus: per-rank effect times owned rank, summed per stat and
## clamped to config.stat_caps. Only the trunk and the SELECTED character's
## branch apply — another character's branch must never leak into a run.
## This is the ONLY producer of meta bonuses — the stage applies its output
## exactly once, so effects cannot double-stack.
static func aggregate_effects(
	tree: Dictionary, state: Dictionary, character_id: String
) -> Dictionary:
	var totals: Dictionary = {}
	for entry: Dictionary in nodes(tree):
		var branch: String = node_character(entry)
		if not branch.is_empty() and branch != character_id:
			continue
		var rank: int = rank_of(state, String(entry.get("id", "")))
		if rank < 1:
			continue
		var effect: Dictionary = entry.get("effect", {})
		var stat: String = String(effect.get("stat", ""))
		var amount: float = float(effect.get("per_rank", 0.0)) * mini(rank, max_rank(entry))
		totals[stat] = float(totals.get(stat, 0.0)) + amount
	var caps: Dictionary = (tree.get("config", {}) as Dictionary).get("stat_caps", {})
	for stat: String in totals.keys():
		if caps.has(stat):
			totals[stat] = minf(float(totals[stat]), float(caps[stat]))
	return totals


## N7-2 술법 branch application: a new stats dict with the owned weapon-stat
## bonuses folded into the mechanic blocks the runtime already reads —
## burn duration, chain jumps, ward radius, orbit orb count, seal stacks.
## Weapons without the matching block are returned unchanged.
static func modified_weapon_stats(stats: Dictionary, effects: Dictionary) -> Dictionary:
	var result: Dictionary = stats.duplicate(true)
	var burn_scale: float = float(effects.get("burn_duration", 0.0))
	var status: Dictionary = result.get("on_hit_status", {})
	if burn_scale > 0.0 and String(status.get("id", "")) == "burn":
		status["duration_sec"] = float(status.get("duration_sec", 0.0)) * (1.0 + burn_scale)
	var jumps: int = int(effects.get("chain_jumps", 0.0))
	if jumps > 0 and result.has("chain"):
		var chain: Dictionary = result["chain"]
		chain["jumps"] = int(chain.get("jumps", 0)) + jumps
	var ward_scale: float = float(effects.get("ward_radius", 0.0))
	if ward_scale > 0.0 and result.has("ward"):
		var ward: Dictionary = result["ward"]
		ward["radius_px"] = float(ward.get("radius_px", 0.0)) * (1.0 + ward_scale)
	var extra_orbs: int = int(effects.get("orbit_count", 0.0))
	if extra_orbs > 0 and String(result.get("mechanic", "")) == "orbit":
		result["projectile_count"] = int(result.get("projectile_count", 1)) + extra_orbs
	var seal_ease: int = int(effects.get("seal_burst", 0.0))
	var seal: Dictionary = result.get("on_hit_seal", {})
	if seal_ease > 0 and not seal.is_empty():
		seal["burst_at"] = maxi(int(seal.get("burst_at", 0)) - seal_ease, MIN_SEAL_BURST)
	# N9-88: two more effect kinds, added for the field passives (불씨 정통 and
	# 광역 확장) but usable by any future tree node — this function is the one
	# place "effects fold into weapon stats" lives, whoever supplies them.
	var burn_dps_scale: float = float(effects.get("burn_dps", 0.0))
	if burn_dps_scale > 0.0 and String(status.get("id", "")) == "burn":
		status["dps"] = float(status.get("dps", 0.0)) * (1.0 + burn_dps_scale)
	var area_scale: float = float(effects.get("area_radius", 0.0))
	if area_scale > 0.0:
		# The AREA mechanics only: a chain's reach and an orbit's ring have
		# their own knobs, and scaling them here would double-dip.
		for block_name: String in ["explosion", "ward", "shockwave"]:
			if result.has(block_name):
				var block: Dictionary = result[block_name]
				block["radius_px"] = float(block.get("radius_px", 0.0)) * (1.0 + area_scale)
	return result


## Every node at max rank — the balance-guard playtest profile.
static func maxed_state(tree: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for entry: Dictionary in nodes(tree):
		state[String(entry.get("id", ""))] = max_rank(entry)
	return state


## Full data contract for tools/validate_data.gd (and the unit tests): every
## rule the screen and the run rely on. Returns human-readable issue strings.
## `characters` is the roster (data/characters.json) branch nodes must match.
static func data_issues(tree: Dictionary, characters: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var entries: Array[Dictionary] = nodes(tree)
	if entries.is_empty():
		issues.append("nodes missing or empty")
		return issues
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		var node_id: String = String(entry.get("id", ""))
		if node_id.is_empty():
			issues.append("node missing id")
			continue
		if ids.has(node_id):
			issues.append("duplicate node id '%s'" % node_id)
		ids.append(node_id)
	for entry: Dictionary in entries:
		_node_issues(tree, entry, ids, characters, issues)
	_reachability_issues(entries, ids, issues)
	_cap_issues(tree, entries, characters, issues)
	return issues


static func _node_issues(
	tree: Dictionary, entry: Dictionary, ids: Array[String],
	characters: Dictionary, issues: Array[String]
) -> void:
	var node_id: String = String(entry.get("id", ""))
	if String(entry.get("name_ko", "")).is_empty() \
			or String(entry.get("name_en", "")).is_empty():
		issues.append("node '%s' missing name_ko/name_en" % node_id)
	if String(entry.get("desc_ko", "")).is_empty() \
			or String(entry.get("desc_en", "")).is_empty():
		issues.append("node '%s' missing desc_ko/desc_en" % node_id)
	var branch: String = node_character(entry)
	if not branch.is_empty() and not characters.has(branch):
		issues.append("node '%s' character '%s' not in characters.json" % [node_id, branch])
	var effect: Dictionary = entry.get("effect", {})
	var stat: String = String(effect.get("stat", ""))
	# The stat vocabulary IS the set the run actually consumes — anything else
	# would be a dead node that silently does nothing.
	if stat not in wired_stats():
		issues.append("node '%s' effect stat '%s' not wired to the run" % [node_id, stat])
	if float(effect.get("per_rank", 0.0)) <= 0.0:
		issues.append("node '%s' effect per_rank must be positive" % node_id)
	_cost_issues(tree, entry, issues)
	for required: Variant in entry.get("requires", []):
		if String(required) == node_id:
			issues.append("node '%s' requires itself" % node_id)
		elif not ids.has(String(required)):
			issues.append("node '%s' requires missing node '%s'" % [node_id, required])
		else:
			# Edges never cross tabs: a branch node's prerequisite lives on the
			# same branch, a trunk node's on the trunk.
			var required_entry: Dictionary = node(tree, String(required))
			if node_character(required_entry) != branch:
				issues.append(
					"node '%s' requires '%s' from a different branch" % [node_id, required]
				)
	var pos: Array = entry.get("pos", [])
	if pos.size() != 2 or float(pos[0]) < 0.0 or float(pos[0]) > 1.0 \
			or float(pos[1]) < 0.0:
		issues.append("node '%s' pos must be [x 0..1, row >= 0]" % node_id)


## N7-2 cost-curve contract: every cost positive, each rank strictly more
## expensive than the last, and a node's first rank costs more than each
## prerequisite's first rank — deeper tiers always cost more than the trunk
## they grow from.
static func _cost_issues(
	tree: Dictionary, entry: Dictionary, issues: Array[String]
) -> void:
	var node_id: String = String(entry.get("id", ""))
	var costs: Array = entry.get("costs", [])
	if costs.is_empty():
		issues.append("node '%s' costs empty (max_rank < 1)" % node_id)
		return
	var previous: int = 0
	for cost: Variant in costs:
		if (cost is not float and cost is not int) or int(cost) <= 0:
			issues.append("node '%s' has a non-positive cost" % node_id)
			return
		if int(cost) <= previous:
			issues.append("node '%s' costs must be strictly increasing" % node_id)
			return
		previous = int(cost)
	for required: Variant in entry.get("requires", []):
		var required_costs: Array = node(tree, String(required)).get("costs", [])
		if not required_costs.is_empty() and int(costs[0]) <= int(required_costs[0]):
			issues.append(
				"node '%s' first cost must exceed prerequisite '%s'" % [node_id, required]
			)


## Kahn-style peel: repeatedly resolve nodes whose prerequisites are all
## resolved. Whatever is left sits on or behind a dependency cycle and can
## never be reached from a root.
static func _reachability_issues(
	entries: Array[Dictionary], ids: Array[String], issues: Array[String]
) -> void:
	var resolved: Dictionary = {}
	var progressed: bool = true
	while progressed:
		progressed = false
		for entry: Dictionary in entries:
			var node_id: String = String(entry.get("id", ""))
			if resolved.has(node_id):
				continue
			var ready: bool = true
			for required: Variant in entry.get("requires", []):
				# Missing prereqs are reported separately; only real edges gate.
				if ids.has(String(required)) and not resolved.has(String(required)):
					ready = false
					break
			if ready:
				resolved[node_id] = true
				progressed = true
	for entry: Dictionary in entries:
		var node_id: String = String(entry.get("id", ""))
		if not resolved.has(node_id):
			issues.append("node '%s' unreachable (dependency cycle)" % node_id)


## Balance guard: every fractional stat the tree touches must declare a
## positive cap, and no single character's reachable total (trunk + own
## branch) may exceed it — ranks past the cap would be sold but do nothing.
static func _cap_issues(
	tree: Dictionary, entries: Array[Dictionary], characters: Dictionary,
	issues: Array[String]
) -> void:
	var caps: Dictionary = (tree.get("config", {}) as Dictionary).get("stat_caps", {})
	var capped_seen: Array[String] = []
	for entry: Dictionary in entries:
		var stat: String = String((entry.get("effect", {}) as Dictionary).get("stat", ""))
		if stat not in CAPPED_STATS or capped_seen.has(stat):
			continue
		capped_seen.append(stat)
		if float(caps.get(stat, 0.0)) <= 0.0:
			issues.append("config.stat_caps.%s missing or not positive" % stat)
	for character_id: String in characters:
		for stat: String in capped_seen:
			if not caps.has(stat):
				continue
			var raw: float = _raw_total(tree, character_id, stat)
			if raw > float(caps[stat]) + 0.0001:
				issues.append(
					"stat '%s' reachable total %.2f for '%s' exceeds cap %.2f (dead ranks)"
					% [stat, raw, character_id, float(caps[stat])]
				)


static func _raw_total(tree: Dictionary, character_id: String, stat: String) -> float:
	var total: float = 0.0
	for entry: Dictionary in nodes(tree):
		var branch: String = node_character(entry)
		if not branch.is_empty() and branch != character_id:
			continue
		var effect: Dictionary = entry.get("effect", {})
		if String(effect.get("stat", "")) != stat:
			continue
		total += float(effect.get("per_rank", 0.0)) * max_rank(entry)
	return total
