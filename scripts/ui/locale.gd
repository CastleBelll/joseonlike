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
	"settings.title": {"ko": "설정", "en": "Settings"},
	"settings.master_volume": {"ko": "전체 음량", "en": "Master Volume"},
	"settings.music_volume": {"ko": "음악", "en": "Music"},
	"settings.effects_volume": {"ko": "효과음", "en": "Effects"},
	"settings.language": {"ko": "언어", "en": "Language"},
	"settings.close": {"ko": "닫기", "en": "Close"},
}

static var current_locale: String = DEFAULT_LOCALE


static func text(key: String) -> String:
	if not STRINGS.has(key):
		push_error("UiLocale: unknown key " + key)
		return key
	var entry: Dictionary = STRINGS[key]
	return entry.get(current_locale, entry[DEFAULT_LOCALE])
