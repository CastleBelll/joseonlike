# QA 브리프 — 모바일 확대(축소 base) 검수 (4b398cc)

오너 지시 "모바일에서 전체적으로 너무 작아"로 좁은 폰에서 base가 CSS 쪽으로
축소되게 바꿨다(세로 0.9 하한, 가로는 축소 없음). 실화면 판정 필요.

## 준비

merge origin/main (4b398cc 이상) → CRLF 재정규화 → import.

## 재현 방법

폰 캔버스는 `root.content_scale_size = Vector2i(486, 864)` + `root.size` 동일
(3x 아이폰이 실제 받는 base). 비교 기준은 기존 540x960.

## 검수 목록 (486x864 + 486x972 캡처, EN·KO 양쪽)

| # | 항목 | 통과 기준 |
|---|---|---|
| M1 | 첫 가이드(FTUE guide) | 486 base에서 글자·종이가 화면 안, 이전보다 크게 읽힘 |
| M2 | 본거지 | 컬럼·현판·출정 버튼 전부 화면 안. EN에서 난이도·길이 버튼 ellipsis가 흉하지 않은가(‹값›이 잘리는가) |
| M3 | 건물 현판 EN | "Region Select" 등 ellipsis 상태 — 의미 전달 되는가 |
| M4 | 설정 팝업 EN | 행 라벨 ellipsis — "Joystick Opa…"가 허용 수준인가, 슬라이더·버튼 종이 안 |
| M5 | 레벨업 팝업 | 카드 3장 무스크롤, 상단 인셋 축소가 어색하지 않은가 |
| M6 | 수행자 선택 | 카드·설명·버튼 화면 안 |
| M7 | 540x960 회귀 | 기존 캔버스에서 달라진 것 없음 (ellipsis는 발동 안 해야 정상) |

## 산출물 (worker_done)

- M1~M7 PASS/FAIL + 캡처 (captures/qa-mobile-scale/). FAIL엔 측정값.
- ellipsis가 흉한 항목은 FIX 제안(줄바꿈? 폰트 축소?) 한 줄.
- 게임 코드 수정 금지, main 푸시 금지.
