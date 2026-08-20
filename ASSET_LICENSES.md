# JOSEONLIKE — Asset Licenses

Every asset under `asset/` must have a row here before it ships. No row, no commit.

| Path | Source | License | Attribution required | Added |
|---|---|---|---|---|
| `asset/font/neodgm.ttf` (Neo둥근모) | https://github.com/neodgm/neodgm v1.530 | SIL OFL 1.1 | Credit in-game before release (RZ) | 2026-08-14 (relocated) |
| `asset/effect/swing_arc.png` | Owner-dropped pack `new_asset/owner/Effects` (sprAttackSwing; copied unmodified — already a square-frame strip) | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-20 (N9-70) |
| `asset/sfx/*.wav` (8 effects) | Generated in-repo by `tools/make_sfx.gd` from the synth definitions in that file — no third-party audio | None — original output of this project | None | 2026-08-19 (N9-52) |
| `asset/effect/blink_puff.png` | Owner-dropped pack `new_asset/owner/Retro Impact Effect Pack 5` (sheet A, row 23; desaturated for engine tinting). explosion/strike_flash sheets dropped N3-18 — back to code-drawn | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-15 |
| `asset/effect/hit_{fire,lightning,curse,neutral}.png` | Owner-dropped pack `new_asset/owner/Retro Impact Effect Pack 5` (sheets A/C/B/F, rows 15/9/13/13; native 64px frames assembled by `asset/weapon/build_travel.py`) | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-18 (N9-3f) |
| `asset/weapon/travel/*.png` (11 N9-3f projectile sprites) | Owner-dropped pack `new_asset/owner/500 Bullet 24x24 Free` (Parts 2A/2B/2C/3C; native cells cropped without resampling by `asset/weapon/build_travel.py`) | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-18 (N9-3f) |
| `asset/pickups/health.png` | Owner-dropped pack `new_asset/owner/Pixel UI pack 3` (00.png red heart; night-tinted via asset/pickups/build_assets.py) | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-18 (N6-5) |
| `asset/pickups/nuke.png` | Owner-dropped pack `new_asset/owner/Trap and Weapon` (Bomb.png frame 0; night-tinted via asset/pickups/build_assets.py) | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-18 (N6-5) |
| `asset/bgm/{title,camp,bamboo_forest}.mp3` | Owner-dropped `new_asset/owner/bgm/{Joseonlike,본거지,대나무숲}.mp3`, copied byte-for-byte and renamed to ascii ids | Free to use — owner confirmed 2026-08-20 that every pack he dropped states free licensing. No licence file ships inside the pack itself | None stated | 2026-08-19 (N9-1a) |

## Rules

- Third-party or free-asset-pack material: record the exact pack name, author, URL and
  license (CC0 / CC-BY / OFL / commercial) in its own row, and keep the license text in
  the pack's own folder.
- CC-BY and similar attribution licenses must also appear in the in-game credits before
  release (ROADMAP RZ).
- Anything whose license cannot be established does not enter the repository.
- Owner-supplied assets are recorded as `Owner-supplied` with the delivery date.
