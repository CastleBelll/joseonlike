extends Node
## Layout sweep (owner: PC와 폰 해상도 전부에서 UI 배치·크기를 확인해라):
## builds every menu screen and popup at the content-scale base each target
## device resolves to (DisplayAdapterService.base_for), then asserts that
##
##   * no Button leaves the viewport rect, and
##   * no ScrollContainer is actually scrolling (content taller than its page)
##
## Scrolling is a clamp fallback, not a layout: a screen that scrolls on a
## real device is the bug this sweep exists to catch.
## Run: godot --path . res://tools/layout_sweep.tscn

## Device windows worth proving: desktop fullscreen sizes, phone portrait
## ratios from 16:9 to 19.5:9, and their landscape twins.
const WINDOWS: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1366, 768), Vector2i(1280, 800),
	Vector2i(1080, 1920), Vector2i(720, 1440), Vector2i(1179, 2556), Vector2i(800, 1280),
	Vector2i(2556, 1179), Vector2i(2340, 1080), Vector2i(1440, 720),
]
## Real-phone device-pixel ratios for the windows that ARE phones. base_for
## shrinks the base toward the CSS viewport on these (owner: 모바일에서
## 전체적으로 너무 작아), so the sweep must prove the shrunken bases too —
## a window absent here sweeps at ratio 1 exactly as before.
const WINDOW_RATIOS := {
	Vector2i(1080, 1920): 2.625, Vector2i(720, 1440): 2.0,
	Vector2i(1179, 2556): 3.0, Vector2i(2556, 1179): 3.0,
	Vector2i(2340, 1080): 2.75, Vector2i(1440, 720): 2.0,
}
## Screens whose content is a LIST that grows with data — the 명부수 tree, the
## bestiary and the achievement ledger are meant to scroll, so only their
## chrome (anything outside the scroll) is held to the fit rule.
const LIST_SCREENS: Array[String] = ["meta", "bestiary", "achievements", "smithy"]
const SCREENS := {
	"title": "res://scenes/title.tscn",
	"camp": "res://scenes/camp.tscn",
	"select": "res://scenes/character_select.tscn",
	"meta": "res://scenes/meta_tree.tscn",
	"bestiary": "res://scenes/bestiary.tscn",
	"achievements": "res://scenes/achievements.tscn",
	"smithy": "res://scenes/smithy.tscn",
}

var _failures: Array[String] = []
var _locale: String = "ko"


func _ready() -> void:
	_seed_profile()
	# Both locales: English strings run longer than Korean, so a row that fits
	# one can clip in the other.
	for locale: String in ["ko", "en"]:
		if SaveService.instance != null:
			SaveService.instance.set_setting("locale", locale, false)
		_locale = locale
		for window: Vector2i in WINDOWS:
			await _sweep_window(window)
	if _failures.is_empty():
		print("PASS layout_sweep: %d screens x %d devices x 2 locales, nothing overflows, clips or scrolls"
			% [SCREENS.size() + 6, WINDOWS.size()])
		get_tree().quit(0)
		return
	for line: String in _failures:
		push_error(line)
	push_error("FAIL layout_sweep: %d layout problems" % _failures.size())
	get_tree().quit(1)


## A returning profile so screens render their populated state, never the
## empty first-run one. In memory only — the disk write stays locked.
func _seed_profile() -> void:
	if SaveService.instance == null:
		return
	var profile: Dictionary = SaveProfile.apply_run_result(
		SaveProfile.default_profile(), 287.0, 132, 875, true
	)
	profile = Bestiary.record_discovery(profile, Bestiary.KIND_MONSTERS, "forest_goblin")["profile"]
	SaveService.instance.profile = profile
	SaveService.instance._write_locked = true
	SaveService.instance._write_lock_reason = "layout_sweep uses a throwaway profile"


## The logical canvas a device actually gets: the orientation base, expanded
## on the axis the window has room for (project stretch aspect = "expand").
static func canvas_for(window: Vector2i) -> Vector2:
	var ratio: float = float(WINDOW_RATIOS.get(window, 1.0))
	var base: Vector2 = Vector2(DisplayAdapterService.base_for(window, ratio))
	var window_ratio: float = float(window.x) / float(window.y)
	var base_ratio: float = base.x / base.y
	if window_ratio > base_ratio:
		return Vector2(base.y * window_ratio, base.y)
	return Vector2(base.x, base.x / window_ratio)


func _sweep_window(window: Vector2i) -> void:
	var canvas: Vector2 = canvas_for(window)
	for key: String in SCREENS:
		await _check_screen(key, String(SCREENS[key]), window, canvas, false)
	# The popups ride over the camp, which owns the settings entry.
	await _check_screen("settings", String(SCREENS["camp"]), window, canvas, true)
	await _check_screen("levelup", String(SCREENS["camp"]), window, canvas, true, true)
	for overlay_key: String in ["result", "guide", "hud", "pause"]:
		await _check_overlay(overlay_key, window, canvas)


func _check_screen(
	key: String, path: String, window: Vector2i, canvas: Vector2,
	popup: bool, level_up: bool = false
) -> void:
	# The screens lay out against their own rect, so a host Control sized to
	# the device canvas reproduces that device without resizing the window.
	var host := Control.new()
	host.size = canvas
	add_child(host)
	var screen: Control = (load(path) as PackedScene).instantiate()
	host.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.size = canvas
	var overlay: Node = null
	if popup:
		overlay = _open_popup(level_up, canvas)
	await get_tree().process_frame
	await get_tree().process_frame
	var label: String = "%s[%s] @ %dx%d (canvas %.0fx%.0f)" % [key, _locale, window.x, window.y, canvas.x, canvas.y]
	var rect := Rect2(Vector2.ZERO, canvas)
	var list_screen: bool = LIST_SCREENS.has(key)
	_boxes.clear()
	_box_names.clear()
	_walk(screen, rect, label, list_screen, false)
	if overlay == null:
		# A popup is meant to cover the screen under it, so overlaps are only
		# checked inside one layer at a time.
		_check_overlaps(label)
	if overlay != null:
		_boxes.clear()
		_box_names.clear()
		_walk(overlay, rect, label, false, false)
		_check_overlaps(label)
	if overlay != null:
		overlay.queue_free()
	host.queue_free()
	await get_tree().process_frame


## Popups are CanvasLayers anchored to the real viewport, so the sweep sizes
## their blocker to the device canvas and re-runs their layout.
## The run-time overlays: the result paper, the opening guide, the combat HUD
## and its pause paper. They build straight into a canvas-sized host, no
## stage needed — every one of them is a CanvasLayer or a plain Control.
func _check_overlay(key: String, window: Vector2i, canvas: Vector2) -> void:
	var host := Control.new()
	host.size = canvas
	add_child(host)
	var node: Node = null
	match key:
		"result":
			var result := ResultScreen.new()
			host.add_child(result)
			result._root.set_anchors_preset(Control.PRESET_TOP_LEFT)
			result._root.size = canvas
			result.open(RunFlow.OUTCOME_DEFEAT, {
				"time_text": "4:47", "kills": 132, "gold": 875, "earned": 220,
				"total_gold": 1095, "death_cause": "forest_goblin",
			})
			node = result
		"guide":
			var guide := GuideDialog.new()
			host.add_child(guide)
			var blocker: Control = guide.get_node("Blocker")
			blocker.set_anchors_preset(Control.PRESET_TOP_LEFT)
			blocker.size = canvas
			guide.open(Ftue.GUIDE_PAGES)
			node = guide
		_:
			var hud := CombatHud.new()
			host.add_child(hud)
			hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
			hud.size = canvas
			_fill_belongings(hud)
			if key == "pause":
				# The pause paper rides its own CanvasLayer, which anchors to the
				# real viewport — size its root to the device canvas like the
				# other popups before opening it.
				hud._pause_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
				hud._pause_overlay.size = canvas
				hud._on_pause_pressed()
				# _on_pause_pressed pauses the TREE, and this sweep never used to
				# undo it — so every screen measured after the first window's
				# pause check ran in a paused tree. That leaked state was invisible
				# until the level-up popup started animating only when paused: ten
				# windows measured a half-unrolled scroll and reported overflow.
				get_tree().paused = false
			node = hud
	await get_tree().process_frame
	await get_tree().process_frame
	var label: String = "%s[%s] @ %dx%d (canvas %.0fx%.0f)" % [key, _locale, window.x, window.y, canvas.x, canvas.y]
	_boxes.clear()
	_box_names.clear()
	_walk(node, Rect2(Vector2.ZERO, canvas), label, false, false)
	_check_overlaps(label)
	host.queue_free()
	await get_tree().process_frame


func _open_popup(level_up: bool, canvas: Vector2) -> Node:
	if not level_up:
		var settings := SettingsPopup.new()
		add_child(settings)
		settings._root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		settings._root.size = canvas
		settings.open()
		return settings
	var popup := LevelUpPopup.new()
	add_child(popup)
	popup._root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	popup._root.size = canvas
	var weapons: Dictionary = _json("res://data/weapons.json")
	var passives: Dictionary = _json("res://data/passives.json")
	var owned: Dictionary = {}
	for weapon_id: String in weapons:
		if not weapon_id.begins_with("_"):
			owned[weapon_id] = 8
	var cards: Array[Dictionary] = []
	for choice: Dictionary in [
		{"kind": LevelUp.KIND_WEAPON_UP, "id": "jineon"},
		{"kind": LevelUp.KIND_WEAPON_UP, "id": "gyeolgye"},
		{"kind": LevelUp.KIND_PASSIVE, "id": passives.keys()[0]},
	]:
		cards.append(LevelUp.as_card(choice, weapons, passives, owned, {}, {}, {}))
	popup.open("파워 업!", cards, owned, weapons)
	return popup


func _json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## Every button must land inside the viewport, and no scroll may actually be
## scrolling — both are what "삐져나온다" and "스크롤 생긴다" look like in data.
## The paper a control sits on: the nearest PanelContainer ancestor. A button
## outside its own panel reads as broken even when it is on screen.
static func _paper_of(node: Node) -> Control:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is PanelContainer:
			return parent as Control
		parent = parent.get_parent()
	return null


## Touch floor: below this a button is hard to hit on a phone. The project
## standard is UiPalette.TOUCH_TARGET_MIN (44); the sweep fails under 40 so a
## deliberate 40px pill row stays legal but nothing shrinks past it.
const TOUCH_FLOOR := 40.0

var _boxes: Array[Rect2] = []
var _box_names: PackedStringArray = []


## Two tappable things must not sit on top of each other — that is the
## "가이드가 가린다" class of bug, invisible to an overflow check.
func _check_overlaps(label: String) -> void:
	for i: int in _boxes.size():
		for j: int in range(i + 1, _boxes.size()):
			var a: Rect2 = _boxes[i]
			var b: Rect2 = _boxes[j]
			if not a.intersects(b):
				continue
			var shared: Rect2 = a.intersection(b)
			# Touching borders are fine; a real overlap covers area.
			if shared.size.x < 4.0 or shared.size.y < 4.0:
				continue
			_failures.append(
				"%s: %s and %s overlap (%.0fx%.0f)"
				% [label, _box_names[i], _box_names[j], shared.size.x, shared.size.y]
			)


func _walk(node: Node, viewport: Rect2, label: String, list_screen: bool, inside_scroll: bool) -> void:
	for child: Node in node.get_children():
		# A list screen's rows live below the fold on purpose; only its chrome
		# (back button, header, CTA) has to be on screen.
		var skip: bool = list_screen and inside_scroll
		if child is Button and (child as Control).is_visible_in_tree() and not skip:
			var button := child as Button
			var box: Rect2 = button.get_global_rect()
			if box.size.x > 0.0 and box.size.y > 0.0:
				if not viewport.encloses(box):
					_failures.append(
						"%s: %s leaves the screen (%.0f,%.0f %.0fx%.0f)"
						% [label, button.name, box.position.x, box.position.y, box.size.x, box.size.y]
					)
				# Owner (가로에서 결과 창 버튼이 아래로 빠져나간다): a button can sit
				# inside the SCREEN and still hang off the paper it belongs to.
				# That is what this sweep missed, so it checks the paper too.
				var paper: Control = _paper_of(button)
				if paper != null and not paper.get_global_rect().grow(2.0).encloses(box):
					_failures.append(
						"%s: %s hangs off its paper (%s vs %s)"
						% [label, button.name, str(box), str(paper.get_global_rect())]
					)
				if minf(box.size.x, box.size.y) < TOUCH_FLOOR:
					_failures.append(
						"%s: %s is %.0fx%.0f, under the %.0fpx touch floor"
						% [label, button.name, box.size.x, box.size.y, TOUCH_FLOOR]
					)
				_boxes.append(box)
				_box_names.append(String(button.name))
		# A label whose one line needs more width than it has is truncated on
		# screen — the phone-sized version of "글씨가 잘린다".
		if child is Label and (child as Control).is_visible_in_tree() and not skip:
			var text_label := child as Label
			var wrapped: bool = text_label.autowrap_mode != TextServer.AUTOWRAP_OFF
			var rect: Rect2 = text_label.get_global_rect()
			if not wrapped and not text_label.text.is_empty() and rect.size.x > 0.0:
				var needed: float = text_label.get_minimum_size().x
				if needed > rect.size.x + 1.0:
					_failures.append(
						"%s: %s is clipped (needs %.0f, has %.0f) — \"%s\""
						% [label, text_label.name, needed, rect.size.x, text_label.text.left(24)]
					)
		if child is ScrollContainer and (child as Control).is_visible_in_tree() and not list_screen:
			var scroll := child as ScrollContainer
			var bar: VScrollBar = scroll.get_v_scroll_bar()
			if bar != null and bar.max_value > bar.page + 1.0:
				_failures.append(
					"%s: %s scrolls (%.0f of %.0f visible)"
					% [label, scroll.name, bar.page, bar.max_value]
				)
		_walk(child, viewport, label, list_screen, inside_scroll or child is ScrollContainer)


## B0-1: the belongings row only takes width once it holds something, so an
## unpopulated HUD passes this sweep saying nothing. Fill it with the widest
## build the game can produce — every weapon slot taken, passives past the
## budget (N9-55 lets a walked-to pickup exceed it), and enough loot types to
## trip the material cap — so the overlap check is actually about this row.
func _fill_belongings(hud: CombatHud) -> void:
	var weapons: Array = []
	for i: int in range(LevelUp.WEAPON_SLOTS):
		weapons.append({"id": "sword", "grade": "epic", "level": 8})
	var passives: Array = []
	for i: int in range(LevelUp.PASSIVE_SLOTS + 2):
		passives.append({"id": "attack_damage", "stacks": 9})
	var materials: Array = []
	for i: int in range(CombatHud.BELONGINGS_MATERIAL_MAX + 2):
		materials.append({"id": "whetstone", "count": 9})
	hud.set_belongings(weapons, passives, materials)
