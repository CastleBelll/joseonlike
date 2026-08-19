class_name Stage
extends Node2D
## Combat stage root (N3-1). Ground and props render the AC-4 night-bamboo-
## forest art (N3-10) via Ground/StageField, falling back to palette-token
## placeholders when a texture is missing.

const WEAPONS_PATH := "res://data/weapons.json"
const PASSIVES_PATH := "res://data/passives.json"
const LOOT_PATH := "res://data/loot.json"
const DROP_TABLES_PATH := "res://data/drop_tables.json"
const WEAPON_MODS_PATH := "res://data/weapon_mods.json"
const PICKUPS_PATH := "res://data/pickups.json"
const CHOICES_PER_LEVEL := 3
const POWER_UP_HEADER := "파워 업!"
## N5-5 chest sequence header: one card per screen, (n/total) so the payoff
## reads as a counted sequence, not an endless wall.
const CHEST_HEADER := "보물 상자! (%d/%d)"
const LOOT_SCATTER_PX := 14.0
## N9-18 치명타 확률: a crit deals double damage.
const CRIT_MULTIPLIER := 2.0

@onready var _player: Player = $World/Player
@onready var _joystick: TouchJoystick = $Hud/VirtualJoystick
@onready var _spawner: Spawner = $World/Spawner
@onready var _hud: CombatHud = $Hud/CombatHud
@onready var _field: StageField = $World/StageField
@onready var _ground: GroundLayer = $Ground
@onready var _decor_layer: Node2D = $DecorLayer

var _run_state: RunState
var _orb_pool: NodePool
var _number_pool: NodePool
var _orb_config: Dictionary = {}
var _orb_config_base: Dictionary = {}

# N3-6 run build state: weapon levels, passive stacks and their nodes/effects.
var _weapons_data: Dictionary = {}
var _passives_data: Dictionary = {}
var _owned_levels: Dictionary = {}
var _passive_stacks: Dictionary = {}
var _weapon_categories: Array = []
# N9-6 infinite field: chunk streaming state.
var _field_seed: int = 0
var _props_catalog: Dictionary = {}
var _field_config: Dictionary = {}
var _generated_chunks: Dictionary = {}
# N7-1: the capped permanent 명부수 bonus, computed ONCE in _ready — the only
# meta input the run ever reads, so tree effects cannot double-apply.
var _meta_effects: Dictionary = {}
# N7-2: meta_tree.json config block (revive ratio, first-find timing) and the
# one-shot revive latch — 회생부 fires at most once per run.
var _meta_config: Dictionary = {}
var _revive_used: bool = false
var _weapon_nodes: Dictionary = {}
# N4-2 grade axis: per-weapon run grade plus the data ladder/steps config.
var _owned_grades: Dictionary = {}
var _grades_config: Dictionary = {}
var _grade_ladder: Array[String] = []
var _popup: LevelUpPopup
var _pending_level_ups: int = 0
var _choice_rng := RandomNumberGenerator.new()
var _kills: int = 0
var _ground_size := Vector2.ZERO  # from data/props.json "field" block

# N4-1 loot state: data tables, pooled drops, run-seeded RNG. N4-6: weapons
# a mod replaced this run — banned from every choice pool for good.
var _loot_data: Dictionary = {}
var _drop_tables: Dictionary = {}
var _mods_data: Dictionary = {}
var _loot_pool: NodePool
var _loot_rng := RandomNumberGenerator.new()
var _replaced_weapons: Array[String] = []
# N4-9 rarity evidence: the run second each SPECIAL material dropped at —
# the playtest harness reads this to prove the intended drop rate.
var _special_drop_times: Array[float] = []
# N9-24: the run's first elite always leaves one evolution material. Raising
# the average alone still left whole runs at zero specials, and a run with zero
# materials cannot evolve at any gate level — this removes those dead runs
# instead of inflating the already-lucky ones further.
var _first_elite_resolved: bool = false

# N5-5 destructibles + elite chests: pickup table data, pooled pickup/chest
# entities, and the chest reward queue. _chest_pending counts rewards still
# owed; each is drawn fresh from the level-up pool machinery at show time so a
# card can never offer something the previous reward made illegal. Kind
# counters and chest counts are harness evidence (playtest reads them).
var _pickups_data: Dictionary = {}
var _pickup_pool: NodePool
var _chest_pool: NodePool
var _chest_pending: int = 0
var _chest_batch_total: int = 0
var _chest_batch_index: int = 0
var _chest_showing: bool = false
var _break_stats: Dictionary = {}
var _chest_counts: Array[int] = []
# N6-3 recovery evidence (harness reads them): every landed heal, any source.
var _heal_events: int = 0
var _heal_total: float = 0.0

# N3-8 feedback + N5-1 run flow state.
var _feedback: Dictionary = {}
var _puff_pool: NodePool
# N3-18: pooled 벽사진 wave rings (one per cast; pooled like every effect).
var _burst_ring_pool: NodePool
# N3-17 art integration: pooled sprite puffs for 축지 when the sheet shipped.
var _fx_pool: NodePool
var _gold: int = 0
# N6-5: monsters no longer drop gold — the boss-kill reward from stages.json
# is the single kill-paid gold source left; everything else is destructibles,
# chests and salvage.
var _boss_gold: int = 0
var _run_elapsed: float = 0.0
var _duration_sec: float = 0.0
var _boss: Enemy
var _boss_hp_max: float = 0.0
# N9-49 boss patterns: the attack table for the live boss and the seconds since
# each one last fired. Owned here, like every other pool and timer, so the
# damage lands in one place instead of inside a monster's own physics step.
var _boss_attacks: Array[Dictionary] = []
var _boss_attack_since: Array[float] = []
var _telegraph_pool: NodePool
var _outcome: String = RunFlow.OUTCOME_NONE
var _result: ResultScreen

# N4-4b actives: data entries from characters.json plus per-id cooldown left.
var _actives: Array[Dictionary] = []
var _active_cooldowns: Dictionary = {}

# N6-1 FTUE state: the one-shot move hint node (null once dismissed or for a
# returning profile) and the first-run guarantee table from stages.json —
# _first_run_log maps each guaranteed loot_id to the second it first dropped.
var _move_hint: MoveHint
# N9-14 interactive guide: the dialog node and the actives highlight ring.
var _guide: GuideDialog
var _guide_ring: TutorialRing
## N9-44: metres walked while the guide's move page is up.
var _guide_walked_px: float = 0.0
var _first_run_drops: Array = []
var _first_run_log: Dictionary = {}
# N6-2: a guaranteed first-run drop lands ahead of the player (data offset),
# not on the corpse — something to walk toward and see, not receive.
var _guarantee_offset_px: float = 0.0
# N9-22 selected difficulty tier + run length (empty = defaults).
var _tier: Dictionary = {}
var _run_length: Dictionary = {}


func _ready() -> void:
	var props_config: Dictionary = StageField.load_config()
	var field_config: Dictionary = props_config.get("field", {})
	_ground_size = Vector2(
		float(field_config.get("width_px", 0.0)),
		float(field_config.get("height_px", 0.0))
	)
	# N9-6 infinite field: no bounds — the ground already follows the camera
	# (N3-16) and props stream in per chunk as the player travels.
	_player.bounds = Rect2()
	# randi() is auto-seeded per process start, so every run scatters a fresh
	# field layout; tests drive StageField.generate with fixed seeds instead.
	# Ground and props share one seed so a run's tiles and prop scatter match.
	var field_seed: int = randi()
	_ground.build(field_config, field_seed)
	_field.build(
		props_config.get("props", {}) as Dictionary, field_config, _decor_layer, field_seed
	)
	_field_seed = field_seed
	_props_catalog = props_config.get("props", {})
	_field_config = field_config
	# The origin field's footprint counts as already generated: any chunk it
	# overlaps must never re-scatter on top of the N6-5 origin layout.
	var origin := Rect2(-_ground_size / 2.0, _ground_size)
	var from_chunk: Vector2i = Vector2i((origin.position / StageField.CHUNK_PX).floor())
	var to_chunk: Vector2i = Vector2i((origin.end / StageField.CHUNK_PX).ceil())
	for cx: int in range(from_chunk.x, to_chunk.x):
		for cy: int in range(from_chunk.y, to_chunk.y):
			_generated_chunks[Vector2i(cx, cy)] = true
	_player.died.connect(_on_player_died)
	_player.hit_taken.connect(_on_player_hit)
	_spawner.setup(_player)
	_spawner.enemy_killed.connect(_on_enemy_killed)
	_spawner.boss_spawned.connect(_on_boss_spawned)
	_spawner.shadow_spawned.connect(_on_shadow_spawned)
	# N9-1a: the stage id IS the track id, so a second region ships its own
	# music by adding one entry to data/audio.json and nothing else.
	if MusicService.instance != null:
		MusicService.instance.play(Spawner.STAGE_ID)
	# N4-4a: burn ticks float through the same damage-number pool as hits.
	_spawner.burn_damaged.connect(
		func(amount: float, at: Vector2) -> void: _on_hit_landed(amount, at, false)
	)
	_feedback = _load_json(Spawner.EFFECTS_PATH).get("hit_feedback", {})
	var stage_entry: Dictionary = _load_json(Spawner.STAGES_PATH).get(Spawner.STAGE_ID, {})
	# N9-22: the same tier/length scaling the spawner applies, so the HUD
	# clock and the wave schedule always agree on when the night ends.
	var difficulty_config: Dictionary = Difficulty.load_config()
	_tier = Difficulty.entry(difficulty_config, Difficulty.selected_id(difficulty_config))
	_run_length = Difficulty.run_length(
		difficulty_config, Difficulty.selected_run_length(difficulty_config)
	)
	stage_entry = Difficulty.apply(stage_entry, _tier, _run_length)
	_duration_sec = float(stage_entry.get("duration_sec", 0.0))
	_boss_gold = int(stage_entry.get("boss_gold", 0))
	_puff_pool = NodePool.new(self, _create_puff)
	_telegraph_pool = NodePool.new(self, _create_telegraph)
	_burst_ring_pool = NodePool.new(self, _create_burst_ring)
	if EffectSprite.available("blink_puff"):
		_fx_pool = NodePool.new(self, _create_effect_sprite)
	_result = ResultScreen.new()
	add_child(_result)
	_run_state = RunState.new()
	_run_state.level_reached.connect(_on_level_reached)
	_orb_config_base = RunState.load_orb_config()
	_orb_config = _orb_config_base.duplicate()
	var meta_data: Dictionary = MetaTree.load_tree()
	var meta_clean: Dictionary = MetaTree.sanitize_state(
		meta_data, _profile().get("meta_tree", {}) as Dictionary
	)
	if int(meta_clean["dropped"]) > 0:
		push_warning(
			"stage: dropped %d invalid meta_tree entries" % int(meta_clean["dropped"])
		)
	# N7-2: only the trunk plus the SELECTED character's branch apply here —
	# another character's branch must never leak into this run.
	_meta_effects = MetaTree.aggregate_effects(
		meta_data, meta_clean["state"] as Dictionary,
		String(_profile().get("selected_character", SaveProfile.DEFAULT_CHARACTER))
	)
	_meta_config = meta_data.get("config", {})
	_orb_pool = NodePool.new(self, _create_orb)
	_number_pool = NodePool.new(self, _create_damage_number)
	_weapons_data = _load_json(WEAPONS_PATH)
	_grades_config = WeaponGrade.config(_weapons_data)
	_grade_ladder = WeaponGrade.ladder(_grades_config)
	_passives_data = _load_json(PASSIVES_PATH)
	_loot_data = _load_json(LOOT_PATH)
	_drop_tables = _load_json(DROP_TABLES_PATH)
	_mods_data = _load_json(WEAPON_MODS_PATH)
	_loot_pool = NodePool.new(self, _create_loot_drop)
	_loot_rng.randomize()  # the run RNG: one seed replays a run's drops
	# N5-5: destructible props + pickups + elite chests. The spawner carries
	# the breakable list because it is the target registry weapons already hold.
	_pickups_data = _load_json(PICKUPS_PATH)
	_pickup_pool = NodePool.new(self, _create_pickup)
	_chest_pool = NodePool.new(self, _create_chest)
	_spawner.breakables = _field.breakables
	# Same array reference: chunks appending lights are seen without rewiring.
	_spawner.lights = _field.lights
	for breakable: Breakable in _field.breakables:
		breakable.broke.connect(_on_breakable_broke)
	var starting_weapon: String = Player.load_starting_weapon()
	_owned_levels[starting_weapon] = 1
	_owned_grades[starting_weapon] = LevelUp.current_grade(starting_weapon, _weapons_data, {})
	_add_weapon_node(starting_weapon)
	# N7-1 one-shot meta application: scalars fold into the shared refresh
	# below; the flat HP grant lands here exactly once per run.
	_refresh_run_scalars()
	var meta_hp_grant: float = Player.load_base_hp() * _meta_bonus("max_hp")
	_player.hp += meta_hp_grant
	_player.hp_max += meta_hp_grant
	# N7-2 survivability nodes: the longer post-hit invulnerability window
	# (긴 호흡) applies exactly once; damage reduction moved into
	# _refresh_run_scalars (N9-3g) because the 방비 passive now joins it and
	# passive stacks change mid-run.
	_player.set_invuln_scale(1.0 + _meta_bonus("hit_invuln"))
	_popup = LevelUpPopup.new()
	_popup.picked.connect(_on_choice_picked)
	_popup.dismissed.connect(_on_popup_dismissed)
	add_child(_popup)
	_hud.set_gold(0)  # run gold; banked into the profile at run end (N5-2)
	# N9-5d weapon identity: the level-up pool only offers new weapons from
	# the selected character's categories (도사 gets no 각궁).
	_weapon_categories = Player.load_weapon_categories()
	_actives = Player.load_actives()
	for active: Dictionary in _actives:
		_active_cooldowns[String(active.get("id", ""))] = 0.0
	_hud.build_actives(_actives)
	_hud.active_pressed.connect(_on_active_pressed)
	# N9-3e: the pause overlay pulls the live build on every open.
	_hud.build_provider = _pause_build_summary
	# N6-4 floating joystick: HUD buttons keep tap priority over the stick.
	# The level-up popup needs no entry here — it only ever opens while the
	# tree is paused, which stops the joystick's _input entirely; a future
	# unpaused popup would need its buttons covered by blocks_point too.
	_joystick.blocks_touch = _hud.blocks_point
	_refresh_progress_hud()
	# N7-2 조기 수행: a banked head start grants its levels — and their power-up
	# screens — right now, before the first wave lands.
	for i: int in range(int(_meta_bonus("start_level"))):
		_run_state.add_xp(_run_state.xp_needed())
	# N6-1 FTUE: the scripted first-run drop table only arms on a profile that
	# has never finished a run, and the move hint only until first dismissal.
	var profile: Dictionary = _profile()
	if Ftue.is_first_run(profile):
		_first_run_drops = stage_entry.get("first_run_drops", [])
		_guarantee_offset_px = float(
			(stage_entry.get("opening", {}) as Dictionary).get("guarantee_offset_px", 0.0)
		)
	# N9-16: the guide teaches movement itself, so its own '움직여보자' page
	# owns that moment — the chevron hint would show behind the dialogue
	# (owner report). It arms only when the guide is NOT running, and
	# _on_guide_finished arms it afterwards if the flag is still unseen.
	var guide_running: bool = (
		Ftue.is_first_run(profile) and Ftue.should_show_guide(profile)
	)
	if Ftue.should_show_move_hint(profile) and not guide_running:
		_arm_move_hint()
	# N9-4 first-boot guide, interactive since N9-14: tap-through pages
	# pause the tree; await pages (move / active press) unpause it and
	# highlight the control until the player actually does the thing.
	if guide_running:
		_guide = GuideDialog.new()
		_guide.name = "GuideDialog"
		add_child(_guide)
		_guide.finished.connect(_on_guide_finished)
		_guide.page_shown.connect(_on_guide_page_shown)
		_guide.open(Ftue.GUIDE_PAGES)
	# N7-2 첫 인연: every run guarantees one special material early, through the
	# same guarantee pipeline the FTUE table uses (data timing, run-seeded pick).
	if int(_meta_bonus("first_find")) >= 1:
		_arm_first_find()


## Appends the 첫 인연 guarantee to the run's guarantee table: one random
## special material, due at the data-configured second.
func _arm_first_find() -> void:
	var special_ids: Array[String] = []
	for loot_id: String in _loot_data:
		if bool((_loot_data[loot_id] as Dictionary).get("special", false)):
			special_ids.append(loot_id)
	if special_ids.is_empty():
		return
	var at_sec: float = float(
		(_meta_config.get("first_find", {}) as Dictionary).get("at_sec", 0.0)
	)
	_first_run_drops = _first_run_drops.duplicate()
	_first_run_drops.append({
		"loot_id": special_ids[_loot_rng.randi_range(0, special_ids.size() - 1)],
		"at_sec": at_sec,
	})


func _physics_process(delta: float) -> void:
	_player.joystick_input = _joystick.output
	var moving: bool = (
		_joystick.output != Vector2.ZERO
		or Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO
	)
	if _move_hint != null and moving:
		_dismiss_move_hint()
	# N9-14: the guide's "움직여봐" page advances on real movement. N9-16:
	# doing it there retires the standalone hint too — the lesson landed.
	# N9-44: the page asks for a WALK, not a touch. Distance is accumulated
	# while the move page is up and the lesson only lands once the player has
	# actually covered it.
	if _guide != null and moving:
		_guide_walked_px += _player.velocity.length() * delta
		if _guide_walked_px >= _guide_walk_goal_px():
			_guide.notify_action(Ftue.AWAIT_MOVE)
			if SaveService.instance != null and Ftue.should_show_move_hint(_profile()):
				SaveService.instance.mark_move_hint_seen()
	_run_elapsed += delta
	_tick_boss_attacks(delta)
	_refresh_hp_hud()
	_stream_field_chunks()
	if _duration_sec > 0.0 and _run_elapsed >= _duration_sec:
		_end_run(RunFlow.resolve_outcome(false, false, true))
	if _boss != null and not CombatMath.is_dead(_boss.hp):
		_hud.set_boss_hp(_boss.hp, _boss_hp_max)
	for active: Dictionary in _actives:
		var active_id: String = String(active.get("id", ""))
		var left: float = maxf(float(_active_cooldowns[active_id]) - delta, 0.0)
		_active_cooldowns[active_id] = left
		_hud.set_active_cooldown(active_id, ActiveSkill.cooldown_fraction(
			left, float(active.get("cooldown_sec", 0.0))
		))


## N9-6 infinite field: generate the player's chunk neighborhood on demand.
## One chunk per frame at most — a sprint across fresh ground amortizes the
## scatter cost instead of hitching on a 3x3 burst.
func _stream_field_chunks() -> void:
	if _props_catalog.is_empty():
		return
	var player_chunk: Vector2i = Vector2i(
		(_player.global_position / StageField.CHUNK_PX).floor()
	)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var chunk: Vector2i = player_chunk + Vector2i(dx, dy)
			if _generated_chunks.has(chunk):
				continue
			_generated_chunks[chunk] = true
			var fresh: Array[Breakable] = _field.add_chunk(
				_props_catalog, _field_config, _decor_layer, _field_seed, chunk
			)
			for breakable: Breakable in fresh:
				breakable.broke.connect(_on_breakable_broke)
			return  # at most one chunk per physics frame


## First movement input retires the hint for good (N6-1): the flag persists
## immediately so a crash later in the run cannot bring it back.
func _dismiss_move_hint() -> void:
	_move_hint.queue_free()
	_move_hint = null
	if SaveService.instance != null:
		SaveService.instance.mark_move_hint_seen()


## N9-14: pause on tap-through pages, play on await pages; ring the
## actives cluster while its press is awaited.
## Freezes or releases the world for the staged first-run guide. The spawner
## holds its CLOCK as well as its waves, so nothing comes due in a heap when
## the hold lifts.
func _set_tutorial_hold(held: bool) -> void:
	_spawner.waves_held = held
	for weapon: AutoWeapon in _weapon_nodes.values():
		weapon.hold_fire = held


## How far the current guide page wants the player to walk. Zero when the
## page does not ask for a walk, so any movement satisfies it.
func _guide_walk_goal_px() -> float:
	if _guide == null:
		return 0.0
	return _guide.current_page_number("move_px")


func _ring_rect(target: Rect2) -> void:
	if _guide_ring == null:
		_guide_ring = TutorialRing.new()
		$Hud.add_child(_guide_ring)
	_guide_ring.aim(target)


## The player's on-screen box, for the tutorial ring. The HUD ring lives in
## screen space while the player lives in the world, so the camera transform
## has to be applied rather than the world position used directly.
func _player_screen_rect() -> Rect2:
	var half: float = Player.CONTACT_RADIUS * 2.0
	var centre: Vector2 = (
		_player.get_global_transform_with_canvas().origin
	)
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


func _on_guide_page_shown(index: int, await_action: String) -> void:
	get_tree().paused = await_action.is_empty()
	# N9-36 (owner report: the move lesson arrived with the opening rush and a
	# talisman already flying): the world stays still until the guide reaches
	# the page that introduces combat. One lesson at a time.
	_set_tutorial_hold(index < Ftue.COMBAT_FROM_PAGE)
	_guide_walked_px = 0.0
	if await_action == Ftue.AWAIT_ACTIVE:
		_ring_rect(_hud.actives_rect())
	elif await_action == Ftue.AWAIT_KILL:
		# Ringing the player, not a button: the thing to watch is the talisman
		# leaving them on its own. A projectile is the wrong thing to ring —
		# it is gone before the eye arrives.
		_ring_rect(_player_screen_rect())
	elif _guide_ring != null:
		_guide_ring.queue_free()
		_guide_ring = null


func _arm_move_hint() -> void:
	_move_hint = MoveHint.new()
	_move_hint.name = "MoveHint"
	_move_hint.target = _joystick
	$Hud.add_child(_move_hint)


## N9-4: guide dismissed — unpause, persist the one-shot flag, free the node.
func _on_guide_finished() -> void:
	get_tree().paused = false
	_set_tutorial_hold(false)
	if _guide_ring != null:
		_guide_ring.queue_free()
		_guide_ring = null
	if SaveService.instance != null:
		SaveService.instance.mark_guide_seen()
	if _guide != null:
		_guide.queue_free()
		_guide = null
	# N9-16: the guide's move page already taught this; the hint only
	# returns if that page somehow never retired the flag.
	if _move_hint == null and Ftue.should_show_move_hint(_profile()):
		_arm_move_hint()


## N5-4 괴이록 funnel: null-guarded so demo tools without the autoload run;
## SaveService only writes on a genuinely new discovery.
func _record_discovery(kind: String, id: String) -> void:
	if SaveService.instance != null:
		SaveService.instance.record_discovery(kind, id)


## The live profile, or the default shape in node-free tests and demo tools
## that boot the stage without the SaveManager autoload.
func _profile() -> Dictionary:
	if SaveService.instance != null:
		return SaveService.instance.profile
	return SaveProfile.default_profile()


func _on_player_died() -> void:
	# N7-2 회생부: once per run, the killing blow becomes a second wind instead
	# of the result screen — visible as the HP refill plus the float label.
	var revive: Dictionary = _meta_config.get("revive", {})
	var revive_ratio: float = float(revive.get("hp_ratio", 0.0))
	if not _revive_used and int(_meta_bonus("revive")) >= 1 and revive_ratio > 0.0:
		_revive_used = true
		_player.hp = _player.hp_max * revive_ratio
		_player.grant_invulnerability(float(revive.get("invuln_sec", 0.0)))
		_float_label("회생부 발동!")
		return
	_end_run(RunFlow.resolve_outcome(true, false, false))


## N3-8: the invulnerability blink lives on the player; the HUD adds the
## screen-edge red pulse so a hit is legible even off-center.
func _on_player_hit() -> void:
	_hud.pulse_damage(float(_feedback.get("player_vignette_sec", 0.0)))


## The enemy reference is only valid during this synchronous call — it goes
## back to its pool right after (see Spawner.enemy_killed).
func _on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	# N9-36: "부적은 알아서 날아간다" is a claim; a 괴이 falling to it is the
	# proof, so that page advances on a kill rather than on a tap.
	if _guide != null:
		_guide.notify_action(Ftue.AWAIT_KILL)
	_record_discovery(Bestiary.KIND_MONSTERS, enemy.monster_id)
	_hud.set_kills(_kills)
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		enemy.global_position,
		enemy.contact_radius * float(_feedback.get("death_puff_radius_scale", 1.0)),
		float(_feedback.get("death_puff_sec", 0.0))
	)
	var orb: XpOrb = _orb_pool.acquire()
	orb.launch(enemy.global_position, enemy.xp_drop, _player, _orb_config)
	_spawn_loot(enemy)
	# N5-5: an elite death leaves a reward chest where it fell (walk to open).
	if enemy.is_elite:
		var chest: Chest = _chest_pool.acquire()
		chest.place(
			enemy.global_position, _player,
			float((_pickups_data.get("chest", {}) as Dictionary).get("open_radius_px", 0.0))
		)
		# N6-3 earned recovery: beating the run's set-piece fight refunds a
		# slice of max HP — a reward for engaging the elite, never a drip.
		_heal_player(float(
			(_pickups_data.get("elite_heal", {}) as Dictionary).get("hp_ratio", 0.0)
		))
	if enemy.is_boss:
		# N6-5: the ONE monster that still pays gold — a deliberate boss-kill
		# reward from stage data, paid directly because the kill ends the run
		# this same call (a spawned chest could never be opened).
		_add_gold(_boss_gold)
		_boss = null
		_hud.hide_boss_bar()
		_end_run(RunFlow.resolve_outcome(false, true, false), true)


## N9-49: one telegraph node per warning, pooled like every other effect.
func _create_telegraph() -> BossTelegraph:
	var telegraph := BossTelegraph.new()
	telegraph.erupted.connect(_on_telegraph_erupted)
	telegraph.finished.connect(
		func(done: BossTelegraph) -> void: _telegraph_pool.release(done)
	)
	return telegraph


## Drives the live boss's attack table. Runs on the stage clock rather than the
## boss's own process so a paused tree stops the patterns too.
func _tick_boss_attacks(delta: float) -> void:
	if _boss == null or _boss_attacks.is_empty():
		return
	for i: int in range(_boss_attack_since.size()):
		_boss_attack_since[i] += delta
	var index: int = BossPatterns.due_index(_boss_attacks, _boss_attack_since)
	if index < 0:
		return
	_boss_attack_since[index] = 0.0
	var attack: Dictionary = _boss_attacks[index]
	var radius: float = float(attack.get("radius_px", 0.0))
	var inner: float = float(attack.get("inner_px", 0.0))
	var warn_sec: float = float(attack.get("warn_sec", 0.0))
	# A band pattern is centred on the boss (step in or step out); a disc
	# pattern hunts the player.
	if inner > 0.0:
		_warn_telegraph(_boss.global_position, radius, inner, warn_sec, attack)
		return
	for point: Vector2 in BossPatterns.surge_points(
		_player.global_position, _player.velocity, attack, _choice_rng.randf() * TAU
	):
		_warn_telegraph(point, radius, 0.0, warn_sec, attack)


func _warn_telegraph(
	at: Vector2, radius: float, inner: float, warn_sec: float, attack: Dictionary
) -> void:
	var telegraph: BossTelegraph = _telegraph_pool.acquire()
	telegraph.set_meta("attack", attack)
	telegraph.warn(at, radius, inner, warn_sec, UiPalette.VERMILION)


## The eruption resolves against the player only. Boss patterns are the boss's
## own damage; they never chip the monsters standing in them, which would let a
## player farm the boss's attacks.
func _on_telegraph_erupted(at: Vector2, radius: float, inner: float) -> void:
	for child: Node in get_children():
		var telegraph := child as BossTelegraph
		if telegraph == null or not telegraph.visible or telegraph.global_position != at:
			continue
		var attack: Dictionary = telegraph.get_meta("attack", {})
		if not BossPatterns.covers(_player.global_position, at, radius, inner):
			return
		_player.take_hit(float(attack.get("damage", 0.0)), String(attack.get("name_ko", "")))
		return


func _on_boss_spawned(boss: Enemy) -> void:
	_boss = boss
	_boss_hp_max = boss.hp
	_boss_attacks = BossPatterns.attacks(
		(_load_json(Spawner.MONSTERS_PATH) as Dictionary).get(boss.monster_id, {})
	)
	_boss_attack_since = []
	for _attack: Dictionary in _boss_attacks:
		# Start part-charged so the fight opens with a pattern instead of a
		# silent first cooldown, but not so charged that both land at once.
		_boss_attack_since.append(0.0)
	_hud.show_boss_bar()
	_hud.set_boss_hp(boss.hp, _boss_hp_max)


## Single exit point for the three end conditions; the first one wins.
## N5-2: the run's gold banks into the permanent profile here — the one
## run-end autosave — and the result screen shows the new total.
func _end_run(outcome: String, boss_killed: bool = false) -> void:
	if _outcome != RunFlow.OUTCOME_NONE or outcome == RunFlow.OUTCOME_NONE:
		return
	_outcome = outcome
	# A timeout victory leaves the boss alive — its HP bar must not sit on top
	# of the result screen (QA-1).
	_hud.hide_boss_bar()
	# A run ending mid shockwave-punch would freeze the camera slightly zoomed
	# for the whole result screen (physics stops while paused) — reset first.
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.zoom = Vector2.ONE
	get_tree().paused = true
	var summary: Dictionary = RunFlow.build_summary(
		_run_elapsed, _kills, _gold, _player.last_hit_source
	)
	summary["total_gold"] = SaveService.instance.bank_run(_run_elapsed, _kills, _gold, boss_killed)
	# N9-22: surviving the night opens the next tier of the ladder.
	if outcome == RunFlow.OUTCOME_VICTORY:
		var config: Dictionary = Difficulty.load_config()
		SaveService.instance.mark_difficulty_cleared(Difficulty.selected_id(config))
	_result.open(outcome, summary)


## N4-4b active trigger: the HUD button is display-only — this is the
## authoritative cooldown gate (CombatMath window rule, boundary inclusive).
func _on_active_pressed(active_id: String) -> void:
	if float(_active_cooldowns.get(active_id, 0.0)) > 0.0:
		return
	for active: Dictionary in _actives:
		if String(active.get("id", "")) != active_id:
			continue
		_execute_active(active)
		_active_cooldowns[active_id] = float(active.get("cooldown_sec", 0.0))
		# N9-14: the guide's "눌러봐" page advances on a real cast.
		if _guide != null:
			_guide.notify_action(Ftue.AWAIT_ACTIVE)
		return


## Effects live here so demo tools can fire them without touching cooldowns.
func _execute_active(active: Dictionary) -> void:
	match String(active.get("type", "")):
		"blink":
			_execute_blink(active)
		"burst":
			_execute_burst(active)
		_:
			push_error("stage: unknown active type in " + str(active))


## 축지: blink along the movement direction, stopped at the first solid prop
## and clamped to the field, plus a short invulnerability window.
func _execute_blink(active: Dictionary) -> void:
	var from: Vector2 = _player.global_position
	var direction: Vector2 = _player.last_move_direction
	var distance: float = float(active.get("distance_px", 0.0))
	var blocked_at: float = INF
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * distance)
	query.collision_mask = StageField.LAYER_OBSTACLE
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Stop a body-width short of the prop face. ponytail: a center ray can
		# graze past a narrow corner; the body's own collision catches it next
		# frame — full shape cast if that ever reads wrong in play.
		blocked_at = from.distance_to(hit["position"]) - Player.CONTACT_RADIUS
	_player.global_position = ActiveSkill.blink_destination(
		from, direction, distance, blocked_at, _player.bounds
	)
	_player.grant_invulnerability(float(active.get("invulnerable_sec", 0.0)))
	# N3-17: a puff at BOTH ends so the departure and the arrival read. The
	# desaturated smoke sheet plays tinted to the taoist accent when shipped;
	# the code-drawn ring puff is the fallback.
	_blink_puff(from)
	_blink_puff(_player.global_position)


## 벽사진: the emergency button — heavy damage to everything in a large ring
## around the player, through the normal damage-number pipeline.
func _execute_burst(active: Dictionary) -> void:
	var origin: Vector2 = _player.global_position
	var radius: float = float(active.get("radius_px", 0.0))
	var damage: float = float(active.get("damage", 0.0))
	# N3-18: a clean expanding wave that lands exactly on the damage radius —
	# the N3-17 DeathPuff reuse opened as an opaque gold pancake covering half
	# the screen. The short screen flash stays as the "emergency" punctuation.
	var ring: BlastRing = _burst_ring_pool.acquire()
	ring.burst(
		origin, radius, WeaponEffects.value("burst_ring_sec"), UiPalette.GOLD,
		BlastRing.Style.WAVE
	)
	_hud.flash_screen(UiPalette.GOLD, WeaponEffects.value("screen_flash_sec"))
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	# Collect refs first: striking mutates the spawner's active list.
	var caught: Array[Enemy] = []
	for i: int in WeaponMath.targets_in_radius(origin, positions, radius):
		caught.append(enemies[i])
	for enemy: Enemy in caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(damage, CombatMath.chase_direction(origin, hit_at))
		_on_hit_landed(damage, hit_at, boss_hit)


func _on_orb_collected(orb: XpOrb) -> void:
	# N7-2 문리 + N9-3 passive: xp_gain meta and passive bonuses both scale
	# every orb at pickup through the same multiplier.
	_run_state.add_xp(int(round(
		float(orb.xp_value) * (1.0 + _meta_bonus("xp_gain") + _passive_bonus("xp_gain"))
		* Difficulty.reward_mult(_tier, _run_length, "xp_mult")
	)))
	_refresh_progress_hud()
	_orb_pool.release(orb)


func _refresh_progress_hud() -> void:
	_hud.set_level(_run_state.level)
	_hud.set_xp(_run_state.xp, _run_state.xp_needed())


## N6-2: HUD HP bar + low-HP warning, every physics frame — covers hits,
## max-HP passives and the meta grant through one path. Numbers from data.
func _refresh_hp_hud() -> void:
	_hud.set_hp(
		_player.hp, _player.hp_max,
		float(_feedback.get("low_hp_threshold", 0.0)),
		float(_feedback.get("low_hp_pulse_sec", 0.0))
	)


func _on_hit_landed(amount: float, at: Vector2, boss_hit: bool, crit: bool = false) -> void:
	var number: DamageNumber = _number_pool.acquire()
	number.show_amount(amount, at, boss_hit, crit)


func _on_number_finished(number: DamageNumber) -> void:
	_number_pool.release(number)


## One grant can cross several levels; each one earns a choice screen — the
## only tap a run asks for (DESIGN.md §5.2). Loot never opens a panel (N4-6).
func _on_level_reached(_new_level: int) -> void:
	_pending_level_ups += 1
	if not _popup.visible:
		_advance_popup_queue()


func _show_next_level_up() -> void:
	get_tree().paused = true
	var pool: Array[Dictionary] = LevelUp.candidates(
		_weapons_data, _passives_data, _owned_levels, _passive_stacks,
		_owned_grades, _grades_config, _replaced_weapons, _weapon_categories
	)
	# N9-31 (owner report: 낡은 부적 Lv.5 안됐는데도 개조가 되네): the level gate
	# now applies on the first run too. It used to be waived so the scripted
	# first run could teach 개조 — but that taught a rule that becomes false on
	# run two, and a lesson the game then contradicts is worse than no lesson.
	# The teaching moved to a truthful signal that already exists: picking the
	# material floats "<무기> Lv.N에서 개조" (_material_cue), and the pause
	# screen's 개조 경로 lines carry the same requirement.
	var mod_pool: Array[Dictionary] = LevelUp.mod_candidates(
		_mods_data, _run_state.inventory, _owned_levels, _replaced_weapons
	)
	# N7-2 혜안: the choice_count meta bonus widens every level-up screen.
	var choices: Array[Dictionary] = LevelUp.assemble(
		pool, mod_pool, CHOICES_PER_LEVEL + int(_meta_bonus("choice_count")), _choice_rng
	)
	var masked: Array[String] = _unknown_mod_results(choices)
	var cards: Array[Dictionary] = []
	for choice: Dictionary in choices:
		cards.append(LevelUp.as_card(
			choice, _weapons_data, _passives_data, _owned_levels, _passive_stacks,
			_owned_grades, _grades_config, masked
		))
	# N9-14: the first-ever level-up screen wears a tutorial header once —
	# the popup itself IS the weapon-upgrade tutorial (owner direction).
	var header: String = POWER_UP_HEADER
	if Ftue.should_explain_level_up(_profile()):
		header = Ftue.LEVELUP_EXPLAIN_HEADER
		if SaveService.instance != null:
			SaveService.instance.mark_level_up_explained()
	# N6-1: the very first 개조 card a profile ever sees carries one extra
	# explanation line — same card, same single tap, never again.
	if Ftue.should_explain_mod(_profile()):
		var explained: Dictionary = Ftue.explain_mod_cards(cards)
		cards = explained["cards"]
		if bool(explained["explained"]) and SaveService.instance != null:
			SaveService.instance.mark_mod_explained()
	_popup.open(header, cards, _owned_levels, _weapons_data)


## N4-9 permanent knowledge: mod results this profile's 괴이록 has never
## recorded stay ??? on the card — performing the evolution once makes the
## recipe legible in every later run (knowledge, not power).
func _unknown_mod_results(choices: Array[Dictionary]) -> Array[String]:
	var known: Array = Bestiary.normalized_record(
		_profile().get("bestiary")
	)[Bestiary.KIND_WEAPONS]
	var masked: Array[String] = []
	for choice: Dictionary in choices:
		if String(choice.get("kind", "")) != LevelUp.KIND_MOD:
			continue
		var result_id: String = String(
			(choice.get("mod", {}) as Dictionary).get("result_weapon", "")
		)
		if not result_id.is_empty() and not known.has(result_id):
			masked.append(result_id)
	return masked


func _on_choice_picked(payload: Dictionary) -> void:
	match String(payload.get("kind", "")):
		LevelUp.KIND_NEW_WEAPON, LevelUp.KIND_WEAPON_UP, LevelUp.KIND_PASSIVE, \
		LevelUp.KIND_GRADE_UP:
			_apply_level_up_choice(payload)
		LevelUp.KIND_MOD:
			var mod: Dictionary = payload.get("mod", {})
			_run_state.inventory = Loot.spend(
				_run_state.inventory, String(mod.get("loot_id", ""))
			)
			_apply_weapon_mod(mod)
		_:
			push_error("stage: unknown popup payload " + str(payload))
	# N5-5: a chest reward screen consumes no pending level-up.
	if _chest_showing:
		_chest_showing = false
	else:
		_pending_level_ups -= 1
	_advance_popup_queue()


func _apply_level_up_choice(choice: Dictionary) -> void:
	var result: Dictionary = LevelUp.apply_choice(choice, _owned_levels, _passive_stacks)
	_owned_levels = result["owned_levels"]
	_passive_stacks = result["passive_stacks"]
	var id: String = String(choice.get("id", ""))
	match String(choice.get("kind", "")):
		LevelUp.KIND_NEW_WEAPON:
			# Seed the base grade directly — the callout is for earned raises
			# only, so a weapon whose data grade is already the top rung must
			# not fire it on acquisition. AutoWeapon.setup reads the same base.
			_owned_grades[id] = LevelUp.current_grade(id, _weapons_data, {})
			_add_weapon_node(id)
		LevelUp.KIND_WEAPON_UP:
			(_weapon_nodes[id] as AutoWeapon).set_level(int(_owned_levels[id]))
		LevelUp.KIND_GRADE_UP:
			_set_owned_grade(id, WeaponGrade.next(
				_grade_ladder, LevelUp.current_grade(id, _weapons_data, _owned_grades)
			))
		LevelUp.KIND_PASSIVE:
			_apply_passive_effects(id)


## Swap the owned base weapon node for the recipe result, carrying its level.
## N4-2: the run grade carries too (GDD §33), floored at the result weapon's
## own base grade — a mod can raise the grade, never lower it. N4-6: the base
## weapon is banned from every future choice pool, and materials whose every
## recipe just died cash out to gold.
func _apply_weapon_mod(mod: Dictionary) -> void:
	var base_id: String = String(mod.get("weapon_id", ""))
	var result_id: String = String(mod.get("result_weapon", ""))
	var old_node: AutoWeapon = _weapon_nodes.get(base_id)
	if old_node == null:
		push_error("stage: weapon mod base '%s' has no node" % base_id)
		return
	var carried: String = WeaponGrade.highest(
		_grade_ladder,
		LevelUp.current_grade(base_id, _weapons_data, _owned_grades),
		LevelUp.current_grade(result_id, _weapons_data, {})
	)
	_owned_levels = Loot.apply_mod(_owned_levels, mod)
	_owned_grades.erase(base_id)
	_weapon_nodes.erase(base_id)
	old_node.queue_free()
	_add_weapon_node(result_id)
	(_weapon_nodes[result_id] as AutoWeapon).set_level(int(_owned_levels[result_id]))
	_set_owned_grade(result_id, carried)
	_replaced_weapons.append(base_id)
	var sweep: Dictionary = Loot.salvage_dead(
		_run_state.inventory, _loot_data, _mods_data, _owned_levels, _replaced_weapons
	)
	_run_state.inventory = sweep["inventory"]
	if int(sweep["gold"]) > 0:
		_add_gold(int(sweep["gold"]))


## Single write point for a weapon's run grade: updates the dict, retunes the
## live weapon node, and fires the one-off top-grade callout (N4-2) in the
## damage-number style the moment any weapon first reaches the top rung.
func _set_owned_grade(weapon_id: String, grade: String) -> void:
	var was_top: bool = WeaponGrade.is_top(
		_grade_ladder, String(_owned_grades.get(weapon_id, ""))
	)
	_owned_grades[weapon_id] = grade
	var node: AutoWeapon = _weapon_nodes.get(weapon_id)
	if node != null:
		node.set_grade(grade)
	if WeaponGrade.is_top(_grade_ladder, grade) and not was_top:
		_float_label("%s %s 등급!" % [
			String((_weapons_data.get(weapon_id, {}) as Dictionary).get("name_ko", weapon_id)),
			String(LevelUp.GRADE_KO.get(grade, grade)),
		])


## Non-blocking floating cue in the damage-number style — never pauses,
## never asks for input (DESIGN.md §5.2).
func _float_label(text: String) -> void:
	var number: DamageNumber = _number_pool.acquire()
	number.show_text(text, _player.global_position)


func _on_popup_dismissed() -> void:
	if _chest_showing:
		_chest_showing = false
	else:
		_pending_level_ups -= 1
	_advance_popup_queue()


## Single scheduler for every reward screen: pending level-ups first, then
## queued chest rewards, then release the pause. When the run has ended the
## result screen owns the pause — queued screens are dropped, never shown, and
## the game is never left paused behind a dead popup (N5-5 edge).
func _advance_popup_queue() -> void:
	if _outcome != RunFlow.OUTCOME_NONE:
		_pending_level_ups = 0
		_chest_pending = 0
		_chest_showing = false
		_popup.close()
		return
	if _pending_level_ups > 0:
		_show_next_level_up()
		return
	if _chest_pending > 0:
		_show_next_chest_reward()
		return
	_chest_batch_total = 0
	_chest_batch_index = 0
	_popup.close()
	get_tree().paused = false


func _add_weapon_node(weapon_id: String) -> void:
	# N5-4: owning a weapon is its discovery — covers the starting weapon,
	# level-up picks and mod results (a completed mod) through one funnel.
	_record_discovery(Bestiary.KIND_WEAPONS, weapon_id)
	var weapon := AutoWeapon.new()
	add_child(weapon)
	weapon.setup(weapon_id, _player, _spawner, _meta_effects)
	weapon.hit_landed.connect(_on_hit_landed)
	_weapon_nodes[weapon_id] = weapon
	_refresh_weapon_scales()


func _passive_bonus(passive_id: String) -> float:
	var per_stack: float = float(
		(_passives_data.get(passive_id, {}) as Dictionary).get("per_stack", 0.0)
	)
	return per_stack * float(_passive_stacks.get(passive_id, 0))


## N9-3e: live build snapshot for the pause overlay (CombatHud.build_provider).
## N9-9 adds the evolution paths open to the current build — the owner
## reported the talisman branch tree was invisible in-run.
func _pause_build_summary() -> Dictionary:
	var weapons: Array[Dictionary] = []
	for weapon_id: String in _owned_levels:
		# N9-27: grade travels with the weapon here. Picking 등급↑ used to change
		# something the player had no way to see afterwards.
		var grade: String = LevelUp.current_grade(weapon_id, _weapons_data, _owned_grades)
		weapons.append({
			"id": weapon_id,
			"name": String((_weapons_data.get(weapon_id, {}) as Dictionary).get("name_ko", weapon_id)),
			"level": int(_owned_levels[weapon_id]),
			"grade": grade,
			"grade_ko": String(LevelUp.GRADE_KO.get(grade, LevelUp.DEFAULT_GRADE_KO)),
		})
	var passives: Array[Dictionary] = []
	for passive_id: String in _passive_stacks:
		var stacks: int = int(_passive_stacks[passive_id])
		if stacks <= 0:
			continue
		var passive: Dictionary = _passives_data.get(passive_id, {})
		passives.append({
			"name": String(passive.get("name_ko", passive_id)),
			"stacks": stacks,
			"max": int(passive.get("max_stacks", 0)),
		})
	return {
		"weapons": weapons, "passives": passives,
		"stats": _pause_stat_lines(),
		"evolutions": _evolution_lines(),
	}


## N9-25: the character sheet the pause screen shows. Every line is read from
## the SAME expression combat uses (_refresh_run_scalars / _refresh_weapon_
## scales) rather than recomputed here — a second copy of the arithmetic would
## drift from the real numbers the moment either side is tuned.
## `modified` marks a line that a passive or the meta tree has moved off its
## base, so the panel can highlight what this run actually built.
func _pause_stat_lines() -> Array[Dictionary]:
	var move: float = 1.0 + _passive_bonus("move_speed") + _meta_bonus("move_speed")
	var damage: float = 1.0 + _passive_bonus("attack_damage") + _meta_bonus("attack_damage")
	var attack_speed: float = 1.0 + _passive_bonus("attack_speed") + _meta_bonus("attack_speed")
	var defense: float = _meta_bonus("damage_reduction") + _passive_bonus("defense")
	var magnet: float = 1.0 + _passive_bonus("magnet_radius") + _meta_bonus("magnet_radius")
	var projectile_speed: float = 1.0 + _passive_bonus("projectile_speed")
	var extra_projectiles: int = int(round(_passive_bonus("projectile_count")))
	var crit_chance: float = _passive_bonus("crit_chance")
	var crit_multiplier: float = CRIT_MULTIPLIER + _passive_bonus("crit_damage")
	var xp_gain: float = 1.0 + _meta_bonus("xp_gain") + _passive_bonus("xp_gain")
	var luck: float = _meta_bonus("luck") + _passive_bonus("luck")
	# The damage floor is the one applied in _refresh_run_scalars; showing the
	# raw sum would promise a reduction the player does not actually get.
	var applied_defense: float = 1.0 - maxf(1.0 - defense, 0.5)
	return [
		# Health is always in ink: it is the one line a player checks mid-run,
		# not a modifier that is interesting only when something moved it.
		_stat_line("체력", "%d/%d" % [ceili(_player.hp), ceili(_player.hp_max)], true),
		_stat_line("이동 속도", "%d" % roundi(_player.load_move_speed() * move), move != 1.0),
		_stat_line("공격력", "%d%%" % roundi(damage * 100.0), damage != 1.0),
		_stat_line("공격 속도", "%d%%" % roundi(attack_speed * 100.0), attack_speed != 1.0),
		_stat_line("치명타 확률", "%d%%" % roundi(crit_chance * 100.0), crit_chance > 0.0),
		_stat_line("치명타 피해", "x%.1f" % crit_multiplier, crit_multiplier != CRIT_MULTIPLIER),
		_stat_line("투사체", "+%d" % extra_projectiles, extra_projectiles > 0),
		_stat_line("투사체 속도", "%d%%" % roundi(projectile_speed * 100.0),
			projectile_speed != 1.0),
		_stat_line("피해 감소", "%d%%" % roundi(applied_defense * 100.0), applied_defense > 0.0),
		_stat_line("자석 범위", "%d%%" % roundi(magnet * 100.0), magnet != 1.0),
		_stat_line("경험치 획득", "%d%%" % roundi(xp_gain * 100.0), xp_gain != 1.0),
		_stat_line("행운", "+%d%%" % roundi(luck * 100.0), luck > 0.0),
	]


func _stat_line(stat_name: String, value: String, modified: bool) -> Dictionary:
	return {"name": stat_name, "value": value, "modified": modified}


## One line per recipe an OWNED weapon can still take: base → result with
## the material's name and whether it is in the run inventory right now.
func _evolution_lines() -> Array[String]:
	var lines: Array[String] = []
	for mod_id: String in _mods_data:
		var mod: Dictionary = _mods_data[mod_id]
		var base_id: String = String(mod.get("weapon_id", ""))
		var result_id: String = String(mod.get("result_weapon", ""))
		if not _owned_levels.has(base_id):
			continue
		if _owned_levels.has(result_id) or _replaced_weapons.has(result_id):
			continue
		var loot_id: String = String(mod.get("loot_id", ""))
		var held: bool = int(_run_state.inventory.get(loot_id, 0)) > 0
		# N9-23: the gate moved to Lv.5, so the line has to say what is still
		# missing — holding the material with the level unmet used to read as a
		# ✓ that never produced a card.
		var need: int = int(mod.get("level_required", 1))
		var level: int = int(_owned_levels[base_id])
		var gate: String = "" if level >= need else "  Lv.%d 필요" % need
		lines.append("%s → %s · %s%s%s" % [
			String((_weapons_data.get(base_id, {}) as Dictionary).get("name_ko", base_id)),
			String((_weapons_data.get(result_id, {}) as Dictionary).get("name_ko", result_id)),
			String((_loot_data.get(loot_id, {}) as Dictionary).get("name_ko", loot_id)),
			" ✓" if held else " 필요",
			gate,
		])
	return lines


func _meta_bonus(stat: String) -> float:
	return float(_meta_effects.get(stat, 0.0))


## N7-2 재물안: every run gold gain routes through here so the gold_gain meta
## bonus applies uniformly (kills, salvage, dead-material cash-outs).
## Returns the amount actually gained for cue labels.
func _add_gold(amount: int) -> int:
	var gained: int = int(round(
		float(amount) * (1.0 + _meta_bonus("gold_gain"))
		* Difficulty.reward_mult(_tier, _run_length, "gold_mult")
	))
	_gold += gained
	_hud.set_gold(_gold)
	return gained


## Recompute every run-wide passive effect from the stack counts, then apply
## the one-shot effects for the stack that was just gained.
func _apply_passive_effects(gained_id: String) -> void:
	_refresh_run_scalars()
	# Max HP has no separate cap yet; each stack grants its slice of base HP.
	if gained_id == "max_hp":
		var per_stack: float = float(
			(_passives_data.get("max_hp", {}) as Dictionary).get("per_stack", 0.0)
		)
		var grant: float = Player.load_base_hp() * per_stack
		_player.hp += grant
		_player.hp_max += grant


## Every run-wide scalar recomputed from its data base, so neither passive
## stacks nor the meta bonus can ever compound with themselves.
func _refresh_run_scalars() -> void:
	_refresh_weapon_scales()
	_player.set_speed_scale(
		1.0 + _passive_bonus("move_speed") + _meta_bonus("move_speed")
	)
	# N9-3g 방비 passive joins the 철피 meta reduction; floored at taking 50%
	# so no future stat combo can approach immunity.
	_player.set_damage_taken_scale(maxf(
		1.0 - _meta_bonus("damage_reduction") - _passive_bonus("defense"), 0.5
	))
	_orb_config = _orb_config_base.duplicate()
	_orb_config["magnet_radius_px"] = (
		float(_orb_config_base.get("magnet_radius_px", 0.0))
		* (1.0 + _passive_bonus("magnet_radius") + _meta_bonus("magnet_radius"))
	)


func _refresh_weapon_scales() -> void:
	var damage_scale: float = 1.0 + _passive_bonus("attack_damage") + _meta_bonus("attack_damage")
	var cooldown_scale: float = 1.0 / (
		1.0 + _passive_bonus("attack_speed") + _meta_bonus("attack_speed")
	)
	var speed_scale: float = 1.0 + _passive_bonus("projectile_speed")
	var extra_projectiles: int = int(round(_passive_bonus("projectile_count")))
	# N9-18/N9-19 치명타: chance from 치명타 확률, multiplier from the base
	# x2 plus every 치명 일격 stack.
	var crit_chance: float = _passive_bonus("crit_chance")
	var crit_multiplier: float = CRIT_MULTIPLIER + _passive_bonus("crit_damage")
	for weapon_id: String in _weapon_nodes:
		var weapon: AutoWeapon = _weapon_nodes[weapon_id]
		weapon.set_scales(damage_scale, cooldown_scale, speed_scale)
		weapon.set_extra_projectiles(extra_projectiles)
		# N9-27: grade is a per-WEAPON crit specialisation on top of the run-wide
		# passive crit, which is what makes it a different question from level
		# rather than a second copy of it.
		var base_grade: String = String(
			(_weapons_data.get(weapon_id, {}) as Dictionary).get("grade", "")
		)
		var grade: String = LevelUp.current_grade(weapon_id, _weapons_data, _owned_grades)
		weapon.set_crit(
			crit_chance + WeaponGrade.bonus(
				_grades_config, base_grade, grade, "crit_chance"
			),
			crit_multiplier + WeaponGrade.bonus(
				_grades_config, base_grade, grade, "crit_damage"
			)
		)


func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_error("stage: cannot parse " + path)
		return {}
	return data


## True when the first elite's own roll produced no special and the data asks
## for the floor. A roll that already dropped one needs no help.
func _first_elite_guarantee_due(drops: Array[String]) -> bool:
	var config: Dictionary = _drop_tables.get("_config", {})
	if not bool(config.get("first_elite_special", false)):
		return false
	for loot_id: String in drops:
		if bool((_loot_data.get(loot_id, {}) as Dictionary).get("special", false)):
			return false
	return true


## Roll the dead monster's drop table and scatter tier-tinted drops around
## the corpse so they never hide under the XP orb.
func _spawn_loot(enemy: Enemy) -> void:
	var table: Dictionary = _drop_tables.get(enemy.monster_id, {})
	# N4-9 천운 + N9-3 행운 passive: both luck sources scale special-material
	# odds only, through the same capped multiplier inside Loot.roll_drops.
	var drops: Array[String] = Loot.roll_drops(
		table, _loot_rng, _loot_data, _meta_bonus("luck") + _passive_bonus("luck")
	)
	# N6-1 scripted first run: any overdue guarantee rides the next kill; a
	# natural drop of the same loot earlier satisfies it via _first_run_log.
	drops.append_array(Ftue.due_guarantees(_first_run_drops, _run_elapsed, _first_run_log))
	if enemy.is_elite and not _first_elite_resolved:
		_first_elite_resolved = true
		if _first_elite_guarantee_due(drops):
			var granted: String = Loot.weighted_special(table, _loot_rng, _loot_data)
			if not granted.is_empty():
				drops.append(granted)
	for loot_id: String in drops:
		# Boss drops land as the run ends — a trophy, not evolution currency —
		# so the rarity metric counts only specials a build can still use.
		if not enemy.is_boss \
				and bool((_loot_data.get(loot_id, {}) as Dictionary).get("special", false)):
			_special_drop_times.append(_run_elapsed)
		var at: Vector2 = enemy.global_position
		if Ftue.is_guaranteed(_first_run_drops, loot_id) and not _first_run_log.has(loot_id):
			_first_run_log[loot_id] = _run_elapsed
			# N6-2: place the scripted guarantee ahead of the player's travel
			# direction, clamped to the field — seen and walked toward, never
			# landing in their lap at the corpse.
			if _guarantee_offset_px > 0.0:
				at = _player.global_position + _player.last_move_direction * _guarantee_offset_px
				if _player.bounds.has_area():
					at = at.clamp(_player.bounds.position, _player.bounds.end)
		var drop: LootDrop = _loot_pool.acquire()
		var scatter := Vector2(
			_loot_rng.randf_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX),
			_loot_rng.randf_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX)
		)
		drop.launch_loot(
			at + scatter, loot_id,
			Loot.tier_color(_loot_data, loot_id), _player, _orb_config
		)


## N4-6: every material collects silently, exactly like XP and gold. Useful
## ones (a live recipe exists) bank into the run inventory; dead ones cash
## out to gold on the spot — the player never holds dead inventory. Special
## materials float a small cue label; commons just tick the counters.
func _on_loot_collected(orb: XpOrb) -> void:
	var loot_id: String = (orb as LootDrop).loot_id
	_loot_pool.release(orb)
	_record_discovery(Bestiary.KIND_LOOT, loot_id)
	var stats: Dictionary = _loot_data.get(loot_id, {})
	if Loot.is_material_useful(loot_id, _mods_data, _owned_levels, _replaced_weapons):
		_run_state.inventory = Loot.add(_run_state.inventory, loot_id)
		if bool(stats.get("special", false)):
			# N9-18 (owner report: "도깨비불을 얻었는데 진화가 안 나온다"):
			# a special material is banked long before its recipe unlocks —
			# the card needs the BASE weapon at level_required. Say which
			# level is still missing instead of a silent "획득".
			_float_label(_material_cue(loot_id, String(stats.get("name_ko", loot_id))))
		return
	var gained: int = _add_gold(Loot.salvage_gold(_loot_data, loot_id))
	if bool(stats.get("special", false)):
		_float_label("+%d냥" % gained)


## N9-18: cue text for a banked special material — either "ready" or the
## exact base weapon + level the evolution card is still waiting on. Picks
## the closest recipe (fewest levels missing) when several match.
## N10-1a: the shadow's rule, stated once per run at the moment it matters.
func _on_shadow_spawned(enemy: Enemy) -> void:
	_float_label("%s — 빛 안에서만 벨 수 있다" % enemy.name_ko)


func _material_cue(loot_id: String, loot_name: String) -> String:
	var best_gap: int = -1
	var best_line: String = ""
	for mod_id: String in _mods_data:
		var mod: Dictionary = _mods_data[mod_id]
		if String(mod.get("loot_id", "")) != loot_id:
			continue
		var base_id: String = String(mod.get("weapon_id", ""))
		var result_id: String = String(mod.get("result_weapon", ""))
		if not _owned_levels.has(base_id):
			continue
		if _owned_levels.has(result_id) or _replaced_weapons.has(result_id):
			continue
		var need: int = int(mod.get("level_required", 1))
		var gap: int = need - int(_owned_levels[base_id])
		if gap <= 0:
			return "%s · 개조 준비 완료!" % loot_name
		if best_gap < 0 or gap < best_gap:
			best_gap = gap
			best_line = "%s · %s Lv.%d에서 개조" % [
				loot_name,
				String((_weapons_data.get(base_id, {}) as Dictionary).get("name_ko", base_id)),
				need,
			]
	return best_line if not best_line.is_empty() else "%s 획득" % loot_name


## N5-5 destructible feedback: the shared pooled puff at the prop's footprint,
## then one roll on the data table — most breaks give nothing or small gold on
## purpose; the exciting kinds stay uncommon (validator-enforced shares).
func _on_breakable_broke(breakable: Breakable) -> void:
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		breakable.global_position,
		breakable.hit_radius * float(_feedback.get("death_puff_radius_scale", 1.0)),
		float(_feedback.get("death_puff_sec", 0.0))
	)
	var kind: String = Pickups.roll_break(_pickups_data, _loot_rng)
	_break_stats[kind] = int(_break_stats.get(kind, 0)) + 1
	if kind == Pickups.KIND_NOTHING:
		return
	var pickup: Pickup = _pickup_pool.acquire()
	pickup.launch_pickup(breakable.global_position, kind, _player, _orb_config)


## N5-5 pickup effects, each applied at collection so the player walked to it.
## HEALTH at full HP converts to gold (chosen rule: the drop is never wasted,
## and the check runs at collection time so getting hit on the way still heals).
func _on_pickup_collected(orb: XpOrb) -> void:
	var kind: String = (orb as Pickup).kind
	_pickup_pool.release(orb)
	match kind:
		Pickups.KIND_GOLD:
			var gained: int = _add_gold(
				int((_pickups_data.get("gold", {}) as Dictionary).get("amount", 0))
			)
			_float_label("+%d냥" % gained)
		Pickups.KIND_HEALTH:
			_collect_health()
		Pickups.KIND_NUKE:
			_execute_nuke()
		Pickups.KIND_MAGNET:
			_execute_magnet()


func _collect_health() -> void:
	var health: Dictionary = _pickups_data.get("health", {})
	if _player.hp >= _player.hp_max:
		var gained: int = _add_gold(int(health.get("full_hp_gold", 0)))
		_float_label("+%d냥" % gained)
		return
	_heal_player(float(health.get("hp_ratio", 0.0)))


## N6-3 single heal path (health pickup, elite kill): ratio of max HP, capped
## at full, with the float label + green pulse so the heal reads in a crowd
## (N3-18 grammar). Already-full or zero-ratio heals do nothing silently.
func _heal_player(hp_ratio: float) -> void:
	if hp_ratio <= 0.0 or _player.hp >= _player.hp_max:
		return
	var heal: float = minf(_player.hp_max * hp_ratio, _player.hp_max - _player.hp)
	_player.hp += heal
	_heal_events += 1
	_heal_total += heal
	_float_label("회복 +%d" % int(round(heal)))
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		_player.global_position, Player.CONTACT_RADIUS * 2.0,
		float(_feedback.get("death_puff_sec", 0.0)), UiPalette.SUCCESS
	)


## NUKE: full data damage to every ON-SCREEN trash enemy, capped damage to
## elites and the boss (data elite_boss_damage) so a set-piece fight can never
## be one-shot by a lucky pot. Reuses the 벽사진 wave-ring + screen-flash
## vocabulary in VERMILION so the payoff reads full-screen.
func _execute_nuke() -> void:
	var origin: Vector2 = _player.global_position
	var ring: BlastRing = _burst_ring_pool.acquire()
	ring.burst(
		origin, float((_pickups_data.get("nuke", {}) as Dictionary).get("ring_radius_px", 0.0)),
		WeaponEffects.value("burst_ring_sec"), UiPalette.VERMILION, BlastRing.Style.WAVE
	)
	_hud.flash_screen(UiPalette.VERMILION, WeaponEffects.value("screen_flash_sec"))
	# Collect refs first: killing mutates the spawner's active list.
	var caught: Array[Enemy] = _spawner.active_enemies().duplicate()
	var view_size: Vector2 = get_viewport_rect().size
	for enemy: Enemy in caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		if CombatMath.outside_view(enemy.global_position, origin, view_size, 0.0):
			continue  # "everything on screen", literally — offscreen waves survive
		var capped: bool = enemy.is_boss or enemy.is_elite
		var damage: float = Pickups.nuke_damage(_pickups_data, capped)
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(damage, CombatMath.chase_direction(origin, hit_at))
		_on_hit_landed(damage, hit_at, boss_hit)


## MAGNET: every uncollected orb, material and pickup on the field flies in at
## once. An empty field still shows the ring + label — never a dead tap.
func _execute_magnet() -> void:
	var ring: BlastRing = _burst_ring_pool.acquire()
	ring.burst(
		_player.global_position,
		float((_pickups_data.get("magnet", {}) as Dictionary).get("ring_radius_px", 0.0)),
		WeaponEffects.value("burst_ring_sec"), UiPalette.LOOT_RARE, BlastRing.Style.WAVE
	)
	_float_label("자석!")
	for child: Node in get_children():
		if child is XpOrb and (child as XpOrb).visible:
			(child as XpOrb).attract_now()


## N5-5 chest open: roll the reward count against luck, then queue that many
## reward screens. Rewards are drawn one at a time at show time (never here),
## so every card is legal against the state the previous reward produced. A
## chest opened after the run ended is deliberately discarded — the run is
## banked, the result screen owns the game.
func _on_chest_opened(chest: Chest) -> void:
	_chest_pool.release(chest)
	if _outcome != RunFlow.OUTCOME_NONE:
		return
	var count: int = Pickups.roll_chest_count(
		_pickups_data.get("chest", {}), _meta_bonus("luck"), _loot_rng
	)
	_chest_counts.append(count)
	_chest_pending += count
	_chest_batch_total += count
	if not _popup.visible:
		_advance_popup_queue()


## One chest reward screen: a single card drawn fresh through the level-up
## pool machinery (same legality rules — dedupe, evolution_only, replaced
## exclusions). N9-5d (owner direction): chests only STRENGTHEN what the
## build already has — weapon level/grade raises and passives; new weapons
## and 개조 stay level-up exclusives. A dry pool pays out the data
## fallback gold instead.
func _show_next_chest_reward() -> void:
	_chest_pending -= 1
	_chest_batch_index += 1
	var pool: Array[Dictionary] = LevelUp.candidates(
		_weapons_data, _passives_data, _owned_levels, _passive_stacks,
		_owned_grades, _grades_config, _replaced_weapons, _weapon_categories
	)
	# Owner direction: a chest only deepens what the run already has; new
	# skills belong to the level-up screen. The weapon half of that shipped in
	# N5-5, but a passive at zero stacks is just as new and slipped through —
	# owner report N9-41. Both are excluded by asking whether the build already
	# holds the subject, rather than by listing kinds, so a future card kind
	# cannot reopen the same hole.
	var owned_only: Array[Dictionary] = []
	for choice: Dictionary in pool:
		var id: String = String(choice.get("id", ""))
		match String(choice.get("kind", "")):
			LevelUp.KIND_NEW_WEAPON:
				continue
			LevelUp.KIND_PASSIVE:
				if int(_passive_stacks.get(id, 0)) <= 0:
					continue
		owned_only.append(choice)
	var rewards: Array[Dictionary] = LevelUp.assemble(owned_only, [], 1, _choice_rng)
	if rewards.is_empty():
		var gained: int = _add_gold(
			int((_pickups_data.get("chest", {}) as Dictionary).get("fallback_gold", 0))
		)
		_float_label("+%d냥" % gained)
		_advance_popup_queue()
		return
	get_tree().paused = true
	_chest_showing = true
	var masked: Array[String] = _unknown_mod_results(rewards)
	var cards: Array[Dictionary] = [LevelUp.as_card(
		rewards[0], _weapons_data, _passives_data, _owned_levels, _passive_stacks,
		_owned_grades, _grades_config, masked
	)]
	_popup.open(
		CHEST_HEADER % [_chest_batch_index, _chest_batch_total],
		cards, _owned_levels, _weapons_data
	)


func _create_pickup() -> Pickup:
	var pickup := Pickup.new()
	pickup.collected.connect(_on_pickup_collected)
	return pickup


func _create_chest() -> Chest:
	var chest := Chest.new()
	chest.opened.connect(_on_chest_opened)
	return chest


func _create_loot_drop() -> LootDrop:
	var drop := LootDrop.new()
	drop.collected.connect(_on_loot_collected)
	return drop


func _create_orb() -> XpOrb:
	var orb := XpOrb.new()
	orb.collected.connect(_on_orb_collected)
	return orb


func _create_damage_number() -> DamageNumber:
	var number := DamageNumber.new()
	number.finished.connect(_on_number_finished)
	return number


func _blink_puff(at: Vector2) -> void:
	# N3-18: mist tinted WEAPON_SOUL — the N3-17 ACCENT_TAOIST modulate turned
	# the white smoke sheet near-black on the night ground, so the step
	# vanished. Pale soul-blue reads at both ends of the jump.
	if _fx_pool != null:
		var sprite: EffectSprite = _fx_pool.acquire()
		sprite.play_effect("blink_puff", at, 0.0, UiPalette.WEAPON_SOUL)
		return
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		at, Player.CONTACT_RADIUS * 2.0,
		WeaponEffects.value("blink_puff_sec"), UiPalette.WEAPON_SOUL
	)


func _create_effect_sprite() -> EffectSprite:
	var sprite := EffectSprite.new()
	sprite.finished_effect.connect(
		func(done: EffectSprite) -> void: _fx_pool.release(done)
	)
	return sprite


func _create_burst_ring() -> BlastRing:
	var ring := BlastRing.new()
	ring.finished.connect(
		func(done: BlastRing) -> void: _burst_ring_pool.release(done)
	)
	return ring


func _create_puff() -> DeathPuff:
	var puff := DeathPuff.new()
	puff.finished.connect(
		func(done: DeathPuff) -> void: _puff_pool.release(done)
	)
	return puff
