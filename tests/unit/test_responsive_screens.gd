extends RefCounted
## Owner (모든 UI/UX는 반응형으로): a screen that decides its layout at build
## time must rebuild when the orientation flips, and a paper that measures its
## band must re-measure on resize. The result screen measured ONCE at _ready
## and hung its CTA off the sheet in landscape; this keeps the whole set
## honest by source, since the flip itself needs a live tree to exercise.

const SCREENS := {
	"camp_screen": "res://scripts/ui/camp_screen.gd",
	"character_select": "res://scripts/ui/character_select.gd",
	"combat_hud": "res://scripts/ui/combat_hud.gd",
	"guide_dialog": "res://scripts/ui/guide_dialog.gd",
	"level_up_popup": "res://scripts/ui/level_up_popup.gd",
	"result_screen": "res://scripts/ui/result_screen.gd",
	"settings_popup": "res://scripts/ui/settings_popup.gd",
	"title": "res://scripts/ui/title.gd",
}


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Every screen that reads the viewport has to hear about it changing.
func test_every_screen_listens_for_a_resize() -> bool:
	var passed: bool = true
	for name: String in SCREENS:
		var source: String = _source(String(SCREENS[name]))
		if source.is_empty():
			push_error("test_responsive_screens: cannot read %s" % name)
			passed = false
			continue
		if not source.contains("resized.connect"):
			push_error(
				"test_responsive_screens: %s never connects resized — it measures once" % name
			)
			passed = false
	return passed


## The result paper's own regression: its band must be computed in a function
## the resize hook can call, not inline in _ready where it ran exactly once.
func test_the_result_paper_measures_in_a_reusable_place() -> bool:
	var source: String = _source(String(SCREENS["result_screen"]))
	var passed: bool = (
		source.contains("func _layout_panel")
		and source.contains("_root.resized.connect(_layout_panel)")
	)
	if not passed:
		push_error("test_responsive_screens: the result paper stopped re-measuring on resize")
	return passed
