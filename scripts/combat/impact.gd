class_name Impact
extends RefCounted
## Hit feel (N9-67): hitstop and screen shake. Pure and node-free, so the two
## effects that are hardest to judge by eye can be judged by number instead.
##
## Owner direction: this is a roguelike, so impact matters more than anything
## decorative. The two things missing were the two that carry it — a frame of
## freeze on a hit that counted, and a camera that flinches.
##
## Both are RATIONED, and that is the whole design. A bullet-heaven lands
## dozens of hits a second; a freeze on every one of them is not impact, it is
## a slideshow, and shake that accumulates without a ceiling is nausea. So
## hitstop fires only on events that are rare and meaningful, never on an
## ordinary hit, and both are clamped.

## Event kinds, in rising order of weight.
const HIT := "hit"
const CRIT := "crit"
const KILL := "kill"
const ELITE_KILL := "elite_kill"
const BOSS_HIT := "boss_hit"
const ERUPT := "erupt"
const NUKE := "nuke"


## Seconds to freeze for `kind`, from the data block. Zero means this kind does
## not stop the world — which is the answer for an ordinary hit, however many
## of them land.
static func hitstop_sec(config: Dictionary, kind: String) -> float:
	return maxf(float((config.get("hitstop", {}) as Dictionary).get(kind, 0.0)), 0.0)


## Shake to ADD for `kind`, before the ceiling. Separate from hitstop because
## the two do not always belong together: a kill shakes without freezing, and
## a boss eruption does both.
static func shake_amount(config: Dictionary, kind: String) -> float:
	return maxf(float((config.get("shake", {}) as Dictionary).get(kind, 0.0)), 0.0)


## Adds `amount` to the shake already running and clamps it. The ceiling is
## what keeps a surge from turning the screen into a blender — without it,
## twenty simultaneous kills would sum into something unplayable.
static func added_shake(current: float, amount: float, config: Dictionary) -> float:
	var ceiling: float = float((config.get("shake", {}) as Dictionary).get("max", 0.0))
	return clampf(current + amount, 0.0, maxf(ceiling, 0.0))


## Shake left after `delta`. Linear decay: an exponential tail leaves a tiny
## tremor running for seconds, which reads as a loose camera rather than as a
## hit.
static func decayed_shake(current: float, delta: float, config: Dictionary) -> float:
	var rate: float = float(
		(config.get("shake", {}) as Dictionary).get("decay_per_sec", 0.0)
	)
	return maxf(current - maxf(rate, 0.0) * delta, 0.0)


## Camera offset for the current shake. The two axes use different frequencies
## so the motion is a jitter rather than a diagonal slide, and `scale` is the
## player's own setting — shake is the one effect people genuinely cannot
## tolerate, so it has to be turnable-down.
static func shake_offset(amount: float, time_sec: float, scale: float) -> Vector2:
	var strength: float = maxf(amount, 0.0) * clampf(scale, 0.0, 1.0)
	if strength <= 0.0:
		return Vector2.ZERO
	return Vector2(
		sin(time_sec * 71.0) * strength,
		sin(time_sec * 53.0 + 1.7) * strength
	)


## Data contract for validate_data. The rules are all about ceilings: a single
## hitstop long enough to read as a hang, or a shake ceiling high enough to
## throw the field off screen, is a bug that only shows up in play.
static func data_issues(config: Dictionary, label: String) -> Array[String]:
	var issues: Array[String] = []
	var hitstop: Dictionary = config.get("hitstop", {})
	if hitstop.is_empty():
		issues.append(label + ".hitstop block missing")
	for kind: String in hitstop:
		var seconds: float = float(hitstop[kind])
		if seconds < 0.0:
			issues.append("%s.hitstop.%s cannot be negative" % [label, kind])
		elif seconds > 0.2:
			issues.append("%s.hitstop.%s is long enough to read as a hang" % [label, kind])
	# An ordinary hit must never freeze the world: they arrive dozens per
	# second, and the sum of them is the frame rate.
	if float(hitstop.get(HIT, 0.0)) > 0.0:
		issues.append(label + ".hitstop.hit must be zero — ordinary hits are constant")
	var shake: Dictionary = config.get("shake", {})
	if shake.is_empty():
		issues.append(label + ".shake block missing")
		return issues
	var ceiling: float = float(shake.get("max", 0.0))
	if ceiling <= 0.0:
		issues.append(label + ".shake.max must be positive")
	elif ceiling > 24.0:
		issues.append(label + ".shake.max is large enough to throw the field off screen")
	if float(shake.get("decay_per_sec", 0.0)) <= 0.0:
		issues.append(label + ".shake.decay_per_sec must be positive or shake never ends")
	for kind: String in shake:
		if kind == "max" or kind == "decay_per_sec":
			continue
		if float(shake[kind]) < 0.0:
			issues.append("%s.shake.%s cannot be negative" % [label, kind])
	return issues
