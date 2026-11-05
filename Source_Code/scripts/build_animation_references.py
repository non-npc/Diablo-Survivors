"""Export original walking/attacking frames for hand-marked compositing masks."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "animation_references"
DIRECTIONS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]

def build():
    OUTPUT.mkdir(exist_ok=True)
    manifests = {"d1": ROOT / ".local/demo/survival.json",
                 "d2": Path(json.loads((ROOT / ".local/diablo2/active.json").read_text())["manifest_path"])}
    index = {}
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)
    for game, path in manifests.items():
        manifest = json.loads(path.read_text())
        for character, visual in manifest["class_visuals"].items():
            sheet = Image.new("RGB", (1400, 1510), "#202630")
            draw = ImageDraw.Draw(sheet)
            draw.text((20, 12), f"{game.upper()} / {character} - mark torso/leg boundaries in RED on both frames", font=font, fill="white")
            records = []
            for direction, name in enumerate(DIRECTIONS):
                group_x, group_y = (direction % 2) * 700, 60 + (direction // 2) * 360
                for column, state in enumerate(["attack", "walk"]):
                    clip = visual["clips"][state]
                    count = clip["frames_per_direction"][direction]
                    frame = count // 2 if state == "attack" else count // 4
                    width, height = clip["frame_width"], clip["frame_height"]
                    anchor = clip.get("anchor", [width / 2, height])
                    with Image.open(clip["sheet"]) as source:
                        sprite = source.convert("RGBA").crop((frame*width, direction*height, (frame+1)*width, (direction+1)*height))
                    # Shared ground anchor preserves the original alignment, without guessing a seam.
                    panel = Image.new("RGBA", (160, 144), "#343c48")
                    px, py = round(80-anchor[0]), round(128-anchor[1])
                    panel.alpha_composite(sprite, (px, py))
                    x, y = group_x+15+column*340, group_y+35
                    sheet.paste(panel.resize((320,288), Image.Resampling.NEAREST).convert("RGB"), (x,y))
                    code = f"{game}-{character}-{name}-{state}"
                    draw.text((x,group_y), f"{name} / {state} / frame {frame}", font=font, fill="white")
                    records.append(dict(code=code, direction_index=direction, state=state, frame=frame,
                                        source=clip["sheet"], anchor=anchor,
                                        panel_origin=[x,y], scale=2, frame_offset=[px,py]))
            filename = f"{game}_{character}.png"
            sheet.save(OUTPUT / filename)
            index[filename] = records
    (OUTPUT / "frame_index.json").write_text(json.dumps(index, indent=2))
    (OUTPUT / "README.md").write_text("# Animation mask references\n\nEach class sheet shows one original attack frame and one walking frame for all eight directions. Mark the torso/leg boundary in red on BOTH images of each pair, keeping the original sheet size. Label any special pieces (robes, shields or weapons) that should stay with the upper body. Frames are enlarged 2x without smoothing; frame_index.json maps your markings back to the original pixels. These are references, not merged animations. A single marked frame gives an initial mask; other poses may need adjustments after testing.\n")
    print(f"Created {len(index)} class sheets in {OUTPUT}")

if __name__ == "__main__":
    build()
