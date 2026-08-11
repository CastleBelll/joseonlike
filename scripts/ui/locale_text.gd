class_name LocaleText
extends RefCounted
## Locale-aware text picker. Game content (character/weapon/monster/... names
## and level-up choice descriptions) always comes from data/*.json name_ko /
## name_en fields via field(); UI chrome (button labels, headers, empty-state
## copy) has no data/*.json source, so it lives in UI_STRINGS below instead of
## being scattered as literals across controller scripts.

## Small, non-content UI chrome strings only. Anything that names a character,
## weapon, monster, stage, passive, or achievement must come from data/*.json.
const UI_STRINGS: Dictionary = {
	"start_button": {"ko": "시작", "en": "Start"},
	"menu_start": {"ko": "시작", "en": "Start"},
	"menu_continue": {"ko": "이어하기", "en": "Continue"},
	"menu_settings": {"ko": "설정", "en": "Settings"},
	"pause_title": {"ko": "일시정지", "en": "Paused"},
	"settings_title": {"ko": "설정", "en": "Settings"},
	"settings_master_volume": {"ko": "전체 음량", "en": "Master Volume"},
	"settings_music_volume": {"ko": "음악 음량", "en": "Music Volume"},
	"settings_effects_volume": {"ko": "효과음 음량", "en": "Effects Volume"},
	"settings_language": {"ko": "언어: 한국어", "en": "Language: English"},
	"achievements_quests_title": {"ko": "업적 및 퀘스트", "en": "Achievements & Quests"},
	"achievements_section_title": {"ko": "업적", "en": "Achievements"},
	"quests_section_title": {"ko": "퀘스트", "en": "Quests"},
	"quests_coming_soon": {"ko": "퀘스트 준비 중입니다.", "en": "Quests coming soon."},
	"pause_resume": {"ko": "계속하기", "en": "Resume"},
	"pause_quit_to_title": {"ko": "타이틀로 나가기", "en": "Quit to Title"},
	"menu_credits": {"ko": "제작진", "en": "Credits"},
	"menu_quit": {"ko": "종료", "en": "Quit"},
	"credits_body": {"ko": "JOSEONLIKE\n조선 민속 로그라이크\n\n제작: JOSEONLIKE 팀", "en": "JOSEONLIKE\nA Joseon-folklore roguelike\n\nMade by the JOSEONLIKE team"},

	"area_select_title": {"ko": "지역 선택", "en": "Select Area"},
	"area_locked_reason": {"ko": "준비 중인 지역입니다.", "en": "This area is not open yet."},

	"camp_title": {"ko": "본거지", "en": "Base Camp"},
	"camp_walk_hint": {"ko": "가까이 다가가 확인 버튼을 눌러 들어가세요", "en": "Walk close and press interact to enter"},
	"building_workshop": {"ko": "공방", "en": "Workshop"},
	"building_archive": {"ko": "서고", "en": "Archive"},
	"building_training_ground": {"ko": "훈련장", "en": "Training Ground"},
	"building_shrine": {"ko": "사당", "en": "Shrine"},
	"start_run": {"ko": "출정", "en": "Start Run"},
	"close": {"ko": "닫기", "en": "Close"},
	"building_placeholder_body": {"ko": "준비 중입니다.", "en": "Coming soon."},

	"character_select_title": {"ko": "사냥꾼 선택", "en": "Select Hunter"},
	"locked_label": {"ko": "잠김", "en": "Locked"},
	"select_button": {"ko": "선택", "en": "Select"},
	"back_button": {"ko": "뒤로", "en": "Back"},
	"loading_label": {"ko": "불러오는 중...", "en": "Loading..."},
	"empty_characters": {"ko": "불러올 캐릭터가 없습니다.", "en": "No characters available."},
	"error_characters": {"ko": "캐릭터 데이터를 불러오지 못했습니다.", "en": "Failed to load character data."},
	"unlock_gold_template": {"ko": "%d 골드로 잠금 해제", "en": "Unlock for %d gold"},
	"unlock_achievement_template": {"ko": "달성 필요: %s", "en": "Requires: %s"},
	"unlock_unknown": {"ko": "알 수 없는 조건", "en": "Unknown condition"},

	"hp_label": {"ko": "체력", "en": "HP"},
	"level_label": {"ko": "레벨", "en": "Lv"},
	"time_label": {"ko": "시간", "en": "Time"},
	"kills_label": {"ko": "처치", "en": "Kills"},
	"weapons_empty": {"ko": "무기 없음", "en": "No weapons"},

	"level_up_title_template": {"ko": "레벨 %d - 강화 선택", "en": "Level %d - Choose Upgrade"},
	"kind_weapon_new": {"ko": "신규 무기", "en": "New Weapon"},
	"kind_weapon_upgrade": {"ko": "무기 강화", "en": "Weapon Upgrade"},
	"kind_passive": {"ko": "패시브", "en": "Passive"},
	"no_choices": {"ko": "선택지가 없습니다.", "en": "No choices available."},

	"victory_title": {"ko": "승리!", "en": "Victory!"},
	"defeat_title": {"ko": "패배", "en": "Defeat"},
	"gold_label": {"ko": "획득 골드", "en": "Gold Earned"},
	"new_achievements_label": {"ko": "신규 업적", "en": "New Achievements"},
	"no_new_achievements": {"ko": "신규 업적 없음", "en": "No new achievements"},
	"return_to_camp": {"ko": "본거지로 귀환", "en": "Return to Camp"},
	"no_result_data": {"ko": "결과 데이터가 없습니다.", "en": "No result data available."},
}


static func is_korean() -> bool:
	return TranslationServer.get_locale().begins_with("ko")


## Picks `<field_base>_ko` / `<field_base>_en` off a data/*.json dictionary,
## preferring the current locale and falling back to whichever side exists.
static func field(data: Dictionary, field_base: String = "name") -> String:
	var ko_value: String = String(data.get("%s_ko" % field_base, ""))
	var en_value: String = String(data.get("%s_en" % field_base, ""))
	var preferred: String = ko_value if is_korean() else en_value
	var fallback: String = en_value if is_korean() else ko_value
	if not preferred.is_empty():
		return preferred
	if not fallback.is_empty():
		return fallback
	return "???"


## Picks between two locale-specific textures (e.g. asset/title/joseonlike_ko.png
## vs joseonlike_en.png) the same way field()/ui() pick text, so no screen
## hardcodes which language's art to show.
static func texture(korean: Texture2D, english: Texture2D) -> Texture2D:
	return korean if is_korean() else english


## Picks a UI chrome string (not game content) by key from UI_STRINGS.
static func ui(key: String) -> String:
	var entry: Variant = UI_STRINGS.get(key, {})
	if not (entry is Dictionary) or entry.is_empty():
		push_warning("LocaleText.ui: unknown key '%s'" % key)
		return key
	var preferred_key: String = "ko" if is_korean() else "en"
	var fallback_key: String = "en" if is_korean() else "ko"
	return String(entry.get(preferred_key, entry.get(fallback_key, key)))
