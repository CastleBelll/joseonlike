class_name Bestiary
extends RefCounted
## Pure 괴이록 discovery-record logic (N5-4, GDD §18/§31): the permanent
## profile record of what the player has seen, the data-derived rosters each
## section counts against, and the view-model rows the screen renders.
## Loot and builds vanish at run end — this record and the gold are what
## remain, so a first sighting persists the moment it happens and survives
## death. BestiaryScreen owns the nodes; tests/unit/test_bestiary.gd covers
## every rule here.

const KIND_MONSTERS := "monsters"
const KIND_LOOT := "loot"
const KIND_WEAPONS := "weapons"
const KINDS: Array[String] = [KIND_MONSTERS, KIND_LOOT, KIND_WEAPONS]

const UNKNOWN_NAME := "???"

## One-line mechanic descriptions per LevelUp.SUPPORTED_MECHANICS — the
## bestiary tells the player what a weapon DOES, never its raw stats.
const MECHANIC_LINES := {
	"straight": {"ko": "적을 향해 곧게 날아간다", "en": "Flies straight at the nearest foe"},
	"pierce": {"ko": "적을 꿰뚫고 계속 나아간다", "en": "Pierces through enemies in a line"},
	"explosion": {"ko": "명중한 곳에서 폭발해 주변을 태운다", "en": "Explodes where it lands"},
	"chain": {"ko": "번개가 적에서 적으로 연쇄한다", "en": "Lightning chains from foe to foe"},
	"melee_arc": {"ko": "가까운 전방을 크게 휩쓴다", "en": "Sweeps a wide arc up close"},
	"orbit": {"ko": "주위를 맴돌며 닿는 적을 태운다", "en": "Orbits the caster, searing on touch"},
	"ward": {"ko": "장판을 펼쳐 안의 적을 태우고 늦춘다", "en": "Lays a field that burns and slows"},
	"summon": {"ko": "스스로 싸우는 신장을 부린다", "en": "Calls a guardian that fights on its own"},
	"shockwave": {"ko": "주기적인 파동으로 적을 밀쳐낸다", "en": "Periodic waves knock foes back"},
	"curse": {"ko": "죽음이 옆으로 번지는 저주를 건다", "en": "A curse that spreads on death"},
}

const TIER_LABELS := {
	"common": {"ko": "일반", "en": "Common"},
	"uncommon": {"ko": "고급", "en": "Uncommon"},
	"rare": {"ko": "희귀", "en": "Rare"},
	"epic": {"ko": "영웅", "en": "Epic"},
	"mythic": {"ko": "신화", "en": "Mythic"},
}


const VIEWED_KEY := "viewed"


static func default_record() -> Dictionary:
	return {
		KIND_MONSTERS: [], KIND_LOOT: [], KIND_WEAPONS: [], "unseen": 0,
		VIEWED_KEY: {KIND_MONSTERS: [], KIND_LOOT: [], KIND_WEAPONS: []},
	}


## Coerces any payload (JSON round-trip, hand-edited file) into the record
## shape: deduped string id lists and a non-negative unseen counter. Garbage
## in, empty record out — never a crash.
static func normalized_record(raw: Variant) -> Dictionary:
	var record: Dictionary = default_record()
	var source_dict: Dictionary = raw if raw is Dictionary else {}
	for kind: String in KINDS:
		# Always assign the typed list, even for a missing/garbage section, so
		# every consumer can rely on Array[String] elements downstream.
		var ids: Array[String] = []
		var source: Variant = source_dict.get(kind)
		if source is Array:
			for entry: Variant in source as Array:
				var id: String = String(entry)
				if not id.is_empty() and not ids.has(id):
					ids.append(id)
		record[kind] = ids
	record["unseen"] = maxi(int(source_dict.get("unseen", 0)), 0)
	# N9-11 NEW badge: per-kind viewed lists, same garbage-proof coercion.
	var viewed_source: Variant = source_dict.get(VIEWED_KEY)
	var viewed_dict: Dictionary = viewed_source if viewed_source is Dictionary else {}
	var viewed: Dictionary = record[VIEWED_KEY]
	for kind: String in KINDS:
		var ids: Array[String] = []
		var source: Variant = viewed_dict.get(kind)
		if source is Array:
			for entry: Variant in source as Array:
				var id: String = String(entry)
				if not id.is_empty() and not ids.has(id):
					ids.append(id)
		viewed[kind] = ids
	return record


## Folds one sighting into the profile. Idempotent and order-independent:
## the first sighting returns a NEW profile with the id appended and the
## camp hint counter bumped; every repeat returns the input untouched with
## new=false so the caller skips the disk write. The input is never mutated.
static func record_discovery(profile: Dictionary, kind: String, id: String) -> Dictionary:
	if kind not in KINDS or id.is_empty():
		return {"profile": profile, "new": false}
	var record: Dictionary = normalized_record(profile.get("bestiary"))
	if (record[kind] as Array).has(id):
		return {"profile": profile, "new": false}
	var next: Dictionary = profile.duplicate(true)
	(record[kind] as Array).append(id)
	record["unseen"] = int(record["unseen"]) + 1
	next["bestiary"] = record
	return {"profile": next, "new": true}


## N9-11 NEW badge: folds a batch of ids into the kind's viewed list.
## Pure and idempotent — changed=false means every id was already viewed
## and the caller skips the disk write.
static func mark_viewed(profile: Dictionary, kind: String, ids: Array) -> Dictionary:
	if kind not in KINDS or ids.is_empty():
		return {"profile": profile, "changed": false}
	var record: Dictionary = normalized_record(profile.get("bestiary"))
	var viewed: Array = (record[VIEWED_KEY] as Dictionary)[kind]
	var changed: bool = false
	for entry: Variant in ids:
		var id: String = String(entry)
		if not id.is_empty() and not viewed.has(id):
			viewed.append(id)
			changed = true
	if not changed:
		return {"profile": profile, "changed": false}
	var next: Dictionary = profile.duplicate(true)
	next["bestiary"] = record
	return {"profile": next, "changed": true}


## An entry is NEW while discovered but never rendered in its tab.
static func is_new(record: Dictionary, kind: String, id: String) -> bool:
	var clean: Dictionary = normalized_record(record)
	return (clean[kind] as Array).has(id) \
		and not ((clean[VIEWED_KEY] as Dictionary)[kind] as Array).has(id)


## Opening the 괴이록 retires the camp hint; changed=false means no write.
static func mark_seen(profile: Dictionary) -> Dictionary:
	var record: Dictionary = normalized_record(profile.get("bestiary"))
	if int(record["unseen"]) == 0:
		return {"profile": profile, "changed": false}
	var next: Dictionary = profile.duplicate(true)
	record["unseen"] = 0
	next["bestiary"] = record
	return {"profile": next, "changed": true}


static func unseen_count(profile: Dictionary) -> int:
	return int(normalized_record(profile.get("bestiary"))["unseen"])


## Camp's one-line new-discoveries hint; "" when there is nothing unseen.
static func camp_hint(profile: Dictionary) -> String:
	var unseen: int = unseen_count(profile)
	if unseen == 0:
		return ""
	return UiLocale.text("bestiary.camp_hint_fmt") % unseen


## Drops recorded ids that no longer exist in data (a removed weapon or
## monster): render from the cleaned record, warn once via dropped, never
## crash. valid_ids maps each kind to the data id list it must exist in.
static func prune_record(record: Dictionary, valid_ids: Dictionary) -> Dictionary:
	var clean: Dictionary = normalized_record(record)
	var dropped: int = 0
	for kind: String in KINDS:
		var kept: Array[String] = []
		for id: String in clean[kind] as Array[String]:
			if (valid_ids.get(kind, []) as Array).has(id):
				kept.append(id)
			else:
				dropped += 1
		clean[kind] = kept
	return {"record": clean, "dropped": dropped}


## The monster roster the 몬스터 section counts against: every monster that
## actually spawns somewhere — wave entries in encounter order, then the
## stage boss. Derived from data on every open, so a new wave monster shows
## up as a ??? row automatically; a monsters.json entry no stage spawns is
## unreachable and deliberately stays out of the count.
static func monster_roster(stages: Dictionary, monsters: Dictionary) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	var listed: Array[String] = []
	for stage_id: String in stages:
		var stage: Dictionary = stages[stage_id]
		var ids: Array[String] = []
		for wave: Variant in stage.get("waves", []):
			ids.append(String((wave as Dictionary).get("monster_id", "")))
		ids.append(String(stage.get("boss_id", "")))
		for monster_id: String in ids:
			if monster_id.is_empty() or listed.has(monster_id) \
					or not monsters.has(monster_id):
				continue
			listed.append(monster_id)
			roster.append({
				"id": monster_id,
				"stage_id": stage_id,
				"boss": monster_id == String(stage.get("boss_id", "")),
			})
	return roster


static func loot_roster(loot: Dictionary) -> Array[String]:
	var roster: Array[String] = []
	for loot_id: String in loot:
		roster.append(loot_id)
	return roster


## Weapons a run can actually own: every non-evolution weapon the runtime
## can fire, plus the closure of mod results reachable from them (a mod
## chain counts as long as its base is itself reachable). Legacy data
## entries no character can obtain stay out so the count can be completed.
static func weapon_roster(weapons: Dictionary, mods: Dictionary) -> Array[String]:
	var roster: Array[String] = []
	for weapon_id: String in weapons:
		if weapon_id.begins_with("_"):
			continue
		var stats: Dictionary = weapons[weapon_id]
		if not bool(stats.get("evolution_only", false)) and LevelUp.runtime_can_fire(stats):
			roster.append(weapon_id)
	var grew: bool = true
	while grew:
		grew = false
		for mod_id: String in mods:
			var mod: Dictionary = mods[mod_id]
			var result_id: String = String(mod.get("result_weapon", ""))
			if roster.has(String(mod.get("weapon_id", ""))) \
					and weapons.has(result_id) and not roster.has(result_id):
				roster.append(result_id)
				grew = true
	return roster


## Section progress, ALWAYS derived from the data roster: found counts only
## ids the roster contains, so a hand-edited record claiming everything can
## never inflate the numbers past what the data holds.
static func progress(record: Dictionary, kind: String, roster_ids: Array) -> Dictionary:
	var discovered: Array = normalized_record(record)[kind]
	var found: int = 0
	for id: Variant in roster_ids:
		if discovered.has(id):
			found += 1
	return {"found": found, "total": roster_ids.size()}


static func display_name(entry: Dictionary, locale: String) -> String:
	var key: String = "name_en" if locale == "en" else "name_ko"
	return String(entry.get(key, entry.get("name_ko", "")))


## GDD §18 ??? rule applied per name: a discovered id shows its real name,
## an undiscovered one only proves something exists there.
static func masked_name(entry: Dictionary, discovered: bool, locale: String) -> String:
	if not discovered:
		return UNKNOWN_NAME
	return display_name(entry, locale)


## View-model rows for the 몬스터 section. A discovered monster shows what
## the player learned in the field: its name and where it appears.
static func monster_rows(
	roster: Array[Dictionary], monsters: Dictionary, stages: Dictionary,
	record: Dictionary, locale: String
) -> Array[Dictionary]:
	var clean: Dictionary = normalized_record(record)
	var discovered_ids: Array = clean[KIND_MONSTERS]
	var viewed_ids: Array = (clean[VIEWED_KEY] as Dictionary)[KIND_MONSTERS]
	var rows: Array[Dictionary] = []
	for entry: Dictionary in roster:
		var monster_id: String = String(entry["id"])
		var monster: Dictionary = monsters.get(monster_id, {})
		var discovered: bool = discovered_ids.has(monster_id)
		# An elite_of derivation has no sprite of its own — portrait falls
		# back to its base creature, exactly like the in-world render.
		var sprite_dir: String = String(monster.get("sprite", ""))
		if sprite_dir.is_empty():
			sprite_dir = String((monsters.get(
				String(monster.get("elite_of", "")), {}
			) as Dictionary).get("sprite", ""))
		var lines: Array[String] = []
		if discovered:
			lines.append(UiLocale.text("bestiary.appears_fmt") % display_name(
				stages.get(String(entry["stage_id"]), {}) as Dictionary, locale
			))
		rows.append({
			"id": monster_id,
			"discovered": discovered,
			"is_new": discovered and not viewed_ids.has(monster_id),
			"name": masked_name(monster, discovered, locale),
			"lines": lines,
			"pill": UiLocale.text("bestiary.boss") if discovered and bool(entry["boss"]) else "",
			"sprite_dir": sprite_dir,
		})
	return rows


## View-model rows for the 전리품 section: name, tier pill and what the
## material can transform — each side of a recipe masked by its own
## discovery, so an unmade result stays a secret (GDD §17).
static func loot_rows(
	roster_ids: Array[String], loot: Dictionary, mods: Dictionary,
	weapons: Dictionary, record: Dictionary, locale: String
) -> Array[Dictionary]:
	var clean: Dictionary = normalized_record(record)
	var discovered_ids: Array = clean[KIND_LOOT]
	var viewed_ids: Array = (clean[VIEWED_KEY] as Dictionary)[KIND_LOOT]
	var rows: Array[Dictionary] = []
	for loot_id: String in roster_ids:
		var stats: Dictionary = loot.get(loot_id, {})
		var discovered: bool = discovered_ids.has(loot_id)
		var lines: Array[String] = []
		if discovered:
			var desc: String = String(stats.get("desc_" + locale, stats.get("desc_ko", "")))
			if not desc.is_empty():
				lines.append(desc)
			for mod_id: String in mods:
				var mod: Dictionary = mods[mod_id]
				if String(mod.get("loot_id", "")) != loot_id:
					continue
				# The loot row already names the material it is about, so this
				# line only has to say what it turns into and at what level.
				lines.append(_recipe_line(
					weapons, String(mod.get("weapon_id", "")), mod, clean, locale
				))
		rows.append({
			"id": loot_id,
			"discovered": discovered,
			"is_new": discovered and not viewed_ids.has(loot_id),
			"name": masked_name(stats, discovered, locale),
			"lines": lines,
			"pill": _tier_label(String(stats.get("tier", "")), locale) if discovered else "",
			"sprite_dir": "",
		})
	return rows


## View-model rows for the 무기 section: the weapon's mechanic in one line,
## then its mod branches with undiscovered ends masked.
## B0-3 (owner: 진화 하는 방식도 제대로 느낌이 안 오고 ... 사람들이 보기도
## 어려울 것 같고). `loot` is optional so older callers keep working; without it
## a recipe line simply omits the material it would otherwise name.
static func weapon_rows(
	roster_ids: Array[String], weapons: Dictionary, mods: Dictionary,
	record: Dictionary, locale: String, loot: Dictionary = {}
) -> Array[Dictionary]:
	var clean: Dictionary = normalized_record(record)
	var discovered_ids: Array = clean[KIND_WEAPONS]
	var viewed_ids: Array = (clean[VIEWED_KEY] as Dictionary)[KIND_WEAPONS]
	var rows: Array[Dictionary] = []
	for weapon_id: String in roster_ids:
		var stats: Dictionary = weapons.get(weapon_id, {})
		var discovered: bool = discovered_ids.has(weapon_id)
		var lines: Array[String] = []
		# How the weapon fights is knowledge, so it stays behind the discovery.
		if discovered:
			lines.append(mechanic_line(String(stats.get("mechanic", "")), locale))
		# The recipes are NOT. They used to be inside the branch above, so a
		# weapon you had not found yet showed no paths at all and the archive
		# could not answer "how many are left" — the one question that makes a
		# collection worth filling. The result name stays masked (N4-9); what is
		# revealed is that a path exists and what it costs, which is the half a
		# player can act on.
		for mod_id: String in mods:
			var mod: Dictionary = mods[mod_id]
			if String(mod.get("weapon_id", "")) != weapon_id:
				continue
			lines.append(UiLocale.text("bestiary.branch_fmt") % _recipe_line(
				weapons, weapon_id, mod, clean, locale, loot, true
			))
		rows.append({
			"id": weapon_id,
			"discovered": discovered,
			"is_new": discovered and not viewed_ids.has(weapon_id),
			"name": masked_name(stats, discovered, locale),
			"lines": lines,
			"pill": "",
			"sprite_dir": "",
		})
	return rows


static func mechanic_line(mechanic: String, locale: String) -> String:
	var entry: Dictionary = MECHANIC_LINES.get(mechanic, {})
	return String(entry.get(locale, entry.get("ko", "")))


static func _tier_label(tier: String, locale: String) -> String:
	var entry: Dictionary = TIER_LABELS.get(tier, {})
	return String(entry.get(locale, entry.get("ko", tier)))


## "환도 → ??? · 숫돌 · Lv.5" — the arrow says a path exists, the material and
## the level say what it takes, and the result stays earned.
## `omit_base` belongs to the weapons tab only, where the row heading already
## names the weapon. The loot tab's heading is the MATERIAL, so dropping the
## base there would lose which weapon the recipe even starts from.
static func _recipe_line(
	weapons: Dictionary, base_id: String, mod: Dictionary,
	clean_record: Dictionary, locale: String, loot: Dictionary = {},
	omit_base: bool = false
) -> String:
	var discovered: Array = clean_record[KIND_WEAPONS]
	var result_id: String = String(mod.get("result_weapon", ""))
	var result_name: String = masked_name(
		weapons.get(result_id, {}), discovered.has(result_id), locale
	)
	# When the base is unknown AND the row already stands for it, the heading is
	# a "???" too — repeating it put three of them on two lines and said nothing.
	var line: String = "%s → %s" % [
		masked_name(weapons.get(base_id, {}), discovered.has(base_id), locale),
		result_name,
	]
	if omit_base and not discovered.has(base_id):
		line = "→ %s" % result_name
	var loot_id: String = String(mod.get("loot_id", ""))
	if not loot_id.is_empty() and loot.has(loot_id):
		line += " · %s" % UiLocale.data_name(loot[loot_id] as Dictionary, loot_id)
	var need: int = int(mod.get("level_required", 0))
	if need > 1:
		line += " · " + UiLocale.text("bestiary.recipe_level_fmt") % need
	return line
