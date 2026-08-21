class_name UiLocale
extends RefCounted
## Minimal ko/en string table. Only holds strings the built screens use;
## grows with each screen instead of porting the old full key file.

const DEFAULT_LOCALE := "ko"

const STRINGS := {
	"title.game_name": {"ko": "조선라이크", "en": "JOSEONLIKE"},
	"title.start": {"ko": "게임 시작", "en": "Start Game"},
	"title.select_character": {"ko": "수행자 선택", "en": "Select Cultivator"},
	"title.settings": {"ko": "설정", "en": "Settings"},
	"select.selected": {"ko": "선택됨", "en": "Selected"},
	"select.locked": {"ko": "잠김", "en": "Locked"},
	"select.back": {"ko": "나가기", "en": "Back"},
	"select.how_to_unlock": {"ko": "해금 방법", "en": "How to unlock"},
	"settings.title": {"ko": "설정", "en": "Settings"},
	"settings.tab_game": {"ko": "게임", "en": "Game"},
	"settings.tab_audio": {"ko": "오디오", "en": "Audio"},
	"settings.master_volume": {"ko": "전체 음량", "en": "Master Volume"},
	"settings.music_volume": {"ko": "음악", "en": "Music"},
	"settings.effects_volume": {"ko": "효과음", "en": "Effects"},
	"settings.joystick_opacity": {"ko": "조이스틱 불투명도", "en": "Joystick Opacity"},
	"settings.language": {"ko": "언어", "en": "Language"},
	"settings.close": {"ko": "닫기", "en": "Close"},
	"meta.title": {"ko": "수련", "en": "Training"},
	"meta.locked": {"ko": "잠김", "en": "Locked"},
	"meta.max": {"ko": "최대", "en": "MAX"},
	"meta.available": {"ko": "구매 가능", "en": "Available"},
	"meta.cost_fmt": {"ko": "%d냥", "en": "%d coins"},
	"meta.buy_fmt": {"ko": "강화 — %d냥", "en": "Upgrade — %d"},
	"meta.short_fmt": {"ko": "엽전 부족 — %d냥", "en": "Need %d coins"},
	"meta.hint": {"ko": "노드를 선택하세요", "en": "Select a node"},
	"meta.requires_fmt": {"ko": "%s 필요", "en": "Requires %s"},
	"meta.bought": {"ko": "강화 완료", "en": "Upgraded"},
	"meta.no_gold": {"ko": "엽전이 부족합니다", "en": "Not enough coins"},
	"meta.maxed_fmt": {"ko": "최대 강화 완료 · %s", "en": "Fully upgraded · %s"},
	"meta.next_fmt": {"ko": "%s (%d/%d 단계)", "en": "%s (rank %d/%d)"},
	"meta.permanent": {"ko": "영구 적용 · 다음 출정부터", "en": "Permanent · from the next run"},
	"meta.tab_shared": {"ko": "공용", "en": "Shared"},
	"meta.branch_only_fmt": {"ko": "%s 전용 · 선택한 수행자에게만 적용", "en": "%s only · applies to that cultivator"},
	"meta.char_locked": {"ko": "수행자 해금 후 구매 가능", "en": "Unlock the cultivator to purchase"},
	"bestiary.title": {"ko": "괴이록", "en": "Records of Anomalies"},
	"achievements.title": {"ko": "업적", "en": "Achievements"},
	"achievements.earned": {"ko": "달성", "en": "Earned"},
	"achievements.unlocked": {"ko": "해금", "en": "unlocked"},
	"bestiary.tab_monsters": {"ko": "몬스터", "en": "Monsters"},
	"bestiary.tab_loot": {"ko": "전리품", "en": "Loot"},
	"bestiary.tab_weapons": {"ko": "무기", "en": "Weapons"},
	"bestiary.appears_fmt": {"ko": "출몰: %s", "en": "Appears in: %s"},
	"bestiary.boss": {"ko": "보스", "en": "Boss"},
	"bestiary.branch_fmt": {"ko": "개조: %s", "en": "Mod: %s"},
	"bestiary.camp_hint_fmt": {"ko": "괴이록에 새 기록 %d건", "en": "%d new records in the archive"},
}

static var current_locale: String = DEFAULT_LOCALE


static func text(key: String) -> String:
	if not STRINGS.has(key):
		push_error("UiLocale: unknown key " + key)
		return key
	var entry: Dictionary = STRINGS[key]
	return entry.get(current_locale, entry[DEFAULT_LOCALE])

## N9-87 retrofit translation for text that shipped as Korean literals inside
## the code. STRINGS above is key-based and right for anything written with it
## from the start; these 94 were already in the source, and inventing a key for
## each would have touched every call site twice for no gain. So the Korean IS
## the key.
##
## Format specifiers survive translation in the same order and count — callers
## still write `UiLocale.t("투사체 +%s") % value` — and a script checks that,
## because `%` fills positionally and a swapped pair silently prints the wrong
## numbers rather than failing.
const INLINE_EN := {
	"파워 업!": "Power Up!",
	"보물 상자! (%d/%d)": "Treasure Chest! (%d/%d)",
	"회생부 발동!": "Revival Charm!",
	"두두리를 물리쳤다": "Dudueori has fallen",
	"%s %s 등급!": "%s is now %s",
	"%s 획득": "%s acquired",
	"회복 +%d": "Healed +%d",
	"자석!": "Magnet!",
	"+%d냥": "+%d coins",
	"%s — 빛 안에서만 벨 수 있다": "%s — only cuts within the light",
	"%s · 개조 준비 완료!": "%s · ready to remake",
	"%s · %s Lv.%d에서 개조": "%s · remake at %s Lv.%d",
	"알 수 없는 존재": "Unknown",
	"일시 정지": "Paused",
	"계속하기": "Resume",
	"설정": "Settings",
	"타이틀로": "Quit to Title",
	"닫기": "Close",
	"무기": "Weapons",
	"패시브": "Passives",
	"능력치": "Stats",
	"개조 경로": "Remake Path",
	"%s %d  (칸 %d + 주움 %d)": "%s %d  (slots %d + found %d)",
	"  (가득 참)": "  (full)",
	"  Lv.%d 필요": "  needs Lv.%d",
	" 필요": " needed",
	"체력": "Health",
	"이동 속도": "Move Speed",
	"공격력": "Attack",
	"공격 속도": "Attack Speed",
	"치명타 확률": "Crit Chance",
	"치명타 피해": "Crit Damage",
	"투사체": "Projectiles",
	"투사체 속도": "Projectile Speed",
	"피해 감소": "Damage Reduction",
	"자석 범위": "Magnet Range",
	"경험치 획득": "XP Gain",
	"행운": "Luck",
	"일반": "Common",
	"고급": "Fine",
	"희귀": "Rare",
	"영웅": "Heroic",
	"신화": "Mythic",
	"등급↑": "Grade Up",
	"등급 상승": "Grade Up",
	"신규!": "New!",
	"변신!": "Evolved!",
	"개조": "Remake",
	"%s — 피해 %s · 쿨다운 %s초": "%s — %s damage · %ss cooldown",
	"피해 %s→%s · 쿨다운 %s초→%s초": "Damage %s→%s · Cooldown %ss→%ss",
	"%s · 등급 %s→%s · %s": "%s · grade %s→%s · %s",
	"%s → %s (레벨 유지)": "%s → %s (keeps its level)",
	"%s → %s · 피해 %s→%s (레벨 유지)": "%s → %s · damage %s→%s (keeps its level)",
	"투사체 +%s": "Projectiles +%s",
	"관통 +%s": "Pierce +%s",
	"관통 피해 유지 +%s": "Pierce damage kept +%s",
	"연쇄 +%s회": "Chain +%s jumps",
	"도약 피해 유지 +%s": "Jump damage kept +%s",
	"연쇄 범위 +%s": "Chain range +%s",
	"폭발 반경 +%s": "Blast radius +%s",
	"가장자리 피해 +%s": "Edge damage +%s",
	"원호 +%s°": "Arc +%s°",
	"넉백 +%s배": "Knockback x%s",
	"선회 속도 +%s": "Orbit speed +%s",
	"선회 반경 +%s": "Orbit radius +%s",
	"구슬 크기 +%s": "Orb size +%s",
	"장판 반경 +%s": "Ward radius +%s",
	"장판 지속 +%s초": "Ward lasts +%ss",
	"감속 강화": "Stronger slow",
	"소환 지속 +%s초": "Summon lasts +%ss",
	"소환수 공격 가속": "Summon strikes faster",
	"소환수 이동 +%s": "Summon speed +%s",
	"파동 반경 +%s": "Shockwave radius +%s",
	"기절 +%s초": "Stun +%ss",
	"전염 +%s마리": "Spreads to +%s more",
	"지속 피해 +%s": "Damage over time +%s",
	"전파 반경 +%s": "Spread radius +%s",
	"상태 지속 +%s초": "Status lasts +%ss",
	"봉인 폭발 조건 완화": "Seal bursts sooner",
	"폭발 반경 %s": "Blast radius %s",
	"연쇄 %d회 · 도약당 피해 %d%%": "Chains %d times · %d%% damage per jump",
	"%s° 원호 · 넉백 %s배": "%s° arc · knockback x%s",
	"선회 구슬 %d개 · 반경 %s": "%d orbiting orbs · radius %s",
	"직선 전원 관통": "Pierces everything in line",
	"관통 %d": "Pierces %d",
	"장판 반경 %s · %s초 지속 · 이동 %d%%": "Ward radius %s · lasts %ss · move %d%%",
	"소환수 %s초 · %s초마다 공격": "Summon lasts %ss · strikes every %ss",
	"파동 반경 %s · 기절 %s초 · 넉백 %s배": "Shockwave radius %s · stun %ss · knockback x%s",
	"화상 초당 %s (%s초)": "Burns %s per second (%ss)",
	" · 사망 시 전파": " · spreads on death",
	"감전 이동 %d%% (%s초)": "Shocked: move %d%% (%ss)",
	"저주 초당 %s (%s초) · 사망 시 %d마리 전염": "Curse %s per second (%ss) · spreads to %d on death",
	"봉인 %d중첩 시 %s배 폭발": "At %d seal stacks, bursts for x%s",
	"피해의 %d%% 흡혈": "Heals %d%% of damage dealt",
	"본거지": "Camp",
	"출정 횟수": "Runs",
	"최고 생존": "Best Time",
	"최고 처치": "Best Kills",
	"보스 처치": "Bosses Slain",
	"난이도 ‹%s›": "Difficulty ‹%s›",
	"길이 ‹%s›": "Length ‹%s›",
	"아직 다른 선택지가 없다": "Nothing else to choose yet",
	"수행자 선택": "Choose Cultivator",
	"출정": "Set Out",
	"수련": "Training",
	"괴이록": "Bestiary",
	"업적": "Achievements",
	"무기 도감": "Weapon Codex",
	"훈련장": "Training Ground",
	"지역 선택": "Choose Region",
	"준비 중": "Not ready",
	"승리": "Victory",
	"패배": "Defeat",
	"죽음": "Killed by",
	"생존 시간": "Survived",
	"처치": "Kills",
	"엽전": "Coins",
	"보유 엽전": "Coins Held",
	"본거지로": "To Camp",
	"%d냥": "%d coins",
	"가자": "Let's go",
	"다음": "Next",
	"끌어서 이동": "Drag to move",
	"첫 개조! 재료로 무기를 바꾼다": "First remake! Trade materials for a new weapon",
	"첫 파워 업! 하나를 골라 강해지자": "First power up! Pick one and grow",
	"우치": "Uchi",
	"정령왕의 저주가 짙군... 숲 전체가 영원한 밤에 잠겼어.\n놈을 봉인하려면 우선 살아남아야 한다.": "The Spirit King's curse runs deep... the whole forest has sunk into endless night.\nTo seal him, first you survive.",
	"먼저 움직여보자.\n화면 아무 곳이나 끌어서, 저만치 걸어가 봐.": "Move first.\nDrag anywhere on the screen and walk over there.",
	"걸음은 됐다. 이제 숨을 고르고 들어라.\n곧 괴이가 몰려온다.": "Walking will do. Catch your breath and listen.\nThe creatures are coming.",
	"부적은 알아서 날아간다 — 겨눌 것 없이 자리만 잡아.\n오는 놈을 하나 베어봐라.": "The talismans fly on their own — no aiming, just position.\nCut down one that comes.",
	"오른쪽 아래 빛나는 단추가 내 비장의 술법이다.\n축지는 위기 탈출, 벽사진은 사방 일소 — 하나 눌러봐.": "Those glowing buttons are my hidden arts.\nChukji escapes danger, Byeoksajin sweeps every side — press one.",
	"괴이를 잡아 기가 차면 새 술법을 고를 수 있다.\n이제 네 밤이다. 가자.": "Slay creatures, fill your energy, and you may choose a new art.\nThe night is yours now. Go.",
}


## Korean text in, the current locale's text out. An untranslated string falls
## back to the Korean it was given, which is exactly what shipped before this,
## so a gap in the table degrades instead of blanking the UI.
static func t(korean: String) -> String:
	if current_locale == DEFAULT_LOCALE:
		return korean
	return String(INLINE_EN.get(korean, korean))

## A data entry's own name in the current locale. Every catalogue in data/
## already carries name_ko and name_en side by side; several screens still
## reached straight for name_ko, so a translated label printed an untranslated
## value next to it — "Difficulty ‹순행›". Falls back to the Korean, which is
## what those call sites did before.
static func data_name(entry: Dictionary, fallback: String = "-") -> String:
	var localized: Variant = entry.get("name_" + current_locale)
	if localized is String and not (localized as String).is_empty():
		return localized
	return String(entry.get("name_" + DEFAULT_LOCALE, fallback))


## desc_ko/desc_en twin of data_name (N9-105) — same fallback ladder.
static func data_desc(entry: Dictionary, fallback: String = "") -> String:
	var localized: Variant = entry.get("desc_" + current_locale)
	if localized is String and not (localized as String).is_empty():
		return localized
	return String(entry.get("desc_" + DEFAULT_LOCALE, fallback))
