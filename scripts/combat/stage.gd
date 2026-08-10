class_name Stage
extends Node2D
## Owns one run: the clock, the player, the spawner, the boss, XP collection and
## the run-ended verdict.
##
## Everything leaves this node through EventBus, so UI and meta progression can
## observe a run without either side holding a reference to the other.

const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player.tscn")
const PROJECTILE_ROOT_GROUP: StringName = &"projectile_root"

const KEY_VICTORY: String = "victory"
const KEY_TIME_SEC: String = "time_sec"
const KEY_KILLS: String = "kills"
const KEY_GOLD: String = "gold"
const KEY_XP_DROP: String = "xp_drop"
const KEY_GOLD_DROP: String = "gold_drop"

## Used when the scene is played directly instead of through SceneRouter.
@export var stage_id_override: String = ""

var stage_id: String = ""
var elapsed_sec: float = 0.0
var gold: int = 0

var _stage_data: Dictionary = {}
var _is_choice_open: bool = false
var _has_ended: bool = false

@onready var _actors: Node2D = $Actors
@onready var _pickups: Node2D = $Pickups
@onready var _projectiles: Node2D = $Projectiles
@onready var _ground: StageGround = $Ground
@onready var _audio: CombatAudio = $CombatAudio
@onready var _spawner: Spawner = $Spawner
@onready var _boss: BossController = $BossController


func _ready() -> void:
	# The stage must keep ticking while the tree is paused for a level-up choice,
	# otherwise nothing is left running to unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_projectiles.add_to_group(PROJECTILE_ROOT_GROUP)

	_stage_data = _load_stage()
	_ground.setup(stage_id)
	_audio.start_ambience()
	_spawn_player()
	_spawner.configure(_stage_data)
	_boss.configure(_stage_data, _spawner)

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.level_reached.connect(_on_level_reached)
	EventBus.upgrade_chosen.connect(_on_upgrade_chosen)


func _process(delta: float) -> void:
	if _has_ended or _is_choice_open:
		return
	elapsed_sec += delta
	RunState.elapsed_sec = elapsed_sec
	_spawner.advance_to(elapsed_sec)
	_boss.advance_to(elapsed_sec)


func is_choice_open() -> bool:
	return _is_choice_open


func has_ended() -> bool:
	return _has_ended


func _load_stage() -> Dictionary:
	stage_id = stage_id_override if not stage_id_override.is_empty() else RunState.stage_id
	if stage_id.is_empty():
		push_error("Stage: no stage id in RunState and no override set")
		return {}
	var data: Dictionary = GameData.stage(stage_id)
	if data.is_empty():
		push_error("Stage: no data for stage '%s'" % stage_id)
	return data


func _spawn_player() -> void:
	var player: Node2D = PLAYER_SCENE.instantiate() as Node2D
	player.global_position = _viewport_centre()
	_actors.add_child(player)


func _viewport_centre() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size * 0.5


## RunState.kills is the authoritative counter: the HUD reads it live and the
## results payload reads it back, so combat must not keep a private tally.
func _on_enemy_killed(monster_id: String, position: Vector2) -> void:
	RunState.kills += 1
	var data: Dictionary = GameData.monster(monster_id)
	gold += maxi(int(data.get(KEY_GOLD_DROP, 0)), 0)
	_drop_xp(maxi(int(data.get(KEY_XP_DROP, 0)), 0), position)


func _drop_xp(amount: int, position: Vector2) -> void:
	if amount <= 0:
		return
	var orb := XpPickup.new()
	orb.collected.connect(_on_xp_collected)
	_pickups.add_child(orb)
	orb.setup(amount, position)


func _on_xp_collected(amount: int) -> void:
	RunState.add_xp(amount)


## A level-up choice freezes the field. The choice UI lives in meta-ui and only
## has to emit upgrade_chosen to hand control back.
func _on_level_reached(_level: int, _choices: Array[Dictionary]) -> void:
	if _has_ended:
		return
	_is_choice_open = true
	get_tree().paused = true


func _on_upgrade_chosen(_choice_id: String) -> void:
	if not _is_choice_open:
		return
	_is_choice_open = false
	get_tree().paused = false


func _on_player_died() -> void:
	_end_run(false)


func _on_boss_defeated(_boss_id: String) -> void:
	_end_run(true)


func _end_run(victory: bool) -> void:
	if _has_ended:
		return
	_has_ended = true
	_is_choice_open = false
	get_tree().paused = false
	_spawner.release_all()
	_audio.stop_ambience()
	var result: Dictionary = {
		KEY_VICTORY: victory,
		KEY_TIME_SEC: elapsed_sec,
		KEY_KILLS: RunState.kills,
		KEY_GOLD: gold,
	}
	EventBus.run_ended.emit(result)
	# Nothing else listens for run_ended to close the loop, and the results
	# screen reads its payload from SceneRouter, so the stage routes itself out.
	SceneRouter.goto_results(result)
