# JOSEONLIKE — Architecture

Engine: **Godot 4.7** (GL Compatibility renderer, mobile-first 540x960 portrait,
landscape supported). Language: **GDScript**, statically typed.

This document describes the code as it is. How work is scheduled and verified is
[CLAUDE.md](CLAUDE.md); balance numbers are [data/BALANCE.md](data/BALANCE.md);
art rules are [ASSET_SPEC.md](ASSET_SPEC.md) and
[ASSET_REQUIREMENTS.md](ASSET_REQUIREMENTS.md).

> Rewritten 2026-08-26 against the tree. The previous version described a planned
> structure — an `EventBus` signal hub, a `GameData` loader, a `SceneRouter`, eight
> directional rotations per character — none of which was ever built. What follows
> is what a reader will actually find. Section numbers are kept where other
> documents cite them (§4 data, §6 conventions).

---

## 1. Shape of the thing

There is no framework layer. A run is one scene (`scenes/stage.tscn`) whose script
`Stage` owns the field, the spawner, the player and the HUD, and every system it
drives is a plain class it holds. Systems talk by direct call, or by a signal from
the node that owns the fact — a monster tells its spawner it died, the spawner
relays it to the stage, and the stage decides what that means.

That is deliberate, and it is what CLAUDE.md §4 asks for: prove first, generalise
later. The only things pulled out into autoloads are the ones that must outlive a
run.

| Autoload | Script | What it owns |
|---|---|---|
| `SaveManager` | `scripts/core/save_manager.gd` | the profile on disk, and the in-memory copy every screen reads |
| `MusicManager` | `scripts/core/music_player.gd` | which track is playing, and the crossfade between them |
| `SfxManager` | `scripts/core/sfx_player.gd` | one-shot sounds, with a per-sound minimum interval |
| `DisplayAdapter` | `scripts/core/display_adapter.gd` | content scale and orientation, including the web fullscreen path |

Registered in `project.godot`. Audio buses (`Master` / `Music` / `Effects`) live in
`default_bus_layout.tres`; every player names its bus, or a settings slider moves a
value that changes nothing audible.

---

## 2. Directory layout

```
scenes/          seven screens, flat: title, character_select, camp, stage,
                 bestiary, achievements, meta_tree
scripts/
  core/     (12) autoloads + profile/save + the data-shaped helpers that outlive a
                 run (bestiary, achievements, unlocks, meta tree, camp, ftue)
  combat/   (43) everything a run is made of — stage, spawner, enemy, player,
                 weapons, projectiles, effects, field, pickups, pure maths
  ui/       (19) screens and HUD, plus the palette, icon and locale tables
data/       (18) JSON content, the single source of balance truth
tests/unit/ (54) headless tests, auto-discovered
tools/      (28) headless harnesses and validators
asset/           art and audio the game loads
new_asset/       working originals the game never loads — see new_asset/README.md
```

There is no `scripts/weapons/`, `scripts/meta/` or `scripts/services/`. Weapons are
data plus `scripts/combat/auto_weapon.gd`; meta progression lives in `scripts/core/`;
there are no service shims.

---

## 3. What holds what

**`Stage`** (`scripts/combat/stage.gd`) is the run. It loads the data it needs,
builds the field, owns the pools, and is the one place that turns an event into a
consequence: a kill into xp and loot, a level into a choice screen, a part coming
off a 삼두구미 into a float and a changed monster. It is large on purpose —
splitting it would move the coupling rather than remove it — and its size is a
registered task, not an accident.

**`Spawner`** (`scripts/combat/spawner.gd`) owns live enemies: the wave table, the
live cap, separation, off-screen culling, and the pool. Enemy signals arrive here
and are relayed onward, so nothing inside an enemy holds a stage reference.

**`Enemy`** (`scripts/combat/enemy.gd`) is one class for every monster. Behaviour is
data (`behaviour` in `monsters.json`); the ones that actually branch are `boss`,
`suicide` (화약 도깨비), `thief` (야광귀) and `multipart` (삼두구미), and the rest
chase. Every source of damage routes through `Enemy.take_damage`, which is why the
그슨대's absorb guard, the thief's harmlessness and the multipart's armour each live
in exactly one place instead of in twenty-seven weapons.

**`StageField`** (`scripts/combat/stage_field.gd`) scatters props by theme in seeded
clusters and streams new chunks as the player walks. A prop that declares a radius
registers into an index — `light_grid` (lantern light, which 그슨대 needs) and
`sieve_grid` (체, which stops a thief) — both `PropGrid`, a uniform cell grid, so a
per-frame proximity question costs local density instead of world size.

**Pure maths** lives in `CombatMath`, `WeaponMath`, `PlayerMotion`, `RunFlow`,
`Difficulty`, `Endless`, `Pickups`, `Loot`, `MetaTree`, `Bestiary`. Static functions,
no nodes — which is what lets the headless suite test the rules directly. When a new
rule needs a decision, the decision goes here and the node calls it.

**Pools**: `NodePool` backs enemies, projectiles, pickups, orbs, chests and puffs. A
pooled object resets in `setup()`, never in `_ready()`.

---

## 4. Data (`data/*.json`)

Eighteen files, each a JSON object keyed by id. Ids are `snake_case` ASCII; display
text is `name_ko` / `name_en` and is never hardcoded in a script (`UiLocale` holds
the UI strings, `UiLocale.data_name()` resolves the data ones).

| File | What it decides |
|---|---|
| `characters.json` | the roster, base stats, starting weapon, actives, unlock rule |
| `weapons.json` | 27 weapons: mechanic, damage, cooldown, travel/hit art, evolution |
| `weapon_mods.json`, `evolutions.json` | 개조 branches and what they require |
| `passives.json`, `progression.json` | passive stats and the xp curve |
| `monsters.json` | stats, `collision_radius`, `behaviour`, and the block a behaviour requires |
| `stages.json` | duration, waves, boss, spawning limits, soft enrage, endless |
| `props.json` | the prop catalogue, field density, and per-theme placement |
| `drop_tables.json`, `loot.json`, `pickups.json` | what falls, and what it does |
| `meta_tree.json`, `unlocks.json`, `achievements.json` | between-run progression |
| `effects.json` | every timing, radius and sprite sheet the visuals consume |
| `difficulties.json` | the difficulty ladder and run lengths |
| `audio.json` | tracks and sound effects, including borrowed stand-ins |

Rules that live here rather than in code, because they are balance:

- **Weapon slots cap at 4** and passive picks at 4 per level-up screen; a found
  field passive ignores that cap, because walking to something visible is not the
  same act as picking from a menu.
- **`collision_radius` is required** on every monster and must fit inside the
  sprite's own half-width — what you see is what hits.
- **XP curve** is geometric, from `progression.json` (`base_xp` 6, `growth` 1.28).

`tools/validate_data.gd` is the contract. It checks that every cross-file id
resolves, that every `res://` path in any data file exists, and that a declared
behaviour carries the numbers it needs — a suicide's fuse, a thief's escape, a
multipart's parts and the material each part is gated behind. **A rule that only
lives in code will drift; put it in the validator.**

---

## 5. Testing and harnesses

```sh
godot --headless --path . --import                          # class cache, first
godot --headless --path . --script tests/run_tests.gd       # 552 tests, must print PASS
godot --headless --path . --script tools/validate_data.gd   # data cross-references
```

`tests/run_tests.gd` discovers `tests/unit/*.gd` and calls every `test_*` method; a
method fails by returning `false` and pushing an error. Tests cover pure functions
and data contracts — they do not build scenes.

What a test cannot see, a **harness** drives. Each is a scene under `tools/` that
boots the real thing and reports:

| Harness | Answers |
|---|---|
| `playtest.tscn` | can a bot finish a run — outcome, level, dps, fps at the surge |
| `layout_sweep.tscn` | does any screen overflow, clip or scroll (12 screens x 11 devices x 2 locales) |
| `locale_check.tscn` | is every Korean literal translated, and do the format specifiers match |
| `thief_check.tscn` | 야광귀: the theft, the escape, and the 체 that stops it |
| `multipart_check.tscn` | 삼두구미: gated, armoured, taken apart, then killable |
| `shadow_check.tscn` | 그슨대: absorbs in the dark, dies in the light |
| `weapon_demo`, `field_check`, `pause_check`, `camp_check`, … | one weapon or one screen, captured |

Why there are so many: a rule that is invisible from outside — a body that ignores
damage, a passive that vanishes off-screen — looks exactly like a bug, and only a
harness that drives the case can tell the two apart.

---

## 6. Conventions

- Static typing everywhere: `var hp: float = 100.0`, `func fire(dir: Vector2) -> void`.
- Balance numbers live in `data/`, never in code. Constants over magic numbers.
- `snake_case` files and functions, `PascalCase` class names, `UPPER_SNAKE_CASE` consts.
- Early returns over nesting.
- No `print()` in committed game code — `push_warning` / `push_error`. Harnesses in
  `tools/` print by design; that is their output.
- Comments explain **why**, in English, and name the thing that went wrong when the
  code exists to stop it coming back.
- Sprites are nearest-neighbour and the project sets `default_texture_filter=0`.
  Never enable filtering on a sprite import — it turns the pixel grid to mush.
- Never commit `.godot/`, keystores, or `.env`.

---

## 7. Where the game is

One night runs end to end: title → camp → region select → run (waves, level-up
choices, elites, boss at 5:40) → result → camp, with gold, bestiary and achievements
persisted. Two regions (대나무 숲, 폐허가 된 마을), two playable characters
(도사 by default, 무사 unlocked by an achievement) with 궁수 declared and not yet
built, 27 weapons with 개조 branches, a 34-node meta tree, and an endless mode that
loops a stage's own waves.

The queue, and everything already done, is [TASKS.md](TASKS.md).
