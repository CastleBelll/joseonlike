# new_asset — 작업용 원본 보관소

여기 있는 것은 **게임이 직접 읽지 않는다**. `.gdignore`가 있어 Godot이 임포트조차
하지 않는다. 게임이 쓰는 것은 전부 `asset/` 아래 있고, 이 폴더의 재료가 빌드
스크립트를 거쳐 그리로 간다.

정리 원칙 하나: **아무것도 지우지 않는다.** 쓰지 않게 된 것은 `archive/`로 옮긴다.

## 폴더

| 폴더 | 무엇 | 읽는 스크립트 |
|---|---|---|
| `generated/` | 생성 모델로 뽑은 원본. 파일명이 곧 설치 대상 id다 | `asset/build_from_generated.py`, `asset/monsters/build_night2_sheets.py` |
| `owner/` | 오너가 직접 그렸거나 받아온 것. `taoist.png`가 캐릭터 밀도 앵커다 | `asset/monsters/build_owner_sheets.py`, `asset/weapon/build_travel.py`, `asset/ui/build_assets.py` 외 |
| `sheets/` | 스프라이트 시트 요청·수령분 | `asset/build_sprite_requests.py` |
| `needs_sprite/` | 아직 시트가 없는 것들의 참고 그림 | `asset/build_sprite_requests.py` |
| `source/` | 게임 밖 원본. 지금은 오너가 만든 BGM 원본(`bgm/`) | 없음 — 보관 전용 |
| `archive/` | 이제 쓰지 않는 것. 지우지 않고 여기 둔다 | 없음 |

## archive에 있는 것

- `Effect Asset`, `Effects`, `Environment`, `Retro Impact Effect Pack 5`,
  `Pixel Holy Spell Effect 32x32 Pack 3` — 받아뒀지만 한 번도 쓰이지 않은 무료 팩
- `walk_needed` — 걷기 시트 요청 목록이었던 것
- `generated_superseded/` — 지난 세대 렌더. 같은 대상이 다시 생성되어 설치
  스크립트가 더 이상 이름을 부르지 않는 것들 (밤1 괴이 4종, 축지·벽사진 아이콘,
  법검·봉마검 옛 투사체 등)

## 새 그림을 받을 때

`generated/<파일명>.png`에 넣는다. 파일명이 데이터 id가 된다 (`icon_sal.png` →
`asset/ui/weapon_icons/sal.png`). 프롬프트 규격과 배경 색 규칙은
[ASSET_REQUIREMENTS.md](../ASSET_REQUIREMENTS.md)의 "생성 프롬프트 틀"에 있다.
