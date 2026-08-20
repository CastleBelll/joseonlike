extends RefCounted
## N9-88: the five mechanic-reshaping passives, and the guard that keeps a
## passive from ever being offerable-but-inert again.
##
## 도력, 광역 확장, 불씨 정통, 연쇄 확장 and 봉인 가속 sat in passives.json
## for months looking implemented — data complete, names localized, per_stack
## tuned — while Stage never read them. Nothing failed because nothing offered
## them. Now they are offered, so their effects have to be real.

const STAGE_PATH := "res://scripts/combat/stage.gd"

## A weapon carrying every block the new effect keys touch.
const SAMPLE_STATS := {
	"mechanic": "explosion",
	"explosion": {"radius_px": 100.0},
	"ward": {"radius_px": 80.0},
	"shockwave": {"radius_px": 120.0},
	"chain": {"jumps": 2, "range_px": 150.0},
	"on_hit_status": {"id": "burn", "dps": 10.0, "duration_sec": 3.0},
	"on_hit_seal": {"burst_at": 5},
}


func test_burn_dps_scales_only_burn() -> bool:
	var burned: Dictionary = MetaTree.modified_weapon_stats(
		SAMPLE_STATS, {"burn_dps": 0.6}
	)
	var shocked: Dictionary = SAMPLE_STATS.duplicate(true)
	(shocked["on_hit_status"] as Dictionary)["id"] = "shock"
	var untouched: Dictionary = MetaTree.modified_weapon_stats(
		shocked, {"burn_dps": 0.6}
	)
	return (
		is_equal_approx(float((burned["on_hit_status"] as Dictionary)["dps"]), 16.0)
		and is_equal_approx(float((untouched["on_hit_status"] as Dictionary)["dps"]), 10.0)
	)


func test_area_radius_scales_the_area_blocks_and_nothing_else() -> bool:
	var scaled: Dictionary = MetaTree.modified_weapon_stats(
		SAMPLE_STATS, {"area_radius": 0.25}
	)
	return (
		is_equal_approx(float((scaled["explosion"] as Dictionary)["radius_px"]), 125.0)
		and is_equal_approx(float((scaled["ward"] as Dictionary)["radius_px"]), 100.0)
		and is_equal_approx(float((scaled["shockwave"] as Dictionary)["radius_px"]), 150.0)
		# A chain's reach has its own passive; area must not double-dip it.
		and is_equal_approx(float((scaled["chain"] as Dictionary)["range_px"]), 150.0)
	)


## The two keys the meta tree already used, driven from the passive side:
## the fold is one function, so both suppliers must see the same arithmetic.
func test_chain_and_seal_reuse_the_meta_fold() -> bool:
	var reshaped: Dictionary = MetaTree.modified_weapon_stats(
		SAMPLE_STATS, {"chain_jumps": 2.0, "seal_burst": 2.0}
	)
	return (
		int((reshaped["chain"] as Dictionary)["jumps"]) == 4
		and int((reshaped["on_hit_seal"] as Dictionary)["burst_at"]) == 3
	)


## burst_at can never fall through the floor — a seal that burst at zero
## stacks would fire on every hit.
func test_seal_haste_respects_the_floor() -> bool:
	var reshaped: Dictionary = MetaTree.modified_weapon_stats(
		SAMPLE_STATS, {"seal_burst": 99.0}
	)
	return int((reshaped["on_hit_seal"] as Dictionary)["burst_at"]) == MetaTree.MIN_SEAL_BURST


## The fold must never corrupt its input: pooled weapons recompute on every
## level-up, and an in-place mutation would compound each time.
func test_the_fold_leaves_the_input_untouched() -> bool:
	var input: Dictionary = SAMPLE_STATS.duplicate(true)
	MetaTree.modified_weapon_stats(input, {
		"burn_dps": 1.0, "area_radius": 1.0, "chain_jumps": 5.0, "seal_burst": 5.0
	})
	return (
		is_equal_approx(float((input["explosion"] as Dictionary)["radius_px"]), 100.0)
		and is_equal_approx(float((input["on_hit_status"] as Dictionary)["dps"]), 10.0)
		and int((input["chain"] as Dictionary)["jumps"]) == 2
		and int((input["on_hit_seal"] as Dictionary)["burst_at"]) == 5
	)


## The trap-closer: every passive the level-up screen may offer must be read
## by the stage. Checked against the SOURCE, because a passive consumed only
## in a branch no test happens to reach is still consumed — and one consumed
## nowhere is a card that does nothing no matter what runs.
##
## Two accepted shapes: the `_passive_bonus("<id>")` scalar path that most
## stats use, or the id quoted anywhere else in stage.gd — max_hp is granted
## at pick time through `_passives_data.get("max_hp")` rather than as a
## per-frame bonus, and that is consumption too.
func test_offerable_passives_are_consumed() -> bool:
	var source: String = FileAccess.get_file_as_string(STAGE_PATH)
	var passed: bool = true
	for passive_id: String in LevelUp.OFFERABLE_PASSIVES:
		var scalar_read: bool = source.contains('_passive_bonus("%s")' % passive_id)
		var any_read: bool = source.contains('"%s"' % passive_id)
		if not (scalar_read or any_read):
			push_error(
				"test_field_passives: '%s' is offerable but stage.gd never reads it"
				% passive_id
			)
			passed = false
	return passed
