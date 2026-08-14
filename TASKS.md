# JOSEONLIKE — Tasks

One feature per session, per [CLAUDE.md](CLAUDE.md). Milestones: [ROADMAP.md](ROADMAP.md).
Tick a box only after commit **and** push succeeded.

Baseline recorded 2026-08-13 at commit `9d3b8b5`:
`godot --headless --path . --script tests/run_tests.gd` → `PASS 22 file(s): 22 passed, 0 failed, 0 errored`.

---

## 1. State inventory

### KEEP — working, tested, do not rewrite

- [x] Core autoloads — `EventBus`, `GameData`, `SaveManager`, `RunState`, `SceneRouter`
- [x] Boot → data load → title routing
- [x] Title screen (layered backdrop, music, menu)
- [x] Settings screen — Master/Music/Effects sliders, ko/en language, persisted
- [x] Camp screen — walkable camp, building panels, Archive → achievements/quests
- [x] Character select — 3 characters, unlock state displayed
- [x] Area select — Bamboo Forest selectable, other GDD areas rendered locked
- [x] Combat stage — spawner, wave schedule, boss spawn, contact damage, death
- [x] Auto-attack weapons — sword, bow, talisman, projectiles, melee arc, evolution
- [x] XP drops, pickups, level-up choice, weapon/passive grants
- [x] HUD — hp/xp/timer/kills/weapon chips, pause overlay
- [x] Results screen — time, kills, gold and newly unlocked achievements
- [x] Achievement tracker with counters and gold rewards
- [x] Quest counters (daily reset, story counters) — data-less scaffolding
- [x] `MusicDirector` + `Music`/`Effects` audio buses
- [x] Headless test runner, 22 test files, `tools/validate_data.gd`, GitHub Actions CI

### BROKEN — known defects, each is its own feature below

- Run gold is never banked into the profile (`M2-1`)
- `unlock.type == "gold"` always evaluates to locked → Archer is unreachable (`M2-2`)
- Level-up choice logs `GameData: unknown weapons id "choice_..."` errors (`DEBT-1`)

### UNUSED — present but nothing calls it

- `scripts/services/ads.gd`, `scripts/services/analytics.gd` — deliberate M4 stubs,
  not autoloaded, no call sites. Keep, do not extend until M4.
- 18 of 22 monsters in `data/monsters.json` have no stage referencing them.
- Camp Workshop / Training Ground / Shrine open a "Coming soon" panel.

### UNKNOWN — needs a look when touched

- Coverage of `asset/**` versus what scenes actually load. The 8-direction
  rotation sheets under `asset/character/*/raw` become legacy once P1-3 lands;
  audit and prune them in a later cleanup feature.
- Whether `data/BALANCE.md` numbers still match `data/*.json` after M1 changes.

---

## 2. Feature backlog

### P1 — Framework pivot (side-view + character identity) — CURRENT

Owner decision 2026-08-14: 8-direction art retired, 2D side-view with
left/right facing only; per-character weapon categories enforced.
Codex asset worktree `side-sprites` generates the character sprites
(style: `new_asset/basic.png`).

- [ ] **P1-1 2-direction facing** — the player sprite faces right when moving
      right, left when moving left (mirror), and keeps its last facing while
      moving purely vertically or standing still; `CharacterMotion` facing
      logic is unit-tested; 8-direction bucket selection is no longer used for
      the player.
- [ ] **P1-2 Character weapon identity** — `data/characters.json` gains
      `weapon_categories`; level-up weapon offers only contain weapons whose
      category is allowed for the run's character; `tools/validate_data.gd`
      fails when a starting weapon's category is not allowed or a character
      has an empty pool; existing runs with now-forbidden weapons still load.
- [ ] **P1-3 Side-view sprite integration** — the reviewed sprites from the
      `side-sprites` worktree are merged; Taoist/Warrior/Archer render the new
      `side/idle.png` in camp, character select and combat; old rotation
      sheets are no longer referenced by the player path. (blocked on codex
      worker output review)
- [ ] **P1-4 Walk-cycle animation** — while moving, the player plays the
      4-frame `side/walk.png` strip at the existing `WALK_HZ`; idle shows
      `side/idle.png`; the pixel-offset hop is removed for characters that
      have a strip and remains as fallback otherwise. (blocked on P1-3)
- [ ] **P1-5 Monster 2-direction conversion** — monsters follow the same
      left/right facing rule; monsters without side-view art keep current
      sprites but stop using 8-direction buckets. (art regeneration is a later
      asset session)

### M2 — Meta progression

- [ ] **M2-1 Bank run gold** — the gold in a run's result is added to the profile's
      `gold` save value exactly once, survives restart, and is not double-counted on
      a results screen re-entry.
- [ ] **M2-2 Gold character unlock** — a character with `unlock.type == "gold"` can be
      bought on the character-select screen when the profile has `cost` gold; the gold
      is deducted, the unlock persists, and an insufficient balance is refused with a
      readable reason.
- [ ] **M2-3 Workshop: one permanent upgrade** — a single gold-priced permanent stat
      upgrade bought in the camp Workshop and applied to the next run.
- [ ] **M2-4 Training Ground: one permanent upgrade** — same shape, different stat.
- [ ] **M2-5 Shrine: one permanent upgrade** — same shape, different stat.
- [ ] **M2-6 `data/quests.json` schema + loader** — quest definitions with counter key,
      target and reward, read through `GameData`.
- [ ] **M2-7 Quest claim flow** — a completed quest can be claimed once on the
      achievements/quests screen and pays its reward.

### M3 — Content

- [ ] **M3-1 Abandoned Temple stage data** — a second `data/stages.json` entry using
      existing monsters, validated by `tools/validate_data.gd`.
- [ ] **M3-2 Stage unlock rule** — the second area unlocks on a recorded condition and
      area select reflects it.
- [ ] **M3-3 Second boss** — one boss entry plus its spawn behaviour.
- [ ] **M3-4..N New weapon** — one weapon per session toward the MVP bar of 20.
- [ ] **M3-x Achievements batch** — small batches toward the MVP bar of 50.

### M4 — Release readiness

- [ ] **M4-1 Ad SDK integration** behind `AdsService`
- [ ] **M4-2 Analytics SDK integration** behind `AnalyticsService` + PII audit
- [ ] **M4-3 Balance pass** against `data/BALANCE.md`
- [ ] **M4-4 Export verification** (Android / iOS / PC)
- [ ] **M4-5 Owner-supplied asset integration** (see `ASSET_REQUIREMENTS.md`)
- [ ] **M4-6 Localization completeness** — no hardcoded display strings

---

## 3. Tech debt

Each entry is a normal feature session when it is picked up. Do not fold one into an
unrelated commit.

- [ ] **DEBT-1** `scripts/ui/level_up_choice.gd` `_tier_for()` calls `GameData.weapon()`
      with choice ids (`choice_old_talisman_upgrade`, `w`, `u`), producing
      `push_error` noise on every level-up and in the test run. Resolve the tier from
      the choice's weapon id instead.
- [ ] **DEBT-2** Godot `*.import` files are tracked and rewrite themselves per machine,
      so a second checkout showed ~1800 modified files. Decide: gitignore them or
      normalise them.
- [ ] **DEBT-3** `ARCHITECTURE.md` §1 documented a six-worktree parallel ownership
      contract. The worktrees are gone (2026-08-13); the section now describes the
      single-session workflow. Re-check the rest of the document for leftover
      "worktree owns X" phrasing when next editing it.
- [ ] **DEBT-4** Autoload `_ready()` never fires under the headless test runner
      (`docs/CI.md`), so `_ready`-driven logic is untestable there. Revisit if it
      starts hiding real defects.
- [ ] **DEBT-5** `scripts/core/run_state.gd` is 512 lines — the largest file in the
      project. Split only if a feature needs to touch it and the size is in the way.

---

## 4. Done log

| Date | Feature | Commit |
|---|---|---|
| 2026-08-13 | Development process switched to the one-feature loop; parallel worktrees removed | see git log |
| 2026-08-14 | P1 framework pivot planned: side-view 2-direction art + character weapon identity; codex sprite worktree dispatched | see git log |
