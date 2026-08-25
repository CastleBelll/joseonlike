# Dedicated weapon and warrior effects

`build_weapon_skill_effects.py` keeps the staff sheets at 128px per frame and
normalizes both warrior actives onto a 64px logical grid before exact x2
nearest-neighbour enlargement. This keeps every edge pixel-aligned and
reproducible; the shipped sheets have binary alpha, no antialiasing, and 6-7
RGBA colours.

## Deliverables

| Effect | Sheet | Frames | Data playback | Display size | Read |
| --- | ---: | ---: | ---: | ---: | --- |
| `swing_seokjang` | 1024x128 | 8 | existing 20fps | 96px | blunt brass wedge, dust/gravel, 2-3 rings |
| `swing_ghost_staff` | 1024x128 | 8 | existing 20fps | 96px | matching blunt wedge, pale ghost silhouettes, violet rings |
| `skill_chamgyeok` | 1024x128 | 8 | 20fps | 150px | sword-tip flash, filled 130-degree two-hand cleave, crimson fragments |
| `skill_cheolbyeok` | 768x128 | 6 | 18fps | 96px | fixed octagonal steel ring, crimson sparks, bright locked final frame |

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
  swings: `0.4138`.
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
64 colours, a warrior-active logical-grid roundtrip difference of 2% or more,
a staff/sword peak IoU of 0.45 or greater, or a chamgyeok/weapon peak IoU of
0.45 or greater.
