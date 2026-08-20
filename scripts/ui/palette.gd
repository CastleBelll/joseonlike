class_name UiPalette
extends RefCounted
## Design tokens from DESIGN.md §1-2. The only place raw color values live.

const NIGHT := Color("#16110d")
const NIGHT_BROWN := Color("#241a12")
const PAPER := Color("#ede0c4")
const PAPER_CARD := Color("#f6ecf0")
const WOOD := Color("#e2a057")
const WOOD_HOVER := Color("#edb26c")
const WOOD_PRESSED := Color("#c08544")
const WOOD_BORDER := Color("#6e4322")
const WOOD_TEXT := Color("#4a2e14")
const INK := Color("#1a1613")
const GOLD := Color("#ffd94a")
const GOLD_BORDER := Color("#c49a3d")
const VERMILION := Color("#bf402a")
const SUCCESS := Color("#58d858")
const TEXT_ON_DARK := Color("#f0e6d2")

# Paper-panel popup tokens (DESIGN.md §3 종이 패널 / 선택 카드, capture _07).
const PAPER_INSET := Color("#f7f0e2")
const PAPER_CARD_BORDER := Color("#c9a0a6")
const LATTICE := Color("#a89880")
const TEXT_MUTED_ON_PAPER := Color("#6b6258")
# N5-3 camp stats: muted row names on the dark card (AA vs NIGHT_BROWN).
const TEXT_MUTED_ON_DARK := Color("#b0a494")
const PILL_TEXT := Color("#ffffff")

# In-game world tokens (DESIGN.md §5 dark forest look).
## Matches the dominant value of asset/stages/bamboo_forest/ground_tile.png.
## Only drawn when the tile art is missing, so a drift between the two shows up
## as the floor changing hue the moment an asset fails to load.
const FOREST_GROUND := Color("#1b2320")
const FOREST_SHADOW := Color("#1a2117")
const ACCENT_TAOIST := Color("#4a7fd6")
# N2-1 character accents (DESIGN.md §4 수행자 선택, GDD 부록 A palettes):
# warrior crimson (진홍), archer deep green (진녹).
const ACCENT_WARRIOR := Color("#e2604e")
const ACCENT_ARCHER := Color("#8bc45e")

# N2-1 select-card tokens (DESIGN.md §3 선택 카드, capture _01): dark row
# cards on the near-black screen, dim low-saturation border when unselected,
# darker square portrait well on the left.
const CARD_BG := Color("#211c26")
const CARD_BG_SELECTED := Color("#28230f")
const CARD_BORDER_DIM := Color("#453d54")
const CARD_WELL := Color("#2b2531")
# Monster silhouette separation per DESIGN.md §5.1 (goblin=green, spirit=white).
const ENEMY_GOBLIN := Color("#6faa4e")
const ENEMY_SPIRIT := Color("#d8dfd2")
const ENEMY_BRUTE := Color("#a4763b")
# XP orb glow per DESIGN.md §5.1 (cyan-green) and white damage numbers.
const XP_ORB := Color("#49e0b5")
const XP_ORB_CORE := Color("#d8fff2")
const DAMAGE_TEXT := Color("#ffffff")

# N3-8 hit feedback / N5-1 boss: flash white, spirit-white death puff, and a
# violet boss silhouette separated from every mob green/white/brown.
const HIT_FLASH := Color("#ffffff")
## Overbright modulate for sprite hit flash (N3-12): fills clamp toward white
## while the near-black outlines stay dark, so the silhouette survives the hit.
const SPRITE_HIT_FLASH := Color(8.0, 8.0, 8.0)
const DEATH_PUFF := ENEMY_SPIRIT
const ENEMY_BOSS := Color("#8a56c9")

# N3-9 bamboo forest prop placeholders (night-desaturated, above FOREST_GROUND).
const PROP_BAMBOO := Color("#3d6b33")
const PROP_ROCK := Color("#5c5f58")
const PROP_LOG := Color("#5a3d24")
const PROP_WATER := Color("#28424e")
const DECOR_GRASS := Color("#2e4026")
const DECOR_FERN := Color("#375030")
const DECOR_PEBBLE := Color("#464a40")
const PROP_LANTERN := Color("#50737f")
const PROP_SHRINE := Color("#415250")
const DECOR_FOG := Color("#293c47")

# N4-1 loot drop tier tints (in-field diamonds; the popup carries the words).
const LOOT_COMMON := Color("#cfc8b8")
const LOOT_UNCOMMON := Color("#7fc25e")
const LOOT_RARE := Color("#5aa2e0")
const LOOT_EPIC := Color("#a86fd6")
const LOOT_MYTHIC := GOLD
const LOOT_CORE := Color("#ffffff")

# QA-3 grade pill tints (words stay the primary signal, DESIGN.md §2):
# dark enough for the white PILL_TEXT, hue-separated per ladder rung.
const GRADE_COMMON := VERMILION
const GRADE_UNCOMMON := Color("#3e7a2e")
const GRADE_RARE := Color("#35619e")
const GRADE_EPIC := Color("#6a4399")
const GRADE_MYTHIC := Color("#8a6a12")

## N9-27: grade id → colour, shared by the level-up pill and the pause build
## summary. It lived only in level_up_popup until the pause screen needed to
## show grade too; two copies of a colour table drift the moment one is tuned.
## N9-34 치명타: hot gold-white, distinct from the boss GOLD and from the
## plain DAMAGE_TEXT so a crit is legible in a crowd of ordinary numbers.
const CRIT_TEXT := Color("#ffe08a")

const GRADE_COLORS: Dictionary = {
	"common": GRADE_COMMON,
	"uncommon": GRADE_UNCOMMON,
	"rare": GRADE_RARE,
	"epic": GRADE_EPIC,
	"mythic": GRADE_MYTHIC,
}


static func grade_color(grade_id: String) -> Color:
	return GRADE_COLORS.get(grade_id, GRADE_COMMON)

# N4-1 modded-weapon projectile tints so a transformation reads on the field.
const WEAPON_FIRE := Color("#ff8a3c")
const WEAPON_LIGHTNING := Color("#8ad2ff")
const WEAPON_SEAL := GOLD
# N4-4a taoist archetype placeholders: pale soul-flame orbs (혼불) and the
# violet ghost-iron staff arc, separated from lightning blue and boss violet.
const WEAPON_SOUL := Color("#cfd6ff")
const WEAPON_GHOST := Color("#b07ee0")
## N4-4b 살 curse: sickly magenta-violet, separated from ghost-iron violet
## and the boss silhouette so a cursed field reads at a glance.
const WEAPON_CURSE := Color("#d967c9")

# N6-5 floating joystick: neutral overlay-control tones — ink-based base,
# desaturated light ring/knob. Deliberately NOT the wood family so the stick
# reads as a transient touch overlay, never as a wooden button.
const JOYSTICK_BASE := Color("#1d2024")
const JOYSTICK_RING := Color("#8d949c")
const JOYSTICK_KNOB := Color("#d4d8dc")

# Spacing scale (4/8pt grid).
const SPACE_XS := 4
## N10-1a 그슨대: a bruised violet while untouchable — dark and wrong, but
## still clearly readable against the night ground (a near-black silhouette
## measured as invisible in the field), lifting to a pale grey once a light
## reaches it. LIGHT_HALO is the warm pool a lantern or campfire casts, so the
## player can see which props are lights and how far each one reaches.
const SHADOW_DARK := Color(0.27, 0.24, 0.40, 1.0)
const SHADOW_LIT := Color(0.72, 0.70, 0.82, 1.0)

const LIGHT_HALO := Color(1.0, 0.82, 0.48, 1.0)

const SPACE_SM := 8
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 32

# Type scale (DESIGN.md §1).
const FONT_SIZE_TITLE := 28
const FONT_SIZE_BODY := 20
const FONT_SIZE_LABEL := 16

const TOUCH_TARGET_MIN := 44
