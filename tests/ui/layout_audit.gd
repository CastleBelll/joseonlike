extends SceneTree
## Headless layout audit: overlap / off-screen / touch-target checks for
## every meta-ui screen at the real 540x960 mobile viewport, in both
## supported locales (Korean strings run longer than English and are where
## a fixed-size label first breaks).
##
## RUN DIRECTLY, not as a tests/run_tests.gd suite:
##   godot --headless --path . --script tests/ui/layout_audit.gd
## Control anchor/container layout needs a real process frame to resolve
## (proven empirically: right after instantiation every Control reports
## size (0,0) regardless of _ready() having already run; one frame later
## every rect is correct). tests/run_tests.gd calls every suite's run()
## synchronously inside its own _initialize() and never reaches a frame in
## between, so this audit cannot live there directly -- see
## tests/ui/test_layout_audit.gd, which shells out to this exact invocation
## (reusing OS.get_executable_path(), not a hardcoded "godot") and turns a
## non-zero exit into a suite failure.
##
## OVERLAP RULE: a pair of visible Controls is a genuine overlap when their
## global rects intersect UNLESS
##   (a) one is an ancestor of the other -- containment nesting (an icon
##       inside its button, a label inside its panel) is the entire point
##       of a tree, not a defect, or
##   (b) one rect fully encloses the other -- an intentional backdrop layer
##       (a full-screen Background/Dim, or the HUD's own strip backdrop)
##       sitting behind smaller foreground content is not competing with it
##       for space.
## Two same-sized, unrelated Controls landing on top of each other (two
## buttons, a button under another button) is exactly what remains flagged.
##
## Also flags: any visible Control whose rect is not fully within the
## 540x960 viewport (pushed off-screen / clipped), and any visible
## BaseButton smaller than the 44x44 minimum touch target this project
## requires.

const VIEWPORT_SIZE := Vector2i(540, 960)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(540.0, 960.0))
const MIN_TOUCH_TARGET := 44.0
const LOCALES := ["en", "ko"]

var _pending: Array[Dictionary] = []
var _findings: Array[String] = []

## This file is itself the --script entrypoint, which the GDScript compiler
## resolves before autoloads exist (the same pre-bootstrap window
## tests/core/test_run_state.gd's header documents for _init() vs
## _initialize() -- except this hits it even in _initialize(), because the
## whole file is compiled as one unit before either can run). So every
## autoload is fetched by NodePath into a plain-Node local, never referenced
## by bare name, and driven through call()/set()/emit_signal().
## Must match AchievementTracker.UNLOCKED_PREFIX (scripts/meta/achievements.gd).
const ACHV_UNLOCKED_PREFIX := "achv_unlocked_"

var _event_bus: Node
var _run_state: Node
var _achievement_tracker: Node
var _save_manager: Node

var _level_up_controls: Array[Node] = []
var _results_controls: Array[Node] = []
var _setup_frame_done: bool = false
var _quit_pending: bool = false
var _exit_code: int = 0
var _quit_wait_frames: int = 10


func _initialize() -> void:
	_event_bus = root.get_node("EventBus")
	_run_state = root.get_node("RunState")
	_achievement_tracker = root.get_node("AchievementTracker")
	_save_manager = root.get_node("SaveManager")

	var load_result: Error = root.get_node("GameData").call("load_all")
	if load_result != OK:
		push_error("layout_audit: GameData.load_all() failed (error %d); auditing with empty content" % load_result)

	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		_queue("title", "res://scenes/ui/title.tscn", locale)
		_queue("camp", "res://scenes/basecamp/camp.tscn", locale)
		_queue("character_select", "res://scenes/ui/character_select.tscn", locale)

		_run_state.set("character_id", "taoist")
		_queue("area_select", "res://scenes/ui/area_select.tscn", locale)
		_queue("settings", "res://scenes/ui/settings.tscn", locale)
		_queue("achievements_quests", "res://scenes/ui/achievements_quests.tscn", locale)

		_setup_hud_state()
		_queue("hud", "res://scenes/ui/hud.tscn", locale)

		var level_up: Dictionary = _queue("level_up_choice", "res://scenes/ui/level_up_choice.tscn", locale)
		_level_up_controls.append(level_up["control"])

		var results: Dictionary = _queue("results", "res://scenes/ui/results.tscn", locale)
		_results_controls.append(results["control"])


## level_up_choice/results need their OWN _ready() to have populated their
## @onready node refs before EventBus.level_reached/display_result() can
## touch them safely -- and _ready() here turned out to NOT always run
## synchronously inside add_child() (it does for the first few scenes queued
## in one _initialize(), but not reliably once a signal has already fired
## re-entrantly through render_choices()'s own add_child calls; verified
## empirically, not documented Godot behaviour). So this waits one full
## _process() frame after every scene is queued -- guaranteeing every
## _ready() in the batch has run -- before doing anything that depends on it.
func _run_post_ready_setup() -> void:
	# One emit reaches every currently-connected level_up_choice instance
	# (both locales queued in _initialize() are already connected by now).
	if not _level_up_controls.is_empty():
		_event_bus.emit_signal("level_reached", 9, _stress_level_up_choices())

	# Boss bar + damage/pickup toasts are dressed HUD states, not just the
	# idle strip -- drive both locale instances into them so a real overlap
	# (toast under boss bar, boss bar under weapon chips) would actually
	# get caught here instead of only showing up in a live run.
	_event_bus.emit_signal("boss_spawned", "temple_guardian")
	_event_bus.emit_signal("player_damaged", 12.0, 40.0)
	_event_bus.emit_signal("xp_gained", 5)

	_achievement_tracker.call("snapshot_before_run")
	_save_manager.call("set_value", ACHV_UNLOCKED_PREFIX + "first_boss", true)
	_save_manager.call("set_value", ACHV_UNLOCKED_PREFIX + "goblin_hunter", true)
	for control: Node in _results_controls:
		control.call("display_result", {"victory": true, "time_sec": 605.0, "kills": 87, "gold": 240})


## Instantiates scene_path in its own 540x960 SubViewport (isolated
## coordinate space per screen) and records it for the next frame's audit.
func _queue(screen_id: String, scene_path: String, locale: String) -> Dictionary:
	var sv := SubViewport.new()
	sv.size = VIEWPORT_SIZE
	root.add_child(sv)

	# Screen roots vary (Control for camp/title/character_select/results,
	# CanvasLayer for hud/level_up_choice's overlay pattern), so this stays
	# untyped Node -- _collect_visible() below descends through either kind.
	var packed: PackedScene = load(scene_path)
	var inst: Node = packed.instantiate()
	sv.add_child(inst)

	var entry: Dictionary = {"label": "%s[%s]" % [screen_id, locale], "control": inst}
	_pending.append(entry)
	return entry


func _setup_hud_state() -> void:
	_run_state.call("reset")
	_run_state.set("character_id", "taoist")
	_run_state.set("stage_id", "bamboo_forest")
	_run_state.set("level", 7)
	_run_state.set("xp", 12)
	_run_state.set("kills", 128)
	_run_state.set("elapsed_sec", 305.0)
	# Four weapon chips: the worst realistic case for the HUD's own row
	# colliding with the HP/XP/timer/kills cluster above it.
	_run_state.set("weapons", [
		{"id": "old_talisman", "level": 5},
		{"id": "sword", "level": 3},
		{"id": "bow", "level": 2},
		{"id": "fire_talisman", "level": 1},
	])


## Three choices (the real max -- RunState.CHOICES_PER_LEVEL) with
## realistic-length Korean strings, the case most likely to overflow a
## fixed-size card.
func _stress_level_up_choices() -> Array[Dictionary]:
	return [
		{"id": "fire_talisman", "kind": "weapon_new", "name_ko": "화염 부적 획득", "name_en": "Acquire Fire Talisman", "description_ko": "화염 속성 피해를 입히는 신규 부적을 획득합니다."},
		{"id": "old_talisman", "kind": "weapon_upgrade", "name_ko": "낡은 부적 강화", "name_en": "Upgrade Old Talisman", "description_ko": "낡은 부적 Lv.4 / 8"},
		{"id": "attack_speed", "kind": "passive", "name_ko": "공격 속도 증가", "name_en": "Increased Attack Speed", "description_ko": "공격 속도가 8% 증가합니다. (3 / 5 스택)"},
	]


## Frame 1: every _ready() queued in _initialize() is now guaranteed to have
## run, so it is safe to drive level_up_choice/results into their populated
## state. Frame 2: that state (and everything else) has had a layout pass,
## so measurement is accurate. See _run_post_ready_setup()'s comment.
func _process(_delta: float) -> bool:
	if not _setup_frame_done:
		_setup_frame_done = true
		_run_post_ready_setup()
		return false

	if _quit_pending:
		_quit_wait_frames -= 1
		if _quit_wait_frames > 0:
			return false
		quit(_exit_code)
		return true

	for entry: Dictionary in _pending:
		var label: String = entry["label"]
		var control: Node = entry["control"]
		_findings.append_array(_find_overlaps(label, control))
		_findings.append_array(_find_offscreen(label, control))
		_findings.append_array(_find_small_touch_targets(label, control))

	if _findings.is_empty():
		print_rich("[color=green]LAYOUT AUDIT PASS[/color] 0 findings across %d screen/locale instances" % _pending.size())
		_exit_code = 0
	else:
		for finding: String in _findings:
			print_rich("[color=red]LAYOUT FINDING[/color] %s" % finding)
		print_rich("[color=red]LAYOUT AUDIT FAIL[/color] %d finding(s)" % _findings.size())
		_exit_code = 1

	# The level_reached stress-emit above drives level_up_choice.gd's real
	# _show_panel(), which fires UiSound.play_level_up() -- a fire-and-forget
	# AudioStreamPlayer (scripts/ui/ui_sound.gd) added directly under root,
	# freed only by its own "finished" signal once playback completes. This
	# script used to quit within the same or next frame, nowhere near a ~1s
	# WAV's natural finish, so "finished" never fired and both the player
	# and its AudioStreamPlayback leaked at exit -- confirmed via
	# --verbose: AudioStreamWAV/AudioStreamPlaybackWAV pointing straight at
	# level_up.wav. Calling stop() and freeing the node immediately did NOT
	# fix it either (verified): the Dummy audio driver headless runs on
	# still needs several real engine ticks to process a stop request on
	# its mix-thread side before the playback resource actually releases --
	# there is no synchronous "stop now" here. ui_sound.gd's finished-signal
	# cleanup is correct for a real play session (the whole process exits
	# together regardless of any single stream), so the fix belongs here:
	# this script is what deliberately triggers that real side effect for
	# stress-testing, so it is what should own tearing it down -- by
	# stopping playback and then holding quit() for _quit_wait_frames more
	# frames (empirically the minimum that reliably clears the leak across
	# repeated runs was under 10; kept a small margin above that).
	for child in root.get_children():
		if child is AudioStreamPlayer:
			child.stop()

	_quit_pending = true
	return false


## A ScrollContainer clips its content to its own rect for both rendering and
## hit-testing -- content scrolled past that boundary is genuinely invisible,
## not a layout bug. Both checks below compare this clipped "effective" rect
## instead of the raw global rect so a long, legitimately-scrollable list
## (achievements_quests' achievement rows, e.g.) does not read as pushed
## off-screen or as colliding with a full-screen backdrop it is actually
## sitting safely behind. Touch-target sizing (_find_small_touch_targets)
## intentionally keeps using the raw rect -- that check is about a control's
## own defined size, not whether scrolling currently hides it.
func _visible_rects(screen_root: Node) -> Array[Dictionary]:
	var controls: Array[Control] = []
	_collect_visible(screen_root, controls)

	var entries: Array[Dictionary] = []
	for control: Control in controls:
		var rect: Rect2 = control.get_global_rect()
		var scroll: Control = _nearest_scroll_container(control)
		if scroll != null:
			rect = rect.intersection(scroll.get_global_rect())
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue  # scrolled fully out of view -- nothing visible to check
		entries.append({"control": control, "rect": rect})
	return entries


func _nearest_scroll_container(control: Control) -> Control:
	var current: Node = control.get_parent()
	while current != null:
		if current is ScrollContainer:
			return current
		current = current.get_parent()
	return null


func _find_overlaps(label: String, screen_root: Node) -> Array[String]:
	var entries: Array[Dictionary] = _visible_rects(screen_root)

	var findings: Array[String] = []
	for i in range(entries.size()):
		for j in range(i + 1, entries.size()):
			var a: Control = entries[i]["control"]
			var b: Control = entries[j]["control"]
			if _is_ancestor(a, b) or _is_ancestor(b, a):
				continue

			var rect_a: Rect2 = entries[i]["rect"]
			var rect_b: Rect2 = entries[j]["rect"]
			if not rect_a.intersects(rect_b):
				continue
			if rect_a.encloses(rect_b) or rect_b.encloses(rect_a):
				continue

			findings.append("%s: OVERLAP %s %s <-> %s %s" % [
				label, str(a.get_path()), rect_a, str(b.get_path()), rect_b,
			])
	return findings


func _find_offscreen(label: String, screen_root: Node) -> Array[String]:
	var entries: Array[Dictionary] = _visible_rects(screen_root)

	var findings: Array[String] = []
	for entry: Dictionary in entries:
		var control: Control = entry["control"]
		var rect: Rect2 = entry["rect"]
		if not VIEWPORT_RECT.encloses(rect):
			findings.append("%s: OFFSCREEN %s %s extends outside the %s viewport" % [
				label, str(control.get_path()), rect, VIEWPORT_RECT,
			])
	return findings


func _find_small_touch_targets(label: String, screen_root: Node) -> Array[String]:
	var controls: Array[Control] = []
	_collect_visible(screen_root, controls)

	var findings: Array[String] = []
	for control: Control in controls:
		if not (control is BaseButton):
			continue
		var size: Vector2 = control.get_global_rect().size
		if size.x < MIN_TOUCH_TARGET or size.y < MIN_TOUCH_TARGET:
			findings.append("%s: SMALL_TOUCH_TARGET %s size=%s is below %.0fx%.0f" % [
				label, str(control.get_path()), size, MIN_TOUCH_TARGET, MIN_TOUCH_TARGET,
			])
	return findings


func _collect_visible(node: Node, out: Array[Control]) -> void:
	if node is Control:
		var control: Control = node
		if control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0:
			out.append(control)
	for child in node.get_children():
		_collect_visible(child, out)


func _is_ancestor(maybe_ancestor: Node, node: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if current == maybe_ancestor:
			return true
		current = current.get_parent()
	return false
