extends RefCounted
## Guards the N3-17 card layout: no description the real data can produce may
## exceed its card's border rect, and the grown panel must still fit the
## portrait screen. Text height is measured through TextParagraph — a separate
## API path from the popup's own measurement — so a revert to a fixed card
## height fails here.

const WEAPONS_PATH := "res://data/weapons.json"
const PASSIVES_PATH := "res://data/passives.json"
const MODS_PATH := "res://data/weapon_mods.json"
## Highest weapon level and top grade produce the longest stat numbers.
const WORST_LEVEL := 8
const WORST_GRADE := "mythic"


func _load(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## Every description the level-up screen can put on a card, at the levels and
## grades that make them longest, split by card kind: a screen holds at most
## ONE 개조 card (LevelUp.assemble), so the worst screen is 1 mod + 2 others.
## {"mod": Array[String], "other": Array[String]}
func _descs_by_kind() -> Dictionary:
	var weapons: Dictionary = _load(WEAPONS_PATH)
	var passives: Dictionary = _load(PASSIVES_PATH)
	var mods: Dictionary = _load(MODS_PATH)
	var grades: Dictionary = WeaponGrade.config(weapons)
	var other: Array[String] = []
	var mod_descs: Array[String] = []
	var owned: Dictionary = {}
	var owned_grades: Dictionary = {}
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		owned[weapon_id] = WORST_LEVEL
		owned_grades[weapon_id] = WORST_GRADE
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		for kind: String in [
			LevelUp.KIND_NEW_WEAPON, LevelUp.KIND_WEAPON_UP, LevelUp.KIND_GRADE_UP
		]:
			other.append(LevelUp.describe(
				{"kind": kind, "id": weapon_id}, weapons, passives,
				owned, {}, owned_grades, grades
			))
	for passive_id: String in passives:
		other.append(LevelUp.describe(
			{"kind": LevelUp.KIND_PASSIVE, "id": passive_id}, weapons, passives, {}, {}
		))
	for mod_id: String in mods:
		var choice: Dictionary = {"kind": LevelUp.KIND_MOD, "id": mod_id, "mod": mods[mod_id]}
		var desc: String = LevelUp.describe(
			choice, weapons, passives, owned, {}, owned_grades, grades
		)
		mod_descs.append(desc)
		# The first 개조 card ever shown carries one extra explanation line.
		mod_descs.append(Ftue.MOD_EXPLAIN_LINE + "\n" + desc)
	return {"mod": mod_descs, "other": other}


func _card_width() -> float:
	var style: StyleBox = UiIcons.paper_panel()
	var root_width: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_width", 540)
	)
	return (
		root_width - LevelUpPopup.PANEL_MARGIN_X * 2.0
		- style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		- LevelUpPopup.BODY_MARGIN * 4.0
	)


func _line_spacing() -> int:
	var label := Label.new()
	var spacing: int = label.get_theme_constant("line_spacing")
	label.free()
	return spacing


func _tallest(descs: Array[String], font: Font, wrap_width: float, spacing: int) -> float:
	var tallest: float = 0.0
	for desc: String in descs:
		tallest = maxf(tallest, LevelUpPopup.card_height_for(desc, font, wrap_width, spacing))
	return tallest


func test_no_desc_exceeds_its_card() -> bool:
	var font: Font = LevelUpPopup.card_font()
	var wrap_width: float = _card_width() - LevelUpPopup.TEXT_LEFT - LevelUpPopup.WELL_MARGIN
	var spacing: int = _line_spacing()
	var passed: bool = wrap_width > 0.0
	var by_kind: Dictionary = _descs_by_kind()
	var all_descs: Array[String] = []
	all_descs.append_array(by_kind["mod"] as Array[String])
	all_descs.append_array(by_kind["other"] as Array[String])
	for desc: String in all_descs:
		var card_height: float = LevelUpPopup.card_height_for(desc, font, wrap_width, spacing)
		# Independent measurement of the rendered text block.
		var paragraph := TextParagraph.new()
		paragraph.break_flags = LevelUpPopup.DESC_BREAK_FLAGS
		paragraph.width = wrap_width
		paragraph.add_string(desc, font, UiPalette.FONT_SIZE_LABEL)
		var text_height: float = (
			paragraph.get_size().y + float(spacing * (paragraph.get_line_count() - 1))
		)
		if LevelUpPopup.DESC_TOP + text_height > card_height:
			push_error("test_level_up_popup: desc overflows its card: " + desc)
			passed = false
	if not passed:
		push_error("test_level_up_popup: card content exceeds the card border rect")
	return passed


func test_fixed_card_elements_fit_min_height() -> bool:
	# Icon well + its label must fit even on the shortest possible card.
	var fixed_bottom: float = (
		LevelUpPopup.WELL_MARGIN + LevelUpPopup.WELL_SIZE + 4.0 + 20.0
	)
	var passed: bool = fixed_bottom <= LevelUpPopup.CARD_HEIGHT_MIN
	if not passed:
		push_error("test_level_up_popup: well column no longer fits CARD_HEIGHT_MIN")
	return passed


## N4-7: the owned-weapon strip must fit the screen at the maximum number of
## weapons a run can own — every offerable weapon at once (mods swap 1:1, so
## they never raise the count). The strip wraps inside the panel margins and
## the wrapped height must stay inside the panel's bottom reserve.
func test_owned_strip_fits_at_max_owned_count() -> bool:
	var weapons: Dictionary = _load(WEAPONS_PATH)
	var max_owned: int = 0
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var stats: Dictionary = weapons[weapon_id]
		if not bool(stats.get("evolution_only", false)) and LevelUp.runtime_can_fire(stats):
			max_owned += 1
	# N9-5e: 화부/뇌부/살 became evolution-only talisman branches, shrinking
	# the offerable roster to 7 spiritual + the bow. The guard only proves
	# the data still carries a multi-weapon roster worth wrap-testing.
	if max_owned < 7:
		push_error("test_level_up_popup: offerable weapon count fixture assumption broke")
		return false
	var root_width: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_width", 540)
	)
	var strip_width: float = root_width - LevelUpPopup.PANEL_MARGIN_X * 2.0
	var height: float = LevelUpPopup.owned_strip_height(max_owned, strip_width)
	var passed: bool = (
		UiPalette.SPACE_MD + height <= LevelUpPopup.OWNED_STRIP_RESERVE
	)
	if not passed:
		push_error(
			"test_level_up_popup: %d owned weapons wrap to %.0fpx, over the %.0fpx reserve"
			% [max_owned, height, LevelUpPopup.OWNED_STRIP_RESERVE]
		)
	return passed


func test_panel_fits_portrait_screen() -> bool:
	var font: Font = LevelUpPopup.card_font()
	var wrap_width: float = _card_width() - LevelUpPopup.TEXT_LEFT - LevelUpPopup.WELL_MARGIN
	var spacing: int = _line_spacing()
	var by_kind: Dictionary = _descs_by_kind()
	var tallest_mod: float = _tallest(by_kind["mod"] as Array[String], font, wrap_width, spacing)
	var tallest_other: float = _tallest(
		by_kind["other"] as Array[String], font, wrap_width, spacing
	)
	# Worst legal screen: one 개조 card plus two regular picks.
	var heights: Array[float] = [tallest_mod, tallest_other, tallest_other]
	var style: StyleBox = UiIcons.paper_panel()
	var unclamped: float = LevelUpPopup.panel_height_for(
		heights, style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	)
	var screen_height: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_height", 960)
	)
	var limit: float = (
		screen_height - LevelUpPopup.PANEL_TOP - LevelUpPopup.OWNED_STRIP_RESERVE
	)
	# The worst legal screen must fit WITHOUT the overflow scroll engaging —
	# if data growth ever trips this, revisit the layout, not the clamp.
	var passed: bool = unclamped <= limit
	if not passed:
		push_error(
			"test_level_up_popup: worst screen (%.0fpx) outgrows the panel limit %.0fpx"
			% [unclamped, limit]
		)
	return passed


## Owner (2026-08-24): landscape lays the choices out as columns. The regular
## (non-개조) worst screen must fit the 540 landscape height without the clamp
## engaging, and the roster strip must stay one row on the wide band.
func test_landscape_columns_fit_the_540_height() -> bool:
	var font: Font = LevelUpPopup.card_font()
	var spacing: int = _line_spacing()
	var style: StyleBox = UiIcons.paper_panel()
	var body_width: float = (
		LevelUpPopup.PANEL_MAX_WIDTH_LANDSCAPE
		- style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		- LevelUpPopup.BODY_MARGIN * 4.0
	)
	var column_width: float = LevelUpPopup.column_width_for(body_width, 3)
	var passed: bool = column_width >= LevelUpPopup.CARD_COLUMN_MIN_WIDTH
	var wrap_width: float = column_width - LevelUpPopup.WELL_MARGIN * 2.0
	var by_kind: Dictionary = _descs_by_kind()
	# Regular cards plus every plain 개조 desc must fit; only the one-time
	# FTUE explainer line may push a card into the scroll fallback.
	var descs: Array[String] = []
	descs.append_array(by_kind["other"] as Array[String])
	for desc: String in by_kind["mod"] as Array[String]:
		if not desc.begins_with(Ftue.MOD_EXPLAIN_LINE):
			descs.append(desc)
	var tallest: float = 0.0
	for desc: String in descs:
		tallest = maxf(
			tallest, LevelUpPopup.column_card_height_for(desc, font, wrap_width, spacing)
		)
	# Landscape budget must be priced with LANDSCAPE chrome — the portrait
	# defaults (64px header, 20px margins) overstate the frame by 74px and
	# failed the honest TextParagraph card measure (resweep play R3).
	var unclamped: float = LevelUpPopup.panel_height_for(
		[tallest], style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM),
		LevelUpPopup.HEADER_HEIGHT_LANDSCAPE, LevelUpPopup.BODY_MARGIN_LANDSCAPE
	)
	var limit: float = (
		LevelUpPopup.DESIGN_HEIGHT_LANDSCAPE - LevelUpPopup.PANEL_TOP_LANDSCAPE
		- LevelUpPopup.OWNED_STRIP_RESERVE_LANDSCAPE
	)
	if unclamped > limit:
		push_error(
			"test_level_up_popup: landscape columns (%.0fpx) outgrow the %.0fpx limit"
			% [unclamped, limit]
		)
		passed = false
	# The wide band must hold every offerable weapon in ONE strip row —
	# that is what lets the landscape reserve shrink to a single row.
	var weapons: Dictionary = _load(WEAPONS_PATH)
	var max_owned: int = 0
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var stats: Dictionary = weapons[weapon_id]
		if not bool(stats.get("evolution_only", false)) and LevelUp.runtime_can_fire(stats):
			max_owned += 1
	var strip_width: float = 960.0 - LevelUpPopup.PANEL_MARGIN_X * 2.0
	# N11-22: the roster grew past what one 960px row can seat (20 offerable
	# weapons at 48px wells). Landscape still RESERVES one row — the cap does
	# that, and the +N badge carries the rest — and a real run, which holds
	# four weapons plus what it evolved them into, must never need a second.
	if LevelUpPopup.owned_strip_rows(max_owned, strip_width, true) != 1:
		push_error("test_level_up_popup: landscape roster strip wraps past one row")
		passed = false
	var real_roster: int = LevelUp.WEAPON_SLOTS + 2
	if LevelUpPopup.owned_strip_rows(real_roster, strip_width) != 1:
		push_error("test_level_up_popup: a real run's roster must fit one row")
		passed = false
	return passed


func test_column_width_floors_at_min() -> bool:
	# 10 cards can never fit the band; the split floors and the row scrolls.
	var floored: float = LevelUpPopup.column_width_for(800.0, 10)
	var split: float = LevelUpPopup.column_width_for(800.0, 3)
	var passed: bool = (
		floored == LevelUpPopup.CARD_COLUMN_MIN_WIDTH
		and split == floorf((800.0 - LevelUpPopup.CARD_GAP * 2.0) / 3.0)
	)
	if not passed:
		push_error("test_level_up_popup: column_width_for split or floor is wrong")
	return passed


func test_panel_top_centers_the_expand_extra_height() -> bool:
	# N9-113 (owner: 파워 업 모달이 너무 위로): at the 960 design height the
	# top is exactly PANEL_TOP; a taller expand viewport splits its extra
	# height evenly, and a shorter-than-design one never pulls the top up.
	var passed: bool = LevelUpPopup.panel_top_for(960.0) == LevelUpPopup.PANEL_TOP
	passed = passed and LevelUpPopup.panel_top_for(1200.0) == LevelUpPopup.PANEL_TOP + 120.0
	passed = passed and LevelUpPopup.panel_top_for(900.0) == LevelUpPopup.PANEL_TOP
	if not passed:
		push_error("test_level_up_popup: panel_top_for mis-centers the expand height")
	return passed
