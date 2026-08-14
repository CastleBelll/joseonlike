class_name SealStatus
extends RefCounted
## Pure seal-mark state (GDD v2 section 11, the taoist sealing line): every
## hit stacks a mark, and reaching the threshold bursts and resets. Autoload-
## free (see CombatMath) so the headless runner tests the arithmetic directly;
## the enemy owns applying the burst damage.

var stacks: int = 0


## Adds one mark. Returns true when the threshold is reached — the burst —
## and resets the count so the next mark starts a fresh cycle.
func apply(burst_at: int) -> bool:
	if burst_at <= 0:
		return false
	stacks += 1
	if stacks < burst_at:
		return false
	stacks = 0
	return true
