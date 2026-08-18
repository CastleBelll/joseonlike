extends Node
## Resolution independence check: loads the real title scene, screenshots
## whatever window size Godot was launched with (via --resolution WxH),
## and quits. Run once per target resolution:
##   godot --path . --resolution 1080x2340 res://tools/resolution_check.tscn
## Used to verify window/stretch/mode=viewport + aspect=expand (project.godot
## [display]) doesn't distort or clip the title screen on phone vs PC
## aspect ratios.

const SHOT_DIR := "user://resolution_checks/"


func _ready() -> void:
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var win_size: Vector2i = DisplayServer.window_get_size()
	# The stretch-adjusted canvas Controls actually lay out in — NOT
	# get_viewport().size, which is the pre-stretch base resolution under
	# stretch/mode=viewport and reads far smaller than the visible canvas.
	var canvas_size: Vector2 = get_viewport().get_visible_rect().size
	var shot_path: String = "%suser_%dx%d.png" % [SHOT_DIR, win_size.x, win_size.y]
	get_viewport().get_texture().get_image().save_png(shot_path)

	var logo: Label = title.get_node("Logo")
	var menu_button: Button = title.get_node("MenuButtons/MenuButton_start")
	var logo_rect: Rect2 = logo.get_global_rect()
	var button_rect: Rect2 = menu_button.get_global_rect()
	var overflow: bool = (
		logo_rect.position.x < 0.0 or logo_rect.end.x > canvas_size.x
		or button_rect.position.x < 0.0 or button_rect.end.x > canvas_size.x
		or button_rect.end.y > canvas_size.y
	)

	print("RESOLUTION shot: " + ProjectSettings.globalize_path(shot_path))
	print("window=%dx%d canvas=%s logo_rect=%s button_rect=%s" % [
		win_size.x, win_size.y, canvas_size, logo_rect, button_rect
	])
	if overflow:
		push_error("FAIL resolution_check: logo or start button falls outside the viewport at %dx%d" % [win_size.x, win_size.y])
	else:
		print("PASS resolution_check: logo and start button stay on-screen at %dx%d" % [win_size.x, win_size.y])
	get_tree().quit(0)
