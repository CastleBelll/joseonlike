class_name LevelUpPopup
extends CanvasLayer
## Paper-panel choice popup, capture _07 grammar: lattice corners, header band,
## full-width row cards stacked vertically, and the owned-weapon strip outside
## the panel. Serves the level-up choices (N3-6) — including the 개조 card
## (N4-6) — from pre-built display cards (LevelUp.as_card), so this stays one
## card component. All colors are UiPalette tokens; the icon wells bind
## asset/ui icons by id (N3-13) with a letter-glyph fallback for ids without
## art (passives). The paper panel is the chrome 9-slice — lattice corners
## are baked into its margins.

signal picked(payload: Dictionary)
signal dismissed

const NEW_LABEL := "신규!"
const TRANSFORM_LABEL := "변신!"
## QA-3: pill tint per grade ladder rung; unknown ids fall back to common.
const GRADE_PILL_COLORS := {
	"common": UiPalette.GRADE_COMMON,
	"uncommon": UiPalette.GRADE_UNCOMMON,
	"rare": UiPalette.GRADE_RARE,
	"epic": UiPalette.GRADE_EPIC,
	"mythic": UiPalette.GRADE_MYTHIC,
}

const LAYER_ABOVE_HUD := 10
const PANEL_MARGIN_X := 24.0
## N9-152 (owner: 가로에서 파워업 선택지가 너무 길다): the paper band never
## grows past the portrait design width — wide viewports center it.
const PANEL_MAX_WIDTH := 492.0
## Owner (2026-08-24): in landscape the stacked cards forced a vertical
## scroll — the choices lay out as side-by-side columns on a wide band
## instead. Trimmed below the full 960 so the field shows at the sides
## (owner: the popup covered the whole screen).
const PANEL_MAX_WIDTH_LANDSCAPE := 872.0
const PANEL_TOP := 96.0
## Landscape has 540 design px of height; the portrait 96px top would eat it.
const PANEL_TOP_LANDSCAPE := 16.0
## The project's design viewport height; aspect "expand" can hand a taller one.
const DESIGN_HEIGHT := 960.0
const DESIGN_HEIGHT_LANDSCAPE := 540.0
## A column card narrower than this clips its name line; below it the row
## scrolls horizontally instead of shrinking further (pathological counts).
const CARD_COLUMN_MIN_WIDTH := 232.0
## Owner (2026-08-24): the landscape popup covered the whole screen — the
## floor only guarantees a two-line card, so short screens stay short.
const CARD_COLUMN_HEIGHT_MIN := 196.0
const HEADER_HEIGHT := 64.0
const BODY_MARGIN := 20.0
## Cards grow with their wrapped description (N3-17); this is the floor that
## keeps a short card's icon well and pill layout intact.
const CARD_HEIGHT_MIN := 136.0
const CARD_GAP := 16.0
const CARD_CORNER := 10
const CARD_BORDER_WIDTH := 2
const FOCUS_RING_WIDTH := 4
const WELL_SIZE := 72.0
const WELL_CORNER := 8
const WELL_MARGIN := 16.0
## Column cards (landscape) stack name and description under the icon well
## row; these are the y offsets of that stacked layout (the name line starts
## right where the well's own label row ends).
const COLUMN_NAME_TOP := WELL_MARGIN + WELL_SIZE + 24.0
const COLUMN_DESC_TOP := COLUMN_NAME_TOP + 28.0
# Weapon icons show at integer multiples of their 32px logical size and the
# loot badge at its native 24px, so NEAREST sampling stays lossless
# (asset/ui/README.md).
const WELL_ICON_SIZE := 64.0
const OWNED_ICON_SIZE := 32.0
const LOOT_BADGE_SIZE := 24.0
const TEXT_LEFT := 104.0
## Description block geometry inside a card (N3-17): top edge below the name,
## bottom padding to the card border, and the wrap flags matching
## AUTOWRAP_WORD_SMART so the height measurement equals the render.
const DESC_TOP := WELL_MARGIN + 44.0
const DESC_BOTTOM_PAD := WELL_MARGIN
const DESC_BREAK_FLAGS := (
	TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
)
## Screen space kept clear below the panel for the owned-weapon strip; past
## this the card list scrolls instead of growing (N3-17). Covers the strip
## wrapped to two rows — every offerable weapon owned at once (N4-7).
const OWNED_STRIP_RESERVE := 120.0
## The landscape band is wide enough for the whole roster in ONE strip row,
## so its reserve only needs that row plus a tight gap above it.
const OWNED_STRIP_RESERVE_LANDSCAPE := 56.0
const PILL_SIZE := Vector2(64.0, 30.0)
const PILL_MARGIN := 12.0
const OWNED_WELL_SIZE := 48.0
const OWNED_ROW_GAP := 12.0
## Vertical gap between wrapped strip rows (N4-7) — tight, so two rows still
## fit the panel's bottom reserve.
const OWNED_WRAP_GAP := 4.0
const OWNED_BADGE_HEIGHT := 18.0
const OWNED_BADGE_OUTLINE := 4
const CLOSE_BUTTON_SIZE := Vector2(200.0, 64.0)

var _root: Control
var _panel: PanelContainer
var _body: Control
var _scroll: ScrollContainer
var _owned_row: HFlowContainer
var _title: Label
## What the open popup is showing, so a rotation can rebuild the same screen.
var _last_cards: Array[Dictionary] = []
var _last_owned: Dictionary = {}
var _last_weapons: Dictionary = {}
var _built_landscape: bool = false


func _init() -> void:
	# The popup must keep processing input while the stage tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_HUD


func _ready() -> void:
	_root = Control.new()
	_root.name = "Blocker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "PaperPanel"
	_panel.add_theme_stylebox_override("panel", UiIcons.paper_panel())
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_apply_panel_band()
	_panel.offset_top = PANEL_TOP
	# The bottom edge is recomputed per open() from the card stack (N3-17).
	_panel.offset_bottom = PANEL_TOP + CARD_HEIGHT_MIN
	_root.add_child(_panel)
	var layout := Control.new()
	layout.name = "Layout"
	_panel.add_child(layout)
	layout.add_child(_make_header())
	_body = Panel.new()
	_body.name = "Body"
	(_body as Panel).add_theme_stylebox_override("panel", _inset_style())
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.offset_left = BODY_MARGIN
	_body.offset_right = -BODY_MARGIN
	_body.offset_top = HEADER_HEIGHT + BODY_MARGIN
	_body.offset_bottom = -BODY_MARGIN * 2.0
	layout.add_child(_body)
	# The scroll only ever engages when a pathological card stack outgrows the
	# clamped panel (N3-17); with real data everything fits and it is inert.
	_scroll = ScrollContainer.new()
	_scroll.name = "CardScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = BODY_MARGIN
	_scroll.offset_right = -BODY_MARGIN
	_scroll.offset_top = BODY_MARGIN
	_scroll.offset_bottom = -BODY_MARGIN
	_body.add_child(_scroll)
	# A flow container wraps the strip once a run owns more weapons than one
	# row fits (N4-7) — the strip must never run off the 540px screen edge.
	_owned_row = HFlowContainer.new()
	_owned_row.name = "OwnedRow"
	_owned_row.add_theme_constant_override("h_separation", int(OWNED_ROW_GAP))
	_owned_row.add_theme_constant_override("v_separation", int(OWNED_WRAP_GAP))
	_owned_row.position = Vector2(PANEL_MARGIN_X, PANEL_TOP + CARD_HEIGHT_MIN)
	_root.add_child(_owned_row)
	# Owner (모든 UI/UX는 반응형으로): the columns-or-rows choice is made when
	# the popup opens, and the tree is PAUSED while it is up — a rotation mid
	# choice would otherwise leave the old layout on screen.
	_root.resized.connect(_relayout_on_flip)
	visible = false


## Build and show the popup from pre-built display cards. The stage owns
## pausing; this only renders and routes the pick (card "payload" back through
## picked). 0 cards degrade to a close button (no crash, no dead end).
func open(
	header_text: String,
	display_cards: Array[Dictionary],
	owned_levels: Dictionary,
	weapons: Dictionary
) -> void:
	for child: Node in _scroll.get_children():
		child.queue_free()
	for child: Node in _owned_row.get_children():
		child.queue_free()
	_title.text = header_text
	var landscape: bool = _is_landscape()
	_last_cards = display_cards
	_last_owned = owned_levels
	_last_weapons = weapons
	_built_landscape = landscape
	# Owner (2026-08-24): landscape rows scroll horizontally if they ever
	# outgrow the band; the portrait stack keeps its vertical-only scroll.
	_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if landscape
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	var cards: BoxContainer = HBoxContainer.new() if landscape else VBoxContainer.new()
	cards.name = "Cards"
	cards.add_theme_constant_override("separation", int(CARD_GAP))
	_scroll.add_child(cards)
	# Cards are sized to their wrapped description up front (N3-17): the width
	# is derived from the fixed layout, so the wrap measurement in
	# card_height_for equals what the Label renders. Landscape splits the body
	# width into equal columns instead of full-width rows.
	var card_width: float = (
		column_width_for(_card_width(), display_cards.size()) if landscape
		else _card_width()
	)
	var font: Font = card_font()
	var line_spacing: int = _title.get_theme_constant("line_spacing")
	var heights: Array[float] = []
	for card: Dictionary in display_cards:
		var height: float = (
			column_card_height_for(
				String(card.get("desc", "")), font, card_width - WELL_MARGIN * 2.0,
				line_spacing
			) if landscape
			else card_height_for(
				String(card.get("desc", "")), font, card_width - TEXT_LEFT - WELL_MARGIN,
				line_spacing
			)
		)
		heights.append(height)
	if landscape and not heights.is_empty():
		# One aligned row: every column takes the tallest measured height.
		var tallest: float = heights.max()
		for i: int in heights.size():
			heights[i] = tallest
	for i: int in display_cards.size():
		cards.add_child(_make_card(display_cards[i], card_width, heights[i], landscape))
	if display_cards.is_empty():
		heights.append(CARD_HEIGHT_MIN)
		cards.add_child(_make_close_button())
	# N9-113 (owner: 파워 업 모달이 너무 위로): aspect "expand" grows a tall
	# phone's viewport past the 960 design height, and a fixed 96px top left
	# the popup hugging the top edge — the extra height splits evenly instead.
	var top: float = (
		PANEL_TOP_LANDSCAPE + maxf(_root_size().y - DESIGN_HEIGHT_LANDSCAPE, 0.0) / 2.0
		if landscape else panel_top_for(_root_size().y)
	)
	# Landscape is one row, so the panel wraps the tallest card, not the sum.
	var stack_heights: Array[float] = heights
	if landscape and not heights.is_empty():
		stack_heights = [heights[0]]
	var reserve: float = (
		OWNED_STRIP_RESERVE_LANDSCAPE if landscape else OWNED_STRIP_RESERVE
	)
	var panel_height: float = minf(
		panel_height_for(stack_heights, _panel_style_margins_y()),
		_root_size().y - top - reserve
	)
	# Owner (2026-08-24): a short landscape panel floats centred instead of
	# hugging the top, so the field stays visible above and below the paper.
	if landscape:
		top = maxf(
			PANEL_TOP_LANDSCAPE,
			(_root_size().y - reserve - panel_height) / 2.0
		)
	_apply_panel_band()
	_panel.offset_top = top
	_panel.offset_bottom = top + panel_height
	# The tight landscape reserve pairs with the tighter SM gap.
	var strip_gap: float = float(UiPalette.SPACE_SM if landscape else UiPalette.SPACE_MD)
	_owned_row.position = Vector2(
		_panel_inset(), top + panel_height + strip_gap
	)
	# The strip's rect width is what the flow container wraps against.
	_owned_row.size = Vector2(
		_root_size().x - _panel_inset() * 2.0, reserve - strip_gap
	)
	_build_owned_row(owned_levels, weapons)
	visible = true
	var first: Control = cards.get_child(0)
	first.call_deferred("grab_focus")


## Rebuilds the open screen from the cards it is already showing, but only
## when the orientation actually flips.
func _relayout_on_flip() -> void:
	if not visible or _last_cards.is_empty():
		return
	if _is_landscape() == _built_landscape:
		return
	open(_title.text, _last_cards, _last_owned, _last_weapons)


func close() -> void:
	visible = false


## Fixed-size card (N3-17): width comes from the portrait layout constants,
## height from card_height_for on the wrapped description. A fixed rect keeps
## the measured wrap width identical to the rendered one even when the
## overflow scrollbar appears (it may overlap the card edge in that
## pathological case — accepted, real data never engages the scroll).
func _make_card(
	display: Dictionary, card_width: float, card_height: float, column: bool = false
) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override("normal", _card_style(UiPalette.PAPER_CARD))
	card.add_theme_stylebox_override("hover", _card_style(UiPalette.PAPER_INSET))
	card.add_theme_stylebox_override("pressed", _card_style(UiPalette.PAPER_INSET))
	card.add_theme_stylebox_override("focus", _focus_ring())
	var payload: Dictionary = display.get("payload", {})
	card.pressed.connect(func() -> void: picked.emit(payload))
	var name_text: String = String(display.get("name", ""))
	card.add_child(_make_icon_well(
		name_text,
		String(display.get("icon_weapon_id", "")),
		String(display.get("icon_loot_id", "")),
		String(display.get("icon_passive_id", ""))
	))
	var label_text: String = String(display.get("well_label", ""))
	var well_label := _label(
		label_text, UiPalette.FONT_SIZE_LABEL,
		UiPalette.VERMILION
		if label_text in [UiLocale.t(NEW_LABEL), UiLocale.t(TRANSFORM_LABEL)]
		else UiPalette.INK
	)
	well_label.position = Vector2(WELL_MARGIN, WELL_MARGIN + WELL_SIZE + 4.0)
	well_label.size = Vector2(WELL_SIZE, 20.0)
	well_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(well_label)
	var name_label := _label(name_text, UiPalette.FONT_SIZE_TITLE, UiPalette.INK)
	# Column cards (landscape) stack the name and description under the icon
	# well; row cards keep the portrait icon-left layout.
	if column:
		name_label.position = Vector2(WELL_MARGIN, COLUMN_NAME_TOP)
		name_label.size = Vector2(card_width - WELL_MARGIN * 2.0, 32.0)
	else:
		name_label.position = Vector2(TEXT_LEFT, WELL_MARGIN)
		name_label.size = Vector2(
			card_width - TEXT_LEFT - PILL_SIZE.x - PILL_MARGIN * 2.0, 32.0
		)
	name_label.clip_text = true
	card.add_child(name_label)
	var desc_label := _label(
		String(display.get("desc", "")),
		UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER
	)
	# Autowrap first: set_size clamps to the minimum size, and without wrap the
	# minimum width is the full unwrapped line (N3-17 regression).
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if column:
		desc_label.position = Vector2(WELL_MARGIN, COLUMN_DESC_TOP)
		desc_label.size = Vector2(
			card_width - WELL_MARGIN * 2.0, card_height - COLUMN_DESC_TOP - DESC_BOTTOM_PAD
		)
	else:
		desc_label.position = Vector2(TEXT_LEFT, DESC_TOP)
		desc_label.size = Vector2(
			card_width - TEXT_LEFT - WELL_MARGIN, card_height - DESC_TOP - DESC_BOTTOM_PAD
		)
	card.add_child(desc_label)
	card.add_child(_make_grade_pill(
		String(display.get("grade", "")), String(display.get("grade_id", ""))
	))
	return card


## The font every card label renders with: the project theme's default, with
## the engine fallback for a broken theme install. Static so the headless
## layout test measures with the exact same font (N3-17).
static func card_font() -> Font:
	var theme: Theme = load("res://asset/ui_theme.tres")
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font


## Card height for one description at its wrap width (N3-17): the measured
## multiline text block plus the fixed geometry above and below it, floored at
## CARD_HEIGHT_MIN. Label line spacing is added per extra line on top of the
## server measurement — a few px of bottom slack beats a clipped last line.
static func card_height_for(
	desc: String, font: Font, wrap_width: float, line_spacing: int
) -> float:
	var measured: Vector2 = font.get_multiline_string_size(
		desc, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, UiPalette.FONT_SIZE_LABEL,
		-1, DESC_BREAK_FLAGS
	)
	var line_height: float = maxf(font.get_height(UiPalette.FONT_SIZE_LABEL), 1.0)
	var lines: int = maxi(int(ceilf(measured.y / (line_height + float(line_spacing)))), 1)
	var text_height: float = measured.y + float(line_spacing * (lines - 1))
	return maxf(CARD_HEIGHT_MIN, DESC_TOP + text_height + DESC_BOTTOM_PAD)


## Unclamped panel height for a card stack: header, body/scroll margins, the
## cards and their gaps, plus the panel stylebox's own content margins.
## N9-113: where the panel starts on this screen. At the 960 design height
## this is exactly PANEL_TOP; anything a taller (aspect "expand") viewport
## adds is split evenly above and below so the popup stays centred.
static func panel_top_for(root_height: float) -> float:
	return PANEL_TOP + maxf(root_height - DESIGN_HEIGHT, 0.0) / 2.0


static func panel_height_for(card_heights: Array[float], style_margins_y: float) -> float:
	var cards_total: float = 0.0
	for height: float in card_heights:
		cards_total += height
	cards_total += CARD_GAP * float(maxi(card_heights.size() - 1, 0))
	return style_margins_y + HEADER_HEIGHT + BODY_MARGIN * 5.0 + cards_total


## Owned-strip wrap math (N4-7), static so the layout test can prove the
## strip fits the reserve at the data's maximum owned-weapon count. Entries
## are OWNED_WELL_SIZE wide — the level label under the well is narrower.
static func owned_strip_rows(count: int, strip_width: float) -> int:
	var per_row: int = maxi(
		int((strip_width + OWNED_ROW_GAP) / (OWNED_WELL_SIZE + OWNED_ROW_GAP)), 1
	)
	return int(ceilf(float(count) / float(per_row)))


static func owned_strip_height(count: int, strip_width: float) -> float:
	var rows: int = owned_strip_rows(count, strip_width)
	return float(rows) * OWNED_WELL_SIZE + float(maxi(rows - 1, 0)) * OWNED_WRAP_GAP


## Column card height (landscape): the stacked name/desc layout under the
## well, floored so a short card keeps its shape. Static for the layout test.
static func column_card_height_for(
	desc: String, font: Font, wrap_width: float, line_spacing: int
) -> float:
	var measured: Vector2 = font.get_multiline_string_size(
		desc, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, UiPalette.FONT_SIZE_LABEL,
		-1, DESC_BREAK_FLAGS
	)
	var line_height: float = maxf(font.get_height(UiPalette.FONT_SIZE_LABEL), 1.0)
	var lines: int = maxi(int(ceilf(measured.y / (line_height + float(line_spacing)))), 1)
	var text_height: float = measured.y + float(line_spacing * (lines - 1))
	return maxf(CARD_COLUMN_HEIGHT_MIN, COLUMN_DESC_TOP + text_height + DESC_BOTTOM_PAD)


## Equal column split of the body width; floored so a pathological card count
## scrolls horizontally instead of crushing the columns. Static for the test.
static func column_width_for(avail_width: float, count: int) -> float:
	var n: int = maxi(count, 1)
	# Floored: a fractional split makes the row 1-2px wider than the scroll
	# area and summons a pointless horizontal scrollbar.
	return maxf(
		floorf((avail_width - CARD_GAP * float(n - 1)) / float(n)),
		CARD_COLUMN_MIN_WIDTH
	)


func _is_landscape() -> bool:
	return _root_size().x > _root_size().y


## N9-152: distance from either screen edge to the paper band — the old
## PANEL_MARGIN_X on phones, centered once the viewport is wider than the
## portrait design band. Landscape widens the band to its own design width.
func _panel_inset() -> float:
	var band: float = PANEL_MAX_WIDTH_LANDSCAPE if _is_landscape() else PANEL_MAX_WIDTH
	return maxf(PANEL_MARGIN_X, (_root_size().x - band) / 2.0)


func _apply_panel_band() -> void:
	var inset: float = _panel_inset()
	_panel.offset_left = inset
	_panel.offset_right = -inset


func _card_width() -> float:
	var style: StyleBox = _panel.get_theme_stylebox("panel")
	return (
		_root_size().x - _panel_inset() * 2.0
		- style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		- BODY_MARGIN * 4.0
	)


func _panel_style_margins_y() -> float:
	var style: StyleBox = _panel.get_theme_stylebox("panel")
	return style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)


## The blocker fills the viewport once inside the tree; before that (headless
## layout tests) fall back to the project's portrait design size.
func _root_size() -> Vector2:
	if _root != null and _root.size.x > 0.0:
		return _root.size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 540)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 960))
	)


func _make_icon_well(
	name_text: String, weapon_icon_id: String, loot_icon_id: String,
	passive_icon_id: String = ""
) -> Panel:
	var well := Panel.new()
	well.position = Vector2(WELL_MARGIN, WELL_MARGIN)
	well.size = Vector2(WELL_SIZE, WELL_SIZE)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.INK
	style.set_corner_radius_all(WELL_CORNER)
	well.add_theme_stylebox_override("panel", style)
	# N9-10b: passive cards get their stat glyphs — the letter fallback
	# only remains for ids without art.
	var icon: Texture2D = UiIcons.weapon_icon(weapon_icon_id)
	if icon == null:
		icon = UiIcons.passive_icon(passive_icon_id)
	if icon != null:
		var rect: TextureRect = UiIcons.icon_rect(icon, WELL_ICON_SIZE)
		rect.position = Vector2.ONE * ((WELL_SIZE - WELL_ICON_SIZE) / 2.0)
		rect.size = Vector2(WELL_ICON_SIZE, WELL_ICON_SIZE)
		well.add_child(rect)
	else:
		# Missing-icon fallback: first syllable of the name in gold.
		var glyph := _label(name_text.left(1), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD)
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(glyph)
	# The mod card shows the consumed material as a corner badge (N3-13).
	var loot: Texture2D = UiIcons.loot_icon(loot_icon_id)
	if loot != null:
		var badge: TextureRect = UiIcons.icon_rect(loot, LOOT_BADGE_SIZE)
		badge.position = Vector2.ONE * (WELL_SIZE - LOOT_BADGE_SIZE + 4.0)
		badge.size = Vector2(LOOT_BADGE_SIZE, LOOT_BADGE_SIZE)
		well.add_child(badge)
	return well


func _make_grade_pill(text: String, grade_id: String) -> Panel:
	var pill := Panel.new()
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.offset_left = -(PILL_SIZE.x + PILL_MARGIN)
	pill.offset_right = -PILL_MARGIN
	pill.offset_top = PILL_MARGIN
	pill.offset_bottom = PILL_MARGIN + PILL_SIZE.y
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.grade_color(grade_id)
	style.set_corner_radius_all(int(PILL_SIZE.y / 2.0))
	pill.add_theme_stylebox_override("panel", style)
	var label := _label(text, UiPalette.FONT_SIZE_LABEL, UiPalette.PILL_TEXT)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(label)
	return pill


func _make_close_button() -> Button:
	var button := Button.new()
	button.text = UiLocale.t("닫기")
	button.custom_minimum_size = CLOSE_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	WoodButton.apply(button)
	button.pressed.connect(func() -> void: dismissed.emit())
	return button


func _build_owned_row(owned_levels: Dictionary, weapons: Dictionary) -> void:
	for weapon_id: String in owned_levels:
		var well := Panel.new()
		well.custom_minimum_size = Vector2(OWNED_WELL_SIZE, OWNED_WELL_SIZE)
		var style := StyleBoxFlat.new()
		style.bg_color = UiPalette.INK
		style.set_corner_radius_all(WELL_CORNER)
		well.add_theme_stylebox_override("panel", style)
		var stats: Dictionary = weapons.get(weapon_id, {})
		var icon: Texture2D = UiIcons.weapon_icon(weapon_id)
		if icon != null:
			var rect: TextureRect = UiIcons.icon_rect(icon, OWNED_ICON_SIZE)
			# N9-113 (owner: icons hung out of the wells): a CENTER preset on
			# a zero-size rect anchors its top-left at the well's middle and
			# lets the icon spill bottom-right; place it explicitly like the
			# card wells do.
			rect.position = Vector2.ONE * ((OWNED_WELL_SIZE - OWNED_ICON_SIZE) / 2.0)
			rect.size = Vector2(OWNED_ICON_SIZE, OWNED_ICON_SIZE)
			well.add_child(rect)
		else:
			# Missing-icon fallback, same rule as the card wells.
			var glyph := _label(
				UiLocale.data_name(stats, weapon_id).left(1),
				UiPalette.FONT_SIZE_BODY, UiPalette.GOLD
			)
			glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			well.add_child(glyph)
		# The level rides ON the well as a badge (N4-7): a label row under the
		# wells made two wrapped strip rows outgrow the panel's bottom reserve.
		var level_label := _label(
			"Lv.%d" % int(owned_levels[weapon_id]),
			UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_ON_DARK
		)
		level_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		level_label.offset_top = -OWNED_BADGE_HEIGHT
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_color_override("font_outline_color", UiPalette.INK)
		level_label.add_theme_constant_override("outline_size", OWNED_BADGE_OUTLINE)
		well.add_child(level_label)
		_owned_row.add_child(well)


func _make_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = HEADER_HEIGHT
	_title = _label("", UiPalette.FONT_SIZE_TITLE, UiPalette.VERMILION)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	return header


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _inset_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PAPER_INSET
	style.set_corner_radius_all(CARD_CORNER)
	return style


func _card_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = UiPalette.PAPER_CARD_BORDER
	style.set_border_width_all(CARD_BORDER_WIDTH)
	style.set_corner_radius_all(CARD_CORNER)
	return style


func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UiPalette.GOLD
	ring.set_border_width_all(FOCUS_RING_WIDTH)
	ring.set_corner_radius_all(CARD_CORNER)
	return ring
