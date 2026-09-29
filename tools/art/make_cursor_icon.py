"""Draws the chunky cartoon cursor icon used on the CLICK button and click popups (no image libraries).

  python3 tools/art/make_cursor_icon.py   -> art/icons_ui/Cursor.png (256x256, transparent)
"""
import math, struct, zlib
from pathlib import Path

SIZE = 256
SS = 3  # supersamples per axis
OUT = Path(__file__).resolve().parents[2] / 'art' / 'icons_ui' / 'Cursor.png'

# Classic arrow, in 0..1 units, tip at the top-left.
ARROW = [(0.22, 0.10), (0.22, 0.80), (0.39, 0.64), (0.52, 0.92), (0.64, 0.86), (0.51, 0.59), (0.74, 0.59)]
OUTLINE = 0.045  # outline width, in 0..1 units
INK = (24, 36, 72)
TOP = (255, 255, 255)
BOTTOM = (150, 205, 255)
SHADOW = (24, 36, 72, 90)

def inside(px, py, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit

def edge_distance(px, py, poly):
    best = 1e9
    for i in range(len(poly)):
        ax, ay = poly[i]; bx, by = poly[(i + 1) % len(poly)]
        dx, dy = bx - ax, by - ay
        t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(px - (ax + t * dx), py - (ay + t * dy)))
    return best

def shade(px, py):
    """RGBA for one sample point, or None if empty."""
    d = edge_distance(px, py, ARROW)
    if inside(px, py, ARROW):
        if d < OUTLINE * 0.55:
            return INK + (255,)
        t = min(1, max(0, (py - 0.1) / 0.8))
        c = tuple(round(TOP[k] + (BOTTOM[k] - TOP[k]) * t) for k in range(3))
        return c + (255,)
    if d < OUTLINE:
        return INK + (255,)
    # Soft drop shadow down-right.
    sx, sy = px - 0.035, py - 0.045
    if inside(sx, sy, ARROW) or edge_distance(sx, sy, ARROW) < OUTLINE:
        return SHADOW
    return None

def main():
    rows = []
    for y in range(SIZE):
        row = bytearray([0])
        for x in range(SIZE):
            acc = [0, 0, 0, 0]
            for sy in range(SS):
                for sx in range(SS):
                    c = shade((x + (sx + 0.5) / SS) / SIZE, (y + (sy + 0.5) / SS) / SIZE)
                    if c:
                        a = c[3]
                        acc[0] += c[0] * a; acc[1] += c[1] * a; acc[2] += c[2] * a; acc[3] += a
            n = SS * SS
            a = acc[3] / n
            if a > 0:
                row += bytes((round(acc[0] / acc[3]), round(acc[1] / acc[3]), round(acc[2] / acc[3]), round(a)))
            else:
                row += bytes(4)
        rows.append(bytes(row))
    raw = b''.join(rows)
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png)
    print(OUT, len(png))

if __name__ == '__main__':
    main()
