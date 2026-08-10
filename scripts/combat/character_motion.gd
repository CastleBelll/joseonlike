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

const IDLE_HZ: float = 4.0
const WALK_HZ: float = 8.0

## Idle breathes on y only; x never moves, so the silhouette stays put.
const IDLE_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, 0),
]

## Walk swings one pixel left, up, right, centre. The x sequence is mirrored on
## alternating steps so the two strides are not identical.
const WALK_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 0),
]

const FRAME_COUNT: int = 4
const DIRECTION_COUNT: int = 8


## Nearest of the eight authored rotations for a movement vector. A zero vector
## has no direction to read, so it falls back rather than guessing.
static func direction_name(vector: Vector2) -> String:
	if vector.length_squared() == 0.0:
		return DEFAULT_DIRECTION
	var bucket: int = int(round(vector.angle() / (TAU / float(DIRECTION_COUNT))))
	return DIRECTION_NAMES[posmod(bucket, DIRECTION_COUNT)]


## Which frame of a `hz`-rate cycle `elapsed_sec` lands on.
static func frame_index(elapsed_sec: float, hz: float) -> int:
	if elapsed_sec <= 0.0 or hz <= 0.0:
		return 0
	return int(floor(elapsed_sec * hz)) % FRAME_COUNT


## How many complete cycles have elapsed; walk uses its parity to mirror x.
static func step_index(elapsed_sec: float, hz: float) -> int:
	if elapsed_sec <= 0.0 or hz <= 0.0:
		return 0
	return int(floor(elapsed_sec * hz)) / FRAME_COUNT


static func idle_offset(elapsed_sec: float) -> Vector2i:
	return IDLE_OFFSETS[frame_index(elapsed_sec, IDLE_HZ)]


static func walk_offset(elapsed_sec: float) -> Vector2i:
	var offset: Vector2i = WALK_OFFSETS[frame_index(elapsed_sec, WALK_HZ)]
	if step_index(elapsed_sec, WALK_HZ) % 2 == 1:
		return Vector2i(-offset.x, offset.y)
	return offset


## Whole-pixel recoil away from the aim direction, applied for a single tick.
static func recoil_offset(aim: Vector2) -> Vector2i:
	if aim.length_squared() == 0.0:
		return Vector2i.ZERO
	var away: Vector2 = -aim.normalized()
	return Vector2i(signi(int(round(away.x * 2.0))), signi(int(round(away.y * 2.0))))
