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
- [x] N1-2 codex AC-2 아트 통합 (배경 레이어 + 현판 로고)
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

- [x] **N4-2 무기 등급 + 15분 페이싱** — weapons.json `_grades` 사다리
      (일반→고급→희귀→영웅→신화, 단계별 데이터 배수 + mythic tinted 플래그),
      레벨업 `등급↑` 카드 / 개조 등급 승계(max(승계, 결과 기본)), 최상위
      도달 골드 콜아웃(DamageNumber 재사용), bamboo_forest 15분 커브
      (900s 보스, 840s 대량 공세 피크, 5분부터 정예), `bamboo_brute_elite`
      (elite_of 배수 파생 + 전용 희귀 드랍), soft_enrage(920s+, 스폰 시
      스탯 스케일), RunFlow 스케줄 불변식 + validate_data 등급/정예/페이싱
      크로스체크, 보스 hp 7000 재조정
- [x] **N4-6 전리품 자동 획득 + 개조 레벨업 카드 흡수** — 특수 재료 3택
      팝업과 큐잉 삭제 (DESIGN.md §5.2 인터랙션 예산), 모든 재료는 XP·엽전
      처럼 무음 자동 획득 (특수 재료만 데미지 숫자 스타일 플로팅 라벨),
      쓸 수 없는 재료(레시피 없음/결과 무기 보유/개조로 대체됨)는 픽업
      즉시 자동 분해 → 엽전, 재료+기반 무기 보유 시 "개조" 카드가 레벨업
      3택에 등장(화면당 최대 1장, 결과 무기 등급 필 + 실수치), 선택 시
      재료 소모 + 레벨·등급 승계 스왑, **개조로 대체된 무기는 신규·강화
      풀에서 런 내내 영구 제외 (오너 리포트 버그 픽스, 회귀 테스트 포함)**,
      개조 후 죽은 인벤토리 자동 정산
- [x] **N4-2b 5분 런 리스케일** — 오너 결정(모바일 1런 = 5분) 반영:
      bamboo_forest 300s 커브 (2:00 정예, 3:30 대량 공세 피크 57, 4:00 보스,
      4:40 소프트 인레이지, 5:00 타임아웃 승리), XP 곡선 6×1.5^(L-1)로
      런당 레벨업 8~10회, 초반 드랍 테이블 특수 재료 바이어스(첫 런 내
      개조 팝업 보장), 보스 hp 2400, schedule_issues에 duration_sec 초과
      불변식 추가, tools/playtest.tscn 자동 플레이 검증 하네스

---

## 작업 큐 (오너 지시 2026-08-14: 한 번에 하나씩)

병렬 작업은 여기서 끝난다. 아래 순서대로 **하나 개발 → 검증 → 커밋/푸시
→ 오너 확인 → 다음**. 진행 중인 3건(N1-2 타이틀 아트 연결, N2-1 수행자
선택, N4-2 등급·페이싱)이 착지하면 이 큐로 전환한다.

**게이트 (오너 지시 2026-08-14)**: **도사가 완성되기 전에는 두 번째
캐릭터도 두 번째 지역도 착수하지 않는다.** 도사의 스킬 4~5종과 빌드
분기가 실제로 플레이 가능해야 다음 콘텐츠로 넘어간다.

우선순위는 (1) 지금 눈에 보이는 전투 결함 → (2) 도사 완성 → (3) 다듬기
→ (4) 신규 콘텐츠 순이다.

| # | 작업 | 왜 지금 |
|---|---|---|
| 1 | ~~**N3-14 몬스터 겹침 해소**~~ ✅ | 완료 — 그리드 기반 분리 조향, 평균 겹침 8.46 → 0.00 (플레이테스트 261/240 샘플) |
| 2 | ~~**N3-15 조준 범위를 화면 안으로**~~ ✅ | 완료 — 뷰 렉트+마진 내 & 무기 range_px 내 적만 조준, 대상 없으면 발사 보류, 투사체 화면 밖 소멸 |
| 3 | ~~**N4-4a 도사 핵심 무기 6종**~~ ✅ | 완료 — 6종 메커니즘(단일/폭발/연쇄/근접원호/선회도트/관통) + 개조 분기 5종(화령부·뇌정부·봉마검·귀철석장·화령혼불) 데이터 구동. 봉인은 법검 분기로 이동, lightning_talisman 삭제. 플레이테스트: 승리 298.5s, 서지 fps min 59, peak live 51 |
| 4 | ~~**N4-4b 도사 확장 4종 + 액티브 2종**~~ ✅ | 완료 — 결계(장판 도트+감속)·신장(자율 소환, 프롭 충돌)·진언(주기 파동 넉백+기절)·살(사망 전염 저주) + 개조 분기 4종(화염 결계·뇌정 신장·봉인 진언·귀살), 축지(순보+무적)·벽사진(비상 일소) HUD 우하단 클러스터. 그랜트 플레이테스트: 승리 300s, 서지 fps min 59, peak live 58 |
| 4.5 | ~~**N3-16 바닥 렌더 범위 버그**~~ ✅ | 완료 — GroundLayer가 카메라 시야 타일 윈도우를 따라간다 (좌표+시드 순수함수 배리언트/회전, 윈도우 변경 시에만 redraw). 필드 코너 스크린샷으로 회색 밴드 소멸 확인 (tools/ground_check.tscn) |
| 5 | ~~**N4-3 5분 런 밸런스 패스 (측정 기반)**~~ ✅ | 완료 — playtest 강제 빌드(`--weapon`)/배치(`--batch`)/시드/배속 하네스로 10무기 전수 측정. BEFORE 스프레드 35x(혼불 트랩 136dmg) → AFTER 3시드 평균 2.3x. 혼불 궤도 링·진언·신장·결계 구조 수정, edge_falloff/pierce_retention/orb_radius_px 데이터 이관. 서지 ranged 14→18 + enrage 속도 1.45로 순수 회피 봉쇄(노픽 빌드 seed99 사망). 헤비 빌드(6무기 동시) 서지 fps min 59 |
| 6 | ~~**N6-1 첫 실행 흐름(FTUE)**~~ ✅ | 완료 — 첫 부팅 도사 고정 즉시 출정(Ftue.route_character), 조이스틱 이동 힌트 1회(입력 시 해제, 프로필 영속), 첫 개조 카드 1줄 설명("재료로 무기를 바꾼다") 1회, stages.json first_run_drops로 부적지 ≤30s·도깨비불 60s 보장 드랍. 플레이테스트: 힌트 표시→해제, 보장 10.95s/63.9s 발화, 개조 70.3s, 재실행 시 힌트·설명·보장 모두 미발화 |
| 7.5 | ~~**N3-17 카드 오버플로 + 무기 이펙트 품질**~~ ✅ | 완료 — 레벨업 카드가 설명 랩핑 높이에 맞춰 성장(고정 136px 폐지, 최악 데이터 검증 테스트 + tools/popup_check.tscn), 10무기 코드사이드 이펙트 패스(폭발 링/연쇄 번개 볼트/석장 스윕/혼불 글로우+트레일/법검 잔상/결계 틱 펄스/신장 타격 플래시/진언 링+카메라 넛지/살 저주 마크+전파 점프/축지 2점 퍼프/벽사진 전면 플래시), 타이밍 data/effects.json weapon_effects |
| 7 | ~~**N3-13 무기·전리품 아이콘 아트 연결**~~ ✅ | 완료 — 레벨업/개조 카드 웰·보유 무기 스트립이 weapons.json id로 asset/ui 아이콘 바인딩(아이콘 없으면 글자 폴백, 패시브만 해당), 개조 카드에 재료 아이콘 배지, HUD 해골/엽전/일시정지/정보 실아이콘(16px 1x·32px 2x NEAREST), 나무 버튼·종이 패널 9-slice 전환(창살은 패널 텍스처에 내장, GOLD 포커스 링 유지), validate_data가 아이콘 없는 무기/전리품 id 보고. 테스트 205/205, 플레이테스트 승리 300s·보스 처치·서지 fps 60 |
| 8 | **N5-3 본거지(캠프) 최소판** | 런 사이 거점 |
| 9 | **N7-1 명부수형 메타 트리** | 엽전 영구 강화, 설화 `_02` 문법 |
| 10 | **N5-4 괴이록(도감)** | 처치·획득 기록, 미발견은 ??? |
| 11 | **N9-1 사운드** | BGM + 효과음 |
| — | **게이트 통과 후** | |
| 12 | N8-1 두 번째 캐릭터 | 도사 완성 확인 후 |
| 13 | N8-2 두 번째 지역 (공동묘지) | 도사 완성 확인 후 |
| 14 | RZ-1 안드로이드 실기기 검증 | |

큐 밖(수시): 오너가 `new_asset/`에 에셋 떨구면 가공·연결 커밋 1건.

## AC-트랙 — 에셋 (codex, 별도 커밋)

- [x] **AC-1 도사 캐릭터 세트** — 인월드 idle+walk4 + 선택 카드 초상
      (오너 제공 시트 가공)
- [x] AC-2 타이틀 아트 (밤하늘/한옥 마을/현판 로고 ko·en)
- [x] AC-3 UI 크롬 (나무 버튼 9-slice/창살 코너/무기·전리품 아이콘) —
      아트 커밋(009e7b0) + N3-13 연결로 완료
- [x] AC-4 전장 타일/프롭 (대나무숲 야간, 조용한 바닥 타일 재생성 포함)
- [x] AC-5 몬스터 1지역분 (도깨비/원혼/거한/정령왕)

---

## Done log

| Date | Feature | Commit |
|---|---|---|
| 2026-08-14 | Full rebuild decision; docs reset (DESIGN v3 / ROADMAP / TASKS) | — |
| 2026-08-14 | N0-1 repo reset (old code/assets removed, font kept) | 7042085 |
| 2026-08-14 | N0-2 minimal boot: title stub + test runner + data validator | — |
| 2026-08-14 | N1-2 title art integration: sky/village texture layers + locale-swapped signboard logo | — |
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
| 2026-08-14 | N4-2 weapon grades + 15-min pacing: `_grades` ladder/step multipliers in weapons.json, grade-up level-up card + mod grade carry + top-grade gold callout, 15-min bamboo_forest wave curve (elite from 5:00, surge peak 840s, boss 900s, soft enrage 920s+), `bamboo_brute_elite` data-derived elite + rare-material drop table, RunFlow schedule invariants, validate_data grade/elite/pacing cross-checks, boss hp 7000 | — |
| 2026-08-14 | N4-2b 5-minute run rescale: 300s bamboo_forest curve (elite 2:00, surge peak 57 at 3:30, boss 4:00 hp 2400, enrage 4:40), XP curve 6×1.5^(L-1) for 8–10 level-ups, early special-material drop bias, duration_sec bound invariant in schedule_issues, autoplay verification harness (tools/playtest.tscn) | — |
| 2026-08-14 | N5-2 autosave/auto-resume + settings popup: SaveProfile pure helpers + SaveService autoload (user://profile.save JSON, temp-rename safe write with crash recovery, schema v1 migration hook, corrupt→warning+fresh), run-end gold banking + lifetime stats, result-screen 보유 엽전 row, paper-panel settings popup (3 volume sliders + 한국어/English toggle, applies live + persists), Master/Music/Effects buses, single-primary-action title | — |
| 2026-08-14 | N3-15 on-screen-only targeting: nearest enemy inside view rect + data margin AND per-weapon range_px (weapons.json `_targeting` + every weapon), hold-fire when nothing visible, projectile expires on leaving view rect + margin, validate_data targeting contract | — |
| 2026-08-14 | N3-14 enemy separation steering: bucketed-grid neighbour lookup (Separation, reused buffers, no per-frame alloc), weighted push blended into chase, boss push-exempt but crowd-blocking, tuning in effects.json, playtest crowd metric avg-stacked 8.46 → 0.00 | — |
| 2026-08-14 | N4-4b taoist extended kit: four new data-driven mechanics (결계 ward DoT+slow, 신장 autonomous prop-colliding summon, 진언 periodic knockback+stun shockwave, 살 death-spreading curse), four mod branches (화염 결계/뇌정 신장/봉인 진언/귀살), two actives (축지 blink+invuln, 벽사진 emergency burst) on a bottom-right HUD cluster, pooled ward/summon/pulse nodes, validate_data + pure-helper test coverage, playtest --grant surge load test 59fps | — |
| 2026-08-14 | N3-16 ground coverage fix: GroundLayer follows the camera's tile window (per-tile seed-hash variant/rotation, redraw only on window change), grey band gone at field edges, coverage invariant test + tools/ground_check.tscn edge screenshot | — |
| 2026-08-14 | N4-6 loot auto-collect + mod-as-level-up-card: special-material popup and queueing deleted (DESIGN.md §5.2), every material collects silently via the magnet path (floating cue label for specials), dead materials auto-salvage to gold at pickup, 개조 card in the level-up 3-pick (max one per screen, result grade pill, real numbers, consumes material, carries level+grade), replaced weapons permanently excluded from new/upgrade pools (owner-reported regression, covered by failing-first test), dead-inventory sweep after each mod | — |
| 2026-08-15 | N4-3 measured balance pass: playtest forced-build/batch/seed/speed harness + damage accounting, 10-weapon sweeps (BEFORE 35x → AFTER 2.3x on 3-seed averages, tables in data/BALANCE.md), 혼불 orbit-ring rework (data orb_radius_px, ring 105px), 진언/신장/결계/석장/화부/법검/살/낡은부적 retunes, new data knobs explosion.edge_falloff + pierce_retention (validate_data + unit tests), surge ranged 14→18 + escort 8→12 + enrage speed 1.45 so a pure-evasion no-pick build can die (seed99 death measured), rendered 6-weapon heavy build surge fps min 59 | — |
| 2026-08-15 | N6-1 FTUE first sixty seconds: pure Ftue helpers (first-boot taoist routing, one-shot move-hint / mod-explain profile flags, first-run guarantee table), profile `ftue` block with migration fill, MoveHint chevron overlay dismissed by first input, one extra 개조-card line "재료로 무기를 바꾼다" once per profile, stages.json `first_run_drops` (부적지 10s, 도깨비불 60s) validated end-to-end, playtest hint shot + first-run report, zero added taps | — |
