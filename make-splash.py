#!/usr/bin/env python3
"""Build unlock.png: the stock OMARCHY pixel wordmark with its O swapped for a
bitcoin coin, over a star field and a cratered moon limb along the bottom
edge. Plymouth/SDDM put the password field 40 px under this image, so the limb
reads as the horizon the field sits on. Wordmark cells are 10 px like the
stock logo; the backdrop is drawn on 5 px cells. The backdrop ships as
splash-cells.png (320x128, palette-quantised from an openai/gpt-5.4-image-2
redraw via ppq.ai); without it a plainer procedural backdrop is generated.
Needs ImageMagick and /usr/share/plymouth/themes/omarchy/logo.png.

    ./make-splash.py && omarchy plymouth preview '#12141a' '#e2e4ea' unlock.png preview-unlock.png
"""
import random, subprocess, tempfile, os

CELL = 10
WHITE, DIM, ORANGE, INK = (0xE2,0xE4,0xEA), (0x8B,0x90,0x9D), (0xF7,0x93,0x1A), (0x12,0x14,0x1A)
STOCK = "/usr/share/plymouth/themes/omarchy/logo.png"   # 800x188, O spans x<89, M starts at 109

def pam(grid, path):
    h, w = len(grid), len(grid[0])
    with open(path, "wb") as f:
        f.write(f"P7\nWIDTH {w}\nHEIGHT {h}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n".encode())
        f.write(bytes(v for row in grid for c in row for v in ((0,0,0,0) if c is None else c + (255,))))

# --- coin: 19-cell disc, charcoal pixel B with stubs top and bottom
GLYPH = ["..#..#...", "..#..#...", "#######..", "##....##.", "##....##.", "##....##.", "#######..",
         "##.....##", "##.....##", "##.....##", "#######..", "..#..#...", "..#..#..."]
N = 19; oy = (N - len(GLYPH)) // 2; ox = (N - len(GLYPH[0])) // 2
coin = [[None] * N for _ in range(N)]
for y in range(N):
    for x in range(N):
        if (x + .5 - N/2)**2 + (y + .5 - N/2)**2 > (N/2)**2: continue
        gy, gx = y - oy, x - ox
        coin[y][x] = INK if 0 <= gy < len(GLYPH) and 0 <= gx < len(GLYPH[0]) and GLYPH[gy][gx] == "#" else ORANGE

# --- backdrop: 160x64 cells, moon limb (big circle arc) + stars clear of the wordmark box
random.seed(21)
W, H = 160, 64
bg = [[None] * W for _ in range(H)]
R = 260; cx, cy = W/2, H - 14 + R
for y in range(H):
    for x in range(W):
        if (x + .5 - cx)**2 + (y + .5 - cy)**2 <= R*R: bg[y][x] = WHITE
for x in range(W):                                   # drop slivers thinner than 2 cells
    col = [y for y in range(H) if bg[y][x]]
    if len(col) < 2:
        for y in col: bg[y][x] = None
moon = [(x, y) for y in range(H) for x in range(W) if bg[y][x] == WHITE]
top = min(y for _, y in moon)
for x, y in moon:
    if y > top + 1 and random.random() < 0.05: bg[y][x] = INK
for _ in range(9):                                   # crater rims with a shadowed half
    x, y = random.choice(moon); r = random.choice([2, 2, 3])
    if y - r <= top + 1: continue
    for yy in range(y - r, y + r + 1):
        for xx in range(x - r, x + r + 1):
            d = (xx - x)**2 + (yy - y)**2
            if 0 <= xx < W and 0 <= yy < H and bg[yy][xx] is not None:
                if r*r - 2*r <= d <= r*r + 1: bg[yy][xx] = INK
                elif d < r*r - 2*r and (xx - x) + (yy - y) < 0: bg[yy][xx] = INK
BX, BY, BW, BH = 35, 18, 90, 19                      # wordmark box in cells
clear = lambda x, y: BX - 3 <= x < BX + BW + 3 and BY - 3 <= y < BY + BH + 3
n = 0
while n < 110:
    x, y = random.randrange(W), random.randrange(top - 2)
    if clear(x, y) or bg[y][x] is not None: continue
    if random.random() < 0.12:                       # plus-shaped bright star
        for dx, dy in ((0,0), (1,0), (-1,0), (0,1), (0,-1)):
            if 0 <= x+dx < W and 0 <= y+dy < H and not clear(x+dx, y+dy): bg[y+dy][x+dx] = WHITE
    else:
        bg[y][x] = WHITE if random.random() < 0.6 else DIM
    n += 1

tmp = tempfile.mkdtemp()
pam(coin, f"{tmp}/coin.pam"); pam(bg, f"{tmp}/bg.pam")
m = lambda *a: subprocess.run(["magick", *a], check=True)
m(f"{tmp}/coin.pam", "-filter", "point", "-resize", f"{CELL*100}%", f"{tmp}/coin.png")
m(f"{tmp}/bg.pam",   "-filter", "point", "-resize", f"{CELL*100}%", f"{tmp}/bg.png")
# the stock logo has anti-aliased edges; threshold alpha so every cell is hard
m(STOCK, "-crop", "691x188+109+0", "+repage", "-fill", "#e2e4ea", "-colorize", "100",
  "-channel", "A", "-threshold", "50%", "+channel", f"{tmp}/marchy.png")
m("-size", "901x190", "xc:none", f"{tmp}/coin.png", "-geometry", "+0+0", "-composite",
  f"{tmp}/marchy.png", "-geometry", "+210+1", "-composite", f"{tmp}/wordmark.png")
here = os.path.dirname(os.path.abspath(__file__))
cells = os.path.join(here, "splash-cells.png")
if os.path.exists(cells):
    m(cells, "-filter", "point", "-resize", "500%", f"{tmp}/bg.png")
m(f"{tmp}/bg.png", f"{tmp}/wordmark.png", "-geometry", f"+{BX*CELL}+{BY*CELL}", "-composite",
  os.path.join(here, "unlock.png"))
print("wrote unlock.png")
