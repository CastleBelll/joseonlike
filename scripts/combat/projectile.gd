class_name Projectile
extends Node2D
## Straight-line talisman projectile (N3-3). Pooled by AutoWeapon; finishes
## on first enemy hit or on leaving the visible view rect plus the shared
## targeting margin (N3-15) — it never chases anything off-screen.
## ponytail: no pierce yet — old_talisman has pierce 0; add when a pierced
## weapon becomes obtainable in a run.

signal hit_landed(amount: float, at: Vector2, boss_hit: bool)
signal finished(projectile: Projectile)

const PAPER_SIZE := Vector2(6.0, 12.0)
const HIT_RADIUS := 4.0

var _velocity := Vector2.ZERO
var _damage: float = 0.0
var _view_margin: float = 0.0
var _spawner: Spawner
var _player: Player
var _paper: ColorRect


func _ready() -> void:
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.color = UiPalette.PAPER
	_paper.size = PAPER_SIZE
	_paper.position = -PAPER_SIZE / 2.0
	add_child(_paper)
	var seal := ColorRect.new()
	seal.name = "Seal"
	seal.color = UiPalette.VERMILION
	seal.size = PAPER_SIZE / 3.0
	seal.position = -PAPER_SIZE / 6.0
	_paper.add_child(seal)


func launch(from: Vector2, direction: Vector2, speed: float, damage: float,
		spawner: Spawner, player: Player, tint: Color = UiPalette.PAPER,
		view_margin: float = 0.0) -> void:
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


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	for enemy: Enemy in _spawner.active_enemies():
		var reach: float = enemy.contact_radius + HIT_RADIUS
		if global_position.distance_squared_to(enemy.global_position) > reach * reach:
			continue
		# Capture before take_damage: a killing hit releases the enemy to its
		# pool synchronously, and the number must rise where the hit landed.
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(_damage, _velocity.normalized())
		hit_landed.emit(_damage, hit_at, boss_hit)
		finished.emit(self)
		return
	# Player position approximates the smoothed camera center, same tradeoff
	# as the spawner (N3-4).
	var gone: bool = CombatMath.outside_view(
		global_position, _player.global_position, get_viewport_rect().size, _view_margin
	)
	if gone:
		finished.emit(self)
