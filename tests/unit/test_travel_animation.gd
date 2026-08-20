extends RefCounted
## N9-80 flight animation: which cell a shot shows while it is in the air.
##
## The still case matters most. Every travel sprite shipped today is one frame,
## and a projectile that asked Sprite2D for cell 1 of a 1-cell texture would
## draw nothing — a shot that is invisible for its whole flight.

const WEAPONS_PATH := "res://data/weapons.json"


func test_a_single_frame_never_leaves_cell_zero() -> bool:
	return (
		Projectile.travel_frame(0.0, 1) == 0
		and Projectile.travel_frame(5.0, 1) == 0
		and Projectile.travel_frame(5.0, 0) == 0
		and Projectile.travel_frame(5.0, -3) == 0
	)


func test_frames_advance_at_the_declared_rate() -> bool:
	var step: float = 1.0 / Projectile.TRAVEL_FPS
	return (
		Projectile.travel_frame(0.0, 4) == 0
		and Projectile.travel_frame(step * 1.5, 4) == 1
		and Projectile.travel_frame(step * 2.5, 4) == 2
		and Projectile.travel_frame(step * 3.5, 4) == 3
	)


## A flight has no fixed length, so the cycle has to wrap rather than run off
## the end of the strip.
func test_a_long_flight_wraps_instead_of_running_off_the_strip() -> bool:
	var step: float = 1.0 / Projectile.TRAVEL_FPS
	return (
		Projectile.travel_frame(step * 4.5, 4) == 0
		and Projectile.travel_frame(step * 9.5, 4) == 1
		and Projectile.travel_frame(100.0, 4) < 4
	)


## Time cannot run backwards, but a pooled instance re-armed on the same frame
## can hand this a zero, and a negative would index outside the strip.
func test_negative_age_stays_on_the_first_cell() -> bool:
	return Projectile.travel_frame(-1.0, 4) == 0


## Every weapon that declares a strip must have a file its count actually
## divides — the same rule validate_data enforces, checked here so a bad export
## fails the suite too.
func test_declared_frame_counts_divide_their_sheets() -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	if raw is not Dictionary:
		push_error("test_travel_animation: cannot read " + WEAPONS_PATH)
		return false
	var passed: bool = true
	for weapon_id: String in (raw as Dictionary):
		if weapon_id.begins_with("_"):
			continue
		var weapon: Dictionary = (raw as Dictionary)[weapon_id]
		var frames: int = int(weapon.get("travel_frames", 1))
		if frames <= 1:
			continue
		var texture: Texture2D = load(String(weapon.get("travel_sprite", "")))
		if texture == null or int(texture.get_size().x) % frames != 0:
			push_error("test_travel_animation: %s frame count does not fit" % weapon_id)
			passed = false
	return passed
