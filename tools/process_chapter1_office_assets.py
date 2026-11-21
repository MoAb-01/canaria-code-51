"""
Preprocesses the 3 Chapter I Office assets to match Tarek's 32x40 pixel density:
1. office_room_bg.png — 200x200 NEAREST-downsampled top-down 3/4 office (1x pixel grid, displayed at 3x in Godot).
2. office_desk.png    — 56x37 transparent NEAREST-downsampled desk (outside-border black flood-fill R,G,B < 20).
3. desk_pov.png       — Lossless PNG of the 16:9 first-person desk close-up.
"""

from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image

PROJECT_ROOT = Path(r"c:\Users\UHD\Documents\my-test-game")
OUT_DIR = PROJECT_ROOT / "assets" / "textures" / "office"
OUT_DIR.mkdir(parents=True, exist_ok=True)
ARTIFACT_DIR = Path(r"C:\Users\UHD\.gemini\antigravity\brain\58a3aa24-682d-414b-9ef5-d6cc67268d3d")
TAREK_SHEET = PROJECT_ROOT / "assets" / "sprites" / "tarek" / "tarek_spritesheet.png"

SRC_BG = Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795099127089_f176b3f6.jpg")
SRC_DESK = Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795099139706_a8b02568.jpg")
SRC_POV = Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795099160299_4bd0c3ef.jpg")


def outside_black_flood_fill(rgb: np.ndarray, thresh: int = 20) -> np.ndarray:
    """Strictly outside-border flood-fill for black background (R<20, G<20, B<20)."""
    h, w, _ = rgb.shape
    is_black = (rgb[:, :, 0] < thresh) & (rgb[:, :, 1] < thresh) & (rgb[:, :, 2] < thresh)
    bg = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if is_black[0, x] and not bg[0, x]:
            bg[0, x] = True; q.append((0, x))
        if is_black[h - 1, x] and not bg[h - 1, x]:
            bg[h - 1, x] = True; q.append((h - 1, x))
    for y in range(h):
        if is_black[y, 0] and not bg[y, 0]:
            bg[y, 0] = True; q.append((y, 0))
        if is_black[y, w - 1] and not bg[y, w - 1]:
            bg[y, w - 1] = True; q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and is_black[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(bg, 0, 255).astype(np.uint8)
    return rgba


def main():
    # 1. Measure Tarek ground truth (32x40 cell, 16x32 standing body)
    tarek_sheet = Image.open(TAREK_SHEET).convert("RGBA")
    tarek_idle = tarek_sheet.crop((0, 120, 32, 160))  # row 3 col 0 = idle_down

    # 2. Process office room background -> 200x200 NEAREST (chair = 21x38 px, matches 16x32 Tarek)
    bg_rgb = np.array(Image.open(SRC_BG).convert("RGB"))
    bg_rgba = outside_black_flood_fill(bg_rgb, thresh=20)
    bg_pil = Image.fromarray(bg_rgba, "RGBA")
    bg_small = bg_pil.resize((200, 200), Image.Resampling.NEAREST)
    bg_out = OUT_DIR / "office_room_bg.png"
    bg_small.save(bg_out, "PNG")
    print(f"Saved {bg_out} ({bg_small.size})")

    # 3. Process standalone office desk -> outside flood-fill, tight crop, 56px wide NEAREST
    desk_rgb = np.array(Image.open(SRC_DESK).convert("RGB"))
    desk_rgba = outside_black_flood_fill(desk_rgb, thresh=20)
    ys, xs = np.where(desk_rgba[:, :, 3] > 0)
    desk_tight = desk_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1, :]
    raw_h, raw_w = desk_tight.shape[:2]
    target_desk_w = 56
    target_desk_h = int(round(raw_h * (target_desk_w / float(raw_w))))
    desk_small = Image.fromarray(desk_tight, "RGBA").resize(
        (target_desk_w, target_desk_h), Image.Resampling.NEAREST
    )
    desk_out = OUT_DIR / "office_desk.png"
    desk_small.save(desk_out, "PNG")
    print(f"Saved {desk_out} ({desk_small.size}) from raw tight crop {raw_w}x{raw_h}")

    # 4. Save full-res lossless PNG for First-Person Desk POV
    pov_img = Image.open(SRC_POV).convert("RGB")
    pov_out = OUT_DIR / "desk_pov.png"
    pov_img.save(pov_out, "PNG")
    print(f"Saved {pov_out} ({pov_img.size})")

    # 5. Composite 3x verification preview: Room + Tarek seated in chair + Desk in front
    comp = Image.new("RGBA", (200, 200), (0, 0, 0, 255))
    comp.alpha_composite(bg_small, (0, 0))
    # Chair center in 200x200 is x=122, seat y~76..86 -> Tarek (32x40, feet at y=39)
    # Place Tarek so his head sits against the upper chair backrest (y ~ 58..90)
    tarek_x = 122 - 16
    tarek_y = 56
    comp.alpha_composite(tarek_idle, (tarek_x, tarek_y))
    # Place Desk centered at x=122, directly in front of chair (covering Tarek's lower body)
    desk_x = 122 - (target_desk_w // 2)
    desk_y = 75
    comp.alpha_composite(desk_small, (desk_x, desk_y))

    preview = comp.resize((600, 600), Image.Resampling.NEAREST)
    preview_path = ARTIFACT_DIR / "verification_chapter1_office_3x.png"
    preview.save(preview_path, "PNG")
    print(f"Saved 3x composite preview -> {preview_path}")


if __name__ == "__main__":
    main()
