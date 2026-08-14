extends RefCounted
## Guards the N3-2 taoist sprite wiring: idle + 4-frame walk at 8 fps built
## from the AC-1 16x exports (asset/characters/taoist/README.md contract).

const LOGICAL_FRAME_SIZE := 40.0


func test_sprite_frames_contract() -> bool:
	var frames: SpriteFrames = Player.build_sprite_frames()
	var passed: bool = frames.has_animation(Player.ANIM_IDLE)
	passed = passed and frames.has_animation(Player.ANIM_WALK)
	passed = passed and frames.get_frame_count(Player.ANIM_IDLE) == 1
	passed = passed and frames.get_frame_count(Player.ANIM_WALK) == Player.WALK_FRAME_COUNT
	passed = passed and frames.get_animation_speed(Player.ANIM_WALK) == Player.WALK_FPS
	if not passed:
		push_error("test_player_sprite: sprite frame contract broken")
	return passed


func test_frames_downscale_to_logical_size() -> bool:
	var frames: SpriteFrames = Player.build_sprite_frames()
	var idle: Texture2D = frames.get_frame_texture(Player.ANIM_IDLE, 0)
	var passed: bool = idle.get_size().x / Player.SPRITE_EXPORT_SCALE == LOGICAL_FRAME_SIZE
	for i: int in range(Player.WALK_FRAME_COUNT):
		var frame: Texture2D = frames.get_frame_texture(Player.ANIM_WALK, i)
		passed = passed and frame.get_size() == idle.get_size()
	if not passed:
		push_error("test_player_sprite: export frames are not 16x blocks of 40x40")
	return passed
