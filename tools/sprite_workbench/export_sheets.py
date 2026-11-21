import json
import re
from PIL import Image

# Read tarek_base_pixels.js
with open('tools/sprite_workbench/tarek_base_pixels.js', 'r', encoding='utf-8') as f:
    text = f.read()

json_str = text[text.find('{'):text.rfind('}')+1]
specs = json.loads(json_str)

W = 32
H = 40

C = {
    "OUT": "#141518",
    "SPEC": "#686140",
    "OLV_L": "#565a3a",
    "OLV_M": "#515237",
    "OLV_D": "#494c33",
    "SKIN_L": "#976f50",
    "SKIN_D": "#6a503c",
    "GUN_L": "#38404c",
    "GUN_M": "#242a33",
    "GUN_D": "#141518",
    "FL_Y": "#ffe066",
    "FL_O": "#ff922b",
}

def make_blank():
    return [["" for _ in range(W)] for _ in range(H)]

def clone_grid(g):
    return [row[:] for row in g]

def put_pts(g, pts):
    for x, y, col in pts:
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = col
    return g

def make_armless_base(grid, d, cr):
    g = clone_grid(grid)
    def clear_rect(x0, x1, y0, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= y < H and 0 <= x < W:
                    g[y][x] = ""
    def seal_col(x, y0, y1, col=C["OUT"]):
        for y in range(y0, y1 + 1):
            if 0 <= y < H and 0 <= x < W and not g[y][x]:
                g[y][x] = col

    if not cr and d == "down":
        clear_rect(7, 10, 19, 27)
        clear_rect(21, 24, 19, 27)
        seal_col(11, 20, 27, C["OUT"])
        seal_col(20, 20, 27, C["OUT"])
    elif not cr and d == "side":
        # Erase ALL ghost arm and hand pixels behind the back and hip (x=8..12, y=19..26)
        clear_rect(8, 12, 19, 26)
        # Erase front dangling hand
        clear_rect(20, 22, 20, 27)
        # Seal back contour with clean dark outline
        seal_col(13, 19, 26, C["OUT"])
    elif not cr and d == "up":
        clear_rect(7, 11, 18, 27)
        clear_rect(21, 24, 18, 27)
        seal_col(12, 19, 27, C["OUT"])
        seal_col(20, 19, 27, C["OUT"])
    elif cr and d == "down":
        clear_rect(7, 10, 23, 31)
        clear_rect(21, 24, 23, 31)
        seal_col(11, 24, 30, C["OUT"])
        seal_col(20, 24, 30, C["OUT"])
    elif cr and d == "side":
        clear_rect(8, 12, 24, 31)
        clear_rect(19, 22, 25, 31)
        seal_col(13, 24, 31, C["OUT"])
    elif cr and d == "up":
        clear_rect(7, 10, 22, 30)
        clear_rect(21, 24, 22, 30)
        seal_col(11, 23, 29, C["OUT"])
        seal_col(20, 23, 29, C["OUT"])
    return g

def side_arm(sy, flash=0, recoil=0):
    g = make_blank()
    rx = -1 if recoil else 0
    pts = [
        # Pistol
        [21 + rx, sy - 3, C["OUT"]], [22 + rx, sy - 3, C["OUT"]], [23 + rx, sy - 3, C["OUT"]], [24 + rx, sy - 3, C["OUT"]], [25 + rx, sy - 3, C["OUT"]],
        [21 + rx, sy - 2, C["GUN_M"]], [22 + rx, sy - 2, C["GUN_L"]], [23 + rx, sy - 2, C["GUN_L"]], [24 + rx, sy - 2, C["GUN_L"]], [25 + rx, sy - 2, C["GUN_M"]],
        [26 + rx, sy - 2, C["OUT"]],
        [21 + rx, sy - 1, C["GUN_L"]], [22 + rx, sy - 1, C["GUN_M"]], [23 + rx, sy - 1, C["OUT"]], [24 + rx, sy - 1, C["OUT"]], [25 + rx, sy - 1, C["OUT"]],
        # Lead arm & hand
        [18, sy - 1, C["OLV_L"]], [19, sy - 1, C["OLV_L"]],
        [18, sy, C["OLV_M"]], [19, sy, C["OLV_D"]],
        [20, sy - 1, C["OUT"]],
        [20, sy, C["SKIN_L"]], [21, sy, C["SKIN_L"]], [22, sy, C["SKIN_D"]],
        [23, sy, C["OUT"]],
        # Support arm
        [12, sy - 1, C["OUT"]], [13, sy - 1, C["SPEC"]],
        [12, sy, C["OUT"]], [13, sy, C["OLV_D"]],
        [14, sy, C["OLV_L"]], [15, sy, C["OLV_M"]], [16, sy, C["OLV_M"]], [17, sy, C["OUT"]],
        [16, sy + 1, C["OUT"]], [17, sy + 1, C["OLV_L"]], [18, sy + 1, C["OLV_L"]], [19, sy + 1, C["OLV_M"]],
        [17, sy + 2, C["OUT"]], [18, sy + 2, C["OUT"]], [19, sy + 2, C["OUT"]],
        # Support hand cupping underneath
        [20, sy + 1, C["SKIN_L"]], [21, sy + 1, C["SKIN_D"]], [22, sy + 1, C["SKIN_D"]], [23, sy + 1, C["OUT"]],
        [21, sy + 2, C["SKIN_L"]], [22, sy + 2, C["OUT"]],
        [20, sy + 2, C["OUT"]], [21, sy + 3, C["OUT"]]
    ]
    if flash == 1:
        pts.extend([
            [26, sy - 2, C["FL_Y"]], [27, sy - 2, C["FL_Y"]], [28, sy - 2, C["FL_O"]],
            [27, sy - 3, C["FL_O"]], [27, sy - 1, C["FL_O"]]
        ])
    return put_pts(g, pts)

def down_arm(sy, flash=0, recoil=0):
    g = make_blank()
    ry = -1 if recoil else 0
    pts = [
        [9, sy - 2, C["OUT"]], [10, sy - 2, C["SPEC"]], [11, sy - 2, C["OUT"]],
        [10, sy - 1, C["OUT"]], [11, sy - 1, C["OLV_L"]], [12, sy - 1, C["OLV_M"]], [13, sy - 1, C["OUT"]],
        [12, sy, C["OUT"]], [13, sy, C["OLV_D"]],
        [20, sy - 2, C["OUT"]], [21, sy - 2, C["SPEC"]], [22, sy - 2, C["OUT"]],
        [18, sy - 1, C["OUT"]], [19, sy - 1, C["OLV_M"]], [20, sy - 1, C["OLV_L"]], [21, sy - 1, C["OUT"]],
        [18, sy, C["OLV_D"]], [19, sy, C["OUT"]],
        # Hands
        [14, sy - 1, C["OUT"]], [15, sy - 1, C["OUT"]], [16, sy - 1, C["OUT"]], [17, sy - 1, C["OUT"]],
        [14, sy, C["SKIN_L"]], [15, sy, C["SKIN_L"]], [16, sy, C["SKIN_L"]], [17, sy, C["SKIN_L"]],
        [14, sy + 1, C["SKIN_D"]], [15, sy + 1, C["SKIN_L"]], [16, sy + 1, C["SKIN_L"]], [17, sy + 1, C["SKIN_D"]],
        # Vertical barrel
        [14, sy + 2 + ry, C["OUT"]], [15, sy + 2 + ry, C["GUN_L"]], [16, sy + 2 + ry, C["GUN_M"]], [17, sy + 2 + ry, C["OUT"]],
        [14, sy + 3 + ry, C["OUT"]], [15, sy + 3 + ry, C["GUN_M"]], [16, sy + 3 + ry, C["GUN_D"]], [17, sy + 3 + ry, C["OUT"]],
        [15, sy + 4 + ry, C["OUT"]], [16, sy + 4 + ry, C["GUN_D"]]
    ]
    if flash == 1:
        pts.extend([
            [16, sy + 5, C["FL_Y"]], [15, sy + 5, C["FL_O"]], [17, sy + 5, C["FL_O"]],
            [16, sy + 6, C["FL_Y"]], [16, sy + 7, C["FL_O"]]
        ])
    return put_pts(g, pts)

def up_arm(sy, flash=0, recoil=0):
    g = make_blank()
    ry = 1 if recoil else 0
    pts = [
        [10, sy - 2, C["OUT"]], [11, sy - 2, C["SPEC"]],
        [9, sy - 1, C["OUT"]], [10, sy - 1, C["OLV_L"]], [11, sy - 1, C["OLV_M"]], [12, sy - 1, C["OUT"]],
        [10, sy, C["OUT"]], [11, sy, C["OLV_D"]], [12, sy, C["OUT"]],
        [12, sy - 2, C["OLV_L"]], [13, sy - 2, C["OLV_M"]], [13, sy - 3, C["OLV_L"]], [14, sy - 3, C["OLV_M"]],
        [20, sy - 2, C["SPEC"]], [21, sy - 2, C["OUT"]],
        [19, sy - 1, C["OUT"]], [20, sy - 1, C["OLV_M"]], [21, sy - 1, C["OLV_L"]], [22, sy - 1, C["OUT"]],
        [19, sy, C["OUT"]], [20, sy, C["OLV_D"]], [21, sy, C["OUT"]],
        [19, sy - 2, C["OLV_L"]], [18, sy - 2, C["OLV_M"]], [18, sy - 3, C["OLV_L"]], [17, sy - 3, C["OLV_M"]],
        # Hands & single barrel
        [15, sy - 3, C["SKIN_D"]], [16, sy - 3, C["SKIN_D"]],
        [14, sy - 4 + ry, C["OUT"]], [15, sy - 4 + ry, C["GUN_M"]], [16, sy - 4 + ry, C["GUN_L"]], [17, sy - 4 + ry, C["OUT"]],
        [14, sy - 5 + ry, C["OUT"]], [15, sy - 5 + ry, C["GUN_M"]], [16, sy - 5 + ry, C["GUN_D"]], [17, sy - 5 + ry, C["OUT"]],
        [15, sy - 6 + ry, C["OUT"]], [16, sy - 6 + ry, C["GUN_D"]]
    ]
    if flash == 1:
        pts.extend([
            [16, sy - 6, C["FL_Y"]], [15, sy - 6, C["FL_O"]], [17, sy - 6, C["FL_O"]],
            [16, sy - 7, C["FL_Y"]], [16, sy - 8, C["FL_O"]]
        ])
    return put_pts(g, pts)

def reload_side(sy):
    g = make_blank()
    pts = [
        [12, sy - 1, C["OUT"]], [13, sy - 1, C["SPEC"]],
        [14, sy, C["OLV_L"]], [15, sy, C["OLV_M"]], [16, sy + 1, C["OLV_D"]],
        [18, sy, C["SKIN_L"]], [19, sy, C["SKIN_L"]], [20, sy - 1, C["GUN_L"]], [21, sy - 2, C["GUN_M"]],
        [19, sy + 1, C["SKIN_D"]], [20, sy + 1, C["GUN_D"]], [20, sy + 2, C["GUN_D"]],
    ]
    return put_pts(g, pts)

overlays = {
    "aim_idle:side": [side_arm(19)],
    "aim_idle:down": [down_arm(19)],
    "aim_idle:up": [up_arm(19)],
    "aim_walk:side": [side_arm(19 + (i % 2)) for i in range(5)],
    "aim_walk:down": [down_arm(19 + (i % 2)) for i in range(4)],
    "aim_walk:up": [up_arm(19 + (i % 2)) for i in range(4)],
    "shoot:side": [side_arm(19, 1, 0), side_arm(19, 0, 1)],
    "shoot:down": [down_arm(19, 1, 0), down_arm(19, 0, 1)],
    "shoot:up": [up_arm(19, 1, 0), up_arm(19, 0, 1)],
    "reload:side": [side_arm(19), reload_side(19), reload_side(20), side_arm(19)],
    "reload:down": [down_arm(19), down_arm(20), down_arm(19)],
    "reload:up": [up_arm(19), up_arm(20), up_arm(19)],
    "crouch_aim:side": [side_arm(24)],
    "crouch_aim:down": [down_arm(24)],
    "crouch_aim:up": [up_arm(24)],
    "crouch_shoot:side": [side_arm(24, 1, 0), side_arm(24, 0, 1)],
    "crouch_shoot:down": [down_arm(24, 1, 0), down_arm(24, 0, 1)],
    "crouch_shoot:up": [up_arm(24, 1, 0), up_arm(24, 0, 1)],
}

def hex_to_rgba(hex_str):
    if not hex_str:
        return (0, 0, 0, 0)
    h = hex_str.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

# Export Full Sheet (18 rows, max 5 cols)
rows = list(overlays.keys())
max_cols = max(len(overlays[k]) for k in rows)
sheet_im = Image.new('RGBA', (max_cols * W, len(rows) * H), (0, 0, 0, 0))

for r, k in enumerate(rows):
    anim, d = k.split(':')
    cr = anim.startswith('crouch_')
    for col_idx, ov in enumerate(overlays[k]):
        if anim == "aim_walk":
            walk_key = f"walk_{d}"
            walk_list = specs['walk_frames_rgba_hex'][walk_key]
            raw_base = walk_list[col_idx % len(walk_list)]
        else:
            base_key = f"{'crouch' if cr else 'stand'}_{d}"
            raw_base = specs['base_frames_rgba_hex'][base_key]
        
        base = make_armless_base(raw_base, d, cr)
        # Composite base, then overlay
        cell_im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        for y in range(H):
            for x in range(W):
                c = base[y][x]
                if c:
                    cell_im.putpixel((x, y), hex_to_rgba(c))
                ov_c = ov[y][x]
                if ov_c:
                    cell_im.putpixel((x, y), hex_to_rgba(ov_c))
        
        sheet_im.paste(cell_im, (col_idx * W, r * H), cell_im)

sheet_im.save('tools/sprite_workbench/tarek_32x40_sheet.png')
print(f"Exported tools/sprite_workbench/tarek_32x40_sheet.png ({sheet_im.size[0]}x{sheet_im.size[1]})")

# Export tarek_pistol_arms.png (72x20: side, down, up centered on shoulder)
arms_im = Image.new('RGBA', (72, 20), (0, 0, 0, 0))
sh = specs['gun_and_muzzle_offsets']['pivot_origin_sprite_px']['standing_shoulder']
sx0, sy0 = round(sh[0]), round(sh[1])

for idx, d in enumerate(["side", "down", "up"]):
    grid = overlays[f"aim_idle:{d}"][0]
    for y in range(H):
        for x in range(W):
            col = grid[y][x]
            if not col:
                continue
            tx = idx * 24 + 12 + (x - sx0)
            ty = 10 + (y - sy0)
            if idx * 24 <= tx < (idx + 1) * 24 and 0 <= ty < 20:
                arms_im.putpixel((tx, ty), hex_to_rgba(col))

arms_im.save('assets/sprites/tarek/tarek_pistol_arms.png')
arms_im.save('tools/sprite_workbench/tarek_pistol_arms.png')
print("Exported tarek_pistol_arms.png (72x20)")
