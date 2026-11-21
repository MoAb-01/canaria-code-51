"""
Extracts the 4 cabinet close-up sprites from the uploaded composite sheet into
assets/sprites/cabinet/ with transparent backgrounds (outside-border flood-fill
preserving internal dark outlines).
"""

from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

PROJECT = Path(r"c:\Users\UHD\Documents\my-test-game")
OUT_DIR = PROJECT / "assets" / "sprites" / "cabinet"
OUT_DIR.mkdir(parents=True, exist_ok=True)
ARTIFACT_DIR = Path(r"C:\Users\UHD\.gemini\antigravity\brain\58a3aa24-682d-414b-9ef5-d6cc67268d3d")
SRC = Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795270756420_a643ab97.jpg")

NAMES = [
    "drawer_front_closed.png",
    "drawer_interior_open.png",
    "brass_key.png",
    "pistol_pickup.png",
]


def flood_bg(rgb: np.ndarray, bg_rgb: tuple[int, int, int], tol: int = 16) -> np.ndarray:
    h, w, _ = rgb.shape
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    br, bg_c, bb = bg_rgb
    is_bg = (np.abs(r - br) <= tol) & (np.abs(g - bg_c) <= tol) & (np.abs(b - bb) <= tol)

    mask = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if is_bg[0, x] and not mask[0, x]:
            mask[0, x] = True; q.append((0, x))
        if is_bg[h - 1, x] and not mask[h - 1, x]:
            mask[h - 1, x] = True; q.append((h - 1, x))
    for y in range(h):
        if is_bg[y, 0] and not mask[y, 0]:
            mask[y, 0] = True; q.append((y, 0))
        if is_bg[y, w - 1] and not mask[y, w - 1]:
            mask[y, w - 1] = True; q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and is_bg[ny, nx]:
                mask[ny, nx] = True
                q.append((ny, nx))

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(mask, 0, 255).astype(np.uint8)
    return rgba


def find_runs(mask_1d: np.ndarray, min_gap: int = 16) -> list[tuple[int, int]]:
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
    return [(a, b) for a, b in merged if (b - a + 1) >= 20]


def main():
    full = np.array(Image.open(SRC).convert("RGB"))
    # Crop above the bottom filename captions (captions sit below y=480)
    top = full[:475, :, :]
    bg_rgb = tuple(int(v) for v in top[0, 0])
    print("Detected bg RGB:", bg_rgb)

    rgba = flood_bg(top, bg_rgb, tol=16)
    col_bands = find_runs((rgba[:, :, 3] > 0).any(axis=0), min_gap=20)
    assert len(col_bands) == 4, f"Expected 4 sprites, found {len(col_bands)}: {col_bands}"

    previews = []
    for name, (x0, x1) in zip(NAMES, col_bands):
        sub = rgba[:, x0:x1 + 1, :]
        ys, xs = np.where(sub[:, :, 3] > 0)
        tight = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1, :].copy()
        img = Image.fromarray(tight, "RGBA")
        out_path = OUT_DIR / name
        img.save(out_path, "PNG")
        print(f"Saved {out_path} ({img.size[0]}x{img.size[1]})")
        previews.append(img)

    # Save quick preview on checker/slate background
    max_h = max(p.height for p in previews)
    total_w = sum(p.width for p in previews) + 60
    canvas = Image.new("RGBA", (total_w, max_h + 24), (48, 56, 68, 255))
    cx = 12
    for p in previews:
        canvas.alpha_composite(p, (cx, (max_h - p.height) // 2 + 12))
        cx += p.width + 12
    canvas.save(ARTIFACT_DIR / "verify_cabinet_sprites.png", "PNG")


if __name__ == "__main__":
    main()
