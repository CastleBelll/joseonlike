class_name LootDrops
extends RefCounted
## Pure loot-roll logic for monster drop tables (data/drop_tables.json).
##
## Autoload-free and side-effect-free (see CombatMath) so the headless runner
## can test the probabilities without a scene tree. The caller owns the RNG:
## combat passes a CombatRng stream so a seeded run reproduces its drops.

## GDD v2 section 29: tier is communicated by colour plus icon, never colour
## alone. Until authored loot art lands these tints drive the placeholder
## swatches, and they stay the tier accent colours afterwards.
const TIER_TINTS: Dictionary = {
	"common": Color(0.92, 0.92, 0.92),
	"uncommon": Color(0.36, 0.85, 0.42),
	"rare": Color(0.32, 0.56, 0.95),
	"epic": Color(0.66, 0.38, 0.92),
	"legendary": Color(0.98, 0.78, 0.25),
	"mythic": Color(0.94, 0.30, 0.30),
}
const FALLBACK_TINT := Color(0.92, 0.92, 0.92)

const KEY_DROPS := "drops"
const KEY_LOOT_ID := "loot_id"
const KEY_CHANCE := "chance"


## Rolls every entry of a monster's drop table independently and returns the
## loot ids that dropped. {} (a monster with no table) rolls nothing.
## `luck_bonus` scales every chance fractionally (0.25 == +25%), so the luck
## passive is a real loot stat rather than a dead key.
static func roll(drop_table: Dictionary, rng: RandomNumberGenerator, luck_bonus: float = 0.0) -> Array[String]:
	var dropped: Array[String] = []
	var drops: Variant = drop_table.get(KEY_DROPS)
	if not (drops is Array):
		return dropped

	for entry: Variant in (drops as Array):
		if not (entry is Dictionary):
			continue
		var drop: Dictionary = entry
		var loot_id: String = String(drop.get(KEY_LOOT_ID, ""))
		if loot_id.is_empty():
			continue
		var chance: float = float(drop.get(KEY_CHANCE, 0.0)) * (1.0 + maxf(luck_bonus, 0.0))
		if chance <= 0.0:
			continue
		# randf() < 1.0 can miss on the boundary, so a guaranteed drop short-circuits.
		if chance >= 1.0 or rng.randf() < chance:
			dropped.append(loot_id)

	return dropped


static func tier_tint(tier: String) -> Color:
	var tint: Variant = TIER_TINTS.get(tier)
	return tint if tint is Color else FALLBACK_TINT
