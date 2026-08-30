# QA 브리프 — HD UI 크롬 시각 게이트

오너의 HD UI 리메이크 42장이 build/ 조각으로 들어갔다 (8d679ac). 오너의 기존
규칙: **HD 리메이크가 실표시 크기에선 구판보다 못할 수 있다 — 실표시 크기로
게이트한다.** 네 임무는 각 조각을 실제 화면에서 보고 구판 대비 판정하는 것.

## 준비

1. `git fetch origin && git merge origin/main`  (8d679ac 이상)
2. CRLF 재정규화: 인덱스를 비웠다가 하드 리셋 (`git rm -q --cached -r .` 후
   `git reset --hard`) — 이후 `.gd`가 전부 LF인지 확인
3. `godot --headless --path . --import`
4. 구판 비교: merge 전 HEAD 해시를 기록해 두고,
   `git show <구해시>:asset/ui/chrome/build/<piece>.png > old_<piece>.png`
   식으로 꺼내 비교.

## 판정 대상 (모두 960x540 + 540x960)

| 화면 | 조각 |
|---|---|
| 타이틀 | title_plaque(두루마리액자), wood 버튼, 설정 기어 |
| 본거지 | plate/plaque 현판 버튼 6종, 뒤로가기, 엽전 pill |
| 설정/일시정지 | paper_panel(새 종이!), 탭, 토글·체크박스(구판 유지 — 이질감?) |
| 레벨업 | scroll 족자(세로)+횡권(가로) — 새 두루마리는 롤러가 얇다. 이음새·미러 캡 판정 |
| 전투 HUD | 코너 버튼(일시정지·기어), 소지품 슬롯(slot_*), 디스크 뱃지 |
| 결과 | paper_panel, 버튼 |
| 괴이록/업적 | slot/disc/아이콘 버튼류 |

## 판정 기준

- 실표시 크기에서 구판보다 선명한가/탁한가 (축소 후 뭉개짐, 테두리 두께 위화감)
- 9-slice 늘어난 자리 어색함 (특히 paper_panel 모서리, scroll 롤러)
- 색이 기존 등급 변조(slot 틴트)·팔레트와 충돌하는가
- 새 조각과 구판 잔존 조각(토글·체크박스·plaque·바·배너)의 이질감

## 산출물 (worker_done)

- 조각별 **KEEP**(HD 유지) / **REVERT**(구판 복귀) / **FIX**(무엇을 어떻게) 판정표
- 심각 문제는 캡처 파일명 명시 (`captures/qa-chrome-gate/`)
- 게임 코드 수정 금지, 보고만. main 푸시 금지.
