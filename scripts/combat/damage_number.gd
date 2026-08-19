class_name DamageNumber
extends Label
## Small white pixel damage number (N3-3, DESIGN.md §5.1) rising and fading
## over the hit enemy. Pooled by the stage; crit styling lands with crits.

signal finished(number: DamageNumber)

const FONT_SIZE := 12
const BOSS_FONT_SIZE := 18  # N5-1: boss hits read bigger and gold
## N9-34: a crit is the entire payoff of the grade axis, and it used to look
## exactly like an ordinary hit with a larger number. Bigger still, in the crit
## colour, and prefixed — never colour alone, since a number is a poor place to
## ask the player to compare hues mid-fight.
const CRIT_FONT_SIZE := 22
const CRIT_PREFIX := "★"
const CRIT_RISE_SCALE := 1.5
const OUTLINE_SIZE := 2
const RISE_SPEED := 30.0
const LIFETIME_SEC := 0.6
const RISE_OFFSET := Vector2(0.0, -14.0)  # start above the enemy's center

var _age: float = 0.0
## Crits rise faster so they separate from the ordinary numbers around them.
var _rise_scale: float = 1.0


func _ready() -> void:
	label_settings = LabelSettings.new()
	label_settings.font_size = FONT_SIZE
	label_settings.font_color = UiPalette.DAMAGE_TEXT
	label_settings.outline_size = OUTLINE_SIZE
	label_settings.outline_color = UiPalette.INK


func show_amount(
	amount: float, at: Vector2, boss_hit: bool = false, crit: bool = false
) -> void:
	# Pooled instances alternate targets, so restyle on every show.
	_rise_scale = CRIT_RISE_SCALE if crit else 1.0
	if crit:
		label_settings.font_size = CRIT_FONT_SIZE
		label_settings.font_color = UiPalette.CRIT_TEXT
		_present("%s%d" % [CRIT_PREFIX, int(round(amount))], at)
		return
	label_settings.font_size = BOSS_FONT_SIZE if boss_hit else FONT_SIZE
	label_settings.font_color = UiPalette.GOLD if boss_hit else UiPalette.DAMAGE_TEXT
	_present(str(int(round(amount))), at)


## N4-2: brief gold text callout in the same rise-and-fade style — used for
## the top-grade announcement, so no new toast system exists.
func show_text(message: String, at: Vector2) -> void:
	label_settings.font_size = BOSS_FONT_SIZE
	label_settings.font_color = UiPalette.GOLD
	_present(message, at)


func _present(message: String, at: Vector2) -> void:
	text = message
	_age = 0.0
	modulate.a = 1.0
	# Center the label on the hit point; size updates after text assignment.
	reset_size()
	position = at + RISE_OFFSET - size / 2.0


func _process(delta: float) -> void:
	_age += delta
	position.y -= RISE_SPEED * _rise_scale * delta
	modulate.a = 1.0 - _age / LIFETIME_SEC
	if _age >= LIFETIME_SEC:
		finished.emit(self)
