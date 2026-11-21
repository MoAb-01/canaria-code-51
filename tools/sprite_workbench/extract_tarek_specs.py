import json
import os
import re
from collections import Counter
from PIL import Image

ROOT = r"c:\Users\UHD\Documents\my-test-game"
SHEET_PATH = os.path.join(ROOT, "assets", "sprites", "tarek", "tarek_spritesheet.png")
TSCN_PATH = os.path.join(ROOT, "entities", "player", "tarek.tscn")
TAREK_GD_PATH = os.path.join(ROOT, "entities", "player", "tarek.gd")
WEAPON_GD_PATH = os.path.join(ROOT, "components", "weapon_component.gd")
OUT_DIR = os.path.join(ROOT, "tools", "sprite_workbench")
OUT_JS = os.path.join(OUT_DIR, "tarek_base_pixels.js")

os.makedirs(OUT_DIR, exist_ok=True)

sheet = Image.open(SHEET_PATH).convert("RGBA")

# 1. Extract frame specs & animation names + FPS from tarek.tscn
with open(TSCN_PATH, "r", encoding="utf-8") as f:
    tscn = f.read()

anim_entries = []
for m in re.finditer(
    r'\{\s*"frames":\s*\[(.*?)\],\s*"loop":\s*(true|false),\s*"name":\s*&"([^"]+)",\s*"speed":\s*([0-9.]+)\s*\}',
    tscn,
    re.DOTALL,
):
    frames_raw, loop_str, name, speed_str = m.groups()
    frame_count = len(re.findall(r'"texture":', frames_raw))
    anim_entries.append({
        "name": name,
        "fps": float(speed_str),
        "loop": (loop_str == "true"),
        "frames": frame_count,
    })

with open(TAREK_GD_PATH, "r", encoding="utf-8") as f:
    tarek_gd = f.read()
with open(WEAPON_GD_PATH, "r", encoding="utf-8") as f:
    weapon_gd = f.read()

# 2. Extract exact 32x40 RGBA hex matrices for standing & crouching base frames
frame_coords = {
    "stand_down":  (0, 120, 32, 40),
    "stand_side":  (0, 160, 32, 40),
    "stand_up":    (0, 200, 32, 40),
    "crouch_down": (0, 240, 32, 40),
    "crouch_side": (0, 320, 32, 40),
    "crouch_up":   (0, 400, 32, 40),
}

def to_hex_rgba(p):
    r, g, b, a = p
    if a == 0:
        return ""
    return f"#{r:02x}{g:02x}{b:02x}{a:02x}" if a < 255 else f"#{r:02x}{g:02x}{b:02x}"

frames_hex = {}
palette_counts = Counter()
foot_baselines = {}

for key, (x0, y0, w, h) in frame_coords.items():
    crop = sheet.crop((x0, y0, x0 + w, y0 + h))
    rows = []
    max_y = 0
    for y in range(h):
        row = []
        for x in range(w):
            p = crop.getpixel((x, y))
            hx = to_hex_rgba(p)
            row.append(hx)
            if p[3] > 0:
                if y > max_y:
                    max_y = y
                palette_counts[f"#{p[0]:02x}{p[1]:02x}{p[2]:02x}"] += 1
        rows.append(row)
    frames_hex[key] = rows
    foot_baselines[key] = max_y

walk_coords = {
    "walk_down":        (0,   4, 32, 40),
    "walk_side":        (40,  5, 32, 40),
    "walk_up":          (80,  4, 32, 40),
    "crouch_walk_down": (280, 2, 32, 40),
    "crouch_walk_side": (360, 4, 32, 40),
    "crouch_walk_up":   (440, 2, 32, 40),
}
walk_frames_hex = {}
for wkey, (wy, count, ww, wh) in walk_coords.items():
    seq = []
    for c in range(count):
        crop = sheet.crop((c * ww, wy, c * ww + ww, wy + wh))
        seq.append([[to_hex_rgba(crop.getpixel((x, y))) for x in range(ww)] for y in range(wh)])
    walk_frames_hex[wkey] = seq

# Categorize palette colors
def classify_hex(hx):
    r, g, b = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
    if r <= 36 and g <= 36 and b <= 40:
        return "hair_outline"
    if r >= 100 and g >= 75 and b >= 55 and r > g > b:
        return "skin"
    if g >= r and g > b and r >= 65:
        return "olive_jacket"
    if r > g and g >= b and r >= 55:
        return "harness_belt"
    return "pants_boots"

categorized_palette = {
    "all_by_frequency": [{"hex": hx, "count": cnt} for hx, cnt in palette_counts.most_common()],
    "skin": [],
    "hair_outline": [],
    "olive_jacket": [],
    "harness_belt": [],
    "pants_boots": [],
}
for hx, cnt in palette_counts.most_common():
    categorized_palette[classify_hex(hx)].append(hx)

# 3. Extract WeaponComponent offsets & compute sprite-space pixel coords
def parse_vec2(src, var_name):
    m = re.search(rf'@export var {var_name}:\s*Vector2\s*=\s*Vector2\(\s*([^,]+),\s*([^)]+)\)', src)
    return [float(m.group(1)), float(m.group(2))] if m else None

shoulder_off = parse_vec2(weapon_gd, "shoulder_offset")
crouch_off = parse_vec2(weapon_gd, "crouch_shoulder_offset")
peek_off = parse_vec2(weapon_gd, "peek_shoulder_offset")
muzzle_def = parse_vec2(weapon_gd, "muzzle_local_pos")

# Convert player-local offset (pos=(0,-14), scale=(3,3), sprite offset=(0,-15), frame 32x40)
# player_x = 3 * (px - 16), player_y = -14 + 3 * (py - 35)
def player_to_sprite_px(vx, vy):
    return [round(vx / 3.0 + 16.0, 2), round((vy + 14.0) / 3.0 + 35.0, 2)]

gun_muzzle_specs = {
    "sprite_transform": {
        "node_position": [0, -14],
        "scale": [3, 3],
        "sprite_offset": [0, -15],
        "frame_center_px": [16, 20],
    },
    "weapon_component_exports_local": {
        "shoulder_offset": shoulder_off,
        "crouch_shoulder_offset": crouch_off,
        "peek_shoulder_offset": peek_off,
        "muzzle_local_pos_default": muzzle_def,
    },
    "pivot_origin_sprite_px": {
        "standing_shoulder": player_to_sprite_px(*shoulder_off),
        "crouching_shoulder": player_to_sprite_px(*crouch_off),
        "peeking_shoulder": player_to_sprite_px(*peek_off),
    },
    "muzzle_point_by_direction": {
        "side_right": {
            "pivot_local": [33, 0],
            "standing_player_local": [shoulder_off[0] + 33, shoulder_off[1]],
            "standing_sprite_px": player_to_sprite_px(shoulder_off[0] + 33, shoulder_off[1]),
            "crouching_player_local": [crouch_off[0] + 33, crouch_off[1]],
            "crouching_sprite_px": player_to_sprite_px(crouch_off[0] + 33, crouch_off[1]),
        },
        "side_left_flip_h": {
            "pivot_local_rotated": [-33, 0],
            "standing_player_local": [shoulder_off[0] - 33, shoulder_off[1]],
            "standing_sprite_px": player_to_sprite_px(shoulder_off[0] - 33, shoulder_off[1]),
            "crouching_player_local": [crouch_off[0] - 33, crouch_off[1]],
            "crouching_sprite_px": player_to_sprite_px(crouch_off[0] - 33, crouch_off[1]),
        },
        "down": {
            "pivot_local": [0, 18],
            "standing_player_local": [shoulder_off[0], shoulder_off[1] + 18],
            "standing_sprite_px": player_to_sprite_px(shoulder_off[0], shoulder_off[1] + 18),
            "crouching_player_local": [crouch_off[0], crouch_off[1] + 18],
            "crouching_sprite_px": player_to_sprite_px(crouch_off[0], crouch_off[1] + 18),
        },
        "up": {
            "pivot_local": [0, -18],
            "standing_player_local": [shoulder_off[0], shoulder_off[1] - 18],
            "standing_sprite_px": player_to_sprite_px(shoulder_off[0], shoulder_off[1] - 18),
            "crouching_player_local": [crouch_off[0], crouch_off[1] - 18],
            "crouching_sprite_px": player_to_sprite_px(crouch_off[0], crouch_off[1] - 18),
        },
    },
}

data = {
    "grid_and_anchor": {
        "cell_width": 32,
        "cell_height": 40,
        "sheet_size": [sheet.width, sheet.height],
        "foot_baseline_y_by_frame": foot_baselines,
        "foot_baseline_y": 39,
        "foot_baseline_player_local_y": -14 + 3 * (39 - 35),
        "tarek_gd_expected_prefixes": [
            "idle_", "walk_", "crouch_idle_", "crouch_walk_", "jump_",
            "flashlight_idle_", "flashlight_walk_", "flashlight_crouch_",
            "grab_still_", "push_", "pull_", "punch_", "defend_", "damaged_idle_",
        ],
        "weapon_component_expected_prefixes": [
            "idle_", "walk_", "crouch_idle_", "crouch_walk_", "peek_shoot_",
        ],
        "tarek_tscn_animations": anim_entries,
    },
    "palette": categorized_palette,
    "gun_and_muzzle_offsets": gun_muzzle_specs,
    "base_frames_rgba_hex": frames_hex,
    "walk_frames_rgba_hex": walk_frames_hex,
}

with open(OUT_JS, "w", encoding="utf-8") as f:
    f.write("// Auto-generated by tools/sprite_workbench/extract_tarek_specs.py\n")
    f.write("const TAREK_BASE_SPECS = ")
    json.dump(data, f, indent=2)
    f.write(";\nglobalThis.TAREK_BASE_SPECS = TAREK_BASE_SPECS;\n")

print(f"Wrote {OUT_JS}")
print(f"Cell: 32x40, foot_baseline_y: 39, animations: {len(anim_entries)}, palette colors: {len(palette_counts)}")
