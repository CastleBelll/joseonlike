# JOSEONLIKE — Roadmap

Milestone order. One feature at a time, per [CLAUDE.md](CLAUDE.md).
Feature-level breakdown and current state: [TASKS.md](TASKS.md).

---

## M1 — Vertical slice — **DONE**

`boot → title → camp → character select → area select → Bamboo Forest → auto combat →
level-up choice → boss → results`, with settings, achievements, quest counters,
music and SFX buses. 22 headless test files pass.

## P1 — Framework pivot: side-view + character identity — **CURRENT**

Direction change (2026-08-14, owner decision). The 8-direction rotation art is
retired. The game presents as 2D side-view: sprites face left/right only, left
is a mirror, walking is a real 4-frame cycle. Character sprites are regenerated
in the `new_asset/basic.png` style by a codex asset worktree; weapons and props
will come from free assets. Each character also gets a hard weapon identity —
allowed weapon categories in data, enforced in the level-up offer.

1. 2-direction facing: player faces left/right from horizontal movement,
   vertical movement keeps last facing (`P1-1`).
2. Character weapon identity in data + level-up filtering (`P1-2`).
3. Integrate codex side-view sprites for Taoist/Warrior/Archer (`P1-3`).
4. Real walk-cycle animation replacing the pixel-offset hop (`P1-4`).
5. Monsters converted to the 2-direction rule (`P1-5`).

Exit condition: no scene renders an 8-direction rotation sprite for the player,
the three characters animate side-view walks, and no character can be offered a
weapon outside its categories.

## M2 — Meta progression that sticks — **NEXT**

The run loop plays, but almost nothing a run produces survives it. M2 closes that.

1. Bank the gold a run earns into the profile (today it is displayed and dropped).
2. Spend gold: character unlock purchase (`unlock.type == "gold"` currently always
   returns locked, so Archer is unreachable).
3. Make one camp building do something real, then the next
   (Workshop → Training Ground → Shrine). Archive already routes to achievements/quests.
4. Quest definitions in data, so the counters `Quests` already tracks have targets
   and rewards.

Exit condition: a player who clears a run is measurably stronger or richer next run,
and every camp building either works or is removed from the screen.

## M3 — Content breadth

Data-driven expansion on top of a proven loop. 18 monsters already exist in
`data/monsters.json` with no stage using them.

1. Second stage — Abandoned Temple (GDD §14) with its own waves and boss.
2. Stage unlock rule (area select already renders locked cards).
3. Weapons toward the MVP bar of 20, one weapon per session.
4. Remaining bosses (MVP bar: 3).
5. Achievements toward the MVP bar of 50.

## M4 — Release readiness

1. Real ad SDK behind `AdsService` (stub today).
2. Real analytics SDK behind `AnalyticsService` (stub today), PII audit.
3. Balance pass against `data/BALANCE.md`.
4. Export verification for Android/iOS/PC.
5. Owner-supplied asset integration pass (see [ASSET_REQUIREMENTS.md](ASSET_REQUIREMENTS.md)).
6. Localization completeness check (`ko`/`en`, no hardcoded strings).

---

## MVP bar (GDD §16) vs. today

| Item | Target | Now |
|---|---|---|
| Characters | 3 | 3 defined, 1 reachable (Warrior needs an achievement, Archer's gold unlock is not implemented) |
| Areas | 2 | 1 |
| Weapons | 20 | 7 |
| Monsters | 15 | 22 defined, 4 used |
| Bosses | 3 | 1 |
| Achievements | 50 | 8 |
