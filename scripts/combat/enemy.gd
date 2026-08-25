class_name Enemy
extends CharacterBody2D
## Chasing contact-damage monster (N3-4). Stats come from data/monsters.json;
## monsters with a "sprite" set render the AC-5 art (N3-12): idle + 4-frame
## walk mirrored by travel direction, 16x NEAREST downscale like the player.
## Artless monsters keep the placeholder rect. All behaviours chase for now —
## ranged/charger AI is a later feature.

signal died(enemy: Enemy)
## 화약 도깨비 (N9-165): the fuse is lit — the stage draws the warning that
## says where the powder will go off, and how long the player has.
signal fuse_lit(enemy: Enemy, fuse_sec: float, radius_px: float)
## The fuse ran out. The stage owns the damage, like every other area attack.
signal detonated(enemy: Enemy, at: Vector2, radius_px: float, damage: float)
## N4-4a: one DoT tick landed (burn, or curse since N4-4b) — relayed by the
## spawner so the stage can float a damage number without every enemy holding
## a stage reference.
signal burn_ticked(amount: float, at: Vector2)

const VISUAL_HEIGHT_RATIO := 2.4  # slightly taller than wide, like the player
const EYE_RATIO := 0.18
## N9-136: doubled with the owner's 16-frame walk sheets so the cycle keeps
## the old 8-frame cadence.
const WALK_FPS := 16.0
## The boss idle_breathe strip reads as a slow one-pixel inhale at this rate.
const IDLE_FPS := 2.0
const BREATHE_FILE := "idle_breathe.png"
## Enemies overlap the player and each other freely (VS-like feel); damage is
## the proximity check below, never physics. Layer 2 keeps them off the
## player's default layer 1 so nothing pushes anything.
const COLLISION_LAYER_ENEMY := 2
## N4-4a burn cadence: damage lands in half-second ticks so the DoT reads as
## repeated small hits rather than a smooth drain.
const BURN_TICK_SEC := 0.5

## forest_spirit reads white, forest_goblin green, per DESIGN.md §5.1
## silhouette separation. Unknown ids fall back to the goblin green.
const PLACEHOLDER_COLORS: Dictionary = {
	"forest_goblin": UiPalette.ENEMY_GOBLIN,
	"forest_spirit": UiPalette.ENEMY_SPIRIT,
	"bamboo_brute": UiPalette.ENEMY_BRUTE,
}

## SpriteFrames are built once per sprite set and shared by every pooled
## instance; 60 live enemies must never rebuild atlas slices per spawn.
static var _frames_cache: Dictionary = {}

## N4-2 elite derivation: an "elite_of" monsters.json entry is pure data-side
## multipliers over its base monster. Returns a full stats dict the ordinary
## setup() consumes — same enemy code, bigger and tougher numbers.
static func derive_elite_stats(base: Dictionary, elite: Dictionary) -> Dictionary:
	var size_mult: float = float(elite.get("size_mult", 1.0))
	var reward_mult: float = float(elite.get("reward_mult", 1.0))
	var derived: Dictionary = base.duplicate()
	derived["hp"] = float(base.get("hp", 1.0)) * float(elite.get("hp_mult", 1.0))
	derived["damage"] = float(base.get("damage", 0.0)) * float(elite.get("damage_mult", 1.0))
	derived["speed"] = float(base.get("speed", 0.0)) * float(elite.get("speed_mult", 1.0))
	derived["collision_radius"] = float(base.get("collision_radius", 10.0)) * size_mult
	derived["xp_drop"] = int(round(float(base.get("xp_drop", 0)) * reward_mult))
	derived["size_scale"] = size_mult
	derived["name_ko"] = String(elite.get("name_ko", base.get("name_ko", "")))
	derived["name_en"] = String(elite.get("name_en", base.get("name_en", "")))
	derived["name_en"] = String(elite.get("name_en", base.get("name_en", "")))
	# N5-5: elites drop reward chests and resist the nuke pickup's full damage.
	derived["is_elite"] = true
	return derived

var monster_id := ""
## N6-2 killer attribution: the resolved localized display name (elite
## derivation included) — what the result screen prints if this enemy lands
## the killing blow.
var name_ko := ""
var hp: float = 0.0
var contact_radius: float = 0.0
var xp_drop: int = 0
var is_boss: bool = false
## N5-5: set for "elite_of" variants (derive_elite_stats) — chest drop + nuke cap.
var is_elite: bool = false
## N3-14: written by the spawner every physics frame (already weighted);
## the boss always keeps ZERO so trash never shoves it around.
var separation_push := Vector2.ZERO

var _damage: float = 0.0
var _speed: float = 0.0
var _contact_cooldown: float = 0.0
var _time_since_contact: float = 0.0
var _target: Player
var _body: ColorRect
var _visual: Node2D
var _status_overlay: StatusOverlay
var _sprite: AnimatedSprite2D
var _has_art := false
var _size_scale: float = 1.0  # N4-2: elite variants render bigger
var _facing: int = PlayerMotion.FACING_RIGHT
var _shape: CollisionShape2D
var _block_normal := Vector2.ZERO
var _avoid_sign: float = 1.0
# N3-8 hit feedback state (numbers from data/effects.json via the spawner).
var _flash_left: float = 0.0
var _flash_sec: float = 0.0
var _knockback := Vector2.ZERO
var _knockback_speed: float = 0.0
var _knockback_decay: float = 0.0
var _boss_knockback_scale: float = 1.0
# N4-4a status state (GDD §11.1 branches). Burn ticks damage over time and may
# spread on death (spawner reads the public fields); shock slows the chase;
# seal stacks detonate — the striking projectile applies the burst damage.
var burn_dps: float = 0.0
var burn_duration: float = 0.0
var burn_spread_px: float = 0.0
var _burn_left: float = 0.0
var _burn_tick: float = 0.0
var _shock_scale: float = 1.0
var _shock_left: float = 0.0
var _seal_stacks: int = 0
# N4-4b statuses: stun (진언 shockwave) roots the chase and mutes the contact
# bite; curse (살) ticks like burn and spreads to fresh carriers on death —
# the spawner reads the public fields to propagate.
var curse_dps: float = 0.0
var curse_duration: float = 0.0
var curse_spread_px: float = 0.0
var curse_spread_count: int = 0
var _curse_left: float = 0.0
var _curse_tick: float = 0.0
var _stun_left: float = 0.0
## 화약 도깨비 fuse state. `is_suicide` also silences contact damage: the bomb
## hurts through its blast or not at all.
var is_suicide: bool = false
var _suicide: Dictionary = {}
var _fuse_left: float = 0.0
var _fuse_lit: bool = false
var _spent: bool = false

## 야광귀 (N10-1a) theft state. A thief walks to the loot rather than the
## player and never lands a hit — the whole threat is that it leaves with
## something. `theft_goal` is written by the stage, which is the only place
## that knows where the field's pickups are; a goal of NAN means "nothing to
## steal" and the thief chases like anything else so it is never left standing.
var is_thief: bool = false
var carried_passive: String = ""
var theft_goal := Vector2(NAN, NAN)
## N10-1b: standing inside a 체 (sieve), counting its holes. The stage sets it
## because the stage is what knows where the sieves are; the enemy only has to
## stop. Kept separate from `_stun_left` — a stun is something a weapon did and
## it ticks away, while this holds for exactly as long as the thief is in the
## radius, and refreshing a stun every frame would fight the weapon that owns it.
var stalled: bool = false
var _theft: Dictionary = {}

# N10-1a 그슨대: the shadow contract. `shadow_config` empty = an ordinary
# monster, so every existing enemy is untouched. `light_sources` is the live
# array the field owns (chunks append to it as the world grows).
var shadow_config: Dictionary = {}
var light_sources: Array[Dictionary] = []
var _shadow_scale: float = 1.0
var _lit: bool = false
var _shadow_anchor := Vector2.ZERO
var _shadow_anchored: bool = false
var _shadow_leashed: bool = false
## N9-48: seconds spent outside the haunt, counting down to sinking away.
var _shadow_leash_left: float = 0.0


func _ready() -> void:
	collision_layer = COLLISION_LAYER_ENEMY
	# Solid stage props (N3-9) are the only thing an enemy collides with.
	collision_mask = StageField.LAYER_OBSTACLE
	_shape = CollisionShape2D.new()
	_shape.shape = CircleShape2D.new()
	add_child(_shape)
	# The Visual wrapper carries the facing flip (scale.x = ±1) for both the
	# sprite and the placeholder rect, mirroring the player's structure.
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE / SpriteSheet.EXPORT_SCALE
	_visual.add_child(_sprite)
	_body = ColorRect.new()
	_body.name = "Body"
	_visual.add_child(_body)
	var eye := ColorRect.new()
	eye.name = "Eye"
	eye.color = UiPalette.INK
	_body.add_child(eye)
	# N3-17 status overlay: burn flame ticks and the curse mark, drawn above
	# the silhouette. Outside the flipped Visual wrapper so it never mirrors.
	_status_overlay = StatusOverlay.new()
	_status_overlay.name = "StatusOverlay"
	_status_overlay.enemy = self
	add_child(_status_overlay)


## (Re)arms a pooled instance. Safe to call repeatedly on the same node.
func setup(
	id: String,
	stats: Dictionary,
	target: Player,
	contact_cooldown: float,
	feedback: Dictionary = {}
) -> void:
	monster_id = id
	name_ko = UiLocale.data_name(stats, "")
	hp = float(stats.get("hp", 1.0))
	_damage = float(stats.get("damage", 0.0))
	_speed = float(stats.get("speed", 0.0))
	contact_radius = float(stats.get("collision_radius", 10.0))
	xp_drop = int(stats.get("xp_drop", 0))
	is_boss = String(stats.get("behaviour", "")) == "boss"
	is_suicide = String(stats.get("behaviour", "")) == "suicide"
	_suicide = stats.get("suicide", {})
	_fuse_left = 0.0
	_fuse_lit = false
	_spent = false
	is_thief = String(stats.get("behaviour", "")) == "thief"
	_theft = stats.get("theft", {})
	carried_passive = ""
	theft_goal = Vector2(NAN, NAN)
	stalled = false
	is_elite = bool(stats.get("is_elite", false))
	_size_scale = float(stats.get("size_scale", 1.0))
	_flash_left = 0.0
	_flash_sec = float(feedback.get("enemy_flash_sec", 0.0))
	_knockback = Vector2.ZERO
	_knockback_speed = float(feedback.get("knockback_speed_px_s", 0.0))
	_knockback_decay = float(feedback.get("knockback_decay_px_s2", 0.0))
	_boss_knockback_scale = float(feedback.get("boss_knockback_scale", 1.0))
	burn_dps = 0.0
	burn_duration = 0.0
	burn_spread_px = 0.0
	_burn_left = 0.0
	_burn_tick = 0.0
	_shock_scale = 1.0
	_shock_left = 0.0
	_seal_stacks = 0
	curse_dps = 0.0
	curse_duration = 0.0
	curse_spread_px = 0.0
	curse_spread_count = 0
	_curse_left = 0.0
	_curse_tick = 0.0
	_stun_left = 0.0
	shadow_config = stats.get("shadow", {})
	_shadow_scale = 1.0
	_lit = false
	_shadow_anchored = false
	_shadow_leashed = false
	_shadow_leash_left = 0.0
	# Pool-safe: a shadow that sank away must not hand its fade to the next
	# monster reusing this instance.
	modulate.a = 1.0
	_contact_cooldown = contact_cooldown
	_time_since_contact = contact_cooldown  # first touch may hit immediately
	separation_push = Vector2.ZERO
	_target = target
	(_shape.shape as CircleShape2D).radius = contact_radius
	_block_normal = Vector2.ZERO
	# Fixed per-instance detour side keeps two blocked enemies from mirroring
	# each other forever on the same wall face.
	_avoid_sign = 1.0 if (get_instance_id() & 1) == 0 else -1.0
	_apply_visual(String(stats.get("sprite", "")))


## Pool-safe visual (re)arm: facing, animation, frame and flash tint are all
## reset so a reused instance never shows a previous life's state.
func _apply_visual(sprite_dir: String) -> void:
	_facing = PlayerMotion.FACING_RIGHT
	_visual.scale = Vector2.ONE
	_has_art = not sprite_dir.is_empty() and ResourceLoader.exists(
		sprite_dir.path_join("idle.png")
	)
	_sprite.visible = _has_art
	_body.visible = not _has_art
	if not _has_art:
		_apply_placeholder_visual()
		return
	# Pool-safe: the scale is re-derived every arm, so an elite's 1.6x body
	# never leaks into the next ordinary monster reusing this instance.
	_sprite.scale = Vector2.ONE / SpriteSheet.EXPORT_SCALE * _size_scale
	_sprite.sprite_frames = frames_for(sprite_dir)
	_sprite.modulate = Color.WHITE
	_sprite.play(SpriteSheet.ANIM_IDLE)
	_sprite.frame = 0


## Cached per sprite directory. The boss ships a 2-frame idle_breathe strip
## that replaces the static idle when present.
static func frames_for(sprite_dir: String) -> SpriteFrames:
	if _frames_cache.has(sprite_dir):
		return _frames_cache[sprite_dir]
	var idle_path: String = sprite_dir.path_join(BREATHE_FILE)
	if not ResourceLoader.exists(idle_path):
		idle_path = sprite_dir.path_join("idle.png")
	var frames: SpriteFrames = SpriteSheet.build_frames(
		idle_path, sprite_dir.path_join("walk.png"), WALK_FPS, IDLE_FPS
	)
	_frames_cache[sprite_dir] = frames
	return frames


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	_time_since_contact += delta
	_update_flash(delta)
	_update_burn(delta)
	_update_curse(delta)
	if CombatMath.is_dead(hp):
		return  # a DoT tick killed this enemy; it is already released
	if _update_shadow(delta):
		return  # sank away and was pooled; this body has left the space
	_shock_left = maxf(_shock_left - delta, 0.0)
	_stun_left = maxf(_stun_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, _knockback_decay * delta)
	if is_suicide and _update_fuse(delta):
		return  # the powder went off; this body has left the space
	var desired: Vector2 = CombatMath.chase_direction(
		global_position, _target.global_position
	)
	var speed: float = _speed * (_shock_scale if _shock_left > 0.0 else 1.0)
	if is_thief:
		if not carried_passive.is_empty():
			# Carrying: the player is the thing to get away from. Same chase
			# maths, read backwards, so a cornered thief still slides along
			# props instead of grinding into them.
			desired = -desired
			speed *= float(_theft.get("flee_speed_mult", 1.0))
		elif not is_nan(theft_goal.x):
			desired = CombatMath.chase_direction(global_position, theft_goal)
	var steer: Vector2 = CombatMath.avoid_direction(desired, _block_normal, _avoid_sign)
	# Stunned (진언, N4-4b): the chase stops dead; only knockback still moves it.
	if _stun_left > 0.0 or _shadow_leashed or _fuse_lit or stalled:
		speed = 0.0
	velocity = Separation.blended_direction(steer, separation_push) * speed + _knockback
	move_and_slide()
	_block_normal = (
		get_slide_collision(0).get_normal() if get_slide_collision_count() > 0
		else Vector2.ZERO
	)
	_update_visual_motion()
	# A bomb never also body-slams: its whole damage is the blast. A thief never
	# lands a hit at all — chasing it has to be the player's choice, not
	# something they are punished into.
	if _stun_left <= 0.0 and not is_suicide and not is_thief:
		_try_contact_damage()


## Runs the fuse: lights it at arm's length, counts it down while the bomb
## stands still, and detonates. True means this body is gone.
func _update_fuse(delta: float) -> bool:
	var distance: float = global_position.distance_to(_target.global_position)
	if CombatMath.fuse_lights(distance, float(_suicide.get("trigger_px", 0.0)), _fuse_lit):
		_fuse_lit = true
		_fuse_left = float(_suicide.get("fuse_sec", 0.0))
		fuse_lit.emit(self, _fuse_left, float(_suicide.get("radius_px", 0.0)))
	if not _fuse_lit or _spent:
		return _spent
	_fuse_left -= delta
	if not CombatMath.fuse_fires(_fuse_left, _spent):
		return false
	_spent = true
	detonated.emit(
		self, global_position,
		float(_suicide.get("radius_px", 0.0)), float(_suicide.get("damage", 0.0))
	)
	# The bomb dies by its own hand — the drop and the counter still credit the
	# player, the same as any other death.
	died.emit(self)
	return true


## `knockback_scale` lets heavy hits (석장 arc swing, N4-4a) shove harder than
## the shared data/effects.json baseline; the boss damping still applies on top.
func take_damage(
	amount: float, hit_direction: Vector2 = Vector2.ZERO, knockback_scale: float = 1.0
) -> void:
	# 그슨대 in the dark absorbs everything — projectiles, arcs, wards and the
	# burn/curse ticks that route through here. Guarding at the single entry
	# point is what keeps every weapon free of a shadow special case.
	if absorbs_damage():
		return
	hp = CombatMath.apply_damage(hp, amount)
	if CombatMath.is_dead(hp):
		died.emit(self)
		return
	_flash_left = _flash_sec
	if _has_art:
		_sprite.modulate = UiPalette.SPRITE_HIT_FLASH
	else:
		_body.color = UiPalette.HIT_FLASH
	var scale_factor: float = _boss_knockback_scale if is_boss else 1.0
	_knockback = hit_direction * _knockback_speed * scale_factor * knockback_scale


## Strongest burn wins — reapplying a weaker burn never downgrades the DoT,
## but any reapply refreshes the clock. Spread radius carries so a spreading
## burn keeps spreading (화령석 domino, GDD §11.1).
func apply_burn(dps: float, duration: float, spread_px: float = 0.0) -> void:
	if dps >= burn_dps:
		burn_dps = dps
		burn_duration = duration
	burn_spread_px = maxf(burn_spread_px, spread_px)
	_burn_left = maxf(_burn_left, duration)


## True only for a shadow monster standing outside every light. Callers use
## it to skip damage numbers — an absorbed hit must not print a number.
func absorbs_damage() -> bool:
	return not shadow_config.is_empty() and not _lit


func is_shadow() -> bool:
	return not shadow_config.is_empty()


## The thief's four numbers, for the stage that drives it. Handing the block
## over is cheaper than making the stage load the monster catalogue a second
## time just to look up what this enemy already knows.
func theft_config() -> Dictionary:
	return _theft


## Swell in the dark, shrink in the light, and show which one is happening.
## The silhouette is the whole tell: near-black and growing means "you cannot
## hurt this yet", lit and shrinking means "hit it now".
## Returns true when the shadow released itself this frame — the caller must
## stop immediately. Emitting died() hands this body back to the pool and takes
## it out of the physics space, so anything after it (move_and_slide) runs on a
## body with no space and errors ("body->get_space() is null").
func _update_shadow(delta: float) -> bool:
	if shadow_config.is_empty():
		return false
	if not _shadow_anchored:
		# The spawner positions the enemy after setup(), so the haunt anchor can
		# only be taken on the first frame it is actually standing somewhere.
		_shadow_anchor = global_position
		_shadow_anchored = true
	_lit = CombatMath.is_lit(global_position, light_sources)
	# A shadow haunts its patch of dark; it does not hunt across the province.
	# Without this a monster nothing can kill becomes a timer on the player's
	# life instead of a fight they choose to take — measured: the playtest bot
	# lost every seed to an unleashed one, and no amount of stat softening
	# fixed the shape of that.
	_shadow_leashed = not CombatMath.within_leash(
		_shadow_anchor, _target.global_position, float(shadow_config.get("leash_px", 0.0))
	)
	# N9-48 (owner: "오다가 말고 끝까지 안 따라오더라"): standing frozen at the
	# leash edge reads as a broken chase. A shadow that has lost its hold sinks
	# back into the dark it belongs to — it fades and is gone, which reads as
	# the haunt letting go rather than as a monster that stopped working.
	var fade_sec: float = float(shadow_config.get("leash_fade_sec", 0.0))
	if _shadow_leashed and fade_sec > 0.0:
		_shadow_leash_left += delta
		modulate.a = clampf(1.0 - _shadow_leash_left / fade_sec, 0.0, 1.0)
		if _shadow_leash_left >= fade_sec:
			modulate.a = 1.0
			died.emit(self)
			return true
	elif _shadow_leash_left > 0.0:
		# Back inside the haunt before it finished sinking: it solidifies again.
		_shadow_leash_left = maxf(_shadow_leash_left - delta * 2.0, 0.0)
		modulate.a = clampf(1.0 - _shadow_leash_left / fade_sec, 0.0, 1.0)
	_shadow_scale = CombatMath.shadow_scale(_shadow_scale, delta, _lit, shadow_config)
	_visual.scale = Vector2(float(_facing) * _shadow_scale, _shadow_scale)
	if _flash_left <= 0.0:
		var tint: Color = UiPalette.SHADOW_LIT if _lit else UiPalette.SHADOW_DARK
		if _has_art:
			_sprite.modulate = tint
		else:
			_body.color = tint
	return false


func is_burning() -> bool:
	return _burn_left > 0.0


func apply_shock(slow_scale: float, duration: float) -> void:
	_shock_scale = minf(_shock_scale, slow_scale)
	_shock_left = maxf(_shock_left, duration)


## 진언 (N4-4b): a stun roots the chase and mutes the contact bite; repeats
## refresh, never shorten.
func apply_stun(duration: float) -> void:
	_stun_left = maxf(_stun_left, duration)


## 살 (N4-4b): strongest curse wins, reapply refreshes the clock — same rule
## as burn. Spread parameters carry so a propagated curse keeps chaining.
func apply_curse(dps: float, duration: float, spread_px: float, spread_count: int) -> void:
	if dps >= curse_dps:
		curse_dps = dps
		curse_duration = duration
	curse_spread_px = maxf(curse_spread_px, spread_px)
	curse_spread_count = maxi(curse_spread_count, spread_count)
	_curse_left = maxf(_curse_left, duration)


func is_cursed() -> bool:
	return _curse_left > 0.0


## One seal stack (법검+주사, N4-4a). Returns true when this stack reaches the
## burst threshold; the caller deals the burst damage so the damage number
## flows through the normal hit pipeline.
func apply_seal(burst_at: int) -> bool:
	_seal_stacks += 1
	if _seal_stacks < burst_at:
		return false
	_seal_stacks = 0
	return true


func _update_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_tick += delta
	if _burn_tick < BURN_TICK_SEC:
		return
	_burn_tick -= BURN_TICK_SEC
	var amount: float = burn_dps * BURN_TICK_SEC
	var at: Vector2 = global_position
	# A killing tick releases this enemy synchronously via died; emitting the
	# tick after keeps the number at the corpse position.
	take_damage(amount)
	burn_ticked.emit(amount, at)


## Same half-second cadence as burn; ticks flow through the shared
## burn_ticked relay so curse numbers float like any other DoT.
func _update_curse(delta: float) -> void:
	# The burn tick this same frame may have already killed and released this
	# enemy — ticking again would emit died twice.
	if _curse_left <= 0.0 or CombatMath.is_dead(hp):
		return
	_curse_left -= delta
	_curse_tick += delta
	if _curse_tick < BURN_TICK_SEC:
		return
	_curse_tick -= BURN_TICK_SEC
	var amount: float = curse_dps * BURN_TICK_SEC
	var at: Vector2 = global_position
	take_damage(amount)
	burn_ticked.emit(amount, at)


## Flash is a plain color/modulate swap — no tween, no alloc.
func _update_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left > 0.0:
		return
	if _has_art:
		_sprite.modulate = Color.WHITE
	else:
		_body.color = _base_color()


## Walk while chasing, idle when knock-back and steering cancel out; face the
## actual travel direction, keeping the last facing on vertical-only travel.
func _update_visual_motion() -> void:
	_facing = PlayerMotion.facing_sign(velocity.x, _facing)
	# A shadow's scale carries its growth on both axes; mirror by sign only.
	_visual.scale.x = float(_facing) * absf(_visual.scale.x) if is_shadow() 		else float(_facing)
	if not _has_art:
		return
	if velocity != Vector2.ZERO:
		_sprite.play(SpriteSheet.ANIM_WALK)
	else:
		_sprite.play(SpriteSheet.ANIM_IDLE)


func _base_color() -> Color:
	if is_boss:
		return UiPalette.ENEMY_BOSS
	return PLACEHOLDER_COLORS.get(monster_id, UiPalette.ENEMY_GOBLIN)


func _try_contact_damage() -> void:
	if not CombatMath.can_hit(_time_since_contact, _contact_cooldown):
		return
	var reach: float = contact_radius + Player.CONTACT_RADIUS
	if global_position.distance_squared_to(_target.global_position) > reach * reach:
		return
	if _target.take_hit(CombatMath.shadow_damage(_damage, _shadow_scale, shadow_config), name_ko):
		_time_since_contact = 0.0


func _apply_placeholder_visual() -> void:
	var size := Vector2(contact_radius * 2.0, contact_radius * VISUAL_HEIGHT_RATIO)
	_body.color = _base_color()
	_body.size = size
	_body.position = -size / 2.0
	var eye := _body.get_node("Eye") as ColorRect
	var eye_side: float = size.x * EYE_RATIO
	eye.size = Vector2(eye_side, eye_side)
	eye.position = Vector2(size.x * 0.55, size.y * 0.2)


## N3-17 status visual: a flickering soul-flame above a burning enemy and a
## crossed hex mark above a cursed one, so both DoTs read at a glance on a
## crowded field. Draw-call only — no nodes, no allocation; redraws run only
## while a status is active (plus one clearing redraw when it ends). Flicker
## rate from data (weapon_effects.status_flicker_hz).
class StatusOverlay:
	extends Node2D

	const FLAME_RADIUS := 4.0
	const MARK_HALF := 5.0
	const MARK_WIDTH := 2.0
	const RISE_PX := 6.0

	var enemy: Enemy
	var _phase: float = 0.0
	var _was_active: bool = false

	func _physics_process(delta: float) -> void:
		var active: bool = enemy.is_burning() or enemy.is_cursed()
		if active:
			_phase += delta * WeaponEffects.value("status_flicker_hz")
			queue_redraw()
		elif _was_active:
			queue_redraw()  # one clearing pass after the last status expires
		_was_active = active

	func _draw() -> void:
		var top: float = -(enemy.contact_radius * Enemy.VISUAL_HEIGHT_RATIO * 0.5 + RISE_PX)
		var flicker: float = 0.5 + 0.5 * sin(_phase * TAU)
		if enemy.is_burning():
			var at := Vector2(-MARK_HALF - 1.0 if enemy.is_cursed() else 0.0, top)
			var wobble := Vector2(flicker * 2.0 - 1.0, -flicker * 2.0)
			draw_circle(at + wobble, FLAME_RADIUS, UiPalette.WEAPON_FIRE)
			draw_circle(at + wobble * 1.4, FLAME_RADIUS * 0.5, UiPalette.GOLD)
		if enemy.is_cursed():
			var at := Vector2(MARK_HALF + 1.0 if enemy.is_burning() else 0.0, top)
			var bob := Vector2(0.0, (flicker - 0.5) * 2.0)
			var arm := Vector2(MARK_HALF, MARK_HALF)
			var flip := Vector2(MARK_HALF, -MARK_HALF)
			draw_line(at + bob - arm, at + bob + arm, UiPalette.WEAPON_CURSE, MARK_WIDTH)
			draw_line(at + bob - flip, at + bob + flip, UiPalette.WEAPON_CURSE, MARK_WIDTH)
			draw_arc(
				at + bob, MARK_HALF + 2.0, 0.0, TAU, 12, UiPalette.WEAPON_CURSE, 1.0
			)
