extends RefCounted
## Guards the N7-1/N7-2 명부수 meta tree: the data contract (cycles, unwired
## stats, cost curve, per-character ownership, duplicates), purchase
## validation across every edge case, corrupt-state sanitizing, the capped
## per-character run-start aggregate, the 술법 weapon-stat application and the
## screen's tab/CTA/selection behaviour.

const META_SCENE := "res://scenes/meta_tree.tscn"

## Purchasable characters for the pure-purchase tests.
const UNLOCKED: Array[String] = ["taoist"]

## Roster fixture: taoist unlocked by default, warrior locked.
static func _tiny_characters() -> Dictionary:
	return {
		"taoist": {"name_ko": "도사", "name_en": "Taoist", "unlock": {"type": "default"}},
		"warrior": {
			"name_ko": "무사", "name_en": "Warrior",
			"unlock": {"type": "achievement", "achievement_id": "goblin_hunter"},
		},
	}


## Synthetic tree: trunk root (max_hp 5%/rank, 2 ranks) → branch
## (attack_damage 4%, 1 rank), plus one node per character branch. Caps
## deliberately BELOW the achievable max_hp total so the clamp is observable.
static func _tiny_tree() -> Dictionary:
	return {
		"config": {"stat_caps": {"max_hp": 0.08, "attack_damage": 0.1}},
		"nodes": [
			{
				"id": "root", "name_ko": "뿌리", "name_en": "Root",
				"desc_ko": "체력", "desc_en": "HP",
				"icon": "tough_fiber",
				"effect": {"stat": "max_hp", "per_rank": 0.05},
				"costs": [10, 25], "requires": [], "pos": [0.3, 0],
			},
			{
				"id": "branch", "name_ko": "가지", "name_en": "Branch",
				"desc_ko": "공격", "desc_en": "Damage",
				"icon": "whetstone",
				"effect": {"stat": "attack_damage", "per_rank": 0.04},
				"costs": [20], "requires": ["root"], "pos": [0.7, 1],
			},
			{
				"id": "tao_burn", "name_ko": "불씨", "name_en": "Ember",
				"desc_ko": "화상", "desc_en": "Burn",
				"icon": "dokkaebi_flame", "character": "taoist",
				"effect": {"stat": "burn_duration", "per_rank": 0.25},
				"costs": [30], "requires": [], "pos": [0.3, 0],
			},
			{
				"id": "war_blade", "name_ko": "환도", "name_en": "Blade",
				"desc_ko": "공격", "desc_en": "Damage",
				"icon": "whetstone", "character": "warrior",
				"effect": {"stat": "attack_damage", "per_rank": 0.04},
				"costs": [30], "requires": [], "pos": [0.3, 0],
			},
		],
	}


static func _profile_with(gold: int, state: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["gold"] = gold
	profile["meta_tree"] = state
	return profile


static func _issues(tree: Dictionary) -> Array[String]:
	return MetaTree.data_issues(tree, _tiny_characters())


## --- data contract ---------------------------------------------------------


func test_shipped_tree_data_is_valid() -> bool:
	var tree: Dictionary = MetaTree.load_tree()
	var issues: Array[String] = MetaTree.data_issues(tree, MetaTree.load_characters())
	if not issues.is_empty():
		push_error("test_meta_tree: shipped tree invalid: " + str(issues))
		return false
	# N7-2: trunk plus one branch per roster character, much larger than N7-1.
	return MetaTree.nodes(tree).size() >= 20 \
		and MetaTree.branch_nodes(tree, "taoist").size() >= 5 \
		and MetaTree.branch_nodes(tree, "warrior").size() >= 2 \
		and MetaTree.branch_nodes(tree, "archer").size() >= 2


## An effect stat nothing in the run consumes must FAIL validation — this is
## the "no inert nodes" proof the task demands.
func test_validator_rejects_unwired_effect_stat() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][0]["effect"] as Dictionary)["stat"] = "not_a_stat"
	for issue: String in _issues(tree):
		if issue.contains("not_a_stat") and issue.contains("not wired"):
			return true
	return false


func test_validator_rejects_dependency_cycle() -> bool:
	var tree: Dictionary = _tiny_tree()
	# root ⇄ branch: a cycle no purchase order can ever satisfy.
	(tree["nodes"][0] as Dictionary)["requires"] = ["branch"]
	for issue: String in _issues(tree):
		if issue.contains("cycle"):
			return true
	return false


func test_validator_rejects_missing_prerequisite() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][1] as Dictionary)["requires"] = ["ghost_node"]
	for issue: String in _issues(tree):
		if issue.contains("ghost_node"):
			return true
	return false


func test_validator_rejects_bad_costs_and_missing_cap() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][0] as Dictionary)["costs"] = [0]        # non-positive cost
	(tree["nodes"][1] as Dictionary)["costs"] = []         # max_rank < 1
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary).erase("attack_damage")
	var issues: Array[String] = _issues(tree)
	var bad_cost: bool = false
	var empty_costs: bool = false
	var missing_cap: bool = false
	for issue: String in issues:
		bad_cost = bad_cost or issue.contains("non-positive cost")
		empty_costs = empty_costs or issue.contains("costs empty")
		missing_cap = missing_cap or issue.contains("stat_caps.attack_damage")
	return bad_cost and empty_costs and missing_cap


## N7-2 cost curve: ranks must get strictly more expensive, and a deeper node
## must open above its prerequisite's opening price.
func test_validator_rejects_broken_cost_curve() -> bool:
	var flat: Dictionary = _tiny_tree()
	(flat["nodes"][0] as Dictionary)["costs"] = [10, 10]
	var flat_hit: bool = false
	for issue: String in _issues(flat):
		flat_hit = flat_hit or issue.contains("strictly increasing")
	var shallow: Dictionary = _tiny_tree()
	(shallow["nodes"][1] as Dictionary)["costs"] = [5]  # cheaper than root's 10
	var shallow_hit: bool = false
	for issue: String in _issues(shallow):
		shallow_hit = shallow_hit or issue.contains("must exceed prerequisite")
	return flat_hit and shallow_hit


## N7-2 ownership: branch nodes must name a roster character, and edges must
## never cross between branches (they could not render on one tab).
func test_validator_rejects_bad_branch_ownership() -> bool:
	var unknown: Dictionary = _tiny_tree()
	(unknown["nodes"][2] as Dictionary)["character"] = "nobody"
	var unknown_hit: bool = false
	for issue: String in _issues(unknown):
		unknown_hit = unknown_hit or issue.contains("'nobody' not in characters.json")
	var cross: Dictionary = _tiny_tree()
	(cross["nodes"][2] as Dictionary)["requires"] = ["root"]  # taoist ← trunk
	var cross_hit: bool = false
	for issue: String in _issues(cross):
		cross_hit = cross_hit or issue.contains("different branch")
	return unknown_hit and cross_hit


func test_validator_rejects_duplicate_ids() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][1] as Dictionary)["id"] = "root"
	for issue: String in _issues(tree):
		if issue.contains("duplicate"):
			return true
	return false


func test_validator_rejects_cap_exceeded_by_reachable_total() -> bool:
	# warrior's branch + trunk attack_damage total 8% against a 6% cap: the
	# extra rank would be sold but do nothing — dead ranks must FAIL.
	var tree: Dictionary = _tiny_tree()
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary)["attack_damage"] = 0.06
	for issue: String in _issues(tree):
		if issue.contains("exceeds cap"):
			return true
	return false


## --- purchase validation ---------------------------------------------------


func test_purchase_spends_gold_and_raises_rank() -> bool:
	var before: Dictionary = _profile_with(30)
	var result: Dictionary = MetaTree.purchase(before, _tiny_tree(), "root", UNLOCKED)
	var after: Dictionary = result["profile"]
	return bool(result["ok"]) \
		and int(after["gold"]) == 20 \
		and MetaTree.rank_of(after["meta_tree"], "root") == 1 \
		and int(before["gold"]) == 30 \
		and (before["meta_tree"] as Dictionary).is_empty()  # input never mutated


func test_purchase_refused_without_enough_gold() -> bool:
	var before: Dictionary = _profile_with(9)
	var result: Dictionary = MetaTree.purchase(before, _tiny_tree(), "root", UNLOCKED)
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_GOLD \
		and result["profile"] == before  # no partial state, gold unchanged


func test_purchase_refused_while_prerequisite_unmet() -> bool:
	var result: Dictionary = MetaTree.purchase(
		_profile_with(999), _tiny_tree(), "branch", UNLOCKED
	)
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_LOCKED


## A locked character's branch is visible but never purchasable — even with
## gold, prerequisites met and the node known.
func test_purchase_refused_for_locked_character_branch() -> bool:
	var result: Dictionary = MetaTree.purchase(
		_profile_with(999), _tiny_tree(), "war_blade", UNLOCKED
	)
	var unlocked_ok: Dictionary = MetaTree.purchase(
		_profile_with(999), _tiny_tree(), "tao_burn", UNLOCKED
	)
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_CHARACTER \
		and bool(unlocked_ok["ok"])


func test_purchase_refused_at_max_rank() -> bool:
	var profile: Dictionary = _profile_with(999, {"root": 2})
	var result: Dictionary = MetaTree.purchase(profile, _tiny_tree(), "root", UNLOCKED)
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_MAXED \
		and int((result["profile"] as Dictionary)["gold"]) == 999


func test_purchase_refused_for_unknown_node() -> bool:
	var result: Dictionary = MetaTree.purchase(
		_profile_with(999), _tiny_tree(), "nope", UNLOCKED
	)
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_UNKNOWN


func test_next_rank_cost_scales_per_rank() -> bool:
	var root: Dictionary = MetaTree.node(_tiny_tree(), "root")
	return MetaTree.next_cost(root, 0) == 10 \
		and MetaTree.next_cost(root, 1) == 25 \
		and MetaTree.next_cost(root, 2) == MetaTree.NO_NEXT_COST


func test_prerequisite_satisfied_by_rank_one() -> bool:
	var tree: Dictionary = _tiny_tree()
	return not MetaTree.is_unlocked(tree, {}, "branch") \
		and MetaTree.is_unlocked(tree, {"root": 1}, "branch") \
		and MetaTree.locked_names(tree, {}, "branch", "ko") == ["뿌리" as String]


## --- corrupt state / aggregate ---------------------------------------------


func test_sanitize_drops_unknown_and_clamps_ranks() -> bool:
	var result: Dictionary = MetaTree.sanitize_state(_tiny_tree(), {
		"root": 99,        # above max — clamp to 2
		"branch": -1,      # negative — drop
		"ghost_node": 1,   # unknown (e.g. a node the N7-2 rework removed) — drop
	})
	var state: Dictionary = result["state"]
	return MetaTree.rank_of(state, "root") == 2 \
		and not state.has("branch") \
		and not state.has("ghost_node") \
		and int(result["dropped"]) == 3


func test_aggregate_two_ranks_is_exactly_double() -> bool:
	var tree: Dictionary = _tiny_tree()
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary)["max_hp"] = 1.0
	var one: Dictionary = MetaTree.aggregate_effects(tree, {"root": 1}, "taoist")
	var two: Dictionary = MetaTree.aggregate_effects(tree, {"root": 2}, "taoist")
	return is_equal_approx(float(one["max_hp"]), 0.05) \
		and is_equal_approx(float(two["max_hp"]), 0.10)


func test_aggregate_clamps_to_stat_cap() -> bool:
	# root at rank 2 would give +10% max_hp; the cap holds it at +8%.
	var effects: Dictionary = MetaTree.aggregate_effects(
		_tiny_tree(), {"root": 2}, "taoist"
	)
	return is_equal_approx(float(effects["max_hp"]), 0.08)


func test_aggregate_ignores_ranks_above_max() -> bool:
	# Even a corrupt rank that slipped past sanitizing never grants extra power.
	var tree: Dictionary = _tiny_tree()
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary)["max_hp"] = 1.0
	var effects: Dictionary = MetaTree.aggregate_effects(tree, {"root": 99}, "taoist")
	return is_equal_approx(float(effects["max_hp"]), 0.10)


## The no-leak rule: an owned taoist node contributes nothing to a warrior
## run, and vice versa — only the trunk is shared.
func test_aggregate_branch_never_leaks_between_characters() -> bool:
	var state: Dictionary = {"root": 1, "tao_burn": 1, "war_blade": 1}
	var taoist: Dictionary = MetaTree.aggregate_effects(_tiny_tree(), state, "taoist")
	var warrior: Dictionary = MetaTree.aggregate_effects(_tiny_tree(), state, "warrior")
	return is_equal_approx(float(taoist.get("burn_duration", 0.0)), 0.25) \
		and not taoist.has("attack_damage") \
		and is_equal_approx(float(warrior.get("attack_damage", 0.0)), 0.04) \
		and not warrior.has("burn_duration") \
		and is_equal_approx(float(taoist["max_hp"]), float(warrior["max_hp"]))


func test_maxed_state_maxes_every_node() -> bool:
	var tree: Dictionary = MetaTree.load_tree()
	var state: Dictionary = MetaTree.maxed_state(tree)
	for entry: Dictionary in MetaTree.nodes(tree):
		if MetaTree.rank_of(state, String(entry["id"])) != MetaTree.max_rank(entry):
			return false
	return true


## --- 술법 weapon-stat application -------------------------------------------


func test_weapon_stats_burn_chain_ward_orbit_seal() -> bool:
	var effects: Dictionary = {
		"burn_duration": 0.5, "chain_jumps": 2.0, "ward_radius": 0.24,
		"orbit_count": 1.0, "seal_burst": 1.0,
	}
	var burn: Dictionary = MetaTree.modified_weapon_stats(
		{"on_hit_status": {"id": "burn", "dps": 4.0, "duration_sec": 3.0}}, effects
	)
	var chain: Dictionary = MetaTree.modified_weapon_stats(
		{"chain": {"jumps": 3, "falloff": 0.7, "range_px": 150.0}}, effects
	)
	var ward: Dictionary = MetaTree.modified_weapon_stats(
		{"ward": {"radius_px": 100.0, "duration_sec": 3.5}}, effects
	)
	var orbit: Dictionary = MetaTree.modified_weapon_stats(
		{"mechanic": "orbit", "projectile_count": 3}, effects
	)
	var seal: Dictionary = MetaTree.modified_weapon_stats(
		{"on_hit_seal": {"burst_at": 4, "burst_damage_scale": 3.0}}, effects
	)
	return is_equal_approx(
			float((burn["on_hit_status"] as Dictionary)["duration_sec"]), 4.5
		) \
		and int((chain["chain"] as Dictionary)["jumps"]) == 5 \
		and is_equal_approx(float((ward["ward"] as Dictionary)["radius_px"]), 124.0) \
		and int(orbit["projectile_count"]) == 4 \
		and int((seal["on_hit_seal"] as Dictionary)["burst_at"]) == 3


func test_weapon_stats_seal_never_drops_below_floor() -> bool:
	var eased: Dictionary = MetaTree.modified_weapon_stats(
		{"on_hit_seal": {"burst_at": 2, "burst_damage_scale": 3.0}},
		{"seal_burst": 5.0}
	)
	return int((eased["on_hit_seal"] as Dictionary)["burst_at"]) == MetaTree.MIN_SEAL_BURST


func test_weapon_stats_untouched_without_matching_block() -> bool:
	# A straight-throw weapon gains nothing from any 술법 node; shock (not
	# burn) statuses keep their duration.
	var stats: Dictionary = {
		"mechanic": "straight", "damage": 15.0,
		"on_hit_status": {"id": "shock", "slow_scale": 0.55, "duration_sec": 1.5},
	}
	var result: Dictionary = MetaTree.modified_weapon_stats(stats, {
		"burn_duration": 0.5, "chain_jumps": 2.0, "orbit_count": 1.0,
	})
	return result == stats


func test_weapon_stats_input_never_mutated() -> bool:
	var stats: Dictionary = {"chain": {"jumps": 3}}
	MetaTree.modified_weapon_stats(stats, {"chain_jumps": 1.0})
	return int((stats["chain"] as Dictionary)["jumps"]) == 3


## --- screen ----------------------------------------------------------------


func test_screen_builds_with_tabs_and_cta_follows_selection() -> bool:
	var screen: MetaTreeScreen = (load(META_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	var passed: bool = screen.find_child("GoldValue", true, false) != null
	passed = passed and screen.find_child("Node_coin_eye", true, false) != null
	# One tab per roster character plus the shared trunk.
	passed = passed and screen.find_child("Tab_shared", true, false) != null \
		and screen.find_child("Tab_taoist", true, false) != null \
		and screen.find_child("Tab_warrior", true, false) != null \
		and screen.find_child("Tab_archer", true, false) != null
	var cta: Button = screen.find_child("CtaButton", true, false)
	# No selection: the CTA is hidden, never a dead greyed button.
	passed = passed and cta != null and not cta.visible
	# Selecting an affordable-shape node shows the CTA (broke profile → 부족).
	screen.select_node("coin_eye")
	passed = passed and cta.visible
	# A locked node hides the CTA and names its requirement in the card.
	# N11-14 rewired the trunk for breadth: 부적 연마 is a root now, 돌가죽
	# is the node still gated behind 철골.
	screen.select_node("ledger_eye")
	var effect_label: Label = screen.find_child("DetailEffect", true, false)
	passed = passed and not cta.visible \
		and effect_label != null and effect_label.text.contains("엽전 눈")
	if not passed:
		push_error("test_meta_tree: screen structure or CTA state wrong")
	screen.free()
	return passed


func test_screen_branch_tabs_switch_and_lock() -> bool:
	var screen: MetaTreeScreen = (load(META_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	# Selecting a taoist-branch node lands on the taoist tab with the node
	# built; the trunk's nodes are torn down.
	screen.select_node("burn_mastery")
	var passed: bool = screen._current_tab == "taoist" \
		and screen._node_buttons.has("burn_mastery") \
		and not screen._node_buttons.has("coin_eye")
	var cta: Button = screen.find_child("CtaButton", true, false)
	passed = passed and cta.visible
	# A locked character's branch: node visible, CTA hidden, and the reason
	# NAMED — whatever it says. N9-73 changed that text from a promise nothing
	# could keep ("earn 도깨비 사냥꾼") to the truth ("not built yet"), so the
	# rule under test is that a locked branch explains itself, not the wording.
	screen.select_node("iron_stance")
	var info_label: Label = screen.find_child("DetailInfo", true, false)
	passed = passed and screen._current_tab == "warrior" \
		and screen._node_buttons.has("iron_stance") \
		and not cta.visible \
		and info_label != null and not info_label.text.is_empty()
	# Even a forced CTA press on a locked branch buys nothing.
	screen._profile["gold"] = 99999
	screen._selected_id = "iron_stance"
	screen._on_cta_pressed()
	passed = passed and int(screen._profile["gold"]) == 99999 \
		and (screen._profile["meta_tree"] as Dictionary).is_empty()
	if not passed:
		push_error("test_meta_tree: branch tab behaviour wrong")
	screen.free()
	return passed


func test_screen_cta_refuses_purchase_without_gold() -> bool:
	# Node-free purchase path (no SaveService): tap the CTA with zero gold —
	# gold and rank must not move (edge #1).
	var screen: MetaTreeScreen = (load(META_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	screen.select_node("coin_eye")
	screen._on_cta_pressed()
	var passed: bool = int(screen._profile["gold"]) == 0 \
		and (screen._profile["meta_tree"] as Dictionary).is_empty()
	# With gold, the same tap buys rank 1 and the pill reflects the spend —
	# expected remainder derives from data so a cost retune cannot break this.
	var rank_cost: int = MetaTree.next_cost(MetaTree.node(MetaTree.load_tree(), "coin_eye"), 0)
	screen._profile["gold"] = 100
	screen._on_cta_pressed()
	passed = passed and int(screen._profile["gold"]) == 100 - rank_cost \
		and MetaTree.rank_of(screen._profile["meta_tree"], "coin_eye") == 1
	# Deselect: the CTA can never act on a stale selection (edge #13).
	screen._on_canvas_input(_click())
	screen._on_cta_pressed()
	passed = passed and int(screen._profile["gold"]) == 100 - rank_cost
	if not passed:
		push_error("test_meta_tree: screen purchase flow leaked state")
	screen.free()
	return passed


static func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## N9-162: a rank with a material bill refuses without the goods, spends them
## atomically with the gold, and leaves the input profile untouched.
func test_material_bill_gates_and_spends() -> bool:
	var tree: Dictionary = {"config": {}, "nodes": [{
		"id": "forge", "name_ko": "벼림", "effect": {"stat": "attack_damage", "per_rank": 0.01},
		"costs": [100, 200], "materials": {"bamboo": [2, 4]}, "requires": [],
	}]}
	var broke: Dictionary = {"gold": 500, "materials": {"bamboo": 1}, "meta_tree": {}}
	var refused: Dictionary = MetaTree.purchase(broke, tree, "forge", [])
	var passed: bool = not bool(refused["ok"]) 		and String(refused["reason"]) == MetaTree.REASON_MATERIALS
	var rich: Dictionary = {"gold": 500, "materials": {"bamboo": 5}, "meta_tree": {}}
	var bought: Dictionary = MetaTree.purchase(rich, tree, "forge", [])
	passed = passed and bool(bought["ok"])
	var next: Dictionary = bought["profile"]
	passed = passed and int(next["gold"]) == 400 		and int((next["materials"] as Dictionary)["bamboo"]) == 3
	# the input profile is never mutated
	passed = passed and int(rich["gold"]) == 500 		and int((rich["materials"] as Dictionary)["bamboo"]) == 5
	if not passed:
		push_error("test_meta_tree: material bill gating/spending broke")
	return passed

## N11-3b: cheapest_next is what the result screen sells — every exclusion
## branch gets a case (gold-only reachability is the contract).
func test_cheapest_next_picks_the_cheapest_reachable_rank() -> bool:
	# Fresh state, broke: root(10) is cheaper than tao_burn(30); the locked
	# branch (requires root) and the warrior's node must not compete.
	var best: Dictionary = MetaTree.cheapest_next(_tiny_tree(), {}, 0, UNLOCKED)
	return (
		String(best.get("id", "")) == "root"
		and int(best.get("cost", 0)) == 10
		and int(best.get("gap", 0)) == 10
	)


func test_cheapest_next_gap_is_zero_when_affordable() -> bool:
	var best: Dictionary = MetaTree.cheapest_next(_tiny_tree(), {}, 50, UNLOCKED)
	return String(best.get("id", "")) == "root" and int(best.get("gap", -1)) == 0


func test_cheapest_next_skips_locked_and_foreign_branches() -> bool:
	# root maxed: branch unlocks (20) and beats tao_burn (30); the warrior's
	# 30-cost node must never appear while the warrior is locked.
	var state := {"root": 2}
	var best: Dictionary = MetaTree.cheapest_next(_tiny_tree(), state, 0, UNLOCKED)
	return String(best.get("id", "")) == "branch" and int(best.get("gap", 0)) == 20


func test_cheapest_next_excludes_material_billed_nodes_until_stocked() -> bool:
	var tree: Dictionary = _tiny_tree()
	# Make the cheap root demand a material the pouch lacks.
	(tree["nodes"][0] as Dictionary)["materials"] = {"fire_stone": [1, 1]}
	var broke: Dictionary = MetaTree.cheapest_next(tree, {}, 0, UNLOCKED, {})
	var stocked: Dictionary = MetaTree.cheapest_next(
		tree, {}, 0, UNLOCKED, {"fire_stone": 1}
	)
	# Without the stone the next ding is tao_burn; with it, root returns.
	return (
		String(broke.get("id", "")) == "tao_burn"
		and String(stocked.get("id", "")) == "root"
	)


func test_cheapest_next_empty_when_everything_is_maxed() -> bool:
	var state := {"root": 2, "branch": 1, "tao_burn": 1}
	return MetaTree.cheapest_next(_tiny_tree(), state, 9999, UNLOCKED).is_empty()



func test_refund_removed_pays_back_and_drops_the_ranks() -> bool:
	# N11-18: the redesign removed 49 nodes; a profile holding their ranks gets
	# the exact coins back, once, and the dead ids leave the state.
	var tree := {
		"config": {"_removed_refunds": {"gone_node": [100, 250], "other_gone": [80]}},
		"nodes": [],
	}
	var profile: Dictionary = SaveProfile.default_profile()
	profile["gold"] = 40
	profile["meta_tree"] = {"gone_node": 2, "other_gone": 1, "kept_node": 3}
	var result: Dictionary = MetaTree.refund_removed(profile, tree)
	var next: Dictionary = result["profile"]
	if int(result["refunded"]) != 430 or int(next["gold"]) != 470:
		push_error("test_meta_tree: refund must pay 100+250+80 into the purse")
		return false
	var state: Dictionary = next["meta_tree"]
	if state.has("gone_node") or state.has("other_gone") or int(state["kept_node"]) != 3:
		push_error("test_meta_tree: refunded ids must leave, kept ids must stay")
		return false
	# Second pass finds nothing — the ranks are already gone.
	return int(MetaTree.refund_removed(next, tree)["refunded"]) == 0


func test_salvage_leftovers_sells_a_share_of_the_pouch() -> bool:
	# N11-19 환전꾼: the rate sells whole units only, pays the loot's own
	# salvage_gold, and takes what it sold out of the pouch.
	var loot := {
		"bamboo": {"salvage_gold": 5},
		"ghost_iron": {"salvage_gold": 10},
	}
	var result: Dictionary = MetaTree.salvage_leftovers(
		{"bamboo": 10, "ghost_iron": 3}, loot, 0.3
	)
	var pouch: Dictionary = result["pouch"]
	# bamboo: 3 sold x 5 = 15, ghost_iron: floor(0.9) = 0 sold.
	if int(result["coins"]) != 15 or int(pouch["bamboo"]) != 7:
		push_error("test_meta_tree: salvage must sell whole units at loot value")
		return false
	if int(pouch["ghost_iron"]) != 3:
		push_error("test_meta_tree: a pouch too small to round up must keep it all")
		return false
	# N11-20 self-check: what the camp still owes is NOT sold. 8 of the 10
	# bamboo are spoken for, so only the 2 spare ones can be traded, and 30%
	# of 2 rounds down to nothing.
	var spared: Dictionary = MetaTree.salvage_leftovers(
		{"bamboo": 10}, loot, 0.3, {"bamboo": 8}
	)
	if int(spared["coins"]) != 0 or int((spared["pouch"] as Dictionary)["bamboo"]) != 10:
		push_error("test_meta_tree: salvage must not sell what the camp still bills")
		return false
	# No rate, no trade.
	return int(MetaTree.salvage_leftovers({"bamboo": 10}, loot, 0.0)["coins"]) == 0


func test_archer_effects_fold_into_weapon_stats() -> bool:
	# N11-19c: 꿰뚫는 달 pushes pierce retention ABOVE 1.0 so a shot grows as
	# it pierces, and 원격 hands the projectile its distance bonus.
	var stats := {"pierce": 2, "pierce_retention": 0.7, "mechanic": "pierce"}
	var grown: Dictionary = MetaTree.modified_weapon_stats(
		stats, {"pierce_growth": 0.45, "range_damage": 0.16}
	)
	if not is_equal_approx(float(grown["pierce_retention"]), 1.15):
		push_error("test_meta_tree: pierce growth must add to retention")
		return false
	if not is_equal_approx(float(grown["range_damage"]), 0.16):
		push_error("test_meta_tree: range damage must reach the weapon stats")
		return false
	# A weapon with no pierce is untouched by the growth.
	var plain: Dictionary = MetaTree.modified_weapon_stats(
		{"mechanic": "orbit"}, {"pierce_growth": 0.45}
	)
	return not plain.has("pierce_retention")


func test_family_upgrades_only_touch_their_own_build() -> bool:
	# N11-20b (owner: 무기를 업그레이드 하는 걸 얘기한 거였어): a fire branch
	# sharpens fire weapons and leaves the lightning ones exactly as they were.
	var tree := {"nodes": [
		{"id": "build_fire_might", "build_family": "fire", "character": "taoist",
			"effect": {"stat": "family_damage", "per_rank": 0.1}, "costs": [100, 200]},
		{"id": "build_fire_tempo", "build_family": "fire", "character": "taoist",
			"effect": {"stat": "family_haste", "per_rank": 0.06}, "costs": [100]},
		{"id": "build_lightning_might", "build_family": "lightning", "character": "taoist",
			"effect": {"stat": "family_damage", "per_rank": 0.1}, "costs": [100]},
	]}
	var totals: Dictionary = MetaTree.family_effects(
		tree, {"build_fire_might": 2, "build_fire_tempo": 1}, "taoist"
	)
	if not is_equal_approx(float((totals["fire"] as Dictionary)["family_damage"]), 0.2):
		push_error("test_meta_tree: two ranks of a family node must stack")
		return false
	if totals.has("lightning"):
		push_error("test_meta_tree: an unbought family must contribute nothing")
		return false
	var fire: Dictionary = MetaTree.apply_family_upgrades(
		{"family": "fire", "damage": 100.0, "cooldown_sec": 1.0}, totals
	)
	var bolt: Dictionary = MetaTree.apply_family_upgrades(
		{"family": "lightning", "damage": 100.0, "cooldown_sec": 1.0}, totals
	)
	if not is_equal_approx(float(fire["damage"]), 120.0) \
			or not is_equal_approx(float(fire["cooldown_sec"]), 0.94):
		push_error("test_meta_tree: the fire weapon must take both upgrades")
		return false
	return is_equal_approx(float(bolt["damage"]), 100.0)
