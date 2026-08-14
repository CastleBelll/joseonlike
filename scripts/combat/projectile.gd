class_name Projectile
extends Node2D
## Pooled weapon projectile (N3-3, mechanics N4-4a). One class, one pool:
## straight flight plus the data-driven extras a shot config arms per launch —
## pierce (법검), impact explosion (화부), chain jumps (뇌부), on-hit status
## (burn/shock) and seal stacks. Finishes when its mechanic is spent or it
## leaves the visible view rect plus the shared targeting margin (N3-15).

signal hit_landed(amount: float, at: Vector2, boss_hit: bool)
## N4-4a: the impact splash happened — AutoWeapon shows the pooled ring flash.
signal exploded(at: Vector2, radius: float)
signal finished(projectile: Projectile)

const PAPER_SIZE := Vector2(6.0, 12.0)
## 법검/봉마검 placeholder: a longer, thinner blade of sword-qi (N4-4a).
const BLADE_SIZE := Vector2(4.0, 24.0)
const HIT_RADIUS := 4.0

var _velocity := Vector2.ZERO
var _damage: float = 0.0
var _view_margin: float = 0.0
var _spawner: Spawner
var _player: Player
var _paper: ColorRect
var _seal_mark: ColorRect
# N4-4a mechanic state, armed per launch from the AutoWeapon shot config.
var _pierce_left: int = 0
var _explosion_radius: float = 0.0
var _chain_jumps_left: int = 0
var _chain_falloff: float = 1.0
var _chain_range: float = 0.0
var _chain_target: Enemy
var _status: Dictionary = {}
var _seal: Dictionary = {}
# Enemies this shot already struck (instance id -> true) so pierce and chain
# never hit twice. A pooled instance re-armed mid-flight would be wrongly
# excluded, but flights last well under a second — accepted.
var _struck: Dictionary = {}
var _touched: Array[Enemy] = []  # per-frame scratch, reused without alloc


func _ready() -> void:
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.color = UiPalette.PAPER
	add_child(_paper)
	_seal_mark = ColorRect.new()
	_seal_mark.name = "Seal"
	_seal_mark.color = UiPalette.VERMILION
	_paper.add_child(_seal_mark)
	_apply_shape(PAPER_SIZE)


## `config` arms the N4-4a mechanics; an empty dict keeps the plain N3-3 shot:
## {"pierce": int, "explosion_radius": float, "chain": {jumps, falloff,
## range_px}, "status": Dictionary, "seal": Dictionary, "size": Vector2}.
func launch(from: Vector2, direction: Vector2, speed: float, damage: float,
		spawner: Spawner, player: Player, tint: Color = UiPalette.PAPER,
		view_margin: float = 0.0, config: Dictionary = {}) -> void:
	global_position = from
	_velocity = direction * speed
	# The talisman's long side leads the flight direction.
	rotation = direction.angle() + PI / 2.0
	_damage = damage
	_view_margin = view_margin
	_spawner = spawner
	_player = player
	# N4-1: modded weapons tint the paper so a transformation reads on field.
	_paper.color = tint
	_pierce_left = int(config.get("pierce", 0))
	_explosion_radius = float(config.get("explosion_radius", 0.0))
	var chain: Dictionary = config.get("chain", {})
	_chain_jumps_left = int(chain.get("jumps", 0))
	_chain_falloff = float(chain.get("falloff", 1.0))
	_chain_range = float(chain.get("range_px", 0.0))
	_chain_target = null
	_status = config.get("status", {})
	_seal = config.get("seal", {})
	_struck.clear()
	_apply_shape(config.get("size", PAPER_SIZE))


func _physics_process(delta: float) -> void:
	# A live chain leg re-aims every frame so the jump actually connects even
	# while the target keeps walking.
	if _chain_target != null and not CombatMath.is_dead(_chain_target.hp):
		var direction: Vector2 = CombatMath.chase_direction(
			global_position, _chain_target.global_position
		)
		if direction != Vector2.ZERO:
			_velocity = direction * _velocity.length()
			rotation = direction.angle() + PI / 2.0
	global_position += _velocity * delta
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
			_jump_chain(hit_at)
			return
		if _pierce_left > 0:
			_pierce_left -= 1
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
	var burst: float = 0.0
	if not _seal.is_empty() and enemy.apply_seal(int(_seal.get("burst_at", 0))):
		burst = damage * float(_seal.get("burst_damage_scale", 0.0))
	enemy.take_damage(damage + burst, _velocity.normalized())
	hit_landed.emit(damage, hit_at, boss_hit)
	if burst > 0.0:
		hit_landed.emit(burst, hit_at, boss_hit)


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
			_strike(enemy, _damage)


## 뇌부 (N4-4a): bounce to the nearest fresh enemy in chain range with the
## data falloff applied, or finish when the crowd runs out.
func _jump_chain(from: Vector2) -> void:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	var exclude: Array[int] = []
	for i: int in range(enemies.size()):
		positions.append(enemies[i].global_position)
		if _struck.has(enemies[i].get_instance_id()):
			exclude.append(i)
	var index: int = WeaponMath.chain_next_index(from, positions, exclude, _chain_range)
	if index < 0:
		finished.emit(self)
		return
	_chain_jumps_left -= 1
	_damage *= _chain_falloff
	_chain_target = enemies[index]
	var direction: Vector2 = CombatMath.chase_direction(from, positions[index])
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	_velocity = direction * _velocity.length()
	rotation = direction.angle() + PI / 2.0


func _apply_shape(size: Vector2) -> void:
	_paper.size = size
	_paper.position = -size / 2.0
	_seal_mark.size = size / 3.0
	_seal_mark.position = size / 2.0 - size / 6.0
