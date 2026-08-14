# JOSEONLIKE — Tasks (Full Rebuild)

One feature per session, per [CLAUDE.md](CLAUDE.md). Phases: [ROADMAP.md](ROADMAP.md).
Tick a box only after commit **and** push succeeded.

2026-08-14: 오너 지시로 전면 리빌드. 구 백로그(R-시리즈)와 done log는
git 히스토리(`63b50c8` 이전)에만 남긴다. 구 코드/에셋 참조 금지.

---

## N0 — 리셋 & 부트 — DONE

- [x] **N0-1 리포 리셋** — scenes/ scripts/ tests/ tools/ asset/ 및 구
      게임 파일 제거 (Neo둥근모 ttf + ASSET_LICENSES.md 항목은 유지·이동).
      data/, 문서, example/, new_asset/ 유지. project.godot 정리.
- [x] **N0-2 최소 부트** — NIGHT 배경 + 픽셀 폰트 "조선라이크" 타이틀
      스텁이 에러 없이 뜬다. 헤드리스 테스트 러너 골격이 PASS를 출력한다.

## N1 — 타이틀 — CURRENT

- [x] N1-1 타이틀 레이아웃 (플레이스홀더 아트, DESIGN.md §4 배치)
- [ ] N1-2 codex AC-2 아트 통합 (배경 레이어 + 현판 로고)
- [x] N1-3 설정 팝업 (음량/언어, 자동 저장) — N5-2에서 구현

## N2 — 수행자 선택

- [x] N2-1 characters.json 재검증 + 카드 리스트 화면 (도사 1 + 잠금 카드)
- [x] N2-2 선택 상태 저장/복원, 선택됨 배지 — N2-1에서 함께 구현
      (SaveService persist, 런 시작 시 선택 캐릭터 스탯/무기 사용)
- [ ] N2-3 codex AC-1 초상 통합

## N3 — 전투 수직 슬라이스 (세션 단위로 분해)

- [x] N3-1 스테이지 씬 + 카메라 + 가상 조이스틱 이동
- [x] N3-2 도사 인월드 스프라이트 (AC-1, 2방향 + 4프레임 걷기)
- [x] N3-3 자동 공격 무기 1종 (부적 투척)
- [x] N3-4 몬스터 스폰/추적/접촉 피해/사망
- [x] N3-5 XP 드랍 → 자석 픽업 → 레벨업
- [x] N3-6 파워 업 팝업 (행 카드 문법, 실수치 설명)
- [x] N3-7 전투 HUD (타이머/XP바/카운터, DESIGN.md §3)
- [x] N3-8 피격 피드백 (데미지 숫자는 N3-3에서 선반영)
- [x] N3-9 절차 생성 스테이지 필드 — 대나무숲 프롭 (충돌형 솔리드 + 데코,
      매 런 새 랜덤 배치, data/props.json 카탈로그)
- [x] N3-10 대나무숲 아트 통합 (AC-4) — 실제 타일/프롭 텍스처 렌더링,
      시드 기반 재현 가능한 타일 변형, 하단부 기준 충돌 박스

## N5 — 런 완결 (보스 → 승패 → 결과)

- [x] N5-1a 보스 웨이브 — stages.json `boss_at_sec` 시점 단일 보스 스폰,
      상단 얇은 보스 HP바, 처치 = 승리, 타임아웃 = 승리 (GDD §34 소프트
      인레이지는 클리어 후 잔류로 해석)
- [x] **N5-2 자동 저장·자동 재개 + 설정 팝업** — SaveProfile(순수)/
      SaveService(autoload) user://profile.save JSON, temp-rename 안전 쓰기 +
      크래시 복구, schema v1 마이그레이션 훅, 손상 파일 → 경고 + 새 프로필,
      런 종료 시 엽전 뱅킹(결과 화면 "보유 엽전") + 생애 통계, 설정 팝업
      (음량 3슬라이더 + 한국어/English 토글, 즉시 적용·자동 저장),
      Master/Music/Effects 오디오 버스, 타이틀 단일 프라이머리 버튼
      (이어하기/종료 버튼 없음 — 오너 지시)
- [x] N5-1b 결과 화면 — 종이 패널 (승리/패배, 생존 시간, 처치, 엽전
      표시 전용) + 타이틀 복귀 CTA. 메타/뱅킹은 후속 페이즈

## N4 — 전리품 & 무기 개조

- [x] **N4-1 전리품 드랍 + 자석 픽업 + 특수 재료 3택 팝업** — drop_tables
      기반 시드 롤, 티어 tint 다이아몬드 풀링 드랍, XP 오브 자석 경로 재사용,
      RunState 런 인벤토리, 특수 재료 사용(무기 변신·레벨 유지)/보관/분해
      팝업 (행 카드 컴포넌트 공유, 큐잉으로 패널 중첩 금지)

## N4+ — ROADMAP.md 페이즈 진입 시 세분화

## AC-트랙 — 에셋 (codex, 별도 커밋)

- [ ] **AC-1 도사 캐릭터 세트** — 인월드 idle+walk4 좌우 + 선택 카드 초상
- [ ] AC-2 타이틀 아트 (배경/현판/등롱)
- [ ] AC-3 UI 크롬 (나무 버튼/종이 패널/창살/아이콘)
- [ ] AC-4 전장 타일/프롭/XP 오브
- [ ] AC-5 몬스터 1지역분

---

## Done log

| Date | Feature | Commit |
|---|---|---|
| 2026-08-14 | Full rebuild decision; docs reset (DESIGN v3 / ROADMAP / TASKS) | — |
| 2026-08-14 | N0-1 repo reset (old code/assets removed, font kept) | 7042085 |
| 2026-08-14 | N0-2 minimal boot: title stub + test runner + data validator | — |
| 2026-08-14 | N1-1 design tokens (UiPalette/UiLocale/WoodButton, global theme) + title layout | — |
| 2026-08-14 | N3-1 stage scene: camera-follow player, touch joystick + WASD, title routing | — |
| 2026-08-14 | N3-4 enemy spawn/chase/contact damage/death: pooled wave spawner, player HP + invuln, data cross-checks | — |
| 2026-08-14 | N3-3 + N3-5 auto-attack talisman, damage numbers, XP orbs + magnet, RunState leveling (progression.json curve) | — |
| 2026-08-14 | N3-6 power-up popup: paper panel row cards, real-number descriptions, weapon levels + passive stacks, queued multi-level | — |
| 2026-08-14 | N3-2 taoist in-world sprite: idle + 4-frame walk (8fps, speed-scaled), facing mirror, 16x NEAREST downscale | — |
| 2026-08-14 | N3-7 combat HUD: outlined timer, thin XP bar, Lv/kill/gold counters, glyph placeholder icons, paper-panel pause overlay, minimal player HP bar | — |
| 2026-08-14 | N3-9 procedural bamboo forest field: data/props.json catalogue, seeded deterministic scatter, solid StaticBody2D props, enemy slide/avoid steering, Y-sorted world | — |
| 2026-08-14 | N3-8 hit feedback: white flash + knockback (data/effects.json), pooled particle-free death puff, player screen-edge vermilion vignette | — |
| 2026-08-14 | N5-1a boss wave: data-driven boss_at_sec spawn, no-despawn/no-cap boss, top thin HP bar, gold boss damage numbers | — |
| 2026-08-14 | N5-1b run result screen: RunFlow outcome arbiter (death > boss kill > timeout-as-victory), paper-panel 승리/패배 + time/kills/gold, CTA to title | — |
| 2026-08-14 | N3-10 bamboo forest art integration: real tile/prop/decor textures, seeded ground-variant tiling (GroundLayer), base-footprint collision boxes rebuilt from delivered art | — |
| 2026-08-14 | N4-1 loot drops + magnet pickup + special-material 3-choice popup: seeded drop rolls, tier-tinted pooled diamonds via XP-orb magnet path, RunState run inventory, use/keep/salvage cards on the shared paper-panel component, weapon-mod swap carrying level, tinted modded projectiles, loot data cross-checks | — |
| 2026-08-14 | N3-12 monster/boss sprite wiring: data-driven sprite sets (idle + 4-frame walk, boss idle_breathe), shared SpriteSheet builder with the player, facing mirror + overbright hit flash, footprint-based hurt circles, validate_data sprite-file check | — |
| 2026-08-14 | N3-11 fix: prop render scale now derived from visible silhouette content (not the padded export canvas) so declared logical heights actually render; ground variants placed as sparse noise-clustered patches with per-tile rotation instead of an even scatter | — |
| 2026-08-14 | N2-1 수행자 선택 screen: full-width row cards from characters.json (accent name + hanja, 칭호, quoted line, NEAREST portrait well), GOLD-border 선택됨 badge, silhouetted locked cards with unlock text, SaveService-persisted selection consumed by the run, title corner-utility entry, card copy/accent/unlock cross-checks in validate_data | — |
| 2026-08-14 | N5-2 autosave/auto-resume + settings popup: SaveProfile pure helpers + SaveService autoload (user://profile.save JSON, temp-rename safe write with crash recovery, schema v1 migration hook, corrupt→warning+fresh), run-end gold banking + lifetime stats, result-screen 보유 엽전 row, paper-panel settings popup (3 volume sliders + 한국어/English toggle, applies live + persists), Master/Music/Effects buses, single-primary-action title | — |
