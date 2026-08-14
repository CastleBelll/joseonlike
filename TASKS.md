# JOSEONLIKE — Tasks (Full Rebuild)

One feature per session, per [CLAUDE.md](CLAUDE.md). Phases: [ROADMAP.md](ROADMAP.md).
Tick a box only after commit **and** push succeeded.

2026-08-14: 오너 지시로 전면 리빌드. 구 백로그(R-시리즈)와 done log는
git 히스토리(`63b50c8` 이전)에만 남긴다. 구 코드/에셋 참조 금지.

---

## N0 — 리셋 & 부트 — CURRENT

- [ ] **N0-1 리포 리셋** — scenes/ scripts/ tests/ tools/ asset/ 및 구
      게임 파일 제거 (Neo둥근모 ttf + ASSET_LICENSES.md 항목은 유지·이동).
      data/, 문서, example/, new_asset/ 유지. project.godot 정리.
- [ ] **N0-2 최소 부트** — NIGHT 배경 + 픽셀 폰트 "조선라이크" 타이틀
      스텁이 에러 없이 뜬다. 헤드리스 테스트 러너 골격이 PASS를 출력한다.

## N1 — 타이틀

- [ ] N1-1 타이틀 레이아웃 (플레이스홀더 아트, DESIGN.md §4 배치)
- [ ] N1-2 codex AC-2 아트 통합 (배경 레이어 + 현판 로고)
- [ ] N1-3 설정 팝업 (음량/언어, 자동 저장)

## N2 — 수행자 선택

- [ ] N2-1 characters.json 재검증 + 카드 리스트 화면 (도사 1 + 잠금 카드)
- [ ] N2-2 선택 상태 저장/복원, 선택됨 배지
- [ ] N2-3 codex AC-1 초상 통합

## N3 — 전투 수직 슬라이스 (세션 단위로 분해)

- [ ] N3-1 스테이지 씬 + 카메라 + 가상 조이스틱 이동
- [ ] N3-2 도사 인월드 스프라이트 (AC-1, 2방향 + 4프레임 걷기)
- [ ] N3-3 자동 공격 무기 1종 (부적 투척)
- [ ] N3-4 몬스터 스폰/추적/접촉 피해/사망
- [ ] N3-5 XP 드랍 → 자석 픽업 → 레벨업
- [ ] N3-6 파워 업 팝업 (행 카드 문법, 실수치 설명)
- [ ] N3-7 전투 HUD (타이머/XP바/카운터, DESIGN.md §3)
- [ ] N3-8 데미지 숫자 + 피격 피드백

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
