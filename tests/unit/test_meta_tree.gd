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
	var passed: bool = screen.get_node_or_null(
		"Layout/Column/Header/GoldPill/PillRow/GoldValue"
	) != null
	passed = passed and screen.get_node_or_null(
		"Layout/Column/Scroll/Canvas/Node_iron_bones"
	) != null
	# One tab per roster character plus the shared trunk.
	passed = passed and screen.get_node_or_null("Layout/Column/Tabs/Tab_shared") != null \
		and screen.get_node_or_null("Layout/Column/Tabs/Tab_taoist") != null \
		and screen.get_node_or_null("Layout/Column/Tabs/Tab_warrior") != null \
		and screen.get_node_or_null("Layout/Column/Tabs/Tab_archer") != null
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


func test_screen_branch_tabs_switch_and_lock() -> bool:
	var screen: MetaTreeScreen = (load(META_SCENE) as PackedScene).instantiate()
	screen.build_ui()
	# Selecting a taoist-branch node lands on the taoist tab with the node
	# built; the trunk's nodes are torn down.
	screen.select_node("burn_mastery")
	var passed: bool = screen._current_tab == "taoist" \
		and screen._node_buttons.has("burn_mastery") \
		and not screen._node_buttons.has("iron_bones")
	var cta: Button = screen.get_node_or_null("Layout/Column/CtaButton")
	passed = passed and cta.visible
	# A locked character's branch: node visible, CTA hidden, and the reason
	# NAMED — whatever it says. N9-73 changed that text from a promise nothing
	# could keep ("earn 도깨비 사냥꾼") to the truth ("not built yet"), so the
	# rule under test is that a locked branch explains itself, not the wording.
	screen.select_node("hwando_hone")
	var info_label: Label = screen.get_node_or_null(
		"Layout/Column/DetailCard/DetailRow/DetailLines/DetailInfo"
	)
	passed = passed and screen._current_tab == "warrior" \
		and screen._node_buttons.has("hwando_hone") \
		and not cta.visible \
		and info_label != null and not info_label.text.is_empty()
	# Even a forced CTA press on a locked branch buys nothing.
	screen._profile["gold"] = 99999
	screen._selected_id = "hwando_hone"
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
	screen.select_node("iron_bones")
	screen._on_cta_pressed()
	var passed: bool = int(screen._profile["gold"]) == 0 \
		and (screen._profile["meta_tree"] as Dictionary).is_empty()
	# With gold, the same tap buys rank 1 and the pill reflects the spend —
	# expected remainder derives from data so a cost retune cannot break this.
	var rank_cost: int = MetaTree.next_cost(MetaTree.node(MetaTree.load_tree(), "iron_bones"), 0)
	screen._profile["gold"] = 100
	screen._on_cta_pressed()
	passed = passed and int(screen._profile["gold"]) == 100 - rank_cost \
		and MetaTree.rank_of(screen._profile["meta_tree"], "iron_bones") == 1
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
