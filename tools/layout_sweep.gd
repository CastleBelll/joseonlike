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
## Screens whose content is a LIST that grows with data — the 명부수 tree, the
## bestiary and the achievement ledger are meant to scroll, so only their
## chrome (anything outside the scroll) is held to the fit rule.
const LIST_SCREENS: Array[String] = ["meta", "bestiary", "achievements"]
const SCREENS := {
	"title": "res://scenes/title.tscn",
	"camp": "res://scenes/camp.tscn",
	"select": "res://scenes/character_select.tscn",
	"meta": "res://scenes/meta_tree.tscn",
	"bestiary": "res://scenes/bestiary.tscn",
	"achievements": "res://scenes/achievements.tscn",
}

var _failures: Array[String] = []


func _ready() -> void:
	_seed_profile()
	for window: Vector2i in WINDOWS:
		await _sweep_window(window)
	if _failures.is_empty():
		print("PASS layout_sweep: %d screens x %d devices, nothing overflows or scrolls"
			% [SCREENS.size() + 2, WINDOWS.size()])
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
	var base: Vector2 = Vector2(DisplayAdapterService.base_for(window))
	var window_ratio: float = float(window.x) / float(window.y)
	var base_ratio: float = base.x / base.y
	if window_ratio > base_ratio:
		return Vector2(base.y * window_ratio, base.y)
	return Vector2(base.x, base.x / window_ratio)


func _sweep_window(window: Vector2i) -> void:
	var canvas: Vector2 = canvas_for(window)
	for key: String in SCREENS:
		await _check_screen(key, String(SCREENS[key]), window, canvas, false)
	# The two popups ride over the camp, which owns the settings entry.
	await _check_screen("settings", String(SCREENS["camp"]), window, canvas, true)
	await _check_screen("levelup", String(SCREENS["camp"]), window, canvas, true, true)


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
	var label: String = "%s @ %dx%d (canvas %.0fx%.0f)" % [key, window.x, window.y, canvas.x, canvas.y]
	var rect := Rect2(Vector2.ZERO, canvas)
	var list_screen: bool = LIST_SCREENS.has(key)
	_walk(screen, rect, label, list_screen, false)
	if overlay != null:
		_walk(overlay, rect, label, false, false)
	if overlay != null:
		overlay.queue_free()
	host.queue_free()
	await get_tree().process_frame


## Popups are CanvasLayers anchored to the real viewport, so the sweep sizes
## their blocker to the device canvas and re-runs their layout.
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
func _walk(node: Node, viewport: Rect2, label: String, list_screen: bool, inside_scroll: bool) -> void:
	for child: Node in node.get_children():
		# A list screen's rows live below the fold on purpose; only its chrome
		# (back button, header, CTA) has to be on screen.
		var skip: bool = list_screen and inside_scroll
		if child is Button and (child as Control).is_visible_in_tree() and not skip:
			var button := child as Button
			var box: Rect2 = button.get_global_rect()
			if box.size.x > 0.0 and box.size.y > 0.0 and not viewport.encloses(box):
				_failures.append(
					"%s: %s leaves the screen (%.0f,%.0f %.0fx%.0f)"
					% [label, button.name, box.position.x, box.position.y, box.size.x, box.size.y]
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
