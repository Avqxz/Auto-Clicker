"""Draws the glossy red shopping-basket icon for the Shop tile (no image libraries).

The basket is a small tapered 3D box seen from above and to the side: a dark opening with a light rim,
a front and a side face with rows of grid holes, a glossy highlight, and a thick navy outline.

  python3 tools/art/make_shop_icon.py   -> art/icons_ui/ShopBasket.png (256x256, transparent)
"""
import math, struct, zlib
from pathlib import Path

SIZE = 256
SS = 3
OUT = Path(__file__).resolve().parents[2] / 'art' / 'icons_ui' / 'ShopBasket.png'
INK = (24, 30, 58)
OUTLINE = 0.032
EDGE = 0.012  # thin inner lines between faces

# ---- 3D shape -> 2D polygons ----
def project(x, y, z):
    """x in [-1, 1] (left-right), y in [0, 1] (up), z in [0, 1] (depth, away from the viewer)."""
    return (0.46 + 0.34 * x + 0.17 * z, 0.80 - 0.42 * y - 0.20 * z)

TAPER = 0.82  # the bottom is smaller than the rim
def bottom(x, z):
    return (x * TAPER, 0.0, 0.5 + (z - 0.5) * TAPER)

def lerp3(a, b, t):
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))

FRONT3 = [(-1, 1, 0), (1, 1, 0), bottom(1, 0), bottom(-1, 0)]    # top-left, top-right, bottom-right, bottom-left
SIDE3 = [(1, 1, 0), (1, 1, 1), bottom(1, 1), bottom(1, 0)]       # top-front, top-back, bottom-back, bottom-front
RIM3 = [(-1, 1, 0), (1, 1, 0), (1, 1, 1), (-1, 1, 1)]

def face_point(face, u, v):
    """Point on a face quad: u across (0 = first corner side), v down (0 = top edge)."""
    top = lerp3(face[0], face[1], u)
    bot = lerp3(face[3], face[2], u)
    return lerp3(top, bot, v)

def quad2d(face, u0, u1, v0, v1):
    return [project(*face_point(face, u, v)) for u, v in ((u0, v0), (u1, v0), (u1, v1), (u0, v1))]

FRONT = [project(*p) for p in FRONT3]
SIDE = [project(*p) for p in SIDE3]
RIM = [project(*p) for p in RIM3]
# The opening: the rim quad shrunk toward its middle, leaving a light band.
_mid = [sum(p[k] for p in RIM) / 4 for k in range(2)]
OPENING = [(_mid[0] + (p[0] - _mid[0]) * 0.84, _mid[1] + (p[1] - _mid[1]) * 0.55) for p in RIM]

HOLES_FRONT = [quad2d(FRONT3, 0.09 + i * 0.215, 0.09 + i * 0.215 + 0.15, v0, v0 + 0.24)
               for i in range(4) for v0 in (0.2, 0.56)]
HOLES_SIDE = [quad2d(SIDE3, 0.14 + i * 0.4, 0.14 + i * 0.4 + 0.3, v0, v0 + 0.24)
              for i in range(2) for v0 in (0.2, 0.56)]

# The handle: a thick arch over the opening, from the left rim to the right rim.
HANDLE = [project(-0.62 + 1.24 * k / 16, 1 + 0.55 * math.sin(math.pi * k / 16), 0.5) for k in range(17)]
HANDLE_W = 0.055

# ---- geometry helpers ----
def inside(px, py, poly):
    hit, j = False, len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit

def edge(px, py, poly):
    best = 1e9
    for i in range(len(poly)):
        ax, ay = poly[i]; bx, by = poly[(i + 1) % len(poly)]
        dx, dy = bx - ax, by - ay
        t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    return best

def polyline_dist(px, py, pts):
    best = 1e9
    for i in range(len(pts) - 1):
        ax, ay = pts[i]; bx, by = pts[i + 1]
        dx, dy = bx - ax, by - ay
        t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    return best

def mix(a, b, t):
    return tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))

# ---- shading ----
def shade(px, py):
    hd = polyline_dist(px, py, HANDLE)
    if hd < HANDLE_W / 2:
        return INK if hd > HANDLE_W / 2 - EDGE else (235, 60, 78)
    if inside(px, py, RIM):
        if edge(px, py, RIM) < EDGE:
            return INK
        if inside(px, py, OPENING):
            if edge(px, py, OPENING) < EDGE * 0.8:
                return INK
            # Dark inside, a little lighter toward the back wall.
            t = max(0, min(1, (py - OPENING[2][1]) / (OPENING[0][1] - OPENING[2][1] + 1e-9)))
            return mix((150, 30, 50), (95, 12, 32), t)
        return (255, 150, 160)  # rim band
    if inside(px, py, FRONT):
        if edge(px, py, FRONT) < EDGE:
            return INK
        for hole in HOLES_FRONT:
            if inside(px, py, hole):
                return INK if edge(px, py, hole) < EDGE * 0.7 else (125, 18, 38)
        t = (py - FRONT[0][1]) / (FRONT[3][1] - FRONT[0][1])
        col = mix((255, 92, 100), (215, 38, 58), t)
        u = (px - FRONT[0][0]) / (FRONT[1][0] - FRONT[0][0])
        if u < 0.12:  # glossy highlight down the left edge
            col = mix(col, (255, 255, 255), 0.35)
        return col
    if inside(px, py, SIDE):
        if edge(px, py, SIDE) < EDGE:
            return INK
        for hole in HOLES_SIDE:
            if inside(px, py, hole):
                return INK if edge(px, py, hole) < EDGE * 0.7 else (95, 12, 30)
        t = (py - SIDE[0][1]) / (SIDE[3][1] - SIDE[0][1] + 1e-9)
        return mix((215, 45, 65), (165, 25, 45), max(0, min(1, t)))
    return None

def outline_hit(px, py):
    return (min(edge(px, py, FRONT), edge(px, py, SIDE), edge(px, py, RIM)) < OUTLINE
            or polyline_dist(px, py, HANDLE) < HANDLE_W / 2 + OUTLINE * 0.6)

TILT = math.radians(-8)  # a slight lean, like a sticker

def sample(px, py):
    # Rotate the sample point around the middle for the lean.
    dx, dy = px - 0.5, py - 0.5
    c_, s_ = math.cos(-TILT), math.sin(-TILT)
    px, py = 0.5 + dx * c_ - dy * s_, 0.5 + dx * s_ + dy * c_
    c = shade(px, py)
    if c:
        return c + (255,)
    if outline_hit(px, py):
        return INK + (255,)
    # Soft drop shadow down-right.
    sx, sy = px - 0.03, py - 0.04
    if shade(sx, sy) or outline_hit(sx, sy):
        return INK + (80,)
    return None

def main():
    rows = []
    for y in range(SIZE):
        row = bytearray([0])
        for x in range(SIZE):
            acc = [0, 0, 0, 0]
            for sy in range(SS):
                for sx in range(SS):
                    c = sample((x + (sx + 0.5) / SS) / SIZE, (y + (sy + 0.5) / SS) / SIZE)
                    if c:
                        a = c[3]
                        acc[0] += c[0] * a; acc[1] += c[1] * a; acc[2] += c[2] * a; acc[3] += a
            a = acc[3] / (SS * SS)
            row += bytes((round(acc[0] / acc[3]), round(acc[1] / acc[3]), round(acc[2] / acc[3]), round(a))) if a > 0 else bytes(4)
        rows.append(bytes(row))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png)
    print(OUT, len(png))

if __name__ == '__main__':
    main()
