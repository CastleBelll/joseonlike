# Side-view character sprites

## Runtime format

- Logical canvas: **32 × 32 pixels** per frame.
- Export scale: **16× nearest-neighbour**, matching `new_asset/basic.png`.
- Exported frame size: **512 × 512 pixels**.
- `idle.png`: one right-facing / three-quarter-right idle frame, **512 × 512**.
- `walk.png`: four right-facing walk frames in one horizontal strip, **2048 × 512**.
- Color: RGBA PNG with binary alpha. Every exported mark is a uniform **16 × 16** block from the logical grid.
- Shared ground line: logical row **29**. Every frame keeps its full 32 × 32 canvas rather than trimming transparent margins.

The authored pose follows `basic.png`: movement reads toward screen-right, while the face and torso retain a natural three-quarter view instead of a rigid 90-degree profile. Mirror these files in-engine for leftward movement.

## Character identity and held weapon

- **Taoist (도사):** black gat, white dopo with navy binding, held yellow paper talismans (부적).
- **Warrior (무사):** brick-red cheollik, restrained lamellar vest, navy headband, held hwando (환도).
- **Archer (궁수):** tan paeraengi, ochre hunting clothes, leather chest strap, held gakgung (각궁).

The weapon silhouettes contain no lettering or asymmetric emblem, so horizontal mirroring remains valid.

## Walk order and slicing

Slice `walk.png` as **4 columns × 1 row**, with 512 × 512 regions:

1. Contact A
2. Passing A
3. Contact B
4. Passing B

Loop frames `0 → 1 → 2 → 3` at about 8–10 fps. The walk frames share one pixel-identical upper-body layer through logical row 22; generated lower robe and leg pixels below it retain the alternating walk poses.

## Higgsfield generation

Each character came from **one five-pose sheet generation**, never from independent frame generations. This keeps identity, costume, weapon, and proportions coherent before local stabilization.

- Service: Higgsfield MCP image generation.
- Model: **GPT Image 2** (`gpt_image_2`).
- Preset/parameters: **2K**, **high** quality, **16:9**, one result.
- Style conditioning: uploaded `new_asset/basic.png` in every final generation.
- Structure conditioning: a prior whole five-pose sheet for the same character was also supplied to the final weapon-bearing generation.
- Final raw sheet size: **2688 × 1520**.
- Final generation job IDs:
  - Taoist: `487b1777-095d-4bd1-984b-b30e160d68a9`
  - Warrior: `afa6940e-3354-4723-9618-124453026322`
  - Archer: `96d56675-ea72-4a26-b700-dc651f78d367`

The requested Higgsfield `get_workflow_instructions({ workflow: "character-sheet" })` operation was not registered in this worker session. Work paused and the coordinator explicitly authorized using the available Higgsfield generation tools directly; all single-sheet consistency constraints remained in force.

Raw generated sheets are preserved at:

- `asset/character/Taoist/raw/side_sheet_higgsfield.png`
- `asset/character/Warrior/raw/side_sheet_higgsfield.png`
- `asset/character/Archer/raw/side_sheet_higgsfield.png`

## Local post-processing

Run from the repository root:

```text
python tools/process_higgsfield_sideview_sprites.py
```

The processor performs only generated-image transformations; it does not draw character pixels:

1. Removes the generated green chroma background by color dominance.
2. Finds the five largest connected foreground components and orders them left-to-right.
3. Reduces all five figures with one per-character scale onto a 32 × 32 logical grid.
4. Aligns each frame from the hat/head anchor and fixes the feet to logical ground row 29.
5. Reuses the first generated walk frame's upper layer for the other walk frames through row 22, eliminating head, costume, and held-item flicker.
6. Quantizes the whole five-frame sheet together to a shared bounded palette with no dithering.
7. Exports the logical pixels at 16× using nearest-neighbour sampling.

The earlier `tools/generate_sideview_sprites.py` Pillow drawing workflow was removed. It is superseded by the Higgsfield source sheets and the extraction-only processor above.

## Verification

All six runtime PNGs and all three four-frame strips were visually inspected after processing. The checks confirmed:

- exact dimensions: idle 512 × 512; walk 2048 × 512;
- transparent PNG output with binary alpha;
- all opaque pixels snapped to the 16× export grid;
- equal 512-pixel walk cells and one common canvas height;
- palette totals of 16–17 RGBA entries including transparency;
- logical alpha bounds ending on ground row 29;
- **0.0 logical-pixel upper-body center spread** across each four-frame walk loop;
- stable gat/headband/paeraengi, costume, face, and held weapon across the walk frames;
- distinct alternating lower-body poses and readable loop order;
- no background remnants, dividers, labels, or watermark.

Keep texture filtering and mipmaps disabled in Godot so the 32 × 32 logical pixels remain crisp.
