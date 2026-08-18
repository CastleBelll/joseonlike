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
| A | ~~**N7-2 메타 경제 재설계 + 캐릭터별 특화**~~ ✅ | 완료 (2026-08-16) — 22노드(공용 트렁크 13 + 도사 5 + 무사 2 + 궁수 2), 도사 총액 1,330→14,990냥(~35-40런), 랭크별 증가 비용 곡선을 validate_data가 강제, 신규 노드 종류(엽전/경험치 획득, 2레벨 출정, 4장 선택지, 재료 보장, 피해 감소, 무적 연장, 회생부) 전부 배선, 도사 술법 분기(화상 지속/연쇄 도약/결계 반경/혼불 구슬/봉인 중첩)는 무기 데이터 스탯 재사용, 캐릭터 간 누출 금지 테스트, 잠긴 캐릭터 분기 = 해금 조건 명시 잠금 콘텐츠, 탭 UI. 측정: 뇌부 연쇄 3→5, dps 22.2→32.4 |
| B | ~~**N3-18 기술 이펙트 재작업**~~ ✅ | 완료 (2026-08-16) — 12종 전수 before/after 캡처 진단 후 재작업. 화부: 팩 스프라이트 폐기(마젠타 광선 + 실반경 절반 거짓) → 코드 폭발(골드 코어 플래시→데이터 반경 착지 링+엠버 스파크). 신장 타격: 스프라이트 폐기 → X-슬래시 확대. 뇌부: 첫 타 크랙클(chain_first_leg_px) + 볼트 두께/지속 데이터화 — 이전엔 필드에서 사실상 안 보임. 석장: 이중 실선 → 채운 부채꼴+밝은 리딩 엣지. 혼불: 2.1x 글로우 안개 덩어리 → 히트 반경 캡 글로우+3로브 불꽃+짧은 트레일. 결계: 디버그 원 → 회전 대시 링+팔각 성형 진. 진언/벽사진: 불투명 팬케이크 → WAVE 스타일 이중 링(데이터 반경 정착), 스크린 플래시 0.28→0.14 알파·0.22s. 축지: ACCENT_TAOIST 모듈레이트(야간에 검정) → WEAPON_SOUL. 부적/법검: 투사체 크기 데이터화+비행 트레일. 살: 점프 0.45s. explosion/strike_flash 시트 삭제, blink_puff만 유지. 서지 fps min 59 avg 60(1775 샘플, 기준선 동일), 승리 300s, 테스트 285/285 |
| S | **N9-2 스토리·네이밍 패스** | 오너 지적: 지금 스토리가 전혀 반영 안 된 느낌. GDD 조선 설화 세계관을 실제 텍스트로 내린다 — 도사의 동기와 여정, 지역 배경, 몬스터·보스 유래, 무기·전리품 이름과 한 줄 설명, 화면 문구를 한 목소리로 통일. 화폐 표기(엽전/냥) 정합성도 여기서 정리 |
| 5 | ~~**N4-3 5분 런 밸런스 패스 (측정 기반)**~~ ✅ | 완료 — playtest 강제 빌드(`--weapon`)/배치(`--batch`)/시드/배속 하네스로 10무기 전수 측정. BEFORE 스프레드 35x(혼불 트랩 136dmg) → AFTER 3시드 평균 2.3x. 혼불 궤도 링·진언·신장·결계 구조 수정, edge_falloff/pierce_retention/orb_radius_px 데이터 이관. 서지 ranged 14→18 + enrage 속도 1.45로 순수 회피 봉쇄(노픽 빌드 seed99 사망). 헤비 빌드(6무기 동시) 서지 fps min 59 |
| 6 | ~~**N6-1 첫 실행 흐름(FTUE)**~~ ✅ | 완료 — 첫 부팅 도사 고정 즉시 출정(Ftue.route_character), 조이스틱 이동 힌트 1회(입력 시 해제, 프로필 영속), 첫 개조 카드 1줄 설명("재료로 무기를 바꾼다") 1회, stages.json first_run_drops로 부적지 ≤30s·도깨비불 60s 보장 드랍. 플레이테스트: 힌트 표시→해제, 보장 10.95s/63.9s 발화, 개조 70.3s, 재실행 시 힌트·설명·보장 모두 미발화 |
| 7.5 | ~~**N3-17 카드 오버플로 + 무기 이펙트 품질**~~ ✅ | 완료 — 레벨업 카드가 설명 랩핑 높이에 맞춰 성장(고정 136px 폐지, 최악 데이터 검증 테스트 + tools/popup_check.tscn), 10무기 코드사이드 이펙트 패스(폭발 링/연쇄 번개 볼트/석장 스윕/혼불 글로우+트레일/법검 잔상/결계 틱 펄스/신장 타격 플래시/진언 링+카메라 넛지/살 저주 마크+전파 점프/축지 2점 퍼프/벽사진 전면 플래시), 타이밍 data/effects.json weapon_effects. 후속 아트 통합: Retro Impact Pack 5 → asset/effect/ 3종(폭발/타격 플래시/축지 퍼프, EffectSprite 풀, sprite_effects 데이터, 라이선스 미확인 — 오너 확인 필요), 파라메트릭 이펙트(볼트/링/트레일/마크)는 코드 드로잉 유지 |
| 7 | ~~**N3-13 무기·전리품 아이콘 아트 연결**~~ ✅ | 완료 — 레벨업/개조 카드 웰·보유 무기 스트립이 weapons.json id로 asset/ui 아이콘 바인딩(아이콘 없으면 글자 폴백, 패시브만 해당), 개조 카드에 재료 아이콘 배지, HUD 해골/엽전/일시정지/정보 실아이콘(16px 1x·32px 2x NEAREST), 나무 버튼·종이 패널 9-slice 전환(창살은 패널 텍스처에 내장, GOLD 포커스 링 유지), validate_data가 아이콘 없는 무기/전리품 id 보고. 테스트 205/205, 플레이테스트 승리 300s·보스 처치·서지 fps 60 |
| 7.7 | ~~**N4-7 개조 결과 무기 게이팅 + 레벨업 카드 중복 방지**~~ ✅ | 완료 — 개조 결과 무기는 레시피로만 획득(`evolution_only` 데이터 게이트, validate_data가 weapon_mods 결과 무기의 플래그 누락을 FAIL로 강제), 한 레벨업 화면에 같은 무기 id 카드 2장 금지(LevelUp.pick/assemble subject-id 중복 배제, 200시드 테스트), 보유 무기 스트립 HFlowContainer 랩 + Lv 배지 오버레이로 최대 보유 수에서도 540px 내(레이아웃 테스트). 플레이테스트: 개조 카드 1화면 제시/1회 선택, 신규 카드로 나온 개조 결과 0건, 승리 296.3s |
| 8 | ~~**N5-3 본거지(캠프) 최소판**~~ ✅ | 완료 — 타이틀→캠프→출정 루프 (첫 부팅은 FTUE대로 캠프 생략, 첫 결과 화면부터 캠프 착지), 보유 엽전+생애 통계 표시, GDD §24 건물 4곳 준비 중 플레이스홀더, 수행자 선택 캠프 동선, 순수 Camp 헬퍼 + 테스트 6종, tools/camp_check.tscn 스크린샷 |
| 9 | ~~**N7-1 명부수형 메타 트리**~~ ✅ | 완료 — data/meta_tree.json 8노드 DAG(단계별 비용, 선행 조건, 스탯 캡), 순수 MetaTree 헬퍼(구매=단일 프로필 fold, 손상 상태 새니타이즈, 캡 적용 집계), 프로필 schema v2(meta_tree, 신형 스키마 읽기 전용 페일세이프, 엽전 오버플로 클램프), 런 시작 1회 적용(무기 배율/이속/자석/HP), 명부수 화면(설화 `_02` 문법: 신목 트렁크+노드 그래프 스크롤, 상세 카드=다음 단계 표시, 나무 CTA, 최대 시 CTA 숨김), 캠프 명부수 스팟 라우팅, validate_data 사이클/미지 스탯/중복 id/도달 불가 거부, 테스트 245/245, 맥스 트리 플레이테스트: seed7 일반 봇 224s 패배·seed123 nopick 200s 패배(캡 유효) |
| 10 | ~~**N5-4 괴이록(도감)**~~ ✅ | 완료 — 발견 즉시 영구 기록(몬스터 처치/전리품 획득/무기 보유·개조 완성, 런 중 즉시 저장이라 패배·크래시에도 생존), 프로필 bestiary 블록(v2 유지, 무기록 프로필 빈 기록 마이그레이션), 캠프 괴이록 스팟 → 3탭 화면(몬스터/전리품/무기, 행 카드, 미발견 = ??? + 실루엣, 섹션·전체 카운트는 데이터 파생), 발견 몬스터 = 출몰 지역, 재료 = 티어 pill + 변환 레시피(미발견 쪽 ??? 마스킹), 무기 = 메커니즘 1줄 + 개조 분기, 캠프 새 기록 1줄 힌트(열람 시 해제), 미지 id 로드 시 경고 드랍, 테스트 259/259 |
| 10.5 | ~~**QA-1 전체 기능 감사**~~ ✅ | 완료 (2026-08-16) — 전 기능 pass, 수정 3건(물웅덩이 통행 가능화, 결과 화면 보스 HP바 잔류 제거, playtest 보스 리포트 오표기), 큐 후보 리포트 4건: 부분 로컬라이제이션(캠프/결과/HUD/카드 한국어 고정), 캠프에서 설정 접근 불가, .import 사이드카 정책 불일치(24 추적/85 미추적, CI.md와 모순), _end_run null 가드 비일관 |
| 10.7 | ~~**QA-2 신규 유저 경험 감사 + .import 정책**~~ ✅ | 완료 (2026-08-16) — .import 사이드카 untrack(폰트 1건만 화이트리스트, fresh-clone 검증), 소수정 3건(HUD 죽은 ⓘ 버튼 숨김, 카드 문구 px 단위 제거, 명부수 CTA 잔액 부족 시 비활성 스타일), 큐 후보: 첫 90초 무위협 구간, 사망 원인 미표시, HUD HP 부재, 승리 시 보스 생존 앤티클라이맥스, 캠프 아트 부재, 패시브 글자 아이콘, 레어리티 필 단색, 액티브 스킬 무설명, 괴이록 NEW 뱃지 부재 |
| 10.8 | ~~**N6-2 오프닝 위협 + 사망 가독성 + HUD HP**~~ ✅ | 완료 (2026-08-16) — QA-2 발견 1·2·3 해소. (1) 오프닝 프론트로드: 0s 고블린 14@0.7s + 12s 10@0.8s (기존 5@2.5s), stages.json `opening` 블록(20s 내 최소 18스폰·40s 내 첫 레벨업 XP 계획)을 RunFlow.opening_issues로 validate_data가 강제, 보장 드랍은 이동 방향 160px 앞 착지. 측정: 일반 봇 첫 레벨업 33.9s·0-20s 피해 0·승리, idle 봇 0-20s 피해 30·33.2s 사망. (2) 죽음 라인: Enemy name_ko → Player.last_hit_source → 결과 화면 "죽음" 행(정예/보스 이름 통과, 무귀속 중립 폴백), 저HP 경고 = 데이터 임계 25%·0.9s 루프 vignette. (3) HUD HP바: XP바 아래 5px 스트립(토큰 색, 저HP 시 주홍), 스프라이트 아래 바 유지(시선 위치 보완). 테스트 275/275 |
| 10.9 | ~~**N4-8 무기 성장 곡선 재조형**~~ ✅ | 완료 (2026-08-17) — 도사 무기 21종(기본 10 + 개조 결과 11) 성장 곡선 재설계: 1레벨 겸손(기본 피해 ~70-77%로 컷), 레벨당 체감(+25-40%/레벨), `milestones` 스키마(레벨별 메커니즘 추가 성장 — 투사체/연쇄/원호/구슬/장판/전염, LevelUp.stats_at_level 병합, 카드에 ★표기, validate_data가 경로 화이트리스트·mid+max 필수·max 병합 스탯 계약 강제). 멀티샷 훅(WeaponMath.fan_directions), AutoWeapon 레벨별 메커니즘 재계산, 스포너 live_cap 화면 밖 최원거리 재활용(제로 dps 회피 런이 wave 일정을 얼리던 구멍 폐쇄), enrage 250s/1.6배속+escort 연장. 헤드룸 x2.1-3.9 → x3.9-15.6, 무강화 런 3/3 사망(216-256s), 일반 런 승리(38-41 dps), L8 앵커 스프레드 2.1x(노이즈 플로어 내), maxed meta+nopick 8시드 1사망(가드 유지). 테스트 294/294, 스크린샷 captures/n4-8/ |
| 10.95 | ~~**N4-9 진화 획득화(희소성+지식)**~~ ✅ | 완료 (2026-08-17) — 특수 재료 잡몹 드랍 사실상 제거(도깨비불 0.005만), 정예가 공급원(합 0.12/마리, 화령석 0.08 중심), drop_tables `_config.special_chance_max` 캡을 validate_data가 강제(잡몹 0.005/정예 0.12), 전 레시피 `level_required: 3`(N4-8 첫 마일스톤 재사용, max_level 초과·마일스톤 이탈 FAIL, FTUE 첫 런만 면제), 명부수 천운 노드(특수 확률 +25%×2, 캡 0.5, 특수만 배율), 미수행 진화는 카드에서 ??? 마스킹 → 수행 시 괴이록 레시피 공개(기존 기록 재사용, 지식만·할인 없음). 측정(20런 시드): luck0 특수 0.55/런·8/20런, 천운max 0.90/런·13/20런(정확히 ×1.5), 메타max 진화 2/10런, FTUE 보장 1/1 유지. 스크린샷 captures/n4-9/ |
| 10.97 | ~~**N5-5 파괴 오브젝트 + 정예 보상 상자**~~ ✅ | 완료 (2026-08-17) — 파괴 가능 프롭 3종(소죽림 25/바위 45/쓰러진 나무 60 HP, 데이터 구동, 장식은 불가·validator 강제), 플레이어 무기만 피해(투사체/석장 원호/혼불 구슬/진언 파동 — 적은 불가, 의도), 파괴 시 풀링 퍼프 + 픽업 테이블 롤(꽝 50/엽전 38/회복 6/전멸부 3/자석 3, 꽝+엽전 ≥80% validator 강제), 픽업은 자석 경로 월드 엔티티. 회복 만피 시 10냥 전환(획득 시점 판정), 전멸부는 화면 내 잡몹 999·정예/보스 150 캡(데이터, 원샷 방지 validator·보스 2400→2250 생존 증명), 자석은 전 필드 흡인(빈 필드 무해). 정예 처치 = 풀링 상자 드랍, 밟아서 개봉 = 시간 정지 + 보상 1/3/5(기본 70/22/8, 천운 luck×shift 0/4/10 벤드 — 10k 측정: luck0 69.5/22.8/7.8%, luck0.5 38.5/35.4/26.1%), 보상은 레벨업 풀 기계 재사용(카드당 1탭, 5보상=5탭, 고갈 시 40냥), 런 종료 후 개봉은 폐기(일시정지 잔류 금지). 측정: 5런 파괴 평균 6.4/런, 상자 평균 3.0/런, 렌더 서지 fps min 59 avg 60(기준선 동일). 스크린샷 captures/n5-5/ |
| 10.98 | ~~**QA-3 신규 유저 경험 감사 2차**~~ ✅ | 완료 (2026-08-18) — 밸런스·콘텐츠 웨이브 이후 재감사 (프레시 세이브 실플레이 + 렌더 봇 런, 스크린샷 captures/qa-3/). 소수정 2건: 등급 필 단계별 색상(팔레트 토큰, 문자 우선 유지), 비활성 나무 버튼 텍스트 가독성(엽전 부족 CTA). **미검증 1건**: 오프닝 러시의 인간 반응속도 체감 난이도 — idle 봇 ~30s 사망(의도), 퍼펙트 봇 무피해 승리 사이 실제 신규 유저 체감을 데스크톱 사용 충돌로 실측 못 함, 오너 30초 자가 확인 요청. 구조적 리스크: 첫 레벨업 팝업(~0:23)이 러시 수렴 시점과 정확히 겹침 — 팝업 닫는 순간 포위 상태. 큐 후보: (1) 오프닝 팝업 직후 1.5-2s 접촉 유예 검토, (2) 회복 루프 부재(파괴물 회복 5.8%뿐, 봇 승리 런에 1회), (3) 파괴 오브젝트 시스템 비가시(부술 수 있다는 신호 전무, 꽝 50%), (4) 신장 소환수 = 파란 사각형(스프라이트 부재, 유일하게 미완성으로 보임), (5) 진화 인런 신호 부재(재료 0.55/런 + ??? 카드 무수치 블라인드 픽), (6) HP/XP 얇은 이중 스트립 혼동, (7) 보스 HP바 무명·최상단 얇음, (8) 상자 5보상 = 레벨업 화면 5연속(잭팟감 없음), (9) 카드 소수점 수치(12.65), (10) 첫 카드 골드 포커스 링이 추천으로 읽힘, (11) 캠프 준비 중 스팟 무반응 의심 + 무기 도감/괴이록 무기 탭 중복. QA-2 잔존 확인: 보스 생존 타임아웃 앤티클라이맥스(완화됨, N4-8 후 정상 빌드는 보스 처치), 캠프 텍스트 메뉴(유지), 패시브 글자 아이콘(유지), 액티브 무소개(유지, 오프닝 난이도로 더 아픔), ~~레어리티 필 단색~~(이번 수정), NEW 뱃지 부재(유지), 명부수 지출 넛지 부재(유지), 엽전/냥 표기 혼재(유지), 일시정지 설정 부재(유지), 부분 영문화(유지) |
| 10.99 | ~~**N6-3 팝업 유예 + 회복 루프**~~ ✅ | 완료 (2026-08-18) — QA-3 발견 1·2 해소. (1) 팝업 접촉 유예: 모든 선택 화면(레벨업/상자, 큐 경유 전부)이 닫혀 일시정지가 풀리는 순간 1.5s 접촉 무적(effects.json `popup_grace_sec`, 기존 무적 블링크로 텔레그래프). 큐 드레인당 1회, CombatMath.grace_extend가 maxf 갱신이라 중첩·이월 불가(순수 헬퍼 + 테스트 4종). 렌더 증거: 첫 팝업 ~25s 닫힘 직후 유예 활성 샷. 오프닝 2펄스는 유지 — 유예가 결정 순간과 위험 피크를 분리하고, 웨이브 재배치는 QA-3 확인된 0:10 긴장(validator 오프닝 계약)을 깨는 리스크라 기각, idle 프로브 0-30s 피해 102.0·33.2s 사망 전후 동일. (2) 회복 루프: 파괴물 회복 6→10%(꽝 50→46, plain 84%≥0.8 validator 유지) + 정예 처치 시 max HP 15% 회복(pickups.json `elite_heal`, (0,0.5] validator, 공유 힐 경로 — 2:00 정예가 바로 누적 피해가 치명이 되는 지점이라 정예 격파 = 회복 밸브, UI 0, 예산 상한 6마리, 보상이지 드립 아님). Pickups.heal_budget 순수 헬퍼로 예산 산정(테스트 3종). 측정: 일반 봇 힐 0→6회 113.4hp(예산 161.3), hp@2:00 96→96/150, hp@보스 96(회복 불가)→122.4/150(회복), 서지 fps min 60 avg 60(기준선 유지). 가드: 유예가 나쁜 빌드도 버프해 metamax nopick이 enrage 2.5에서 무패(12/12) → `soft_enrage.damage_mult_max` 2.5→2.8 보상, 최종 데이터에서 nopick 293.3s 패배·metamax nopick 260.5s 패배 관측(시드 고정에도 결과는 타이밍 노이즈, N4-8의 1/8 기준과 동일)·일반 봇 270.8s 보스킬 승리. 정예 힐 런타임 증명 50.4→69.3(+15%). 테스트 317/317, 스크린샷 captures/n6-3/ |
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
| 2026-08-17 | N4-8 weapon growth curves: 21 spiritual weapons reshaped (level-1 bases cut to ~70-77%, per-level steps +25-40%/level, `milestones` schema with additive mechanic deltas merged by LevelUp.stats_at_level — extra projectiles/chain jumps/arc width/orbit orbs/ward uptime/curse spread, ★ marker on milestone cards), multishot fan hook (WeaponMath.fan_directions + _targeting.multishot_spread_deg), AutoWeapon recomputes mechanic blocks per level, spawner recycles farthest offscreen enemy when live_cap blocks a due wave (zero-dps evasion runs froze the whole wave schedule), enrage 250s/1.6x + stretched escort, validate_data milestone contract, headroom x2.1-3.9 → x3.9-15.6, no-upgrade dies 3/3 (216-256s), normal wins (38-41 dps), L8 spread 2.1x, maxed-meta guard holds (1/8 nopick deaths, watch item renewed), tests 294/294 | — |
| 2026-08-15 | N4-7 mod-result weapon gating + level-up dedupe: validate_data fails any weapon_mods result missing `evolution_only`, LevelUp.pick/assemble guarantee one weapon id per screen (mod card's base+result seed the exclusion set), owned-weapon strip wraps via HFlowContainer with Lv badges overlaid on the wells (fits 540px at max owned count, layout test), playtest instrumented: 0 mod results offered as new weapons | — |
| 2026-08-15 | N5-3 base camp minimal: pure Camp helpers (post-title / select-exit routing off Ftue.is_first_run, profile summary view-model, GDD §24 building roster with 준비 중 resolution), camp scene on the dark meta grammar (GOLD title + coin/gold header, NIGHT_BROWN lifetime-stats card, 4 tappable building spots answering 준비 중, 수행자 선택 + one-tap 출정 wood buttons), title start routes returning profiles to camp (first boot still straight to stage), result CTA 본거지로 lands in camp, character-select back returns to camp for returning profiles, TEXT_MUTED_ON_DARK token, tools/camp_check.tscn screenshot harness, camp_backdrop registered in ASSET_REQUIREMENTS.md | — |
| 2026-08-15 | N7-1 명부수 meta tree: data/meta_tree.json 8-node DAG (per-rank cost ladders, prerequisites, per-stat caps), pure MetaTree helpers (purchase as one atomic profile fold, corrupt-state sanitize, capped aggregate, Kahn cycle/reachability validation), profile schema v2 with future-schema read-only fail-safe + MAX_GOLD overflow clamp, run-start single-point application into weapon/speed/magnet/hp scalars, 명부수 screen on the `_02` meta grammar (scrollable trunk graph, next-rank detail card, wood CTA hidden at max, empty-tap deselect), camp 명부수 spot routing, validate_data meta contract, playtest --meta=max + meta_flow_check persistence harness, maxed profile still loses (seed7 normal 224s / seed123 nopick 200s defeats) | — |
| 2026-08-15 | N5-4 괴이록 bestiary: pure Bestiary helpers (idempotent order-independent discovery fold persisted at sighting time so the record survives defeat and crash, unseen counter, unknown-id prune with warning, data-derived rosters — stage-spawn monsters + boss, loot.json, reachable-weapon closure over runtime_can_fire + mod chains — and ???-masked view-model rows), profile bestiary block on schema v2 with record-less migration fill, stage discovery hooks (kill/pickup/weapon-own incl. mod results), camp 괴이록 spot routes to a 3-tab row-card screen (per-section + overall counts derived from data, silhouetted ??? rows, tier/boss pills, mechanic one-liners, recipe ends masked per own discovery), one-line camp hint cleared on open, tools/bestiary_check.tscn 3-tab shots, tests 259/259 | — |
| 2026-08-16 | N7-2 meta economy rework + per-character branches: 22-node tree (13 shared trunk + 5 taoist 술법 + 2 warrior + 2 archer locked-visible with unlock text), taoist-relevant total 1,330 → 14,990냥 (~35-40 runs at the measured 83냥 loss / 299-512냥 win income, first rank affordable after one losing run), strictly-increasing per-rank cost curve + prereq-cost rule + per-character cap-waste guard enforced by MetaTree.data_issues, new wired node kinds (gold_gain/xp_gain multipliers, start_level with immediate power-up, choice_count 4-card screens, first_find guaranteed special material, damage_reduction, hit_invuln, once-per-run revive with float label), taoist branch folds into weapon data via MetaTree.modified_weapon_stats (burn duration/chain jumps/ward radius/orbit orbs/seal burst_at floor 2), per-character aggregate no-leak (unit-tested), pill-tab screen (trunk + branch per roster entry, selection follows tabs), stale-node prune on load without refund (deliberate, documented), survivability trimmed after a 6/6 unlosable nopick sweep (DR 5%/rank cap 14%, i-frames 10%/rank cap 20%, revive 30%) → maxed nopick 3W/1L (seed 5 defeat 279.5s), measured branch effect noebu chain 3→5 jumps / 22.2→32.4 dps, tests 285/285 | — |
| 2026-08-16 | N6-2 dangerous opening + legible death + HUD HP: front-loaded goblin rush (0s 14@0.7s + 12s 10@0.8s vs the old 5@2.5s) with a stages.json `opening` contract (≥18 spawns in 20s, level-2 XP scheduled by 40s, guarantee drop offset 160px ahead of travel) enforced by RunFlow.opening_issues in validate_data, killer attribution (Enemy.name_ko → Player.last_hit_source → 죽음 row on defeat, elite/boss names pass through, neutral fallback for unattributable), low-HP looping vignette + vermilion HUD fill at the data threshold (25%, 0.9s pulse), HUD HP bar under the XP bar (under-sprite bar kept), playtest --idle probe + first-level-up/0-20s-damage report (normal bot: 33.9s first level-up, 0 dmg, victory; idle bot: 30 dmg, dead 33.2s to 숲 도깨비), tests 275/275 | — |
| 2026-08-16 | QA-2 new-player experience audit + .import policy (D6): untracked all generated .import sidecars (font whitelist kept for its antialiasing=0 pixel params, fresh-clone import + 259/259 tests verified, CI cache key rehashed over asset sources, docs/CI.md updated), full first-session playthrough on a deleted save (title→first run→level-up→mod→death→camp→tree→bestiary→second run, screenshots), 3 small fixes (dead HUD info button hidden, px units stripped from card copy, meta-tree CTA disabled style when unaffordable), 9 queue candidates led by the threat-free first 90 seconds and unexplained deaths | — |
| 2026-08-16 | QA-1 pre-content full functional audit: every built feature exercised from a deleted save and a returning save (rendered autoplay runs, 10-weapon headless batch, real-save meta purchase/relaunch phases, corrupt-save boot, all screenshot harnesses), 3 fixes (water_puddle walkable decor, boss HP bar hidden on run end, playtest boss-report misprint), 4 queue-candidate reports (partial localization, no settings access from camp, .import sidecar policy split, _end_run null-guard inconsistency), tests 259/259 + validate_data PASS | — |
| 2026-08-15 | N6-1 FTUE first sixty seconds: pure Ftue helpers (first-boot taoist routing, one-shot move-hint / mod-explain profile flags, first-run guarantee table), profile `ftue` block with migration fill, MoveHint chevron overlay dismissed by first input, one extra 개조-card line "재료로 무기를 바꾼다" once per profile, stages.json `first_run_drops` (부적지 10s, 도깨비불 60s) validated end-to-end, playtest hint shot + first-run report, zero added taps | — |
| 2026-08-17 | N5-5 destructibles + pickups + elite chests: 3 breakable props (data hp, solid-only, validator), player-weapon-only damage via the spawner breakable registry (projectile flight / arc / orbit / shockwave hooks), pooled shatter puff + data break table (nothing/gold/health/nuke/magnet, plain-share ≥0.8 enforced), pickups as magnet-path world entities (full-HP health → gold at collection, nuke 999 trash / 150 elite-boss cap with one-shot validator guard, magnet attract_now full-field pull), elite is_elite flag → pooled walk-over chest, 1/3/5 rewards via luck-bent weights (validator: strict escalation + <50% five-count at luck cap), rewards drawn per-screen through the LevelUp pool machinery (1 tap per reward, fallback gold on dry pool, post-outcome discard), pickup_check screenshot harness, playtest break/chest metrics, tests 310/310 | — |
| 2026-08-18 | N6-3 post-popup grace + earned recovery (QA-3 findings 1·2): 1.5s contact grace on every choice-screen close through the popup queue (effects.json popup_grace_sec, existing invuln blink telegraph, once per queue drain, CombatMath.grace_extend/grace_tick maxf rule — never stacks or carries, 4 unit tests), opening pulses left untouched (idle-probe 0-30s damage 102.0 / death 33.2s identical before-after), break-table health 6→10% (plain 84% over the 0.8 validator floor), elite-kill heal 15% max HP (pickups.json elite_heal with (0,0.5] validator contract, shared heal path with float label + green pulse, runtime-proven 50.4→69.3), Pickups.heal_budget pure pricing helper (3 tests), playtest heals/hp-at-elite/hp-at-boss/grace-shot instrumentation + pickup_check elite-heal probe, measured normal bot heals 0→6 (113.4hp, budget 161.3), hp at boss 96 flat → 122.4/150 recovered, surge fps min 60 avg 60 (baseline held), guard compensation soft_enrage.damage_mult_max 2.5→2.8 (grace made metamax-nopick unlosable at 2.5 — 12/12 survivals; at 2.8 defeats observed: nopick 293.3s, metamax nopick 260.5s), tests 317/317, screenshots captures/n6-3/ | — |
| 2026-08-18 | QA-3 second new-player experience audit: fresh-save real-windowed session (title→runs→camp→명부수 purchase→괴이록→pause) + rendered bot run for surge/boss/chest/evolution visuals (victory 274s, 1 evolution via chest, 8 prop breaks, 6 chests), 2 small fixes (per-grade pill tints via UiPalette.GRADE_* with words kept primary + grade_id on card display, disabled wood-button text to TEXT_MUTED_ON_DARK for the 엽전 부족 CTA), opening-difficulty-at-human-pace flagged UNVERIFIED (desktop contention; idle bot dies ~30s by design, perfect bot untouched — owner 30s self-check requested), 11 queue candidates + QA-2 leftover verdicts recorded in the queue row, tests 311/311 | — |
| 2026-08-17 | N4-9 earned evolution: trash special drops cut to near zero (spirit 도깨비불 0.005 only), elites the special source (0.12/kill sum, 화령석-weighted), validator-enforced rarity caps (drop_tables._config), level_required 3 milestone gate on every recipe (FTUE first run waived), 천운 luck node (+25%×2 special-only multiplier, cap 0.5), unperformed evolutions masked ??? on the card until the 괴이록 records them. Measured: 0.55 specials/run (8/20 runs), luck max 0.90/run (exactly ×1.5), meta-max 2 evolutions/10 runs, FTUE 1/1 | — |
