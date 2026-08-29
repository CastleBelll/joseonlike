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
const NODE_SIZE := 72.0
const NODE_ICON_SIZE := 40.0
const NODE_LABEL_WIDTH := 150.0
## QA gate F1 (N11-9): the two caption columns sit 0.44 of the usable width
## apart, so on a narrow canvas a fixed 150px caption overlaps its row
## neighbour glyph-on-glyph. The width adapts until caption <= separation
## (solving w <= 0.44*(canvas-w) - gap), floored so a caption stays a word.
const COLUMN_SPAN := 0.44
const CAPTION_GAP := 6.0
const CAPTION_WIDTH_MIN := 88.0
const ROW_HEIGHT := 165.0
const CANVAS_TOP_PAD := 28.0
const CANVAS_BOTTOM_PAD := 72.0
## Owner (가로모드도 어색하고 자꾸 스크롤이 생길정도라서 크기를 조금씩 줄여도
## 될 것 같아): a landscape phone has barely 200px of tree band, so a row pitch
## built for a 960-tall screen showed one row and a scrollbar. The nodes keep
## their size — they are touch targets and the circle art is built once — and
## the SPACING between rows carries the reduction instead.
const ROW_HEIGHT_LANDSCAPE := 118.0
## Wide enough for the detail card's icon well plus two lines of effect text.
const SIDE_WIDTH_LANDSCAPE := 380.0
const CANVAS_TOP_PAD_LANDSCAPE := 14.0
const CANVAS_BOTTOM_PAD_LANDSCAPE := 40.0
const NODE_BORDER_WIDTH := 3
const EDGE_WIDTH := 3.0
const TRUNK_WIDTH := 10.0
## N11-11 (owner: 마인드맵처럼 업그레이드가 퍼져나가고 호버 클릭 시 애니메이션
## 이랑 사운드도): every node hangs off the trunk (or its requires parent) by
## a drawn curve, so the tree reads as branches spreading, not a list.
const BRANCH_SAMPLES := 14
const PULSE_PERIOD_SEC := 1.6
const PULSE_RING_PAD := 4.0
const PULSE_RING_SWING := 2.5
const HOVER_SCALE := 1.1
const HOVER_TWEEN_SEC := 0.1
const PRESS_PUNCH_SCALE := 0.92
const BURST_SEC := 0.5
const BURST_RADIUS_FROM := NODE_SIZE * 0.5
const BURST_RADIUS_TO := NODE_SIZE * 1.3
const CAPTION_TRUNK_PAD := 4.0
const PILL_CORNER_RADIUS := UiPalette.PILL_RADIUS
const PILL_PADDING_X := UiPalette.PILL_PAD_X
const PILL_PADDING_Y := UiPalette.PILL_PAD_Y
const CARD_CORNER_RADIUS := 12
const CARD_PADDING := 14
const CARD_ICON_WELL := 64.0
const COIN_ICON_SIZE := 28.0
const BACK_SIZE := 44.0
const CTA_HEIGHT := 60
const TAB_HEIGHT := 40
const DETAIL_MIN_HEIGHT := 96.0
const NOTICE_FADE_SEC := 1.4
## Locked node icons dim by alpha only — no raw color values outside palette.
const LOCKED_ICON_ALPHA := 0.35
## The shared-trunk tab id; character tabs use the roster id.
const TAB_TRUNK := ""

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
var _scroll: ScrollContainer
var _gold_label: Label
var _detail_name: Label
var _detail_info: Label
var _detail_effect: Label
var _detail_icon: TextureRect
var _cta: Button
## The tree row and the panel beside (landscape) or below (portrait) it.
var _body: HBoxContainer
var _side: VBoxContainer
var _side_slack: Control
var _side_in_row: bool = false
var _notice_label: Label
var _notice_tween: Tween
var _tab_buttons: Dictionary = {}
var _node_buttons: Dictionary = {}
var _node_labels: Dictionary = {}


func _ready() -> void:
	build_ui()


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

	_cta = Button.new()
	_cta.name = "CtaButton"
	_cta.custom_minimum_size = Vector2(0.0, CTA_HEIGHT)
	WoodButton.apply(_cta)
	_cta.pressed.connect(_on_cta_pressed)
	_side.add_child(_cta)
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
	var tab_ids: Array[String] = [TAB_TRUNK]
	for character_id: String in _characters:
		tab_ids.append(character_id)
	for tab_id: String in tab_ids:
		var tab := Button.new()
		tab.name = "Tab_" + (tab_id if not tab_id.is_empty() else "shared")
		tab.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_populate_tab()
	_refresh()
	if is_inside_tree():
		_scroll.scroll_vertical = 0


func _build_graph() -> Control:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

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
	for caption: Label in _node_labels.values():
		caption.queue_free()
	_node_buttons.clear()
	_node_labels.clear()
	var max_row: float = 0.0
	for entry: Dictionary in _tab_nodes():
		max_row = maxf(max_row, float((entry.get("pos", []) as Array)[1]))
	_canvas.custom_minimum_size = Vector2(
		0.0, _canvas_top_pad() + (max_row + 1.0) * _row_height() + _canvas_bottom_pad()
	)
	for entry: Dictionary in _tab_nodes():
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
			UiIcons.loot_icon(String(entry.get("icon", ""))), NODE_ICON_SIZE
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

		var caption := _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_ON_DARK)
		caption.name = "Caption_" + node_id
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size = Vector2(_caption_width(_canvas.size.x), 0.0)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_canvas.add_child(caption)
		_node_labels[node_id] = caption


func _build_detail_card() -> Control:
	var card := PanelContainer.new()
	card.name = "DetailCard"
	card.custom_minimum_size = Vector2(0.0, DETAIL_MIN_HEIGHT)
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
	_detail_icon = UiIcons.icon_rect(null, NODE_ICON_SIZE)
	_detail_icon.name = "DetailIcon"
	well.add_child(_detail_icon)
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
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_detail_effect)
	_detail_info = _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER)
	_detail_info.name = "DetailInfo"
	# QA gate F2 (N11-9): unlock hints and material bills are SENTENCES — a
	# one-line Label's minimum width became the column's minimum and pushed
	# the tab row and the gold pill 664px off the canvas. Wrap collapses the
	# demand to the longest word (the V1/result-sheet grammar).
	_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(_detail_info)
	row.add_child(lines)
	return card


## --- selection / purchase -------------------------------------------------


func select_node(node_id: String) -> void:
	# A programmatic select may target another tab (tests, deep links) — the
	# tab follows the node so the selection is always visible.
	var branch: String = MetaTree.node_character(MetaTree.node(_tree, node_id))
	if branch != _current_tab:
		_current_tab = branch
		_populate_tab()
	_selected_id = node_id
	_refresh()
	var button: Button = _node_buttons.get(node_id)
	if button != null and is_inside_tree():
		_scroll.ensure_control_visible(button)


func _on_node_pressed(node_id: String) -> void:
	_play_sfx("ui_open")
	var button: Button = _node_buttons.get(node_id)
	if button != null and is_inside_tree():
		var tween: Tween = create_tween()
		tween.tween_property(
			button, "scale", Vector2.ONE * PRESS_PUNCH_SCALE, HOVER_TWEEN_SEC / 2.0
		)
		tween.tween_property(button, "scale", Vector2.ONE, HOVER_TWEEN_SEC)
	select_node(node_id)


func _on_node_hover(button: Button, entered: bool) -> void:
	if not is_inside_tree():
		return
	if entered:
		_play_sfx("ui_click")
	var tween: Tween = create_tween()
	tween.tween_property(
		button, "scale",
		Vector2.ONE * (HOVER_SCALE if entered else 1.0), HOVER_TWEEN_SEC
	).set_ease(Tween.EASE_OUT)


func _play_sfx(sound_id: String) -> void:
	if SfxService.instance != null:
		SfxService.instance.play(sound_id)


## N11-11: the graph breathes — purchasable rings swell on a slow sine and
## finished bursts fall out of the list. Redraws only while this screen is
## the scene, which it always is when visible.
func _process(delta: float) -> void:
	_pulse_phase = fmod(_pulse_phase + delta, PULSE_PERIOD_SEC)
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
	for entry: Dictionary in _tab_nodes():
		var node_id: String = String(entry["id"])
		_style_node(entry, node_id, state, gold)
	_refresh_detail(state, gold)
	if _canvas != null:
		_layout_nodes()
		_canvas.queue_redraw()


func _refresh_tabs() -> void:
	for tab_id: String in _tab_buttons:
		var tab: Button = _tab_buttons[tab_id]
		var caption: String
		var muted: bool = false
		if tab_id == TAB_TRUNK:
			caption = UiLocale.text("meta.tab_shared")
		else:
			caption = MetaTree.display_name(
				_characters.get(tab_id, {}) as Dictionary, UiLocale.current_locale
			)
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
	return _current_tab != TAB_TRUNK and _current_tab not in _unlocked


func _style_node(
	entry: Dictionary, node_id: String, state: Dictionary, gold: int
) -> void:
	var button: Button = _node_buttons[node_id]
	var caption: Label = _node_labels[node_id]
	var rank: int = MetaTree.rank_of(state, node_id)
	var unlocked: bool = MetaTree.is_unlocked(_tree, state, node_id)
	var cost: int = MetaTree.next_cost(entry, rank)
	var name_text: String = MetaTree.display_name(entry, UiLocale.current_locale)
	var selected: bool = node_id == _selected_id

	var border: Color = UiPalette.CARD_BORDER_DIM
	var fill: Color = UiPalette.CARD_BG
	var status: String
	var icon: TextureRect = button.get_node("Icon")
	icon.modulate.a = 1.0
	if _branch_locked():
		# The whole branch is roster advertising: named, priced, not buyable.
		icon.modulate.a = LOCKED_ICON_ALPHA
		status = UiLocale.text("meta.locked") + " · " \
			+ UiLocale.text("meta.cost_fmt") % cost
	elif rank > 0:
		border = UiPalette.GOLD_BORDER
		fill = UiPalette.CARD_BG_SELECTED
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
		border = UiPalette.WOOD
		status = UiLocale.text("meta.available") + " · " \
			+ UiLocale.text("meta.cost_fmt") % cost
	else:
		status = UiLocale.text("meta.cost_fmt") % cost
	if selected:
		border = UiPalette.GOLD

	for state_name: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state_name, _node_plate(fill, border))
	button.add_theme_stylebox_override("focus", _node_plate(fill, UiPalette.GOLD))
	caption.text = name_text + "\n" + status
	caption.add_theme_color_override(
		"font_color",
		UiPalette.TEXT_ON_DARK if (unlocked or rank > 0) and not _branch_locked()
		else UiPalette.TEXT_MUTED_ON_DARK
	)


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
	_detail_icon.texture = UiIcons.loot_icon(String(entry.get("icon", "")))
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
	if _current_tab == TAB_TRUNK:
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
	var width: float = _canvas.size.x
	if width <= 0.0:
		return
	# The canvas is as tall as the pitch makes it, and the pitch changes with
	# the orientation — so it is re-measured here rather than only at build,
	# where a flip would leave the old height (and its scrollbar) behind.
	var max_row: float = 0.0
	for entry: Dictionary in _tab_nodes():
		max_row = maxf(max_row, float((entry.get("pos", []) as Array)[1]))
	_canvas.custom_minimum_size = Vector2(
		0.0, _canvas_top_pad() + (max_row + 1.0) * _row_height() + _canvas_bottom_pad()
	)
	for entry: Dictionary in _tab_nodes():
		var node_id: String = String(entry["id"])
		if not _node_buttons.has(node_id):
			continue
		var center: Vector2 = _node_center(entry, width)
		var button: Button = _node_buttons[node_id]
		button.position = center - Vector2(NODE_SIZE / 2.0, NODE_SIZE / 2.0)
		var caption: Label = _node_labels[node_id]
		var caption_width: float = _caption_width(width)
		caption.custom_minimum_size = Vector2(caption_width, 0.0)
		caption.size.x = caption_width
		caption.position = Vector2(
			center.x - caption_width / 2.0, center.y + NODE_SIZE / 2.0
		)


## Row pitch and canvas padding for the orientation on screen right now. Read
## per layout pass, not cached, because _layout_nodes already re-runs on every
## resize — a cached value would be the stale-on-flip bug this pass is fixing.
func _is_landscape() -> bool:
	return size.x > size.y


## F1: the widest caption that cannot reach its row neighbour on this canvas.
## QA re-verify: the fixed 0.44 span assumed two-column rows, and the one
## three-column row (우치 row 2, min-sep 0.35) still overlapped — the span
## is MEASURED from the current tab's rows now, so new data cannot break it.
func _caption_width(width: float) -> float:
	var span: float = _tab_min_column_sep()
	var fits: float = (span * width - CAPTION_GAP) / (1.0 + span)
	return clampf(fits, CAPTION_WIDTH_MIN, NODE_LABEL_WIDTH)


## Smallest horizontal gap between neighbouring nodes on any one row of the
## current tab; COLUMN_SPAN is the ceiling (a lone-column tab needs no less).
func _tab_min_column_sep() -> float:
	var rows: Dictionary = {}
	for entry: Dictionary in _tab_nodes():
		var pos: Array = entry.get("pos", [0.5, 0.0])
		var row: int = int(pos[1])
		if not rows.has(row):
			rows[row] = [] as Array[float]
		(rows[row] as Array[float]).append(float(pos[0]))
	var narrowest: float = COLUMN_SPAN
	for row: int in rows:
		var xs: Array[float] = rows[row]
		xs.sort()
		for i: int in range(1, xs.size()):
			narrowest = minf(narrowest, xs[i] - xs[i - 1])
	return maxf(narrowest, 0.1)


func _row_height() -> float:
	return ROW_HEIGHT_LANDSCAPE if _is_landscape() else ROW_HEIGHT


func _canvas_top_pad() -> float:
	return CANVAS_TOP_PAD_LANDSCAPE if _is_landscape() else CANVAS_TOP_PAD


func _canvas_bottom_pad() -> float:
	return CANVAS_BOTTOM_PAD_LANDSCAPE if _is_landscape() else CANVAS_BOTTOM_PAD


## Puts the detail panel where the current orientation wants it. Only moves on
## an actual flip: re-parenting on every resize would throw away the scroll
## position and the selection every time a desktop window is dragged.
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
	return MetaTree.branch_nodes(_tree, _current_tab)


func _node_center(entry: Dictionary, width: float) -> Vector2:
	var pos: Array = entry.get("pos", [0.5, 0.0])
	var caption_width: float = _caption_width(width)
	var usable: float = width - caption_width
	return Vector2(
		caption_width / 2.0 + float(pos[0]) * maxf(usable, 0.0),
		_canvas_top_pad() + float(pos[1]) * _row_height() + NODE_SIZE / 2.0
	)


## The 신목 trunk plus prerequisite edges, drawn under the node buttons.
## Satisfied edges warm to GOLD_BORDER so progress reads on the tree itself.
func _draw_graph() -> void:
	var width: float = _canvas.size.x
	var height: float = _canvas.custom_minimum_size.y
	# F11: the trunk ran straight through the node captions ("부적│연마").
	# It is drawn as segments now, skipping every caption's rect band.
	var gaps: Array[Vector2] = []
	for caption: Label in _node_labels.values():
		if caption == null:
			continue
		var rect: Rect2 = caption.get_rect()
		var trunk_x: float = width / 2.0
		if rect.position.x - CAPTION_TRUNK_PAD <= trunk_x 				and trunk_x <= rect.end.x + CAPTION_TRUNK_PAD:
			gaps.append(Vector2(
				rect.position.y - CAPTION_TRUNK_PAD, rect.end.y + CAPTION_TRUNK_PAD
			))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor: float = 0.0
	for gap: Vector2 in gaps:
		if gap.x > cursor:
			_canvas.draw_line(
				Vector2(width / 2.0, cursor), Vector2(width / 2.0, gap.x),
				UiPalette.WOOD_BORDER, TRUNK_WIDTH
			)
		cursor = maxf(cursor, gap.y)
	if cursor < height:
		_canvas.draw_line(
			Vector2(width / 2.0, cursor), Vector2(width / 2.0, height),
			UiPalette.WOOD_BORDER, TRUNK_WIDTH
		)
	var state: Dictionary = _profile.get("meta_tree", {})
	# N11-11: branches, not wires. A node with prerequisites hangs off its
	# parent; a root node hangs off the trunk one half-row above itself, so
	# the whole tab reads as growth spreading out of the spine. Colour is the
	# node's own state: bought gold, buyable wood, locked dim.
	for entry: Dictionary in _tab_nodes():
		var to_center: Vector2 = _node_center(entry, width)
		var branch_color: Color = _node_state_color(entry, state)
		var requires: Array = entry.get("requires", [])
		if requires.is_empty():
			var spine := Vector2(width / 2.0, to_center.y - _row_height() * 0.45)
			_draw_branch(spine, to_center, branch_color)
		for required: Variant in requires:
			var from_entry: Dictionary = MetaTree.node(_tree, String(required))
			if from_entry.is_empty():
				continue
			_draw_branch(_node_center(from_entry, width), to_center, branch_color)
	# Breathing ring on every node the player could buy RIGHT NOW, a steady
	# gold ring on what is already theirs — the growth state readable at a
	# glance, before any caption is read.
	var ring_swell: float = sin(_pulse_phase * TAU / PULSE_PERIOD_SEC) * PULSE_RING_SWING
	for entry: Dictionary in _tab_nodes():
		var center: Vector2 = _node_center(entry, width)
		var node_id: String = String(entry.get("id", ""))
		if MetaTree.rank_of(state, node_id) >= MetaTree.max_rank(entry):
			_canvas.draw_arc(
				center, NODE_SIZE / 2.0 + PULSE_RING_PAD, 0.0, TAU, 32,
				UiPalette.GOLD_BORDER, 2.0
			)
		elif _is_buyable(entry, state):
			_canvas.draw_arc(
				center, NODE_SIZE / 2.0 + PULSE_RING_PAD + ring_swell, 0.0, TAU, 32,
				Color(UiPalette.GOLD, 0.65), 2.0
			)
	# One-shot purchase bursts: an expanding, fading gold ring where the coin
	# was just spent.
	for burst: Dictionary in _bursts:
		var t: float = float(burst.get("t", 0.0)) / BURST_SEC
		var radius: float = lerpf(BURST_RADIUS_FROM, BURST_RADIUS_TO, t)
		_canvas.draw_arc(
			burst.get("at", Vector2.ZERO), radius, 0.0, TAU, 40,
			Color(UiPalette.GOLD, 1.0 - t), 3.0
		)


## N11-11: one quadratic branch curve, sampled — the control point sits on
## the parent's x at the child's height, which is what bends the line out of
## the spine the way a branch leaves a trunk.
func _draw_branch(from: Vector2, to: Vector2, color: Color) -> void:
	var control := Vector2(from.x, to.y)
	var points := PackedVector2Array()
	for i: int in BRANCH_SAMPLES + 1:
		var t: float = float(i) / float(BRANCH_SAMPLES)
		var a: Vector2 = from.lerp(control, t)
		var b: Vector2 = control.lerp(to, t)
		points.append(a.lerp(b, t))
	_canvas.draw_polyline(points, color, EDGE_WIDTH, true)


## The colour a node's branch and ring speak: bought, within reach, or dim.
func _node_state_color(entry: Dictionary, state: Dictionary) -> Color:
	var node_id: String = String(entry.get("id", ""))
	if MetaTree.rank_of(state, node_id) >= 1:
		return UiPalette.GOLD_BORDER
	if _is_buyable(entry, state):
		return UiPalette.WOOD
	return UiPalette.CARD_BORDER_DIM


func _is_buyable(entry: Dictionary, state: Dictionary) -> bool:
	return MetaTree.can_purchase(
		_tree, state, int(_profile.get("gold", 0)), String(entry.get("id", "")),
		_unlocked, _profile.get("materials", {}) as Dictionary
	) == MetaTree.REASON_OK


## --- helpers --------------------------------------------------------------


## N10-20: the kit's round plate, tinted by the same border colour the flat
## node used. The border was the SECOND cue by design — the status word carries
## the first — so the tint has to keep saying it, and does.
func _node_plate(fill: Color, border: Color) -> StyleBox:
	var kit: StyleBox = UiIcons.disc_panel(border)
	if kit != null:
		return kit
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(NODE_BORDER_WIDTH)
	box.set_corner_radius_all(int(NODE_SIZE / 2.0))
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
