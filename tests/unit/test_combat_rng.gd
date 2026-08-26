extends RefCounted
## Guards C6's combat stream (CombatRng): a run seed decides every crit, and
## nothing decorative can shift it. Crits used to come off the global `randf()`
## that effects, sprite frames and orb phases also draw from, so what had been
## rendered before a weapon fired decided where the crits landed.

const EPSILON := 0.0001
const SAMPLE := 32


func _rolls(seed_value: int, count: int) -> Array[float]:
	CombatRng.seed_run(seed_value)
	var out: Array[float] = []
	for _i: int in range(count):
		out.append(CombatRng.roll())
	return out


func test_one_seed_replays_the_same_rolls() -> bool:
	var first: Array[float] = _rolls(7, SAMPLE)
	var second: Array[float] = _rolls(7, SAMPLE)
	for i: int in range(SAMPLE):
		if absf(first[i] - second[i]) > EPSILON:
			return false
	return true


func test_a_different_seed_gives_a_different_stream() -> bool:
	var first: Array[float] = _rolls(7, SAMPLE)
	var other: Array[float] = _rolls(8, SAMPLE)
	for i: int in range(SAMPLE):
		if absf(first[i] - other[i]) > EPSILON:
			return true
	return false


func test_the_global_stream_cannot_shift_the_combat_stream() -> bool:
	var clean: Array[float] = _rolls(7, SAMPLE)
	CombatRng.seed_run(7)
	var drawn: Array[float] = []
	for i: int in range(SAMPLE):
		# Stand in for the cosmetic draws that share the global generator.
		for _j: int in range(i % 3 + 1):
			randf()
		drawn.append(CombatRng.roll())
	for i: int in range(SAMPLE):
		if absf(clean[i] - drawn[i]) > EPSILON:
			return false
	return true


func test_a_zero_chance_never_consumes_the_stream() -> bool:
	# A weapon with no crit stat must not shift where every later crit lands.
	CombatRng.seed_run(7)
	var expected: float = CombatRng.roll()
	CombatRng.seed_run(7)
	for _i: int in range(8):
		if CombatRng.hits(0.0):
			return false
	return absf(CombatRng.roll() - expected) <= EPSILON


func test_a_certain_chance_always_hits() -> bool:
	CombatRng.seed_run(7)
	for _i: int in range(SAMPLE):
		if not CombatRng.hits(1.0):
			return false
	return true
