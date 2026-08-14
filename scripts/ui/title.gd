extends Control
## Title / main menu screen -- JOSEONLIKE's boot destination
## (SceneRouter.goto_title(), core-engine).
##
## asset/UI_ART_REPORT.md item 1: five actions (Start, Continue, Settings,
## Credits, Quit) plus a version plaque. Start is the one clearly primary
## action (tallest, full width); Continue is demonstrably lighter (shorter);
## Settings/Credits are a secondary row; Quit is smallest -- same 44x44
## touch-target floor as everything else (UiPalette.apply_button_style()
## enforces that regardless), but narrow and centred instead of full width,
## so its footprint is visibly smaller without touching opacity (an alpha
## trick would risk the WCAG contrast this project measures against real
## background pixels -- see tests/ui/layout_audit.gd -- since modulate alpha
## blends toward whatever backdrop is behind it, not toward a known colour).
##
## ASSET_SPEC.md section 3: the backdrop is a layered set, not a flat image
## -- asset/title/layers/*.png (sky/moon_glow/palace/bamboo_far/bamboo_near/
## ground), asset/title/fog_strip.png, asset/title/mote.png. Every layer is
## the full 540x960 canvas stacked at the origin (no offsets to compute).
## The layer set does not exist in this worktree yet as of this writing, so
## every path is resolved through a named constant and this falls back to
## the flat asset/stage/backdrops/main_menu.png (no motion) when the layers
## are absent -- the same "check ResourceLoader.exists(), do not block on a
## sibling worktree's art" pattern SceneRouter._goto() already uses for a
## scene path a worktree has not landed yet.

const TITLE_EN: Texture2D = preload("res://asset/title/joseonlike_en.png")
const TITLE_KO: Texture2D = preload("res://asset/title/joseonlike_ko.png")
const BACKDROP_FLAT: Texture2D = preload("res://asset/stage/backdrops/main_menu.png")
const VERSION_PLAQUE: Texture2D = preload("res://asset/ui/main/version_plaque_9slice.png")

const ICON_START: Texture2D = preload("res://asset/ui/main/start.png")
const ICON_SETTINGS: Texture2D = preload("res://asset/ui/main/settings.png")
const ICON_CREDITS: Texture2D = preload("res://asset/ui/main/credits.png")
const ICON_QUIT: Texture2D = preload("res://asset/ui/main/quit.png")

## No version-numbering scheme exists yet (project.godot has no app version
## field); this is a placeholder for the plaque, not a real release number.
const VERSION_TEXT := "M1"

## First boot skips every selection screen and drops straight into combat
## (GDD v2 section 28: the first 60 seconds). Fixed defaults on purpose —
## a brand-new player has nothing unlocked to choose from anyway.
const FIRST_RUN_CHARACTER := "taoist"
const FIRST_RUN_STAGE := "bamboo_forest"

const LAYER_SKY := "res://asset/title/layers/sky.png"
const LAYER_MOON_GLOW := "res://asset/title/layers/moon_glow.png"
const LAYER_PALACE := "res://asset/title/layers/palace.png"
const LAYER_BAMBOO_FAR := "res://asset/title/layers/bamboo_far.png"
const LAYER_BAMBOO_NEAR := "res://asset/title/layers/bamboo_near.png"
const LAYER_GROUND := "res://asset/title/layers/ground.png"
const LAYER_FOG_STRIP := "res://asset/title/fog_strip.png"
const LAYER_MOTE := "res://asset/title/mote.png"

const CANVAS_SIZE := Vector2(540.0, 960.0)
const FOG_SIZE := Vector2(1080.0, 320.0)
const FOG_POSITION := Vector2(0.0, 600.0)

## depth key -> parallax ratio. Depth reads from the RATIO between layers,
## not the absolute pixel distance -- sky barely moves, ground/bamboo_near
## move most. Keys not listed here (moon_glow, fog, ground's own silhouette
## detail) intentionally get no independent parallax entry: moon_glow tracks
## its layer visually via breathing alone, and giving every single layer its
## own drift would read as the screen swimming, not depth.
const PARALLAX_RATIOS := {
	"sky": 0.0,
	"palace": 0.18,
	"bamboo_far": 0.32,
	"bamboo_near": 0.55,
	"ground": 0.7,
}
const PARALLAX_MAX_PX := 6.0
const PARALLAX_LERP_SPEED := 4.0

const FOG_SCROLL_SECONDS := 40.0
const BAMBOO_SWAY_DEGREES := 0.6
const BAMBOO_SWAY_SECONDS := 6.0
const BAMBOO_SWAY_PHASE_DELAY_SEC := 2.1
const MOON_BREATH_SECONDS := 4.5
const MOON_BREATH_MIN_ALPHA := 0.35
const MOON_BREATH_MAX_ALPHA := 0.75
const MOTE_COUNT := 10
const MOTE_LIFETIME_SEC := 8.0
const MOTE_SPAWN_POSITION := Vector2(270.0, 900.0)

const LOGO_ENTRANCE_SECONDS := 0.6
const LOGO_ENTRANCE_RISE_PX := 18.0

const PRIMARY_ICON_PX := 32.0
const SECONDARY_ICON_PX := 20.0

## The in-game hunter standing on the path fills the dead band between the
## palace and the menu (owner feedback: the middle of the screen was empty).
## Reuses the side-view idle at the same integer downscale family as combat.
const HERO_SPRITE := "res://asset/character/Taoist/side/idle.png"
const HERO_SIZE := Vector2(64.0, 64.0)
const HERO_POSITION := Vector2(238.0, 580.0)

@onready var _backdrop: TextureRect = $Backdrop
@onready var _backdrop_layers: Control = $BackdropLayers
@onready var _logo: TextureRect = $Logo
@onready var _start_button: Button = $Actions/StartButton
@onready var _settings_button: Button = $Actions/SecondaryRow/SettingsButton
@onready var _credits_button: Button = $Actions/SecondaryRow/CreditsButton
@onready var _quit_button: Button = $Actions/SecondaryRow/QuitButton
@onready var _version_plaque: NinePatchRect = $VersionPlaque
@onready var _version_label: Label = $VersionPlaque/VersionLabel
@onready var _credits_panel: Panel = $CreditsPanel
@onready var _credits_body: Label = $CreditsPanel/PanelMargin/PanelBox/CreditsBody
@onready var _credits_close: Button = $CreditsPanel/PanelMargin/PanelBox/CreditsClose

var _return_focus_target: Control = null

## Sampled once when the title opens: no profile file = a player who has
## never played. Sampled at _ready and not at press time, because the
## autosave timer can write the file while they sit on this screen and a
## genuinely new player must still get the first-run flow.
@onready var _first_boot: bool = not FileAccess.file_exists(SaveManager.SAVE_PATH)

var _layered_backdrop: bool = false
var _parallax_layers: Array[Dictionary] = []   ## [{node, ratio, base_position}]
var _pointer_target: Vector2 = Vector2.ZERO    ## -1..1 per axis
var _pointer_offset: Vector2 = Vector2.ZERO    ## smoothed toward _pointer_target
var _motion_tweens: Array[Tween] = []
var _motes: GPUParticles2D = null


func _ready() -> void:
	MusicDirector.play("title")

	_setup_backdrop()
	set_process(_layered_backdrop)

	_logo.texture = LocaleText.texture(TITLE_KO, TITLE_EN)
	_animate_logo_entrance()

	# One entry point on purpose: the profile autosaves and the game resumes
	# it automatically, so a separate Continue action carried no meaning
	# (owner decision 2026-08-14).
	_configure_action(_start_button, ICON_START, "menu_start")
	_start_button.pressed.connect(_on_start_pressed)

	# The secondary row is deliberately lighter than Start: smaller icons and
	# label-size text, so the one primary action owns the block.
	_configure_action(_settings_button, ICON_SETTINGS, "menu_settings", SECONDARY_ICON_PX, UiPalette.FONT_SIZE_LABEL)
	_settings_button.pressed.connect(_on_settings_pressed)

	_configure_action(_credits_button, ICON_CREDITS, "menu_credits", SECONDARY_ICON_PX, UiPalette.FONT_SIZE_LABEL)
	_credits_button.pressed.connect(_on_credits_pressed)

	_configure_action(_quit_button, ICON_QUIT, "menu_quit", SECONDARY_ICON_PX, UiPalette.FONT_SIZE_LABEL)
	_quit_button.pressed.connect(_on_quit_pressed)

	_setup_hero()

	_version_plaque.texture = VERSION_PLAQUE
	_version_plaque.patch_margin_left = 8
	_version_plaque.patch_margin_top = 8
	_version_plaque.patch_margin_right = 8
	_version_plaque.patch_margin_bottom = 8
	_version_label.text = VERSION_TEXT
	_version_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_version_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)

	_credits_panel.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())
	_credits_body.text = LocaleText.ui("credits_body")
	_credits_body.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_credits_close.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_credits_close)
	_credits_close.pressed.connect(_close_credits)
	_credits_panel.visible = false

	_start_button.grab_focus()


## Icon (left) + label (right) inside the existing button chrome, matching
## the pattern already used for camp buildings/character cards. Icon and font
## size are parameters so secondary actions can visibly weigh less.
func _configure_action(
	button: Button,
	icon_texture: Texture2D,
	label_key: String,
	icon_px: float = PRIMARY_ICON_PX,
	font_size: int = UiPalette.FONT_SIZE_BODY
) -> void:
	UiPalette.apply_button_style(button)
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, 44.0)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = LocaleText.ui(label_key)
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


## A still hunter on the path. Static on purpose — the backdrop already
## breathes (fog, sway, motes); a second animated focal point would compete
## with the menu.
func _setup_hero() -> void:
	if not ResourceLoader.exists(HERO_SPRITE):
		return
	var hero := TextureRect.new()
	# expand_mode BEFORE texture and size: with the default EXPAND_KEEP_SIZE
	# the moment the 512px texture lands the minimum size clamps the rect to
	# texture size and a later size assignment cannot shrink it back.
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.texture = load(HERO_SPRITE)
	hero.custom_minimum_size = HERO_SIZE
	hero.size = HERO_SIZE
	hero.position = HERO_POSITION
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Behind the menu/logo Controls added later in the tree order, but in
	# front of the backdrop layers.
	add_child(hero)
	move_child(hero, _backdrop_layers.get_index() + 1)


func _animate_logo_entrance() -> void:
	var final_position: Vector2 = _logo.position
	_logo.position = final_position - Vector2(0.0, LOGO_ENTRANCE_RISE_PX)
	_logo.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_logo, "position", final_position, LOGO_ENTRANCE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_logo, "modulate:a", 1.0, LOGO_ENTRANCE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _setup_backdrop() -> void:
	_layered_backdrop = ResourceLoader.exists(LAYER_SKY)
	if not _layered_backdrop:
		_backdrop.texture = BACKDROP_FLAT
		_backdrop_layers.visible = false
		return

	_backdrop.visible = false
	_add_layer(LAYER_SKY, "sky")
	var moon_glow: TextureRect = _add_layer(LAYER_MOON_GLOW, "moon_glow")
	_add_layer(LAYER_PALACE, "palace")
	var bamboo_far: TextureRect = _add_layer(LAYER_BAMBOO_FAR, "bamboo_far")
	var bamboo_near: TextureRect = _add_layer(LAYER_BAMBOO_NEAR, "bamboo_near")
	_setup_fog()
	_add_layer(LAYER_GROUND, "ground")
	_setup_bamboo_sway(bamboo_far, bamboo_near)
	_setup_moon_breath(moon_glow)
	_setup_motes()


## Adds one full-canvas layer stacked at the origin (ASSET_SPEC.md: "every
## layer is the full 540x960 canvas... no offsets to compute") if its asset
## exists, and registers it for parallax when depth_key carries a ratio.
## Point-anchored (not FULL_RECT) with an explicit size deliberately: a
## stretched-anchor Control recomputes .position from its anchors on every
## layout pass, which would fight the parallax offsets applied in
## _process() every frame. Returns null (adds nothing) when the asset is
## absent, so a partially-cut layer set still renders whatever IS ready
## instead of an all-or-nothing flat fallback.
func _add_layer(path: String, depth_key: String) -> TextureRect:
	if not ResourceLoader.exists(path):
		return null
	var layer := TextureRect.new()
	layer.texture = load(path)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.stretch_mode = TextureRect.STRETCH_KEEP
	layer.size = CANVAS_SIZE
	layer.position = Vector2.ZERO
	_backdrop_layers.add_child(layer)

	var ratio: float = float(PARALLAX_RATIOS.get(depth_key, 0.0))
	if ratio > 0.0:
		_parallax_layers.append({"node": layer, "ratio": ratio, "base_position": layer.position})
	return layer


func _setup_fog() -> void:
	if not ResourceLoader.exists(LAYER_FOG_STRIP):
		return
	var fog := TextureRect.new()
	fog.texture = load(LAYER_FOG_STRIP)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.stretch_mode = TextureRect.STRETCH_KEEP
	fog.size = FOG_SIZE
	fog.position = FOG_POSITION
	fog.modulate.a = 0.5
	_backdrop_layers.add_child(fog)

	## The strip is authored seamless horizontally and is exactly double the
	## viewport width, so sliding it left by its own full width and resetting
	## to 0 each loop is an invisible wrap, not a technique that depends on
	## guessing where a seam falls.
	var tween := create_tween().set_loops()
	tween.tween_property(fog, "position:x", FOG_POSITION.x - FOG_SIZE.x, FOG_SCROLL_SECONDS).from(FOG_POSITION.x).set_trans(Tween.TRANS_LINEAR)
	_motion_tweens.append(tween)


func _setup_bamboo_sway(bamboo_far: TextureRect, bamboo_near: TextureRect) -> void:
	if bamboo_far != null:
		_sway(bamboo_far, BAMBOO_SWAY_SECONDS, 0.0)
	## A shorter period plus a phase delay keeps bamboo_near visibly out of
	## sync with bamboo_far, so the pair reads as two independent layers
	## swaying rather than the whole screen wobbling in lockstep.
	if bamboo_near != null:
		_sway(bamboo_near, BAMBOO_SWAY_SECONDS * 0.8, BAMBOO_SWAY_PHASE_DELAY_SEC)


func _sway(layer: TextureRect, period_sec: float, phase_delay_sec: float) -> void:
	layer.pivot_offset = Vector2(layer.size.x * 0.5, layer.size.y)  # sways from its base, not its centre
	var amplitude: float = deg_to_rad(BAMBOO_SWAY_DEGREES)
	var tween := create_tween().set_loops()
	if phase_delay_sec > 0.0:
		tween.tween_interval(phase_delay_sec)
	tween.tween_property(layer, "rotation", amplitude, period_sec * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(layer, "rotation", -amplitude, period_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(layer, "rotation", 0.0, period_sec * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion_tweens.append(tween)


func _setup_moon_breath(moon_glow: TextureRect) -> void:
	if moon_glow == null:
		return
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	moon_glow.material = material
	moon_glow.modulate.a = MOON_BREATH_MIN_ALPHA

	var tween := create_tween().set_loops()
	tween.tween_property(moon_glow, "modulate:a", MOON_BREATH_MAX_ALPHA, MOON_BREATH_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(moon_glow, "modulate:a", MOON_BREATH_MIN_ALPHA, MOON_BREATH_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion_tweens.append(tween)


func _setup_motes() -> void:
	if not ResourceLoader.exists(LAYER_MOTE):
		return
	_motes = GPUParticles2D.new()
	_motes.texture = load(LAYER_MOTE)
	_motes.amount = MOTE_COUNT
	_motes.lifetime = MOTE_LIFETIME_SEC
	_motes.position = MOTE_SPAWN_POSITION
	_motes.process_material = _build_mote_material()
	_backdrop_layers.add_child(_motes)


func _build_mote_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 12.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 6.0
	material.initial_velocity_max = 14.0
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(230.0, 4.0, 1.0)
	material.color = Color(1.0, 1.0, 1.0, 0.6)
	material.scale_min = 0.6
	material.scale_max = 1.2

	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.15, 1.0))
	alpha_curve.add_point(Vector2(0.85, 1.0))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_texture := CurveTexture.new()
	alpha_texture.curve = alpha_curve
	material.alpha_curve = alpha_texture
	return material


## Whole-pixel offsets only: default_texture_filter=0 (nearest, set project-
## wide) shimmers under sub-pixel positions, the same class of mistake as
## combat's character motion needing pixel-snapping.
func _process(_delta: float) -> void:
	if _parallax_layers.is_empty():
		return
	var tilt: Vector2 = _sample_tilt()
	var target: Vector2 = (_pointer_target + tilt).clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	_pointer_offset = _pointer_offset.lerp(target, clampf(_delta * PARALLAX_LERP_SPEED, 0.0, 1.0))
	for entry: Dictionary in _parallax_layers:
		var node: Control = entry["node"]
		var ratio: float = entry["ratio"]
		var base: Vector2 = entry["base_position"]
		var raw: Vector2 = _pointer_offset * ratio * PARALLAX_MAX_PX
		node.position = base + raw.round()


## Accelerometer tilt as a small additional nudge on platforms that expose
## one; returns zero on desktop/unsupported hardware (the typical reading
## with no sensor), so this needs no platform check of its own.
func _sample_tilt() -> Vector2:
	var gravity: Vector3 = Input.get_gravity()
	if gravity.length() < 0.01:
		return Vector2.ZERO
	return Vector2(gravity.x, -gravity.y) * 0.3


func _on_start_pressed() -> void:
	UiSound.play_click(self)
	if _first_boot:
		RunState.begin(FIRST_RUN_CHARACTER, FIRST_RUN_STAGE)
		SceneRouter.goto_stage(FIRST_RUN_STAGE)
		return
	SceneRouter.goto_camp()


func _on_settings_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_settings()


## No dedicated credits screen exists (or is asked for); a lightweight
## in-place panel matches how camp's building placeholders already work.
func _on_credits_pressed() -> void:
	UiSound.play_click(self)
	_return_focus_target = _credits_button
	_credits_panel.visible = true
	_credits_close.grab_focus()
	_set_background_motion_active(false)


func _close_credits() -> void:
	UiSound.play_click(self)
	_credits_panel.visible = false
	if is_instance_valid(_return_focus_target):
		_return_focus_target.grab_focus()
	_return_focus_target = null
	_set_background_motion_active(true)


## Nothing behind the credits panel should keep the CPU busy: pause every
## looping tween and stop the particle system (rather than just hiding it --
## a paused-but-still-simulating emitter costs the same as a visible one).
func _set_background_motion_active(active: bool) -> void:
	if not _layered_backdrop:
		return
	for tween: Tween in _motion_tweens:
		if is_instance_valid(tween):
			if active:
				tween.play()
			else:
				tween.pause()
	if _motes != null:
		_motes.emitting = active
	set_process(active)


func _on_quit_pressed() -> void:
	UiSound.play_click(self)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_credits()
		get_viewport().set_input_as_handled()
		return
	if not _layered_backdrop:
		return
	if event is InputEventMouseMotion:
		_set_pointer_target((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag:
		_set_pointer_target((event as InputEventScreenDrag).position)


func _set_pointer_target(screen_position: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var normalized: Vector2 = (screen_position / viewport_size) * 2.0 - Vector2.ONE
	_pointer_target = normalized.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
