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
## Already correctly named, but dropped at a portrait size the square rect
## would squash.
RESQUARE = ["old_talisman"]


def to_square(image: Image.Image) -> Image.Image:
    """Trim to the subject, then centre it on a transparent square."""
    image = image.convert("RGBA")
    box = image.getbbox()
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
            print(f"  skip {drop_name}: not here")
            continue
        source = Image.open(drop)
        size = source.size
        to_square(source).save(ICONS / f"{weapon_id}.png")
        source.close()
        print(f"  {drop_name} {size[0]}x{size[1]} -> {weapon_id}.png {SIDE}x{SIDE}")
        drop.replace(KEEP / drop.name)
        sidecar = ICONS / f"{drop_name}.png.import"
        if sidecar.exists():
            sidecar.unlink()  # Godot re-imports by filename; a stale one is noise
    for weapon_id in RESQUARE:
        path = ICONS / f"{weapon_id}.png"
        if not path.exists():
            continue
        source = Image.open(path)
        size = source.size
        if size[0] == size[1] == SIDE:
            source.close()
            print(f"  {weapon_id}: already {SIDE}x{SIDE}")
            continue
        squared = to_square(source)
        source.close()
        squared.save(path)
        print(f"  {weapon_id} {size[0]}x{size[1]} -> {SIDE}x{SIDE}")


if __name__ == "__main__":
    main()
