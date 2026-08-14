class_name CharacterMotion
extends RefCounted
## Deterministic, pixel-snapped character motion.
##
## There are no walk or attack frames and deliberately will not be: two
## same-pose generated renders differed by 449 of 1,702 pixels, so generated
## motion would flicker rather than animate (asset/M1_ASSET_REPORT.md). Instead
## one authored sprite per direction is offset by whole pixels on a fixed
## schedule. Everything here is integer -- no subpixel bobbing, no fractional
## scale, no rotation, which are what make pixel art read as wrong.
##
## Pure and autoload-free so the headless test runner can load it.

## Ordered to match atan2 buckets: index = round(angle / 45 degrees) mod 8.
const DIRECTION_NAMES: PackedStringArray = [
	"east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east",
]
const DEFAULT_DIRECTION: String = "south"

const IDLE_HZ: float = 2.0
const WALK_HZ: float = 8.0

## Idle breathes on y only; x never moves, so the silhouette stays put.
##
## Retuned after a player reported that standing still read as drifting. The old
## cycle ran at 4 Hz and sat lifted for two of its four frames, so the body was
## off its resting line half the time and changed every 250 ms -- a hover, not a
## breath. This holds the rest position for three frames of four and lifts once,
## and at 2 Hz the cycle is 2 s: 1.5 s at rest, a single 0.5 s lift. Amplitude
## stays at one pixel, which was already the minimum; what changed is rate and
## how much of the cycle is spent at rest. Walk is untouched -- that was the
## cycle that needed to be visible.
const IDLE_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, 0),
]

## Walk is a vertical hop: 0, -1, -2, -1 pixels, every frame moving.
##
## Measured, not guessed. The first version swung one pixel left/up/right and was
## invisible in play: at 90 px/s the hunter travels 11.25 px per walk frame, so a
## 1 px offset is 8.9% of the translation it rides on, and three of the four
## frames moved on the horizontal axis -- exactly the axis that translation
## masks. Vertical is the only axis nothing else is using, and 2 px is 4.3% of
## the 46 px sprite height rather than 2.2%. Still whole-pixel: the asset report
## banned subpixel offsets, fractional scale and rotation, not amplitude.
const WALK_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -1),
]

const FRAME_COUNT: int = 4
const DIRECTION_COUNT: int = 8

## Side-view facing (GDD v2 section 6): sprites face left or right only.
const FACING_RIGHT: int = 1
const FACING_LEFT: int = -1

## No cycle or recoil offset may exceed this on either axis. Two offsets that
## compose past it read as a glitch rather than as animation.
const MAX_OFFSET_PX: int = 2


## Nearest of the eight authored rotations for a movement vector. A zero vector
## has no direction to read, so it falls back rather than guessing.
static func direction_name(vector: Vector2) -> String:
	if vector.length_squared() == 0.0:
		return DEFAULT_DIRECTION
	var bucket: int = int(round(vector.angle() / (TAU / float(DIRECTION_COUNT))))
	return DIRECTION_NAMES[posmod(bucket, DIRECTION_COUNT)]


## Side-view facing for a movement vector: the horizontal component decides,
## and pure-vertical or zero movement keeps `current` so the sprite never
## snaps to a default mid-strafe (GDD v2 section 6).
static func facing_sign(vector: Vector2, current: int) -> int:
	if vector.x > 0.0:
		return FACING_RIGHT
	if vector.x < 0.0:
		return FACING_LEFT
	return current


## Which frame of a `hz`-rate cycle `elapsed_sec` lands on.
static func frame_index(elapsed_sec: float, hz: float) -> int:
	if elapsed_sec <= 0.0 or hz <= 0.0:
		return 0
	return int(floor(elapsed_sec * hz)) % FRAME_COUNT


static func idle_offset(elapsed_sec: float) -> Vector2i:
	return IDLE_OFFSETS[frame_index(elapsed_sec, IDLE_HZ)]


static func walk_offset(elapsed_sec: float) -> Vector2i:
	return WALK_OFFSETS[frame_index(elapsed_sec, WALK_HZ)]


## The single source of the sprite offset for a tick.
##
## Recoil REPLACES the cycle offset instead of adding to it. Composing them
## produced a 2-3 px jump on one tick, which reads as a glitch, and it also broke
## the promise that the recoil is one pixel.
static func sprite_offset(
	elapsed_sec: float,
	is_walking: bool,
	recoil: Vector2i,
	is_recoiling: bool
) -> Vector2i:
	if is_recoiling:
		return recoil
	return walk_offset(elapsed_sec) if is_walking else idle_offset(elapsed_sec)


## Whole-pixel recoil away from the aim direction, applied for a single tick.
static func recoil_offset(aim: Vector2) -> Vector2i:
	if aim.length_squared() == 0.0:
		return Vector2i.ZERO
	var away: Vector2 = -aim.normalized()
	return Vector2i(signi(int(round(away.x * 2.0))), signi(int(round(away.y * 2.0))))
