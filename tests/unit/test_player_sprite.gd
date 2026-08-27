extends RefCounted
## Guards the player sprite wiring: a breathing idle and a run cycle, both
## square-framed strips built by asset/tools/bake_sheets.py.
##
## N10-10: the idle used to be one frame lifted out of the walk strip, because
## the separate idle drawing looked like a different character. The sheets are
## generated from the idle reference now, so the idle is a real animation and
## this asserts it has more than one frame — the old "== 1" would pass again
## the moment somebody reinstated the override.
##
## The frame side is deliberately NOT pinned. Frames must be square, because
## SpriteSheet counts them as width over height, but the side follows whatever
## drawn height the bake targets, and a pinned number fails every re-bake.


func test_sprite_frames_contract() -> bool:
	var frames: SpriteFrames = Player.build_sprite_frames()
	var passed: bool = frames.has_animation(Player.ANIM_IDLE)
	passed = passed and frames.has_animation(Player.ANIM_WALK)
	passed = passed and frames.get_frame_count(Player.ANIM_IDLE) > 1
	# The count belongs to the art, not to this file: 16, 24 and 25 frame walks
	# have all shipped. What has to hold is that it is a cycle, not a still.
	passed = passed and frames.get_frame_count(Player.ANIM_WALK) >= Player.WALK_FRAME_MIN
	# Owner split run from walk — where the art exists, both must be cycles and
	# both must loop, or easing off the stick would stutter.
	if frames.has_animation(SpriteSheet.ANIM_RUN):
		passed = passed and frames.get_frame_count(SpriteSheet.ANIM_RUN) >= Player.WALK_FRAME_MIN
		passed = passed and frames.get_animation_loop(SpriteSheet.ANIM_RUN)
		passed = passed and frames.get_animation_loop(Player.ANIM_WALK)
	passed = passed and frames.get_animation_speed(Player.ANIM_WALK) == Player.WALK_FPS
	passed = passed and frames.get_animation_speed(Player.ANIM_IDLE) == Player.IDLE_FPS
	if not passed:
		push_error("test_player_sprite: sprite frame contract broken")
	return passed


func test_frames_are_square_and_one_size() -> bool:
	var frames: SpriteFrames = Player.build_sprite_frames()
	var side: Vector2 = frames.get_frame_texture(Player.ANIM_IDLE, 0).get_size()
	var passed: bool = side.x == side.y and side.x > 0.0
	for i: int in range(frames.get_frame_count(Player.ANIM_IDLE)):
		passed = passed and frames.get_frame_texture(Player.ANIM_IDLE, i).get_size() == side
	for i: int in range(frames.get_frame_count(Player.ANIM_WALK)):
		passed = passed and frames.get_frame_texture(Player.ANIM_WALK, i).get_size() == side
	if not passed:
		push_error("test_player_sprite: frames are not one square size: " + str(side))
	return passed


## The drawn figure is what the world reads, and it must not grow when the
## player stops. Running may be SHORTER — the stride lowers the body — but never
## taller, and never by more than a stride's worth.
## How much taller a running pose may stand than a standing one before it reads
## as the character changing size rather than moving.
const POSE_ALLOWANCE := 1.06


func test_walk_does_not_resize_the_character() -> bool:
	var frames: SpriteFrames = Player.build_sprite_frames()
	var standing: float = _drawn_height(frames, Player.ANIM_IDLE)
	var running: float = _drawn_height(frames, Player.ANIM_WALK)
	# The measurement is the tallest drawn pixel, which cannot tell a SCALE
	# change from a POSE change: a run cycle legitimately reaches higher than a
	# stand, because the leg extends and the hat tilts. The 2026-08-27 art
	# measures 38.0 standing against 39.4 running from the same bake scale.
	# The bound the guard exists for is the scale accident — powder_dokkaebi
	# jumping 37.5% between its own idle and walk — and a 6% pose allowance
	# still catches that by a wide margin.
	var passed: bool = running <= standing * POSE_ALLOWANCE
	passed = passed and running >= standing * 0.85
	if not passed:
		push_error("test_player_sprite: idle %.1f vs walk %.1f logical px" % [
			standing / Player.SPRITE_EXPORT_SCALE, running / Player.SPRITE_EXPORT_SCALE
		])
	return passed


func _drawn_height(frames: SpriteFrames, anim: String) -> float:
	var tallest: float = 0.0
	for i: int in range(frames.get_frame_count(anim)):
		var used: Rect2i = frames.get_frame_texture(anim, i).get_image().get_used_rect()
		tallest = maxf(tallest, float(used.size.y))
	return tallest


## Owner: 본거지에서만 걷고 출정은 뛰어야지. The split is by place, not by input.
func test_running_is_a_place_not_a_joystick_push() -> bool:
	var frames: SpriteFrames = Player.build_sprite_frames()
	if not frames.has_animation(SpriteSheet.ANIM_RUN):
		return true  # no run art in this checkout; nothing to guard
	var player := Player.new()
	player._sprite = AnimatedSprite2D.new()
	player._sprite.sprite_frames = frames
	player.add_child(player._sprite)
	player._speed = 100.0
	# Standing still is idle wherever you are.
	player.velocity = Vector2.ZERO
	player.running = true
	player._update_animation()
	var passed: bool = player._sprite.animation == Player.ANIM_IDLE
	# Moving in the camp walks, however hard the stick is pushed...
	player.running = false
	player.velocity = Vector2(100.0, 0.0)
	player._update_animation()
	passed = passed and player._sprite.animation == Player.ANIM_WALK
	# ...and moving on a run runs, however gently.
	player.running = true
	player.velocity = Vector2(12.0, 0.0)
	player._update_animation()
	passed = passed and player._sprite.animation == SpriteSheet.ANIM_RUN
	player.free()
	if not passed:
		push_error("test_player_sprite: run/walk is not decided by place")
	return passed
