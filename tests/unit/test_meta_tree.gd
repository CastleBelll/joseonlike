extends RefCounted
## Guards the N7-1 명부수 meta tree: the data contract (cycles, unknown
## stats, costs, duplicates), purchase validation across every edge case,
## corrupt-state sanitizing, the capped run-start aggregate and the screen's
## CTA/selection behaviour.

const META_SCENE := "res://scenes/meta_tree.tscn"


## Two-node synthetic tree: root (max_hp 5%/rank, 2 ranks) → branch
## (attack_damage 4%, 1 rank). Caps deliberately BELOW the achievable total
## on max_hp so the clamp is observable.
static func _tiny_tree() -> Dictionary:
	return {
		"config": {"stat_caps": {"max_hp": 0.08, "attack_damage": 0.06}},
		"nodes": [
			{
				"id": "root", "name_ko": "뿌리", "name_en": "Root",
				"icon": "tough_fiber",
				"effect": {"stat": "max_hp", "per_rank": 0.05},
				"costs": [10, 25], "requires": [], "pos": [0.3, 0],
			},
			{
				"id": "branch", "name_ko": "가지", "name_en": "Branch",
				"icon": "whetstone",
				"effect": {"stat": "attack_damage", "per_rank": 0.04},
				"costs": [20], "requires": ["root"], "pos": [0.7, 1],
			},
		],
	}


static func _profile_with(gold: int, state: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = SaveProfile.default_profile()
	profile["gold"] = gold
	profile["meta_tree"] = state
	return profile


## --- data contract ---------------------------------------------------------


func test_shipped_tree_data_is_valid() -> bool:
	var tree: Dictionary = MetaTree.load_tree()
	var issues: Array[String] = MetaTree.data_issues(tree)
	if not issues.is_empty():
		push_error("test_meta_tree: shipped tree invalid: " + str(issues))
		return false
	return MetaTree.nodes(tree).size() >= 6


func test_validator_rejects_unknown_effect_stat() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][0]["effect"] as Dictionary)["stat"] = "not_a_stat"
	for issue: String in MetaTree.data_issues(tree):
		if issue.contains("not_a_stat"):
			return true
	return false


func test_validator_rejects_dependency_cycle() -> bool:
	var tree: Dictionary = _tiny_tree()
	# root ⇄ branch: a cycle no purchase order can ever satisfy.
	(tree["nodes"][0] as Dictionary)["requires"] = ["branch"]
	for issue: String in MetaTree.data_issues(tree):
		if issue.contains("cycle"):
			return true
	return false


func test_validator_rejects_missing_prerequisite() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][1] as Dictionary)["requires"] = ["ghost_node"]
	for issue: String in MetaTree.data_issues(tree):
		if issue.contains("ghost_node"):
			return true
	return false


func test_validator_rejects_bad_costs_and_missing_cap() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][0] as Dictionary)["costs"] = [0]        # non-positive cost
	(tree["nodes"][1] as Dictionary)["costs"] = []         # max_rank < 1
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary).erase("attack_damage")
	var issues: Array[String] = MetaTree.data_issues(tree)
	var bad_cost: bool = false
	var empty_costs: bool = false
	var missing_cap: bool = false
	for issue: String in issues:
		bad_cost = bad_cost or issue.contains("non-positive cost")
		empty_costs = empty_costs or issue.contains("costs empty")
		missing_cap = missing_cap or issue.contains("stat_caps.attack_damage")
	return bad_cost and empty_costs and missing_cap


func test_validator_rejects_duplicate_ids() -> bool:
	var tree: Dictionary = _tiny_tree()
	(tree["nodes"][1] as Dictionary)["id"] = "root"
	for issue: String in MetaTree.data_issues(tree):
		if issue.contains("duplicate"):
			return true
	return false


## --- purchase validation ---------------------------------------------------


func test_purchase_spends_gold_and_raises_rank() -> bool:
	var before: Dictionary = _profile_with(30)
	var result: Dictionary = MetaTree.purchase(before, _tiny_tree(), "root")
	var after: Dictionary = result["profile"]
	return bool(result["ok"]) \
		and int(after["gold"]) == 20 \
		and MetaTree.rank_of(after["meta_tree"], "root") == 1 \
		and int(before["gold"]) == 30 \
		and (before["meta_tree"] as Dictionary).is_empty()  # input never mutated


func test_purchase_refused_without_enough_gold() -> bool:
	var before: Dictionary = _profile_with(9)
	var result: Dictionary = MetaTree.purchase(before, _tiny_tree(), "root")
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_GOLD \
		and result["profile"] == before  # no partial state, gold unchanged


func test_purchase_refused_while_prerequisite_unmet() -> bool:
	var result: Dictionary = MetaTree.purchase(_profile_with(999), _tiny_tree(), "branch")
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_LOCKED


func test_purchase_refused_at_max_rank() -> bool:
	var profile: Dictionary = _profile_with(999, {"root": 2})
	var result: Dictionary = MetaTree.purchase(profile, _tiny_tree(), "root")
	return not bool(result["ok"]) \
		and String(result["reason"]) == MetaTree.REASON_MAXED \
		and int((result["profile"] as Dictionary)["gold"]) == 999


func test_purchase_refused_for_unknown_node() -> bool:
	var result: Dictionary = MetaTree.purchase(_profile_with(999), _tiny_tree(), "nope")
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
		"ghost_node": 1,   # unknown — drop
	})
	var state: Dictionary = result["state"]
	return MetaTree.rank_of(state, "root") == 2 \
		and not state.has("branch") \
		and not state.has("ghost_node") \
		and int(result["dropped"]) == 3


func test_aggregate_two_ranks_is_exactly_double() -> bool:
	var tree: Dictionary = _tiny_tree()
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary)["max_hp"] = 1.0
	var one: Dictionary = MetaTree.aggregate_effects(tree, {"root": 1})
	var two: Dictionary = MetaTree.aggregate_effects(tree, {"root": 2})
	return is_equal_approx(float(one["max_hp"]), 0.05) \
		and is_equal_approx(float(two["max_hp"]), 0.10)


func test_aggregate_clamps_to_stat_cap() -> bool:
	# root at rank 2 would give +10% max_hp; the cap holds it at +8%.
	var effects: Dictionary = MetaTree.aggregate_effects(_tiny_tree(), {"root": 2})
	return is_equal_approx(float(effects["max_hp"]), 0.08)


func test_aggregate_ignores_ranks_above_max() -> bool:
	# Even a corrupt rank that slipped past sanitizing never grants extra power.
	var tree: Dictionary = _tiny_tree()
	((tree["config"] as Dictionary)["stat_caps"] as Dictionary)["max_hp"] = 1.0
	var effects: Dictionary = MetaTree.aggregate_effects(tree, {"root": 99})
	return is_equal_approx(float(effects["max_hp"]), 0.10)


func test_maxed_state_maxes_every_node() -> bool:
	var tree: Dictionary = MetaTree.load_tree()
	var state: Dictionary = MetaTree.maxed_state(tree)
	for entry: Dictionary in MetaTree.nodes(tree):
		if MetaTree.rank_of(state, String(entry["id"])) != MetaTree.max_rank(entry):
			return false
	return true


## --- screen ----------------------------------------------------------------


func test_screen_builds_and_cta_follows_selection() -> bool:
	var screen: MetaTreeScreen = (load(META_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	var passed: bool = screen.get_node_or_null(
		"Layout/Column/Header/GoldPill/PillRow/GoldValue"
	) != null
	passed = passed and screen.get_node_or_null(
		"Layout/Column/Scroll/Canvas/Node_iron_bones"
	) != null
	var cta: Button = screen.get_node_or_null("Layout/Column/CtaButton")
	# No selection: the CTA is hidden, never a dead greyed button.
	passed = passed and cta != null and not cta.visible
	# Selecting an affordable-shape node shows the CTA (broke profile → 부족).
	screen.select_node("iron_bones")
	passed = passed and cta.visible
	# A locked node hides the CTA and names its requirement in the card.
	screen.select_node("sharp_talisman")
	var effect_label: Label = screen.get_node_or_null(
		"Layout/Column/DetailCard/DetailRow/DetailLines/DetailEffect"
	)
	passed = passed and not cta.visible \
		and effect_label != null and effect_label.text.contains("철골")
	if not passed:
		push_error("test_meta_tree: screen structure or CTA state wrong")
	screen.free()
	return passed


func test_screen_cta_refuses_purchase_without_gold() -> bool:
	# Node-free purchase path (no SaveService): tap the CTA with zero gold —
	# gold and rank must not move (edge #1).
	var screen: MetaTreeScreen = (load(META_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	screen.select_node("iron_bones")
	screen._on_cta_pressed()
	var passed: bool = int(screen._profile["gold"]) == 0 \
		and (screen._profile["meta_tree"] as Dictionary).is_empty()
	# With gold, the same tap buys rank 1 and the pill reflects the spend.
	screen._profile["gold"] = 100
	screen._on_cta_pressed()
	passed = passed and int(screen._profile["gold"]) == 70 \
		and MetaTree.rank_of(screen._profile["meta_tree"], "iron_bones") == 1
	# Deselect: the CTA can never act on a stale selection (edge #13).
	screen._on_canvas_input(_click())
	screen._on_cta_pressed()
	passed = passed and int(screen._profile["gold"]) == 70
	if not passed:
		push_error("test_meta_tree: screen purchase flow leaked state")
	screen.free()
	return passed


static func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
