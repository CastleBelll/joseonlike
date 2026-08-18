extends Node
## Settings popup layout check (N1-2-REVISED): opens the real SettingsPopup
## on the 오디오 tab (the taller of the two — 3 slider rows), screenshots it,
## and asserts the close button's bottom edge stays inside the paper panel.
## Run: godot --path . res://tools/settings_check.tscn

const SHOT_PATH := "user://settings_check.png"


func _ready() -> void:
	var popup := SettingsPopup.new()
	add_child(popup)
	popup.open()
	popup._select_tab(SettingsPopup.TAB_GAME)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var panel: PanelContainer = popup.get_node("Blocker/PaperPanel")
	var close_button: Button = popup.get_node("Blocker/PaperPanel/Layout/Body/CloseButton")
	var panel_bottom: float = panel.get_global_rect().position.y + panel.get_global_rect().size.y
	var close_bottom: float = close_button.get_global_rect().position.y + close_button.get_global_rect().size.y

	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("SETTINGS shot: " + ProjectSettings.globalize_path(SHOT_PATH))
	if close_bottom <= panel_bottom:
		print("PASS settings_check: close button fits (bottom %.1f <= panel %.1f)" % [close_bottom, panel_bottom])
	else:
		push_error("FAIL settings_check: close button overflows panel (bottom %.1f > panel %.1f)" % [close_bottom, panel_bottom])
	get_tree().quit(0)
