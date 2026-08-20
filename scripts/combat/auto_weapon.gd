class_name AutoWeapon
extends Node2D
## Data-driven auto-attack (N3-3, archetypes N4-4a): one node drives every
## taoist weapon mechanic from data/weapons.json via its "mechanic" field —
## straight throw, pierce line, impact explosion, chain jumps, melee arc
## swing, and orbiting DoT orbs. Targeting mechanics aim through the shared
## N6-4 fallback chain (CombatMath.fallback_aim): the nearest live enemy that
## is visible on screen (view rect + _targeting.view_margin_px) AND within
## the weapon's own range_px (N3-15), else the nearest visible destructible,
## else the player's facing direction — a weapon never holds its shot.
## All balance numbers come from data.

signal hit_landed(amount: float, at: Vector2, boss_hit: bool, crit: bool)

const WEAPONS_PATH := "res://data/weapons.json"
## Cooldown can shrink per level and per attack-speed stacks; never let it
## reach zero or the weapon would fire every frame.
const MIN_COOLDOWN_SEC := 0.05
## Orb visual + hit radius fallback for the orbit mechanic (혼불) when the
## data omits orbit.orb_radius_px (N4-3: the real value is a data knob).
const ORB_RADIUS_PX := 5.0
const MECHANIC_STRAIGHT := "straight"
const MECHANIC_PIERCE := "pierce"
const MECHANIC_EXPLOSION := "explosion"
const MECHANIC_CHAIN := "chain"
const MECHANIC_MELEE_ARC := "melee_arc"
const MECHANIC_ORBIT := "orbit"
# N4-4b extended kit (GDD §11.1): ground ward, autonomous summon, periodic
# control shockwave, and the spreading-curse projectile.
const MECHANIC_WARD := "ward"
const MECHANIC_SUMMON := "summon"
const MECHANIC_SHOCKWAVE := "shockwave"
const MECHANIC_CURSE := "curse"
## N4-1/N4-4a: per-weapon placeholder tint so every archetype reads distinct
## on the field; anything unlisted keeps the plain talisman paper.
const TINTS: Dictionary = {
	"fire_talisman": UiPalette.WEAPON_FIRE,
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
	"gyeolgye": UiPalette.WEAPON_SEAL,
	"hwayeom_gyeolgye": UiPalette.WEAPON_FIRE,
	"sinjang": UiPalette.ACCENT_TAOIST,
	"noe_sinjang": UiPalette.WEAPON_LIGHTNING,
	"bongin_jineon": UiPalette.WEAPON_SEAL,
	"sal": UiPalette.WEAPON_CURSE,
	"gwisal": UiPalette.WEAPON_CURSE,
}

## Fan spread between adjacent multishot projectiles when the data omits
## _targeting.multishot_spread_deg (N4-8).
## N9-69 impact marks. The ceiling is per weapon: a ward ticking across a
## crowd reports dozens of hits a second, and the screen has to stay readable.
const MAX_LIVE_MARKS := 14
const CRIT_MARK_SCALE := 1.45
const FAN_SPREAD_DEG := 10.0

var weapon_id: String = ""

## Meta-modified base entry from weapons.json; _stats is this with the
## current level's milestone deltas folded in (N4-8).
var _base_stats: Dictionary = {}
var _stats: Dictionary = {}
var _fan_spread_deg: float = FAN_SPREAD_DEG
var _level: int = 1
var _grade: String = ""
var _grades: Dictionary = {}
var _damage_scale: float = 1.0
var _cooldown_scale: float = 1.0
var _speed_scale: float = 1.0
var _extra_projectiles: int = 0
var _crit_chance: float = 0.0
var _crit_multiplier: float = 1.0
## Set by _roll_damage and read at the emit that immediately follows it. A
## member rather than a returned pair because this is the per-hit hot path and
## a Dictionary here would allocate on every shot.
var _last_crit: bool = false
## N9-36: set by the stage while the first-run guide is before its combat page.
var hold_fire: bool = false
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
var _orb_radius: float = ORB_RADIUS_PX
var _orbit_elapsed: float = 0.0
var _orbs: Array[Node2D] = []
# Per-enemy orbit re-hit gate: instance id -> next allowed _orbit_elapsed.
# Pooled enemies reuse ids, so a fresh spawn may inherit a near-expired gate —
# at worst it dodges orbs for one cooldown_sec. Accepted.
var _orb_recent: Dictionary = {}
var _arc_flash: ArcFlash
var _flash_pool: NodePool
var _impact_effect: String = ""
## N9-69: impact marks currently on screen from THIS weapon, against the cap.
var _live_marks: int = 0
var _impact_pool: NodePool
# N3-17 effect state: chain-jump bolts and the shockwave camera thump.
var _bolt_pool: NodePool
var _nudge_left: float = 0.0
var _caught: Array[Enemy] = []  # per-frame scratch, reused without alloc
# N4-4b mechanic state: pooled wards, one live summon, shockwave numbers.
var _ward: Dictionary = {}
var _ward_pool: NodePool
var _summon_config: Dictionary = {}
var _summon_pool: NodePool
var _live_summon: Summon
var _shockwave: Dictionary = {}
var _positions: Array[Vector2] = []  # per-pulse scratch, reused without alloc


## `meta_effects` (N7-2) is the capped 명부수 aggregate; the 술법-branch keys
## fold into this weapon's mechanic blocks before anything reads them.
func setup(
	id: String, player: Player, spawner: Spawner, meta_effects: Dictionary = {}
) -> void:
	_player = player
	_spawner = spawner
	_pool = NodePool.new(self, _create_projectile)
	var weapons: Variant = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	if weapons is not Dictionary or not (weapons as Dictionary).has(id):
		push_error("auto_weapon: unknown weapon id '%s' in %s" % [id, WEAPONS_PATH])
		return
	weapon_id = id
	_base_stats = MetaTree.modified_weapon_stats(weapons[id], meta_effects)
	_impact_effect = String(_base_stats.get("hit_effect", ""))
	if EffectSprite.available(_impact_effect):
		_impact_pool = NodePool.new(self, _create_impact_sprite)
		# N9-69 (owner: "몬스터 타격 표시가 필요할거같아"): connected to the
		# weapon's OWN report of a hit, which every attack shape already emits.
		# Spawning from the projectile path — where it used to live — left the
		# arc, orbit, ward, summon and shockwave weapons with nothing at the
		# point of contact but a tenth of a second of white flash, and at 130
		# monsters that flash is invisible.
		hit_landed.connect(_mark_hit)
	_grades = WeaponGrade.config(weapons)
	_grade = String(_base_stats.get("grade", ""))
	var targeting: Dictionary = (weapons as Dictionary).get("_targeting", {})
	_view_margin = float(targeting.get("view_margin_px", 0.0))
	_fan_spread_deg = float(targeting.get("multishot_spread_deg", FAN_SPREAD_DEG))
	_mechanic = String(_base_stats.get("mechanic", MECHANIC_STRAIGHT))
	# One-time pools and visuals; every per-level number (milestones included)
	# is derived in _recompute so a level-up can reshape the mechanic (N4-8).
	match _mechanic:
		MECHANIC_MELEE_ARC:
			_arc_flash = ArcFlash.new()
			add_child(_arc_flash)
		MECHANIC_EXPLOSION, MECHANIC_SHOCKWAVE:
			_flash_pool = NodePool.new(self, _create_blast_ring)
		MECHANIC_CHAIN:
			_bolt_pool = NodePool.new(self, _create_chain_bolt)
		MECHANIC_WARD:
			_ward_pool = NodePool.new(self, _create_ward)
		MECHANIC_SUMMON:
			_summon_pool = NodePool.new(self, _create_summon)
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
## (attack speed as 1 / (1 + bonus), computed by the stage). N9-3 adds a
## projectile-speed multiplier for the 신속 투사 passive; melee/field
## mechanics keep speed 0 so it is naturally a no-op for them.
func set_scales(
	damage_scale: float, cooldown_scale: float, speed_scale: float = 1.0
) -> void:
	_damage_scale = damage_scale
	_cooldown_scale = cooldown_scale
	_speed_scale = speed_scale
	_recompute()


## N9-3g 다중 투사 passive: flat projectile bonus folded into the effective
## stats, so fans, orbits and every count consumer see it uniformly.
func set_extra_projectiles(count: int) -> void:
	_extra_projectiles = count
	_recompute()


## N9-18 치명타 확률: run-wide crit chance/multiplier from passives. Rolled
## per shot in _roll_damage so every mechanic — projectile, arc, ward tick,
## orbit graze — crits through one path.
func set_crit(chance: float, multiplier: float) -> void:
	_crit_chance = chance
	_crit_multiplier = multiplier


## Damage for one hit, with the crit roll folded in.
func _roll_damage() -> float:
	_last_crit = _crit_chance > 0.0 and randf() < _crit_chance
	return _damage * _crit_multiplier if _last_crit else _damage


func _recompute() -> void:
	if _base_stats.is_empty():
		return
	# N4-8: fold the current level's milestone deltas in first, so every
	# consumer below reads the effective mechanic numbers, not the level-1 base.
	_stats = LevelUp.stats_at_level(_base_stats, _level)
	if _extra_projectiles > 0:
		# stats_at_level returns the ORIGINAL dict when the weapon has no
		# milestones — copy before mutating or the bonus would corrupt
		# _base_stats and compound on every recompute.
		_stats = _stats.duplicate(true)
		_stats["projectile_count"] = int(_stats.get("projectile_count", 1)) + _extra_projectiles
	_speed = float(_stats.get("speed", 0.0)) * _speed_scale
	_range = float(_stats.get("range_px", 0.0))
	_lifesteal = float(_stats.get("lifesteal", 0.0))
	_shot_config = _build_shot_config()
	_arc = _stats.get("arc", {})
	_ward = _stats.get("ward", {})
	_summon_config = _stats.get("summon", {})
	_shockwave = _stats.get("shockwave", {})
	if _mechanic == MECHANIC_ORBIT:
		_orbit = _stats.get("orbit", {})
		_orb_radius = float(_orbit.get("orb_radius_px", ORB_RADIUS_PX))
		_sync_orbs(int(_stats.get("projectile_count", 1)))
	# A milestone delta and the 봉인 간파 meta node can both lower the seal
	# threshold; re-apply MetaTree's floor after composition so no data combo
	# can push it below the mechanic's minimum.
	var seal: Dictionary = _stats.get("on_hit_seal", {})
	if not seal.is_empty():
		seal["burst_at"] = maxi(int(seal.get("burst_at", 0)), MetaTree.MIN_SEAL_BURST)
	_damage = WeaponGrade.stat_at(_stats, "damage", _level, _grade, _grades) * _damage_scale
	_cooldown = maxf(
		WeaponGrade.stat_at(_stats, "cooldown_sec", _level, _grade, _grades) * _cooldown_scale,
		MIN_COOLDOWN_SEC
	)


## The per-shot Projectile mechanic block, fixed per weapon (only damage and
## cooldown move with levels/grades/passives).
func _build_shot_config() -> Dictionary:
	var config: Dictionary = {}
	var travel_sprite: String = String(_stats.get("travel_sprite", ""))
	if not travel_sprite.is_empty():
		config["travel_sprite"] = travel_sprite
	if _stats.has("on_hit_status"):
		config["status"] = _stats.get("on_hit_status", {})
	if _stats.has("on_hit_seal"):
		config["seal"] = _stats.get("on_hit_seal", {})
	match _mechanic:
		MECHANIC_STRAIGHT, MECHANIC_CURSE:
			config["pierce"] = int(_stats.get("pierce", 0))
		MECHANIC_PIERCE:
			config["pierce"] = int(_stats.get("pierce", 0))
			config["pierce_retention"] = float(_stats.get("pierce_retention", 1.0))
			config["size"] = Projectile.blade_size()  # 법검 blade streak (N3-17)
		MECHANIC_EXPLOSION:
			var explosion: Dictionary = _stats.get("explosion", {})
			config["explosion_radius"] = float(explosion.get("radius_px", 0.0))
			config["explosion_falloff"] = float(explosion.get("edge_falloff", 1.0))
		MECHANIC_CHAIN:
			config["chain"] = _stats.get("chain", {})
	return config


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# N9-36: the tutorial teaches one thing at a time, and "your talisman fires
	# itself" is a later beat than "you can walk". Held before that beat, the
	# cooldown does not run down either, so releasing the hold fires promptly
	# rather than after a leftover wait.
	if hold_fire:
		return
	_decay_nudge(delta)
	if _mechanic == MECHANIC_ORBIT:
		_process_orbit(delta)
		return
	# A live summon suspends the cooldown; the resummon clock starts only
	# after the general expires.
	if _mechanic == MECHANIC_SUMMON and _live_summon != null:
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	match _mechanic:
		MECHANIC_WARD:
			_place_ward()
		MECHANIC_SUMMON:
			_spawn_summon()
		MECHANIC_SHOCKWAVE:
			_pulse_shockwave()
		_:
			_fire()
	_cooldown_left = _cooldown


func _fire() -> void:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	var aim: Dictionary = _fallback_aim(positions)
	if _mechanic == MECHANIC_MELEE_ARC:
		_fire_arc(enemies, positions, aim["point"] as Vector2)
		return
	# N9-42: lightning strikes, it does not fly. A chain weapon resolves on the
	# enemy it aimed at with no travel, and the bolt is drawn from the caster.
	# With nothing to aim at there is nothing to strike — unlike a thrown
	# talisman, a bolt cannot be fired into empty space and hit later.
	var strike_now: Enemy = null
	if _mechanic == MECHANIC_CHAIN:
		if String(aim.get("kind", "")) != "enemy":
			return
		strike_now = enemies[int(aim.get("index", -1))]
	var direction: Vector2 = CombatMath.chase_direction(
		_player.global_position, aim["point"] as Vector2
	)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT  # target exactly on the player; any heading hits
	# N4-8 multishot: projectile mechanics fire projectile_count shots fanned
	# around the aim; count 1 keeps the exact single-shot behaviour.
	for shot_direction: Vector2 in WeaponMath.fan_directions(
		direction, int(_stats.get("projectile_count", 1)), deg_to_rad(_fan_spread_deg)
	):
		var projectile: Projectile = _pool.acquire()
		# _roll_damage sets _last_crit, so it must be evaluated before the
		# argument list reads it.
		var shot_damage: float = _roll_damage()
		projectile.launch(
			_player.global_position, shot_direction, _speed, shot_damage, _spawner,
			_player, _tint(), _view_margin, _shot_config, _last_crit, strike_now
		)


## 석장 (N4-4a): one swing centered on the aim point — everything whose body
## reaches into the arc takes damage and a boosted shove.
func _fire_arc(enemies: Array[Enemy], positions: Array[Vector2], aim_point: Vector2) -> void:
	var origin: Vector2 = _player.global_position
	var aim: float = (aim_point - origin).angle()
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
		var arc_damage: float = _roll_damage()
		enemy.take_damage(arc_damage, CombatMath.chase_direction(origin, hit_at), knockback)
		_after_hit(arc_damage)
		hit_landed.emit(arc_damage, hit_at, boss_hit, _last_crit)
	_arc_flash.flash(
		origin, aim, arc_rad, _range, _tint(), WeaponEffects.value("arc_sweep_sec")
	)
	# N5-5: the swing also smashes destructible props caught in the sector.
	var break_positions: Array[Vector2] = []
	var break_radii: Array[float] = []
	for breakable: Breakable in _spawner.breakables:
		break_positions.append(breakable.global_position)
		break_radii.append(breakable.hit_radius)
	for i: int in WeaponMath.arc_hits(
		origin, aim, arc_rad, _range, break_positions, break_radii
	):
		if _spawner.breakables[i].alive():
			_spawner.breakables[i].take_weapon_damage(_damage)


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
		var reach: float = enemy.contact_radius + _orb_radius
		for orb: Node2D in _orbs:
			if orb.global_position.distance_squared_to(enemy.global_position) <= reach * reach:
				_caught.append(enemy)
				break
	# N5-5: orbs grind destructible props too, on the same per-target re-hit
	# clock enemies use (_orb_recent keys are instance ids, shared namespace).
	for breakable: Breakable in _spawner.breakables:
		if not breakable.alive() \
				or float(_orb_recent.get(breakable.get_instance_id(), 0.0)) > _orbit_elapsed:
			continue
		var break_reach: float = breakable.hit_radius + _orb_radius
		for orb: Node2D in _orbs:
			if orb.global_position.distance_squared_to(breakable.global_position) \
					<= break_reach * break_reach:
				_orb_recent[breakable.get_instance_id()] = _orbit_elapsed + _cooldown
				breakable.take_weapon_damage(_damage)
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
		var orb_damage: float = _roll_damage()
		enemy.take_damage(orb_damage, CombatMath.chase_direction(_player.global_position, hit_at))
		_after_hit(orb_damage)
		# N9-34: reported the BASE damage while dealing the rolled one, so an
		# orbit crit hit for double and printed the ordinary number.
		hit_landed.emit(orb_damage, hit_at, boss_hit, _last_crit)


## 결계 (N4-4b): drop a pooled ward on the aim point — the same N6-4
## fallback chain every targeting weapon uses, so an empty view still plants
## the ward along the player's heading.
func _place_ward() -> void:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	var ward: Ward = _ward_pool.acquire()
	ward.arm(
		_fallback_aim(positions)["point"] as Vector2, _spawner, _ward,
		_damage, _stats.get("on_hit_status", {}), _tint(),
		_crit_chance, _crit_multiplier
	)


## 신장 (N4-4b): one general at a time, raised at the master's side.
func _spawn_summon() -> void:
	_live_summon = _summon_pool.acquire()
	_live_summon.arm(
		_player.global_position, _player, _spawner, _summon_config,
		_damage, _stats.get("on_hit_status", {}), _tint(),
		_crit_chance, _crit_multiplier
	)


## 진언 (N4-4b): a pulse around the player — damage is secondary, the point
## is the knockback + stun space. Pulses on the clock even with an empty
## field so the heartbeat stays readable.
func _pulse_shockwave() -> void:
	var origin: Vector2 = _player.global_position
	var radius: float = float(_shockwave.get("radius_px", 0.0))
	var stun_sec: float = float(_shockwave.get("stun_sec", 0.0))
	var knockback: float = float(_shockwave.get("knockback_scale", 1.0))
	var seal: Dictionary = _stats.get("on_hit_seal", {})
	var flash: BlastRing = _flash_pool.acquire()
	# N3-18: a control pulse is a clean double ring, not a detonation — enemies
	# inside the stun space stay readable.
	flash.burst(
		origin, radius, WeaponEffects.value("shockwave_ring_sec"), _tint(),
		BlastRing.Style.WAVE
	)
	_start_nudge()
	var enemies: Array[Enemy] = _spawner.active_enemies()
	_positions.clear()
	for enemy: Enemy in enemies:
		_positions.append(enemy.global_position)
	# Collect refs first: striking mutates the spawner's active list.
	_caught.clear()
	for i: int in WeaponMath.targets_in_radius(origin, _positions, radius):
		_caught.append(enemies[i])
	for enemy: Enemy in _caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		enemy.apply_stun(stun_sec)
		# N9-34: the shockwave used _damage directly, so 진언 was the one
		# mechanic that never crit — while still reporting a stale _last_crit
		# left over from another weapon's hit.
		var pulse_damage: float = _roll_damage()
		var burst: float = 0.0
		if not seal.is_empty() and enemy.apply_seal(int(seal.get("burst_at", 0))):
			burst = pulse_damage * float(seal.get("burst_damage_scale", 0.0))
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(
			pulse_damage + burst, CombatMath.chase_direction(origin, hit_at), knockback
		)
		_after_hit(pulse_damage)
		hit_landed.emit(pulse_damage, hit_at, boss_hit, _last_crit)
		if burst > 0.0:
			hit_landed.emit(burst, hit_at, boss_hit, false)
	# N5-5: the pulse cracks destructible props inside its radius as well.
	for breakable: Breakable in _spawner.breakables:
		if breakable.alive() and origin.distance_squared_to(breakable.global_position) \
				<= (radius + breakable.hit_radius) * (radius + breakable.hit_radius):
			breakable.take_weapon_damage(_damage)


## Shared N6-4 aim resolution: visible enemy in range → visible destructible
## → facing direction. Player position approximates the smoothed camera
## center, same tradeoff as the spawner (N3-4); facing falls back through
## last_move_direction so a standstill still fires toward the sprite's side.
func _fallback_aim(enemy_positions: Array[Vector2]) -> Dictionary:
	var view_size: Vector2 = get_viewport_rect().size
	var enemy_index: int = CombatMath.nearest_visible_index(
		_player.global_position, _player.global_position, view_size,
		_view_margin, enemy_positions, _range
	)
	if enemy_index >= 0:
		return {
			"kind": "enemy", "index": enemy_index,
			"point": enemy_positions[enemy_index],
		}
	# Only an empty view pays for the breakable sweep — with an enemy on
	# screen (the overwhelmingly common case) the scan above already answered.
	var break_positions: Array[Vector2] = []
	for breakable: Breakable in _spawner.breakables:
		if breakable.alive():
			break_positions.append(breakable.global_position)
	return CombatMath.fallback_aim(
		_player.global_position, _player.global_position, view_size,
		_view_margin, enemy_positions, break_positions, _range,
		_player.last_move_direction
	)


## 석장+귀철 (N4-4a): every landed point heals its lifesteal share, capped at
## the run's max HP.
func _after_hit(amount: float) -> void:
	if _lifesteal <= 0.0:
		return
	_player.hp = minf(_player.hp + amount * _lifesteal, _player.hp_max)


## Rebuild the orbit ring only when the orb count actually changes (N4-8
## milestone orb) — ordinary levels keep the same nodes and their trails.
func _sync_orbs(count: int) -> void:
	if _orbs.size() == maxi(count, 1):
		return
	for orb: Node2D in _orbs:
		orb.queue_free()
	_orbs.clear()
	_build_orbs(count)


func _build_orbs(count: int) -> void:
	for i: int in range(maxi(count, 1)):
		var orb := OrbVisual.new()
		orb.color = _tint()
		orb.radius = _orb_radius
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
	projectile.hit_landed.connect(_on_projectile_hit)
	projectile.exploded.connect(_on_projectile_exploded)
	projectile.chained.connect(_on_projectile_chained)
	projectile.finished.connect(_on_projectile_finished)
	return projectile


func _on_projectile_hit(amount: float, at: Vector2, boss_hit: bool, crit: bool) -> void:
	_after_hit(amount)
	# The mark is spawned by _mark_hit off this signal, not here: one place for
	# every attack shape, so a weapon added later cannot forget to show a hit.
	hit_landed.emit(amount, at, boss_hit, crit)


## One impact mark per reported hit. Rotated to face away from the caster, so
## the mark says where the blow came from rather than sitting flat.
##
## Capped: a ward ticking across a crowd of 130 reports dozens of hits a
## second, and an uncapped pool would carpet the screen in white and allocate
## a sprite for each. Past the ceiling the hit still lands, still counts, and
## still makes its number and its sound — it just does not add another mark to
## a place already covered in them.
func _mark_hit(_amount: float, at: Vector2, _boss_hit: bool, crit: bool) -> void:
	if _impact_pool == null or _live_marks >= MAX_LIVE_MARKS:
		return
	_live_marks += 1
	var sprite: EffectSprite = _impact_pool.acquire()
	sprite.play_effect(
		_impact_effect, at, 0.0,
		UiPalette.CRIT_TEXT if crit else Color.WHITE
	)
	# A crit already has its own number and sound; the bigger mark is what
	# makes it read when the eye is on the other side of the screen.
	sprite.scale *= CRIT_MARK_SCALE if crit else 1.0
	if _player != null:
		sprite.rotation = (at - _player.global_position).angle()


func _create_impact_sprite() -> EffectSprite:
	var sprite := EffectSprite.new()
	sprite.finished_effect.connect(
		func(done: EffectSprite) -> void:
			_live_marks = maxi(_live_marks - 1, 0)
			_impact_pool.release(done)
	)
	return sprite


func _on_projectile_exploded(at: Vector2, radius: float) -> void:
	# N3-18: back to the parametric blast — the sheet frames never filled their
	# square, so the sprite under-sold the true radius and its pack colors
	# fought the night palette. The code ring lands exactly on the data radius.
	if _flash_pool == null:
		return
	var flash: BlastRing = _flash_pool.acquire()
	flash.burst(at, radius, WeaponEffects.value("explosion_ring_sec"), _tint())


## 뇌부 (N3-17): the jump leg between two chained enemies gets its lightning.
func _on_projectile_chained(from: Vector2, to: Vector2) -> void:
	if _bolt_pool == null:
		return
	var bolt: ChainBolt = _bolt_pool.acquire()
	bolt.show_bolt(
		from, to, _tint(), WeaponEffects.value("chain_bolt_sec"),
		WeaponEffects.value("chain_bolt_jitter_px")
	)


## 진언 (N3-17): a brief screen thump matching the knockback beat — a zoom
## punch that pulls the view edges in by shockwave_nudge_px and recovers over
## shockwave_nudge_sec. Zoom-in only: a camera OFFSET would expose the strip
## beyond GroundLayer's tile window at the screen edge.
## ponytail: two live shockwave weapons would share camera.zoom; last writer
## wins for a frame — visually indistinguishable, per-weapon blend if it ever
## reads wrong.
func _start_nudge() -> void:
	_nudge_left = WeaponEffects.value("shockwave_nudge_sec")


## A mod swap can queue_free this weapon mid-punch; never leave the camera
## stuck off 1.0 zoom.
func _exit_tree() -> void:
	if _nudge_left <= 0.0:
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.zoom = Vector2.ONE


func _decay_nudge(delta: float) -> void:
	if _nudge_left <= 0.0:
		return
	_nudge_left = maxf(_nudge_left - delta, 0.0)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var nudge_sec: float = maxf(WeaponEffects.value("shockwave_nudge_sec"), 0.01)
	var punch: float = (
		WeaponEffects.value("shockwave_nudge_px") / maxf(get_viewport_rect().size.y, 1.0)
	)
	camera.zoom = Vector2.ONE * (1.0 + punch * (_nudge_left / nudge_sec))


func _create_ward() -> Ward:
	var ward := Ward.new()
	ward.ticked.connect(
		func(amount: float, at: Vector2, boss_hit: bool, crit: bool) -> void:
			_after_hit(amount)
			hit_landed.emit(amount, at, boss_hit, crit)
	)
	ward.finished.connect(
		func(done: Ward) -> void: _ward_pool.release(done)
	)
	return ward


func _create_summon() -> Summon:
	var summon := Summon.new()
	summon.struck.connect(
		func(amount: float, at: Vector2, boss_hit: bool, crit: bool) -> void:
			_after_hit(amount)
			hit_landed.emit(amount, at, boss_hit, crit)
	)
	summon.expired.connect(
		func(done: Summon) -> void:
			_live_summon = null
			_summon_pool.release(done)
	)
	return summon


func _create_blast_ring() -> BlastRing:
	var flash := BlastRing.new()
	flash.finished.connect(
		func(done: BlastRing) -> void: _flash_pool.release(done)
	)
	return flash


func _create_chain_bolt() -> ChainBolt:
	var bolt := ChainBolt.new()
	bolt.finished.connect(
		func(done: ChainBolt) -> void: _bolt_pool.release(done)
	)
	return bolt


func _on_projectile_finished(projectile: Projectile) -> void:
	_pool.release(projectile)


## 혼불 orb (N4-4a, reworked N3-18): a soul FLAME, not a fog moon — the N3-17
## pass drew a 2.1x glow halo over a 16px disc which read as a ~65px white
## blob smearing a comet tail. Now: tight glow capped at the true hit radius,
## a tapering three-lobe flame body, a white core, and a short thin trail.
## The trail ring buffer is pre-sized once; recording never allocates. Fade
## time from data (weapon_effects.orbit_trail_sec).
class OrbVisual:
	extends Node2D

	const TRAIL_CAPACITY := 6
	const GLOW_ALPHA := 0.22
	const TRAIL_ALPHA := 0.3
	const TRAIL_RADIUS_SCALE := 0.35
	## N9-5c: the orb body is the dokkaebi-fire wisp, authored in LUMINANCE so
	## `color` (soul blue / fire orange / grade tint) modulates the hue — which
	## is how 혼불 and 화령 혼불 share one texture and still read as different
	## flames. N9-38 replaced the single frame with the owner's 14-frame loop.
	## Visual height tracks the hit diameter.
	const WISP_TEXTURE := "res://asset/weapon/fx/honbul_wisp.png"
	const WISP_HEIGHT_SCALE := 2.6
	const WISP_FPS := 12.0

	var color: Color = UiPalette.WEAPON_SOUL
	var radius: float = AutoWeapon.ORB_RADIUS_PX

	var _trail := PackedVector2Array()
	var _ages := PackedFloat32Array()
	var _head: int = -1
	var _count: int = 0
	var _wisp: AnimatedSprite2D

	func _init() -> void:
		_trail.resize(TRAIL_CAPACITY)
		_ages.resize(TRAIL_CAPACITY)

	func _ready() -> void:
		_wisp = AnimatedSprite2D.new()
		_wisp.sprite_frames = SpriteSheet.loop_frames(WISP_TEXTURE, WISP_FPS)
		_wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_wisp.modulate = color
		var frame: Texture2D = _wisp.sprite_frames.get_frame_texture(
			SpriteSheet.ANIM_IDLE, 0
		)
		var height: float = maxf(frame.get_height() if frame != null else 1.0, 1.0)
		_wisp.scale = Vector2.ONE * (radius * WISP_HEIGHT_SCALE / height)
		# Orbs are built together, so start each at a different point in the
		# loop — otherwise every flame flickers in lockstep and reads as one
		# blinking object rather than several fires.
		_wisp.play()
		_wisp.frame = randi() % maxi(
			_wisp.sprite_frames.get_frame_count(SpriteSheet.ANIM_IDLE), 1
		)
		add_child(_wisp)

	## Parent AutoWeapon moves the orb in ITS _physics_process (parents run
	## before children), so recording here always sees this frame's position.
	func _physics_process(delta: float) -> void:
		for i: int in range(TRAIL_CAPACITY):
			_ages[i] += delta
		_head = (_head + 1) % TRAIL_CAPACITY
		_count = mini(_count + 1, TRAIL_CAPACITY)
		_trail[_head] = global_position
		_ages[_head] = 0.0
		queue_redraw()

	func _draw() -> void:
		var fade_sec: float = maxf(WeaponEffects.value("orbit_trail_sec"), 0.01)
		for step: int in range(1, _count):
			var index: int = (_head - step + TRAIL_CAPACITY) % TRAIL_CAPACITY
			var fade: float = 1.0 - clampf(_ages[index] / fade_sec, 0.0, 1.0)
			if fade <= 0.0:
				break  # entries only get older down the buffer
			draw_circle(
				to_local(_trail[index]),
				radius * TRAIL_RADIUS_SCALE * fade,
				Color(color, TRAIL_ALPHA * fade)
			)
		# Glow stops exactly at the data hit radius: what glows is what hits.
		# The wisp Sprite2D child carries the flame body (N9-5c).
		draw_circle(Vector2.ZERO, radius, Color(color, GLOW_ALPHA))


## 석장 swing (N3-17): an animated sweep — the leading edge travels across the
## swing arc over the flash time, dragging a fading wedge trail behind it, so
## the swing reads as motion instead of a static stamp. One swing is ever
## alive per weapon (cooldown >> flash), so a single reused instance replaces
## a pool. Sweep time comes from data (weapon_effects.arc_sweep_sec).
class ArcFlash:
	extends Node2D

	const EDGE_WIDTH := 6.0
	const TRAIL_WIDTH := 2.0
	const POINTS := 20
	const TRAIL_ALPHA := 0.28
	## The full sector sits under the swept one, fainter so the sweep still reads.
	const FULL_ALPHA := 0.16
	## The bright leading blade covers this slice of the full arc.
	const EDGE_SLICE := 0.22
	## N9-47: the leading blade is the pack crescent rather than a drawn slice.
	## It rides the sweep at the outer radius; the truthful sector underneath is
	## still what states coverage, so a fixed-shape sprite never has to.
	## Authored in luminance, like every other tinted effect here.
	const BLADE_TEXTURE := "res://asset/weapon/fx/arc_blade.png"
	const BLADE_FRAMES := 4
	## Blade height as a share of the swing radius.
	const BLADE_SCALE := 0.55

	var _aim: float = 0.0
	var _arc_rad: float = 0.0
	var _radius: float = 0.0
	var _color: Color = UiPalette.PAPER
	var _age: float = 0.0
	var _duration: float = 0.0

	static var _blade_frames: Array[AtlasTexture] = []

	## Cut once for the whole run: a strip of square-ish cells, same contract as
	## every other strip in the project (count is declared, cells are equal).
	static func _blades() -> Array[AtlasTexture]:
		if not _blade_frames.is_empty():
			return _blade_frames
		if not ResourceLoader.exists(BLADE_TEXTURE, "Texture2D"):
			return _blade_frames
		var sheet: Texture2D = load(BLADE_TEXTURE)
		if sheet == null:
			return _blade_frames
		var cell: float = sheet.get_size().x / float(BLADE_FRAMES)
		for i: int in range(BLADE_FRAMES):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
				Vector2(cell * float(i), 0.0), Vector2(cell, sheet.get_size().y)
			)
			_blade_frames.append(atlas)
		return _blade_frames

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
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_age += delta
		if _age >= _duration:
			visible = false
			return
		queue_redraw()

	## Pre-sized wedge scratch: POINTS arc samples + the origin. Refilled in
	## place every frame — drawing never allocates beyond the first frame.
	var _wedge := PackedVector2Array()
	## Second scratch buffer for the full-extent fan (see _draw).
	var _full := PackedVector2Array()

	func _draw() -> void:
		var progress: float = clampf(_age / _duration, 0.0, 1.0)
		var start: float = _aim - _arc_rad / 2.0
		# Ease-out sweep: the blade whips through most of the arc early.
		var eased: float = 1.0 - (1.0 - progress) * (1.0 - progress)
		var edge: float = start + _arc_rad * eased
		var fade: float = 1.0 - progress
		# N9-39: the WHOLE sector is drawn from frame one, fading out, because
		# the damage lands across the whole arc at frame one too. Sweeping the
		# fill open over arc_sweep_sec meant the instant of the hit showed a
		# thin sliver — the swing read as a torch beam rather than a 160-degree
		# swing (and it widens to 250 with milestones, which was invisible).
		# The sweeping blade below still supplies the motion.
		if _arc_rad > 0.0:
			if _full.size() != POINTS + 2:
				_full.resize(POINTS + 2)
			_full[0] = Vector2.ZERO
			for i: int in range(POINTS + 1):
				var full_angle: float = lerpf(start, start + _arc_rad, float(i) / float(POINTS))
				_full[i + 1] = Vector2.from_angle(full_angle) * _radius
			draw_colored_polygon(_full, Color(_color, FULL_ALPHA * fade))
			draw_arc(
				Vector2.ZERO, _radius, start, start + _arc_rad, POINTS,
				Color(_color, 0.5 * fade), TRAIL_WIDTH
			)
		# The brighter swept portion rides on top, so the eye still reads a
		# direction of travel across the sector.
		if edge > start:
			if _wedge.size() != POINTS + 2:
				_wedge.resize(POINTS + 2)
			_wedge[0] = Vector2.ZERO
			for i: int in range(POINTS + 1):
				var angle: float = lerpf(start, edge, float(i) / float(POINTS))
				_wedge[i + 1] = Vector2.from_angle(angle) * _radius
			draw_colored_polygon(_wedge, Color(_color, TRAIL_ALPHA * fade))
			draw_arc(
				Vector2.ZERO, _radius, start, edge, POINTS,
				Color(_color, 0.8 * fade), TRAIL_WIDTH
			)
		# N9-47: the drawn crescent rides the leading edge. Missing art falls
		# through to the slice below, so the swing never depends on the asset.
		var blades: Array[AtlasTexture] = _blades()
		if not blades.is_empty():
			var blade: AtlasTexture = blades[mini(
				int(progress * float(blades.size())), blades.size() - 1
			)]
			var blade_h: float = maxf(blade.get_size().y, 1.0)
			var scale: float = _radius * BLADE_SCALE / blade_h
			draw_set_transform(
				Vector2.from_angle(edge) * (_radius * 0.78), edge, Vector2.ONE * scale
			)
			draw_texture(
				blade, -blade.get_size() / 2.0, Color(_color, 0.85 * fade)
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		# Leading blade: a short, bright slice with a white-hot core riding the
		# outer rim — the moving staff head.
		var blade_from: float = maxf(edge - _arc_rad * EDGE_SLICE, start)
		draw_arc(
			Vector2.ZERO, _radius, blade_from, edge, POINTS,
			Color(UiPalette.PAPER, fade), EDGE_WIDTH
		)
		draw_arc(
			Vector2.ZERO, _radius, blade_from, edge, POINTS,
			Color(UiPalette.LOOT_CORE, 0.8 * fade), EDGE_WIDTH * 0.4
		)
