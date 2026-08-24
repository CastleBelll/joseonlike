extends RefCounted
## Guards the N5-3 base camp: routing from profile state, the summary
## view-model over the save profile, building placeholder resolution and the
## camp screen construction.

const CAMP_SCENE := "res://scenes/camp.tscn"


static func _returning_profile() -> Dictionary:
	var profile: Dictionary = SaveProfile.default_profile()
	return SaveProfile.apply_run_result(profile, 213.0, 87, 450, true)


func test_first_boot_routes_straight_to_stage() -> bool:
	# GDD §28: a brand new profile never sees camp before its first run.
	var fresh: Dictionary = SaveProfile.default_profile()
	if Camp.destination_after_title(fresh) != Camp.DEST_STAGE:
		push_error("test_camp: fresh profile must skip camp")
		return false
	return Camp.destination_after_select_exit(fresh) == Camp.DEST_TITLE


func test_mid_tutorial_quit_routes_to_camp() -> bool:
	# N9-104 (owner: quitting mid-tutorial re-skipped the camp): a sortie that
	# STARTED but never finished must land the next launch in camp, while the
	# tutorial content itself stays armed (is_first_run still true).
	var quit_early: Dictionary = Ftue.mark_first_sortie_started(SaveProfile.default_profile())
	if Camp.destination_after_title(quit_early) != Camp.DEST_CAMP:
		push_error("test_camp: a started-but-unfinished tutorial must route to camp")
		return false
	if not Ftue.is_first_run(quit_early):
		push_error("test_camp: an unfinished tutorial must still count as the first run")
		return false
	return Camp.destination_after_select_exit(quit_early) == Camp.DEST_CAMP


func test_returning_profile_routes_to_camp() -> bool:
	var returning: Dictionary = _returning_profile()
	if Camp.destination_after_title(returning) != Camp.DEST_CAMP:
		push_error("test_camp: returning profile must land in camp")
		return false
	return Camp.destination_after_select_exit(returning) == Camp.DEST_CAMP


func test_summary_reads_profile_state() -> bool:
	var summary: Dictionary = Camp.summary(_returning_profile())
	var passed: bool = int(summary["gold"]) == 450
	passed = passed and int(summary["runs_played"]) == 1
	passed = passed and String(summary["best_time_text"]) == "3:33"
	passed = passed and int(summary["best_kills"]) == 87
	passed = passed and int(summary["bosses_killed"]) == 1
	if not passed:
		push_error("test_camp: summary does not mirror the profile")
	return passed


func test_summary_tolerates_missing_sections() -> bool:
	# A hand-edited or pre-migration dict must never crash the camp screen.
	var summary: Dictionary = Camp.summary({})
	return int(summary["gold"]) == 0 and int(summary["runs_played"]) == 0 \
		and String(summary["best_time_text"]) == "0:00"


func test_buildings_roster_and_meta_routing() -> bool:
	var buildings: Array[Dictionary] = Camp.buildings()
	if buildings.size() != 6:
		push_error("test_camp: expected 6 GDD building spots (incl. 명부수)")
		return false
	# Buildings with a landed screen route to it instead of talking
	# (명부수 N7-1, 괴이록 N5-4, 해금 N9-58); the rest stay 준비 중 placeholders.
	var routed: Dictionary = {
		"meta": "res://scenes/meta_tree.tscn",
		"bestiary": "res://scenes/bestiary.tscn",
		"achievements": "res://scenes/achievements.tscn",
	}
	# N9-150: 지역 선택 acts in place — ready, but it cycles the departure
	# region inside the camp instead of routing to a scene.
	var in_place: Array[String] = ["region_select"]
	for building: Dictionary in buildings:
		if String(building["label"]).is_empty():
			push_error("test_camp: building must be labelled")
			return false
		if in_place.has(String(building["id"])):
			if not bool(building["ready"]) or not Camp.building_scene(building).is_empty():
				push_error("test_camp: in-place building must be ready and route nowhere")
				return false
			continue
		if routed.has(String(building["id"])):
			if Camp.building_notice(building) != "" \
					or Camp.building_scene(building) != String(routed[building["id"]]):
				push_error("test_camp: routed building must open its scene")
				return false
			# A route to a scene that is not in the build is a dead end that
			# only shows up when someone taps it.
			if not ResourceLoader.exists(Camp.building_scene(building)):
				push_error("test_camp: routed scene missing: " + Camp.building_scene(building))
				return false
			continue
		if bool(building["ready"]) \
				or Camp.building_notice(building) != Camp.NOT_READY_NOTICE:
			push_error("test_camp: placeholder building must answer 준비 중")
			return false
		if not Camp.building_scene(building).is_empty():
			push_error("test_camp: placeholder building must not route")
			return false
	return true


func test_camp_screen_builds() -> bool:
	var scene: PackedScene = load(CAMP_SCENE)
	var camp: CampScreen = scene.instantiate()
	camp.build_ui()
	var passed: bool = camp.get_node_or_null("Layout/Column/Header/GoldValue") != null
	passed = passed and camp.get_node_or_null("Layout/Column/Stats") != null
	var grid: GridContainer = camp.get_node_or_null("Layout/Column/Buildings")
	passed = passed and grid != null and grid.get_child_count() == Camp.buildings().size()
	var depart: Button = camp.get_node_or_null("Layout/Column/MenuButtons/DepartButton")
	passed = passed and depart != null \
		and depart.custom_minimum_size.y >= UiPalette.TOUCH_TARGET_MIN
	var select: Button = camp.get_node_or_null("Layout/Column/MenuButtons/SelectButton")
	passed = passed and select != null
	if not passed:
		push_error("test_camp: camp screen structure incomplete")
	camp.free()
	return passed
