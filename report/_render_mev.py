# -*- coding: utf-8 -*-
"""Render real MoonEvidence CLI / test output into clean PowerShell-style PNGs.

The text below is the *actual* output captured by running the commands live
(`node <cli> verify/explain ...` and `moon test --target wasm-gc,js`); this
script only lays it out as a terminal screenshot so long digest lines wrap
cleanly instead of being clipped by a resized console window.
"""
import os
from PIL import Image, ImageDraw, ImageFont

# Windows Terminal "Campbell" palette
BG = (12, 12, 12)
TITLE_BG = (45, 45, 45)
TITLE_FG = (204, 204, 204)
DEFAULT = (204, 204, 204)
DIM = (140, 140, 140)
WHITE = (242, 242, 242)
GREEN = (35, 209, 139)
CYAN = (58, 150, 221)
YELLOW = (229, 195, 0)
RED = (231, 72, 86)
PROMPT = (120, 160, 120)

FONT_PATH = r"C:\Windows\Fonts\consola.ttf"
FONT_BOLD = r"C:\Windows\Fonts\consolab.ttf"
FS = 20
font = ImageFont.truetype(FONT_PATH, FS)
font_b = ImageFont.truetype(FONT_BOLD, FS)
title_font = ImageFont.truetype(FONT_PATH, 17)

PAD = 20
LH = FS + 8
TITLE_H = 36
CHAR_W = font.getlength("M")
MAXCOLS = 94


def wrap_line(segs):
    """Flatten (text,color[,bold]) segments to char list, wrap at MAXCOLS."""
    chars = []
    for seg in segs:
        t, c = seg[0], seg[1]
        b = seg[2] if len(seg) > 2 else False
        for ch in t:
            chars.append((ch, c, b))
    if not chars:
        return [[]]
    rows = []
    for i in range(0, len(chars), MAXCOLS):
        chunk = chars[i:i + MAXCOLS]
        row = []
        for ch, c, b in chunk:
            if row and row[-1][1] == c and row[-1][2] == b:
                row[-1][0] += ch
            else:
                row.append([ch, c, b])
        rows.append(row)
    return rows


def render(path, title, lines):
    flat = []
    for segs in lines:
        flat.extend(wrap_line(segs))
    maxw = 0
    for row in flat:
        w = sum((font_b if b else font).getlength(t) for t, _, b in row)
        maxw = max(maxw, w)
    maxw = max(maxw, title_font.getlength(title) + 130)
    W = int(maxw + PAD * 2)
    H = int(TITLE_H + PAD * 2 + LH * len(flat))
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, TITLE_H], fill=TITLE_BG)
    d.text((PAD, (TITLE_H - 17) // 2), title, font=title_font, fill=TITLE_FG)
    cy = TITLE_H // 2
    for i, col in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)][::-1]):
        cx = W - 20 - i * 26
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=col)
    y = TITLE_H + PAD
    for row in flat:
        x = PAD
        for t, c, b in row:
            f = font_b if b else font
            d.text((x, y), t, font=f, fill=c)
            x += f.getlength(t)
        y += LH
    img.save(path)
    print("saved", path, img.size)


OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
os.makedirs(OUT, exist_ok=True)

PS = "PS ...\\moon-evidence> "

# ---- Image 1: CLI verify (OK) + explain (tampered -> E2003) ----
cli_lines = [
    [(PS, PROMPT), ("$cli = \"_build/js/debug/build/src/cmd/main/main.js\"", DIM)],
    [(PS, PROMPT), ("node $cli verify examples/valid-pack", WHITE, True)],
    [("verification OK", GREEN, True)],
    [("checked 2 files, 2 passed; merkle root verified; 0 errors, 0 warnings", DIM)],
    [],
    [(PS, PROMPT), ("node $cli explain examples/tampered-pack", WHITE, True)],
    [("verification FAILED", RED, True)],
    [("  ", DEFAULT), ("[E2003]", YELLOW, True),
     (" files/a.txt: digest mismatch, expected "
      "sha256:a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447 "
      "got sha256:7509e5bda0c762d2bac7f90d758b5b2263fa01ccbc542ab5e3df163be08e6ca9",
      DEFAULT)],
    [("checked 2 files, 1 passed; merkle root verified; 1 error, 0 warnings", DIM)],
]
render(os.path.join(OUT, "mev_cli.png"),
       "Windows PowerShell  -  MoonEvidence CLI (verify / explain)", cli_lines)

# ---- Image 2: moon test on wasm-gc + js, 215/215 ----
test_lines = [
    [(PS, PROMPT), ("moon test --target wasm-gc,js", WHITE, True)],
    [],
    [("Total tests: ", DEFAULT), ("215", WHITE, True), (", passed: ", DEFAULT),
     ("215", GREEN, True), (", failed: ", DEFAULT), ("0", DEFAULT),
     (". ", DEFAULT), ("[wasm-gc]", CYAN)],
    [("Total tests: ", DEFAULT), ("215", WHITE, True), (", passed: ", DEFAULT),
     ("215", GREEN, True), (", failed: ", DEFAULT), ("0", DEFAULT),
     (". ", DEFAULT), ("[js]", CYAN)],
]
render(os.path.join(OUT, "mev_test.png"),
       "Windows PowerShell  -  moon test (wasm-gc + js backends)", test_lines)

print("ALL DONE")
