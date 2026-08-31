class_name Stage
extends Node2D
## Combat stage root (N3-1). Ground and props render the AC-4 night-bamboo-
## forest art (N3-10) via Ground/StageField, falling back to palette-token
## placeholders when a texture is missing.

## N9-115 (owner: 핸드폰으로 보니 애셋이 전부 좀 작다): the whole field renders
## slightly magnified. Every zoom write in the run (shockwave punch, resets)
## multiplies from this base, never from 1.0.
const CAMERA_BASE_ZOOM := 1.15
## N9-152: the design viewport; wide/tall aspects zoom so the visible WORLD
## AREA stays what the portrait design shows — landscape trades height for
## width instead of shrinking every figure (owner: 캐릭터가 너무 작아 보인다).
const DESIGN_VIEWPORT := Vector2(540.0, 960.0)


## Camera zoom for the current viewport: area-constant against the design.
static func camera_zoom_for(viewport_size: Vector2) -> float:
	var design_area: float = DESIGN_VIEWPORT.x * DESIGN_VIEWPORT.y
	var area: float = maxf(viewport_size.x * viewport_size.y, 1.0)
	return CAMERA_BASE_ZOOM * sqrt(area / design_area)


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
## N9-95: radius of the gold wave that marks an evolution landing.
const EVOLUTION_RING_PX := 170.0
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
var _bestiary_start_count: int = 0
var _orb_config: Dictionary = {}
var _orb_config_base: Dictionary = {}
## Live (uncollected) XP orbs, for the N11 live_cap merge. Erased on collect.
var _live_orbs: Array[XpOrb] = []
## N10-5: how much of one level-up screen is weapon cards, from progression.json.
var _weapon_card_share: float = LevelUp.DEFAULT_WEAPON_CARD_SHARE
## N10-12: the selected character's permanent trait, empty when it declares none.
var _innate: Dictionary = {}

# N3-6 run build state: weapon levels, passive stacks and their nodes/effects.
var _weapons_data: Dictionary = {}
var _passives_data: Dictionary = {}
var _owned_levels: Dictionary = {}
var _passive_stacks: Dictionary = {}
var _weapon_categories: Array = []
## N11-20 빌드: families the camp opened, weighted up in the level-up pool.
var _favoured_families: Array[String] = []
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
## N9-55 field passives: seconds until the next one is placed, and the ones
## currently lying on the map (tracked so the cap counts what is actually out
## there, not how many have ever been spawned).
var _field_passive_wait: float = 0.0
var _live_field_passives: Array[Pickup] = []
## N10-1a: passives that left the field in a thief's hands. Read by
## tools/thief_check.tscn, which otherwise cannot tell the designed escape from
## the generic off-screen cull — the two used to look identical from outside.
var thefts_lost: int = 0
## Lifetime count, for the harness: a run that places none has the feature
## switched off in all but name, and nothing else would say so.
var _field_passives_placed: int = 0
## N9-57: edge arrows for the drops that are deliberately off-screen.
var _markers: OffscreenMarkers
## N9-59: the 지도 unlock. Null when it is not owned — the map is a purchase,
## so an unbought one must not exist at all rather than be hidden.
var _minimap: Minimap
## Seconds until the next map sweep. Blips are gathered by walking the stage's
## children, which is cheap at 5Hz and wasteful every frame.
var _minimap_wait: float = 0.0
## Top-left: the timer and bars sit above, the actives below-right, and the
## thumb lives at the bottom — this is the only corner a map does not fight
## something for.
const MINIMAP_MARGIN := 16.0
## QA B3 + Q27: the fatter XP rail pushed the Lv label to y141, and portrait
## stacks the belongings strip right under it (y144..166) — the map sits
## below whichever band its orientation actually has. Landscape's strip
## starts right of the map (x144), so only the label row matters there.
const MINIMAP_TOP := 148.0
## F7: two belongings lines end at y192 — one line was all 176 cleared.
const MINIMAP_TOP_PORTRAIT := 200.0
const MINIMAP_REFRESH_SEC := 0.2
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
## N10-11 철질려: the archer's caltrop field, pooled like every other ground
## effect so a run that spams it does not allocate.
var _trap_pool: NodePool
# N3-17 art integration: pooled sprite puffs for 축지 when the sheet shipped.
var _fx_pool: NodePool
var _gold: int = 0
# N6-5: monsters no longer drop gold — the boss-kill reward from stages.json
# is the single kill-paid gold source left; everything else is destructibles,
# chests and salvage.
var _boss_gold: int = 0
var _run_elapsed: float = 0.0
var _duration_sec: float = 0.0
## N9-60: seconds until the endless night sends the boss back. Zero when none
## is pending.
var _boss_return_wait: float = 0.0
## N9-65: evolutions performed this run, folded into the career counters when
## the run banks.
var _evolutions: int = 0
## N9-67 hit feel. The hitstop deadline is in REAL milliseconds because a
## frozen world has a zero delta — a timer counted in delta would never expire
## and the freeze would be permanent.
var _hitstop_until_msec: int = 0
var _hitstop_base_scale: float = 1.0
var _shake: float = 0.0
var _shake_time: float = 0.0
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
## N11-20: the most the tree may cut off an active cooldown.
const MAX_ACTIVE_HASTE := 0.45

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
	var start_camera: Camera2D = get_node_or_null("World/Player/Camera2D")
	if start_camera != null:
		start_camera.zoom = Vector2.ONE * camera_zoom_for(get_viewport_rect().size)
	# Rotation mid-run re-derives the zoom for the new aspect (N9-152).
	get_viewport().size_changed.connect(_on_viewport_resized)
	_stage_ready_field()


## The rest of _ready, split so the resize hook sits beside its subject.
func _on_viewport_resized() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.zoom = Vector2.ONE * camera_zoom_for(get_viewport_rect().size)


func _stage_ready_field() -> void:
	var props_config: Dictionary = StageField.load_config()
	var field_config: Dictionary = props_config.get("field", {})
	_ground_size = Vector2(
		float(field_config.get("width_px", 0.0)),
		float(field_config.get("height_px", 0.0))
	)
	# N9-6 infinite field: no bounds — the ground already follows the camera
	# (N3-16) and props stream in per chunk as the player travels.
	_player.bounds = Rect2()
	# Owner: 본거지에서만 걷고 출정은 뛰어야지. A stage is the 출정 — the camp
	# leaves this false and keeps the walk.
	_player.running = true
	# randi() is auto-seeded per process start, so every run scatters a fresh
	# field layout; tests drive StageField.generate with fixed seeds instead.
	# Ground and props share one seed so a run's tiles and prop scatter match.
	var field_seed: int = randi()
	# C6: combat draws from its own stream, seeded from the same number. Crits
	# used to come off the global generator, which effects, sprite frames and orb
	# phases also draw from — so how many of those had happened by the time a
	# weapon fired decided where the crits landed, and no seed ever reproduced a
	# run. Seeding here ties the combat stream to the field seed the harness
	# already fixes with `seed(run_seed)`.
	CombatRng.seed_run(field_seed)
	_ground.build(field_config, field_seed, _spawner.stage_id())
	_field.build(
		props_config.get("props", {}) as Dictionary, field_config, _decor_layer, field_seed
	)
	_field_seed = field_seed
	_props_catalog = props_config.get("props", {})
	_field_config = field_config
	# N11-2: hand the enemies this run's solid grid — their manual prop
	# contact (no physics bodies). Static because every live enemy shares
	# one field; each stage build overwrites it with its own grid.
	Enemy.solids = _field.solids_grid
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
	_spawner.setup(_player, _field_seed)
	_spawner.enemy_killed.connect(_on_enemy_killed)
	# 화약 도깨비 (N9-165): the same telegraph the boss uses draws the fuse, so
	# a warning circle means one thing in this game no matter who lit it.
	_spawner.enemy_fuse_lit.connect(_on_enemy_fuse_lit)
	_spawner.enemy_detonated.connect(_on_enemy_detonated)
	_spawner.enemy_part_broken.connect(_on_enemy_part_broken)
	_spawner.enemy_part_blocked.connect(_on_enemy_part_blocked)
	_spawner.boss_spawned.connect(_on_boss_spawned)
	_spawner.shadow_spawned.connect(_on_shadow_spawned)
	# N9-1a: the stage id IS the track id, so a second region ships its own
	# music by adding one entry to data/audio.json and nothing else.
	if MusicService.instance != null:
		MusicService.instance.play(Spawner.stage_id())
	# N4-4a: burn ticks float through the same damage-number pool as hits.
	_spawner.burn_damaged.connect(
		func(amount: float, at: Vector2) -> void: _on_hit_landed(amount, at, false)
	)
	_feedback = _load_json(Spawner.EFFECTS_PATH).get("hit_feedback", {})
	# N11-3b: what the night ADDS to the 괴이록 is part of what it pays —
	# snapshot the record size so the result screen can count the new pages.
	_bestiary_start_count = _bestiary_count()
	var stage_entry: Dictionary = _load_json(Spawner.STAGES_PATH).get(Spawner.stage_id(), {})
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
	_trap_pool = NodePool.new(self, _create_trap_ward)
	if EffectSprite.available("blink_puff"):
		_fx_pool = NodePool.new(self, _create_effect_sprite)
	_result = ResultScreen.new()
	add_child(_result)
	_run_state = RunState.new()
	# 삼두구미 (N10-3b): the pouch is handed over by reference AFTER it exists —
	# wiring it beside the other spawner signals read fine and ran on a null.
	_spawner.held_materials = _run_state.inventory
	_run_state.level_reached.connect(_on_level_reached)
	_orb_config_base = RunState.load_orb_config()
	_orb_config = _orb_config_base.duplicate()
	_weapon_card_share = float(RunState.load_level_up_config().get(
		"weapon_card_share", LevelUp.DEFAULT_WEAPON_CARD_SHARE
	))
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
	# N11-20b: the camp's family upgrades ride along under a reserved key, so
	# a weapon's setup still takes one dictionary.
	_meta_effects["_families"] = MetaTree.family_effects(
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
	# N11-4: a run only sees recipes the smithy has unlocked. Harness
	# profiles waive the gate so playtest bots and QA fixtures still
	# exercise 개조 without grinding the camp first.
	if SaveService.instance != null:
		_mods_data = Smithy.runtime_mods(
			_mods_data, SaveService.instance.profile,
			SaveService.instance.is_harness_profile()
		)
	_loot_pool = NodePool.new(self, _create_loot_drop)
	# C6: this used to call randomize(), which reads OS entropy and ignores the
	# run seed entirely — the comment here claimed one seed replayed a run's
	# drops and it never did. Seeded from the field seed, it now does.
	_loot_rng.seed = _field_seed
	# N5-5: destructible props + pickups + elite chests. The spawner carries
	# the breakable list because it is the target registry weapons already hold.
	_pickups_data = _load_json(PICKUPS_PATH)
	_pickup_pool = NodePool.new(self, _create_pickup)
	_chest_pool = NodePool.new(self, _create_chest)
	_spawner.breakables = _field.breakables
	# Same array reference: chunks appending lights are seen without rewiring.
	_spawner.lights = _field.lights
	_spawner.light_grid = _field.light_grid
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
	# N11-19c 그림자 걸음: 초희's odds of turning a hit aside entirely.
	_player.set_dodge_chance(_meta_bonus("dodge_chance"))
	_popup = LevelUpPopup.new()
	_popup.picked.connect(_on_choice_picked)
	_popup.dismissed.connect(_on_popup_dismissed)
	add_child(_popup)
	_hud.set_gold(0)  # run gold; banked into the profile at run end (N5-2)
	# N9-5d weapon identity: the level-up pool only offers new weapons from
	# the selected character's categories (도사 gets no 각궁).
	_weapon_categories = Player.load_weapon_categories()
	# N11-20: the builds the camp has opened weight this run's card pool.
	_favoured_families = MetaTree.unlocked_families(
		MetaTree.load_tree(),
		_profile().get("meta_tree", {}) as Dictionary,
		Player.character_id()
	)
	_actives = Player.load_actives()
	_innate = Player.load_innate()
	for active: Dictionary in _actives:
		_active_cooldowns[String(active.get("id", ""))] = 0.0
	_hud.build_actives(_actives)
	_hud.active_pressed.connect(_on_active_pressed)
	# N9-3e: the pause overlay pulls the live build on every open.
	_hud.build_provider = _pause_build_summary
	# B0-1: draw the row once at spawn so the starting weapon and the three
	# empty slots are visible before the first level-up.
	_refresh_belongings()
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
	# N9-104: record that the tutorial sortie began, so quitting mid-run does
	# not send the next launch straight back into the stage (title routing).
	if (
		Ftue.is_first_run(profile)
		and not Ftue.has_started_first_sortie(profile)
		and SaveService.instance != null
	):
		SaveService.instance.mark_first_sortie_started()
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
	# N11-19 길눈: the night opens with material already in the pouch, so a
	# mod can be reachable before the first elite falls.
	_grant_start_materials(int(_meta_bonus("start_material")))


## N11-19 길눈: seeds the run inventory with common materials the region can
## actually drop, so the grant reads as "found on the way in" rather than as
## an item out of nowhere.
func _grant_start_materials(count: int) -> void:
	if count <= 0:
		return
	var ids: Array[String] = []
	for loot_id: String in _loot_data:
		if not bool((_loot_data[loot_id] as Dictionary).get("special", false)):
			ids.append(loot_id)
	if ids.is_empty():
		return
	ids.sort()
	for i: int in count:
		var pick: String = ids[_loot_rng.randi_range(0, ids.size() - 1)]
		_run_state.inventory[pick] = int(_run_state.inventory.get(pick, 0)) + 1


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
	_tick_field_passives(delta)
	_tick_thieves()
	_tick_minimap(delta)
	_tick_impact(delta)
	_tick_breakable_cull(delta)
	_refresh_hp_hud()
	_stream_field_chunks()
	_tick_boss_return(delta)
	if _duration_sec > 0.0 and not _spawner.is_endless_run() 			and _run_elapsed >= _duration_sec:
		_end_run(RunFlow.resolve_outcome(
			false, false, true, _spawner.boss_unfinished(_boss)
		))
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
		_float_label(UiLocale.t("회생부 발동!"))
		return
	_end_run(RunFlow.resolve_outcome(true, false, false))


## N3-8: the invulnerability blink lives on the player; the HUD adds the
## screen-edge red pulse so a hit is legible even off-center.
func _on_player_hit() -> void:
	_play_sfx("hurt")
	_hud.pulse_damage(float(_feedback.get("player_vignette_sec", 0.0)))


## The enemy reference is only valid during this synchronous call — it goes
## back to its pool right after (see Spawner.enemy_killed).
func _on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	# N9-36: "부적은 알아서 날아간다" is a claim; a 괴이 falling to it is the
	# proof, so that page advances on a kill rather than on a tap.
	if _guide != null:
		_guide.notify_action(Ftue.AWAIT_KILL)
	_play_sfx("kill")
	_punch(Impact.ELITE_KILL if enemy.is_elite or enemy.is_boss else Impact.KILL)
	_record_discovery(Bestiary.KIND_MONSTERS, enemy.monster_id)
	_hud.set_kills(_kills)
	var puff: DeathPuff = _puff_pool.acquire()
	puff.puff(
		enemy.global_position,
		enemy.contact_radius * float(_feedback.get("death_puff_radius_scale", 1.0)),
		float(_feedback.get("death_puff_sec", 0.0))
	)
	_spawn_xp_orb(enemy.global_position, enemy.xp_drop)
	_drop_stolen_passive(enemy)
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
		_play_sfx("boss_down")
		# N9-60: in an endless night the boss is a recurring event, not the
		# finish line. Killing it pays out and sets the next one coming; the
		# only way the run ends is the player falling.
		if _spawner.is_endless_run():
			_boss_return_wait = Endless.boss_repeat_sec(_endless_config())
			_float_label(UiLocale.t("두두리를 물리쳤다"))
			return
		_end_run(RunFlow.resolve_outcome(false, true, false), true)


## N9-60 (owner: "무한모드도 존재했으면 좋겠어"). Counts down to the next boss
## once the last one fell. Zero means nothing is pending — the boss is either
## alive or was never scheduled to return.
func _tick_boss_return(delta: float) -> void:
	if _boss_return_wait <= 0.0:
		return
	_boss_return_wait -= delta
	if _boss_return_wait > 0.0:
		return
	_boss_return_wait = 0.0
	_spawner.spawn_boss()


func _endless_config() -> Dictionary:
	return (_load_json(Spawner.STAGES_PATH) as Dictionary).get(
		Spawner.stage_id(), {}
	).get(Endless.FLAG, {})


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
	# Owner (두두리랑 밤2 보스가 공격할 때 모션 취하게): the swing plays with the
	# telegraph, not with the damage, so the wind-up is what warns you and the
	# ring is what tells you where. A monster with no attack art ignores this.
	_boss.play_attack()
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
	# The warning has to be audible: its whole job is to be reacted to, and the
	# shape can start off-screen.
	_play_sfx("boss_warn")
	var telegraph: BossTelegraph = _telegraph_pool.acquire()
	telegraph.set_meta("attack", attack)
	telegraph.warn(at, radius, inner, warn_sec, UiPalette.VERMILION)


## The eruption resolves against the player only. Boss patterns are the boss's
## own damage; they never chip the monsters standing in them, which would let a
## player farm the boss's attacks.
## The bomb lights up: a warning disc exactly the size of the blast, timed to
## the fuse. It carries no damage — the enemy's own detonation does that, so a
## bomb killed mid-fuse leaves the warning to fade with nothing behind it.
func _on_enemy_fuse_lit(enemy: Enemy, fuse_sec: float, radius_px: float) -> void:
	_play_sfx("boss_warn")
	var telegraph: BossTelegraph = _telegraph_pool.acquire()
	telegraph.set_meta("attack", {})
	telegraph.warn(
		enemy.global_position, radius_px, 0.0, fuse_sec, UiPalette.WEAPON_FIRE
	)


func _on_enemy_detonated(
	at: Vector2, radius_px: float, damage: float, name_ko: String
) -> void:
	_punch(Impact.ERUPT)
	_play_sfx("break_pot")
	if EffectSprite.available("hit_fire_talisman"):
		var sprite: EffectSprite = _fx_pool.acquire()
		sprite.play_effect("hit_fire_talisman", at, radius_px, UiPalette.WEAPON_FIRE)
	if CombatMath.blast_covers(_player.global_position.distance_to(at), radius_px):
		_player.take_hit(damage, name_ko)


func _on_telegraph_erupted(at: Vector2, radius: float, inner: float) -> void:
	# The ground opening is the heaviest beat in the fight, and it lands
	# whether or not the player was standing in it — the near miss is part of
	# what teaches the pattern.
	_punch(Impact.ERUPT)
	for child: Node in get_children():
		var telegraph := child as BossTelegraph
		if telegraph == null or not telegraph.visible or telegraph.global_position != at:
			continue
		var attack: Dictionary = telegraph.get_meta("attack", {})
		if not BossPatterns.covers(_player.global_position, at, radius, inner):
			return
		_player.take_hit(float(attack.get("damage", 0.0)), UiLocale.data_name(attack, ""))
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
		camera.zoom = Vector2.ONE * camera_zoom_for(get_viewport_rect().size)
		# N9-67: and its shake offset, or the result screen sits crooked for as
		# long as it is open — physics is paused, so nothing would decay it.
		camera.offset = Vector2.ZERO
	_shake = 0.0
	# A run that ends mid-freeze would leave the whole game stopped.
	if _hitstop_until_msec > 0:
		_hitstop_until_msec = 0
		Engine.time_scale = _hitstop_base_scale
	get_tree().paused = true
	# QA (play, BLOCKER-2): only a dead player has a killer. A defeat with the
	# player still standing is the clock arriving over a live boss, and saying
	# so is also the first place the new defeat rule is stated on screen.
	var cause: String = ""
	if CombatMath.is_dead(_player.hp):
		cause = _player.last_hit_source
	elif outcome == RunFlow.OUTCOME_DEFEAT:
		cause = RunFlow.CAUSE_BOSS_SURVIVED
	var summary: Dictionary = RunFlow.build_summary(
		_run_elapsed, _kills, _gold, cause
	)
	summary["total_gold"] = SaveService.instance.bank_run(
		_run_elapsed, _kills, _gold, boss_killed,
		{
			"victory": outcome == RunFlow.OUTCOME_VICTORY,
			"level": _run_state.level,
			"evolutions": _evolutions,
			# N9-162: unspent materials come home to the 수련 pouch.
			"loot": _run_state.inventory,
		}
	)
	# N9-65: whatever the run just completed is announced on the result screen.
	# An achievement that lands silently is one the player never learns the
	# rule for, and the rule is the reason it exists.
	summary["earned"] = SaveService.instance.take_earned_achievements()
	# N11-3b (owner: 결과 화면이 성장을 판다): what the night banked and what
	# it puts in reach — the idler loop's whole pitch, printed where the run
	# ends. Materials count the POUCH delta, records the 괴이록 delta, and
	# the next upgrade is the cheapest rank gold alone can still close.
	var banked: int = 0
	for loot_id: Variant in _run_state.inventory:
		banked += maxi(int(_run_state.inventory[loot_id]), 0)
	summary["banked_materials"] = banked
	# N11-19/20b: a lost night banks only its share, so the sheet says so —
	# a purse that quietly shrank reads as a bug, not as a cost.
	if outcome != RunFlow.OUTCOME_VICTORY:
		summary["defeat_share"] = clampf(
			float((_meta_config.get("defeat_bank_base", 1.0)))
			+ _meta_bonus("defeat_bank"), 0.0, 1.0
		)
	summary["new_records"] = maxi(_bestiary_count() - _bestiary_start_count, 0)
	var profile: Dictionary = _profile()
	summary["next_upgrade"] = MetaTree.cheapest_next(
		MetaTree.load_tree(),
		profile.get("meta_tree", {}) as Dictionary,
		int(profile.get("gold", 0)),
		MetaTree.unlocked_characters(MetaTree.load_characters(), profile),
		profile.get("materials", {}) as Dictionary
	)
	# N9-22: surviving the night opens the next tier of the ladder.
	if outcome == RunFlow.OUTCOME_VICTORY:
		var config: Dictionary = Difficulty.load_config()
		SaveService.instance.mark_difficulty_cleared(Difficulty.selected_id(config))
	_play_sfx("victory" if outcome == RunFlow.OUTCOME_VICTORY else "defeat")
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
		# N11-20: the tree shortens the wait between casts (축지술) rather
		# than handing out a second skill. Clamped so a cast never becomes
		# free — the cooldown IS the cost of an active.
		var haste: float = clampf(_meta_bonus("active_haste"), 0.0, MAX_ACTIVE_HASTE)
		_active_cooldowns[active_id] = float(
			active.get("cooldown_sec", 0.0)
		) * (1.0 - haste)
		# N9-14: the guide's "눌러봐" page advances on a real cast.
		if _guide != null:
			_guide.notify_action(Ftue.AWAIT_ACTIVE)
		return


## Effects live here so demo tools can fire them without touching cooldowns.
## N11-20: the tree's active_power scales what a cast actually does — the
## burst's damage and reach, the cleave's arc, the trap's bite. Applied here
## so every caller (demo tools included) gets the same cast the player does.
func _empowered_active(active: Dictionary) -> Dictionary:
	var power: float = maxf(_meta_bonus("active_power"), 0.0)
	if power <= 0.0:
		return active
	var scaled: Dictionary = active.duplicate(true)
	for key: String in ["damage", "radius_px", "duration_sec"]:
		if scaled.has(key):
			scaled[key] = float(scaled[key]) * (1.0 + power)
	return scaled


func _execute_active(active: Dictionary) -> void:
	# Here rather than in the button handler, so a demo tool firing an active
	# directly is not silently different from a player pressing it.
	_play_sfx("skill")
	active = _empowered_active(active)
	match String(active.get("type", "")):
		"blink":
			_execute_blink(active)
		"burst":
			_execute_burst(active)
		"cleave":
			_execute_cleave(active)
		"trap":
			_execute_trap(active)
		"guard":
			# N9-148 철벽: the warrior plants his feet — incoming damage drops
			# to the data scale for the duration. No movement penalty; the
			# cooldown is the cost.
			_player.grant_guard(
				float(active.get("duration_sec", 0.0)),
				float(active.get("damage_taken_scale", 1.0))
			)
			# N9-169: it used to be invisible — a button that changed a number
			# and nothing on screen. The art plays where he plants himself.
			_play_active_art(active, _player.global_position, 0.0)
		_:
			push_error("stage: unknown active type in " + str(active))


## 철질려 (N10-11): the archer scatters caltrops where she stands and backs
## away over them. It is her survival art, and it is deliberately NOT a blink —
## the taoist already teleports, and giving the archer the same escape would
## have made the two classes read the same. She buys distance with ground she
## has denied, which is what a bow needs and a teleport hands out for free.
##
## The field is a Ward, the same object 결계 places: a persistent radius that
## ticks damage and slows what stands in it. Reusing it means the caltrops
## inherit every fix that mechanic has already had.
func _execute_trap(active: Dictionary) -> void:
	var ward: Ward = _trap_pool.acquire()
	ward.arm(
		_player.global_position, _spawner, active.get("ward", {}),
		float(active.get("damage", 0.0)) * (1.0 + _build_bonus("skill_power")),
		{}, UiPalette.ACCENT_ARCHER
	)
	_play_active_art(active, _player.global_position, 0.0)


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
	# N9-88 도력: the one number an active-skill build can grow.
	var damage: float = (
		float(active.get("damage", 0.0)) * (1.0 + _build_bonus("skill_power"))
	)
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


## One-shot art for an active, at its own named sheet. `reach` of 0 keeps the
## sheet's own logical size (a guard aura), anything else draws it to that
## diameter so what is seen matches what the skill covers.
func _play_active_art(active: Dictionary, at: Vector2, reach: float) -> void:
	var effect_id: String = String(active.get("effect", ""))
	if effect_id.is_empty() or not EffectSprite.available(effect_id):
		return
	var art: EffectSprite = _fx_pool.acquire()
	art.play_effect(effect_id, at, reach, UiPalette.ACCENT_WARRIOR)


## N9-168 참격: the warrior's second art. Where 벽사진 clears a full circle
## around the taoist, this one is a swing — everything inside the arc the
## blade actually covers, in the direction he faces. Same damage pipeline and
## the same 도력 scaling; the cone is what makes it a warrior's skill rather
## than a smaller burst.
func _execute_cleave(active: Dictionary) -> void:
	var origin: Vector2 = _player.global_position
	var radius: float = float(active.get("radius_px", 0.0))
	var arc_rad: float = deg_to_rad(float(active.get("arc_deg", 0.0)))
	var aim: float = _player.last_move_direction.angle()
	var damage: float = (
		float(active.get("damage", 0.0)) * (1.0 + _build_bonus("skill_power"))
	)
	# Every art names its own sheet (N9-169). Borrowing the 환도 swing made the
	# skill look like a weapon attack; the fallback only keeps a nameless art
	# visible at all.
	var effect_id: String = String(active.get("effect", "swing_arc"))
	if EffectSprite.available(effect_id):
		var art: EffectSprite = _fx_pool.acquire()
		art.play_effect(
			effect_id, origin + Vector2.from_angle(aim) * radius * 0.5,
			radius, UiPalette.ACCENT_WARRIOR
		)
		art.rotation = aim
	_hud.flash_screen(UiPalette.ACCENT_WARRIOR, WeaponEffects.value("screen_flash_sec"))
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	var radii: Array[float] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
		radii.append(enemy.contact_radius)
	# Collect refs first: striking mutates the spawner's active list.
	var caught: Array[Enemy] = []
	for i: int in WeaponMath.arc_hits(origin, aim, arc_rad, radius, positions, radii):
		caught.append(enemies[i])
	for enemy: Enemy in caught:
		if CombatMath.is_dead(enemy.hp):
			continue
		var hit_at: Vector2 = enemy.global_position
		var boss_hit: bool = enemy.is_boss
		enemy.take_damage(
			damage, CombatMath.chase_direction(origin, hit_at),
			float(active.get("knockback_scale", 1.0))
		)
		_on_hit_landed(damage, hit_at, boss_hit)


func _on_orb_collected(orb: XpOrb) -> void:
	# N7-2 문리 + N9-3 passive: xp_gain meta and passive bonuses both scale
	# every orb at pickup through the same multiplier.
	_run_state.add_xp(int(round(
		float(orb.xp_value) * (1.0 + _build_bonus("xp_gain"))
		* Difficulty.reward_mult(_tier, _run_length, "xp_mult")
	)))
	_refresh_progress_hud()
	_live_orbs.erase(orb)
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
	# N9-156 (owner): the numbers are a switch now; sound and impact stay so
	# hits still read with the numbers off.
	var show_numbers: bool = (
		SaveService.instance == null
		or bool(SaveService.instance.get_setting("show_damage_numbers"))
	)
	if show_numbers:
		var number: DamageNumber = _number_pool.acquire()
		number.show_amount(amount, at, boss_hit, crit)
	# N9-52: a crit already reads differently on screen; giving it its own
	# sound means it also reads differently when the eye is somewhere else.
	_play_sfx("crit" if crit else "hit")
	_punch(Impact.BOSS_HIT if boss_hit else (Impact.CRIT if crit else Impact.HIT))


## Every effect goes through here so the null check for node-free harnesses
## lives in one place instead of at each call site.
func _play_sfx(sound_id: String) -> void:
	if SfxService.instance != null:
		SfxService.instance.play(sound_id)


func _on_number_finished(number: DamageNumber) -> void:
	_number_pool.release(number)


## One grant can cross several levels; each one earns a choice screen — the
## only tap a run asks for (DESIGN.md §5.2). Loot never opens a panel (N4-6).
func _on_level_reached(_new_level: int) -> void:
	_pending_level_ups += 1
	_play_sfx("levelup")
	if not _popup.visible:
		_advance_popup_queue()


## N10-6: 도력 raises active-art damage and nothing else, so it is a card that
## does nothing for a character whose arts deal none — the archer has no actives
## at all, and 철벽 is a guard, not a hit.
func _has_damaging_active() -> bool:
	for active: Dictionary in _actives:
		if float(active.get("damage", 0.0)) > 0.0:
			return true
	return false


func _show_next_level_up() -> void:
	get_tree().paused = true
	var pool: Array[Dictionary] = LevelUp.candidates(
		_weapons_data, _passives_data, _owned_levels, _passive_stacks,
		_owned_grades, _grades_config, _replaced_weapons, _weapon_categories,
		false, _has_damaging_active(), _favoured_families
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
		pool, mod_pool, CHOICES_PER_LEVEL + int(_meta_bonus("choice_count")),
		_choice_rng, _weapon_card_share
	)
	# N11-8 follow-up (QA: 한 장짜리 화면은 "선택"이 아니라 "확인 버튼"이다 —
	# 176개 화면 중 91개가 3장 미달, 후보 17종이 연마로 이관된 직접 결과):
	# a single non-mod candidate applies itself with a float label instead of
	# pausing the fight for a screen with no decision on it. A lone MOD card
	# still opens the screen — it spends a material and swaps a weapon, and
	# that stays the player's call. Two cards remain a real choice.
	if choices.size() == 1 and String(choices[0].get("kind", "")) != LevelUp.KIND_MOD:
		var auto_choice: Dictionary = choices[0]
		_apply_level_up_choice(auto_choice)
		_float_label("%s %s" % [
			LevelUp.display_name(auto_choice, _weapons_data, _passives_data),
			UiLocale.t("자동 강화"),
		])
		_refresh_belongings()
		_pending_level_ups -= 1
		_advance_popup_queue()
		return
	var masked: Array[String] = _unknown_mod_results(choices)
	var cards: Array[Dictionary] = []
	for choice: Dictionary in choices:
		cards.append(LevelUp.as_card(
			choice, _weapons_data, _passives_data, _owned_levels, _passive_stacks,
			_owned_grades, _grades_config, masked
		))
	# N9-14: the first-ever level-up screen wears a tutorial header once —
	# the popup itself IS the weapon-upgrade tutorial (owner direction).
	var header: String = UiLocale.t(POWER_UP_HEADER)
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
			# N9-65: counted for the 개조의 길 achievement. Recorded where the
			# mod is actually applied, not where a card was offered.
			_evolutions += 1
		_:
			push_error("stage: unknown popup payload " + str(payload))
	_refresh_belongings()
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
	# N9-95 (owner: evolving did not feel like anything): the moment itself
	# gets the emergency-burst treatment — gold wave, screen flash, ERUPT
	# punch. A weapon changing what it IS deserves at least what 벽사진 gets.
	var ring: BlastRing = _burst_ring_pool.acquire()
	ring.burst(
		_player.global_position, EVOLUTION_RING_PX,
		WeaponEffects.value("burst_ring_sec"), UiPalette.GOLD, BlastRing.Style.WAVE
	)
	_hud.flash_screen(UiPalette.GOLD, WeaponEffects.value("screen_flash_sec"))
	_punch(Impact.ERUPT)
	_replaced_weapons.append(base_id)
	var sweep: Dictionary = Loot.salvage_dead(
		_run_state.inventory, _loot_data, _mods_data, _owned_levels, _replaced_weapons
	)
	_run_state.inventory = sweep["inventory"]
	_refresh_belongings()
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
		_float_label(UiLocale.t("%s %s 등급!") % [
			UiLocale.data_name(_weapons_data.get(weapon_id, {}) as Dictionary, weapon_id),
			UiLocale.t(String(LevelUp.GRADE_KO.get(grade, grade))),
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


## N11-8 (owner: 패시브를 아예 아이들러쪽 업그레이드로): the in-run passive
## stacks are gone — a build stat is the PERMANENT refine rank (meta tree)
## plus the class innate. Same accessor shape the stack version had, so
## every stat reader migrated without learning a new concept.
func _build_bonus(stat_id: String) -> float:
	return _meta_bonus(stat_id) + _innate_bonus(stat_id)


## The one innate a character carries, if it feeds this stat.
func _innate_bonus(stat_id: String) -> float:
	if String(_innate.get("stat", "")) != stat_id:
		return 0.0
	return float(_innate.get("value", 0.0))


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
			"name": UiLocale.data_name(
				_weapons_data.get(weapon_id, {}) as Dictionary, weapon_id
			),
			"level": int(_owned_levels[weapon_id]),
			"grade": grade,
			"grade_ko": UiLocale.t(
				String(LevelUp.GRADE_KO.get(grade, LevelUp.DEFAULT_GRADE_KO))
			),
			# B0-2: the HUD slot draws this, so "an evolution is possible here"
			# and "you can do it right now" stop costing a pause.
			"evolution": LevelUp.evolution_mark(
				weapon_id, _mods_data, _run_state.inventory,
				_owned_levels, _replaced_weapons
			),
		})
	# N11-8 (owner: 패시브를 아예 아이들러쪽 업그레이드로): the passive column
	# shows the PERMANENT refine ranks — the camp's growth, visible from the
	# pause sheet so a run can still answer "what am I built on".
	var passives: Array[Dictionary] = []
	var meta_ranks: Dictionary = {}
	if SaveService.instance != null:
		meta_ranks = SaveService.instance.profile.get("meta_tree", {})
	for passive_id: String in _passives_data:
		if passive_id.begins_with("_"):
			continue
		var rank: int = int(meta_ranks.get("refine_" + passive_id, 0))
		if rank <= 0:
			continue
		var passive: Dictionary = _passives_data.get(passive_id, {})
		passives.append({
			"id": passive_id,
			"name": UiLocale.data_name(passive, passive_id),
			"stacks": rank,
			"max": int(passive.get("max_stacks", 0)),
		})
	return {
		"weapons": weapons, "passives": passives,
		"stats": _pause_stat_lines(),
		"evolutions": _evolution_lines(),
	}


## Total pages the profile's 괴이록 holds, all kinds together (N11-3b).
func _bestiary_count() -> int:
	var record: Dictionary = Bestiary.normalized_record(_profile().get("bestiary"))
	var total: int = 0
	for kind: String in Bestiary.KINDS:
		total += (record.get(kind, []) as Array).size()
	return total


## B0-1: push the HUD belongings row. Called from the places the build actually
## moves — a level-up pick, a loot pickup, a field passive — rather than every
## frame, because redrawing eight unchanged cells sixty times a second is work
## for nothing. Reuses `_pause_build_summary` so the row and the pause screen
## can never disagree about what is held.
func _refresh_belongings() -> void:
	if _hud == null:
		return
	var summary: Dictionary = _pause_build_summary()
	var materials: Array[Dictionary] = []
	for loot_id: String in _run_state.inventory:
		var count: int = int(_run_state.inventory[loot_id])
		if count <= 0:
			continue
		materials.append({"id": loot_id, "count": count})
	# N11-8: the belongings row is what THIS RUN gathered — weapons and
	# materials. Permanent refine ranks live on the pause sheet, not here.
	_hud.set_belongings(
		summary.get("weapons", []) as Array,
		[],
		materials,
	)


## N9-25: the character sheet the pause screen shows. Every line is read from
## the SAME expression combat uses (_refresh_run_scalars / _refresh_weapon_
## scales) rather than recomputed here — a second copy of the arithmetic would
## drift from the real numbers the moment either side is tuned.
## `modified` marks a line that a passive or the meta tree has moved off its
## base, so the panel can highlight what this run actually built.
func _pause_stat_lines() -> Array[Dictionary]:
	var move: float = 1.0 + _build_bonus("move_speed")
	var damage: float = 1.0 + _build_bonus("attack_damage")
	var attack_speed: float = 1.0 + _build_bonus("attack_speed")
	var defense: float = _meta_bonus("damage_reduction") + _build_bonus("defense")
	var magnet: float = 1.0 + _build_bonus("magnet_radius")
	var projectile_speed: float = (
		1.0 + _build_bonus("projectile_speed")
	)
	var extra_projectiles: int = int(round(_build_bonus("projectile_count")))
	var crit_chance: float = _build_bonus("crit_chance")
	var crit_multiplier: float = (
		CRIT_MULTIPLIER + _build_bonus("crit_damage")
	)
	var xp_gain: float = 1.0 + _build_bonus("xp_gain")
	var luck: float = _build_bonus("luck")
	# The damage floor is the one applied in _refresh_run_scalars; showing the
	# raw sum would promise a reduction the player does not actually get.
	var applied_defense: float = 1.0 - maxf(1.0 - defense, 0.5)
	return [
		# Health is always in ink: it is the one line a player checks mid-run,
		# not a modifier that is interesting only when something moved it.
		_stat_line(UiLocale.t("체력"), "%d/%d" % [ceili(_player.hp), ceili(_player.hp_max)], true),
		_stat_line(UiLocale.t("이동 속도"), "%d" % roundi(_player.load_move_speed() * move), move != 1.0),
		_stat_line(UiLocale.t("공격력"), "%d%%" % roundi(damage * 100.0), damage != 1.0),
		_stat_line(UiLocale.t("공격 속도"), "%d%%" % roundi(attack_speed * 100.0), attack_speed != 1.0),
		_stat_line(UiLocale.t("치명타 확률"), "%d%%" % roundi(crit_chance * 100.0), crit_chance > 0.0),
		_stat_line(UiLocale.t("치명타 피해"), "x%.1f" % crit_multiplier, crit_multiplier != CRIT_MULTIPLIER),
		_stat_line(UiLocale.t("투사체"), "+%d" % extra_projectiles, extra_projectiles > 0),
		_stat_line(UiLocale.t("투사체 속도"), "%d%%" % roundi(projectile_speed * 100.0),
			projectile_speed != 1.0),
		_stat_line(UiLocale.t("피해 감소"), "%d%%" % roundi(applied_defense * 100.0), applied_defense > 0.0),
		_stat_line(UiLocale.t("자석 범위"), "%d%%" % roundi(magnet * 100.0), magnet != 1.0),
		_stat_line(UiLocale.t("경험치 획득"), "%d%%" % roundi(xp_gain * 100.0), xp_gain != 1.0),
		_stat_line(UiLocale.t("행운"), "+%d%%" % roundi(luck * 100.0), luck > 0.0),
	]


func _stat_line(stat_name: String, value: String, modified: bool) -> Dictionary:
	return {"name": stat_name, "value": value, "modified": modified}


## One line per recipe an OWNED weapon can still take: base → result with
## the material's name and whether it is in the run inventory right now.
func _evolution_lines() -> Array[Dictionary]:
	# Structured rows, not strings (owner: 개조경로도 최대한 글 줄이고 이미지로
	# 대체해): the HUD draws base icon -> result icon with a material badge,
	# and the only words left are the level gate. B0-2 masking holds — an
	# unperformed result ships result_known=false and draws as "?".
	var rows: Array[Dictionary] = []
	var known_weapons: Array = Bestiary.normalized_record(
		_profile().get("bestiary")
	)[Bestiary.KIND_WEAPONS]
	for mod_id: String in _mods_data:
		var mod: Dictionary = _mods_data[mod_id]
		var base_id: String = String(mod.get("weapon_id", ""))
		var result_id: String = String(mod.get("result_weapon", ""))
		if not _owned_levels.has(base_id):
			continue
		if _owned_levels.has(result_id) or _replaced_weapons.has(result_id):
			continue
		var loot_id: String = String(mod.get("loot_id", ""))
		var need: int = int(mod.get("level_required", 1))
		rows.append({
			"base_id": base_id,
			"result_id": result_id,
			"result_known": known_weapons.has(result_id),
			"loot_id": loot_id,
			"held": int(_run_state.inventory.get(loot_id, 0)) > 0,
			"need": need,
			"met": int(_owned_levels[base_id]) >= need,
		})
	return rows


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
		1.0 + _build_bonus("move_speed")
	)
	# N9-3g 방비 passive joins the 철피 meta reduction; floored at taking 50%
	# so no future stat combo can approach immunity.
	_player.set_damage_taken_scale(maxf(
		1.0 - _meta_bonus("damage_reduction") - _build_bonus("defense"), 0.5
	))
	_orb_config = _orb_config_base.duplicate()
	_orb_config["magnet_radius_px"] = (
		float(_orb_config_base.get("magnet_radius_px", 0.0))
		* (1.0 + _build_bonus("magnet_radius"))
	)


func _refresh_weapon_scales() -> void:
	var damage_scale: float = 1.0 + _build_bonus("attack_damage")
	var cooldown_scale: float = 1.0 / (
		1.0 + _build_bonus("attack_speed")
	)
	var speed_scale: float = (
		1.0 + _build_bonus("projectile_speed")
	)
	var extra_projectiles: int = int(round(_build_bonus("projectile_count")))
	# N9-18/N9-19 치명타: chance from 치명타 확률, multiplier from the base
	# x2 plus every 치명 일격 stack.
	var crit_chance: float = _build_bonus("crit_chance")
	var crit_multiplier: float = (
		CRIT_MULTIPLIER + _build_bonus("crit_damage")
	)
	# N9-88 mechanic-reshaping passives, same vocabulary as the meta tree.
	# Built once per refresh and handed to every weapon; a weapon whose
	# mechanic has none of these blocks folds them as no-ops.
	var field_effects: Dictionary = {}
	if _build_bonus("chain_amount") > 0.0:
		field_effects["chain_jumps"] = _build_bonus("chain_amount")
	if _build_bonus("seal_haste") > 0.0:
		field_effects["seal_burst"] = _build_bonus("seal_haste")
	if _build_bonus("burn_power") > 0.0:
		field_effects["burn_dps"] = _build_bonus("burn_power")
	if _build_bonus("area_scale") > 0.0:
		field_effects["area_radius"] = _build_bonus("area_scale")
	for weapon_id: String in _weapon_nodes:
		var weapon: AutoWeapon = _weapon_nodes[weapon_id]
		weapon.set_scales(damage_scale, cooldown_scale, speed_scale)
		weapon.set_extra_projectiles(extra_projectiles)
		weapon.set_field_effects(field_effects)
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
		table, _loot_rng, _loot_data, _build_bonus("luck")
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
	_play_sfx("pickup")
	var loot_id: String = (orb as LootDrop).loot_id
	_loot_pool.release(orb)
	_record_discovery(Bestiary.KIND_LOOT, loot_id)
	var stats: Dictionary = _loot_data.get(loot_id, {})
	if Loot.is_material_useful(loot_id, _mods_data, _owned_levels, _replaced_weapons):
		_run_state.inventory = Loot.add(_run_state.inventory, loot_id)
		_refresh_belongings()
		if bool(stats.get("special", false)):
			# N9-18 (owner report: "도깨비불을 얻었는데 진화가 안 나온다"):
			# a special material is banked long before its recipe unlocks —
			# the card needs the BASE weapon at level_required. Say which
			# level is still missing instead of a silent "획득".
			_float_label(_material_cue(loot_id, UiLocale.data_name(stats, loot_id)))
		return
	var gained: int = _add_gold(Loot.salvage_gold(_loot_data, loot_id))
	if bool(stats.get("special", false)):
		_float_label(UiLocale.t("+%d냥") % gained)


## N9-18: cue text for a banked special material — either "ready" or the
## exact base weapon + level the evolution card is still waiting on. Picks
## the closest recipe (fewest levels missing) when several match.
## N10-1a: the shadow's rule, stated once per run at the moment it matters.
func _on_shadow_spawned(enemy: Enemy) -> void:
	_float_label(UiLocale.t("%s — 빛 안에서만 벨 수 있다") % enemy.name_ko)


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
			return UiLocale.t("%s · 개조 준비 완료!") % loot_name
		if best_gap < 0 or gap < best_gap:
			best_gap = gap
			best_line = UiLocale.t("%s · %s Lv.%d에서 개조") % [
				loot_name,
				UiLocale.data_name(_weapons_data.get(base_id, {}) as Dictionary, base_id),
				need,
			]
	return best_line if not best_line.is_empty() else UiLocale.t("%s 획득") % loot_name


## N5-5 destructible feedback: the shared pooled puff at the prop's footprint,
## then one roll on the data table — most breaks give nothing or small gold on
## purpose; the exciting kinds stay uncommon (validator-enforced shares).
func _on_breakable_broke(breakable: Breakable) -> void:
	_play_sfx("break_pot")
	# N9-101: a broken prop used to park invisibly in the field forever. With
	# streamed chunks that is an unbounded pile of dead nodes; nothing ever
	# reuses one, so it is freed. The record list drops it too — deferred,
	# because this handler runs from the prop's own broke signal.
	_field.breakables.erase(breakable)
	# Both lists, immediately: the spawner's culled list is rebuilt only once
	# a second, and a weapon walking it between the free and the next rebuild
	# would touch a dead object. (Before the first cull the two are the same
	# array, so the second erase is a harmless no-op.)
	_spawner.breakables.erase(breakable)
	breakable.queue_free()
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


## N9-55 (owner: "맵에 패시브 스킬들이 떨어져있고… 4개 이상으로도 등록이 되도록").
## Places a passive on the map every interval_sec, on a ring beyond the screen
## edge so it has to be walked to. The cap counts what is still lying out
## there — collecting one immediately makes room for the next.
## N9-101 (owner: catch the frame and garbage-data costs): the breakable list
## only ever grew — every streamed chunk appended, broken props stayed
## forever, and six weapon paths walk the whole list per shot per frame. On an
## endless run that is an unbounded per-frame cost for props three provinces
## away. Once a second the spawner's list is rebuilt to hold only LIVE props
## near the view; the weapons keep their own alive() checks and notice
## nothing. The full record stays in _field.breakables for chunk bookkeeping.
const BREAKABLE_CULL_SEC := 1.0
const BREAKABLE_CULL_RADIUS_PX := 720.0
var _breakable_cull_left: float = 0.0
## Reused between rebuilds — the rebuild must not itself allocate garbage.
var _near_breakables: Array[Breakable] = []


func _tick_breakable_cull(delta: float) -> void:
	_breakable_cull_left -= delta
	if _breakable_cull_left > 0.0:
		return
	_breakable_cull_left = BREAKABLE_CULL_SEC
	var centre: Vector2 = _player.global_position
	var reach: float = BREAKABLE_CULL_RADIUS_PX * BREAKABLE_CULL_RADIUS_PX
	_near_breakables.clear()
	for breakable: Breakable in _field.breakables:
		if not is_instance_valid(breakable) or not breakable.alive():
			continue
		if centre.distance_squared_to(breakable.global_position) <= reach:
			_near_breakables.append(breakable)
	_spawner.breakables = _near_breakables


func _tick_field_passives(delta: float) -> void:
	var block: Dictionary = _pickups_data.get("field_passive", {})
	if block.is_empty():
		return
	# Anything left far behind is recycled: the player has walked away and is
	# never coming back for it, and while it counts against max_live the field
	# ahead of them stops offering anything at all.
	var despawn_px: float = float(block.get("despawn_px", 0.0))
	var kept: Array[Pickup] = []
	for pickup: Pickup in _live_field_passives:
		if not is_instance_valid(pickup) or not pickup.visible:
			continue
		if despawn_px > 0.0 				and pickup.global_position.distance_to(_player.global_position) > despawn_px:
			_pickup_pool.release(pickup)
			continue
		kept.append(pickup)
	_live_field_passives = kept
	_refresh_markers()
	_field_passive_wait -= delta
	if _field_passive_wait > 0.0:
		return
	_field_passive_wait = float(block.get("interval_sec", 20.0))
	if _live_field_passives.size() >= int(block.get("max_live", 1)):
		return
	var ids: Array[String] = Pickups.field_passive_ids(_passives_data, _passive_stacks)
	if ids.is_empty():
		return  # everything is maxed: a pickup that grants nothing is a lie
	var at: Vector2 = Pickups.field_spawn_point(
		_player.global_position,
		_loot_rng.randf() * TAU,
		_loot_rng.randf_range(
			float(block.get("spawn_min_px", 600.0)),
			float(block.get("spawn_max_px", 1000.0))
		)
	)
	var pickup: Pickup = _pickup_pool.acquire()
	pickup.launch_pickup(
		at, Pickups.KIND_PASSIVE, _player, _orb_config,
		ids[_loot_rng.randi_range(0, ids.size() - 1)]
	)
	_live_field_passives.append(pickup)
	_field_passives_placed += 1


## 삼두구미 (N10-3a): a part came off. The float says which one and how far
## along the fight is — the body only becomes hittable at three of three, and a
## player who cannot see that reads the armoured phase as a broken hitbox.
func _on_enemy_part_broken(
	_enemy: Enemy, part_name: String, broken: int, total: int
) -> void:
	_float_label(UiLocale.t("%s 파괴! (%d/%d)") % [part_name, broken, total])
	_punch(Impact.ELITE_KILL)
	_play_sfx("crit")


## 삼두구미 (N10-3b): the hit found a part this player cannot open yet. The
## float names the material rather than the failure — "무쇠가 있어야 한다" is a
## thing to go and do, where "no damage" is a bug report.
func _on_enemy_part_blocked(
	_enemy: Enemy, part_name: String, material_id: String
) -> void:
	var material: Dictionary = _loot_data.get(material_id, {})
	_float_label(UiLocale.t("%s: %s이(가) 있어야 한다") % [
		part_name, UiLocale.data_name(material, material_id)
	])


## 야광귀 (N10-1a): the thief walks to what is lying on the ground, takes it,
## and runs. The stage drives it because the stage is the only thing that knows
## where the field's pickups are — the enemy just follows the goal it is handed.
##
## Losing the passive is the point. It is gone the moment the thief gets clear,
## and the only way to keep it is to kill the thief before that, which is why
## the thief itself never deals damage: the chase has to be the player's own
## choice rather than a fight they are forced into.
func _tick_thieves() -> void:
	var thieves: Array[Enemy] = []
	for enemy: Enemy in _spawner.active_enemies():
		if enemy.is_thief:
			thieves.append(enemy)
	if thieves.is_empty():
		return
	var loot := PackedVector2Array()
	for pickup: Pickup in _live_field_passives:
		loot.append(pickup.global_position)
	for thief: Enemy in thieves:
		var theft: Dictionary = thief.theft_config()
		# 체 (N10-1b): the folklore's own answer. Inside one, the thief stops to
		# count holes — long enough to be caught, or to give the loot back if it
		# is already carrying. This runs BEFORE the escape check, so a thief
		# held at the edge of its escape distance never slips out of the radius.
		thief.stalled = CombatMath.thief_stalled(
			thief.global_position, _field.sieve_grid.near(thief.global_position)
		)
		if thief.stalled:
			continue
		var from_player: float = thief.global_position.distance_to(_player.global_position)
		if not thief.carried_passive.is_empty():
			if CombatMath.thief_escaped(from_player, float(theft.get("escape_px", 0.0))):
				_float_label(UiLocale.t("%s 도둑맞았다!") % UiLocale.data_name(
					_passives_data.get(thief.carried_passive, {}), thief.carried_passive
				))
				thief.carried_passive = ""
				thefts_lost += 1
				# Dismissed, not killed: it won, and paying a kill's xp and
				# count for it would read as a reward.
				_spawner.dismiss(thief)
			continue
		var index: int = CombatMath.thief_target(thief.global_position, loot)
		if index < 0:
			thief.theft_goal = Vector2(NAN, NAN)
			continue
		var seek_px: float = float(theft.get("seek_px", 0.0))
		var to_loot: float = thief.global_position.distance_to(loot[index])
		if seek_px > 0.0 and to_loot > seek_px:
			thief.theft_goal = Vector2(NAN, NAN)
			continue
		thief.theft_goal = loot[index]
		if not CombatMath.thief_takes(to_loot, float(theft.get("grab_px", 0.0))):
			continue
		var taken: Pickup = _live_field_passives[index]
		thief.carried_passive = taken.passive_id
		_pickup_pool.release(taken)
		_live_field_passives.remove_at(index)
		loot.remove_at(index)
		_refresh_markers()
		_float_label(UiLocale.t("야광귀가 훔쳐 간다!"))


## The stolen passive falls where the thief did, so killing it is what gets the
## pickup back rather than a refund the player never sees on the field.
func _drop_stolen_passive(enemy: Enemy) -> void:
	if not enemy.is_thief or enemy.carried_passive.is_empty():
		return
	var pickup: Pickup = _pickup_pool.acquire()
	pickup.launch_pickup(
		enemy.global_position, Pickups.KIND_PASSIVE, _player, _orb_config,
		enemy.carried_passive
	)
	_live_field_passives.append(pickup)
	enemy.carried_passive = ""
	_refresh_markers()


## A found passive is added whatever the four-slot budget says (owner
## direction). The cap governs what the LEVEL-UP screen offers — that is a
## choice, made from a menu, and the budget is what makes it a choice. Walking
## across the field to something visible is the opposite kind of act, and
## taxing it with the same rule would make the trip pointless.
func _collect_field_passive(passive_id: String) -> void:
	if passive_id.is_empty():
		return
	var entry: Dictionary = _passives_data.get(passive_id, {})
	if entry.is_empty():
		push_warning("stage: field passive '%s' is not in the passive data" % passive_id)
		return
	_passive_stacks[passive_id] = int(_passive_stacks.get(passive_id, 0)) + 1
	_refresh_run_scalars()
	_refresh_weapon_scales()
	_refresh_belongings()
	_float_label("%s +1" % UiLocale.data_name(entry, passive_id))


## N9-57 (owner: "무언가가 있다는 화살표 표시나 이런게 필요할거고"). Points at
## every field passive that is currently off-screen. Built lazily so a harness
## that never places one never pays for the node.
func _refresh_markers() -> void:
	if _markers == null:
		_markers = OffscreenMarkers.new()
		_markers.name = "OffscreenMarkers"
		$Hud.add_child(_markers)
	var positions: Array[Vector2] = []
	for pickup: Pickup in _live_field_passives:
		positions.append(pickup.global_position)
	_markers.track(positions)


## N9-59 (owner: "위치를 보기위한 지도도 필요할건데 지도같은건 해금해야 얻을 수
## 있도록"). Builds the map on first use and only if the unlock is owned, then
## refreshes it a few times a second.
func _tick_minimap(delta: float) -> void:
	if not _map_unlocked():
		return
	_minimap_wait -= delta
	if _minimap_wait > 0.0:
		return
	_minimap_wait = MINIMAP_REFRESH_SEC
	if _minimap == null:
		_minimap = Minimap.new()
		_minimap.name = "Minimap"
		var viewport: Vector2 = get_viewport_rect().size
		var map_top: float = (
			MINIMAP_TOP if viewport.x > viewport.y else MINIMAP_TOP_PORTRAIT
		)
		_minimap.position = Vector2(MINIMAP_MARGIN, map_top)
		$Hud.add_child(_minimap)
	_minimap.show_blips(_player.global_position, _minimap_blips())


## Walked once per sweep rather than tracked per spawn: the pools hand nodes
## back and forth constantly, and a subscription per pickup would be a second
## bookkeeping path to keep in step with the first.
func _minimap_blips() -> Dictionary:
	var loot: Array[Vector2] = []
	var chests: Array[Vector2] = []
	for child: Node in get_children():
		var item := child as CanvasItem
		if item == null or not item.visible:
			continue
		if child is Chest:
			chests.append((child as Chest).global_position)
		elif child is LootDrop or child is Pickup:
			loot.append((child as Node2D).global_position)
	var passives: Array[Vector2] = []
	for pickup: Pickup in _live_field_passives:
		passives.append(pickup.global_position)
	return {
		Minimap.KIND_LOOT: loot,
		Minimap.KIND_CHEST: chests,
		Minimap.KIND_PASSIVE: passives,
		Minimap.KIND_TERRAIN: _solid_prop_positions(),
	}


## N9-66: solid props, drawn on the map as 산줄기 chevrons. Real positions
## rather than decoration — a printed ridge where nothing stands would make
## the map lie, and this one is earned.
func _solid_prop_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for child: Node in _field.get_children():
		var body := child as StaticBody2D
		if body != null and body.visible:
			out.append(body.global_position)
	return out


func _map_unlocked() -> bool:
	if SaveService.instance == null:
		return false
	return Unlocks.is_unlocked(SaveService.instance.profile, Unlocks.MAP)


## N9-67 (owner: "타격감이 더 중요할거같은데"). One entry point for both effects,
## so a call site says WHAT happened and the data decides how it feels.
##
## Hitstop is skipped whenever the engine is running at anything other than
## real time: that means a harness is fast-forwarding, and freezing the world
## on its schedule would both corrupt its measurements and change how its bot
## plays. Feel is for a person at 1x.
func _punch(kind: String) -> void:
	var config: Dictionary = _feedback
	_shake = Impact.added_shake(_shake, Impact.shake_amount(config, kind), config)
	var stop: float = Impact.hitstop_sec(config, kind)
	if stop <= 0.0 or not is_equal_approx(Engine.time_scale, 1.0):
		return
	# Never shortens a freeze already running: two hits in the same frame make
	# one stop, not a stutter.
	var until: int = Time.get_ticks_msec() + int(stop * 1000.0)
	if until <= _hitstop_until_msec:
		return
	if _hitstop_until_msec == 0:
		_hitstop_base_scale = Engine.time_scale
	_hitstop_until_msec = until
	Engine.time_scale = 0.0


func _tick_impact(delta: float) -> void:
	if _hitstop_until_msec > 0 and Time.get_ticks_msec() >= _hitstop_until_msec:
		_hitstop_until_msec = 0
		Engine.time_scale = _hitstop_base_scale
	if _shake <= 0.0:
		return
	_shake_time += delta
	_shake = Impact.decayed_shake(_shake, delta, _feedback)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	camera.offset = Impact.shake_offset(_shake, _shake_time, _shake_scale())


func _shake_scale() -> float:
	if SaveService.instance == null:
		return 1.0
	return clampf(
		float(SaveService.instance.get_setting(SaveProfile.SCREEN_SHAKE_KEY)), 0.0, 1.0
	)


## N5-5 pickup effects, each applied at collection so the player walked to it.
## HEALTH at full HP converts to gold (chosen rule: the drop is never wasted,
## and the check runs at collection time so getting hit on the way still heals).
func _on_pickup_collected(orb: XpOrb) -> void:
	_play_sfx("pickup")
	var kind: String = (orb as Pickup).kind
	var granted: String = (orb as Pickup).passive_id
	_pickup_pool.release(orb)
	match kind:
		Pickups.KIND_PASSIVE:
			_collect_field_passive(granted)
		Pickups.KIND_GOLD:
			var gained: int = _add_gold(
				int((_pickups_data.get("gold", {}) as Dictionary).get("amount", 0))
			)
			_float_label(UiLocale.t("+%d냥") % gained)
		Pickups.KIND_HEALTH:
			_play_sfx("heal")
			_collect_health()
		Pickups.KIND_NUKE:
			_play_sfx("nuke")
			_execute_nuke()
		Pickups.KIND_MAGNET:
			_play_sfx("magnet")
			_execute_magnet()


func _collect_health() -> void:
	var health: Dictionary = _pickups_data.get("health", {})
	if _player.hp >= _player.hp_max:
		var gained: int = _add_gold(int(health.get("full_hp_gold", 0)))
		_float_label(UiLocale.t("+%d냥") % gained)
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
	_float_label(UiLocale.t("회복 +%d") % int(round(heal)))
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
	_punch(Impact.NUKE)
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


## MAGNET: every uncollected XP orb on the field flies in at once. An empty
## field still shows the ring + label — never a dead tap.
##
## XP ONLY (owner direction). Pickup and LootDrop both EXTEND XpOrb to reuse
## its magnet physics, so the obvious `is XpOrb` test swept in every material
## and prop drop as well — a magnet was hoovering up the whole field. Walking
## to a thing you can see is the reward those are placed for; the magnet is
## for the orbs scattered behind you by a fight.
func _execute_magnet() -> void:
	var ring: BlastRing = _burst_ring_pool.acquire()
	ring.burst(
		_player.global_position,
		float((_pickups_data.get("magnet", {}) as Dictionary).get("ring_radius_px", 0.0)),
		WeaponEffects.value("burst_ring_sec"), UiPalette.LOOT_RARE, BlastRing.Style.WAVE
	)
	_float_label(UiLocale.t("자석!"))
	for child: Node in get_children():
		var orb := child as XpOrb
		if orb == null or not orb.visible:
			continue
		if orb is Pickup or orb is LootDrop:
			continue
		orb.attract_now()


## N5-5 chest open: roll the reward count against luck, then queue that many
## reward screens. Rewards are drawn one at a time at show time (never here),
## so every card is legal against the state the previous reward produced. A
## chest opened after the run ended is deliberately discarded — the run is
## banked, the result screen owns the game.
func _on_chest_opened(chest: Chest) -> void:
	_chest_pool.release(chest)
	if _outcome != RunFlow.OUTCOME_NONE:
		return
	_play_sfx("chest_open")
	var count: int = Pickups.roll_chest_count(
		_pickups_data.get("chest", {}), _build_bonus("luck"), _loot_rng
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
		_owned_grades, _grades_config, _replaced_weapons, _weapon_categories,
		false, _has_damaging_active()
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
		_float_label(UiLocale.t("+%d냥") % gained)
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
		UiLocale.t(CHEST_HEADER) % [_chest_batch_index, _chest_batch_total],
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


## N11 (오너: 끝없는 밤은 렉이 너무 심해): orbs never expire (N9-100 — every
## orb stays collectable), so an endless night grew thousands of live nodes,
## the run's only unbounded per-frame cost. At the data cap the XP merges
## into the nearest live orb instead of becoming a new node — zero XP lost,
## bounded node count. The cap sits above the measured finite-run peak (678),
## so a normal run never merges. Nearest-scan runs only on the capped spawn
## path, never per frame.
func _spawn_xp_orb(at: Vector2, xp: int) -> void:
	var cap: int = int(_orb_config.get("live_cap", 0))
	if cap > 0 and _live_orbs.size() >= cap:
		var nearest: XpOrb = null
		var best: float = INF
		for live: XpOrb in _live_orbs:
			var distance: float = live.global_position.distance_squared_to(at)
			if distance < best:
				best = distance
				nearest = live
		if nearest != null:
			nearest.xp_value += xp
			return
	var orb: XpOrb = _orb_pool.acquire()
	orb.launch(at, xp, _player, _orb_config)
	_live_orbs.append(orb)


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


func _create_trap_ward() -> Ward:
	var ward := Ward.new()
	ward.ticked.connect(
		func(amount: float, at: Vector2, boss_hit: bool, _crit: bool) -> void:
			_on_hit_landed(amount, at, boss_hit)
	)
	ward.finished.connect(func(done: Ward) -> void: _trap_pool.release(done))
	return ward


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
