class_name MetaTreeScreen
extends Control
## 명부수 permanent-upgrade screen (N7-1, branches N7-2, DESIGN.md §4 capture
## `_02`): NIGHT_BROWN meta grammar — back arrow + GOLD title top-left,
## currency pill top-right, pill tabs (공용 trunk + one branch per roster
## character), a scrollable node graph over a trunk in the middle, and the
## selected node's detail card + one full-width wood CTA at the bottom.
## Locked characters' branches render as visible locked content with their
## unlock condition named — never purchasable, never dead chrome.
## All purchase rules live in MetaTree; this screen only renders and routes.

const CAMP_SCENE := "res://scenes/camp.tscn"

const MARGIN_SIDE := 24
const MARGIN_TOP := 24
const MARGIN_BOTTOM := 32
const NODE_SIZE := 56.0
const NODE_ICON_SIZE := 32.0
## QA gate F1 (N11-9): the two caption columns sit 0.44 of the usable width
## apart, so on a narrow canvas a fixed 150px caption overlaps its row
## neighbour glyph-on-glyph. The width adapts until caption <= separation
## (solving w <= 0.44*(canvas-w) - gap), floored so a caption stays a word.
## Owner (가로모드도 어색하고 자꾸 스크롤이 생길정도라서 크기를 조금씩 줄여도
## 될 것 같아): a landscape phone has barely 200px of tree band, so a row pitch
## built for a 960-tall screen showed one row and a scrollbar. The nodes keep
## their size — they are touch targets and the circle art is built once — and
## the SPACING between rows carries the reduction instead.
## Wide enough for the detail card's icon well plus two lines of effect text.
## QA N11-14 F-8: the landscape panel held 210px of dead night under its card
## (38.9% of the screen height) while the tree was squeezed into 508x368. The
## panel keeps what the card and CTA actually need; the tree takes the rest.
const SIDE_WIDTH_LANDSCAPE := 300.0
const NODE_BORDER_WIDTH := 3
const EDGE_WIDTH := 3.0
const TRUNK_WIDTH := 10.0
## N11-12 (owner: 가운데 있고 위·아래·옆으로 퍼져나가서 스크롤이 아니라 전체
## 화면으로): the tab lays out as a RADIAL mindmap — a hub in the middle,
## flat nodes on a golden-angle elliptical spiral filling the whole canvas,
## chained nodes pushed outward past their parent. Nothing scrolls; the
## canvas is the viewport and the spiral is scaled to fit it.
const GOLDEN_ANGLE := 2.399963
## The hub is drawn from the live cell size (see _hub_side) — this is only
## the floor for a canvas too small to give it one.
const HUB_RADIUS := 26.0
## Owner (노드들끼리 간격도 다 다르고): the gap a ring keeps from the next.
const RING_GAP := 14.0
## Each ring out shrinks its discs by this much, down to NODE_SIZE_MIN.
const RING_TAPER := 0.84
const NODE_SIZE_MIN := 34.0
## Where a lone ring of roots sits when the tab has no revealed depth yet.
const SINGLE_RING := 0.62
## The closest the first ring sits to the hub when the rings have room to
## spread — a ring pinned against the hub face reads as a clump.
const FIRST_RING_MIN := 0.44
## How many rings of the chain the canvas shows at once — a portrait radius of
## ~230px seats this many readable discs, and past it the links stop being
## legible at all.
const VISIBLE_DEPTH := 3
## The grid web: how many cells the short side is cut into, the disc's share
## of a cell, and the compass order a chain walks.
const GRID_SPAN := 7.0
const CELL_MIN := 46.0
const CELL_MAX := 96.0
## Owner (제대로 마인드맵부터): at 0.78 the tiles touched and the whole tab
## read as a brick wall of inventory slots — the links, which are what makes
## it a map, had nowhere to show. A tile now takes well under its cell.
const CELL_FILL := 0.62
## The isometric lattice's horizontal and vertical pitch, as a share of a cell.
const ISO_X := 1.0
const ISO_Y := 1.0
## Owner reference: square tiles with a soft corner, not discs.
const TILE_RADIUS := 10
## One hue per branch family, in the kit's own range — earth reds, ink blues,
## The one plate every tile wears, and the three edges that say its state.
const TILE_PLATE := Color("#1d1a17")
const TILE_LOCKED_EDGE := Color("#4a453f")
const TILE_READY_EDGE := Color("#7ea86a")
## How far a state mark sits outside the tile it belongs to.
const TILE_MARK_PAD := 10.0
const GRID_RING: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
## How far an over-deep node steps aside inside its own wedge, and how far it
## pulls back in, so a tail deeper than the canvas never stacks on its parent.
const OVERFLOW_FAN := 0.34
const OVERFLOW_PULL := 0.17
const RADIAL_PAD := 10.0
## Owner (곡선말고 직선으로 여러 갈래로): a chain runs STRAIGHT out along its
## root's bearing. Only a real fork opens an angle, and both forked arms
## then run straight again — no per-step curl.
const CHAIN_FAN := 0.42
## A fork never opens wider than this share of the gap to the next spoke.
const FORK_GAP_SHARE := 0.38
## N11-11/N11-14: every node hangs off the hub (or its requires parent) by a
## straight drawn line, so the tree reads as spokes spreading, not a list.
## Locked links dash at this length.
const DASH_LENGTH := 7.0
const PULSE_PERIOD_SEC := 1.6
## QA I-11: clear of the hover-scaled disc (39.6px) through the whole cycle.
const PULSE_RING_PAD := 8.0
## QA I-8: only the CHEAPEST few breathe — 22 rings breathing at once point
## nowhere. The rest of the buyable set wears a static wood ring.
const PULSE_LIMIT := 4
## QA I-5: branches GROW out of the hub when a tab opens.
const GROW_SEC := 0.35
## Owner (숨어있던 노드들이 나와야 / 애니메이션도 별로): a revealed node swells
## past its size and settles, so an opening reads as an arrival.
const REVEAL_SEC := 0.42
const REVEAL_OVERSHOOT := 0.22
const PULSE_RING_SWING := 2.5
## The gap the selection mark leaves at each diagonal, so it reads as four
## arcs rather than a closed ring.
const SELECT_ARC_GAP := 0.16
const HOVER_SCALE := 1.1
const HOVER_TWEEN_SEC := 0.1
const PRESS_PUNCH_SCALE := 0.92
const BURST_SEC := 0.5
const BURST_RADIUS_FROM := NODE_SIZE * 0.5
const BURST_RADIUS_TO := NODE_SIZE * 1.6
const PILL_CORNER_RADIUS := UiPalette.PILL_RADIUS
const PILL_PADDING_X := UiPalette.PILL_PAD_X
const PILL_PADDING_Y := UiPalette.PILL_PAD_Y
const CARD_CORNER_RADIUS := 12
const CARD_PADDING := 14
const CARD_ICON_WELL := 64.0
## The glyph inside that well — the well is the frame, not the icon.
const CARD_ICON_SIZE := 36.0
const COIN_ICON_SIZE := 28.0
const BACK_SIZE := 44.0
const CTA_HEIGHT := 60
const TAB_HEIGHT := 40
const DETAIL_MIN_HEIGHT := 96.0
## QA N11-14 F-1: the effect line never grows past this, so the card keeps one
## height and the graph canvas never resizes under a tap.
const DETAIL_EFFECT_LINES := 2
const DETAIL_INFO_LINES := 2
const NOTICE_FADE_SEC := 1.4
## Locked node icons dim by alpha only — no raw color values outside palette.
const LOCKED_ICON_ALPHA := 0.35
## The shared-trunk tab id; character tabs use the roster id.
const TAB_TRUNK := ""
## QA gate I-3: 34 trunk nodes cannot hold 62px spacing on a landscape
## canvas (needed area 130k > available 109k) — the 17 refine migrants get
## their own tab, and every tab fits its ellipse with room to breathe.
const TAB_REFINE := "_refine"
const REFINE_PREFIX := "refine_"

var _tree: Dictionary = {}
var _characters: Dictionary = {}
var _unlocked: Array[String] = []
var _current_tab: String = TAB_TRUNK
var _selected_id: String = ""
## Test/tool fallback profile when the SaveManager autoload is absent; with
## SaveService live this mirrors its profile and purchases go through it.
var _profile: Dictionary = SaveProfile.default_profile()

var _canvas: Control
## N11-11 living-graph state: breathing phase for purchasable nodes, and the
## one-shot purchase bursts ({"at": Vector2, "t": float}) still expanding.
var _pulse_phase: float = 0.0
var _bursts: Array[Dictionary] = []
## Owner (숨어있던 노드들이 나와야): ids that just appeared, and how far into
## their arrival they are — they scale up from nothing while the rest holds.
var _reveal_ids: Array[String] = []
## QA N11-14 F-5/F-6: the settled disc size per node, tapering ring by ring.
var _node_sizes: Dictionary = {}
## Where the hub cell landed after the web was centred on its own extent.
var _hub_pos: Vector2 = Vector2.ZERO
## The grid pitch the last layout settled on; the hub and the state marks are
## drawn from it so they always match the tiles.
var _cell: float = 0.0
var _reveal_phase: float = 1.0
## QA I-5 growth fraction (0..1) the branch drawing honors; I-10 tween store.
var _grow: float = 1.0
## QA I-3: the per-layout disc scale the convergence fallback settles on.
var _node_scale: float = 1.0
var _grow_tween: Tween
var _node_tweens: Dictionary = {}
var _scroll: ScrollContainer
var _gold_label: Label
var _detail_name: Label
var _detail_info: Label
var _detail_effect: Label
var _detail_icon: TextureRect
var _cta: Button
## QA N11-14 F-1: the reserved row the CTA lives in, so showing or hiding the
## button never resizes the graph canvas.
var _cta_slot: Control
## The tree row and the panel beside (landscape) or below (portrait) it.
var _body: HBoxContainer
var _side: VBoxContainer
var _side_slack: Control
var _side_in_row: bool = false
var _notice_label: Label
var _notice_tween: Tween
var _tab_buttons: Dictionary = {}
var _node_buttons: Dictionary = {}
## N11-12: one floating caption, under the SELECTED node only — a radial
## full-fit view has no room for 69 standing labels, and the detail card
## already carries the words. var name kept singular on purpose.
var _focus_caption: Label
## node_id -> canvas-space center, rebuilt per tab/resize by _layout_nodes.
var _radial: Dictionary = {}


func _ready() -> void:
	build_ui()
	# QA I-5: the first screen entry grows too, not just tab switches.
	_start_growth()


## Builds every child node. Public so the headless test can construct the
## screen without a running SceneTree (same contract as CampScreen).
func build_ui() -> void:
	_tree = MetaTree.load_tree()
	_characters = MetaTree.load_characters()
	_profile = _live_profile()
	# QA gate F3: the profile decides which branches sell (achievement
	# unlocks included) — read it BEFORE asking who is purchasable.
	_unlocked = MetaTree.unlocked_characters(_characters, _profile)
	# Corrupt or stale tree state heals once, up front — the whole screen
	# then renders from clean state only. N7-2 migration: nodes the rework
	# removed are pruned here (with this warning) and NOT refunded.
	var clean: Dictionary = MetaTree.sanitize_state(
		_tree, _profile.get("meta_tree", {}) as Dictionary
	)
	if int(clean["dropped"]) > 0:
		push_warning(
			"meta_tree_screen: dropped %d invalid tree entries" % int(clean["dropped"])
		)
	_profile["meta_tree"] = clean["state"]

	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.NIGHT_BROWN
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_right", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_top", MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_tabs())

	# Owner (가로모드도 어색하고 자꾸 스크롤이 생길정도라서): stacked, the detail
	# card and the buy button eat most of a 540-tall landscape screen and leave
	# the tree a band barely one row deep — every visit opened on a scrollbar.
	# Landscape spends its width instead: the tree on the left, what you do with
	# it on the right. The children are the same nodes either way, so a flip
	# re-parents them rather than rebuilding the tab.
	_body = HBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override("separation", UiPalette.SPACE_LG)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)

	_side = VBoxContainer.new()
	_side.name = "Side"
	_side.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_body.add_child(_build_graph())
	_side.add_child(_build_detail_card())

	_notice_label = _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.GOLD)
	_notice_label.name = "Notice"
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side.add_child(_notice_label)

	# Q23: in landscape the side pane runs the body's full height with the
	# card, notice and CTA huddled at the top — ~300px of dead panel under
	# them. The slack pins the CTA to the bottom edge instead, where the
	# thumb already is. Landscape-only: _place_side toggles it, because the
	# portrait pane ALSO stretches (verify-QA caught a 230px card-to-CTA gap
	# there — the "portrait collapses it to zero" assumption was wrong).
	_side_slack = Control.new()
	_side_slack.name = "SideSlack"
	_side_slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(_side_slack)

	# QA N11-14 F-1: the CTA appearing on selection stole 76-98px from the
	# portrait canvas and the whole tree jumped under the finger. The slot is
	# reserved always; only the button inside it comes and goes.
	_cta_slot = Control.new()
	_cta_slot.name = "CtaSlot"
	_cta_slot.custom_minimum_size = Vector2(0.0, CTA_HEIGHT)
	_side.add_child(_cta_slot)

	_cta = Button.new()
	_cta.name = "CtaButton"
	_cta.set_anchors_preset(Control.PRESET_FULL_RECT)
	WoodButton.apply(_cta)
	_cta.pressed.connect(_on_cta_pressed)
	_cta_slot.add_child(_cta)
	_place_side()
	resized.connect(_place_side)

	_populate_tab()
	_refresh()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UiPalette.SPACE_SM)

	var back := Button.new()
	back.name = "BackButton"
	# N10-24: the kit's framed back arrow replaces the "‹" glyph. When the
	# piece is missing the text stays, so the button never becomes invisible.
	var arrow: TextureRect = UiIcons.kit_icon_button("btn_left", BACK_SIZE * 0.72)
	if arrow != null:
		arrow.set_anchors_preset(Control.PRESET_CENTER)
		arrow.position = -arrow.custom_minimum_size / 2.0
		back.add_child(arrow)
	else:
		back.text = "‹"
	back.flat = true
	back.custom_minimum_size = Vector2(BACK_SIZE, BACK_SIZE)
	back.add_theme_color_override("font_color", UiPalette.GOLD)
	back.add_theme_color_override("font_hover_color", UiPalette.GOLD)
	back.add_theme_color_override("font_pressed_color", UiPalette.GOLD_BORDER)
	back.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	back.pressed.connect(_on_back_pressed)
	header.add_child(back)

	var title := _label(UiLocale.text("meta.title"), UiPalette.FONT_SIZE_TITLE, UiPalette.GOLD)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var pill := PanelContainer.new()
	pill.name = "GoldPill"
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = UiPalette.CARD_BG
	pill_box.border_color = UiPalette.CARD_BORDER_DIM
	pill_box.set_border_width_all(NODE_BORDER_WIDTH)
	pill_box.set_corner_radius_all(PILL_CORNER_RADIUS)
	pill_box.content_margin_left = PILL_PADDING_X
	pill_box.content_margin_right = PILL_PADDING_X
	pill_box.content_margin_top = PILL_PADDING_Y
	pill_box.content_margin_bottom = PILL_PADDING_Y
	pill.add_theme_stylebox_override("panel", pill_box)
	var pill_row := HBoxContainer.new()
	pill_row.name = "PillRow"
	pill_row.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	pill_row.add_child(UiIcons.icon_rect(UiIcons.hud_icon("coin"), COIN_ICON_SIZE))
	_gold_label = _label("0", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
	_gold_label.name = "GoldValue"
	pill_row.add_child(_gold_label)
	pill.add_child(pill_row)
	header.add_child(pill)
	return header


## N7-2 pill tabs (bestiary grammar): 공용 trunk first, then one tab per
## roster character — locked ones stay tappable so the branch advertises the
## roster instead of hiding it.
func _build_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	var tab_ids: Array[String] = [TAB_TRUNK, TAB_REFINE]
	for character_id: String in _characters:
		tab_ids.append(character_id)
	for tab_id: String in tab_ids:
		var tab := Button.new()
		tab.name = "Tab_" + (tab_id if not tab_id.is_empty() else "shared")
		tab.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Five tabs on a 486 canvas: the long en captions ("Wolyeong ·
		# Locked") must yield by ellipsis or the row shoves the last tab off
		# the screen — the pill still reads by its leading name.
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
		tab.add_theme_color_override("font_hover_color", UiPalette.TEXT_ON_DARK)
		tab.add_theme_color_override("font_pressed_color", UiPalette.TEXT_ON_DARK)
		tab.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		tab.pressed.connect(_on_tab_pressed.bind(tab_id))
		tabs.add_child(tab)
		_tab_buttons[tab_id] = tab
	return tabs


func _on_tab_pressed(tab_id: String) -> void:
	if tab_id == _current_tab:
		return
	_current_tab = tab_id
	_selected_id = ""
	# QA F-10: the biggest state change on the screen gets a click.
	_play_sfx("ui_click")
	# QA I-12: a burst belongs to the tab it was bought on.
	_bursts.clear()
	_populate_tab()
	_refresh()
	_start_growth()


## QA I-5: the branches GROW out of the hub over a third of a second when a
## tab opens — the spreading is a moment, not a still.
func _start_growth() -> void:
	if not is_inside_tree():
		_grow = 1.0
		return
	if _grow_tween != null and _grow_tween.is_valid():
		_grow_tween.kill()
	_grow = 0.0
	_grow_tween = create_tween()
	_grow_tween.tween_property(self, "_grow", 1.0, GROW_SEC).set_ease(Tween.EASE_OUT)
	_grow_tween.finished.connect(func() -> void:
		for node_id: Variant in _node_buttons:
			(_node_buttons[node_id] as Button).scale = Vector2.ONE
	)
	if is_inside_tree():
		_scroll.scroll_vertical = 0


func _build_graph() -> Control:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# N11-12: the radial map fits the viewport whole — the container stays
	# for its layout slot, but nothing ever scrolls.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Tapping the empty canvas deselects; node buttons swallow their own taps.
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.draw.connect(_draw_graph)
	_canvas.resized.connect(_layout_nodes)
	_scroll.add_child(_canvas)
	return _scroll


## (Re)builds the node buttons for the current tab — the graph shows ONE
## branch at a time so a much larger total tree still reads on 540x960.
func _populate_tab() -> void:
	for button: Button in _node_buttons.values():
		button.queue_free()
	_node_buttons.clear()
	_radial.clear()
	_canvas.custom_minimum_size = Vector2.ZERO
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in _revealed_nodes():
		var node_id: String = String(entry["id"])
		var button := Button.new()
		button.name = "Node_" + node_id
		button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		button.size = Vector2(NODE_SIZE, NODE_SIZE)
		button.pressed.connect(_on_node_pressed.bind(node_id))
		# N11-11 hover/press feel: scale breathes up under the pointer and
		# punches on the tap, with the shared UI ticks. Pivot at the disc's
		# middle or the scale walks the button diagonally.
		button.pivot_offset = Vector2(NODE_SIZE, NODE_SIZE) / 2.0
		button.mouse_entered.connect(_on_node_hover.bind(button, true))
		button.mouse_exited.connect(_on_node_hover.bind(button, false))
		var icon: TextureRect = UiIcons.icon_rect(
			UiIcons.tree_icon(String(entry.get("tree_icon", ""))), NODE_ICON_SIZE
		)
		icon.name = "Icon"
		# Center inside the circle: PRESET_CENTER alone anchors the icon's
		# top-left, so pin the offsets to the icon's half size explicitly.
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.offset_left = -NODE_ICON_SIZE / 2.0
		icon.offset_top = -NODE_ICON_SIZE / 2.0
		icon.offset_right = NODE_ICON_SIZE / 2.0
		icon.offset_bottom = NODE_ICON_SIZE / 2.0
		button.add_child(icon)
		_canvas.add_child(button)
		_node_buttons[node_id] = button
	if _focus_caption == null or not is_instance_valid(_focus_caption):
		_focus_caption = _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_ON_DARK)
		_focus_caption.name = "FocusCaption"
		_focus_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_focus_caption.add_theme_color_override("font_outline_color", UiPalette.NIGHT)
		_focus_caption.add_theme_constant_override("outline_size", 4)
		_focus_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# QA I-5: night-on-night text over a stray disc was barely legible —
		# the caption sits on its own translucent slate.
		var slate := StyleBoxFlat.new()
		slate.bg_color = Color(UiPalette.NIGHT, 0.72)
		slate.set_corner_radius_all(6)
		slate.set_content_margin_all(6.0)
		_focus_caption.add_theme_stylebox_override("normal", slate)
	if _focus_caption.get_parent() != _canvas:
		if _focus_caption.get_parent() != null:
			_focus_caption.get_parent().remove_child(_focus_caption)
		_canvas.add_child(_focus_caption)
	_focus_caption.visible = false


func _build_detail_card() -> Control:
	var card := PanelContainer.new()
	card.name = "DetailCard"
	# QA N11-14 F-1: a fixed height, not a minimum — the card grew by a line
	# on selection and the canvas paid for it.
	card.custom_minimum_size = Vector2(0.0, DETAIL_MIN_HEIGHT)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var kit: StyleBox = UiIcons.card_panel()
	if kit != null:
		(kit as StyleBoxTexture).set_content_margin_all(CARD_PADDING)
		card.add_theme_stylebox_override("panel", kit)
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = UiPalette.CARD_BG
		box.border_color = UiPalette.CARD_BORDER_DIM
		box.set_border_width_all(NODE_BORDER_WIDTH)
		box.set_corner_radius_all(CARD_CORNER_RADIUS)
		box.set_content_margin_all(CARD_PADDING)
		card.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.name = "DetailRow"
	row.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	card.add_child(row)

	var well := PanelContainer.new()
	well.name = "IconWell"
	well.custom_minimum_size = Vector2(CARD_ICON_WELL, CARD_ICON_WELL)
	var well_box := StyleBoxFlat.new()
	well_box.bg_color = UiPalette.CARD_WELL
	well_box.set_corner_radius_all(CARD_CORNER_RADIUS)
	well.add_theme_stylebox_override("panel", well_box)
	# A PanelContainer stretches its only child to fill, which blew the glyph
	# up into a white slab; the centre box keeps it at its own size.
	var icon_box := CenterContainer.new()
	icon_box.name = "IconBox"
	well.add_child(icon_box)
	_detail_icon = UiIcons.icon_rect(null, CARD_ICON_SIZE)
	_detail_icon.name = "DetailIcon"
	icon_box.add_child(_detail_icon)
	row.add_child(well)

	var lines := VBoxContainer.new()
	lines.name = "DetailLines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	_detail_name = _label("", UiPalette.FONT_SIZE_BODY, UiPalette.INK)
	_detail_name.name = "DetailName"
	lines.add_child(_detail_name)
	_detail_effect = _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.INK)
	# F2: the locked-branch hint routes through this label too (line 55x) —
	# same sentence-width hazard, same wrap.
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_effect.name = "DetailEffect"
	# QA N11-14 F-1: a two-line ceiling with an ellipsis, so a long effect
	# line can never add a row and shove the canvas.
	_detail_effect.max_lines_visible = DETAIL_EFFECT_LINES
	_detail_effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lines.add_child(_detail_effect)
	_detail_info = _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER)
	_detail_info.name = "DetailInfo"
	# QA gate F2 (N11-9): unlock hints and material bills are SENTENCES — a
	# one-line Label's minimum width became the column's minimum and pushed
	# the tab row and the gold pill 664px off the canvas. Wrap collapses the
	# demand to the longest word (the V1/result-sheet grammar).
	_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# QA N11-14 F-1: a node with a material bill adds a second line here, and
	# that line came out of the graph canvas — the taoist tab still moved 22px
	# under a tap. Two lines are reserved always; nodes without a bill simply
	# leave the second one blank.
	_detail_info.custom_minimum_size = Vector2(
		0.0, float(UiPalette.FONT_SIZE_LABEL) * DETAIL_INFO_LINES * 1.35
	)
	_detail_info.max_lines_visible = DETAIL_INFO_LINES
	_detail_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lines.add_child(_detail_info)
	row.add_child(lines)
	return card


## --- selection / purchase -------------------------------------------------


## QA R-1: tab ownership lives in ONE place. The refine split taught
## _tab_nodes a rule select_node never learned, and tapping any refine
## node threw the screen back to the shared tab — all seventeen migrants
## were unselectable and unbuyable.
func _tab_for(node_id: String) -> String:
	var branch: String = MetaTree.node_character(MetaTree.node(_tree, node_id))
	if branch == TAB_TRUNK and node_id.begins_with(REFINE_PREFIX):
		return TAB_REFINE
	return branch


func select_node(node_id: String) -> void:
	# A programmatic select may target another tab (tests, deep links) — the
	# tab follows the node so the selection is always visible.
	var branch: String = _tab_for(node_id)
	if branch != _current_tab:
		_current_tab = branch
		_populate_tab()
	_selected_id = node_id
	_refresh()
	var button: Button = _node_buttons.get(node_id)
	if button != null and is_inside_tree():
		_scroll.ensure_control_visible(button)


func _on_node_pressed(node_id: String) -> void:
	# QA I-9: the TAP is the click sound; hover went silent — a wheel scroll
	# over the map rattled a dozen ticks.
	_play_sfx("ui_click")
	var button: Button = _node_buttons.get(node_id)
	if button != null and is_inside_tree():
		var tween: Tween = _fresh_tween(button)
		tween.tween_property(
			button, "scale", Vector2.ONE * PRESS_PUNCH_SCALE, HOVER_TWEEN_SEC / 2.0
		)
		# QA I-10: the punch settles back to the HOVER scale while the
		# pointer is still on the disc, not past it.
		tween.tween_property(
			button, "scale",
			Vector2.ONE * (HOVER_SCALE if button.is_hovered() else 1.0),
			HOVER_TWEEN_SEC
		)
	select_node(node_id)


func _on_node_hover(button: Button, entered: bool) -> void:
	if not is_inside_tree():
		return
	var tween: Tween = _fresh_tween(button)
	tween.tween_property(
		button, "scale",
		Vector2.ONE * (HOVER_SCALE if entered else 1.0), HOVER_TWEEN_SEC
	).set_ease(Tween.EASE_OUT)


## QA I-10: one live tween per node — a fresh gesture kills the old one, so
## fast in-out passes never stack fighting animations.
func _fresh_tween(button: Button) -> Tween:
	var old_tween: Tween = _node_tweens.get(button.name)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween: Tween = create_tween()
	_node_tweens[button.name] = tween
	return tween


func _play_sfx(sound_id: String) -> void:
	if SfxService.instance != null:
		SfxService.instance.play(sound_id)


## N11-11: the graph breathes — purchasable rings swell on a slow sine and
## finished bursts fall out of the list. Redraws only while this screen is
## the scene, which it always is when visible.
func _process(delta: float) -> void:
	_pulse_phase = fmod(_pulse_phase + delta, PULSE_PERIOD_SEC)
	# QA I-4/F-9: while the tab grows, the discs POP outward with the reach
	# of the branches — center first, rim last — instead of standing complete
	# under lines being drawn.
	if _grow < 1.0:
		var center := _canvas.size / 2.0
		var span: float = maxf(_canvas.size.length() / 2.0, 1.0)
		for node_id: Variant in _node_buttons:
			var button: Button = _node_buttons[node_id]
			var reach: float = (
				(_radial.get(node_id, center) as Vector2) - center
			).length() / span
			var t: float = clampf((_grow - reach * 0.5) / 0.5, 0.0, 1.0)
			button.scale = Vector2.ONE * t
	elif _reveal_phase < 1.0:
		# A freshly opened node arrives on its own: it swells past full size
		# and settles, so the eye is pulled to what the purchase just gave.
		_reveal_phase = minf(_reveal_phase + delta / REVEAL_SEC, 1.0)
		var eased: float = 1.0 - pow(1.0 - _reveal_phase, 3.0)
		for node_id: String in _reveal_ids:
			if not _node_buttons.has(node_id):
				continue
			var button: Button = _node_buttons[node_id]
			var overshoot: float = sin(eased * PI) * REVEAL_OVERSHOOT
			button.scale = Vector2.ONE * (eased + overshoot)
		if _reveal_phase >= 1.0:
			for node_id: String in _reveal_ids:
				if _node_buttons.has(node_id):
					(_node_buttons[node_id] as Button).scale = Vector2.ONE
			_reveal_ids.clear()
	var alive: Array[Dictionary] = []
	for burst: Dictionary in _bursts:
		burst["t"] = float(burst.get("t", 0.0)) + delta
		if float(burst["t"]) < BURST_SEC:
			alive.append(burst)
	_bursts = alive
	if _canvas != null:
		_canvas.queue_redraw()


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_selected_id = ""
		_refresh()


func _on_back_pressed() -> void:
	SceneFadeLayer.go(self, CAMP_SCENE)


## The CTA acts on the CURRENT selection only and every refusal is feedback,
## never a silent dead button. State changes only through the single profile
## fold in MetaTree.purchase (via SaveService when it is alive).
func _on_cta_pressed() -> void:
	if _selected_id.is_empty():
		return
	var before_reveal: Dictionary = _reveal_set()
	var reason: String
	if SaveService.instance != null:
		reason = SaveService.instance.purchase_meta_node(_tree, _selected_id)
		_profile = SaveService.instance.profile
	else:
		var result: Dictionary = MetaTree.purchase(_profile, _tree, _selected_id, _unlocked)
		reason = String(result["reason"])
		_profile = result["profile"]
	match reason:
		MetaTree.REASON_OK:
			_flash_notice(UiLocale.text("meta.bought"))
			# N11-11: the coin lands audibly and the node rings outward once.
			_play_sfx("levelup")
			var entry: Dictionary = MetaTree.node(_tree, _selected_id)
			if not entry.is_empty() and _canvas != null:
				_bursts.append({
					"at": _node_center(entry, _canvas.size.x), "t": 0.0,
				})
			# Owner (숨어있던 노드들이 나와야): the purchase may have opened
			# ground that had nothing on it — rebuild so the new children get
			# buttons, and let them arrive with their own little growth.
			var opened: Array[String] = _newly_revealed(before_reveal)
			if not opened.is_empty():
				_populate_tab()
				_reveal_ids = opened
				_reveal_phase = 0.0
				_play_sfx("chest_open")
		MetaTree.REASON_GOLD:
			_flash_notice(UiLocale.text("meta.no_gold"))
			_play_sfx("ui_close")
		MetaTree.REASON_MATERIALS:
			_flash_notice(UiLocale.text("meta.no_materials"))
			_play_sfx("ui_close")
		MetaTree.REASON_CHARACTER:
			_flash_notice(UiLocale.text("meta.char_locked"))
			_play_sfx("ui_close")
		_:
			# locked/maxed/unknown never expose a CTA; reaching here means a
			# stale click raced a state change — just re-render.
			pass
	_refresh()


## --- rendering ------------------------------------------------------------


func _refresh() -> void:
	_gold_label.text = str(maxi(int(_profile.get("gold", 0)), 0))
	var state: Dictionary = _profile.get("meta_tree", {})
	var gold: int = int(_profile.get("gold", 0))
	_refresh_tabs()
	for entry: Dictionary in _revealed_nodes():
		var node_id: String = String(entry["id"])
		_style_node(entry, node_id, state, gold)
	_refresh_detail(state, gold)
	if _canvas != null:
		_layout_nodes()
		_canvas.queue_redraw()


func _refresh_tabs() -> void:
	for tab_id: String in _tab_buttons:
		var tab: Button = _tab_buttons[tab_id]
		var caption: String = _tab_caption(tab_id)
		var muted: bool = false
		if tab_id != TAB_TRUNK and tab_id != TAB_REFINE:
			if tab_id not in _unlocked:
				caption += " · " + UiLocale.text("meta.locked")
				muted = true
		tab.text = caption
		tab.add_theme_color_override(
			"font_color",
			UiPalette.TEXT_MUTED_ON_DARK if muted else UiPalette.TEXT_ON_DARK
		)
		for state_name: String in ["normal", "hover", "pressed", "focus"]:
			tab.add_theme_stylebox_override(
				state_name, _pill_plate(tab_id == _current_tab)
			)


## True when the visible tab is a character branch the profile cannot buy yet.
func _branch_locked() -> bool:
	return _current_tab != TAB_TRUNK and _current_tab != TAB_REFINE 		and _current_tab not in _unlocked


func _style_node(
	entry: Dictionary, node_id: String, state: Dictionary, gold: int
) -> void:
	var button: Button = _node_buttons[node_id]
	var rank: int = MetaTree.rank_of(state, node_id)
	var unlocked: bool = MetaTree.is_unlocked(_tree, state, node_id)
	var cost: int = MetaTree.next_cost(entry, rank)
	var name_text: String = MetaTree.display_name(entry, UiLocale.current_locale)
	var selected: bool = node_id == _selected_id

	# Owner reference (2026-08-31): every tile is the same dark plate. State is
	# the BORDER and the icon tint — locked grey, within reach green, owned
	# gold — because a board of coloured fills reads as confetti.
	var border: Color = TILE_LOCKED_EDGE
	var fill: Color = TILE_PLATE
	var status: String
	var icon: TextureRect = button.get_node("Icon")
	icon.modulate = Color.WHITE
	icon.modulate.a = 1.0
	if _branch_locked():
		# The whole branch is roster advertising: named, priced, not buyable.
		icon.modulate.a = LOCKED_ICON_ALPHA
		status = UiLocale.text("meta.locked") + " · " \
			+ UiLocale.text("meta.cost_fmt") % cost
	elif rank > 0:
		border = UiPalette.GOLD_BORDER
		if cost == MetaTree.NO_NEXT_COST:
			status = UiLocale.text("meta.max")
		else:
			status = "%d/%d · " % [rank, MetaTree.max_rank(entry)] \
				+ UiLocale.text("meta.cost_fmt") % cost
	elif not unlocked:
		icon.modulate.a = LOCKED_ICON_ALPHA
		status = UiLocale.text("meta.locked") + " · " \
			+ UiLocale.text("meta.cost_fmt") % cost
	elif cost > 0 and gold >= cost:
		# The next affordable step must be findable without color alone: the
		# words 구매 가능 carry the cue, the WOOD border doubles it.
		border = TILE_READY_EDGE
		status = UiLocale.text("meta.available") + " · " \
			+ UiLocale.text("meta.cost_fmt") % cost
	else:
		status = UiLocale.text("meta.cost_fmt") % cost
	# QA I-6: selection no longer re-tints the plate — the gold disc was
	# swallowing the icon, and the icon IS the node's identity. A drawn ring
	# marks the pick instead (see _draw_graph).

	# N11-24: a diamond node draws its own plate on the canvas, so the button
	# behind it stays transparent — two plates would fight.
	var plate: StyleBox = _node_plate(fill, border)
	# The glyph ships white; the tile tints it so icon and edge always agree.
	icon.modulate = Color(border, icon.modulate.a)
	for state_name: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state_name, plate)
	button.add_theme_stylebox_override("focus", _node_plate(fill, UiPalette.GOLD))
	# N11-12: only the SELECTED node speaks on the canvas — everyone else
	# talks through their ring/branch colour and the detail card.
	if selected and _focus_caption != null:
		_focus_caption.text = name_text + "
" + status
		_focus_caption.add_theme_color_override(
			"font_color",
			UiPalette.TEXT_ON_DARK if (unlocked or rank > 0) and not _branch_locked()
			else UiPalette.TEXT_MUTED_ON_DARK
		)
		_place_focus_caption()


func _refresh_detail(state: Dictionary, gold: int) -> void:
	if _selected_id.is_empty():
		_detail_icon.texture = null
		_detail_name.text = UiLocale.text("meta.hint")
		_detail_effect.text = _branch_hint()
		_detail_info.text = ""
		_cta.visible = false
		return
	var entry: Dictionary = MetaTree.node(_tree, _selected_id)
	var rank: int = MetaTree.rank_of(state, _selected_id)
	var cost: int = MetaTree.next_cost(entry, rank)
	var desc: String = MetaTree.display_desc(entry, UiLocale.current_locale)
	_detail_icon.texture = UiIcons.tree_icon(String(entry.get("tree_icon", "")))
	_detail_name.text = MetaTree.display_name(entry, UiLocale.current_locale)

	if _branch_locked():
		# The locked branch names its unlock condition (DESIGN.md: locked
		# content, not a dead button) — straight from characters.json.
		_detail_effect.text = desc
		_detail_info.text = _branch_hint()
		_cta.visible = false
		return
	if not MetaTree.is_unlocked(_tree, state, _selected_id):
		# The lock names its requirement instead of just refusing (edge #2).
		var names: Array[String] = MetaTree.locked_names(
			_tree, state, _selected_id, UiLocale.current_locale
		)
		_detail_effect.text = UiLocale.text("meta.requires_fmt") % ", ".join(names)
		_detail_info.text = UiLocale.text("meta.locked")
		_cta.visible = false
		return
	if cost == MetaTree.NO_NEXT_COST:
		# Maxed: the CTA disappears rather than sit greyed-out (DESIGN.md §6).
		_detail_effect.text = UiLocale.text("meta.maxed_fmt") % desc
		_detail_info.text = _detail_info_line()
		_cta.visible = false
		return
	# The card always describes the NEXT rank, not rank 1 (edge #4).
	_detail_effect.text = UiLocale.text("meta.next_fmt") % [
		desc, rank + 1, MetaTree.max_rank(entry)
	]
	_detail_info.text = _detail_info_line()
	# N9-162: the rank's material bill rides the info line — each item as
	# 이름 xN with the pouch count beside it, red-flagged when short.
	var bill: Dictionary = MetaTree.next_materials(entry, rank)
	var pouch: Dictionary = _profile.get("materials", {})
	var affordable: bool = gold >= cost and MetaTree.has_materials(pouch, bill)
	if not bill.is_empty():
		var parts: Array[String] = []
		for loot_id: String in bill:
			parts.append("%s x%d (%d)" % [
				UiLocale.data_name(_loot_entry(loot_id), loot_id),
				int(bill[loot_id]), int(pouch.get(loot_id, 0)),
			])
		_detail_info.text += "
" + UiLocale.text("meta.materials_fmt") % ", ".join(parts)
	_cta.visible = true
	# QA-2: grey the CTA when unaffordable so it doesn't invite dead taps.
	_cta.disabled = not affordable
	if affordable:
		_cta.text = UiLocale.text("meta.buy_fmt") % cost
	elif gold < cost:
		_cta.text = UiLocale.text("meta.short_fmt") % cost
	else:
		_cta.text = UiLocale.text("meta.no_materials")


## Branch tabs remind whose runs the node applies to; the trunk stays quiet.
func _detail_info_line() -> String:
	if _current_tab == TAB_TRUNK or _current_tab == TAB_REFINE:
		return UiLocale.text("meta.permanent")
	return UiLocale.text("meta.branch_only_fmt") % MetaTree.display_name(
		_characters.get(_current_tab, {}) as Dictionary, UiLocale.current_locale
	)


## The locked branch's unlock condition, straight from characters.json.
func _branch_hint() -> String:
	if not _branch_locked():
		return ""
	var character: Dictionary = _characters.get(_current_tab, {})
	var key: String = "unlock_text_en" if UiLocale.current_locale == "en" \
		else "unlock_text_ko"
	return String(character.get(key, UiLocale.text("meta.char_locked")))


## Positions every node/caption from its data pos; runs on canvas resize so
## the fractional x coordinates track the actual width.
func _layout_nodes() -> void:
	if _canvas.size.x <= 0.0 or _canvas.size.y <= 0.0:
		return
	_compute_radial()
	for entry: Dictionary in _revealed_nodes():
		var node_id: String = String(entry["id"])
		if not _node_buttons.has(node_id):
			continue
		var button: Button = _node_buttons[node_id]
		var half: float = _node_size_of(node_id) / 2.0
		button.position = (
			(_radial.get(node_id, Vector2.ZERO) as Vector2) - Vector2(half, half)
		)
	# QA N11-14 F-2: the caption is added before the buttons, so it drew UNDER
	# the discs and got clipped by them. Keep it on top of the canvas.
	if _focus_caption != null and is_instance_valid(_focus_caption):
		_focus_caption.move_to_front()
	_place_focus_caption()


## N11-12: the radial layout. Flat nodes walk a golden-angle spiral scaled to
## the canvas ellipse — every step turns ~137.5°, which is what spreads them
## up, down and sideways instead of stacking. A chained node rides its
## parent's bearing a step further out, siblings fanned around it, so a
## requires line always points away from the hub like a growing branch.
func _compute_radial() -> void:
	_radial.clear()
	_node_sizes.clear()
	var entries: Array[Dictionary] = _revealed_nodes()
	if entries.is_empty():
		return
	# QA N11-14 F-4/F-5/F-6: rings could not hold a five-deep chain in a
	# 508x368 landscape canvas — the tail piled onto the outer ring, links
	# became chords across the field and cut through other discs. The tree is
	# a GRID web now: the hub takes the middle cell, every node takes a cell,
	# and a child always lands on a cell NEXT to its parent. Equal cells make
	# the spacing equal everywhere, and a link one cell long cannot reach far
	# enough to cross a third disc.
	var center := _canvas.size / 2.0
	var depth: Dictionary = _depth_map(entries)
	var children: Dictionary = {}
	var roots: Array[String] = []
	for entry: Dictionary in entries:
		var node_id: String = String(entry["id"])
		var requires: Array = entry.get("requires", [])
		var parent_id: String = "" if requires.is_empty() else String(requires[0])
		if parent_id.is_empty() or not depth.has(parent_id) or int(depth[node_id]) == 1:
			roots.append(node_id)
			continue
		var kids: Array = children.get(parent_id, [])
		kids.append(node_id)
		children[parent_id] = kids
	# One cell size for the whole board: big enough to read, small enough that
	# the deepest chain still has cells to walk into.
	var cell: float = clampf(
		minf(_canvas.size.x, _canvas.size.y) / float(GRID_SPAN), CELL_MIN, CELL_MAX
	)
	var cols: int = maxi(int(floor(_canvas.size.x / cell)), 3)
	var rows: int = maxi(int(floor(_canvas.size.y / cell)), 3)
	if cols % 2 == 0:
		cols -= 1
	if rows % 2 == 0:
		rows -= 1
	var half_c: int = (cols - 1) / 2
	var half_r: int = (rows - 1) / 2
	# Owner (중간에 공용 이런거 없애 / 공격력 증가부터 시작해): there is no hub
	# any more. The cheapest root — 공격력 연마 on the refine tab — takes the
	# middle cell and the map grows out of it, so the first thing on screen is
	# a node you can actually buy, not a label.
	var taken: Dictionary = {}
	var cells: Dictionary = {}
	roots.sort_custom(func(a: String, b: String) -> bool:
		return _first_cost(a) < _first_cost(b)
	)
	var dirs: Array[Vector2i] = GRID_RING
	for i: int in roots.size():
		var slot: Vector2i
		if i == 0:
			slot = Vector2i.ZERO
		else:
			var want: Vector2i = dirs[(i - 1) % dirs.size()]
			if i - 1 >= dirs.size():
				want *= 2
			slot = _free_cell(want, want, taken, half_c, half_r)
		taken[slot] = true
		cells[roots[i]] = slot
	# Chains walk outward one cell at a time, keeping their heading when the
	# cell ahead is free and bending to the nearest free neighbour when it is
	# not — so a segment is always one cell long.
	var queue: Array[String] = roots.duplicate()
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		var here: Vector2i = cells[node_id]
		var kids: Array = children.get(node_id, [])
		kids.sort()
		var heading: Vector2i = _cell_heading(here)
		for i: int in kids.size():
			var kid_id: String = String(kids[i])
			var bias: Vector2i = heading if i == 0 else _rotate_cell(
				heading, (i + 1) / 2 * (1 if i % 2 == 1 else -1)
			)
			var slot: Vector2i = _free_cell(here + bias, bias, taken, half_c, half_r)
			taken[slot] = true
			cells[kid_id] = slot
			queue.append(kid_id)
	# Second pass: the cells actually used decide the scale, so a tab with six
	# revealed nodes fills the canvas instead of huddling, and a full tab still
	# fits. The tile's own half-width is part of the budget — sizing on the
	# cell centres alone left the outermost tiles hanging over the edge.
	var lo := Vector2i(0, 0)
	var hi := Vector2i(0, 0)
	for node_id: Variant in cells:
		var slot: Vector2i = cells[node_id]
		lo = Vector2i(mini(lo.x, slot.x), mini(lo.y, slot.y))
		hi = Vector2i(maxi(hi.x, slot.x), maxi(hi.y, slot.y))
	var half_x: float = float(hi.x - lo.x) / 2.0
	var half_y: float = float(hi.y - lo.y) / 2.0
	cell = clampf(
		minf(
			(_canvas.size.x / 2.0 - RADIAL_PAD) / maxf(half_x + CELL_FILL / 2.0, 0.5),
			(_canvas.size.y / 2.0 - RADIAL_PAD) / maxf(half_y + CELL_FILL / 2.0, 0.5)
		), CELL_MIN, CELL_MAX
	)
	# The web is centred on what it occupies, not on the origin cell.
	var shift := Vector2(float(lo.x + hi.x), float(lo.y + hi.y)) / 2.0
	_hub_pos = center - Vector2(shift.x * cell * ISO_X, shift.y * cell * ISO_Y)
	_cell = cell
	var disc: float = cell * CELL_FILL
	for node_id: Variant in cells:
		var slot: Vector2i = cells[node_id]
		_node_sizes[node_id] = disc
		_radial[node_id] = _hub_pos + Vector2(
			float(slot.x) * cell * ISO_X, float(slot.y) * cell * ISO_Y
		)
	_node_scale = 1.0
	_apply_node_sizes()


## The coin price of a node's first rank — the cheapest root anchors the map.
func _first_cost(node_id: String) -> int:
	var costs: Array = MetaTree.node(_tree, node_id).get("costs", [])
	return int(costs[0]) if not costs.is_empty() else 0


## The eight cells around a node, ordered so a search fans out from a bias.
func _free_cell(
	want: Vector2i, bias: Vector2i, taken: Dictionary, half_c: int, half_r: int
) -> Vector2i:
	if _cell_ok(want, taken, half_c, half_r):
		return want
	var origin: Vector2i = want - bias
	for turn: int in [1, -1, 2, -2, 3, -3, 4]:
		var probe: Vector2i = origin + _rotate_cell(bias, turn)
		if _cell_ok(probe, taken, half_c, half_r):
			return probe
	# Everything adjacent is taken: spiral out until something is free, so a
	# crowded board still places every node instead of stacking them.
	for radius: int in range(2, maxi(half_c, half_r) + 1):
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var probe2: Vector2i = origin + Vector2i(dx, dy)
				if _cell_ok(probe2, taken, half_c, half_r):
					return probe2
	return want


func _cell_ok(cell: Vector2i, taken: Dictionary, half_c: int, half_r: int) -> bool:
	if taken.has(cell):
		return false
	return absi(cell.x) <= half_c and absi(cell.y) <= half_r


## Which of the eight compass steps points away from the hub.
func _cell_heading(from: Vector2i) -> Vector2i:
	if from == Vector2i.ZERO:
		return Vector2i(0, -1)
	return Vector2i(signi(from.x), signi(from.y))


## Turns a compass step by `steps` eighths of a circle.
func _rotate_cell(step: Vector2i, steps: int) -> Vector2i:
	var order: Array[Vector2i] = GRID_RING
	var at: int = order.find(step)
	if at < 0:
		at = 0
	return order[posmod(at + steps, order.size())]


## QA N11-14 F-5/F-6: a 231px portrait radius seats barely two full-size
## rings, so every chain deeper than that collapsed onto one ring and its
## links became chords across the field. Discs taper outward instead — the
## ring the node sits on decides its size, which reads as depth and buys the
## room a deep chain needs.
## The board's baseline disc — the grid decides the real size per node, and
## this is the fallback for anything asked about before a layout pass.
func _node_size() -> float:
	return NODE_SIZE * _node_scale


func _ring_size(level: int) -> float:
	return maxf(
		NODE_SIZE * _node_scale * pow(RING_TAPER, float(maxi(level, 1) - 1)),
		NODE_SIZE_MIN * _node_scale
	)


func _node_size_of(node_id: String) -> float:
	return float(_node_sizes.get(node_id, _node_size()))


func _min_separation() -> float:
	var ids: Array = _radial.keys()
	var narrowest: float = INF
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			narrowest = minf(narrowest, (
				(_radial[ids[i]] as Vector2) - (_radial[ids[j]] as Vector2)
			).length())
	return narrowest


## Buttons and icons re-fit the settled disc size after a fallback shrink.
func _apply_node_sizes() -> void:
	for node_id: Variant in _node_buttons:
		var button: Button = _node_buttons[node_id]
		var side: float = _node_size_of(String(node_id))
		button.custom_minimum_size = Vector2(side, side)
		button.size = Vector2(side, side)
		button.pivot_offset = Vector2(side, side) / 2.0
		var icon: TextureRect = button.get_node_or_null("Icon")
		if icon != null:
			var icon_side: float = NODE_ICON_SIZE * (side / NODE_SIZE)
			icon.offset_left = -icon_side / 2.0
			icon.offset_top = -icon_side / 2.0
			icon.offset_right = icon_side / 2.0
			icon.offset_bottom = icon_side / 2.0


func _relax_radial(center: Vector2, radius: Vector2) -> void:
	var min_sep: float = _node_size() + 6.0
	var ids: Array = _radial.keys()
	for _sweep: int in 24:
		var moved: bool = false
		for i: int in ids.size():
			for j: int in range(i + 1, ids.size()):
				var a: Vector2 = _radial[ids[i]]
				var b: Vector2 = _radial[ids[j]]
				var between: Vector2 = b - a
				var distance: float = between.length()
				if distance >= min_sep:
					continue
				var push: Vector2 = (
					between / distance if distance > 0.01
					# A dead-exact stack needs an arbitrary but DETERMINISTIC
					# axis, or the layout differs per run.
					else Vector2.RIGHT.rotated(float(i) * GOLDEN_ANGLE)
				) * (min_sep - distance) / 2.0
				_radial[ids[i]] = a - push
				_radial[ids[j]] = b + push
				moved = true
		var hub_clear: float = HUB_RADIUS + _node_size() / 2.0 + 2.0
		for node_id: Variant in ids:
			var offset: Vector2 = (_radial[node_id] as Vector2) - center
			# Inside the ellipse…
			var unit := Vector2(
				offset.x / maxf(radius.x, 1.0), offset.y / maxf(radius.y, 1.0)
			)
			if unit.length() > 1.0:
				unit = unit.normalized()
				offset = Vector2(unit.x * radius.x, unit.y * radius.y)
			# …and off the hub disc.
			if offset.length() < hub_clear:
				offset = (
					offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
				) * hub_clear
			_radial[node_id] = center + offset
		if not moved:
			break


## The one caption rides under the selected node (N11-12).
func _place_focus_caption() -> void:
	if _focus_caption == null or _selected_id.is_empty() 			or not _radial.has(_selected_id):
		if _focus_caption != null:
			_focus_caption.visible = false
		return
	var at: Vector2 = _radial[_selected_id]
	_focus_caption.visible = true
	_focus_caption.size = Vector2.ZERO
	var want: Vector2 = _focus_caption.get_minimum_size()
	# QA I-5: try below, above, right, left of the disc, and keep the first
	# slot that covers no other node — falling back to the least-covered.
	var half: float = _node_size() / 2.0
	var slots: Array[Vector2] = [
		at + Vector2(-want.x / 2.0, half + 6.0),
		at + Vector2(-want.x / 2.0, -half - 6.0 - want.y),
		at + Vector2(half + 8.0, -want.y / 2.0),
		at + Vector2(-half - 8.0 - want.x, -want.y / 2.0),
		# QA F-6: four diagonals — the cardinal slots all sat on discs in
		# the dense landscape tabs.
		at + Vector2(half + 4.0, half + 4.0),
		at + Vector2(-half - 4.0 - want.x, half + 4.0),
		at + Vector2(half + 4.0, -half - 4.0 - want.y),
		at + Vector2(-half - 4.0 - want.x, -half - 4.0 - want.y),
	]
	var best: Vector2 = slots[0]
	var best_hits: int = 1 << 30
	for slot: Vector2 in slots:
		var clamped := Vector2(
			clampf(slot.x, 4.0, maxf(_canvas.size.x - want.x - 4.0, 4.0)),
			clampf(slot.y, 4.0, maxf(_canvas.size.y - want.y - 4.0, 4.0))
		)
		var rect := Rect2(clamped, want)
		var hits: int = 0
		# A slot that had to be clamped back inside the canvas usually lands
		# on the very disc it describes — count that as a hit so an honest
		# slot elsewhere wins.
		if not clamped.is_equal_approx(slot):
			hits += 2
		if rect.intersects(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)):
			hits += 2
		# The hub face counts as an obstacle — a caption parked over it hid
		# the one label the whole screen is named for.
		var hub_rect := Rect2(
			_canvas.size / 2.0 - Vector2(HUB_RADIUS, HUB_RADIUS),
			Vector2(HUB_RADIUS, HUB_RADIUS) * 2.0
		)
		if rect.intersects(hub_rect):
			hits += 1
		for node_id: Variant in _radial:
			if String(node_id) == _selected_id:
				continue
			var other: Vector2 = _radial[node_id]
			if rect.intersects(Rect2(other - Vector2(half, half), Vector2(half, half) * 2.0)):
				hits += 1
		if hits < best_hits:
			best_hits = hits
			best = clamped
			if hits == 0:
				break
	_focus_caption.position = best


## Row pitch and canvas padding for the orientation on screen right now. Read
## per layout pass, not cached, because _layout_nodes already re-runs on every
## resize — a cached value would be the stale-on-flip bug this pass is fixing.
func _is_landscape() -> bool:
	return size.x > size.y


func _place_side() -> void:
	if _side == null or _body == null:
		return
	var wants_row: bool = _is_landscape()
	if wants_row == _side_in_row and _side.get_parent() != null:
		return
	_side_in_row = wants_row
	if _side_slack != null:
		_side_slack.visible = wants_row
	# F10: with EXPAND in portrait the side pane split the leftover height
	# with the tree and parked 300px of night under its own CTA. Portrait
	# takes its natural height; the tree scroll gets everything else.
	_side.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL if wants_row else Control.SIZE_SHRINK_BEGIN
	)
	if _side.get_parent() != null:
		_side.get_parent().remove_child(_side)
	# The tree takes whatever the panel does not: without this the panel's own
	# minimum width wins the row and the tree collapses to a sliver.
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 1.0
	if wants_row:
		_side.custom_minimum_size = Vector2(SIDE_WIDTH_LANDSCAPE, 0.0)
		_side.size_flags_horizontal = Control.SIZE_SHRINK_END
		_body.add_child(_side)
	else:
		_side.custom_minimum_size = Vector2.ZERO
		_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.get_parent().add_child(_side)
	_layout_nodes()


func _tab_nodes() -> Array[Dictionary]:
	# I-3: the trunk splits — 기본기 on the shared tab, the migrated refine
	# family on its own. Branch tabs are untouched.
	if _current_tab == TAB_REFINE:
		var refined: Array[Dictionary] = []
		for entry: Dictionary in MetaTree.branch_nodes(_tree, TAB_TRUNK):
			if String(entry.get("id", "")).begins_with(REFINE_PREFIX):
				refined.append(entry)
		return refined
	if _current_tab == TAB_TRUNK:
		var trunk: Array[Dictionary] = []
		for entry: Dictionary in MetaTree.branch_nodes(_tree, TAB_TRUNK):
			if not String(entry.get("id", "")).begins_with(REFINE_PREFIX):
				trunk.append(entry)
		return trunk
	return MetaTree.branch_nodes(_tree, _current_tab)


## Owner (업그레이드 하면서 트리별로 숨어있던 노드들이 나와야 하는데 지금은 바로
## 생성되어있고): a node is on screen only once the ground it grows from is
## the player's. Roots are always there; a child appears the moment its
## prerequisite reaches rank 1, so buying is what opens the map.
func _revealed_nodes() -> Array[Dictionary]:
	var state: Dictionary = _profile.get("meta_tree", {})
	var opened: Array[Dictionary] = []
	for entry: Dictionary in _tab_nodes():
		if _is_revealed(entry, state):
			opened.append(entry)
	# QA N11-14 F-5/F-6: a portrait canvas seats about three readable rings,
	# and a chain runs deeper than that — piling the rest onto the outer ring
	# is what made links cross the field and cut through discs. The screen
	# holds a WINDOW instead: the frontier the player is working on, plus any
	# node anywhere that still has a rank left to buy. A node only leaves the
	# canvas once it is finished AND the growth has moved past it.
	var depth: Dictionary = _depth_map(opened)
	var deepest: int = 1
	for node_id: Variant in depth:
		deepest = maxi(deepest, int(depth[node_id]))
	var floor_level: int = maxi(deepest - VISIBLE_DEPTH + 1, 1)
	var shown: Array[Dictionary] = []
	for entry: Dictionary in opened:
		var node_id: String = String(entry["id"])
		var level: int = int(depth.get(node_id, 1))
		var finished: bool = MetaTree.rank_of(state, node_id) >= MetaTree.max_rank(entry)
		if level >= floor_level or not finished:
			shown.append(entry)
	return shown


## Depth of every node within one set, counting only parents that are in it.
func _depth_map(entries: Array[Dictionary]) -> Dictionary:
	var present: Dictionary = {}
	for entry: Dictionary in entries:
		present[String(entry["id"])] = entry
	var depth: Dictionary = {}
	var settled: bool = false
	while not settled:
		settled = true
		for entry: Dictionary in entries:
			var node_id: String = String(entry["id"])
			if depth.has(node_id):
				continue
			var requires: Array = entry.get("requires", [])
			if requires.is_empty() or not present.has(String(requires[0])):
				depth[node_id] = 1
				settled = false
			elif depth.has(String(requires[0])):
				depth[node_id] = int(depth[String(requires[0])]) + 1
				settled = false
	return depth


## The ids on screen right now, so a purchase can tell what it just opened.
func _reveal_set() -> Dictionary:
	var shown: Dictionary = {}
	for entry: Dictionary in _revealed_nodes():
		shown[String(entry["id"])] = true
	return shown


func _newly_revealed(before: Dictionary) -> Array[String]:
	var opened: Array[String] = []
	for entry: Dictionary in _revealed_nodes():
		var node_id: String = String(entry["id"])
		if not before.has(node_id):
			opened.append(node_id)
	return opened


func _is_revealed(entry: Dictionary, state: Dictionary) -> bool:
	var requires: Array = entry.get("requires", [])
	if requires.is_empty():
		return true
	for required: Variant in requires:
		if MetaTree.rank_of(state, String(required)) < 1:
			return false
	return true


func _node_center(entry: Dictionary, _width: float) -> Vector2:
	# N11-12: positions come from the radial layout; the width parameter is
	# kept so the draw path's call sites stay unchanged.
	return _radial.get(String(entry.get("id", "")), _canvas.size / 2.0)


## One tab's display name for the tab pills.
func _tab_caption(tab_id: String) -> String:
	if tab_id == TAB_TRUNK:
		return UiLocale.text("meta.tab_shared")
	if tab_id == TAB_REFINE:
		return UiLocale.t("연마")
	return MetaTree.display_name(
		_characters.get(tab_id, {}) as Dictionary, UiLocale.current_locale
	)


## The 신목 trunk plus prerequisite edges, drawn under the node buttons.
## Satisfied edges warm to GOLD_BORDER so progress reads on the tree itself.
func _draw_graph() -> void:
	var width: float = _canvas.size.x
	# N11-26 (owner: 중간에 공용 이런거 없애): no hub. The map's origin is the
	# cheapest root — a node you can buy — and every line is a real
	# prerequisite between two nodes.
	var state: Dictionary = _profile.get("meta_tree", {})
	# N11-11: branches, not wires. A node with prerequisites hangs off its
	# parent; a root node hangs off the trunk one half-row above itself, so
	# the whole tab reads as growth spreading out of the spine. Colour is the
	# node's own state: bought gold, buyable wood, locked dim.
	for entry: Dictionary in _revealed_nodes():
		var to_center: Vector2 = _node_center(entry, width)
		# Owner reference: the lit path is the OWNED path. A link glows gold
		# only when both of its ends are the player's; everything else is a
		# quiet grey thread, dashed while the node is still locked.
		var node_owned: bool = MetaTree.rank_of(state, String(entry.get("id", ""))) >= 1
		# Owner reference: a line is gold when the path is walked, green when
		# the node it leads to is affordable now, and a quiet grey otherwise.
		var branch_color: Color = TILE_LOCKED_EDGE
		if _is_buyable(entry, state):
			branch_color = TILE_READY_EDGE
		var dashed: bool = false
		# QA FAIL-2 (1.17:1 between bought gold and buyable wood): the LINE
		# ITSELF carries the state — owned 4px, within-reach 3px, locked a
		# 2px dashed vine in a dim that still exists on the night ground
		# (CARD_BORDER_DIM measured 1.66:1 — near-invisible).
		var branch_width: float = EDGE_WIDTH
		var to_disc: float = _node_size_of(String(entry.get("id", "")))
		# N11-26: a root draws no stem — there is no hub for it to hang off.
		for required: Variant in (entry.get("requires", []) as Array):
			var from_id: String = String(required)
			var from_entry: Dictionary = MetaTree.node(_tree, from_id)
			if from_entry.is_empty() or not _radial.has(from_id):
				continue
			var lit: bool = node_owned and MetaTree.rank_of(state, from_id) >= 1
			_draw_branch(
				_node_center(from_entry, width), to_center,
				UiPalette.GOLD_BORDER if lit else branch_color,
				dashed, 2.5 if lit else branch_width,
				_node_size_of(from_id), to_disc
			)
	# Breathing ring on every node the player could buy RIGHT NOW, a steady
	# gold ring on what is already theirs — the growth state readable at a
	# glance, before any caption is read.
	# Owner reference: nothing is drawn on top of a tile except a soft pulse
	# under the few cheapest buys. State is the border, and that is all.
	var pulse_ids: Array[String] = _cheapest_buyable_ids(state)
	var swell: float = sin(_pulse_phase * TAU / PULSE_PERIOD_SEC) * PULSE_RING_SWING
	var fade: float = clampf((_grow - 0.72) / 0.28, 0.0, 1.0)
	if fade > 0.0:
		for entry: Dictionary in _revealed_nodes():
			var node_id: String = String(entry.get("id", ""))
			if node_id not in pulse_ids:
				continue
			var side: float = _node_size_of(node_id) + PULSE_RING_PAD + swell
			_draw_tile_mark(
				_node_center(entry, width), side,
				Color(UiPalette.GOLD, 0.5 * fade), 2.0
			)
	# I-6 / N11-15: the selected node wears a MARK — plate and icon untouched.
	if not _selected_id.is_empty() and _radial.has(_selected_id):
		_draw_selection_mark(
			_radial[_selected_id], _node_size_of(_selected_id)
		)
	# One-shot purchase bursts: an expanding, fading gold ring where the coin
	# was just spent.
	for burst: Dictionary in _bursts:
		var t: float = float(burst.get("t", 0.0)) / BURST_SEC
		var radius: float = lerpf(BURST_RADIUS_FROM, BURST_RADIUS_TO, t)
		# QA I-6: a white kernel flash under the ring — the coin HITS.
		_canvas.draw_circle(
			burst.get("at", Vector2.ZERO), _node_size() / 2.0,
			Color(1.0, 1.0, 1.0, (1.0 - t) * 0.3)
		)
		_canvas.draw_arc(
			burst.get("at", Vector2.ZERO), radius, 0.0, TAU, 40,
			Color(UiPalette.GOLD, 1.0 - t), 4.0
		)


## N11-11: one quadratic branch curve, sampled — the control point sits on
## the parent's x at the child's height, which is what bends the line out of
## the spine the way a branch leaves a trunk.
func _draw_branch(
	from: Vector2, to: Vector2, color: Color, dashed: bool = false,
	width: float = EDGE_WIDTH, from_disc: float = NODE_SIZE,
	to_disc: float = NODE_SIZE
) -> void:
	# QA I-4: end the curve at the disc RIMS — a line that dives under a
	# disc reads as clutter, a line that stops at its edge reads as a link.
	var axis: Vector2 = (to - from).normalized()
	var rim: float = _node_size() / 2.0 + 3.0
	if from.distance_to(to) > rim * 2.5:
		from = from + axis * rim
		to = to - axis * rim
	# Owner (곡선말고 직선으로): the link was a quadratic bend through a corner
	# control point, which read as a curve however straight the layout was.
	# It is one straight segment now — the branch only ever changes direction
	# at a fork, where two child lines actually diverge.
	# QA I-5: only the grown fraction exists yet — the tab OPENING is where
	# the mindmap's spreading actually reads.
	var tip: Vector2 = from.lerp(to, clampf(_grow, 0.0, 1.0))
	# Owner (node 선도 너무 구리고): a bare 3px stroke on the night ground read
	# as a stray hairline. Every live link is cut into the dark first — a
	# keyline a shade wider — so the bright core sits ON something.
	# The reference keeps its lines bare — no keyline, no glow.
	if dashed:
		# QA I-3: locked speaks in FORM, not colour alone — a dashed vine.
		var span: float = from.distance_to(tip)
		var step: float = DASH_LENGTH * 2.0
		var walked: float = 0.0
		while walked < span:
			var head: float = minf(walked + DASH_LENGTH, span)
			_canvas.draw_line(
				from + axis * walked, from + axis * head, color, 2.0
			)
			walked += step
		return
	_canvas.draw_line(from, tip, color, width, true)


## The colour a node's branch and ring speak: bought, within reach, or dim.
func _node_state_color(entry: Dictionary, state: Dictionary) -> Color:
	var node_id: String = String(entry.get("id", ""))
	if MetaTree.rank_of(state, node_id) >= 1:
		return UiPalette.GOLD_BORDER
	if _is_buyable(entry, state):
		return UiPalette.WOOD
	return UiPalette.CARD_BORDER_DIM


## Owner (선택되어있는 아이콘도 너무 별로): the selection was one more gold
## ring among the state rings and read as noise. It is a MARK now — a heavy
## gold arc broken at the four diagonals, with cardinal ticks pointing in, so
## it is unmistakable against a state ring at a glance.
func _draw_selection_mark(at: Vector2, disc: float) -> void:
	# Four corner brackets around the tile — unmistakable next to the plain
	# square a state mark draws, and it never hides the icon.
	var half: float = disc / 2.0 + TILE_MARK_PAD + 3.0
	var arm: float = maxf(disc * 0.28, 8.0)
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var corner := at + Vector2(float(sx) * half, float(sy) * half)
			_canvas.draw_line(
				corner, corner - Vector2(float(sx) * arm, 0.0), UiPalette.GOLD, 3.0
			)
			_canvas.draw_line(
				corner, corner - Vector2(0.0, float(sy) * arm), UiPalette.GOLD, 3.0
			)


## One square outline centred on a tile.
func _draw_tile_mark(at: Vector2, side: float, color: Color, width: float) -> void:
	_canvas.draw_rect(
		Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)),
		color, false, width
	)


## QA I-8: the ids whose rings breathe — the few cheapest next steps.
func _cheapest_buyable_ids(state: Dictionary) -> Array[String]:
	var priced: Array[Dictionary] = []
	for entry: Dictionary in _tab_nodes():
		if not _is_buyable(entry, state):
			continue
		priced.append({
			"id": String(entry.get("id", "")),
			"cost": MetaTree.next_cost(entry, MetaTree.rank_of(state, String(entry.get("id", "")))),
		})
	priced.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["cost"]) < int(b["cost"])
	)
	var out: Array[String] = []
	for i: int in mini(priced.size(), PULSE_LIMIT):
		out.append(String(priced[i]["id"]))
	return out


func _is_buyable(entry: Dictionary, state: Dictionary) -> bool:
	return MetaTree.can_purchase(
		_tree, state, int(_profile.get("gold", 0)), String(entry.get("id", "")),
		_unlocked, _profile.get("materials", {}) as Dictionary
	) == MetaTree.REASON_OK


## --- helpers --------------------------------------------------------------


## N10-20: the kit's round plate, tinted by the same border colour the flat
## node used. The border was the SECOND cue by design — the status word carries
## the first — so the tint has to keep saying it, and does.
## Owner reference (간단한 반응형 노드): a flat rounded TILE, not the kit's
## ceramic disc. The tile carries its family's hue — saturated once the node
## is owned, a dark wash of the same hue while it is not — so a branch reads
## as one colour run before a single label is read.
func _node_plate(fill: Color, border: Color) -> StyleBox:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(NODE_BORDER_WIDTH)
	box.set_corner_radius_all(TILE_RADIUS)
	return box


func _pill_plate(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.CARD_BG_SELECTED if active else UiPalette.CARD_BG
	box.border_color = UiPalette.GOLD_BORDER if active else UiPalette.CARD_BORDER_DIM
	box.set_border_width_all(NODE_BORDER_WIDTH)
	box.set_corner_radius_all(PILL_CORNER_RADIUS)
	return box


func _flash_notice(text_value: String) -> void:
	_notice_label.text = text_value
	_notice_label.modulate = Color.WHITE
	if not is_inside_tree():
		return
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_FADE_SEC)
	_notice_tween.tween_property(
		_notice_label, "modulate", Color.TRANSPARENT, NOTICE_FADE_SEC
	)


func _live_profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static var _loot_cache: Dictionary = {}


func _loot_entry(loot_id: String) -> Dictionary:
	if _loot_cache.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/loot.json")
		)
		if parsed is Dictionary:
			_loot_cache = parsed
	return _loot_cache.get(loot_id, {})
