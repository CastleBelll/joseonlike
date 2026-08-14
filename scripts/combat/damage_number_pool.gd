class_name DamageNumberPool
extends Node2D
## Floating damage numbers: pooled labels that rise and fade above the hit.
##
## Same pooling discipline as EffectPool/DropPool — a 200-hit wave allocating
## a Label per hit is where the frame rate goes. When every slot is busy the
## oldest number is recycled early rather than allocating: the newest hit is
## the one the player is watching.

const MAX_CONCURRENT: int = 64
const LIFETIME_SEC: float = 0.6
const RISE_PX: float = 24.0
const NUMBER_Z_INDEX: int = 30

const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0)
const CRIT_COLOR: Color = Color(1.0, 0.82, 0.25)
const NORMAL_FONT_SIZE: int = 14
const CRIT_FONT_SIZE: int = 20
const OUTLINE_SIZE: int = 3
const OUTLINE_COLOR: Color = Color(0.1, 0.09, 0.07)

## Spread so simultaneous hits on one enemy do not stack into one glyph.
const JITTER_PX: float = 8.0

static var _instance: DamageNumberPool = null

var _idle: Array[Label] = []
var _active: Array[Dictionary] = []
var _rng: RandomNumberGenerator = CombatRng.create()


func _ready() -> void:
	for index in MAX_CONCURRENT:
		var label := Label.new()
		label.name = "Damage%d" % index
		label.visible = false
		label.z_index = NUMBER_Z_INDEX
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		add_child(label)
		_idle.append(label)
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


static func spawn(amount: float, is_crit: bool, world_position: Vector2) -> void:
	if _instance == null or amount <= 0.0:
		return
	_instance._spawn(amount, is_crit, world_position)


func _spawn(amount: float, is_crit: bool, world_position: Vector2) -> void:
	if _idle.is_empty():
		_release(0)
	var label: Label = _idle.pop_back()
	label.text = str(int(round(amount)))
	label.add_theme_color_override("font_color", CRIT_COLOR if is_crit else NORMAL_COLOR)
	label.add_theme_font_size_override("font_size", CRIT_FONT_SIZE if is_crit else NORMAL_FONT_SIZE)
	label.global_position = world_position + Vector2(
		_rng.randf_range(-JITTER_PX, JITTER_PX), -_rng.randf_range(0.0, JITTER_PX)
	)
	label.modulate = Color.WHITE
	label.visible = true
	_active.append({"label": label, "age": 0.0, "start_y": label.global_position.y})


func _process(delta: float) -> void:
	for index in range(_active.size() - 1, -1, -1):
		var entry: Dictionary = _active[index]
		var age: float = float(entry["age"]) + delta
		entry["age"] = age
		if age >= LIFETIME_SEC:
			_release(index)
			continue
		var progress: float = age / LIFETIME_SEC
		var label: Label = entry["label"]
		label.global_position.y = float(entry["start_y"]) - RISE_PX * progress
		label.modulate.a = 1.0 - progress


func _release(index: int) -> void:
	var label: Label = _active[index]["label"]
	label.visible = false
	_idle.append(label)
	_active.remove_at(index)
