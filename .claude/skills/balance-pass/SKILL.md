---
name: balance-pass
description: >-
  Use for any change to how JOSEONLIKE FEELS to play rather than what it does —
  밸런스, 수치 조정, 난이도, 페이싱, 체감, 너무 쉽다/어렵다, dps, 스폰량, 드롭률,
  보상, 경제(엽전·메타 트리 비용), 무기 강약, 플레이테스트, QA, 회귀 확인. Also
  use when the owner reports a feel problem in words rather than numbers ("밤2가
  너무 쉽다", "무사가 약하다", "출정이 지루하다"). Measurement first, extremes
  first, and the result written into data/BALANCE.md. Not for new mechanics —
  that is the new-monster skill.
---

# 밸런스 / QA 패스

이 프로젝트에서 밸런스는 의견이 아니라 **측정**이다. `data/BALANCE.md`가 1,100줄
넘게 쌓인 이유가 그것이고, 근거 없이 바꾼 숫자는 다음 세션이 되돌린다.

## 0. 무엇이 문제인지 숫자로 바꾼다

오너의 말은 대개 체감이다("밤2가 너무 쉽다"). 먼저 그 말을 **측정 가능한 문장**으로
번역한다: 승률인가, 클리어 시각인가, 피격 횟수인가, 레벨 곡선인가, 특정 무기의
dps인가. 번역이 안 되면 아직 고칠 준비가 안 된 것이다.

## 1. 현재 값을 먼저 잰다 (바꾸기 전에)

```sh
godot --headless --path . res://tools/playtest.tscn -- --stage=<id> --speed=4 --seed=7 --runs=2
```

- **`--runs=2` 이상.** 첫 런은 튜토리얼 길이(`first_run_duration_scale` 0.15)라
  63초에 끝난다. 그걸 결과로 읽으면 안 된다.
- **시드를 고정한다.** 시드가 다르면 비교가 아니다. 기준선은 `--seed=7`.
- 무기 하나를 볼 때는 `--weapon=<id>`(강제 단일 빌드), 전 무기 표는 `--batch`.
- 읽을 값: `outcome`(승/패와 시각), `level`, `kills`, `surge fps`,
  `heals ... budget`, `specials dropped`, 그리고 배치 표의 dps.

## 2. 극단값으로 범위를 먼저 찾는다

미세 조정을 열 번 하지 말고, **의도적으로 과한 값과 모자란 값**을 한 번씩 넣어
"어디서 무너지고 어디서 시시해지는가"를 잡는다. 두 극단 사이가 진짜 튜닝 구간이다.
반복 횟수를 크게 줄인다 — 지금까지 우리가 안 하던 방식이다.

## 3. 고칠 곳은 데이터다

수치는 `data/`에 있다. 코드에 박힌 밸런스 숫자를 발견하면 그 자체가 버그다
(ARCHITECTURE.md §6). 주로 만지는 파일:

| 무엇 | 파일 |
|---|---|
| 웨이브 수·간격, 보스 시각, 소프트 인레이지 | `stages.json` |
| 몬스터 hp·피해·속도·xp | `monsters.json` |
| 무기 피해·쿨다운·투사체 수 | `weapons.json` |
| 패시브 배율, xp 곡선 | `passives.json`, `progression.json` |
| 드롭률·특수 재료 상한 | `drop_tables.json`, `pickups.json` |
| 메타 트리 비용 곡선 | `meta_tree.json` |
| 난이도 배율·런 길이 | `difficulties.json` |

**강제 가능한 규칙은 `tools/validate_data.gd`에 넣는다.** 예: 비용 곡선이 랭크마다
오르는지, 특수 재료 드롭률이 상한을 넘지 않는지. 문서에만 적힌 규칙은 드리프트한다.

## 4. 같은 조건으로 다시 잰다

바꾼 뒤 **같은 시드·같은 런 수**로 재측정한다. 전후 값을 나란히 적지 못하면 그
변경은 근거가 없는 것이다.

## 5. QA — 무엇을 언제 돌리는가

| 하네스 | 언제 |
|---|---|
| `tests/run_tests.gd` | 항상 |
| `tools/validate_data.gd` | 데이터를 건드렸으면 항상 |
| `playtest.tscn --runs=2` | 밸런스·페이싱·경제를 건드렸으면 |
| `playtest.tscn --batch` | 무기 간 강약을 건드렸으면 |
| `layout_sweep.tscn` | UI 크기·배치를 건드렸으면 (12화면 × 11기기 × 2언어) |
| `locale_check.tscn` | 화면에 새 문구를 넣었으면 |
| `thief_check` · `multipart_check` · `shadow_check` | 해당 괴이의 규칙에 닿았으면 |
| `pickup_check` · `meta_flow_check` | 드롭·메타 구매 흐름을 건드렸으면 |

하네스 출력에서 **`SCRIPT ERROR`를 먼저** 본다. 파스 에러가 나면 산출물은 옛
파일이 남고, 바뀐 게 없다고 헛돌게 된다.

## 6. 기록한다 — 이게 절반이다

`data/BALANCE.md`에 남긴다. 형식은 이미 그 문서가 정해두고 있다:

- 무엇을 왜 바꿨는가 (체감 문제 → 번역한 지표)
- **전후 측정값**, 시드와 런 수를 포함해서
- 함께 움직인 것 (한쪽을 올려서 다른 쪽을 낮췄다면 그 대가)
- 재보고도 안 고친 것과 그 이유

숫자만 바꾸고 근거를 안 적으면 다음 세션이 "왜 이 값이지?" 하고 되돌린다. 실제로
그렇게 되돌아간 적이 있다.

## 7. 커밋

`TASKS.md`에 한 줄(측정값 포함), Conventional Commits, 영어. 커밋 메시지에는
**무엇이 잘못 느껴졌는지와 무엇으로 확인했는지**를 쓴다.

## 하지 않는 것

- 측정 없이 "약간 올려봤다" — 이 프로젝트에서 가장 자주 되돌려진 변경이다.
- 여러 축을 한 번에 — 무엇이 효과였는지 알 수 없게 된다.
- 새 메커닉 추가 — 그건 `new-monster` 스킬이다. 밸런스 패스는 **있는 것의 숫자**만
  만진다.
