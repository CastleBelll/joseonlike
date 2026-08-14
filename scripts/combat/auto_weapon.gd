class_name AutoWeapon
extends Node2D
## Data-driven auto-attack (N3-3, archetypes N4-4a): one node drives every
## taoist weapon mechanic from data/weapons.json via its "mechanic" field —
## straight throw, pierce line, impact explosion, chain jumps, melee arc
## swing, and orbiting DoT orbs. Projectile mechanics fire the shared pooled
## Projectile at the nearest live enemy that is visible on screen (view rect
## + _targeting.view_margin_px) AND within the weapon's own range_px (N3-15);
## no visible target holds the shot ready. All balance numbers come from data.

signal hit_landed(amount: float, at: Vector2, boss_hit: bool)

const WEAPONS_PATH := "res://data/weapons.json"
## Cooldown can shrink per level and per attack-speed stacks; never let it
## reach zero or the weapon would fire every frame.
const MIN_COOLDOWN_SEC := 0.05
## N4-4a placeholder feedback timings (visual only; damage is instant).
const ARC_FLASH_SEC := 0.18
const EXPLOSION_FLASH_SEC := 0.25
## Orb visual + hit radius for the orbit mechanic (혼불).
const ORB_RADIUS_PX := 5.0
const MECHANIC_STRAIGHT := "straight"
const MECHANIC_PIERCE := "pierce"
const MECHANIC_EXPLOSION := "explosion"
const MECHANIC_CHAIN := "chain"
const MECHANIC_MELEE_ARC := "melee_arc"
const MECHANIC_ORBIT := "orbit"
## N4-1/N4-4a: per-weapon placeholder tint so every archetype reads distinct
## on the field; anything unlisted keeps the plain talisman paper.
const TINTS: Dictionary = {
	"fire_talisman": UiPalette.WEAPON_FIRE,
	"phoenix_talisman": UiPalette.WEAPON_FIRE,
	"hwabu": UiPalette.WEAPON_FIRE,
	"hwaryeongbu": UiPalette.WEAPON_FIRE,
	"noebu": UiPalette.WEAPON_LIGHTNING,
	"noejeongbu": UiPalette.WEAPON_LIGHTNING,
	"beopgeom": UiPalette.WEAPON_SEAL,
	"bongmageom": UiPalette.WEAPON_SEAL,
	"seokjang": UiPalette.WOOD,
	"ghost_staff": UiPalette.WEAPON_GHOST,
	"honbul": UiPalette.WEAPON_SOUL,
	"flame_honbul": UiPalette.WEAPON_FIRE,
}

var weapon_id: String = ""

var _stats: Dictionary = {}
var _level: int = 1
var _grade: String = ""
var _grades: Dictionary = {}
var _damage_scale: float = 1.0
var _cooldown_scale: float = 1.0
var _damage: float = 0.0
var _cooldown: float = 0.0
var _speed: float = 0.0
var _range: float = 0.0
var _view_margin: float = 0.0
var _cooldown_left: float = 0.0
var _player: Player
var _spawner: Spawner
var _pool: NodePool
# N4-4a mechanic state.
var _mechanic: String = MECHANIC_STRAIGHT
var _shot_config: Dictionary = {}
var _lifesteal: float = 0.0
var _arc: Dictionary = {}
var _orbit: Dictionary = {}
var _orbit_elapsed: float = 0.0
var _orbs: Array[Node2D] = []
# Per-enemy orbit re-hit gate: instance id -> next allowed _orbit_elapsed.
# Pooled enemies reuse ids, so a fresh spawn may inherit a near-expired gate —
# at worst it dodges orbs for one cooldown_sec. Accepted.
var _orb_recent: Dictionary = {}
var _arc_flash: ArcFlash
var _flash_pool: NodePool
var _caught: Array[Enemy] = []  # per-frame scratch, reused without alloc


func setup(id: String, player: Player, spawner: Spawner) -> void:
	_player = player
	_spawner = spawner
	_pool = NodePool.new(self, _create_projectile)
	var weapons: Variant = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	if weapons is not Dictionary or not (weapons as Dictionary).has(id):
		push_error("auto_weapon: unknown weapon id '%s' in %s" % [id, WEAPONS_PATH])
		return
	weapon_id = id
	_stats = weapons[id]
	_grades = WeaponGrade.config(weapons)
	_grade = String(_stats.get("grade", ""))
	_speed = float(_stats.get("speed", 0.0))
	_range = float(_stats.get("range_px", 0.0))
	_view_margin = float(
		((weapons as Dictionary).get("_targeting", {}) as Dictionary).get("view_margin_px", 0.0)
	)
	_mechanic = String(_stats.get("mechanic", MECHANIC_STRAIGHT))
	_lifesteal = float(_stats.get("lifesteal", 0.0))
	_shot_config = _build_shot_config()
	match _mechanic:
		MECHANIC_MELEE_ARC:
			_arc = _stats.get("arc", {})
			_arc_flash = ArcFlash.new()
			add_child(_arc_flash)
		MECHANIC_ORBIT:
			_orbit = _stats.get("orbit", {})
			_build_orbs(int(_stats.get("projectile_count", 1)))
		MECHANIC_EXPLOSION:
			_flash_pool = NodePool.new(self, _create_explosion_flash)
	_recompute()


## N3-6 level-up: weapon level drives the per_level curve from weapons.json.
func set_level(level: int) -> void:
	_level = level
	_recompute()


## N4-2 grade raise: the run grade compounds the data-driven step factors on
## top of the level curve.
func set_grade(grade: String) -> void:
	_grade = grade
	_recompute()


## N3-6 passives: run-wide damage multiplier and cooldown multiplier
## (attack speed as 1 / (1 + bonus), computed by the stage).
func set_scales(damage_scale: float, cooldown_scale: float) -> void:
	_damage_scale = damage_scale
	_cooldown_scale = cooldown_scale
	_recompute()


func _recompute() -> void:
	if _stats.is_empty():
		return
	_damage = WeaponGrade.stat_at(_stats, "damage", _level, _grade, _grades) * _damage_scale
	_cooldown = maxf(
		WeaponGrade.stat_at(_stats, "cooldown_sec", _level, _grade, _grades) * _cooldown_scale,
		MIN_COOLDOWN_SEC
	)


## The per-shot Projectile mechanic block, fixed per weapon (only damage and
## cooldown move with levels/grades/passives).
func _build_shot_config() -> Dictionary:
	var config: Dictionary = {}
	if _stats.has("on_hit_status"):
		config["status"] = _stats.get("on_hit_status", {})
	if _stats.has("on_hit_seal"):
		config["seal"] = _stats.get("on_hit_seal", {})
	match _mechanic:
		MECHANIC_STRAIGHT:
			config["pierce"] = int(_stats.get("pierce", 0))
		MECHANIC_PIERCE:
			config["pierce"] = int(_stats.get("pierce", 0))
			config["size"] = Projectile.BLADE_SIZE
		MECHANIC_EXPLOSION:
			config["explosion_radius"] = float(
				(_stats.get("explosion", {}) as Dictionary).get("radius_px", 0.0)
			)
		MECHANIC_CHAIN:
			config["chain"] = _stats.get("chain", {})
	return config


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _mechanic == MECHANIC_ORBIT:
		_process_orbit(delta)
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	if _try_fire():
		_cooldown_left = _cooldown  # no target keeps the shot ready, VS-style


func _try_fire() -> bool:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	# Player position approximates the smoothed camera center, same tradeoff
	# as the spawner (N3-4).
	var index: int = CombatMath.nearest_visible_index(
		_player.global_position, _player.global_position, get_viewport_rect().size,
		_view_margin, positions, _range
	)
	if index < 0:
		return false
	if _mechanic == MECHANIC_MELEE_ARC:
		return _fire_arc(enemies, positions, index)
	var direction: Vector2 = CombatMath.chase_direction(
		_player.global_position, positions[index]
	)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT  # enemy exactly on the player; any heading hits
	var projectile: Projectile = _pool.acquire()
	projectile.launch(
		_player.global_position, direction, _speed, _damage, _spawner, _player,
		_tint(), _view_margin, _shot_config
	)
	return true


## 석장 (N4-4a): one swing centered on the nearest visible enemy — everything
## whose body reaches into the arc takes damage and a boosted shove.
func _fire_arc(enemies: Array[Enemy], positions: Array[Vector2], index: int) -> bool:
	var origin: Vector2 = _player.global_position
	var aim: float = (positions[index] - origin).angle()
	var arc_rad: float = deg_to_rad(float(_arc.get("angle_deg", 0.0)))
	var knockback: float = float(_arc.get("knockback_scale", 1.0))
	var radii: Array[float] = []
	for enemy: Enemy in enemies:
		radii.append(enemy.contact_radius)
	# Collect refs first: striking mutates the spawner's active list.
	_caught.clear()
	for i: int in WeaponMath.arc_hits(origin, aim, arc_rad, _range, positions, radii):
		_caught.append(enemies[i])
	for enemy: Enemy in _caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(_damage, CombatMath.chase_direction(origin, hit_at), knockback)
		_after_hit(_damage)
		hit_landed.emit(_damage, hit_at, boss_hit)
	_arc_flash.flash(origin, aim, arc_rad, _range, _tint(), ARC_FLASH_SEC)
	return true


## 혼불 (N4-4a): orbs ride a ring around the player; contact deals the weapon
## damage, applies the data burn, and re-arms per enemy after cooldown_sec.
func _process_orbit(delta: float) -> void:
	_orbit_elapsed += delta
	var radius: float = float(_orbit.get("radius_px", 0.0))
	var speed_deg: float = float(_orbit.get("speed_deg_s", 0.0))
	for i: int in range(_orbs.size()):
		_orbs[i].global_position = WeaponMath.orbit_position(
			_player.global_position, radius, speed_deg, _orbit_elapsed, i, _orbs.size()
		)
	_caught.clear()
	for enemy: Enemy in _spawner.active_enemies():
		if float(_orb_recent.get(enemy.get_instance_id(), 0.0)) > _orbit_elapsed:
			continue
		var reach: float = enemy.contact_radius + ORB_RADIUS_PX
		for orb: Node2D in _orbs:
			if orb.global_position.distance_squared_to(enemy.global_position) <= reach * reach:
				_caught.append(enemy)
				break
	var status: Dictionary = _stats.get("on_hit_status", {})
	for enemy: Enemy in _caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		_orb_recent[enemy.get_instance_id()] = _orbit_elapsed + _cooldown
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		if String(status.get("id", "")) == "burn":
			enemy.apply_burn(
				float(status.get("dps", 0.0)),
				float(status.get("duration_sec", 0.0)),
				float(status.get("spread_radius_px", 0.0))
			)
		enemy.take_damage(_damage, CombatMath.chase_direction(_player.global_position, hit_at))
		_after_hit(_damage)
		hit_landed.emit(_damage, hit_at, boss_hit)


## 석장+귀철 (N4-4a): every landed point heals its lifesteal share, capped at
## the run's max HP.
func _after_hit(amount: float) -> void:
	if _lifesteal <= 0.0:
		return
	_player.hp = minf(_player.hp + amount * _lifesteal, _player.hp_max)


func _build_orbs(count: int) -> void:
	for i: int in range(maxi(count, 1)):
		var orb := OrbVisual.new()
		orb.color = _tint()
		add_child(orb)
		_orbs.append(orb)


## Weapon-id tint by default; a grade step flagged "tinted" (N4-2) recolors
## the projectile with the run grade's tier color so the raise reads on field.
func _tint() -> Color:
	if WeaponGrade.has_flag(_grades, String(_stats.get("grade", "")), _grade, "tinted"):
		return Loot.TIER_COLORS.get(_grade, UiPalette.PAPER)
	return TINTS.get(weapon_id, UiPalette.PAPER)


func _create_projectile() -> Projectile:
	var projectile := Projectile.new()
	projectile.hit_landed.connect(
		func(amount: float, at: Vector2, boss_hit: bool) -> void:
			_after_hit(amount)
			hit_landed.emit(amount, at, boss_hit)
	)
	projectile.exploded.connect(_on_projectile_exploded)
	projectile.finished.connect(_on_projectile_finished)
	return projectile


func _on_projectile_exploded(at: Vector2, radius: float) -> void:
	if _flash_pool == null:
		return
	var flash: DeathPuff = _flash_pool.acquire()
	flash.puff(at, radius, EXPLOSION_FLASH_SEC, UiPalette.WEAPON_FIRE)


func _create_explosion_flash() -> DeathPuff:
	var flash := DeathPuff.new()
	flash.finished.connect(
		func(done: DeathPuff) -> void: _flash_pool.release(done)
	)
	return flash


func _on_projectile_finished(projectile: Projectile) -> void:
	_pool.release(projectile)


## 혼불 orb placeholder: soul-flame disc with a white core (N4-4a).
class OrbVisual:
	extends Node2D

	var color: Color = UiPalette.WEAPON_SOUL

	func _draw() -> void:
		draw_circle(Vector2.ZERO, AutoWeapon.ORB_RADIUS_PX, color)
		draw_circle(Vector2.ZERO, AutoWeapon.ORB_RADIUS_PX * 0.45, UiPalette.LOOT_CORE)


## 석장 swing placeholder: a double arc stroke that fades over the flash time.
## One swing is ever alive per weapon (cooldown >> flash), so a single reused
## instance replaces a pool.
class ArcFlash:
	extends Node2D

	const OUTER_RATIO := 0.9
	const INNER_RATIO := 0.6
	const OUTER_WIDTH := 5.0
	const INNER_WIDTH := 3.0
	const POINTS := 20

	var _aim: float = 0.0
	var _arc_rad: float = 0.0
	var _radius: float = 0.0
	var _color: Color = UiPalette.PAPER
	var _age: float = 0.0
	var _duration: float = 0.0

	func _ready() -> void:
		visible = false

	func flash(
		at: Vector2, aim: float, arc_rad: float, radius: float,
		color: Color, duration: float
	) -> void:
		global_position = at
		_aim = aim
		_arc_rad = arc_rad
		_radius = radius
		_color = color
		_duration = maxf(duration, 0.01)
		_age = 0.0
		visible = true
		modulate.a = 1.0
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_age += delta
		if _age >= _duration:
			visible = false
			return
		modulate.a = 1.0 - _age / _duration
		queue_redraw()

	func _draw() -> void:
		var from: float = _aim - _arc_rad / 2.0
		var to: float = _aim + _arc_rad / 2.0
		draw_arc(Vector2.ZERO, _radius * OUTER_RATIO, from, to, POINTS, _color, OUTER_WIDTH)
		draw_arc(Vector2.ZERO, _radius * INNER_RATIO, from, to, POINTS, _color, INNER_WIDTH)
