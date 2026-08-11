# JOSEONLIKE — Architecture & Worktree Contract

Engine: **Godot 4.7** (GL Compatibility renderer, mobile-first 540x960 portrait).
Language: **GDScript**, statically typed.

This document is the coordination contract between five parallel worktrees.
Read section 1 (ownership) and section 3 (interfaces) before writing any code.

---

## 1. Worktree Ownership Map

A worker may **create and edit only files under its owned paths**. Touching another
worktree's path is a merge conflict, not a shortcut. If you need a change outside your
paths, send it to the coordinator via `ask`.

| Worktree | Owns (write) | Reads (never writes) |
|---|---|---|
| `core-engine` | `scripts/core/**`, `scenes/boot/**`, `tests/run_tests.gd`, `tests/core/**` | `data/**` |
| `combat` | `scripts/combat/**`, `scripts/weapons/**`, `scenes/combat/**`, `scenes/actors/**`, `tests/combat/**` | `scripts/core/**`, `data/**` |
| `content-data` | `data/**`, `tools/validate_data.gd`, `tests/data/**` | `scripts/core/**` |
| `meta-ui` | `scripts/ui/**`, `scripts/meta/**`, `scenes/ui/**`, `scenes/basecamp/**`, `tests/ui/**` | `scripts/core/**`, `data/**` |
| `infra-ci` | `.github/**`, `export_presets.cfg`, `tools/ci/**`, `scripts/services/**` | everything |
| `asset-forge` | `asset/**`, `tools/asset/**` | everything |

**Coordinator-owned, never edited by workers:** `project.godot`, `ARCHITECTURE.md`, `ASSET_SPEC.md`,
`JOSEONLIKE_GDD.md`, `README.md`, `icon.svg`, `.gitignore`.
Autoload registration, input map entries, and physics layer names live in
`project.godot` — request them, do not add them.

---

## 2. Directory Layout

```
scenes/
  boot/           boot.tscn — entry point, loads data then routes
  actors/         player.tscn, enemy_base.tscn
  combat/         stage.tscn, spawner, pickups
  ui/             hud, level_up_choice, results
  basecamp/       camp.tscn, workshop, archive, training_ground, shrine
scripts/
  core/           autoloads + data loading + save (core-engine)
  combat/         combat systems (combat)
  weapons/        weapon behaviours + evolution (combat)
  ui/             UI controllers (meta-ui)
  meta/           progression, achievements, quests (meta-ui)
  services/       ads, analytics, platform shims (infra-ci)
data/             JSON content, single source of balance truth (content-data)
tests/            headless test scripts, mirrored per owner
tools/            validators and CI helpers
asset/            art and audio, singular. Owned by asset-forge; others reference only
  character/<Name>/<State>/rotations/<direction>.png   8-way sprite sets
  monster/<id>.png                                     single front-facing sprite
  monster/raw/<id>_raw.png                             pre-cutout generator output
```

## Assets

[ASSET_SPEC.md](ASSET_SPEC.md) is the authoritative art and audio specification — style
authority and measured sizes, direction naming and facing rules, set composition, generation
rules including what has been measured not to work, cutting, and the two verification layers.
Read it before commissioning, generating or reviewing any asset. The summary below is the part
that binds every worktree, not just `asset-forge`.

### Asset sets, not asset images

Art is commissioned, generated and reviewed as a **complete set per entity**, never as loose
images. A set that is missing members is unfinished, not partially delivered — earlier rounds
shipped rotations with no motion and weapons with no attack art, and each gap only surfaced
when someone looked.

| Set | Required members |
|---|---|
| Character | 8 idle rotations, walk, attack, death |
| Monster | 8 idle rotations, walk, death |
| Weapon | 32x32 icon, projectile or VFX art, attack effect |
| Effect | 4 frames: anticipation, expansion, peak, dissipation |

Every member must either exist, or be **explicitly recorded as satisfied another way** with the
measurement behind it. Character walk and attack are currently satisfied by pixel-snapped
procedural motion because generated frames were rejected four separate ways; that is a
documented answer, not a missing member. Silently shipping a partial set is the failure mode
this table exists to prevent.

Review is per set, never per image:

- **Facing** — south, south-east and south-west show the face; east and west are opposite
  profiles; north, north-east and north-west show the back. Adjacent directions must be
  distinguishable by eye, not merely different in pixel count. A pixel-distance check cannot see
  this: two back views differ numerically while both remain back views.
- **Progression** — a motion sequence must advance. Death is judged on irreversible collapse,
  which is why it passed where walk's identity gate failed.
- **Coherence** — every member of a set reads as the same entity at the same scale, cut through
  `pixelize.py` against the same palette.

`tools/asset/verify_assets.py` enforces what can be automated. Anything it cannot check is
checked by looking at a contact sheet before the set is reported done.

**Asset paths are `res://asset/...`, singular, not `assets/`.** The directory layout
above is what actually exists on disk; data files and scenes must match it exactly.
Sprites are chroma-keyed and downscaled with nearest-neighbour, and the project sets
`default_texture_filter=0`, so never enable filtering on a sprite import — it turns the
pixel grid to mush.

---

## 3. Interfaces (the only cross-worktree API)

These signatures are frozen. Changing one requires a coordinator decision gate.
`core-engine` implements them; everyone else calls them.

### 3.1 `EventBus` (autoload) — decoupled signal hub

```gdscript
# scripts/core/event_bus.gd
signal run_started(character_id: String, stage_id: String)
signal run_ended(result: Dictionary)          # {victory: bool, time_sec: float, kills: int, gold: int}
signal player_damaged(amount: float, hp_left: float)
signal player_died()
signal enemy_killed(monster_id: String, position: Vector2)
signal xp_gained(amount: int)
signal level_reached(level: int, choices: Array[Dictionary])
signal upgrade_chosen(choice_id: String)
signal weapon_evolved(from_id: String, to_id: String)
signal boss_spawned(boss_id: String)
signal boss_defeated(boss_id: String)
signal stat_recorded(key: String, amount: int)   # achievement/quest counters
```

Rule: emit through `EventBus`, never hold a direct reference to another system's node.

### 3.2 `GameData` (autoload) — read-only content access

```gdscript
# scripts/core/game_data.gd
func load_all() -> Error                       # called once by boot; parses data/*.json
func character(id: String) -> Dictionary
func weapon(id: String) -> Dictionary
func monster(id: String) -> Dictionary
func stage(id: String) -> Dictionary
func passive(id: String) -> Dictionary
func evolution_for(weapon_id: String, passive_id: String) -> String   # "" when none
func all_characters() -> Array[Dictionary]
func all_achievements() -> Array[Dictionary]
func all_weapons() -> Array[Dictionary]      # added: the level-up pool needs enumeration
func all_passives() -> Array[Dictionary]     # added: same reason
```

List accessors inject the JSON key as an `id` field on each returned entry, since the
files are keyed objects and UI code iterates without the key.

Returns are **duplicated dictionaries**; callers must not mutate shared data.
A missing id logs an error and returns `{}` — callers guard with `is_empty()`.

### 3.3 `RunState` (autoload) — live state of one run, reset per run

```gdscript
# scripts/core/run_state.gd
var character_id: String
var stage_id: String
var level: int
var xp: int
var elapsed_sec: float
var kills: int
var weapons: Array[Dictionary]     # [{id, level}]
var passives: Dictionary           # {passive_id: stacks}

func begin(character_id: String, stage_id: String) -> void
func reset() -> void
func add_xp(amount: int) -> void            # emits xp_gained, level_reached
func stat_total(key: String) -> float       # aggregated passive value, e.g. "attack_speed"
func xp_to_next(from_level: int) -> int     # 5 * 1.25^(from_level-1), rounded
func weapon_level(weapon_id: String) -> int
func passive_stacks(passive_id: String) -> int
func grant_weapon(weapon_id: String) -> void
func grant_passive(passive_id: String) -> void
func apply_choice(choice_id: String) -> void
```

**Who applies a level-up pick:** RunState connects to `EventBus.upgrade_chosen` and
applies the pick itself via `apply_choice`. The UI's only job is to emit
`upgrade_chosen(choice_id)`. Do not also mutate weapons or passives from UI code, or
every pick is applied twice.

**XP curve:** `xp_to_next(level) = 5 * 1.25 ^ (level - 1)`, rounded. Geometric, not
arithmetic. `data/BALANCE.md` was originally derived against a guessed arithmetic curve;
the geometric one here is authoritative and the balance notes are re-derived against it.

Concurrent weapon slots are capped at 4; the choice pool stops offering `weapon_new`
once four weapons are held.

### 3.4 `SaveManager` (autoload) — persistence

```gdscript
# scripts/core/save_manager.gd
func load_profile() -> Dictionary
func save_profile() -> Error
func get_value(key: String, default_value: Variant) -> Variant
func set_value(key: String, value: Variant) -> void   # marks dirty, autosaves debounced
```

Save path: `user://profile.save`, JSON, versioned with `{"schema": 1, ...}`.
Never store PII. Never log save contents.

### 3.5 `SceneRouter` (autoload) — scene transitions

```gdscript
# scripts/core/scene_router.gd
func goto_camp() -> void
func goto_character_select() -> void
func goto_stage(stage_id: String) -> void
func goto_results(result: Dictionary) -> void
```

---

## 4. Data Schemas (`data/*.json`)

`content-data` owns these files. Everyone else reads them through `GameData`.
Every file is a JSON object keyed by id, so lookups are O(1) and diffs stay small.
All ids are `snake_case` ASCII. Display text lives in `name_ko` / `name_en`;
never hardcode Korean strings in scripts.

### `data/characters.json`
```json
{
  "taoist": {
    "name_ko": "도사", "name_en": "Taoist",
    "role": "magic_aoe",
    "base_hp": 100, "base_speed": 90.0,
    "starting_weapon": "old_talisman",
    "unlock": { "type": "default" }
  }
}
```
`unlock.type` ∈ `default | achievement | gold`, with `achievement_id` or `cost`.

### `data/weapons.json`
```json
{
  "old_talisman": {
    "name_ko": "낡은 부적", "name_en": "Old Talisman",
    "category": "spiritual",
    "grade": "common",
    "damage": 12.0, "cooldown_sec": 1.2, "projectile_count": 1,
    "pierce": 0, "area_scale": 1.0, "speed": 260.0,
    "max_level": 8,
    "per_level": { "damage": 3.0, "cooldown_sec": -0.05 },
    "evolves_to": "fire_talisman",
    "evolution_only": false,
    "sprite": "res://asset/weapon/icons/old_talisman.png"
  }
}
```
`category` ∈ `melee | ranged | spiritual`. `grade` ∈ `common | rare | epic | legendary | mythic`.
`evolution_only: true` marks a weapon that exists **only** as an evolution result. RunState
must exclude those from the ordinary `weapon_new` pool — otherwise the payoff for meeting an
evolution's weapon-level and passive-stack requirements is also handed out as a plain
level-up pick, and evolution stops being a goal. `evolves_to` must name a weapon that some
rule in `evolutions.json` actually produces; a pointer with no matching rule is a dead end
and the validator rejects it.

### `data/passives.json`
```json
{
  "attack_speed": {
    "name_ko": "공격 속도", "name_en": "Attack Speed",
    "stat": "attack_speed", "per_stack": 0.08, "max_stacks": 5
  }
}
```
Valid `stat` keys (frozen — combat reads these): `attack_damage`, `attack_speed`,
`move_speed`, `crit_chance`, `max_hp`, `xp_gain`, `luck`, `skill_power`.

### `data/evolutions.json`
```json
{
  "phoenix_talisman": {
    "requires_weapon": "fire_talisman",
    "requires_passive": "skill_power",
    "min_weapon_level": 5, "min_passive_stacks": 3,
    "result_weapon": "phoenix_talisman"
  }
}
```

### `data/monsters.json`
```json
{
  "forest_goblin": {
    "name_ko": "숲 도깨비", "name_en": "Forest Goblin",
    "hp": 20.0, "damage": 6.0, "speed": 55.0,
    "xp_drop": 3, "gold_drop": 1,
    "behaviour": "chase",
    "collision_radius": 6.0,
    "sprite": "res://asset/monster/forest_goblin.png"
  }
}
```
`behaviour` ∈ `chase | ranged | charger | swarm | boss`.
`collision_radius` is required and authoritative: sprites range from 26x46 to 60x76, so a
single hardcoded radius in `enemy_base.tscn` cannot fit them. Combat sizes the collision
shape from this field and never from the sprite texture, so a resized sprite never
silently changes hitboxes.

### `data/stages.json`
```json
{
  "bamboo_forest": {
    "name_ko": "대나무 숲", "name_en": "Bamboo Forest",
    "duration_sec": 600,
    "boss_id": "bamboo_spirit_lord",
    "waves": [
      { "at_sec": 0,   "monster_id": "forest_goblin", "count": 6,  "interval_sec": 2.0 },
      { "at_sec": 120, "monster_id": "forest_spirit", "count": 10, "interval_sec": 1.5 }
    ]
  }
}
```

### `data/achievements.json`
```json
{
  "first_boss": {
    "name_ko": "첫 보스 처치", "name_en": "First Boss Clear",
    "counter_key": "boss_defeated", "target": 1,
    "reward": { "type": "gold", "amount": 100 }
  }
}
```
`counter_key` must match a key emitted via `EventBus.stat_recorded`.

---

## 5. Testing

Headless runner: `godot --headless --path . --script tests/run_tests.gd`.
`core-engine` owns the runner; every worktree adds its own `tests/<area>/test_*.gd`.
A test file exposes `func run() -> Array[String]` returning failure messages
(empty array = pass).

Minimum bar per worktree: every non-trivial system has at least one test that fails
if the logic breaks. `content-data` must ship `tools/validate_data.gd` verifying that
every cross-file id reference resolves.

---

## 6. Conventions

- Static typing everywhere: `var hp: float = 100.0`, `func fire(dir: Vector2) -> void`.
- Constants over magic numbers; balance numbers belong in `data/`, not in code.
- `snake_case` files and functions, `PascalCase` class names, `UPPER_SNAKE_CASE` consts.
- Early returns over nested `if`.
- No `print()` in committed code — use `push_warning` / `push_error`.
- Comments explain *why*, in English.
- Never commit `.godot/`, keystores, or `.env`.

---

## 7. Milestone 1 — Vertical Slice

One playable loop end to end:
`camp → character select (Taoist) → Bamboo Forest → auto combat → level-up choice →
boss → results → back to camp with rewards persisted.`

Content bar for M1: 1 character, 1 stage, 3 weapons, 3 monsters, 1 boss, 8 passives.
Everything else expands as data afterwards.
