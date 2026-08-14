# JOSEONLIKE — Tasks

One feature per session, per [CLAUDE.md](CLAUDE.md). Milestones: [ROADMAP.md](ROADMAP.md).
Tick a box only after commit **and** push succeeded.

Baseline recorded 2026-08-13 at commit `9d3b8b5`:
`godot --headless --path . --script tests/run_tests.gd` → `PASS 22 file(s): 22 passed, 0 failed, 0 errored`.

2026-08-14: GDD v2(빌드·전리품 개편) 채택. 백로그를 R-시리즈로 재편.
기존 시스템은 재개발의 토대다 — 버리지 않고 개조한다.

---

## 1. State inventory

### KEEP — working, tested, do not rewrite

- [x] Core autoloads — `EventBus`, `GameData`, `SaveManager`, `RunState`, `SceneRouter`
- [x] Boot → data load → title routing
- [x] Title screen (layered backdrop, music, menu)
- [x] Settings screen — Master/Music/Effects sliders, ko/en language, persisted
- [x] Camp screen — walkable camp, building panels, Archive → achievements/quests
- [x] Character select — 3 characters, unlock state displayed
- [x] Area select — Bamboo Forest selectable, other areas rendered locked
- [x] Combat stage — spawner, wave schedule, boss spawn, contact damage, death
- [x] Auto-attack weapons — sword, bow, talisman, projectiles, melee arc, evolution
- [x] XP drops, pickups, level-up choice, weapon/passive grants
- [x] HUD — hp/xp/timer/kills/weapon chips, pause overlay
- [x] Results screen — time, kills, gold and newly unlocked achievements
- [x] Achievement tracker with counters and gold rewards
- [x] Quest counters (daily reset, story counters) — data-less scaffolding
- [x] `MusicDirector` + `Music`/`Effects` audio buses
- [x] Headless test runner, 22 test files, `tools/validate_data.gd`, GitHub Actions CI

### BROKEN — known defects

- Run gold is never banked (구 M2-1) — R5 엽전 환전으로 재설계 예정
- `unlock.type == "gold"` always locked (구 M2-2) — R5 `unlocks.json`으로 대체 예정
- Level-up choice logs unknown weapon id errors (`DEBT-1`)

### UNUSED — present but nothing calls it

- `scripts/services/ads.gd`, `scripts/services/analytics.gd` — RZ 스텁 유지.
- 18 of 22 monsters in `data/monsters.json` unused — R2 드랍 테이블/ R6 지역에서 소비.
- Camp Workshop / Training Ground / Shrine "Coming soon" — GDD v2 §24 기준 재정의 대상.

### ASSETS — side-sprites worktree (A-트랙)

- v3 스프라이트(도사/무관/궁수, idle+walk) `side-sprites` 워크트리 커밋
  `4967433` 검수 통과, main 머지 대기. 오너 승인 후 A-1.

---

## 2. Feature backlog

### R1 — 첫 실행 경험 (FTUE) — CURRENT

GDD §28. 목표: 설치 첫 10분 안에 "전리품 → 무기 변화" 1회 체험.

- [ ] **R1-1 첫 부팅 분기** — 세이브가 없으면 타이틀 [모험 시작]이 캐릭터/
      지역 선택을 생략하고 도사+대나무숲으로 즉시 출정한다; 세이브가 있으면
      기존 흐름 그대로다 (회귀 기준).
- [ ] **R1-2 조작 오버레이** — 첫 출정 개시 시 이동 안내 오버레이가 1회
      표시되고, 입력이 들어오면 사라지며, 다시는 나타나지 않는다.
- [ ] **R1-3 첫 판 축약 스크립트** — 첫 판만 별도 웨이브 테이블: 30초 내
      보장 전리품 드랍, 5분 전후 약화 보스, 이후 판은 정식 테이블.
- [ ] **R1-4 첫 개조 팝업 튜토리얼** — 첫 특수 재료 획득 시 3택 팝업이
      1회성 설명과 함께 뜨고, 선택 결과가 무기에 즉시 반영된다.
      (R2-3/R2-4 최소 구현을 전제로 하며, 순서상 R2 코어를 먼저 당겨도 된다)
- [ ] **R1-5 첫 귀환 하이라이트** — 첫 클리어/사망 후 본거지에서 괴이록·
      지역 선택 두 곳만 하이라이트된다.

주의: R1-4가 R2 코어(드랍→픽업→팝업)를 필요로 하므로, 실제 세션 순서는
R2-1→R2-2→R2-3→R1 순으로 당겨 잡아도 된다. 세션 시작 시 판단.

### R2 — 전리품 코어 루프

GDD §4, §6, §7, §20, §33.

- [x] **R2-1 loot 스키마+로더** — `data/loot.json`(id, 이름 ko/en, tier,
      태그, 특수 여부)과 `data/drop_tables.json`을 `GameData`가 로드하고
      `tools/validate_data.gd`가 교차 검증한다.
- [x] **R2-2 드랍→픽업** — 몬스터 사망 시 드랍 테이블 확률로 전리품
      엔티티가 생성되고 자석 반경에서 흡수된다; 일반 재료는 자동 누적.
- [x] **R2-3 특수 재료 3택 팝업** — 특수 재료 획득 시 시간 정지 팝업
      (사용/보관/분해→런 골드). 인벤 6칸 제한과 엽전 환전은 R5로 유예.
- [x] **R2-4 개조 레시피** — `data/weapon_mods.json`: 환도+숫돌→예리한
      환도, 환도+귀철→귀철도, 환도+화령석→화염도. 적용 시 무기 교체.
- [ ] **R2-5 개조 체감** — 3갈래가 실제로 다르게 동작한다 (참격 관통 /
      흡혈+자해 / 화상 지속피해). 상태이상 태그 최소 구현 포함.

### R3 — 무기 등급 (코스 그레인, R2 완료 후 상세화)

- [ ] R3-1 등급 데이터 스키마 (weapons.json 확장, 등급 6단계 효과)
- [ ] R3-2 재료 누적/레벨업 강화 선택으로 등급 상승
- [ ] R3-3 신화 도달 = 빌드 완성 연출 + 기록

### R4 — 15분 페이싱 (코스 그레인)

- [ ] R4-1 정예 몬스터 (전용 표시 + 드랍 미리보기)
- [ ] R4-2 중간 보스 / 대량 공세 웨이브
- [ ] R4-3 소프트 인레이지 + BALANCE.md 곡선 정리
- [ ] R4-4 첫 판 축약 테이블 분리 (R1-3과 연동)

### R5 — 괴이록과 해금 (코스 그레인)

- [ ] R5-1 괴이록 화면 (??? 표시, 발견 공개)
- [ ] R5-2 `unlocks.json` 조건형 해금 + 기존 achievement 통합
- [ ] R5-3 발견형 해금 1종 (`secret_recipes.json`)
- [ ] R5-4 엽전 환전 + 사망 결과 화면 (구 M2-1 대체)

### R6 — 콘텐츠 확장 (코스 그레인)

지역 1개 = 1세션 묶음, 캐릭터 1명 = 1세션 묶음. GDD §8, §30 순서 참조.

### A-트랙 — 사이드뷰 아트 (게임플레이 커밋과 분리)

- [x] **A-1 스프라이트 머지** — `side-sprites` v5(워크 사이클 포함,
      `97eb0d0`)를 main에 머지, 씬 참조 없이 에셋만. (v6 Character.png
      기반 재생성이 워크트리에서 진행 중 — 완료 시 재머지)
- [x] **A-2 2방향 facing** — 좌/우 facing (수평 이동이 방향 결정, 수직은
      유지), `CharacterMotion.facing_sign` 단위 테스트, side 아트 보유 시
      플레이어가 8방향 버킷을 쓰지 않음.
- [x] **A-3 워크 사이클** — 이동 중 4프레임 walk 스트립 재생(hframes),
      idle 프레임, 16x export 역스케일 로드, 오프셋 홉은 side 아트 없는
      캐릭터 폴백으로 유지.
- [ ] **A-4 몬스터 2방향 전환** — 8방향 버킷 미사용화 (아트 재생성은 별도).
- [ ] A-5+ 신규 캐릭터/몬스터 스프라이트 생성 세션 (Higgsfield 파이프라인)

---

## 3. Tech debt

- [ ] **DEBT-1** `scripts/ui/level_up_choice.gd` `_tier_for()` choice id로
      `GameData.weapon()` 호출 → push_error 노이즈. 무기 id로 해석하도록 수정.
- [ ] **DEBT-2** `*.import` 파일 추적 문제 (~1800 modified). gitignore 여부 결정.
- [ ] **DEBT-3** `ARCHITECTURE.md` 워크트리 잔재 표현 정리.
- [ ] **DEBT-4** headless 러너에서 autoload `_ready()` 미실행 (docs/CI.md).
- [ ] **DEBT-5** `run_state.gd` 512줄 — 필요 시 분리.
- [ ] **DEBT-6** GDD v2로 무효화된 코드 식별 (골드 구매 해금 경로 등) —
      R5 진입 시 정리 세션으로.

---

## 4. Done log

| Date | Feature | Commit |
|---|---|---|
| 2026-08-13 | Development process switched to the one-feature loop | see git log |
| 2026-08-14 | P1 framework pivot planned (side-view + weapon identity) | `1f478ab` |
| 2026-08-14 | Character visual design bible + roster expansion | `b4e3921` |
| 2026-08-14 | v3 side-view sprites (side-sprites worktree, codex+Higgsfield) | `4967433` (worktree) |
| 2026-08-14 | GDD v2 build & loot revision adopted; R-series backlog | see git log |
| 2026-08-14 | R2-1 loot schema + loader (`loot.json`, `drop_tables.json`, GameData accessors, validator, tests 23/23) | see git log |
| 2026-08-14 | R2-2 loot drop → pickup (LootDrops.roll, DropPool loot spawn, RunState.loot_counts, tests 24/24, soak-verified) | see git log |
| 2026-08-14 | R2-4 weapon mod recipes (`weapon_mods.json`, GameData.mod_for, RunState.apply_weapon_mod, weapon_modified signal, tests 25/25) | see git log |
| 2026-08-14 | R2-3 special-loot 3-choice popup (use/keep/salvage, taoist talisman recipes, salvage_gold data, tests 26/26) | see git log |
| 2026-08-14 | Talisman rework on owner feedback: orbit+homing removed, straight throw at nearest visible enemy; projectile homing/orbit code deleted | see git log |
| 2026-08-14 | Burn status (R2-5 taoist line): BurnStatus DoT, on_hit_status data on fire/phoenix talisman, projectile carrier, tests 27/27 | `a2a9c12` |
