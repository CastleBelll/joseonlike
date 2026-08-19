class_name Spawner
extends Node2D
## Wave-driven off-screen enemy spawner (N3-4). All numbers come from
## data/stages.json (waves + spawning) and data/monsters.json. Enemies are
## reused through EnemyPool; a run never instances per spawn after warm-up.

## Kills only (not off-screen despawns), so drops never spawn unseen. The
## dying enemy is still valid during this synchronous emit; it returns to the
## pool right after, so handlers must read its fields immediately.
signal enemy_killed(enemy: Enemy)
## N5-1: the single stage boss just entered the field.
signal boss_spawned(boss: Enemy)

## N10-1a: fires once per run, the first time a shadow monster reaches the
## field. A monster whose whole rule is invisible ("you cannot hurt this in the
## dark") has to say so the first time, or it just reads as a broken enemy.
signal shadow_spawned(enemy: Enemy)
## N4-4a: a burn tick landed on some enemy — the stage floats the number.
signal burn_damaged(amount: float, at: Vector2)

const STAGES_PATH := "res://data/stages.json"
const MONSTERS_PATH := "res://data/monsters.json"
const EFFECTS_PATH := "res://data/effects.json"
const STAGE_ID := "bamboo_forest"

## N5-5: the field's destructible props, set by the stage after StageField
## builds. The spawner is the target registry every weapon already holds, so
## projectiles/arcs/orbs read breakables from here — enemies never touch them.
var breakables: Array[Breakable] = []

## N10-1a: the field's light list, handed to every spawned enemy. Only shadow
## monsters read it; for everything else it is an unused reference.
var lights: Array[Dictionary] = []

# N10-1a targeting filter: reused buffer, rebuilt only while an untouchable
# shadow is on the field (see active_enemies).
var _targetable: Array[Enemy] = []
var _has_absorbing: bool = false
var _shadow_announced: bool = false
## N9-36 tutorial gate: while held, the run clock does NOT advance either. A
## flag that only skipped _start_due_waves would let every held second come due
## the instant it lifted, dumping the whole opening rush at once — the exact
## ambush the staged tutorial exists to avoid.
var waves_held: bool = false

var _monsters: Dictionary = {}
var _spawning: Dictionary = {}
var _feedback: Dictionary = {}
var _pending_waves: Array[Dictionary] = []
var _running_waves: Array[Dictionary] = []
var _active: Array[Enemy] = []
var _pool: EnemyPool
var _player: Player
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _boss_id: String = ""
var _boss_at_sec: float = RunFlow.NO_BOSS
var _boss_spawn_done: bool = false
var _soft_enrage: Dictionary = {}
## N9-22 selected difficulty tier (empty = no scaling).
var _tier: Dictionary = {}
# N3-14 separation state; buffers are reused every frame (clear keeps
# capacity), so steady-state separation allocates nothing.
var _separation := Separation.new()
var _sep_weight: float = 0.0
var _sep_pad: float = 0.0
var _sep_positions: Array[Vector2] = []
var _sep_radii: Array[float] = []
var _sep_neighbours: Array[int] = []
var _sep_neighbour_positions: Array[Vector2] = []
var _sep_neighbour_radii: Array[float] = []
# N3-17: pooled curse-jump bolts — one per infected neighbour on a cursed death.
var _creep_pool: NodePool


func setup(player: Player) -> void:
	_player = player
	_pool = EnemyPool.new(self)
	_creep_pool = NodePool.new(self, _create_curse_creep)
	_rng.randomize()
	var stage_data: Dictionary = _load_json(STAGES_PATH)
	_monsters = _load_json(MONSTERS_PATH)
	_resolve_elites()
	var effects: Dictionary = _load_json(EFFECTS_PATH)
	_feedback = effects.get("hit_feedback", {})
	var sep: Dictionary = effects.get("separation", {})
	if sep.is_empty():
		push_error("spawner: missing separation tuning in " + EFFECTS_PATH)
	_sep_weight = float(sep.get("weight", 0.0))
	_sep_pad = float(sep.get("pad_px", 0.0))
	_separation.configure(float(sep.get("cell_px", 1.0)))
	var stage: Dictionary = stage_data.get(STAGE_ID, {})
	# N9-22: the selected difficulty tier and run length reshape the schedule
	# (wave counts, boss/surge timing, enrage ceilings) before anything reads it.
	var difficulty_config: Dictionary = Difficulty.load_config()
	_tier = Difficulty.entry(difficulty_config, Difficulty.selected_id(difficulty_config))
	stage = Difficulty.apply(
		stage, _tier,
		Difficulty.run_length(difficulty_config, Difficulty.selected_run_length(difficulty_config))
	)
	_spawning = stage.get("spawning", {})
	_boss_id = String(stage.get("boss_id", ""))
	_boss_at_sec = RunFlow.boss_spawn_time(stage)
	_soft_enrage = stage.get("soft_enrage", {})
	if _spawning.is_empty() or _monsters.is_empty():
		push_error("spawner: missing spawning config or monsters for " + STAGE_ID)
		return
	for wave: Dictionary in stage.get("waves", []):
		_pending_waves.append(wave)


## N4-2: "elite_of" entries are multiplier recipes, not full monsters —
## resolve each one into a complete stats dict once at load time.
func _resolve_elites() -> void:
	for monster_id: String in _monsters:
		var entry: Dictionary = _monsters[monster_id]
		if not entry.has("elite_of"):
			continue
		var base_id: String = String(entry.get("elite_of", ""))
		if not _monsters.has(base_id):
			push_error("spawner: elite '%s' references unknown base '%s'" % [monster_id, base_id])
			continue
		_monsters[monster_id] = Enemy.derive_elite_stats(_monsters[base_id], entry)


## The weapon-facing registry. N10-1a: a shadow standing in the dark is not a
## target at all — that removes its damage numbers and, more importantly, stops
## every auto-aimed weapon from locking onto the one enemy it cannot hurt while
## the rest of the wave closes in. The spawner's own bookkeeping still walks
## `_active`, so despawn, separation and the live cap are unaffected.
## The filtered array is built only while such a shadow exists; an ordinary
## run returns `_active` itself and allocates nothing.
func active_enemies() -> Array[Enemy]:
	return _targetable if _has_absorbing else _active


func _refresh_targetable() -> void:
	_has_absorbing = false
	for enemy: Enemy in _active:
		if enemy.absorbs_damage():
			_has_absorbing = true
			break
	if not _has_absorbing:
		return
	_targetable.clear()
	for enemy: Enemy in _active:
		if not enemy.absorbs_damage():
			_targetable.append(enemy)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_refresh_targetable()
	if waves_held:
		return
	_elapsed += delta
	_start_due_waves()
	_run_waves()
	_start_boss_if_due()
	_despawn_far_enemies()
	_apply_separation()


## Writes this frame's weighted push onto every trash enemy (the enemy blends
## it with its chase direction next physics tick — one frame of lag is
## invisible at 60Hz). The boss is present in the grid so trash flows around
## it, but never receives a push itself.
func _apply_separation() -> void:
	if _active.size() < 2 or _sep_weight <= 0.0:
		return
	_sep_positions.clear()
	_sep_radii.clear()
	for enemy: Enemy in _active:
		_sep_positions.append(enemy.global_position)
		_sep_radii.append(enemy.contact_radius)
	_separation.rebuild(_sep_positions)
	for i: int in range(_active.size()):
		var enemy: Enemy = _active[i]
		if enemy.is_boss:
			enemy.separation_push = Vector2.ZERO
			continue
		_sep_neighbours.clear()
		_sep_neighbour_positions.clear()
		_sep_neighbour_radii.clear()
		_separation.collect_neighbours(_sep_positions, i, _sep_neighbours)
		for j: int in _sep_neighbours:
			_sep_neighbour_positions.append(_sep_positions[j])
			_sep_neighbour_radii.append(_sep_radii[j])
		# Index parity picks the split side for exactly stacked pairs, same
		# trick as the enemy's own _avoid_sign.
		var fallback: Vector2 = Vector2.RIGHT if (i & 1) == 0 else Vector2.LEFT
		enemy.separation_push = Separation.separation_push(
			_sep_positions[i], _sep_radii[i],
			_sep_neighbour_positions, _sep_neighbour_radii,
			_sep_pad, fallback
		) * _sep_weight


func _start_due_waves() -> void:
	for wave: Dictionary in _pending_waves.duplicate():
		if _elapsed < float(wave.get("at_sec", 0.0)):
			continue
		_pending_waves.erase(wave)
		_running_waves.append({
			"monster_id": String(wave.get("monster_id", "")),
			"remaining": int(wave.get("count", 0)),
			"interval": float(wave.get("interval_sec", 1.0)),
			"next_at": _elapsed,
		})


func _run_waves() -> void:
	var live_cap: int = int(_spawning.get("live_cap", 0))
	for wave: Dictionary in _running_waves:
		while int(wave["remaining"]) > 0 and _elapsed >= float(wave["next_at"]):
			if _active.size() >= live_cap and not _evict_farthest_offscreen():
				return  # visible field genuinely full; waves resume on deaths
			_spawn_one(String(wave["monster_id"]))
			wave["remaining"] = int(wave["remaining"]) - 1
			wave["next_at"] = float(wave["next_at"]) + float(wave["interval"])
	_running_waves = _running_waves.filter(
		func(wave: Dictionary) -> bool: return int(wave["remaining"]) > 0
	)


## The boss ignores the live cap on purpose: its arrival is a timed event,
## not a wave, and it must never be starved out by a full field.
func _start_boss_if_due() -> void:
	if _boss_spawn_done or _boss_at_sec < 0.0 or _elapsed < _boss_at_sec:
		return
	_boss_spawn_done = true
	var boss: Enemy = _spawn_one(_boss_id)
	if boss != null:
		boss_spawned.emit(boss)


func _spawn_one(monster_id: String) -> Enemy:
	if not _monsters.has(monster_id):
		push_error("spawner: unknown monster id " + monster_id)
		return null
	var enemy: Enemy = _pool.acquire()
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if not enemy.burn_ticked.is_connected(_on_enemy_burn_ticked):
		enemy.burn_ticked.connect(_on_enemy_burn_ticked)
	# N4-2 soft enrage: monsters spawned after the ramp start arrive scaled,
	# so a stalled post-boss field turns lethal instead of dragging (GDD §34).
	# The boss spawns at boss_at_sec, before the ramp, and is never scaled.
	# N9-22: tier scaling first (flat per-night pressure), then the enrage ramp.
	var tiered: Dictionary = Difficulty.scale_monster(
		_monsters[monster_id], _tier, monster_id == _boss_id
	)
	var stats: Dictionary = RunFlow.enrage_stats(
		tiered, _soft_enrage, RunFlow.enrage_progress(_elapsed, _soft_enrage)
	)
	enemy.light_sources = lights
	enemy.setup(
		monster_id,
		stats,
		_player,
		float(_spawning.get("contact_cooldown_sec", 1.0)),
		_feedback
	)
	# Player position approximates the smoothed camera center; the margin
	# absorbs the few-frame camera lag. Accepted tradeoff for N3-4.
	enemy.global_position = CombatMath.spawn_position(
		_player.global_position,
		get_viewport_rect().size,
		float(_spawning.get("spawn_margin_px", 0.0)),
		_rng.randf_range(0.0, TAU)
	)
	if enemy.is_shadow() and not _shadow_announced:
		_shadow_announced = true
		shadow_spawned.emit(enemy)
	_active.append(enemy)
	return enemy


## N4-8: a saturated field must not freeze the wave schedule — a zero-dps
## evasion run used to pin live_cap slow enemies and silently block the
## surge/escort/enrage waves (the last pure-evasion hole). A due spawn on a
## full field recycles the farthest enemy already outside the spawn view rect
## (where new spawns appear anyway), so the swap is never visible on screen;
## a fully on-screen field still blocks the spawn. Live count never exceeds
## the cap, so the fps budget the cap protects is untouched.
func _evict_farthest_offscreen() -> bool:
	var view: Rect2 = CombatMath.view_rect(
		_player.global_position, get_viewport_rect().size,
		float(_spawning.get("spawn_margin_px", 0.0))
	)
	var farthest: Enemy = null
	var farthest_distance: float = 0.0
	for enemy: Enemy in _active:
		if enemy.is_boss or view.has_point(enemy.global_position):
			continue
		var distance: float = _player.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest = enemy
	if farthest == null:
		return false
	_release(farthest)
	return true


func _despawn_far_enemies() -> void:
	for enemy: Enemy in _active.duplicate():
		if enemy.is_boss:
			continue  # a kited boss must keep walking, never silently vanish
		var gone: bool = CombatMath.should_despawn(
			enemy.global_position,
			_player.global_position,
			get_viewport_rect().size,
			float(_spawning.get("despawn_margin_px", 0.0))
		)
		if gone:
			_release(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.is_burning() and enemy.burn_spread_px > 0.0:
		_spread_burn(enemy)
	if enemy.is_cursed():
		_spread_curse(enemy)
	enemy_killed.emit(enemy)
	_release(enemy)


func _on_enemy_burn_ticked(amount: float, at: Vector2) -> void:
	burn_damaged.emit(amount, at)


## 화령석 branch (N4-4a): a burning enemy's death passes the burn to every
## neighbour in the spread radius — spread carries, so packs fall like dominoes.
func _spread_burn(source: Enemy) -> void:
	var radius: float = source.burn_spread_px
	for enemy: Enemy in _active:
		if enemy == source:
			continue
		if source.global_position.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		enemy.apply_burn(source.burn_dps, source.burn_duration, radius)


## 살 (N4-4b): a cursed death infects up to spread_count nearest UNCURSED
## neighbours — never a current carrier, so the chain sweeps a crowd once
## instead of ping-ponging (WeaponMath.curse_spread_targets is the tested
## reference). Death-time only, so the small per-death arrays are fine.
func _spread_curse(source: Enemy) -> void:
	var positions: Array[Vector2] = []
	var cursed: Array[bool] = []
	for enemy: Enemy in _active:
		positions.append(enemy.global_position)
		cursed.append(enemy == source or enemy.is_cursed())
	for i: int in WeaponMath.curse_spread_targets(
		source.global_position, positions, cursed,
		source.curse_spread_px, source.curse_spread_count
	):
		_active[i].apply_curse(
			source.curse_dps, source.curse_duration,
			source.curse_spread_px, source.curse_spread_count
		)
		# N9-30: the spread is drawn as a creep, not a bolt. It used to reuse
		# 뇌부's ChainBolt with a purple tint, which read as lightning — a thing
		# that strikes — when a curse should crawl to its next host.
		var creep: CurseCreep = _creep_pool.acquire()
		creep.show_creep(
			source.global_position, _active[i].global_position,
			UiPalette.WEAPON_CURSE, WeaponEffects.value("curse_jump_sec"),
			WeaponEffects.value("curse_creep_sag_px")
		)


func _create_curse_creep() -> CurseCreep:
	var creep := CurseCreep.new()
	creep.finished.connect(
		func(done: CurseCreep) -> void: _creep_pool.release(done)
	)
	return creep


func _release(enemy: Enemy) -> void:
	_active.erase(enemy)
	_pool.release(enemy)


func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_error("spawner: cannot parse " + path)
		return {}
	return data
