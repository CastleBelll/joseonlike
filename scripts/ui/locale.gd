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
	"settings.title": {"ko": "설정", "en": "Settings"},
	"settings.tab_game": {"ko": "게임", "en": "Game"},
	"settings.tab_audio": {"ko": "오디오", "en": "Audio"},
	"settings.master_volume": {"ko": "전체 음량", "en": "Master Volume"},
	"settings.music_volume": {"ko": "음악", "en": "Music"},
	"settings.effects_volume": {"ko": "효과음", "en": "Effects"},
	"settings.joystick_opacity": {"ko": "조이스틱 불투명도", "en": "Joystick Opacity"},
	"settings.language": {"ko": "언어", "en": "Language"},
	"settings.close": {"ko": "닫기", "en": "Close"},
	"meta.title": {"ko": "명부수", "en": "Myeongbusu"},
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
