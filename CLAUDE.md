# JOSEONLIKE — Working Rules

Godot 4.7, GDScript (statically typed), mobile-first 540x960 portrait.
Repository is the memory of this project. A previous chat session is **not** project state.

---

## 1. The loop (mandatory)

```
Fresh Session
  → read git status / log + ROADMAP.md + TASKS.md
  → pick exactly ONE feature
  → write its Acceptance Criteria
  → implement
  → static + automated verification
  → Godot runtime verification
  → review (independent context when the change is non-trivial)
  → fix until PASS
  → final verification
  → update docs (TASKS.md, ROADMAP.md, ASSET_REQUIREMENTS.md)
  → commit
  → push
  → END SESSION
```

**One feature = one session = one commit.** Never start the next feature in the
same session. Never commit unverified work.

**Serial only (owner direction 2026-08-14).** Run one worker at a time. Finish
the feature, verify it, commit, push, show the owner, then start the next from
the queue in [TASKS.md](TASKS.md). Do not fan out parallel workers across
worktrees; the only exception is an asset-generation task that touches no game
code and lands as its own commit.

A "feature" is a single verifiable behaviour: `enemy death drop`, `gold spend in
workshop`, `pause menu resume`. `combat system` is not a feature — decompose it.

## 2. Acceptance Criteria first

No code before the criteria are written down in the session. Each criterion must be
checkable by a test or by a described runtime action. Include a regression criterion
naming what must keep working.

## 3. Verification commands

```sh
godot --headless --path . --import                          # class cache; required first
godot --headless --path . --script tests/run_tests.gd       # unit suite, must print PASS
godot --headless --path . --script tools/validate_data.gd   # data cross-reference check
godot --path .                                              # runtime check, actually play it
```

Runtime check covers: no crash, no new `ERROR`/`push_error` output, scene loads,
input works, the feature does what the criteria say, and the previous feature still works.

Details and known runner gaps: [docs/CI.md](docs/CI.md).

## 4. Implementation rules

- Change only what the current feature needs.
- Simplest implementation that satisfies the criteria. No speculative abstraction,
  no framework building, no pre-implementing future systems.
- Prove first, generalize later. Only clearly game-independent systems
  (save, settings, audio, input, localization, logging) get separated up front.
- Existing code is kept. Refactors are their own registered feature in TASKS.md,
  never smuggled into a feature commit.
- Style contract: [ARCHITECTURE.md](ARCHITECTURE.md) §6 (typed vars, no `print()`,
  balance numbers in `data/`, English "why" comments).

## 5. Assets — pipeline, not freeze (revised 2026-08-14)

Art direction: side-view pixel art anchored to the owner-supplied reference
images in `new_asset/` (chunky proportions, 1px outline, flat cel shading;
the anchor set may be replaced by the owner — the folder's current PNGs are
authoritative). Sprites face left/right only; left is an in-engine mirror of
right.

- **Character sprites** are generated in a dedicated asset worktree session
  (codex) from the `new_asset/` style references — never inside a gameplay
  feature commit. Walk cycles must be frame-consistent (derived from one base
  sprite, not independently generated frames).
- **Weapons, props, effects**: free third-party assets; licences go in
  [ASSET_LICENSES.md](ASSET_LICENSES.md).
- New entities without art use `PlaceholderArt`
  (`scripts/combat/placeholder_art.gd`); a missing texture must never block a
  gameplay feature.
- Wanted-but-missing assets go into [ASSET_REQUIREMENTS.md](ASSET_REQUIREMENTS.md).
- Art integration is its own feature commit, separate from gameplay changes.

## 6. Review

Non-trivial change → review it from an independent context before committing.
The reviewer checks only: acceptance criteria met, bugs, regressions, Godot
structure, needless complexity, obvious performance problems, wrong dependencies,
save compatibility, architecture violations. The reviewer does not redesign the game.

Trivial change (one small function, covered by a test that fails without it) →
tests + runtime check are enough.

FAIL → fix → re-verify → re-review. Do not commit on FAIL.

## 7. Commit & push

Conventional Commits, English, one feature per commit:

```
feat(combat): add enemy contact damage cooldown
fix(ui): stop level-up choice logging unknown weapon ids
```

Push must succeed. A feature is not done until `git push` succeeds.

## 8. Session start checklist

1. `git status` / `git log --oneline -10`
2. Read `ROADMAP.md` and `TASKS.md`
3. Read only the code the chosen feature touches — do not scan the whole repo
4. Pick one unblocked, smallest-value-adding feature
5. Write acceptance criteria, then start

## 9. Model / agent usage

Use the cheap path by default. Reserve the strong model for architecture decisions,
hard bugs, and difficult reviews. Do not keep several agents alive analysing the
whole repository — Orca orchestration is for running this loop, not for parallel
long-lived worktree teams.

## 10. Source of truth

`CLAUDE.md` · `ARCHITECTURE.md` · `JOSEONLIKE_GDD.md` · `ROADMAP.md` · `TASKS.md` ·
`ASSET_SPEC.md` · `ASSET_REQUIREMENTS.md` · `ASSET_LICENSES.md` · `data/BALANCE.md` ·
`docs/CI.md` · the code · the git history. Nothing else.
