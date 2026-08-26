---
name: new-monster
description: >-
  Use when adding a monster, a monster behaviour, or any run-affecting combat
  rule to JOSEONLIKE — 새 괴이, 새 행동(behaviour), 부위·상태·재료 게이팅 같은
  전투 규칙. Encodes the sequence this repo settled into over 야광귀 (thief),
  삼두구미 (multipart), 화약 도깨비 (suicide) and 그슨대 (shadow): folklore
  first, contract in the validator, decision in a pure function, and a harness
  for what a test cannot see. Not for UI, art, or balance-only changes.
---

# 새 괴이 / 새 행동 추가

세 번 반복하며 굳은 순서다. 지키면 검증까지 한 세션에 끝나고, 건너뛰면 그 자리에서
되돌아온다. 각 단계의 "왜"는 실제로 그렇게 당했기 때문에 적혀 있다.

## 0. 전승을 먼저 읽는다

`docs/JOSEON_RESEARCH.md`에서 대상 항목의 **규칙 칸**을 읽는다. 이 프로젝트의 괴이는
설화가 곧 판정이다 — "베어도 소용없다"는 무적 페이즈가 되고, "체를 걸면 구멍을
센다"는 정지 반경이 된다. 전승에 없는 기믹을 지어내지 않는다.

## 1. 인수 조건을 먼저 쓴다 (코드 전에)

CLAUDE.md §2. 각 항목은 테스트나 하네스로 확인 가능해야 한다. 마지막 항목은 항상
**회귀**다: 기존 behaviour(chase·boss·suicide·ranged·charger·swarm·thief·multipart)
불변, 기존 보스 불변.

## 2. 데이터에 선언한다

`data/monsters.json`에 항목을 넣는다. 행동이 새로우면 `behaviour` 값과 그 행동이
요구하는 블록을 함께 넣고, `_<이름>_note`에 **왜 이 수치인지**를 한국어로 적는다.

- 스프라이트가 없으면 `sprite` 키를 **넣지 않는다** — PlaceholderArt가 그린다
  (CLAUDE.md §5). 대신 `ASSET_REQUIREMENTS.md`에 `[MISSING]` 블록을 추가하고,
  `scripts/ui/palette.gd`에 전용 플레이스홀더 색을 준다. 색을 안 주면 미등록 id는
  전부 도깨비 초록으로 떨어져 잡몹과 구분이 안 된다.
- 스폰은 `data/stages.json` 웨이브에 넣는다. `at_sec`는 **오름차순**이어야 하고
  (검증기가 막는다), 빈도는 그 괴이가 요구하는 플레이 빈도에 맞춘다.

## 3. 검증기에 계약을 넣는다 (`tools/validate_data.gd`)

**코드에만 있는 규칙은 반드시 드리프트한다.** 새 행동은 `BEHAVIOURS`에 추가하고 그
행동이 요구하는 것을 강제한다:

- 필수 수치가 전부 있고 양수인가
- 다른 행동이 그 블록을 들고 있지 않은가 (`suicide`가 아닌데 `suicide` 블록 등)
- 그 행동만의 불변식 — 도둑은 접촉 피해가 정확히 0, 부위는 부서질 hp와 대가를
  치르는 `on_break`, 재료 게이트는 실재하는 loot이고 어디선가 드롭될 것
- 필수 양수 검사에서 면제할 필드가 있으면 그 자리에서 면제한다(도둑의 `damage`)

## 4. 판단을 순수 함수로 옮긴다 (`scripts/combat/combat_math.gd`)

노드 없는 static 함수로 쓴다. 헤드리스 스위트가 규칙을 직접 검사할 수 있는 이유가
이것이다. 경계값을 의도적으로 정하고(`<=`인지 `<`인지), **빈 입력이 무엇을 뜻하는지**
반드시 결정한다 — `parts_cleared([])`가 false였다면 부위를 선언하지 않은 기존 적
전부가 무적이 됐다.

## 5. Enemy에 배선한다 (`scripts/combat/enemy.gd`)

- 상태 필드를 추가하고 **`setup()`에서 반드시 초기화한다.** 적은 풀링되므로
  `_ready()`에서 초기화하면 재사용된 적이 이전 상태를 물고 나온다.
- 피해와 관련된 것은 전부 `take_damage()` 한 입구에서 분기한다. 무기 27종은 새
  행동을 몰라야 한다.
- 스테이지가 알아야 하는 사건은 시그널로 낸다. 적은 스테이지 참조를 갖지 않는다 →
  `spawner.gd`가 중계하고 `stage.gd`가 소비한다.
- 스테이지에서 참조를 넘길 때는 **그 대상이 이미 존재하는 시점인지 확인한다.**
  `_run_state`는 스포너 시그널 배선보다 늦게 만들어진다 — 나란히 뒀다가 null에
  접근했다.
- 플로트 라벨을 띄웠다면 **`scripts/ui/locale.gd`에 영문 행을 추가한다.**
  `locale_check`가 잡는다. 포맷 지정자 개수가 양쪽에서 같아야 한다.

## 6. 테스트 (`tests/unit/test_<이름>.gd`)

순수 함수의 경계값 + 데이터 계약을 검사한다. 파일을 만들면 자동 탐색된다. 씬을
만들지 않는다. 타입 있는 배열을 직접 만들어 넘기므로, **런타임에서만 나는 타입
오류는 잡지 못한다** — 그건 하네스의 몫이다.

## 7. 하네스 (`tools/<이름>_check.tscn` + `.gd`)

**밖에서 안 보이는 규칙은 버그와 구분이 안 된다.** 피해를 무시하는 몸통은 깨진
히트박스처럼 보인다. 실제 스테이지를 띄워 케이스를 직접 몰고, 각 단계를 출력하고,
마지막에 `PASS`/`FAIL`을 찍고 그 코드로 종료한다.

- 스포너의 `_spawn_one(id)`으로 원하는 괴이를 즉시 세운다.
- 프로브가 **자기가 심은 대상**을 지목하게 하라. 스테이지는 프로브가 도는 동안에도
  픽업을 계속 깔고 적을 스폰한다 — "필드가 비었다"는 아무것도 증명하지 않는다.
- 설계한 결말과 일반 경로(화면 밖 컬링 등)를 구분할 수 있게 하라. 야광귀 프로브는
  한동안 컬링을 "탈출 PASS"로 찍고 있었다. 스테이지에 계수기를 두고 그 값을 봤다.
- `_process`에서 `await`를 쓰면 재진입 가드(`_busy`)를 둔다.

## 8. 검증 (전부 초록이어야 커밋)

```sh
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd        # PASS n/n
godot --headless --path . --script tools/validate_data.gd    # PASS
godot --headless --path . res://tools/locale_check.tscn      # 라벨을 추가했다면
godot --headless --path . res://tools/<이름>_check.tscn       # 새 하네스
godot --headless --path . res://tools/playtest.tscn -- --stage=<id> --speed=4 --seed=7 --runs=2
```

playtest는 **`--runs=2`로 돌린다.** 첫 런은 튜토리얼 길이(`first_run_duration_scale`
0.15)라 63초에 끝나고, 그걸 회귀로 착각해 스태시까지 하며 헤맨 적이 있다.

하네스 출력에서 `SCRIPT ERROR`를 **먼저** 본다. 파스 에러가 나면 스크린샷·산출물은
옛 파일이 남고, "바뀐 게 없다"며 세 번 헛돌게 된다.

## 9. 문서와 커밋

- `TASKS.md` 맨 위 표에 한 줄: 무엇을·왜·측정값·검증 결과.
- 아트가 없으면 `ASSET_REQUIREMENTS.md`에 크기·그리드·실루엣 조건까지.
- Conventional Commits, 영어. 무엇을 고쳤는지가 아니라 **무엇이 잘못돼 있었는지**를
  쓴다.

## 지금까지 이 순서로 들어간 것

| 괴이 | behaviour | 규칙 | 하네스 |
|---|---|---|---|
| 화약 도깨비 | `suicide` | 팔 거리에서 도화선을 켜고 멈춰 터진다, 접촉 피해 없음 | — |
| 야광귀 | `thief` | 필드 패시브를 훔쳐 달아난다, 체 반경에서 정지 | `thief_check` |
| 삼두구미 | `multipart` | 부위 셋, 재료로만 열리고, 본체는 그전까지 무적 | `multipart_check` |
| 그슨대 | `chase` + `shadow` | 어둠에서 흡수·성장, 빛 안에서만 피격 | `shadow_check` |

남은 후보는 `docs/JOSEON_RESEARCH.md`와 `TASKS.md`의 C1 항목에 있다 (영노, 손님).
