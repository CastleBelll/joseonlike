"""Take the owner's upgraded talisman icons into the icon contract (N10-7a).

The owner drops art under whatever name and size the generator gave it. Two
things have to happen before the game can use it:

1. **Name.** UiIcons binds by filename — `asset/ui/weapon_icons/<weapon id>.png`
   — so a drop called `talisman-hawbu.png` is invisible to the build strip and
   validate_data fails the weapon that lost its icon.
2. **Shape.** `UiIcons.icon_rect` gives every icon a SQUARE rect and fills it
   with STRETCH_SCALE, so a 1024x1536 portrait drop renders squashed. The drop
   is trimmed to its subject and re-centred on a square.

Size is 512 because that is what every icon in the set already is (32 logical
x16) and because a weapon icon is displayed at 24-64 px — a 1024 source buys
nothing there and small pixel art tends to read WORSE the more detail it
carries into the downscale.

Originals are moved, never deleted (owner direction 2026-08-24): they land in
new_asset/source/weapon_icons/ so a re-cut can start from the drop.

Run: python asset/ui/adopt_weapon_icons.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ICONS = ROOT / "asset" / "ui" / "weapon_icons"
KEEP = ROOT / "new_asset" / "source" / "weapon_icons"

SIDE = 512
## Alpha below this is glow, not subject. Trimming on "any alpha at all" let a
## nearly invisible halo decide the framing.
ALPHA_FLOOR = 24
## How much of the square the subject fills. Matches the set already there
## (measured: 0.87-0.92 wide, 0.91-0.96 tall).
FILL = 0.94

## Drop name -> weapon id. The owner's filenames do not survive the round trip
## (`hawbu` for 화부, `noe`/`noebu` for two different 부적), so the mapping is
## read off the art instead: within each element the plain talisman is the
## common-grade base and the creature — phoenix, dragon, skulls — is its 개조.
## Confirmed against data/weapons.json grades: hwabu/noebu/sal are common,
## fire_talisman rare, noejeongbu/gwisal epic.
ADOPT = {
    "talisman-hwa": "hwabu",
    "talisman-hawbu": "fire_talisman",
    "talisman-noe": "noebu",
    "talisman-noebu": "noejeongbu",
    "talisman-sal": "sal",
    "talisman-gwisal": "gwisal",
}
## Already correctly named, but not on the frame the set shares — either
## dropped at a portrait size the square rect would squash, or trimmed wrong
## by the alpha bug above. Re-fitting an icon that is already 512 square is
## still worth it: what matters is that the drawing inside sits at the same
## scale as the rest of its series.
RESQUARE = ["old_talisman", "honbul"]


def to_square(image: Image.Image) -> Image.Image:
    """Trim to the subject, then centre it on a transparent square."""
    image = image.convert("RGBA")
    # The ALPHA bbox, not the image bbox. These drops carry colour underneath
    # their transparent pixels, so Image.getbbox() — which reads every band —
    # returned the whole canvas and trimmed nothing: 낡은 부적 came out half the
    # size of its own series because its drawing sat in a wide empty margin.
    # A threshold, not "any alpha at all": these drops carry a wide, nearly
    # invisible glow, and counting it as subject shrank 혼불 to two thirds of
    # its series.
    solid = image.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0)
    box = solid.getbbox()
    if box is None:
        raise ValueError("icon has no visible subject")
    subject = image.crop(box)
    inner = int(SIDE * FILL)
    scale = min(inner / subject.width, inner / subject.height)
    fitted = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    canvas.paste(fitted, ((SIDE - fitted.width) // 2, (SIDE - fitted.height) // 2))
    return canvas


def main() -> None:
    KEEP.mkdir(parents=True, exist_ok=True)
    for drop_name, weapon_id in ADOPT.items():
        drop = ICONS / f"{drop_name}.png"
        if not drop.exists():
            # Already adopted once. Re-cut from the preserved original rather
            # than from the icon, so a fix costs one resample, not two.
            drop = KEEP / f"{drop_name}.png"
        if not drop.exists():
            print(f"  skip {drop_name}: not here")
            continue
        source = Image.open(drop)
        size = source.size
        to_square(source).save(ICONS / f"{weapon_id}.png")
        source.close()
        print(f"  {drop_name} {size[0]}x{size[1]} -> {weapon_id}.png {SIDE}x{SIDE}")
        if drop.parent == ICONS:
            drop.replace(KEEP / drop.name)
            sidecar = ICONS / f"{drop_name}.png.import"
            if sidecar.exists():
                sidecar.unlink()  # Godot re-imports by name; a stale one is noise
    for weapon_id in RESQUARE:
        path = ICONS / f"{weapon_id}.png"
        if not path.exists():
            continue
        # Keep the drop before overwriting it. Running this without the guard
        # destroyed the owner's 1024x1536 낡은 부적 and 1156x1360 혼불 — the only
        # copies, since they were named right and so were never moved aside.
        kept = KEEP / f"{weapon_id}.png"
        if not kept.exists():
            kept.write_bytes(path.read_bytes())
        source = Image.open(path)
        size = source.size
        squared = to_square(source)
        source.close()
        squared.save(path)
        print(f"  {weapon_id} {size[0]}x{size[1]} -> {SIDE}x{SIDE}")


if __name__ == "__main__":
    main()
