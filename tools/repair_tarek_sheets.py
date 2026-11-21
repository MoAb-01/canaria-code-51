"""
Repairs transparent pinholes and stray floating specks in Tarek's three older sheets
(in place, originals backed up to tools/backup_sprites/). Pistol sheets are never modified.
"""
import re
import shutil
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(r"c:\Users\UHD\Documents\my-test-game")
SPR = ROOT / "assets" / "sprites" / "tarek"
BACKUP = ROOT / "tools" / "backup_sprites"
ART = Path(r"C:\Users\UHD\.gemini\antigravity\brain\58a3aa24-682d-414b-9ef5-d6cc67268d3d")
TARGETS = ["tarek_spritesheet.png", "tarek_expansion_spritesheet.png", "tarek_flashlight.png"]
CLEAN = ["tarek_pistol_walk.png", "tarek_pistol_shoot.png", "tarek_pistol_crouch_shoot.png"]
CW, CH = 32, 40
MAX_HOLE = 4          # enclosed transparent regions larger than this are intentional gaps
MIN_COMPONENT = 4     # disconnected components smaller than this are stray specks
EIGHT = np.ones((3, 3), dtype=int)


def build_palette():
    counts = Counter()
    for f in CLEAN:
        a = np.array(Image.open(SPR / f).convert("RGBA"))
        px = a[a[:, :, 3] == 255][:, :3]
        counts.update(map(tuple, px))
    # also pull literal #rrggbb colors from the workbench pixel script
    js = ROOT / "tools" / "sprite_workbench" / "tarek_base_pixels.js"
    if js.exists():
        for h in set(re.findall(r"#([0-9a-fA-F]{6})\b", js.read_text(errors="ignore"))):
            counts[tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))] += 3
    pal = np.array([c for c, n in counts.items() if n >= 20], dtype=np.int32)
    print(f"[Palette] {len(pal)} colors (from {len(counts)} unique)")
    return pal


def snap(color, pal):
    d = ((pal - np.array(color, dtype=np.int32)) ** 2).sum(axis=1)
    return pal[int(d.argmin())]


def repair_cell(cell, pal):
    out = cell.copy()
    alpha = out[:, :, 3] > 0
    stats = {"filled": 0, "specks": 0}
    if not alpha.any():
        return out, stats

    # 1. remove stray specks (disconnected, < MIN_COMPONENT px)
    lab, n = ndimage.label(alpha, structure=EIGHT)
    if n > 1:
        sizes = ndimage.sum(alpha, lab, range(1, n + 1))
        keep_main = int(np.argmax(sizes)) + 1
        for i, s in enumerate(sizes, start=1):
            if i != keep_main and s < MIN_COMPONENT:
                ys_i = np.where(lab == i)[0]
                if ys_i.max() == np.where(alpha)[0].max() and ys_i.max() > np.where(lab == keep_main)[0].max():
                    continue  # speck defines the cell bottom_y baseline: keep so foot baseline is untouched
                out[lab == i] = 0
                stats["specks"] += int(s)
        alpha = out[:, :, 3] > 0

    # 2. fill enclosed pinholes
    holes = ndimage.binary_fill_holes(alpha) & ~alpha
    hl, hn = ndimage.label(holes)
    for i in range(1, hn + 1):
        m = hl == i
        if m.sum() > MAX_HOLE:
            continue
        for y, x in zip(*np.where(m)):
            ys, xs = slice(max(0, y - 1), y + 2), slice(max(0, x - 1), x + 2)
            nb = out[ys, xs]
            nb = nb[nb[:, :, 3] == 255][:, :3]
            if len(nb) == 0:
                continue
            mode = Counter(map(tuple, nb)).most_common(1)[0][0]
            out[y, x, :3] = snap(mode, pal)
            out[y, x, 3] = 255
            stats["filled"] += 1
    return out, stats


def bottom_y(cell):
    ys = np.where(cell[:, :, 3] > 0)[0]
    return int(ys.max()) if len(ys) else -1


def main():
    BACKUP.mkdir(parents=True, exist_ok=True)
    pal = build_palette()
    before_after = {}
    for f in TARGETS:
        src = SPR / f
        bak = BACKUP / f
        if not bak.exists():
            shutil.copy2(src, bak)
        orig = np.array(Image.open(bak).convert("RGBA"))   # always repair from pristine backup
        out = orig.copy()
        H, W = orig.shape[:2]
        tot_f = tot_s = shifted = 0
        for r in range(H // CH):
            for c in range(W // CW):
                sl = (slice(r * CH, (r + 1) * CH), slice(c * CW, (c + 1) * CW))
                cell = orig[sl]
                fixed, st = repair_cell(cell, pal)
                if bottom_y(fixed) != bottom_y(cell):
                    shifted += 1
                out[sl] = fixed
                tot_f += st["filled"]; tot_s += st["specks"]
                if st["filled"] or st["specks"]:
                    print(f"  {f} r{r} c{c}: filled={st['filled']} specks={st['specks']}")
        Image.fromarray(out, "RGBA").save(src, "PNG")
        print(f"{f}: filled {tot_f} pinholes, removed {tot_s} stray px, bottom_y shifts={shifted}")
        before_after[f] = (orig, out)

    # contact sheets: before | after at 4x over magenta
    for f, (o, n) in before_after.items():
        def render(a):
            bg = Image.new("RGBA", (a.shape[1], a.shape[0]), (255, 0, 255, 255))
            bg.alpha_composite(Image.fromarray(a, "RGBA"))
            return bg.resize((a.shape[1] * 4, a.shape[0] * 4), Image.Resampling.NEAREST)
        lo, ln = render(o), render(n)
        sheet = Image.new("RGBA", (lo.width * 2 + 16, lo.height), (255, 255, 255, 255))
        sheet.paste(lo, (0, 0)); sheet.paste(ln, (lo.width + 16, 0))
        sheet.save(ART / f"repair_contact_{f}", "PNG")
    # idle_up close-up (row 5 col 0 of tarek_spritesheet)
    o, n = before_after["tarek_spritesheet.png"]
    sl = (slice(5 * CH, 6 * CH), slice(0, CW))
    def tile(a):
        bg = Image.new("RGBA", (CW, CH), (255, 0, 255, 255)); bg.alpha_composite(Image.fromarray(a[sl], "RGBA"))
        return bg.resize((CW * 12, CH * 12), Image.Resampling.NEAREST)
    to, tn = tile(o), tile(n)
    s = Image.new("RGBA", (to.width * 2 + 16, to.height), (255, 255, 255, 255))
    s.paste(to, (0, 0)); s.paste(tn, (to.width + 16, 0))
    s.save(ART / "repair_idle_up_closeup.png", "PNG")


if __name__ == "__main__":
    main()
