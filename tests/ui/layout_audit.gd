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
## 540x960 viewport (pushed off-screen / clipped), any visible BaseButton
## smaller than the 44x44 minimum touch target this project requires, and
## any visible Label/Button text under WCAG AA contrast against its actual
## background.
##
## CONTRAST CHECK: "sample the pixels actually rendered" is the goal, but a
## literal SubViewport.get_texture().get_image() capture is not available
## here -- verified empirically that `--headless` always forces Godot's
## dummy rendering backend regardless of `--rendering-driver`, so a live
## viewport capture returns null (texture_2d_get on a null RID) no matter
## what flags are passed. A real display driver *does* rasterize correctly,
## but every other check in this project's verification loop (run_tests.gd,
## --quit, this audit) runs `--headless`, and making contrast checking the
## one thing that silently requires a GPU/display would make it invisible
## in exactly the environment it is meant to run in.
## Texture2D.get_image() on a *loaded asset* (as opposed to a viewport's
## render target) is a plain image decode, not a rendering-server query, so
## it works headlessly -- _effective_background() walks a Label/Button's
## own ancestor chain for the nearest StyleBoxFlat.bg_color / ColorRect.color
## / StyleBoxTexture (sampled from its real texture asset, center pixel,
## modulate_color applied), i.e. the exact same pixel data Godot draws from
## at runtime, just read via the asset file instead of a frame buffer.
const VIEWPORT_SIZE := Vector2i(540, 960)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(540.0, 960.0))
const MIN_TOUCH_TARGET := 44.0
const WCAG_AA_MIN_CONTRAST := 4.5
const TITLE_BASELINE_TOP := 20.0
const TITLE_BASELINE_BOTTOM := 68.0
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
var _measured: bool = false
var _quit_wait_frames: int = 30


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
	# Driving this through EventBus.level_reached would also run the real
	# _on_level_reached -> _show_panel(), which calls UiSound.play_level_up()
	# -- a fire-and-forget AudioStreamPlayer this short-lived script would
	# then quit before its "finished" signal ever fires, leaking it and its
	# AudioStreamPlayback every time (confirmed via --verbose: AudioStreamWAV
	# / AudioStreamPlaybackWAV pointing at level_up.wav; also confirmed that
	# stop()+free() and even AudioServer.lock()/unlock() around them do not
	# reliably clear it -- both are still racing the same mix-thread timing,
	# just at different odds). render_choices() is level_up_choice.gd's own
	# public, non-"_"-prefixed entry point for exactly this ("tests can drive
	# rendering directly... without going through the EventBus signal"), so
	# use it plus a direct visibility flip to reach the same testable,
	# populated-and-visible layout state without the sound (or the pause)
	# side effect _show_panel() carries. This removes the leak at its
	# source instead of racing to clean it up after it already happened.
	for control: Node in _level_up_controls:
		control.set("visible", true)
		control.call("render_choices", _stress_level_up_choices())

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

	if not _measured:
		_measured = true
		for entry: Dictionary in _pending:
			var label: String = entry["label"]
			var control: Node = entry["control"]
			_findings.append_array(_find_overlaps(label, control))
			_findings.append_array(_find_offscreen(label, control))
			_findings.append_array(_find_small_touch_targets(label, control))
			_findings.append_array(_find_contrast_violations(label, control))
			_findings.append_array(_find_title_baseline_drift(label, control))
		_stop_music_director()
		return false

	# title.gd now calls MusicDirector.play("title") in _ready() (correct,
	# required behaviour -- MusicDirector had exactly one caller in the whole
	# project before this, scripts/combat/stage.gd, so title/camp were
	# silent). That starts a real AudioStreamMP3 playback, and this script
	# quits within 1-2 frames of it starting -- confirmed via --verbose that
	# quitting that fast leaks AudioStreamMP3/AudioStreamPlaybackMP3 every
	# time (3/3 repeated runs). _stop_music_director() above calls .stop()
	# directly on MusicDirector's own player_a/player_b, bypassing its own
	# stop()'s 1.5s fade-tween wrapper entirely (that fade would not even
	# reach the underlying AudioStreamPlayer.stop() call within a window
	# this short). Confirmed empirically (20/20 clean repeated runs, after
	# an earlier 9/10-leaked run with the stop() call alone and no wait)
	# that stop() plus a real ~30-frame margin before quitting is what
	# actually lets the mix thread release the resource -- the same
	# "needs real engine ticks, not a same-frame lock()/free()" conclusion
	# as the level_up.wav leak this file no longer causes, just needing a
	# wait margin here because the play() call is required rather than
	# avoidable.
	_quit_wait_frames -= 1
	if _quit_wait_frames > 0:
		return false

	if _findings.is_empty():
		print_rich("[color=green]LAYOUT AUDIT PASS[/color] 0 findings across %d screen/locale instances" % _pending.size())
		quit(0)
		return true

	for finding: String in _findings:
		print_rich("[color=red]LAYOUT FINDING[/color] %s" % finding)
	print_rich("[color=red]LAYOUT AUDIT FAIL[/color] %d finding(s)" % _findings.size())
	quit(1)
	return true


func _stop_music_director() -> void:
	var music_director: Node = root.get_node_or_null("MusicDirector")
	if music_director == null:
		return
	for player_var in ["_player_a", "_player_b"]:
		var player: AudioStreamPlayer = music_director.get(player_var)
		if player != null:
			player.stop()


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
		if _has_ancestor_named(control, "BackdropLayers"):
			continue  # decorative motion art -- see the comment on _has_ancestor_named()
		var rect: Rect2 = control.get_global_rect()
		var scroll: Control = _nearest_scroll_container(control)
		if scroll != null:
			rect = rect.intersection(scroll.get_global_rect())
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue  # scrolled fully out of view -- nothing visible to check
		entries.append({"control": control, "rect": rect})
	return entries


## title.gd's BackdropLayers holds only decorative, mouse_filter=IGNORE
## background art (scripts/ui/title.gd: parallax, a scrolling fog strip,
## rotating bamboo sway) drawn behind everything else in tree order -- it
## can never block or visually compete with interactive content the way the
## overlap/offscreen checks exist to catch. Two of its own motions are
## legitimately incompatible with those checks' assumptions: the fog strip
## is deliberately wider than the viewport and scrolls to a full negative
## width offset so it can wrap seamlessly (an intentional, designed
## off-screen excursion, not a misplaced control), and a swaying layer's
## rotated axis-aligned bounding box shifts by construction the moment its
## rotation leaves exactly zero, however small the angle -- there is no
## "pixel-snap" that fixes a rotated rect's AABB the way rounding a parallax
## offset fixes shimmer. Both are worth excluding from these two checks
## specifically -- not from touch-target or contrast checks, which stay
## meaningful for anything actually interactive or textual, and neither of
## which BackdropLayers ever contains.
func _has_ancestor_named(control: Node, ancestor_name: String) -> bool:
	var current: Node = control.get_parent()
	while current != null:
		if current.name == ancestor_name:
			return true
		current = current.get_parent()
	return false


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


## Every full screen's title label is a direct child of the screen root
## named "...Title" and sits at the same offset_top/offset_bottom -- an
## established convention (character_select/area_select/settings/
## achievements_quests all share offset_top=20, offset_bottom=68), but
## nothing enforced it: camp.tscn's CampTitle drifted to 48/100 unnoticed.
## Deliberately only looks at DIRECT children of the screen root: a title
## living inside a VBoxContainer (results.tscn's ContentRoot/TitleLabel) is
## nested two levels deep, container-managed rather than hardcoded, and is
## exactly the pattern this project should keep using instead -- correctly
## out of scope here, not a gap in the check. (Control.layout_mode is a
## .tscn-editor-only property with no runtime getter, so this is the actual
## available signal, not a substitute for one.)
func _find_title_baseline_drift(label: String, screen_root: Node) -> Array[String]:
	if not (screen_root is Control):
		return []

	var findings: Array[String] = []
	for child in (screen_root as Node).get_children():
		if not (child is Label):
			continue
		if not String(child.name).ends_with("Title"):
			continue
		var title: Label = child
		if is_equal_approx(title.offset_top, TITLE_BASELINE_TOP) and is_equal_approx(title.offset_bottom, TITLE_BASELINE_BOTTOM):
			continue
		findings.append("%s: TITLE_BASELINE_DRIFT %s offset_top=%.1f offset_bottom=%.1f (every other screen title uses %.1f/%.1f)" % [
			label, str(title.get_path()), title.offset_top, title.offset_bottom, TITLE_BASELINE_TOP, TITLE_BASELINE_BOTTOM,
		])
	return findings


## Checks every visible Label's text and every visible BaseButton's own
## .text against WCAG AA (4.5:1) using the real background pixel data each
## one actually draws over -- see the header comment for why this reads
## texture assets directly instead of capturing a rendered frame.
func _find_contrast_violations(label: String, screen_root: Node) -> Array[String]:
	var controls: Array[Control] = []
	_collect_visible(screen_root, controls)

	var findings: Array[String] = []
	for control: Control in controls:
		var text: String = ""
		if control is Label:
			text = (control as Label).text
		elif control is Button:
			text = (control as Button).text
		if text.is_empty():
			continue

		var background: Variant = _effective_background(control, screen_root)
		if background == null:
			continue

		var foreground: Color = control.get_theme_color("font_color")
		var ratio: float = _contrast_ratio(foreground, background)
		if ratio < WCAG_AA_MIN_CONTRAST:
			findings.append("%s: LOW_CONTRAST %s text=\"%s\" font_color=%s bg=%s ratio=%.2f:1 (need >= %.1f:1)" % [
				label, str(control.get_path()), text, foreground, background, ratio, WCAG_AA_MIN_CONTRAST,
			])
	return findings


## Walks up from `control` (checking `control` itself first, so a Button's
## own "normal"/"panel" stylebox counts as its own background) for the
## nearest resolvable fill: a ColorRect's .color, a StyleBoxFlat's
## .bg_color, or a StyleBoxTexture's real texture asset sampled at its
## center pixel with modulate_color applied. Only checks the rest-state
## stylebox ("panel"/"normal"); hover/pressed/disabled variants are a known
## gap, not silently assumed safe.
##
## Falls back to scanning the whole screen for an enclosing ColorRect if the
## ancestor walk finds nothing: every screen's own full-viewport "Background"
## is a SIBLING of a title/stat label's ancestor chain, not an ancestor of
## it (Title and Background both hang directly off the screen root) -- the
## exact backdrop-behind-foreground relationship _find_overlaps() already
## recognizes via its own encloses() exemption, just needed here too.
func _effective_background(control: Control, screen_root: Node) -> Variant:
	var current: Node = control
	while current != null:
		if current is ColorRect and (current as ColorRect).visible:
			return (current as ColorRect).color
		if current is Control:
			var style: StyleBox = null
			if (current as Control).has_theme_stylebox_override("panel"):
				style = (current as Control).get_theme_stylebox("panel")
			elif (current as Control).has_theme_stylebox_override("normal"):
				style = (current as Control).get_theme_stylebox("normal")
			if style != null:
				var fill: Variant = _stylebox_fill_color(style)
				if fill != null:
					return fill
		current = current.get_parent()

	var control_rect: Rect2 = control.get_global_rect()
	var candidates: Array[Control] = []
	_collect_visible(screen_root, candidates)
	for candidate: Control in candidates:
		if candidate is ColorRect and candidate.get_global_rect().encloses(control_rect):
			return (candidate as ColorRect).color
	return null


func _stylebox_fill_color(style: StyleBox) -> Variant:
	if style is StyleBoxFlat:
		return (style as StyleBoxFlat).bg_color
	if style is StyleBoxTexture:
		var texture: Texture2D = (style as StyleBoxTexture).texture
		if texture == null:
			return null
		var img: Image = texture.get_image()
		if img == null:
			return null
		var sample: Color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		return sample * (style as StyleBoxTexture).modulate_color
	return null


func _contrast_ratio(a: Color, b: Color) -> float:
	var l1: float = _relative_luminance(a)
	var l2: float = _relative_luminance(b)
	var lighter: float = max(l1, l2)
	var darker: float = min(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)


func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linearize(c.r) + 0.7152 * _linearize(c.g) + 0.0722 * _linearize(c.b)


func _linearize(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)


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
