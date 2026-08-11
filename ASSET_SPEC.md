# JOSEONLIKE Asset Specification

Authoritative rules for every piece of art and audio in this project. Coordinator-owned:
`asset-forge` follows it, `verify_assets.py` enforces what can be automated, and anything this
document does not cover is a question for the coordinator rather than a judgement call.

Every rule here exists because something shipped wrong without it. The failures are named so
nobody has to rediscover them.

---

## 1. Style authority

`asset/character/Taoist/Idle/rotations/south.png` is the reference. Measured, not assumed:

| Property | Value |
|---|---|
| Canvas | 92 x 92 |
| Character content | 37 x 46 pixels |
| Opaque colours | 52 |
| Dominant | pure black `(0,0,0)` outline, dark blue-grey `(31,34,49)` |
| Proportions | chibi, head roughly one third of body height |
| Camera | low top-down, looking down from slightly above |
| Shading | flat, two or three tones per material, no gradients, no anti-aliasing |

**Resolution is what breaks first.** A monster drawn 120 px tall reads as a different, far more
detailed art style no matter how good the prompt was. The first monster set was thrown away for
exactly this. Content height by class:

| Class | Content height |
|---|---|
| Player character | 46 |
| Trash monster | 44 – 58 |
| Elite | 58 |
| Boss | 76 |
| Fixed UI icon | 32 x 32 canvas |
| Effect frame | 64 x 64 canvas |
| Ground tile | 256 x 256, seamless |

---

## 2. Directions

Eight directions, named exactly:

```
south, south-east, east, north-east, north, north-west, west, south-west
```

Facing requirements, and these are semantic — no pixel metric can check them:

| Cells | Must show |
|---|---|
| `south`, `south-east`, `south-west` | the face |
| `east`, `west` | opposite profiles |
| `north`, `north-east`, `north-west` | the back of the head, no face |

Adjacent directions must be **distinguishable by eye**, not merely different in pixel count.
Two back views differ numerically while both remain back views, which is how a set with three
identical rear cells passed verification once.

A creature with no meaningful front — a symmetric flame, an amorphous spirit — is recorded as a
**known-limited set** rather than given eight fabricated views. It still must drop the face on
its northern three cells if it has a face at all.

Mirroring `east` to produce `west` is permitted for shapes that are genuinely symmetric in
profile. It is not generation and must be reported as mirroring.

---

## 3. Set composition

Art is commissioned, generated and reviewed as a **complete set per entity**, never as loose
images. A set missing members is unfinished, not partially delivered.

| Set | Required members |
|---|---|
| Character | 8 idle rotations, walk, attack, death |
| Monster | 8 idle rotations, walk, death |
| Weapon | 32x32 icon, projectile or VFX art, attack effect |
| Effect | 4 frames: anticipation, expansion, peak, dissipation |

Every member must **exist**, or be **recorded as satisfied another way with the measurement
behind it**. Those are the only two acceptable states. Silently absent is not one.

Currently recorded as satisfied otherwise:

- **Character walk and attack** — pixel-snapped procedural motion in `CharacterMotion`, after
  generated frames were rejected four separate ways (section 6).

---

## 4. Motion frames

Order is fixed: `anticipation, expansion, peak, dissipation` for effects; for a death, the last
frame is the resting state (corpse, or fully dissipated spirit).

A motion sequence is judged on **progression**, not on frame-to-frame identity. That distinction
is why death sequences passed where walk cycles failed: a walk demands the character stay
identical while only the legs move, and a death is supposed to change irreversibly, so the same
drift reads as collapse instead of flicker.

---

## 5. Files and paths

Paths are `res://asset/...` — **singular**, not `assets/`.

```
asset/character/<Name>/Idle/rotations/<direction>.png
asset/character/<Name>/Death/<n>.png
asset/character/<Name>/raw/...              pre-cutout generator output
asset/monster/<id>.png                      flat sprite, referenced by data/monsters.json
asset/monster/<id>/rotations/<direction>.png
asset/weapon/icons/<id>.png                 fixed 32x32
asset/weapon/projectiles/<id>.png
asset/effect/<name>/<0-3>.png
asset/stage/, asset/structure/, asset/prop/, asset/title/, asset/audio/
```

Ids are `snake_case` ASCII. Keep pre-cutout generator output under the set's `raw/` so a sprite
can be recut at another size without paying to regenerate it.

`data/monsters.json` points at the flat sprite and the validator ties `collision_radius` to its
pixel width. **Changing a flat sprite's dimensions breaks data validation in a worktree that
does not own the art** — report new dimensions to the coordinator instead of editing data.

---

## 6. Generation rules

Condition on existing art. Pass the reference sprite, and the entity's own correct cells, as
image inputs. "Match the reference" alone does not work; state its measured traits as
constraints.

**Background:** flat chroma, and never a colour the subject contains. A green creature on a
green screen keys away to nothing — that cost a regeneration. Magenta `#FF00FF` is the default,
and the prompt must state that no magenta may appear on the subject.

**Framing:** demand a margin of empty background on all four sides. Asking the subject to "fill
the frame" crops the feet off.

**Sheets versus per-image.** A sheet is one generation containing many cells, sliced by
`slice_sheet.py`. It is cheap and correct for effects, props, structures and icons, where a
mis-slice produces obvious garbage rather than a quiet lie.

For **rotations**, a mis-slice is dangerous: the model does not always lay cells on the grid we
assume, so the slicer cuts across subjects and every cell inherits a wrong image that then gets
a direction name it does not match. This produced cells containing sheet grid lines, cells
containing two figures, and directions facing the wrong way — all of which passed structural
verification. Therefore:

> Sheets are allowed for rotations **only** when every cell is inspected individually and the
> per-cell mechanical checks pass. If inspection finds anything wrong, regenerate the failing
> cells as **one image per direction**, each conditioned on that entity's correct `south`
> sprite, each stating its own direction and what must be visible.

**What does not work, measured — do not retry without a new idea:**

| Attempt | Result |
|---|---|
| Two separate renders of the same pose | 449 / 1702 pixels changed (26.4%) |
| Frames packed into one sheet | 510 / 1702 (30.0%) — worse |
| Frames conditioned on their own direction's idle | 1005 / 1702 and 987 / 1702, only ~34% of change in the lower body; hat and staff moved |
| Six multi-reference motion sheets | 0 of 96 frames accepted |

At 37x46 a leg swing is 6–10 px of silhouette change, and no whole-sprite offset competes with
that. Real walk and attack frames need human pixel authoring, not generation.

---

## 7. Cutting

```bash
python tools/asset/pixelize.py <in.png> <out.png> <content_height> <palette_dir> [canvas_size]
```

Chroma-key, crop to content, downscale with **BOX** (averaging beats NEAREST here — NEAREST
point-samples one arbitrary source pixel per cell and keeps generator noise), then quantise.

The palette is the reference palette **plus** the subject's own dominant hues. Snapping to the
reference palette alone turned the bamboo brute stone grey, because the reference contains no
green. Consistency comes from resolution, outline weight and flat shading — not identical hues.
Outline pixels are forced to pure black so the silhouette reads at sprite size.

`project.godot` sets `default_texture_filter=0` globally. Never add a filtering import
override; it turns the pixel grid to mush.

---

## 8. Verification

Two layers, and neither substitutes for the other.

**Automated** — `tools/asset/verify_assets.py`: fixed canvases, hard alpha, chroma removal,
tile seams, palettes, audio format and peak, semantic facing checks, and per-cell mechanical
checks (exactly one subject, centred, no grid line, no fragment of a neighbour).

**Visual** — a contact sheet per set, in the column order of section 2, inspected cell by cell
before the set is reported done. Retain the sheets under `asset/rotation_audit/` as evidence.

A structural pass is not a review. The verifier once reported every rotation set green while one
set contained grid lines and another contained two figures per cell, because nothing it checked
could see either. When reporting a set as verified, state **what was verified**.

---

## 9. Reporting

A set is reported with: what shipped, what failed measurement **with its numbers**, exact paths
and frame order for the consuming worktree, and credits spent. A truthful negative result is a
real answer and is worth more than art that measured badly and shipped anyway.

Check `balance` before a batch and preflight cost. The backend appears to charge per submitted
job even when a preflight quotes less; estimate accordingly.
