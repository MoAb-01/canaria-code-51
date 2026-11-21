"""
Pixel-perfect processing pipeline for Tarek's 3x4 pistol sprite sheets.
Matches tarek_spritesheet.png (32x40 base cells) in height, pixel density,
outline crispness, foot baseline (bottom_y), and torso X-center alignment.
"""

from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

PROJECT_ROOT = Path(r"c:\Users\UHD\Documents\my-test-game")
BASE_SHEET = PROJECT_ROOT / "assets" / "sprites" / "tarek" / "tarek_spritesheet.png"
OUT_DIR = PROJECT_ROOT / "assets" / "sprites" / "tarek"
ARTIFACT_DIR = Path(r"C:\Users\UHD\.gemini\antigravity\brain\58a3aa24-682d-414b-9ef5-d6cc67268d3d")

INPUT_SHEETS = {
    "tarek_pistol_walk": Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795072482097_f128d2c2.png"),
    "tarek_pistol_shoot": Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795072482114_5757aa22.png"),
    "tarek_pistol_crouch_shoot": Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795072482143_45f2a649.png"),
}

BASE_CELL_W, BASE_CELL_H = 32, 40
OUT_CELL_W, OUT_CELL_H = 48, 40  # Padded width centered on torso anchor (x=24 == x=16 in 32x40)


def measure_ground_truth(sheet_path: Path) -> dict:
    img = Image.open(sheet_path).convert("RGBA")
    arr = np.array(img)

    def cell_metrics(row: int, col: int):
        cell = arr[row * BASE_CELL_H:(row + 1) * BASE_CELL_H,
                   col * BASE_CELL_W:(col + 1) * BASE_CELL_W]
        ys, xs = np.where(cell[:, :, 3] > 10)
        top_y, bot_y = int(ys.min()), int(ys.max())
        return {
            "top_y": top_y,
            "bottom_y": bot_y,
            "height": bot_y - top_y + 1,
            "cx": float(xs.mean()),
            "img": Image.fromarray(cell, "RGBA"),
        }

    stand_down = cell_metrics(3, 0)
    stand_side = cell_metrics(4, 0)
    stand_up = cell_metrics(5, 0)
    crouch_down = cell_metrics(6, 0)
    crouch_side = cell_metrics(8, 0)
    crouch_up = cell_metrics(10, 0)

    gt = {
        "base_cell": (BASE_CELL_W, BASE_CELL_H),
        "stand_height": stand_down["height"],
        "stand_bottom_y": stand_down["bottom_y"],
        "crouch_height": crouch_down["height"],
        "crouch_bottom_y": crouch_down["bottom_y"],
        "base_cx_offset": stand_down["cx"] - (BASE_CELL_W / 2.0),
        "refs": {
            "stand_down": stand_down,
            "stand_side": stand_side,
            "stand_up": stand_up,
            "crouch_down": crouch_down,
            "crouch_side": crouch_side,
            "crouch_up": crouch_up,
        },
    }
    print(
        f"[Ground Truth] Base cell={gt['base_cell']}, "
        f"Stand h={gt['stand_height']} bottom_y={gt['stand_bottom_y']}, "
        f"Crouch h={gt['crouch_height']} bottom_y={gt['crouch_bottom_y']}, "
        f"base_cx_offset={gt['base_cx_offset']:.2f}"
    )
    return gt


def _adj_mask(mask: np.ndarray) -> np.ndarray:
    adj = np.zeros_like(mask, dtype=bool)
    adj[1:, :] |= mask[:-1, :]
    adj[:-1, :] |= mask[1:, :]
    adj[:, 1:] |= mask[:, :-1]
    adj[:, :-1] |= mask[:, 1:]
    return adj


def remove_bg_and_decontaminate(rgba_in: np.ndarray, has_fx: bool = True) -> np.ndarray:
    """
    Background removal for black-background or pre-transparent RGBA sheets:
    - If the source already has transparent borders (RGBA PNG with alpha==0), harden
      semi-transparent edges (alpha < 128 -> 0, else 255) without touching Tarek's black outline/hair.
    - Otherwise (opaque black background), key out strictly via outside-border flood-fill
      with threshold (R < 20 and G < 20 and B < 20) — never globally replacing black.
    """
    out = rgba_in.copy()
    h, w, _ = out.shape
    a = out[:, :, 3]

    border_alpha = np.concatenate([a[0, :], a[-1, :], a[:, 0], a[:, -1]])
    has_transparent_border = bool((border_alpha < 128).mean() > 0.5)

    if has_transparent_border:
        # Harden semi-transparent edge pixels to crisp 1-bit pixel-art alpha
        out[:, :, 3] = np.where(a >= 128, 255, 0).astype(np.uint8)
        return out

    # Strictly outside-border flood-fill for solid black background (R<20, G<20, B<20)
    r, g, b = out[:, :, 0], out[:, :, 1], out[:, :, 2]
    is_black_bg = (r < 20) & (g < 20) & (b < 20)

    bg = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if is_black_bg[0, x] and not bg[0, x]:
            bg[0, x] = True; q.append((0, x))
        if is_black_bg[h - 1, x] and not bg[h - 1, x]:
            bg[h - 1, x] = True; q.append((h - 1, x))
    for y in range(h):
        if is_black_bg[y, 0] and not bg[y, 0]:
            bg[y, 0] = True; q.append((y, 0))
        if is_black_bg[y, w - 1] and not bg[y, w - 1]:
            bg[y, w - 1] = True; q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and is_black_bg[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    out[:, :, 3] = np.where(bg, 0, 255).astype(np.uint8)
    return out


def drop_tiny_islands(rgba: np.ndarray, min_pixels: int = 4) -> np.ndarray:
    """Remove disconnected tiny islands smaller than min_pixels."""
    out = rgba.copy()
    h, w = out.shape[:2]
    fg = out[:, :, 3] > 0
    visited = np.zeros((h, w), dtype=bool)
    ys, xs = np.where(fg)
    for sy, sx in zip(ys, xs):
        if visited[sy, sx]:
            continue
        comp = []
        q = deque([(sy, sx)])
        visited[sy, sx] = True
        while q:
            cy, cx = q.popleft()
            comp.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and fg[ny, nx]:
                        visited[ny, nx] = True
                        q.append((ny, nx))
        if len(comp) < min_pixels:
            for cy, cx in comp:
                out[cy, cx, 3] = 0
    return out


def find_runs(mask_1d: np.ndarray, min_gap: int) -> list[tuple[int, int]]:
    runs = []
    in_run = False
    start = 0
    for i, val in enumerate(mask_1d):
        if val and not in_run:
            in_run = True; start = i
        elif not val and in_run:
            in_run = False; runs.append([start, i - 1])
    if in_run:
        runs.append([start, len(mask_1d) - 1])
    merged = []
    for run in runs:
        if merged and run[0] - merged[-1][1] < min_gap:
            merged[-1][1] = run[1]
        else:
            merged.append(run)
    return [(a, b) for a, b in merged]


def segment_3x4_midpoint_isolated(rgb: np.ndarray, has_fx: bool = True) -> list[list[np.ndarray]]:
    """
    1. Locate the 3 row bands and 4 column bands via projection on the cleaned sheet.
    2. Compute strict midpoint boundaries between neighboring rows/columns so
       muzzle-flash or stray pixels from adjacent cells can NEVER bleed across.
    3. Re-run background removal + decontamination + tiny-island pruning per isolated cell.
    """
    full_rgba = remove_bg_and_decontaminate(rgb, has_fx=has_fx)
    fg = full_rgba[:, :, 3] > 0
    h, w = rgb.shape[:2]

    row_bands = find_runs(fg.any(axis=1), min_gap=15)
    assert len(row_bands) == 3, f"Expected 3 rows, got {len(row_bands)}: {row_bands}"

    row_cuts = [0]
    for i in range(2):
        row_cuts.append((row_bands[i][1] + row_bands[i + 1][0]) // 2)
    row_cuts.append(h)

    grid = []
    for r in range(3):
        ry0, ry1 = row_cuts[r], row_cuts[r + 1]
        band_fg = fg[ry0:ry1, :]
        col_bands = find_runs(band_fg.any(axis=0), min_gap=20)
        assert len(col_bands) == 4, f"Expected 4 cols in row {r}, got {len(col_bands)}"

        col_cuts = [0]
        for i in range(3):
            col_cuts.append((col_bands[i][1] + col_bands[i + 1][0]) // 2)
        col_cuts.append(w)

        row_sprites = []
        for c in range(4):
            cx0, cx1 = col_cuts[c], col_cuts[c + 1]
            cell_rgb = rgb[ry0:ry1, cx0:cx1, :]
            cell_has_fx = has_fx and (c in (1, 2))
            cell_rgba = remove_bg_and_decontaminate(cell_rgb, has_fx=cell_has_fx)
            # In high-res space (~6.5x), drop any disconnected tiny stray island (< 16 raw px)
            cell_rgba = drop_tiny_islands(cell_rgba, min_pixels=16)

            ys, xs = np.where(cell_rgba[:, :, 3] > 0)
            tight = cell_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1, :].copy()
            row_sprites.append(tight)
        grid.append(row_sprites)
    return grid


def body_mask_no_fx(rgba: np.ndarray) -> np.ndarray:
    """Return boolean mask of Tarek's body excluding muzzle flash and smoke pixels."""
    a = rgba[:, :, 3] > 0
    r = rgba[:, :, 0].astype(np.int16)
    g = rgba[:, :, 1].astype(np.int16)
    b = rgba[:, :, 2].astype(np.int16)
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    sat = max_c - min_c
    luma = (0.299 * r + 0.587 * g + 0.114 * b)

    is_flash = a & (r > 180) & (g > 110) & ((r - b) > 35)
    is_flash_core = a & (min_c > 210)
    is_smoke = a & (sat < 22) & (luma > 105)
    return a & (~is_flash) & (~is_flash_core) & (~is_smoke)


def compute_torso_cx(rgba: np.ndarray, row_idx: int) -> float:
    """Anchor X-center on Tarek's head/torso/legs core (excluding arms, flash, smoke)."""
    body = body_mask_no_fx(rgba)
    ys, xs = np.where(body)
    if len(xs) == 0:
        return rgba.shape[1] / 2.0

    top_y, bot_y = int(ys.min()), int(ys.max())
    h = bot_y - top_y + 1

    if row_idx == 1:
        core_mask = (ys <= top_y + int(h * 0.36)) | (ys >= top_y + int(h * 0.68))
        core_xs = xs[core_mask]
        if len(core_xs) > 0:
            return float(core_xs.mean())
    elif row_idx == 2:
        core_mask = (ys <= top_y + int(h * 0.36)) | (ys >= top_y + int(h * 0.55))
        core_xs = xs[core_mask]
        if len(core_xs) > 0:
            return float(core_xs.mean())

    return float(xs.mean())


def clean_downsampled_cell(rgba: np.ndarray, allow_smoke: bool, allow_flash: bool) -> np.ndarray:
    """
    Final post-downsample cleanup on the 1x pixel-art sprite:
    - Strip any outer-edge low-saturation light-grey/off-white pixel bordering alpha==0
      (preserving disconnected smoke puffs on Frame 2).
    - Drop any disconnected stray island < 4 px that is not a legitimate smoke/flash cluster.
    """
    out = rgba.copy()
    h, w, _ = out.shape

    # Identify connected components so we can distinguish main body from disconnected smoke/flash
    fg = out[:, :, 3] > 0
    comp_id = np.full((h, w), -1, dtype=np.int32)
    comps = []
    cid = 0
    ys, xs = np.where(fg)
    for sy, sx in zip(ys, xs):
        if comp_id[sy, sx] != -1:
            continue
        pixels = []
        q = deque([(sy, sx)])
        comp_id[sy, sx] = cid
        while q:
            cy, cx = q.popleft()
            pixels.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and comp_id[ny, nx] == -1 and fg[ny, nx]:
                        comp_id[ny, nx] = cid
                        q.append((ny, nx))
        comps.append(pixels)
        cid += 1

    if not comps:
        return out

    main_cid = max(range(len(comps)), key=lambda i: len(comps[i]))

    # Drop tiny disconnected stray islands (< 4 px) unless they are valid muzzle flash / smoke on FX frames
    for i, pixels in enumerate(comps):
        if i == main_cid:
            continue
        if len(pixels) < 4:
            pts = np.array(pixels)
            cols = out[pts[:, 0], pts[:, 1], :3].astype(np.int16)
            is_warm_flash = allow_flash and bool(((cols[:, 0] > 180) & (cols[:, 1] > 110) & ((cols[:, 0] - cols[:, 2]) > 35)).any())
            is_mid_smoke = allow_smoke and bool(((cols.max(axis=1) - cols.min(axis=1) < 25) & (cols.mean(axis=1) > 105) & (cols.mean(axis=1) < 190)).any())
            if not (is_warm_flash or is_mid_smoke):
                for cy, cx in pixels:
                    out[cy, cx, 3] = 0

    # Strip any remaining bright/mid-grey low-saturation outer-edge JPEG halo on the main body.
    # Tarek's outer silhouette is strictly a 1px black outline (luma < 50) + optional warm flash:
    # 1) Any outer-edge pixel with luma > 135 & sat < 28 is always JPEG halo.
    # 2) Any outer-edge neutral grey pixel (luma > 65 & sat < 18) directly hugging a dark outline
    #    pixel (luma < 50) is a blended black-on-white JPEG rim pixel -> strip it cleanly.
    main_mask = (comp_id == main_cid)
    for _ in range(2):
        alpha = out[:, :, 3] > 0
        adj_bg = _adj_mask(~alpha)
        r = out[:, :, 0].astype(np.int16)
        g = out[:, :, 1].astype(np.int16)
        b = out[:, :, 2].astype(np.int16)
        sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
        luma = 0.299 * r + 0.587 * g + 0.114 * b
        is_dark_outline = alpha & (luma < 50.0)
        adj_dark = _adj_mask(is_dark_outline)
        halo = alpha & main_mask & adj_bg & (
            ((luma > 135.0) & (sat < 28))
            | ((luma > 65.0) & (sat < 18) & adj_dark)
        )
        if not halo.any():
            break
        out[halo, 3] = 0

    return out


def process_sheet(
    name: str,
    src_path: Path,
    scale: float,
    bottom_y: int,
    target_cx: float,
    has_fx: bool,
) -> tuple[Image.Image, list[list[Image.Image]]]:
    rgba = np.array(Image.open(src_path).convert("RGBA"))
    grid = segment_3x4_midpoint_isolated(rgba, has_fx=has_fx)

    sheet = Image.new("RGBA", (OUT_CELL_W * 4, OUT_CELL_H * 3), (0, 0, 0, 0))
    cells = []

    for r in range(3):
        row_cells = []
        for c in range(4):
            raw = grid[r][c]
            raw_h, raw_w = raw.shape[:2]
            new_w = max(1, int(round(raw_w * scale)))
            new_h = max(1, int(round(raw_h * scale)))

            pil_raw = Image.fromarray(raw, "RGBA")
            small = pil_raw.resize((new_w, new_h), Image.Resampling.NEAREST)
            small_arr = clean_downsampled_cell(
                np.array(small),
                allow_smoke=(has_fx and c == 2),
                allow_flash=(has_fx and c == 1),
            )

            body = body_mask_no_fx(small_arr)
            bys, _ = np.where(body)
            feet_y = int(bys.max()) if len(bys) > 0 else int(np.where(small_arr[:, :, 3] > 0)[0].max())
            body_cx = compute_torso_cx(small_arr, r)

            paste_x = int(round(target_cx - body_cx))
            paste_y = int(bottom_y - feet_y)

            ays, axs = np.where(small_arr[:, :, 3] > 0)
            min_ax, max_ax = int(axs.min()), int(axs.max())
            min_ay, max_ay = int(ays.min()), int(ays.max())
            if paste_x + min_ax < 0:
                paste_x = -min_ax
            if paste_x + max_ax >= OUT_CELL_W:
                paste_x = OUT_CELL_W - 1 - max_ax
            if paste_y + min_ay < 0:
                paste_y = -min_ay
            if paste_y + max_ay >= OUT_CELL_H:
                paste_y = OUT_CELL_H - 1 - max_ay

            cell = Image.new("RGBA", (OUT_CELL_W, OUT_CELL_H), (0, 0, 0, 0))
            cell.alpha_composite(Image.fromarray(small_arr, "RGBA"), (paste_x, paste_y))
            sheet.paste(cell, (c * OUT_CELL_W, r * OUT_CELL_H))
            row_cells.append(cell)
        cells.append(row_cells)

    out_path = OUT_DIR / f"{name}.png"
    sheet.save(out_path, "PNG")
    print(f"Saved {out_path} ({sheet.size[0]}x{sheet.size[1]})")
    return sheet, cells


def pad_base_cell(base_32x40: Image.Image) -> Image.Image:
    padded = Image.new("RGBA", (OUT_CELL_W, OUT_CELL_H), (0, 0, 0, 0))
    padded.paste(base_32x40, ((OUT_CELL_W - BASE_CELL_W) // 2, 0))
    return padded


def build_verification_image(gt: dict, processed: dict) -> Path:
    """
    Export a 4x nearest-neighbor zoomed verification image against the dark
    in-game navy background (RGB 25, 32, 43) so outline crispness and zero-halo
    edges are immediately verifiable.
    """
    zoom = 4
    cols = 9
    rows_spec = [
        ("STAND DOWN: Base | Walk Pistol 0-3 | Stand Shoot 0-3",
         [pad_base_cell(gt["refs"]["stand_down"]["img"])]
         + processed["tarek_pistol_walk"][0]
         + processed["tarek_pistol_shoot"][0],
         gt["refs"]["stand_down"]["top_y"], gt["stand_bottom_y"]),
        ("STAND RIGHT: Base | Walk Pistol 0-3 | Stand Shoot 0-3",
         [pad_base_cell(gt["refs"]["stand_side"]["img"])]
         + processed["tarek_pistol_walk"][1]
         + processed["tarek_pistol_shoot"][1],
         gt["refs"]["stand_side"]["top_y"], gt["stand_bottom_y"]),
        ("STAND UP: Base | Walk Pistol 0-3 | Stand Shoot 0-3",
         [pad_base_cell(gt["refs"]["stand_up"]["img"])]
         + processed["tarek_pistol_walk"][2]
         + processed["tarek_pistol_shoot"][2],
         gt["refs"]["stand_up"]["top_y"], gt["stand_bottom_y"]),
        ("CROUCH DOWN: Base | Crouch Shoot 0-3",
         [pad_base_cell(gt["refs"]["crouch_down"]["img"])]
         + processed["tarek_pistol_crouch_shoot"][0],
         gt["refs"]["crouch_down"]["top_y"], gt["crouch_bottom_y"]),
        ("CROUCH RIGHT: Base | Crouch Shoot 0-3",
         [pad_base_cell(gt["refs"]["crouch_side"]["img"])]
         + processed["tarek_pistol_crouch_shoot"][1],
         gt["refs"]["crouch_side"]["top_y"], gt["crouch_bottom_y"]),
        ("CROUCH UP: Base | Crouch Shoot 0-3",
         [pad_base_cell(gt["refs"]["crouch_up"]["img"])]
         + processed["tarek_pistol_crouch_shoot"][2],
         gt["refs"]["crouch_up"]["top_y"], gt["crouch_bottom_y"]),
    ]

    header_h = 22
    cell_zw = OUT_CELL_W * zoom
    cell_zh = OUT_CELL_H * zoom
    canvas_w = cols * cell_zw
    canvas_h = len(rows_spec) * (cell_zh + header_h)

    # Dark navy in-game background matching the ship deck
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (25, 32, 43, 255))
    draw = ImageDraw.Draw(canvas)

    for ri, (title, cell_list, crown_y, bot_y) in enumerate(rows_spec):
        y_off = ri * (cell_zh + header_h)
        draw.rectangle([0, y_off, canvas_w, y_off + header_h], fill=(16, 20, 28, 255))
        draw.text((8, y_off + 5), title, fill=(225, 232, 245, 255))

        row_y = y_off + header_h
        for ci in range(cols):
            cx0 = ci * cell_zw
            draw.line([(cx0, row_y), (cx0, row_y + cell_zh)], fill=(45, 56, 72, 160), width=1)
            center_x = cx0 + int(round((OUT_CELL_W / 2.0 + gt["base_cx_offset"]) * zoom))
            draw.line([(center_x, row_y), (center_x, row_y + cell_zh)], fill=(70, 145, 230, 80), width=1)

        for ci, cell in enumerate(cell_list):
            zoomed = cell.resize((cell_zw, cell_zh), Image.Resampling.NEAREST)
            canvas.alpha_composite(zoomed, (ci * cell_zw, row_y))

        gy_crown = row_y + crown_y * zoom
        gy_bot = row_y + (bot_y + 1) * zoom - 1
        draw.line([(0, gy_crown), (canvas_w, gy_crown)], fill=(0, 210, 245, 160), width=1)
        draw.line([(0, gy_bot), (canvas_w, gy_bot)], fill=(60, 240, 100, 180), width=1)

    out_artifact = ARTIFACT_DIR / "verification_tarek_pistol_dark_4x.png"
    canvas.save(out_artifact, "PNG")
    out_wb = PROJECT_ROOT / "tools" / "sprite_workbench" / "verification_tarek_pistol_4x.png"
    canvas.save(out_wb, "PNG")
    print(f"Saved 4x dark-bg verification image -> {out_artifact}")
    return out_artifact


def main():
    gt = measure_ground_truth(BASE_SHEET)

    stand_rgba = np.array(Image.open(INPUT_SHEETS["tarek_pistol_shoot"]).convert("RGBA"))
    stand_grid = segment_3x4_midpoint_isolated(stand_rgba, has_fx=True)
    stand_aim_h = stand_grid[0][0].shape[0]
    scale_stand = gt["stand_height"] / float(stand_aim_h)

    crouch_rgba = np.array(Image.open(INPUT_SHEETS["tarek_pistol_crouch_shoot"]).convert("RGBA"))
    crouch_grid = segment_3x4_midpoint_isolated(crouch_rgba, has_fx=True)
    crouch_aim_h = crouch_grid[0][0].shape[0]
    scale_crouch = gt["crouch_height"] / float(crouch_aim_h)

    print(f"[Scale] Standing: {gt['stand_height']}/{stand_aim_h} = {scale_stand:.6f}")
    print(f"[Scale] Crouching: {gt['crouch_height']}/{crouch_aim_h} = {scale_crouch:.6f}")

    target_cx = (OUT_CELL_W / 2.0) + gt["base_cx_offset"]
    processed = {}

    _, processed["tarek_pistol_walk"] = process_sheet(
        "tarek_pistol_walk", INPUT_SHEETS["tarek_pistol_walk"],
        scale_stand, gt["stand_bottom_y"], target_cx, has_fx=False
    )
    _, processed["tarek_pistol_shoot"] = process_sheet(
        "tarek_pistol_shoot", INPUT_SHEETS["tarek_pistol_shoot"],
        scale_stand, gt["stand_bottom_y"], target_cx, has_fx=True
    )
    _, processed["tarek_pistol_crouch_shoot"] = process_sheet(
        "tarek_pistol_crouch_shoot", INPUT_SHEETS["tarek_pistol_crouch_shoot"],
        scale_crouch, gt["crouch_bottom_y"], target_cx, has_fx=True
    )

    build_verification_image(gt, processed)


if __name__ == "__main__":
    main()
