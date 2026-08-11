# Layered Title and Author Audio Report

## Outcome

The author audio is filed under stable snake-case runtime paths and the four WAV
one-shots now match the project contract: mono, 16-bit PCM, 22050 Hz, trimmed to
the event, and peak-normalised to -3.01 dBFS. The title now ships as six
full-canvas registered layers plus a seamless fog strip and an 8x8 mote, so
meta-ui can animate depth rather than tweening one flat picture.

## Job 1: audio

### Runtime paths

Music was copied byte-for-byte without re-encoding:

- `asset/audio/bgm/joseonlike.mp3`
- `asset/audio/bgm/moonlit_sanctuary.mp3`
- `asset/audio/bgm/bamboo_forest_spirits.mp3`

Effects:

- `asset/audio/sfx/ui_click.wav`
- `asset/audio/sfx/enemy_death.wav`
- `asset/audio/sfx/player_death.wav`
- `asset/audio/sfx/energy_sound.wav`

All seven delivered files remain byte-for-byte under `asset/audio/raw/` with their
original filenames. Reproducible hashes, trim gate data and measurements are in
`asset/audio/raw/author_audio_metrics.json`.
The first six retained files' SHA-256 values were also compared against their
pre-change Git blobs; all six comparisons were exact. The later energy delivery
was moved byte-for-byte from `asset/audio/bgm/energy_sound.wav` to
`asset/audio/raw/energy_sound.wav` before processing.

### Measured before and after

| Runtime id | Delivered duration | Delivered peak | Natural trim | Runtime duration | Runtime peak |
|---|---:|---:|---:|---:|---:|
| `ui_click` | 1.000 s | 0.04358 / -27.21 dBFS | 0.170 s | 0.170 s | 0.7063 / -3.01 dBFS |
| `enemy_death` | 3.000 s | 1.0000 / 0.00 dBFS | 1.730 s | 0.150 s | 0.7063 / -3.01 dBFS |
| `player_death` | 1.000 s | 0.51923 / -5.69 dBFS | 0.630 s | 0.630 s | 0.7063 / -3.01 dBFS |
| `energy_sound` | 1.000 s | 0.89578 / -0.96 dBFS | 0.510 s | 0.510 s | 0.7063 / -3.01 dBFS |

`enemy_death` has a deliberate runtime cut shorter than its natural noise-gated
tail. Combat has eight round-robin death voices and can recycle one every roughly
0.13 seconds in a dense wave. The first 150 ms contains 41.17% of the original's
total energy, 100% of its peak, and its strongest transient lies in the first
80 ms. Keeping the 1.730-second tail would mean roughly 92% of every voice was
silently interrupted during real play; the 0.150-second version preserves the
recognisable attack and needs no combat voice-policy change.

`energy_sound` is a naturally trimmed one-shot: its last sustained 20 ms window
ends at 0.48 s and a 30 ms release produces the 0.510 s runtime cut while
retaining 99.98% of source energy. Its purpose is not yet known, so it is filed
as SFX rather than guessing a BGM role.

The duration table in `tools/asset/verify_assets.py` checks all eight runtime
WAV files. A directory inventory now also sweeps `ambience/`, `bgm/`, and `sfx/`
and fails for any `.wav`, `.mp3`, or `.ogg` not explicitly registered, closing
the blind spot that let `energy_sound.wav` pass while unmeasured.

## Job 2: layered title

### Runtime inventory and registration

Every scene layer is exactly 540x960 and stacks at `(0, 0)` in this order:

1. `asset/title/layers/sky.png` - opaque sky, paper moon, far mountains
2. `asset/title/layers/moon_glow.png` - transparent discrete halo already centred over the moon
3. `asset/title/layers/palace.png` - transparent moonlit palace and lateral walls
4. `asset/title/layers/bamboo_far.png` - transparent, lifted cool distant bamboo
5. `asset/title/layers/bamboo_near.png` - transparent dark edge-framing bamboo
6. `asset/title/layers/ground.png` - transparent foreground approach and undergrowth

Motion members:

- `asset/title/fog_strip.png` - 1080x320 transparent strip; left/right seam differs by **0 pixels**
- `asset/title/mote.png` - 8x8 transparent spirit mote, 15 opaque pixels

No offset or coordinate manifest exists or is needed. Retained review artifacts:

- `asset/title/raw/title_layers_composite.png` - six-layer 540x960 stack
- `asset/title/raw/title_layers_comparison.png` - original flat backdrop at left, new stack at right
- `asset/title/raw/title_generation_overview.png` - all eight delivered generation raws
- `asset/title/raw/title_layers_metrics.json` - dimensions, coverage, palette and value evidence

### Visual review

I inspected the complete composite beside `asset/stage/backdrops/main_menu.png`,
not just the individual files. There are no holes: the opaque sky remains behind
every transparent omission. The original lower two-thirds measured **21.25**
mean luminance; the corrected stack measures **55.62**. More importantly, the
actual action band at x32..508, y556..936 measures **50.61** mean luminance,
**0.54** mean local 8x8 standard deviation, and **60.61** maximum luminance,
inside the 40..55 / <=7 / <=110 targets. The palace roof and windows,
cool far bamboo, dark near framing and warm foreground form visible value steps.
Near trunks partially occlude the moon/halo as foreground should, while the central
corridor remains open for the logo and controls. Path stones, rubble, and warm
highlights now occupy y300..490; below y600 the ground settles into a continuous,
subtle-texture plane so button labels do not compete with local highlights or holes.

### Generation, raw retention and honest corrections

Higgsfield Nano Banana Pro (`nano_banana_2` backend), one independent generation
per member, all conditioned on the existing flat main-menu backdrop:

| Member | Job id |
|---|---|
| sky | `700e562d-b60f-43c7-bbf0-62382960605e` |
| moon glow | `d06bd039-1ea8-43a6-b4d3-84f9f29b15f6` |
| palace | `d47ea837-0844-4d51-845f-4aa6a6160e33` |
| far bamboo | `14b32517-39f4-4411-9122-5b25dc02bead` |
| near bamboo | `230cb463-6dc6-4435-b568-397ad8bf34e0` |
| ground | `2d1da15a-ffe0-4ad4-8173-b3866b9968de` |
| fog strip | `62839fc2-c7ff-402f-80dd-ad04645cf50d` |
| mote | `3fa4510f-0ae6-4b5a-9593-f5f2bfd53afd` |

Prompt scaffold: preserve the reference composition and low top-down pixel-art
style; use crisp square pixels, pure-black contours, flat two/three-tone shading,
ink-blue/charcoal/paper/vermilion values, no text/UI/people/watermarks, and emit
only the named layer. Transparent members requested flat `#FF00FF` chroma and
explicitly excluded every other stack member. The fog requested compatible edge
wisps; the mote requested one bright compact centred particle.

Six raw layers followed their isolation prompt. Two did not, and the failures are
retained rather than hidden:

- `moon_glow_higgsfield.png` drew two overlapping halos. The valid upper generated
  ring was circularly isolated, scaled to the reference moon and pre-positioned on
  its full 540x960 canvas.
- `mote_higgsfield.png` redrew the reference scene around one correct central mote.
  Only that generated 32x59 source region was extracted and reduced to 8x8.

The fog was mirror-wrapped after chroma removal: generated content is retained,
but the outer seam is mechanically exact rather than trusting a model's
"seamless" claim. Every raw remains under `asset/title/raw/` for recutting.

The action-band correction used one targeted OpenAI image edit, conditioned on
the existing ground layer and title composite, to author a quieter inhabited-earth
source with the detail moved upward. The retained raw is
`asset/title/raw/ground_action_band_edit_openai.png`; deterministic processing
shifts its path upward, cross-fades into a compressed-contrast lower texture, and
recomputes the exact action-band metric.

### Credits

- Balance before: **824.55**
- Preflight: **2 credits each**, eight individual jobs, **16 credits estimated**
- Balance after: **808.55**
- Actual spend: **16.00 credits**

## Integration notes

`meta-ui` should stack the six registered layers at the origin, add/pulse
`moon_glow` additively, apply small parallax/sway offsets at runtime, horizontally
scroll two adjacent fog-strip instances, and spawn/tint/scale instances of the
8x8 mote. The old `asset/stage/backdrops/main_menu.png` remains untouched as a
fallback and comparison authority.

No `data/**`, `scripts/**` or `scenes/**` file was changed.

## Verification

All required and project-wide checks exited 0:

```text
> godot --headless --path . --import
(no output; exit 0)

> godot --headless --path . --quit
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

> godot --headless --path . --script tools/validate_data.gd
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
PASS data validation: no errors
```

The validator also printed its existing `Loaded resource as image file`
warnings for monster PNGs; no warning concerns these title/audio assets and the
command exited 0.

```text
> python tools/asset/verify_assets.py
M1 assets verified: 20 UI icons + 5 chrome assets, 34 weapon assets, 2 characters, 4 seamless tiles, 8 checked WAVs + 3 inventoried music tracks
Motion-generation rejection evidence: 449/1702 pixels changed between same-pose frames
Single-sheet retry rejected: idle pair 510/1702 versus separate baseline 449/1702
Direct-conditioned retry rejected: south walk frames 1005/1702 and 987/1702
Directional additions verified: 14 class rotations + 32 monster rotations, 3 backdrops, 12 props
Six multi-reference motion sheets rejected: 0/96 frames passed the regional stability gate
Expansion assets verified: 18 folklore monsters + 144 rotations, 60 effect frames, 12 structures, 3 title assets
Set-gap additions verified: 100 death frames, 22 procedural walk records, 5 travel sprites, 4 melee swings
Loot and boss-scale assets verified: 12 pickup sets (48 collect frames) + 120x150 boss with 8 rotations and 4 death frames
Destructible stage objects verified: 8 intact sprites + 32 break frames + 8 debris aliases; progression/scale/cue gates passed
Directional-facing audit verified: 25/25 sets, 200 hash-bound cells manually reviewed
Character near-duplicate gate verified: 84 pairs at mean-RGBA threshold 2.50; minima: Taoist 5.11 (east/west), Warrior 2.88 (north-east/north), Archer 4.58 (north-west/south-west)
UI journey verified: 47 icons, 11 illustrations, 31 nine-slices, 3 fixed controls; WCAG-AA/state gates passed
Camp identity verified: 2 warm seamless tiles + 3 rotatable north-facing transition overlays
Button redesign verified: 3 directions x 4 states; selected royal_seal, 6x8 margins, WCAG-AA/pressed-shape gates passed
Layered title verified: 6 registered 540x960 layers + seamless 1080x320 fog + 8x8 mote; action band mean=50.61, local8=0.54, max=60.61
PASS audio inventory negative-path: omitted energy_sound.wav was rejected
```

Focused checks also passed: `python -m py_compile` for both new processors and
the verifier, `git diff --check`, and an ownership diff proving no file outside
`asset/**` or `tools/asset/**` changed.
