class_name MetaTree
extends RefCounted
## Pure, node-free 명부수 permanent-upgrade logic (N7-1, GDD §19): tree data
## access, purchase validation as a single profile mutation, corrupt-state
## sanitizing and the capped run-start aggregate. MetaTreeScreen owns the
## nodes; tests/unit/test_meta_tree.gd covers every rule here.

const TREE_PATH := "res://data/meta_tree.json"

## can_purchase / purchase outcome vocabulary the screen turns into feedback.
const REASON_OK := "ok"
const REASON_UNKNOWN := "unknown_node"
const REASON_LOCKED := "locked"
const REASON_MAXED := "maxed"
const REASON_GOLD := "gold"

const NO_NEXT_COST := -1


static func load_tree() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREE_PATH))
	if data is not Dictionary:
		push_error("meta_tree: cannot parse " + TREE_PATH)
		return {}
	return data


static func nodes(tree: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Variant in tree.get("nodes", []):
		if entry is Dictionary:
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


## Cost of the NEXT rank after current_rank, or NO_NEXT_COST when maxed.
static func next_cost(entry: Dictionary, current_rank: int) -> int:
	var costs: Array = entry.get("costs", [])
	if current_rank < 0 or current_rank >= costs.size():
		return NO_NEXT_COST
	return int(costs[current_rank])


## Validates one prospective purchase without touching anything.
static func can_purchase(
	tree: Dictionary, state: Dictionary, gold: int, node_id: String
) -> String:
	var entry: Dictionary = node(tree, node_id)
	if entry.is_empty():
		return REASON_UNKNOWN
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
static func purchase(profile: Dictionary, tree: Dictionary, node_id: String) -> Dictionary:
	# A successful purchase also persists the sanitized state, so a corrupt
	# profile self-heals here instead of carrying junk entries forever.
	var state: Dictionary = sanitize_state(
		tree, profile.get("meta_tree", {}) as Dictionary
	)["state"]
	var gold: int = int(profile.get("gold", 0))
	var reason: String = can_purchase(tree, state, gold, node_id)
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
## clamped to config.stat_caps. This is the ONLY producer of meta bonuses —
## the stage applies its output exactly once, so effects cannot double-stack.
static func aggregate_effects(tree: Dictionary, state: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for entry: Dictionary in nodes(tree):
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


## Every node at max rank — the balance-guard playtest profile.
static func maxed_state(tree: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for entry: Dictionary in nodes(tree):
		state[String(entry.get("id", ""))] = max_rank(entry)
	return state


## Full data contract for tools/validate_data.gd (and the unit tests): every
## rule the screen and the run rely on. Returns human-readable issue strings.
static func data_issues(tree: Dictionary) -> Array[String]:
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
		_node_issues(entry, ids, issues)
	_reachability_issues(entries, ids, issues)
	_cap_issues(tree, entries, issues)
	return issues


static func _node_issues(
	entry: Dictionary, ids: Array[String], issues: Array[String]
) -> void:
	var node_id: String = String(entry.get("id", ""))
	if String(entry.get("name_ko", "")).is_empty() \
			or String(entry.get("name_en", "")).is_empty():
		issues.append("node '%s' missing name_ko/name_en" % node_id)
	var effect: Dictionary = entry.get("effect", {})
	var stat: String = String(effect.get("stat", ""))
	# The stat vocabulary IS the set the run already applies — anything else
	# would be a dead stat that silently does nothing.
	if stat not in LevelUp.OFFERABLE_PASSIVES:
		issues.append("node '%s' effect stat '%s' unknown to the run" % [node_id, stat])
	if float(effect.get("per_rank", 0.0)) <= 0.0:
		issues.append("node '%s' effect per_rank must be positive" % node_id)
	var costs: Array = entry.get("costs", [])
	if costs.is_empty():
		issues.append("node '%s' costs empty (max_rank < 1)" % node_id)
	for cost: Variant in costs:
		if (cost is not float and cost is not int) or int(cost) <= 0:
			issues.append("node '%s' has a non-positive cost" % node_id)
			break
	for required: Variant in entry.get("requires", []):
		if String(required) == node_id:
			issues.append("node '%s' requires itself" % node_id)
		elif not ids.has(String(required)):
			issues.append("node '%s' requires missing node '%s'" % [node_id, required])
	var pos: Array = entry.get("pos", [])
	if pos.size() != 2 or float(pos[0]) < 0.0 or float(pos[0]) > 1.0 \
			or float(pos[1]) < 0.0:
		issues.append("node '%s' pos must be [x 0..1, row >= 0]" % node_id)


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


## Balance guard: every stat the tree touches must declare a positive cap in
## config.stat_caps, so a data edit cannot silently exceed the design ceiling.
static func _cap_issues(
	tree: Dictionary, entries: Array[Dictionary], issues: Array[String]
) -> void:
	var caps: Dictionary = (tree.get("config", {}) as Dictionary).get("stat_caps", {})
	for entry: Dictionary in entries:
		var stat: String = String((entry.get("effect", {}) as Dictionary).get("stat", ""))
		if stat.is_empty() or stat not in LevelUp.OFFERABLE_PASSIVES:
			continue
		if float(caps.get(stat, 0.0)) <= 0.0:
			issues.append("config.stat_caps.%s missing or not positive" % stat)
