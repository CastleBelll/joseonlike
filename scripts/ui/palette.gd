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
const PILL_TEXT := Color("#ffffff")

# In-game world tokens (DESIGN.md §5 dark forest look).
const FOREST_GROUND := Color("#232b1e")
const FOREST_SHADOW := Color("#1a2117")
const ACCENT_TAOIST := Color("#4a7fd6")
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

# Spacing scale (4/8pt grid).
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 32

# Type scale (DESIGN.md §1).
const FONT_SIZE_TITLE := 28
const FONT_SIZE_BODY := 20
const FONT_SIZE_LABEL := 16

const TOUCH_TARGET_MIN := 44
