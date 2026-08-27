extends RefCounted
## Guards the N3-12 monster sprite wiring: every sprite set declared in
## data/monsters.json builds idle + 4-frame walk at 8 fps, the boss breathes a
## 2-frame idle, and the drawn (logical) height hierarchy from
## asset/monsters/README.md holds against the 38px player.

const MONSTERS_PATH := "res://data/monsters.json"
## N9-75: monsters no longer share one walk length — the owner authored 그슨대
## with eight frames where the others have four. The contract that matters is
## that the animation carries every frame the SHEET declares, which is what
## catches a half-loaded or truncated strip; a fixed number only ever caught
## somebody drawing a longer cycle.
const MIN_WALK_FRAMES := 4
const BOSS_DIR := "res://asset/monsters/dudueori"

## Expected drawn heights in logical px: opaque-pixel rows / EXPORT_SCALE.
## N9-136: remeasured for the owner's 16-frame density-unified walk sheets —
## the idle pose is the cycle's narrowest stance, so heights are no longer
## round numbers.
## The hierarchy the game is held to, not the pixel counts of one art pass.
## Pinning exact heights meant every owner drop broke this test while proving
## nothing — what matters is that trash stays under the player, heavies over,
## and the boss clear of everything. The band is wide enough for a redraw and
## narrow enough that a bake accident (a walk cycle coming out a sixth of its
## height, a strip normalised to the wrong logical size) still fails.
const HEIGHT_BANDS: Dictionary = {
	"res://asset/monsters/forest_goblin": [22.0, 34.0],
	"res://asset/monsters/forest_spirit": [24.0, 36.0],
	"res://asset/monsters/bamboo_brute": [40.0, 56.0],
	BOSS_DIR: [64.0, 110.0],
}
const PLAYER_HEIGHT := 38.0


## Frames a strip declares by its own shape: square frames, count = width over
## height. Read from the file rather than from a constant, so the test cannot
## disagree with the art.
func _strip_frame_count(path: String) -> int:
	var texture: Texture2D = load(path)
	if texture == null or texture.get_height() <= 0:
		return 0
	return int(texture.get_width() / texture.get_height())


func test_declared_sprite_sets_build_walk_and_idle() -> bool:
	var dirs: Array[String] = _declared_sprite_dirs()
	var passed: bool = not dirs.is_empty()
	for sprite_dir: String in dirs:
		var frames: SpriteFrames = Enemy.frames_for(sprite_dir)
		passed = passed and frames.has_animation(SpriteSheet.ANIM_IDLE)
		passed = passed and frames.has_animation(SpriteSheet.ANIM_WALK)
		var declared: int = _strip_frame_count(
			SpriteSheet.strip_path(sprite_dir, SpriteSheet.WALK_STRIP, "walk.png")
		)
		passed = passed and declared >= MIN_WALK_FRAMES
		passed = passed and frames.get_frame_count(SpriteSheet.ANIM_WALK) == declared
		passed = passed and (
			frames.get_animation_speed(SpriteSheet.ANIM_WALK) == Enemy.WALK_FPS
		)
		# N10-22: the idle frame count used to be pinned to one, or two for the
		# boss's breathe sheet. A baked idle is a sixteen-frame breath, so the
		# contract is that an idle EXISTS and carries frames — pinning the number
		# fails every monster the moment its art gains a breath.
		passed = passed and frames.get_frame_count(SpriteSheet.ANIM_IDLE) >= 1
	if not passed:
		push_error("test_enemy_sprite: monster sprite frame contract broken")
	return passed


## Measures real drawn heights (used pixel rows at the 1/16 sprite scale) so
## the on-screen hierarchy goblin < spirit < player < brute << boss is proven
## numerically, not assumed from the asset README.
func test_drawn_height_hierarchy() -> bool:
	var passed := true
	var heights: Dictionary = {}
	for sprite_dir: String in HEIGHT_BANDS:
		var idle: Texture2D = load(
			SpriteSheet.strip_path(sprite_dir, SpriteSheet.IDLE_STRIP, "idle.png")
		)
		var height: float = (
			float(idle.get_image().get_used_rect().size.y) / SpriteSheet.EXPORT_SCALE
		)
		heights[sprite_dir] = height
		var band: Array = HEIGHT_BANDS[sprite_dir]
		passed = passed and height >= float(band[0]) and height <= float(band[1])
	var goblin: float = heights["res://asset/monsters/forest_goblin"]
	var spirit: float = heights["res://asset/monsters/forest_spirit"]
	var brute: float = heights["res://asset/monsters/bamboo_brute"]
	var boss: float = heights[BOSS_DIR]
	passed = passed and goblin < spirit and spirit < PLAYER_HEIGHT
	passed = passed and PLAYER_HEIGHT < brute and brute < boss
	if not passed:
		push_error("test_enemy_sprite: drawn height hierarchy broken: " + str(heights))
	return passed


## Footprint contract: the data hurt-circle must fit inside each monster's own
## sprite half-width — a goblin can never carry the boss's hitbox.
func test_collision_radius_fits_sprite_footprint() -> bool:
	var monsters: Dictionary = _load_monsters()
	var passed := true
	for monster_id: String in monsters:
		var monster: Dictionary = monsters[monster_id]
		if not monster.has("sprite"):
			continue
		var idle: Texture2D = load(SpriteSheet.strip_path(
			String(monster["sprite"]), SpriteSheet.IDLE_STRIP, "idle.png"
		))
		var half_width: float = (
			float(idle.get_image().get_used_rect().size.x) / SpriteSheet.EXPORT_SCALE / 2.0
		)
		passed = passed and float(monster.get("collision_radius", 0.0)) <= half_width
	if not passed:
		push_error("test_enemy_sprite: collision_radius exceeds sprite footprint")
	return passed


func _declared_sprite_dirs() -> Array[String]:
	var dirs: Array[String] = []
	var monsters: Dictionary = _load_monsters()
	for monster_id: String in monsters:
		var sprite_dir: String = String((monsters[monster_id] as Dictionary).get("sprite", ""))
		if not sprite_dir.is_empty():
			dirs.append(sprite_dir)
	return dirs


func _load_monsters() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONSTERS_PATH))
	return data if data is Dictionary else {}


func test_the_texture_limit_is_the_one_the_renderer_enforces() -> bool:
	# QA (auto, b735bc0 B1): a 24320px walk strip failed at the driver, and the
	# error named load() rather than the sheet. The guard turns that into a
	# sentence naming the file and the fix; this pins the number it guards.
	var passed: bool = SpriteSheet.MAX_STRIP_PX == 16384
	# And it has to be a real ceiling for the export contract: a 16-frame cycle
	# of 1024px cells is exactly at it, one of 1520px cells is past it.
	passed = passed and 16 * 1024 <= SpriteSheet.MAX_STRIP_PX
	passed = passed and 16 * 1520 > SpriteSheet.MAX_STRIP_PX
	if not passed:
		push_error("test_enemy_sprite: the strip width ceiling moved")
	return passed


## Owner: 두두리랑 밤2 보스가 공격할 때 모션 취하게. The two stage bosses ship an
## attack sheet; nothing else does, and asking for one that is not there must be
## a quiet no rather than a broken animation.
func test_only_the_stage_bosses_carry_an_attack_cycle() -> bool:
	var stages: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	var monsters: Dictionary = _load_monsters()
	var boss_ids: Array[String] = []
	for stage_id: String in stages:
		var boss: String = String((stages[stage_id] as Dictionary).get("boss_id", ""))
		if not boss.is_empty() and not boss_ids.has(boss):
			boss_ids.append(boss)
	var passed: bool = not boss_ids.is_empty()
	for monster_id: String in monsters:
		var sprite_dir: String = String(
			(monsters[monster_id] as Dictionary).get("sprite", "")
		)
		if sprite_dir.is_empty():
			continue
		var frames := SpriteFrames.new()
		var built: bool = SpriteSheet.add_attack(frames, sprite_dir, 14.0)
		if boss_ids.has(monster_id):
			passed = passed and built
			# One shot: an attack that loops reads as a stuck sprite.
			passed = passed and not frames.get_animation_loop(SpriteSheet.ANIM_ATTACK)
			passed = passed and frames.get_frame_count(SpriteSheet.ANIM_ATTACK) > 1
		else:
			passed = passed and not built
	if not passed:
		push_error("test_enemy_sprite: attack cycles are on the wrong monsters")
	return passed
