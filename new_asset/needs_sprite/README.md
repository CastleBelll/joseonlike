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

**이펙트**(`asset/effect/…`)는 프레임이 정사각이라 `너비 ÷ 높이`로 스스로
선언한다. 프레임 수는 데이터에 적지 않는다.

다만 `impact_*`는 **새로운 이펙트 id**라 등록이 한 번 필요하다.
`data/effects.json`의 `sprite_effects`에 한 항목, 그리고 그 무기의
`hit_effect`를 새 id로 바꾼다:

```json
"impact_beopgeom": {
  "file": "res://asset/effect/impact_beopgeom.png",
  "fps": 32.0,
  "logical_px": 32.0
}
```

`logical_px`는 아래 표의 셀 크기와 같은 숫자다. 기존 `hit_*` 다섯 종은
그대로 두면 되고, 무기가 하나씩 새 id로 옮겨갈 때마다 쓰이지 않게 된다.

투사체는 12fps로 돌고 비행이 1초 미만이라 4프레임이면 충분하다.
그보다 많으면 플레이어가 못 본다.

## 목록

| 파일 | 목표 경로 | 셀 크기 | 권장 프레임 | 무엇 |
|---|---|---|---|---|
| `fx_swing_arc.png` | `asset/effect/swing_arc.png` | 20x20 | 2 | 근접 휘두름 궤적. 초승달이 아니라 베기 자국 — 양끝이 바늘처럼 가늘다 |
| `travel_hwabu.png` | `asset/weapon/travel/hwabu.png` | 18x18 | 4 | 화부 불덩이. 불꽃이 흔들려야 불로 읽힌다 |
| `travel_hwaryeongbu.png` | `asset/weapon/travel/hwaryeongbu.png` | 16x18 | 4 | 화령부 불덩이. 화부보다 세게 |
| `travel_old_talisman.png` | `asset/weapon/travel/old_talisman.png` | 18x10 | 4 | 낡은 부적. 종이가 팔랑이는 것이 이 무기의 정체다 |
| `travel_fire_talisman.png` | `asset/weapon/travel/fire_talisman.png` | 18x10 | 4 | 화염 부적. 불길이 따라 흔들린다 |
| `impact_old_talisman.png` | `asset/effect/impact_old_talisman.png` | 32x32 | 5 | 낡은 부적 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_gyeolgye.png` | `asset/effect/impact_gyeolgye.png` | 44x44 | 5 | 결계 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_divine_bow.png` | `asset/effect/impact_divine_bow.png` | 32x32 | 5 | 신궁 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_fire_talisman.png` | `asset/effect/impact_fire_talisman.png` | 32x32 | 5 | 화염 부적 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_hwabu.png` | `asset/effect/impact_hwabu.png` | 32x32 | 5 | 화부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_hwaryeongbu.png` | `asset/effect/impact_hwaryeongbu.png` | 32x32 | 5 | 화령부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_honbul.png` | `asset/effect/impact_honbul.png` | 32x32 | 5 | 혼불 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_flame_honbul.png` | `asset/effect/impact_flame_honbul.png` | 32x32 | 5 | 화령 혼불 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_hwayeom_gyeolgye.png` | `asset/effect/impact_hwayeom_gyeolgye.png` | 44x44 | 5 | 화염 결계 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_flame_sword.png` | `asset/effect/impact_flame_sword.png` | 32x32 | 5 | 화염검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_noebu.png` | `asset/effect/impact_noebu.png` | 32x32 | 5 | 뇌부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_noejeongbu.png` | `asset/effect/impact_noejeongbu.png` | 32x32 | 5 | 뇌정부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_noe_sinjang.png` | `asset/effect/impact_noe_sinjang.png` | 32x32 | 5 | 뇌신장 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_jineon.png` | `asset/effect/impact_jineon.png` | 44x44 | 5 | 진언 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_bongin_jineon.png` | `asset/effect/impact_bongin_jineon.png` | 44x44 | 5 | 봉인 진언 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_sal.png` | `asset/effect/impact_sal.png` | 32x32 | 5 | 살 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_gwisal.png` | `asset/effect/impact_gwisal.png` | 32x32 | 5 | 귀살 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_ghost_staff.png` | `asset/effect/impact_ghost_staff.png` | 32x32 | 5 | 귀철 석장 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_ghost_sword.png` | `asset/effect/impact_ghost_sword.png` | 32x32 | 5 | 귀철검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_beopgeom.png` | `asset/effect/impact_beopgeom.png` | 32x32 | 5 | 법검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_bongmageom.png` | `asset/effect/impact_bongmageom.png` | 32x32 | 5 | 봉마검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_seokjang.png` | `asset/effect/impact_seokjang.png` | 32x32 | 5 | 석장 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_sinjang.png` | `asset/effect/impact_sinjang.png` | 32x32 | 5 | 신장 소환 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_sword.png` | `asset/effect/impact_sword.png` | 32x32 | 5 | 환도 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_twin_sword.png` | `asset/effect/impact_twin_sword.png` | 32x32 | 5 | 쌍환도 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_sharp_sword.png` | `asset/effect/impact_sharp_sword.png` | 32x32 | 5 | 예리한 환도 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
| `impact_bow.png` | `asset/effect/impact_bow.png` | 32x32 | 5 | 각궁 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다 |
