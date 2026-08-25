# Dedicated weapon and warrior effects

`build_weapon_skill_effects.py` keeps the staff sheets at 128px per frame. It
normalizes chamgyeok onto a 75px grid and cheolbyeok onto a 48px grid before
exact x2 nearest-neighbour enlargement, producing cells that exactly match
their 150px and 96px data display sizes. Every edge stays pixel-aligned and
reproducible; the shipped sheets have binary alpha and no antialiasing.

## Deliverables

| Effect | Sheet | Frames | Data playback | Display size | Read |
| --- | ---: | ---: | ---: | ---: | --- |
| `swing_seokjang` | 1024x128 | 8 | existing 20fps | 96px | blunt brass wedge, dust/gravel, 2-3 rings |
| `swing_ghost_staff` | 1024x128 | 8 | existing 20fps | 96px | matching blunt wedge, pale ghost silhouettes, violet rings |
| `skill_chamgyeok` | 1200x150 | 8 | 20fps | 150px | sword-tip flash, filled 130-degree two-hand cleave, crimson fragments |
| `skill_cheolbyeok` | 576x96 | 6 | 18fps | 96px | fixed octagonal steel ring, crimson sparks, bright locked final frame |

The two existing staff entries remain unchanged as requested; their playback
rate in `data/effects.json` is 20fps. Only the two new skill effects were added
to the registry.

## Comparison check

`weapon-effect-comparison.png` shows, from left to right, the densest frame of
the two staffs, all five sword swings, and chamgyeok in one row. Normal weapon
effects are rendered at their 96px gameplay size and chamgyeok at 150px. The
second row shows all six cheolbyeok frames at 96px.

- Maximum peak-silhouette IoU between either staff and any sword: `0.2676`.
- Maximum peak-silhouette IoU between chamgyeok and any of the seven weapon
  swings: `0.4118`.
- Chamgyeok uses 21 visible sheet colours and cheolbyeok uses 24, with hard
  dark edges, outer/mid/core bands, and bright ignition accents.
- The staff pair shares the same blunt-impact skeleton but separates by
  material: dust and gravel versus floating souls and pale violet ring echoes.
- At gameplay size, the staff wedges remain straight, broad masses; all five
  swords remain thin crescents; chamgyeok is a much larger filled fan and does
  not collapse into a normal attack trail.

## Rebuild and validation

From the repository root:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python asset/effect/build_weapon_skill_effects.py
```

The builder rejects wrong dimensions, partial alpha, empty frames, more than
64 colours, fewer than 12 visible warrior-active colours, any logical-grid
roundtrip difference, a cell that differs from `logical_px`, a staff/sword
peak IoU of 0.45 or greater, or a chamgyeok/weapon peak IoU of 0.45 or greater.
