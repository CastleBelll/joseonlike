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
## N10-16 (owner: 가로모드에서 파워업 하면 너무 여백이 많아서 별로고 너무 커):
## 872 of 960 left the sheet reading as the whole screen, and with the card copy
## now one fact per line the columns no longer need that width — the space was
## going to margin, not to text.
## 3 columns at CARD_COLUMN_MIN_WIDTH + 2 gaps + both body margins. Set below
## this and the row scrolls sideways instead of shrinking — measured at 728,
## which is exactly the columns and leaves nothing for the margins.
const PANEL_MAX_WIDTH_LANDSCAPE := 768.0
const PANEL_TOP := 96.0
## Landscape has 540 design px of height; the portrait 96px top would eat it.
const PANEL_TOP_LANDSCAPE := 16.0
## The project's design viewport height; aspect "expand" can hand a taller one.
const DESIGN_HEIGHT := 960.0
const DESIGN_HEIGHT_LANDSCAPE := 540.0
## A column card narrower than this clips its name line; below it the row
## scrolls horizontally instead of shrinking further (pathological counts).
## N10-16: 232 was sized for card copy that ran as one long paragraph. With one
## fact per line the name is the widest thing left, and holding the old floor
## against the narrowed landscape band clamped three columns wider than the band
## and summoned the very sideways scroll this floor exists to avoid.
const CARD_COLUMN_MIN_WIDTH := 206.0
## Q24: one choice on the wide handscroll used to take the whole body — an
## 850px card whose content hugged the left third and read as a stretched
## banner. A card is a card; past this width the paper shows around it.
const CARD_COLUMN_MAX_WIDTH := 420.0
## Owner (2026-08-24): the landscape popup covered the whole screen — the
## floor only guarantees a two-line card, so short screens stay short.
## N10-16: shorter copy means the floor, not the text, was setting the height,
## and the cards stood half empty. Three short lines fit in 158.
const CARD_COLUMN_HEIGHT_MIN := 158.0
const HEADER_HEIGHT := 64.0
## Owner (자꾸 스크롤이 생길정도라서): a landscape screen is 540 tall and the
## chrome around the cards was written for 960 — title band plus five body
## margins came to a third of the sheet, so the card the player is reading
## scrolled. Landscape spends less on the frame and gives it to the card.
## N10-16 trims four more off the landscape title band. It buys no room on the
## 540 canvases — there the panel is capped by the band, and shrinking the
## header shrinks the estimate by the same amount — but on taller screens it is
## four fewer pixels of frame around the card the player is reading.
const HEADER_HEIGHT_LANDSCAPE := 40.0
const BODY_MARGIN := 20.0
const BODY_MARGIN_LANDSCAPE := 12.0
## Cards grow with their wrapped description (N3-17); this is the floor that
## keeps a short card's icon well and pill layout intact.
const CARD_HEIGHT_MIN := 136.0
const CARD_GAP := 16.0
const CARD_CORNER := 10
const CARD_BORDER_WIDTH := 2
const FOCUS_RING_WIDTH := 4
const WELL_SIZE := 72.0
const WELL_CORNER := 8
## N10-16: trimmed from 16. On a 540 canvas the band is hard-capped and the
## cards were the last few pixels short; the well's own inset is the only place
## left that costs nothing to read.
const WELL_MARGIN := 12.0
## Column cards (landscape) stack name and description under the icon well
## row; these are the y offsets of that stacked layout (the name line starts
## right where the well's own label row ends).
## N10-16: trimmed from 24, but only to 20 — the "변신!" well label lives in
## this gap, and taking all fourteen the 540 canvas needed put the label on top
## of the name. The rest comes from the name-to-description gap below, which
## holds nothing.
## F31: room for the relocated well badge (which now starts at +8 and runs
## 20 tall) before the name line begins.
const COLUMN_NAME_TOP := WELL_MARGIN + WELL_SIZE + 27.0
## The name line's own height. Trimming this is not free space — at 18 the
## description rendered on top of the name.
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
## N10-16: on a 540-tall canvas the panel already filled its band and the cards
## were still three pixels short. The band is what caps it there, so the room
## has to come from the strip's reserve — eight pixels, taken from padding the
## one-row landscape strip never needed.
const OWNED_STRIP_RESERVE_LANDSCAPE := 48.0
const PILL_SIZE := Vector2(64.0, 30.0)
const PILL_MARGIN := 12.0
const OWNED_WELL_SIZE := 48.0
const OWNED_ROW_GAP := 12.0
## Vertical gap between wrapped strip rows (N4-7) — tight, so two rows still
## fit the panel's bottom reserve.
const OWNED_WRAP_GAP := 4.0
## Rows the strip may reserve before the cards start paying for it. A landscape
## band is wide enough that a real run's four weapons never need a second row,
## and the twenty pixels a second one would take are the difference between the
## card's last line being on the paper or not.
const OWNED_MAX_ROWS := 2
const OWNED_MAX_ROWS_LANDSCAPE := 1
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
## The panel's whole content, faded in by the unroll.
var _layout: Control


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
	# Owner (파워 업 시에 저 두루마리가 펼쳐지면서 내용이 나왔으면): the popup
	# wears the kit's hanging scroll and unrolls open (see _unroll). The paper
	# panel stays as the fallback for a checkout without the kit art.
	var scroll_style: StyleBox = UiIcons.scroll_panel()
	_panel.add_theme_stylebox_override(
		"panel", scroll_style if scroll_style != null else UiIcons.paper_panel()
	)
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_apply_panel_band()
	_panel.offset_top = PANEL_TOP
	# The bottom edge is recomputed per open() from the card stack (N3-17).
	_panel.offset_bottom = PANEL_TOP + CARD_HEIGHT_MIN
	_root.add_child(_panel)
	_layout = Control.new()
	_layout.name = "Layout"
	_panel.add_child(_layout)
	var layout: Control = _layout
	layout.add_child(_make_header())
	_body = Panel.new()
	_body.name = "Body"
	(_body as Panel).add_theme_stylebox_override("panel", _inset_style())
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	var body_margin: float = _body_margin()
	_body.offset_left = body_margin
	_body.offset_right = -body_margin
	_body.offset_top = _header_height() + body_margin
	_body.offset_bottom = -body_margin * 2.0
	layout.add_child(_body)
	# The scroll only ever engages when a pathological card stack outgrows the
	# clamped panel (N3-17); with real data everything fits and it is inert.
	_scroll = ScrollContainer.new()
	_scroll.name = "CardScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = body_margin
	_scroll.offset_right = -body_margin
	_scroll.offset_top = body_margin
	_scroll.offset_bottom = -body_margin
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
	# Owner (가로 모드에서는 당연히 가로로 펼쳐져야겠지): portrait hangs the
	# 족자, landscape opens a 횡권 — the same kit piece rebuilt with the rollers
	# on the sides, unrolling from the middle outward the way two hands open one.
	var wanted_style: StyleBox = (
		UiIcons.scroll_panel_landscape() if landscape else UiIcons.scroll_panel()
	)
	if wanted_style == null:
		wanted_style = UiIcons.paper_panel()
	_panel.add_theme_stylebox_override("panel", wanted_style)
	# The body and card scroll were placed ONCE at _ready, against whatever
	# orientation the real window had then — a landscape popup then carried
	# portrait chrome (64px header slot, 20px margins) and its scroll ran 64px
	# short. Latent for as long as the landscape panel took its whole band;
	# the content-fitted panel exposed it. Re-place them per build.
	var chrome_margin: float = _body_margin()
	_body.offset_left = chrome_margin
	_body.offset_right = -chrome_margin
	_body.offset_top = _header_height() + chrome_margin
	_body.offset_bottom = -chrome_margin * 2.0
	_scroll.offset_left = chrome_margin
	_scroll.offset_right = -chrome_margin
	_scroll.offset_top = chrome_margin
	_scroll.offset_bottom = -chrome_margin
	# Owner (2026-08-24): landscape rows scroll horizontally if they ever
	# outgrow the band; the portrait stack keeps its vertical-only scroll.
	_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if landscape
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	var cards: BoxContainer = HBoxContainer.new() if landscape else VBoxContainer.new()
	cards.name = "Cards"
	cards.add_theme_constant_override("separation", int(CARD_GAP))
	if landscape:
		# With the per-card width capped, one or two cards no longer fill the
		# row — centre them on the paper instead of leaning left (Q24).
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Landscape is one row, so the panel wraps the TALLEST card, not the sum and
	# not the first one: cards differ in height (an evolution card carries a
	# stat line the others do not), and sizing to the first clipped whichever
	# card happened to run longer.
	var stack_heights: Array[float] = heights
	if landscape and not heights.is_empty():
		var tallest: float = 0.0
		for height: float in heights:
			tallest = maxf(tallest, height)
		stack_heights = [tallest]
	# The tight landscape reserve pairs with the tighter SM gap.
	var strip_gap: float = float(UiPalette.SPACE_SM if landscape else UiPalette.SPACE_MD)
	# Owner (모바일에서 전체적으로 너무 작아): the adaptive base hands short
	# phones a canvas under the 960 design height, and the popup's fixed top
	# inset plus gaps then cost 13px the cards no longer have. Chrome scales
	# with the canvas — the cards themselves never shrink.
	if not landscape:
		top *= _portrait_squeeze()
		strip_gap *= _portrait_squeeze()
	# The strip is built and MEASURED before the panel is sized, because how
	# tall it is depends on how many weapons are owned and how many rows they
	# wrap into. The reserve used to be a constant guess — 120px for a strip
	# that reaches three rows late in a run — so the last row simply fell off
	# the bottom of the screen.
	var strip_width: float = _root_size().x - _panel_inset() * 2.0
	_owned_row.position = Vector2(_panel_inset(), 0.0)
	_owned_row.size = Vector2(strip_width, 0.0)
	# Q24: pinned to the span's left edge the strip sat in the bottom-left
	# corner, visually detached from the centred handscroll above it. Centred
	# wells read as belonging to the paper in either orientation.
	_owned_row.alignment = FlowContainer.ALIGNMENT_CENTER
	# QA F5: the flow container's own minimum overrides the analytic height —
	# 27 harness weapons wrapped to four real rows, the clip box stayed at
	# two, and the strip walked off the screen. The rows never exceed the
	# budget now: wells past it collapse into one "+N" cell, so the analytic
	# height and the real height are the same number.
	var short_canvas: bool = not landscape and _root_size().y < DESIGN_HEIGHT
	var per_row: int = maxi(
		int((strip_width + OWNED_ROW_GAP) / (OWNED_WELL_SIZE + OWNED_ROW_GAP)), 1
	)
	var row_budget: int = owned_strip_rows(
		owned_levels.size(), strip_width, landscape, short_canvas
	) * per_row
	_build_owned_row(owned_levels, weapons, row_budget)
	var strip_height: float = owned_strip_height(
		owned_levels.size(), strip_width, landscape, short_canvas
	)
	# The strip is pinned to the bottom of the SCREEN and the panel is cut to
	# what is left above it. Deriving the strip's y from the panel's height
	# instead let every rounding difference push it further down until the last
	# row hung off the edge — measured 13px over at level 20, three rows deep.
	# Gap below as well as above: pinned flush to the edge, the wells' level
	# badges sat on the screen's last pixels and read as cut off.
	var strip_top: float = _root_size().y - strip_height - strip_gap * 2.0
	var reserve: float = _root_size().y - strip_top + strip_gap
	var available: float = _root_size().y - top - reserve
	var estimated: float = panel_height_for(
		stack_heights, _panel_style_margins_y(), _header_height(), _body_margin()
	)
	# Owner (가로모드에서 파워업 시 밑에 빈공간이 너무 많은데): landscape used to
	# take the WHOLE band because the height estimate kept running short — but
	# both of that era's silent line-eaters are gone now (the column line-count
	# off-by-one has its headroom, and the CRLF phantom breaks are fixed at the
	# source), so the estimate is trusted again in both orientations. The sweep's
	# no-scroll assertion across all 22 combinations is the guard that put it
	# back, and what re-opens this if the estimate ever lies again.
	var panel_height: float = minf(estimated, available)
	# Owner (아래 무기 종류 레벨 보여주는게 너무 떨어져있어 두루마리 아래로,
	# 세로 모드 일때도): the strip rides right under the scroll in BOTH
	# orientations — screen-bottom pinning left a gulf between them once the
	# paper stopped taking the whole band. Landscape centres scroll + strip
	# as one block; portrait keeps its top anchor and the strip follows.
	var block: float = panel_height + strip_gap + strip_height
	if landscape:
		top = maxf(
			PANEL_TOP_LANDSCAPE,
			(_root_size().y - block) / 2.0
		)
	else:
		# F15: one short card left the sheet pinned high with 500px of night
		# under it — portrait centres the scroll+strip block too, but never
		# ABOVE its designed top inset, so a full three-card sheet sits
		# exactly where it always did.
		top = maxf(top, (_root_size().y - block) / 2.0)
	strip_top = top + panel_height + strip_gap
	_apply_panel_band()
	_panel.offset_top = top
	_panel.offset_bottom = top + panel_height
	# Rows beyond the reserve are cut cleanly rather than half-drawn off the
	# screen edge. Only the harness (every weapon owned at once) ever reaches
	# past the cap; a run's four weapons are one row.
	_owned_row.clip_contents = true
	_owned_row.position = Vector2(_panel_inset(), strip_top)
	_owned_row.size = Vector2(strip_width, strip_height)
	# The scroll unrolls only when the popup APPEARS. A queue of level-ups swaps
	# content on an already-open scroll — re-rolling dozens of times a run would
	# turn the flourish into a wait.
	# Tree-less callers (the headless layout tests build this popup bare) get
	# the finished state — a tween needs a SceneTree to drive it. And the tree
	# must be PAUSED: in play this screen only ever opens over a paused run,
	# while layout_sweep and the harnesses open it unpaused to MEASURE it — and
	# measuring mid-unroll read a half-rolled scroll as an overflow on every
	# device at once.
	if not visible and is_inside_tree() and get_tree().paused:
		if landscape:
			_unroll_wide()
		else:
			_unroll(top, top + panel_height)
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
	# F31: +4 sat the badge on the well's border. Clear of it now — and the
	# name line starts right where the badge row ends (27 = 7 + 20), because
	# the landscape 540 budget is counted to the pixel.
	well_label.position = Vector2(WELL_MARGIN, WELL_MARGIN + WELL_SIZE + 7.0)
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


static func panel_height_for(
	card_heights: Array[float], style_margins_y: float,
	header_height: float = HEADER_HEIGHT, body_margin: float = BODY_MARGIN
) -> float:
	var cards_total: float = 0.0
	for height: float in card_heights:
		cards_total += height
	cards_total += CARD_GAP * float(maxi(card_heights.size() - 1, 0))
	return style_margins_y + header_height + body_margin * 5.0 + cards_total


## Owned-strip wrap math (N4-7), static so the layout test can prove the
## strip fits the reserve at the data's maximum owned-weapon count. Entries
## are OWNED_WELL_SIZE wide — the level label under the well is narrower.
## Chrome sizes for the orientation on screen: a short screen spends less of
## itself on the frame around the cards.
func _header_height() -> float:
	if _is_landscape():
		return HEADER_HEIGHT_LANDSCAPE
	return HEADER_HEIGHT * _portrait_squeeze()


func _body_margin() -> float:
	if _is_landscape():
		return BODY_MARGIN_LANDSCAPE
	return BODY_MARGIN * _portrait_squeeze()


## Chrome-only shrink factor for canvases under the 960 design height (owner:
## 스크롤이 제일 싫어) — the frame pays, the cards never do. Shared by the
## height estimate and the placement code, which is what keeps them honest.
func _portrait_squeeze() -> float:
	return clampf(_root_size().y / DESIGN_HEIGHT, 0.85, 1.0)


static func owned_strip_rows(
	count: int, strip_width: float, landscape: bool = false, short_canvas: bool = false
) -> int:
	var per_row: int = maxi(
		int((strip_width + OWNED_ROW_GAP) / (OWNED_WELL_SIZE + OWNED_ROW_GAP)), 1
	)
	var cap: int = OWNED_MAX_ROWS_LANDSCAPE if landscape else OWNED_MAX_ROWS
	# A squeezed phone canvas (under the 960 design height) cannot pay for a
	# second strip row without the cards scrolling — and 스크롤이 제일 싫다.
	# One row plus the +N overflow badge; a real run's four weapons never
	# wrap anyway, only the own-everything harness does.
	if short_canvas:
		cap = 1
	# Two rows is the ceiling. A run holds four weapons, so real play never
	# reaches it; the popup harness owns all twenty-seven at once, and letting
	# that reserve four rows would push the card being chosen off the paper.
	# Reference beats choice only until it starts costing the choice.
	return mini(int(ceilf(float(count) / float(per_row))), cap)


static func owned_strip_height(
	count: int, strip_width: float, landscape: bool = false, short_canvas: bool = false
) -> float:
	var rows: int = owned_strip_rows(count, strip_width, landscape, short_canvas)
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
	# N10-16: the bottom pad is a full well margin in portrait, where the card is
	# a wide row with air to spare. A landscape column is the tight axis — on a
	# 540 canvas the cards asked for three pixels more than the band could ever
	# give — and half a margin under the last line still reads as a margin.
	# The line count divides by height PLUS spacing while measured.y carries no
	# spacing, so a description one line from the boundary is counted short and
	# its last line renders past the card. One line of headroom covers that off
	# by one — and it is why the landscape panel needed a slack constant before:
	# the shortfall was here, not in the panel.
	# One line of headroom because the line count divides by height PLUS spacing
	# while measured.y carries no spacing, so a description one line from the
	# boundary is counted short and renders past the card. No bottom pad in a
	# column: the headroom already reads as one, and on a 540 canvas the band is
	# hard-capped — every pixel here is one the cards do not get.
	return maxf(
		CARD_COLUMN_HEIGHT_MIN, COLUMN_DESC_TOP + text_height + line_height
	)


## Equal column split of the body width; floored so a pathological card count
## scrolls horizontally instead of crushing the columns. Static for the test.
static func column_width_for(avail_width: float, count: int) -> float:
	var n: int = maxi(count, 1)
	# Floored: a fractional split makes the row 1-2px wider than the scroll
	# area and summons a pointless horizontal scrollbar.
	return clampf(
		floorf((avail_width - CARD_GAP * float(n - 1)) / float(n)),
		CARD_COLUMN_MIN_WIDTH, CARD_COLUMN_MAX_WIDTH
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


## Owner (파워 업 시에 저 두루마리가 펼쳐지면서 내용이 나왔으면). The top
## roller holds still and the paper pays out downward — the bottom cap of the
## 9-slice rides the moving bottom edge, which IS the unroll, no extra art.
## Content fades in over the second half so text never sits on half-open paper.
## The tween binds to this popup, which processes while the tree is paused —
## that is the only time this screen exists.
const UNROLL_SEC := 0.35
var _unroll_target: float = 0.0
var _unroll_tween: Tween


func _unroll(top: float, bottom: float) -> void:
	_unroll_target = bottom
	if _unroll_tween != null:
		_unroll_tween.kill()
	var style: StyleBox = _panel.get_theme_stylebox("panel")
	var rolled: float = minf(
		style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM), bottom - top
	)
	_panel.clip_contents = true
	_panel.offset_bottom = top + rolled
	_layout.modulate.a = 0.0
	_unroll_tween = create_tween()
	_unroll_tween.tween_property(
		_panel, "offset_bottom", bottom, UNROLL_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_unroll_tween.parallel().tween_property(
		_layout, "modulate:a", 1.0, UNROLL_SEC * 0.5
	).set_delay(UNROLL_SEC * 0.5)
	_unroll_tween.finished.connect(_end_unroll, CONNECT_ONE_SHOT)


## The landscape unroll: both rollers travel outward from the middle, like a
## handscroll opened with two hands. The final offsets are whatever
## _apply_panel_band just set, so this animates toward them rather than
## re-deriving the band.
func _unroll_wide() -> void:
	if _unroll_tween != null:
		_unroll_tween.kill()
	var final_left: float = _panel.offset_left
	var final_right: float = _panel.offset_right
	var style: StyleBox = _panel.get_theme_stylebox("panel")
	var rolled: float = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	var center: float = (_root_size().x + final_left + final_right) / 2.0
	_panel.clip_contents = true
	_panel.offset_left = center - rolled * 0.5
	_panel.offset_right = center + rolled * 0.5 - _root_size().x
	_layout.modulate.a = 0.0
	_unroll_tween = create_tween()
	_unroll_tween.tween_property(
		_panel, "offset_left", final_left, UNROLL_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_unroll_tween.parallel().tween_property(
		_panel, "offset_right", final_right, UNROLL_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_unroll_tween.parallel().tween_property(
		_layout, "modulate:a", 1.0, UNROLL_SEC * 0.5
	).set_delay(UNROLL_SEC * 0.5)
	_unroll_tween.finished.connect(_end_unroll, CONNECT_ONE_SHOT)


func _end_unroll() -> void:
	_panel.clip_contents = false


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
func _build_owned_row(
	owned_levels: Dictionary, weapons: Dictionary, budget: int = 0
) -> void:
	var shown: int = 0
	var hidden: int = 0
	for weapon_id: String in owned_levels:
		if budget > 0 and shown >= budget - (1 if owned_levels.size() > budget else 0):
			hidden += 1
			continue
		shown += 1
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
	if hidden > 0:
		var more := _label(
			"+%d" % hidden, UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_ON_DARK
		)
		more.custom_minimum_size = Vector2(OWNED_WELL_SIZE, OWNED_WELL_SIZE)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_owned_row.add_child(more)


func _make_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = _header_height()
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
