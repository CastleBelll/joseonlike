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
const PILL_CORNER_RADIUS := 18
const PILL_PADDING_X := 14
const PILL_PADDING_Y := 6
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
	_unlocked = MetaTree.unlocked_characters(_characters)
	_profile = _live_profile()
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
		caption.custom_minimum_size = Vector2(NODE_LABEL_WIDTH, 0.0)
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
	_detail_effect.name = "DetailEffect"
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_detail_effect)
	_detail_info = _label("", UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER)
	_detail_info.name = "DetailInfo"
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
	select_node(node_id)


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
		MetaTree.REASON_GOLD:
			_flash_notice(UiLocale.text("meta.no_gold"))
		MetaTree.REASON_MATERIALS:
			_flash_notice(UiLocale.text("meta.no_materials"))
		MetaTree.REASON_CHARACTER:
			_flash_notice(UiLocale.text("meta.char_locked"))
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
		caption.position = Vector2(
			center.x - NODE_LABEL_WIDTH / 2.0, center.y + NODE_SIZE / 2.0
		)


## Row pitch and canvas padding for the orientation on screen right now. Read
## per layout pass, not cached, because _layout_nodes already re-runs on every
## resize — a cached value would be the stale-on-flip bug this pass is fixing.
func _is_landscape() -> bool:
	return size.x > size.y


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
	var usable: float = width - NODE_LABEL_WIDTH
	return Vector2(
		NODE_LABEL_WIDTH / 2.0 + float(pos[0]) * maxf(usable, 0.0),
		_canvas_top_pad() + float(pos[1]) * _row_height() + NODE_SIZE / 2.0
	)


## The 신목 trunk plus prerequisite edges, drawn under the node buttons.
## Satisfied edges warm to GOLD_BORDER so progress reads on the tree itself.
func _draw_graph() -> void:
	var width: float = _canvas.size.x
	var height: float = _canvas.custom_minimum_size.y
	_canvas.draw_line(
		Vector2(width / 2.0, 0.0), Vector2(width / 2.0, height),
		UiPalette.WOOD_BORDER, TRUNK_WIDTH
	)
	var state: Dictionary = _profile.get("meta_tree", {})
	for entry: Dictionary in _tab_nodes():
		var to_center: Vector2 = _node_center(entry, width)
		for required: Variant in entry.get("requires", []):
			var from_entry: Dictionary = MetaTree.node(_tree, String(required))
			if from_entry.is_empty():
				continue
			var satisfied: bool = MetaTree.rank_of(state, String(required)) >= 1
			_canvas.draw_line(
				_node_center(from_entry, width), to_center,
				UiPalette.GOLD_BORDER if satisfied else UiPalette.CARD_BORDER_DIM,
				EDGE_WIDTH
			)


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
