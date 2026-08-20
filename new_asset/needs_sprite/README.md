# 스프라이트 프레임이 필요한 것들

이 폴더의 PNG는 **배경을 날린 원본**이다. 프레임을 만들어 각자의 목표 경로에
넣으면 게임이 바로 읽는다.

## 시트 규약

가로로 셀을 이어 붙인 스트립. 셀 크기는 아래 표의 값 그대로다 —
4프레임이면 `18x10`이 `72x10`이 된다.

**투사체**(`asset/weapon/travel/…`)는 프레임 수를 `data/weapons.json`에
적어야 한다. 그 무기 항목에 한 줄 넣으면 된다:

```json
"travel_frames": 4
```

키를 빼면 1프레임(정지)으로 읽는다. 숫자가 폭을 나누지 못하면
`validate_data`가 실패한다. 투사체 그림은 정사각이 아니라서 파일 모양만으로는
프레임 수를 알 수 없기 때문에 적는 것이다.

**이펙트**(`asset/effect/…`, `asset/weapon/fx/…`)는 프레임이 정사각이라
`너비 ÷ 높이`로 스스로 선언한다. 데이터에 적을 것이 없다.

투사체는 12fps로 돌고 비행이 1초 미만이라 4프레임이면 충분하다.
그보다 많으면 플레이어가 못 본다.

## 목록

| 파일 | 목표 경로 | 셀 크기 | 권장 프레임 | 무엇 |
|---|---|---|---|---|
| `fx_hit_phoenix.png` | `asset/effect/hit_phoenix.png` | 48x48 | 5 | 봉황 타격 표시. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `fx_swing_arc.png` | `asset/effect/swing_arc.png` | 20x20 | 2 | 근접 휘두름 궤적. 초승달이 아니라 베기 자국 — 양끝이 바늘처럼 가늘다 |
| `travel_hwabu.png` | `asset/weapon/travel/hwabu.png` | 18x18 | 4 | 화부 불덩이. 불꽃이 흔들려야 불로 읽힌다 |
| `travel_hwaryeongbu.png` | `asset/weapon/travel/hwaryeongbu.png` | 16x18 | 4 | 화령부 불덩이. 화부보다 세게 |
| `travel_sal.png` | `asset/weapon/travel/sal.png` | 18x18 | 4 | 살 저주 연기. 일렁여야 한다 |
| `travel_gwisal.png` | `asset/weapon/travel/gwisal.png` | 16x18 | 4 | 귀살 저주 연기. 도깨비 얼굴이 일그러진다 |
| `travel_old_talisman.png` | `asset/weapon/travel/old_talisman.png` | 18x10 | 4 | 낡은 부적. 종이가 팔랑이는 것이 이 무기의 정체다 |
| `travel_fire_talisman.png` | `asset/weapon/travel/fire_talisman.png` | 18x10 | 4 | 화염 부적. 불길이 따라 흔들린다 |
| `travel_beopgeom.png` | `asset/weapon/travel/beopgeom.png` | 20x7 | 4 | 법검 검기. 번쩍이면 좋지만 위의 것들보다 급하지 않다 |
| `travel_bongmageom.png` | `asset/weapon/travel/bongmageom.png` | 20x7 | 4 | 봉마검 검기. 보랏빛이 흐른다 |
