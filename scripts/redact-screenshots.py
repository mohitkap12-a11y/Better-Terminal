#!/usr/bin/env python3
"""Replaces the text inside the six terminal panes (and the folder path in each pane header) of a full-window
Better Terminal screenshot with generic sample content, so no real names, hosts or paths are published.

usage: redact-screenshots.py dark|light input.png output.png
Needs Pillow. Geometry matches captures of the app at 1966x1405 (window with a hidden title bar, 1x3 + 1x3 panes).
"""
import sys
from PIL import Image, ImageDraw, ImageFont

MODE, SRC, DST = sys.argv[1], sys.argv[2], sys.argv[3]

GEOM = {
    # column x ranges, row content/header y ranges
    "dark":  dict(cols=[(285, 828), (829, 1373), (1374, 1916)], header=[(72, 100), (706, 734)],
                  content=[(101, 705), (735, 1337)]),
    "light": dict(cols=[(284, 827), (828, 1372), (1373, 1916)], header=[(70, 98), (704, 732)],
                  content=[(99, 703), (733, 1336)]),
}[MODE]

PALETTE = {
    "dark":  dict(bg=(1, 4, 9), fg=(225, 232, 238), dim=(125, 133, 140), green=(86, 211, 100), cyan=(86, 212, 221),
                  yellow=(227, 179, 65), blue=(121, 192, 255), red=(255, 123, 114), path=(140, 146, 152)),
    "light": dict(bg=(255, 255, 255), fg=(25, 25, 25), dim=(120, 120, 120), green=(26, 127, 55), cyan=(8, 120, 140),
                  yellow=(140, 105, 0), blue=(9, 80, 200), red=(190, 40, 40), path=(115, 115, 115)),
}[MODE]

MONO = "/usr/share/fonts/truetype/freefont/FreeMono.ttf"
SYMBOLS = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
UI = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
CELL_W, LINE_H, FONT_PX = 9.98, 19, 17
mono, sym = ImageFont.truetype(MONO, FONT_PX), ImageFont.truetype(SYMBOLS, FONT_PX - 2)
ui = ImageFont.truetype(UI, 11)

P = "dev@macbook"
# Each pane: header path and lines of (text, colour-name) runs. "▌" at the end of the last line is the cursor.
PANES = [
    ("~/projects/api", [
        [(f"{P} api % ", "fg"), ("git status", "fg")],
        [("On branch main", "fg")],
        [("Your branch is up to date with 'origin/main'.", "fg")],
        [("", "fg")],
        [("nothing to commit, working tree clean", "fg")],
        [(f"{P} api % ", "fg"), ("npm test", "fg")],
        [("", "fg")],
        [("> api@1.4.0 test", "dim")],
        [("> vitest run", "dim")],
        [("", "fg")],
        [(" ✓ ", "green"), ("src/auth.test.ts ", "fg"), ("(8 tests)", "dim")],
        [(" ✓ ", "green"), ("src/routes.test.ts ", "fg"), ("(14 tests)", "dim")],
        [(" ✓ ", "green"), ("src/db.test.ts ", "fg"), ("(6 tests)", "dim")],
        [("", "fg")],
        [(" Test Files  ", "dim"), ("3 passed", "green"), (" (3)", "dim")],
        [("      Tests  ", "dim"), ("28 passed", "green"), (" (28)", "dim")],
        [("   Duration  1.42s", "dim")],
        [(f"{P} api % ", "fg")],
    ]),
    ("~/projects/web", [
        [(f"{P} web % ", "fg"), ("npm run dev", "fg")],
        [("", "fg")],
        [("> web@0.3.0 dev", "dim")],
        [("> vite", "dim")],
        [("", "fg")],
        [("  VITE ", "green"), ("v5.4.2", "fg"), ("  ready in ", "dim"), ("214 ms", "fg")],
        [("", "fg")],
        [("  ➜  ", "green"), ("Local:   ", "fg"), ("http://localhost:5173/", "cyan")],
        [("  ➜  ", "dim"), ("Network: use --host to expose", "dim")],
        [("12:04:31 ", "dim"), ("[vite] ", "cyan"), ("hmr update ", "fg"), ("/src/App.tsx", "dim")],
        [("12:04:58 ", "dim"), ("[vite] ", "cyan"), ("hmr update ", "fg"), ("/src/styles.css", "dim")],
        [("^C", "fg")],
        [(f"{P} web % ", "fg")],
    ]),
    ("~/projects/docs", [
        [(f"{P} docs % ", "fg"), ("ls", "fg")],
        [("README.md        guides", "fg")],
        [("assets           index.md", "fg")],
        [("config.json      package.json", "fg")],
        [(f"{P} docs % ", "fg"), ("git log --oneline -3", "fg")],
        [("a3f9c21 ", "yellow"), ("Add install guide", "fg")],
        [("5be07d4 ", "yellow"), ("Fix broken links", "fg")],
        [("c18e552 ", "yellow"), ("Update screenshots", "fg")],
        [(f"{P} docs % ", "fg")],
    ]),
    ("~/projects/server", [
        [(f"{P} server % ", "fg"), ("docker compose up -d", "fg")],
        [(" ✔ ", "green"), ("Container db      ", "fg"), ("Started", "green")],
        [(" ✔ ", "green"), ("Container cache   ", "fg"), ("Started", "green")],
        [(" ✔ ", "green"), ("Container api     ", "fg"), ("Started", "green")],
        [(f"{P} server % ", "fg")],
    ]),
    ("~/projects/tools", [
        [(f"{P} tools % ", "fg"), ("cargo build --release", "fg")],
        [("   Compiling ", "green"), ("serde v1.0.203", "fg")],
        [("   Compiling ", "green"), ("tokio v1.38.0", "fg")],
        [("   Compiling ", "green"), ("tools v0.2.0", "fg")],
        [("    Finished ", "green"), ("release [optimized] in 8.41s", "fg")],
        [(f"{P} tools % ", "fg")],
    ]),
    ("~/projects/notes", [
        [(f"{P} notes % ", "fg"), ("echo \"ship it\"", "fg")],
        [("ship it", "fg")],
        [(f"{P} notes % ", "fg")],
    ]),
]

def color(name): return PALETTE[name]

def draw_char(d, ch, x, y, col):
    # FreeMono for letters, DejaVu for symbols it lacks.
    f = mono
    if ord(ch) > 0x2000: f = sym
    d.text((x, y), ch, font=f, fill=col)

im = Image.open(SRC).convert("RGBA")
d = ImageDraw.Draw(im)
bg = PALETTE["bg"]
cols, hdr, cnt = GEOM["cols"], GEOM["header"], GEOM["content"]
i = 0
for r in range(2):
    for c in range(3):
        x0, x1 = cols[c]
        path, lines = PANES[i]; i += 1
        # header: keep the grip and history icons, replace the path
        hy0, hy1 = hdr[r]
        d.rectangle([x0 + 24, hy0 + 2, x1 - 50, hy1 - 2], fill=bg)
        d.text((x0 + 32, hy0 + 7), path, font=ui, fill=PALETTE["path"])
        # content
        cy0, cy1 = cnt[r]
        d.rectangle([x0, cy0, x1 - 1, cy1 - 1], fill=bg)
        y = cy0 + 3
        maxc = int((x1 - x0 - 4) / CELL_W)
        for li, runs in enumerate(lines):
            x = x0 + 1
            col_i = 0
            for text, cname in runs:
                for ch in text:
                    if col_i >= maxc: break
                    draw_char(d, ch, x + col_i * CELL_W, y, color(cname)); col_i += 1
            if li == len(lines) - 1:   # cursor
                cx = x0 + 1 + col_i * CELL_W
                d.rectangle([cx, y + 1, cx + CELL_W - 1, y + LINE_H - 2], outline=color("fg"), width=1)
            y += LINE_H
im.save(DST, optimize=True)
print("wrote", DST)
