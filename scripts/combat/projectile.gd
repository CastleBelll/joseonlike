class_name Projectile
extends Node2D
## Pooled weapon projectile (N3-3, mechanics N4-4a). One class, one pool:
## straight flight plus the data-driven extras a shot config arms per launch —
## pierce (법검), impact explosion (화부), chain jumps (뇌부), on-hit status
## (burn/shock) and seal stacks. Finishes when its mechanic is spent or it
## leaves the visible view rect plus the shared targeting margin (N3-15).

signal hit_landed(amount: float, at: Vector2, boss_hit: bool, crit: bool)
## N4-4a: the impact splash happened — AutoWeapon shows the pooled ring flash.
signal exploded(at: Vector2, radius: float)
## N3-17: a chain shot connected two enemies — AutoWeapon draws the bolt.
signal chained(from: Vector2, to: Vector2)
signal finished(projectile: Projectile)

const HIT_RADIUS := 4.0


## Talisman paper size (N3-18: from data — the 6x12 N3-3 paper was invisible
## in flight at 540x960, so the throw read as nothing but a damage number).
static func paper_size() -> Vector2:
	return Vector2(
		WeaponEffects.value("paper_width_px"), WeaponEffects.value("paper_length_px")
	)


## 법검/봉마검 sword-qi blade (N4-4a, sized from data since N3-18).
static func blade_size() -> Vector2:
	return Vector2(
		WeaponEffects.value("blade_width_px"), WeaponEffects.value("blade_length_px")
	)

## N9-80 flight-animation rate. A constant rather than a data knob: a flight
## lasts a fraction of a second, so this is a look, not a balance number, and a
## per-weapon key would be one more thing to keep in sync with the art.
const TRAVEL_FPS := 12.0

var _velocity := Vector2.ZERO
var _damage: float = 0.0
var _crit: bool = false
var _view_margin: float = 0.0
var _spawner: Spawner
var _player: Player
var _sprite: Sprite2D
var _paper: ColorRect
var _seal_mark: ColorRect
# N4-4a mechanic state, armed per launch from the AutoWeapon shot config.
var _pierce_left: int = 0
# N4-3 tuning knobs: damage kept per pierced enemy, damage kept at the blast
# edge. Both default 1.0 (no decay) when the weapon data omits them.
var _pierce_retention: float = 1.0
var _explosion_falloff: float = 1.0
var _explosion_radius: float = 0.0
var _chain_jumps_left: int = 0
var _chain_falloff: float = 1.0
var _chain_range: float = 0.0
## N3-17: previous chain hit position — the next hit draws a bolt from here.
var _chain_prev := Vector2.INF
## Where this shot was cast from — the first chain leg is drawn from here.
var _origin := Vector2.ZERO
## N9-42 instant strike (chain weapons): resolved on the first physics frame.
var _instant: bool = false
var _instant_target: Enemy = null
var _status: Dictionary = {}
var _seal: Dictionary = {}
var _trail: TrailVisual
## N9-80 flight animation: how many frames the travel art declared, and how long
## this shot has been in the air. 1 frame means a still, which is every shipped
## travel sprite today.
var _travel_frames: int = 1
var _travel_age: float = 0.0
# Enemies this shot already struck (instance id -> true) so pierce and chain
# never hit twice. A pooled instance re-armed mid-flight would be wrongly
# excluded, but flights last well under a second — accepted.
var _struck: Dictionary = {}
var _touched: Array[Enemy] = []  # per-frame scratch, reused without alloc


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "TravelSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.color = UiPalette.PAPER
	add_child(_paper)
	_seal_mark = ColorRect.new()
	_seal_mark.name = "Seal"
	_seal_mark.color = UiPalette.VERMILION
	_paper.add_child(_seal_mark)
	_trail = TrailVisual.new()
	_trail.name = "Trail"
	add_child(_trail)
	_apply_shape(paper_size())
	_set_travel_art("", 1)


## Travel art is optional by contract: bad or absent data keeps the original
## paper/blade ColorRect path rather than turning a projectile invisible.
static func travel_available(path: String) -> bool:
	return not path.is_empty() and ResourceLoader.exists(path, "Texture2D")


## `config` arms the N4-4a mechanics; an empty dict keeps the plain N3-3 shot:
## {"pierce": int, "explosion_radius": float, "chain": {jumps, falloff,
## range_px}, "status": Dictionary, "seal": Dictionary, "size": Vector2,
## "travel_sprite": String}.
## N9-34: `crit` travels with the shot. The roll happens at launch, in the
## weapon, so the projectile has to carry the verdict to the hit it eventually
## lands — otherwise the number reports a plain hit for doubled damage.
func launch(from: Vector2, direction: Vector2, speed: float, damage: float,
		spawner: Spawner, player: Player, tint: Color = UiPalette.PAPER,
		view_margin: float = 0.0, config: Dictionary = {}, crit: bool = false,
		strike_now: Enemy = null) -> void:
	global_position = from
	_origin = from
	_velocity = direction * speed
	_damage = damage
	_crit = crit
	_view_margin = view_margin
	_spawner = spawner
	_player = player
	# N4-1: modded weapons tint the paper so a transformation reads on field.
	_paper.color = tint
	_set_travel_art(
		String(config.get("travel_sprite", "")), int(config.get("travel_frames", 1))
	)
	_aim_visual(direction)
	_pierce_left = int(config.get("pierce", 0))
	_pierce_retention = float(config.get("pierce_retention", 1.0))
	_explosion_radius = float(config.get("explosion_radius", 0.0))
	_explosion_falloff = float(config.get("explosion_falloff", 1.0))
	var chain: Dictionary = config.get("chain", {})
	_chain_jumps_left = int(chain.get("jumps", 0))
	_chain_falloff = float(chain.get("falloff", 1.0))
	_chain_range = float(chain.get("range_px", 0.0))
	_chain_prev = Vector2.INF
	_instant_target = strike_now
	_instant = strike_now != null
	_status = config.get("status", {})
	_seal = config.get("seal", {})
	_struck.clear()
	# N3-18: every shot trails — the flight path is the weapon's read. Pierce
	# keeps the long blade streak; paper shots get a short fade so a crowded
	# field doesn't fill with ribbons.
	_trail.arm(
		true, tint,
		WeaponEffects.value(
			"blade_trail_sec" if config.has("size") else "paper_trail_sec"
		)
	)
	_apply_shape(config.get("size", paper_size()))


func _physics_process(delta: float) -> void:
	if _instant:
		# N9-42: chain weapons do not travel. The shot resolves on the frame it
		# is cast, at its target, and the bolts do the talking. Handled here
		# rather than inside launch() so the strike still runs inside the
		# physics step, where every other strike in this file runs.
		_instant = false
		if _instant_target != null and not CombatMath.is_dead(_instant_target.hp):
			var target_at: Vector2 = _instant_target.global_position
			global_position = target_at
			_strike(_instant_target, _damage)
			if _chain_jumps_left > 0:
				_resolve_chain(target_at)
		_instant_target = null
		finished.emit(self)
		return
	global_position += _velocity * delta
	_tick_travel_art(delta)
	_trail.record(global_position, delta)
	# N5-5: a shot passing over a destructible prop chips it. Free of pierce
	# accounting on purpose — props never eat a shot meant for a monster — and
	# gated by _struck so one flight damages each prop once.
	for breakable: Breakable in _spawner.breakables:
		if not breakable.alive() or _struck.has(breakable.get_instance_id()):
			continue
		var break_reach: float = breakable.hit_radius + HIT_RADIUS
		if global_position.distance_squared_to(breakable.global_position) \
				<= break_reach * break_reach:
			_struck[breakable.get_instance_id()] = true
			breakable.take_weapon_damage(_damage)
	# Collect overlaps first: striking mutates the spawner's active list, so
	# never kill while iterating it.
	_touched.clear()
	for enemy: Enemy in _spawner.active_enemies():
		if _struck.has(enemy.get_instance_id()):
			continue
		var reach: float = enemy.contact_radius + HIT_RADIUS
		if global_position.distance_squared_to(enemy.global_position) <= reach * reach:
			_touched.append(enemy)
	for enemy: Enemy in _touched:
		if CombatMath.is_dead(enemy.hp):
			continue  # an earlier strike this frame already killed it
		var hit_at: Vector2 = enemy.global_position
		_strike(enemy, _damage)
		if _explosion_radius > 0.0:
			_explode(hit_at)
			finished.emit(self)
			return
		if _chain_jumps_left > 0:
			# N9-5d (owner report): the chain resolves INSTANTLY — every jump
			# lands this frame and every bolt leg flashes at once, instead of
			# the shot physically flying leg by leg.
			_resolve_chain(hit_at)
			finished.emit(self)
			return
		if _pierce_left > 0:
			_pierce_left -= 1
			_damage *= _pierce_retention  # 법검 (N4-3): each body soaks a share
			continue  # flies on through; may strike another overlap this frame
		finished.emit(self)
		return
	# Player position approximates the smoothed camera center, same tradeoff
	# as the spawner (N3-4).
	var gone: bool = CombatMath.outside_view(
		global_position, _player.global_position, get_viewport_rect().size, _view_margin
	)
	if gone:
		finished.emit(self)


## One enemy takes this shot: status first (so a killing blow still leaves a
## spreadable burn), then damage — with the seal burst folded into the same
## take_damage call so a dying enemy is never touched twice.
func _strike(enemy: Enemy, damage: float) -> void:
	var hit_at: Vector2 = enemy.global_position
	var boss_hit: bool = enemy.is_boss
	_struck[enemy.get_instance_id()] = true
	# N3-17: a chain shot draws its lightning leg between consecutive hits.
	# N3-18: the FIRST hit also crackles — a short leg arcing in along the
	# flight line — so a lone target still reads "lightning", not plain paper.
	if _chain_range > 0.0:
		if _chain_prev != Vector2.INF:
			chained.emit(_chain_prev, hit_at)
		else:
			# N9-42 (owner: lightning should leave the CHARACTER, not fly in as
			# a talisman): the first leg is drawn from where the shot was cast,
			# so the bolt reads as reaching out from the caster. It used to be
			# a stub arcing in along the flight line, which only made sense
			# while the shot visibly travelled.
			chained.emit(_origin, hit_at)
		_chain_prev = hit_at
	match String(_status.get("id", "")):
		"burn":
			enemy.apply_burn(
				float(_status.get("dps", 0.0)),
				float(_status.get("duration_sec", 0.0)),
				float(_status.get("spread_radius_px", 0.0))
			)
		"shock":
			enemy.apply_shock(
				float(_status.get("slow_scale", 1.0)),
				float(_status.get("duration_sec", 0.0))
			)
		"curse":
			enemy.apply_curse(
				float(_status.get("dps", 0.0)),
				float(_status.get("duration_sec", 0.0)),
				float(_status.get("spread_radius_px", 0.0)),
				int(_status.get("spread_count", 0))
			)
	var burst: float = 0.0
	if not _seal.is_empty() and enemy.apply_seal(int(_seal.get("burst_at", 0))):
		burst = damage * float(_seal.get("burst_damage_scale", 0.0))
	enemy.take_damage(damage + burst, _velocity.normalized())
	hit_landed.emit(damage, hit_at, boss_hit, _crit)
	if burst > 0.0:
		hit_landed.emit(burst, hit_at, boss_hit, false)


## 화부 (N4-4a): full damage to every enemy whose center sits in the splash.
## Strong on clumps by design — the single direct target pays the same shot.
func _explode(at: Vector2) -> void:
	exploded.emit(at, _explosion_radius)
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	var caught: Array[Enemy] = []
	for i: int in WeaponMath.targets_in_radius(at, positions, _explosion_radius):
		if not _struck.has(enemies[i].get_instance_id()):
			caught.append(enemies[i])
	for enemy: Enemy in caught:
		if not CombatMath.is_dead(enemy.hp):
			# N4-3: damage tapers toward the blast edge (edge_falloff 1.0 = flat).
			_strike(enemy, WeaponMath.explosion_damage(
				_damage, at.distance_to(enemy.global_position),
				_explosion_radius, _explosion_falloff
			))


## 뇌부 (N4-4a, instant since N9-5d): walk the whole chain in one frame —
## nearest fresh enemy in range from the last hit, data falloff per leg,
## stopping when the jumps or the crowd run out. _strike draws each bolt
## leg through _chain_prev, so the full chain flashes at once.
func _resolve_chain(from: Vector2) -> void:
	# Snapshot: active_enemies() is the spawner's LIVE array — a chain kill
	# inside this loop releases the enemy and shrinks it, so indexing the
	# original would go stale mid-walk (out-of-bounds observed in playtest).
	var enemies: Array[Enemy] = _spawner.active_enemies().duplicate()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	while _chain_jumps_left > 0:
		var exclude: Array[int] = []
		for i: int in range(enemies.size()):
			if _struck.has(enemies[i].get_instance_id()):
				exclude.append(i)
		var index: int = WeaponMath.chain_next_index(from, positions, exclude, _chain_range)
		if index < 0:
			return
		_chain_jumps_left -= 1
		_damage *= _chain_falloff
		if not CombatMath.is_dead(enemies[index].hp):
			_strike(enemies[index], _damage)
		else:
			_struck[enemies[index].get_instance_id()] = true
		from = positions[index]


## N9-80 (owner: 투사체도 이펙트가 필요할 것 같다). A travel sprite may be a
## horizontal strip, in which case the shot animates while it flies.
##
## The frame count comes from data, not from the file's shape. Character sheets
## in this project declare themselves by shape because their frames are square
## and the reading is unambiguous; travel sprites are NOT square (20x7, 18x10),
## so a 40x20 file could equally be one drawing or two frames and there is no
## way to tell. validate_data checks the declared count against the file width.
##
## Reset on every arm, not only when the path changes: these are pooled, and a
## reused instance that kept the previous shot's count would slice the new
## texture into cells it does not have.
func _set_travel_art(path: String, frames: int) -> void:
	_sprite.texture = load(path) if travel_available(path) else null
	_sprite.visible = _sprite.texture != null
	_paper.visible = not _sprite.visible
	_travel_frames = maxi(frames, 1) if _sprite.texture != null else 1
	_travel_age = 0.0
	_sprite.hframes = _travel_frames
	_sprite.frame = 0


## Advances the flight animation. Loops rather than holding the last frame: a
## flight has no fixed length, so an animation that ended would freeze in mid
## air on the long shots.
func _tick_travel_art(delta: float) -> void:
	if _travel_frames <= 1:
		return
	_travel_age += delta
	_sprite.frame = travel_frame(_travel_age, _travel_frames)


## Which cell a flight of `age` seconds is showing. Pure so the headless suite
## can pin the wrap-around and the still case.
static func travel_frame(age: float, frames: int) -> int:
	if frames <= 1:
		return 0
	return int(maxf(age, 0.0) * TRAVEL_FPS) % frames


func _aim_visual(direction: Vector2) -> void:
	# Pack cells face right; the procedural paper is authored vertically.
	rotation = direction.angle() if _sprite.visible else direction.angle() + PI / 2.0


func _apply_shape(size: Vector2) -> void:
	_paper.size = size
	_paper.position = -size / 2.0
	_seal_mark.size = size / 3.0
	_seal_mark.position = size / 2.0 - size / 6.0


## 법검 after-trail (N3-17): a fixed ring buffer of recent flight positions
## drawn as a tapering, fading streak behind the blade. top_level, so points
## are recorded and drawn in global space while the blade flies on. Buffers
## are pre-sized once — recording never allocates. Fade time comes from
## data/effects.json (weapon_effects.blade_trail_sec).
class TrailVisual:
	extends Node2D

	const CAPACITY := 12
	const WIDTH_HEAD := 5.0
	const WIDTH_TAIL := 1.0
	const ALPHA_HEAD := 0.55

	var _enabled: bool = false
	var _color: Color = UiPalette.WEAPON_SEAL
	var _fade_sec: float = 0.0
	var _points := PackedVector2Array()
	var _ages := PackedFloat32Array()
	var _head: int = -1
	var _count: int = 0

	func _init() -> void:
		top_level = true
		position = Vector2.ZERO
		_points.resize(CAPACITY)
		_ages.resize(CAPACITY)

	func arm(enabled: bool, color: Color, fade_sec: float) -> void:
		_enabled = enabled
		_color = color
		_fade_sec = fade_sec
		_head = -1
		_count = 0
		queue_redraw()

	func record(at: Vector2, delta: float) -> void:
		if not _enabled or _fade_sec <= 0.0:
			return
		for i: int in range(CAPACITY):
			_ages[i] += delta
		_head = (_head + 1) % CAPACITY
		_count = mini(_count + 1, CAPACITY)
		_points[_head] = at
		_ages[_head] = 0.0
		queue_redraw()

	func _draw() -> void:
		if not _enabled or _count < 2:
			return
		for step: int in range(_count - 1):
			var index: int = (_head - step + CAPACITY) % CAPACITY
			var previous: int = (index - 1 + CAPACITY) % CAPACITY
			var fade: float = 1.0 - clampf(_ages[index] / _fade_sec, 0.0, 1.0)
			if fade <= 0.0:
				break  # entries only get older down the buffer
			var t: float = float(step) / float(CAPACITY - 1)
			draw_line(
				to_local(_points[index]), to_local(_points[previous]),
				Color(_color, ALPHA_HEAD * fade), lerpf(WIDTH_HEAD, WIDTH_TAIL, t)
			)
