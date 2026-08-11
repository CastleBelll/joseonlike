# JOSEONLIKE mobile UI art audit and handoff

## Audit before generation

The repository already contained the following coherent visual language, so none of it was regenerated:

- `asset/title/joseonlike_en.png`, `asset/title/joseonlike_ko.png`, and
  `asset/title/title_frame_blank.png`.
- `asset/ui/chrome/panel_9slice.png` and `button_{normal,hover,pressed}_9slice.png`.
- Eight passive icons in `asset/ui/passive/`, eight achievement icons in
  `asset/ui/achievement/`, `asset/ui/currency/{gold,xp}.png`, and
  `asset/ui/state/{lock,check}.png`.
- The established palette from `scripts/ui/palette.gd`: ink `#1A1613`, paper
  `#EDE0C4`, dark paper `#D6C5A1`, vermilion `#BF402A`, dark vermilion
  `#8B2C1C`, gold `#C49A3D`, locked grey `#6B6459`, success `#4A7C42`, danger
  `#A32A2A`, and light text `#F5EEDE`.

The scene/code audit found `scenes/ui/title.tscn`, `character_select.tscn`,
`character_card.tscn`, `hud.tscn`, `level_up_choice.tscn`, `results.tscn`, and
`scenes/basecamp/camp.tscn`. Title had only the start route; character select used
the flat gameplay sprites and immediately started Bamboo Forest; camp's four
buildings opened one placeholder panel; HUD used flat StyleBoxes; level-up used
ordinary buttons; results was text-led. There was no save/profile scene, area
select, pause/settings screen, achievements/quests screen, or ad-offer UI, while
`scripts/services/ads.gd` was deliberately only a no-op M1 service stub.

Before this batch the journey therefore read as follows:

| Step | Before | Measured gap |
|---|---|---|
| Title / main | Partially dressed | Surrounding menu/settings/quit/version treatment |
| Save / profile | Nothing | First-launch and returning-player states |
| Character select | Partially dressed | Portraits, role marks, state frames, preview furniture |
| Area select | Nothing | Stage cards, locked state, difficulty/reward marks |
| Base camp | Partially dressed | Building-specific interior art and panel identity |
| In-run HUD | Partially dressed | Authored bars, boss bar, timer/pause and feedback furniture |
| Level-up | Partially dressed | Tier silhouettes and a dedicated choice-card back |
| Pause / settings | Nothing | Audio, language, slider, toggle, back/quit treatment |
| Results | Partially dressed | Victory/defeat banners, reward and unlock emphasis |
| Achievements / quests | Icons only | Rows, progress and claimed/unclaimed furniture |
| Monetisation | Nothing | Rewarded-ad, continue offer and currency furniture |

## Delivered screen inventory and consumers

All generator sheets are retained in `asset/ui/raw/journey/`; their selected cells
were sliced and passed through `tools/asset/pixelize.py`. The exact generated-cell
inventory and measurements are in `asset/ui/raw/journey/ui_metrics.json`.

The nine recuttable source sheets are exactly:

- `asset/ui/raw/journey/title_profile_icons_sheet_higgsfield.png`
- `asset/ui/raw/journey/character_portraits_sheet_higgsfield.png`
- `asset/ui/raw/journey/area_cards_sheet_higgsfield.png`
- `asset/ui/raw/journey/area_indicators_sheet_higgsfield.png`
- `asset/ui/raw/journey/camp_interiors_sheet_higgsfield.png`
- `asset/ui/raw/journey/camp_icons_sheet_higgsfield.png`
- `asset/ui/raw/journey/hud_settings_icons_sheet_higgsfield.png`
- `asset/ui/raw/journey/results_meta_ad_icons_sheet_higgsfield.png`
- `asset/ui/raw/journey/result_banners_sheet_higgsfield.png`

### 1. Title / main screen

Delivered `asset/ui/main/{start,continue,settings,credits,quit}.png` (32x32) and
`asset/ui/main/version_plaque_9slice.png` (96x32). `scenes/ui/title.tscn` and
`scripts/ui/title.gd` should consume these beside the existing title frame and use
the existing button states; place Start/Continue in the lower thumb zone, Settings
and Credits as secondary actions, Quit last, and version text on the plaque.

### 2. Save / profile or continue

Delivered `asset/ui/profile/{new_profile,returning_profile,delete_profile}.png`
(32x32) plus `slot_9slice.png` and `slot_selected_9slice.png` (96x64). A new
`scenes/ui/profile_select.tscn` and `scripts/ui/profile_select.gd` should consume
the set before camp on first launch, while returning players may expose Continue
on the title screen. The selected slot adds a physical top seal/tab and doubled
corners, not just a colour swap.

### 3. Character select

Delivered `asset/ui/character/portraits/{taoist,warrior,archer}.png` (128x128),
`asset/ui/character/classes/{taoist,warrior,archer}.png` (32x32),
`card_{unselected,selected}_9slice.png` (96x96), and
`preview_panel_9slice.png` (96x64). `scenes/ui/character_card.tscn` should use the
portrait and class mark; `scenes/ui/character_select.tscn` should use the state
frames and preview panel. Route selection onward to Area Select instead of calling
`RunState.begin(..., bamboo_forest)` directly.

### 4. Area / stage select

Delivered `asset/ui/area/cards/{bamboo_forest,abandoned_temple}.png` (224x128),
`asset/ui/area/icons/{bamboo_forest,abandoned_temple,locked,difficulty_1,difficulty_2,difficulty_3,reward,boss}.png`
(32x32), and `card_{unselected,selected,locked}_9slice.png` (96x64). A new
`scenes/ui/area_select.tscn` and `scripts/ui/area_select.gd` should consume them
between character select and `RunState.begin`. Locked uses chain/crossed corners;
selected uses a raised tab/double frame, so neither state depends on hue alone.

### 5. Base camp

Delivered `asset/ui/camp/interiors/{workshop,archive,training_ground,shrine}.png`
(224x112), `asset/ui/camp/icons/{workshop,archive,training_ground,shrine}.png`
(32x32), and `interior_panel_9slice.png` (96x64). Replace the common placeholder
body in `scenes/basecamp/camp.tscn` / `scripts/ui/camp.gd` with the corresponding
interior, building icon and panel skin while keeping its existing navigation.

### 6. In-run HUD

Delivered `asset/ui/hud/icons/{hp,boss,timer,pause,damage,pickup,kills,level}.png`
(32x32), `bar_background_9slice.png`, `hp_fill_9slice.png`, `xp_fill_9slice.png`,
`boss_fill_9slice.png` (96x16), `timer_frame_9slice.png` (96x32), and
`asset/ui/feedback/{damage_toast,pickup_toast}_9slice.png` (96x32).
`scenes/ui/hud.tscn` / `scripts/ui/hud.gd` should replace the flat ProgressBar
StyleBoxes with these textures, add a 44x44 pause button, and show the boss fill
only for a live boss. Combat still needs to provide boss-health and transient
damage/pickup signals; no combat code was edited here.

### 7. Level-up choice

Delivered `asset/ui/level_up/tier_{common,rare,legendary}.png` (32x32) and
`card_{common,rare,legendary}_9slice.png` (96x64). Use them in
`scenes/ui/level_up_choice.tscn` / `scripts/ui/level_up_choice.gd`. Common has one
corner notch, rare two, and legendary a crown/three-notched top, retaining tier
meaning without colour.

### 8. Pause and settings

Delivered `asset/ui/settings/{master_audio,music,effects,language}.png` (32x32),
`slider_{track,fill}_9slice.png` (96x16), `slider_knob.png` (24x24), and
`toggle_{off,on}.png` (48x32). A new `scenes/ui/pause_settings.tscn` and
`scripts/ui/pause_settings.gd` should consume them, reusing main Continue/Quit
icons and the existing button chrome for Back/Quit. Enclose every small icon in a
minimum 44x44 focusable control; keep Resume and Back low on the portrait layout.

### 9. Results

Delivered `asset/ui/results/{victory_banner,defeat_banner}.png` (256x128),
`{reward_chest,new_unlock}.png` (32x32), and
`{reward_callout,unlock_callout}_9slice.png` (96x48). Use them in
`scenes/ui/results.tscn` / `scripts/ui/results.gd`: the rising sun/laurel banner
and broken wreath/moon banner distinguish outcome structurally, while unlocks get
a stamped callout rather than only gold text.

### 10. Achievements and quests

Delivered `asset/ui/meta/{quest,progress,claimed,unclaimed}.png` (32x32),
`{list_row,list_row_claimed}_9slice.png` (96x48), and
`progress_{background,fill}_9slice.png` (96x16). A new
`scenes/ui/achievements_quests.tscn` and matching script should consume these with
the existing eight achievement icons. Claimed is a stamped/check silhouette;
unclaimed is an open seal, and the claimed row gains a physical seal notch.

### 11. Monetisation surfaces

Delivered `asset/ui/monetization/{rewarded_ad,continue_after_death,currency}.png`
(32x32), `{reward_prompt,continue_prompt}_9slice.png` (96x64), and
`currency_display_9slice.png` (96x32). Proposed consumers are
`scenes/ui/rewarded_ad_prompt.tscn`, `scenes/ui/continue_offer.tscn`, and the camp
currency header. Connect them to `scripts/services/ads.gd` only when the service
reports availability; the existing M1 stub must not promise an unavailable reward.

## Nine-slice margins

Margins are listed left/top/right/bottom in logical pixels:

| Asset group | Source size | Margins |
|---|---:|---:|
| Existing `chrome/panel_9slice.png` | 48x48 | 6/6/6/6 |
| Existing `chrome/button_*_9slice.png` | 64x32 | 6/8/6/8 |
| All 96x16 bars/tracks/fills | 96x16 | 6/6/6/6 |
| All 96x32 plaques/timers/toasts/displays | 96x32 | 8/8/8/8 |
| All 96x48 result/meta rows and callouts | 96x48 | 10/10/10/10 |
| All 96x64 slots/cards/panels/prompts | 96x64 | 12/12/12/12 |
| Character 96x96 cards | 96x96 | 12/12/12/12 |

## Generation, rejection, and verification evidence

Higgsfield balance was **872.55 before** and **854.55 after**: nine Nano Banana
Pro sheet jobs at 2 credits each spent **18.00 credits**. The preflight was 2
credits per submitted job; packing related pieces into nine sheets conserved the
budget. No journey step was dropped.

The model did not always obey the stated grid: camp interiors arrived 2x2 rather
than 4x1, camp icons arrived 4x2 rather than 4x1, and HUD/settings used two five-
cell rows plus a four-cell row. Each raw sheet was visually audited and sliced by
its actual layout instead of pretending the prompt layout succeeded. Generated
pseudo-Hangul/pseudo-writing in the language, Taoist, Archive, and Shrine cells,
an equal-sign-like pause mark, and a neighbour fragment on Kills were rejected;
the first four were redrawn deterministically without text in the exact palette,
and the fragment was mechanically removed. Raw failures remain for audit and
recutting.

`tools/asset/measure_ui_journey.py` verifies 47 32px icons, 11 illustrations, 31
nine-slices, three fixed controls, hard alpha, chroma removal, exact furniture
palette, state-shape differences, and WCAG contrast. Recorded ratios are 13.75:1
ink/paper, 10.58:1 ink/dark-paper, 15.55:1 light-text/ink, and 7.34:1
light-text/dark-vermilion. Contact sheets for final human review are
`asset/ui/raw/journey/ui_icons_overview.png`, `ui_illustrations_overview.png`, and
`ui_furniture_overview.png`.

The required repository commands produced the following real terminal results:

```text
> godot --headless --path . --import
[no stdout]
exit 0

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
exit 0

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
exit 0
```

The validator additionally printed its existing `Image.load()` export warning once
for each of the 22 flat monster PNGs; it still exited 0 and reported no data errors.
The asset-specific commands produced:

```text
> python tools/asset/measure_ui_journey.py
icons=47 illustrations=11 furniture=31 fixed_controls=3
contrast={'ink_on_paper': 13.75, 'ink_on_paper_dark': 10.58, 'light_text_on_ink': 15.55, 'light_text_on_vermilion_dark': 7.34}
accepted=True

> python tools/asset/verify_assets.py
UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed
exit 0
```
