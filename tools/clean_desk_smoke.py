"""
Cleans the static grey smoke trail cleanly & seamlessly from:
1. assets/textures/office/desk_pov.png (smooth horizontal plank interpolation matching lamp gradient)
2. assets/textures/office/office_desk.png (cleans static smoke above desk & over wood trim)
"""

from pathlib import Path
import numpy as np
from PIL import Image

PROJECT = Path(r"c:\Users\UHD\Documents\my-test-game")
OFFICE_DIR = PROJECT / "assets" / "textures" / "office"
ARTIFACT_DIR = Path(r"C:\Users\UHD\.gemini\antigravity\brain\58a3aa24-682d-414b-9ef5-d6cc67268d3d")
SRC_POV = Path(r"C:/Users/UHD/.gemini/antigravity/brain/58a3aa24-682d-414b-9ef5-d6cc67268d3d/.user_uploaded/media_1795099160299_4bd0c3ef.jpg")


def clean_desk_pov():
    arr = np.array(Image.open(SRC_POV).convert("RGB"))
    out = arr.copy()

    # The static smoke S-curve sits strictly in y=[270..382], x=[154..202]
    # (the ashtray rim begins at y=383, so stopping at y=382 leaves the ashtray 100% intact).
    # Horizontal linear interpolation from left (x0=152) to right (x1=204) preserves
    # both horizontal plank seams AND the overhead warm lamp brightness gradient seamlessly!
    x0, x1 = 152, 204
    width = x1 - x0
    t = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :, None]
    left_col = arr[270:383, x0 - 3:x0, :].mean(axis=1, keepdims=True).astype(np.float32)
    right_col = arr[270:383, x1:x1 + 3, :].mean(axis=1, keepdims=True).astype(np.float32)
    interp = np.clip(np.round(left_col * (1.0 - t) + right_col * t), 0, 255).astype(np.uint8)
    out[270:383, x0:x1, :] = interp

    path = OFFICE_DIR / "desk_pov.png"
    Image.fromarray(out, "RGB").save(path, "PNG")
    print(f"Seamlessly cleaned static smoke from {path}")

    crop = Image.fromarray(out[260:510, 80:270], "RGB").resize((380, 500), Image.Resampling.NEAREST)
    crop.save(ARTIFACT_DIR / "verify_desk_pov_clean.png", "PNG")


def clean_office_desk():
    path = OFFICE_DIR / "office_desk.png"
    arr = np.array(Image.open(path).convert("RGBA"))
    # Clear static smoke above desk top (rows 0..3)
    arr[0:4, :, 3] = 0
    # Replace the 3 grey smoke pixels on the top wooden trim (rows 4..6, x=47) with adjacent trim
    arr[4:7, 47, :] = arr[4:7, 43, :]

    Image.fromarray(arr, "RGBA").save(path, "PNG")
    print(f"Seamlessly cleaned static smoke from {path}")

    zoom = Image.fromarray(arr, "RGBA").resize((56 * 6, 37 * 6), Image.Resampling.NEAREST)
    zoom.save(ARTIFACT_DIR / "verify_office_desk_clean.png", "PNG")


if __name__ == "__main__":
    clean_desk_pov()
    clean_office_desk()
