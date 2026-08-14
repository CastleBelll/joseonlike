extends RefCounted
## SealStatus: stacks accumulate, burst exactly at the threshold, reset after
## bursting, and invalid thresholds stay inert.


func run() -> Array[String]:
	var failures: Array[String] = []
	var seal := SealStatus.new()

	if seal.apply(4) or seal.apply(4) or seal.apply(4):
		failures.append("burst before reaching the threshold")
	if not seal.apply(4):
		failures.append("no burst on the threshold-reaching mark")
	if seal.stacks != 0:
		failures.append("stacks did not reset after the burst (%d)" % seal.stacks)
	if seal.apply(4):
		failures.append("burst again immediately after the reset")

	var inert := SealStatus.new()
	if inert.apply(0) or inert.apply(-1):
		failures.append("a non-positive threshold must never burst")
	if inert.stacks != 0:
		failures.append("a non-positive threshold must not accumulate stacks")

	return failures
