# Status effect strips

Both status effects are horizontal four-frame loop strips. Each cell is `24x24`, so the
strip canvas is `96x24`; frame rectangles are `(0,0,24,24)`, `(24,0,24,24)`,
`(48,0,24,24)`, and `(72,0,24,24)`.

| id | path | frame content bboxes | opaque pixels | changed pixels, including loop seam |
|---|---|---|---|---|
| `burn` | `res://asset/effect/status/burn/strip.png` | 17x21, 16x21, 17x21, 16x20 | 240, 244, 234, 220 | 87, 98, 82, 56 |
| `seal` | `res://asset/effect/status/seal/strip.png` | 17x17, 21x21, 21x21, 17x17 | 247, 271, 281, 247 | 109, 128, 148, 85 |

Playback recommendation: loop frames `0,1,2,3` at 10 fps, use bottom-centre anchoring,
and position the strip 6 logical pixels above the enemy's sprite bounds. Do not filter or
interpolate; both strips use binary alpha, flat palettes, and a one-pixel dark outline.
