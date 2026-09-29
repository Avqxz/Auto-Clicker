"""Rebuilds every pet in a chunky simulator style (rounded-cube bodies, big glossy or glowing eyes, bold
colors, oversized wings / horns / crowns, Neon accents on rare pets) from short per-pet specs.

  Blender --background --python tools/art/build_bgs_pets.py -- [--sheet-only] [--only "Name,Name"]

Writes, per pet, art/exports/Pet_<Biome>_<Name>.fbx (the names the game already uses) and an icon
art/icons_bgs/<same>.png, plus a contact sheet art/renders/bgs_pets_sheet.png. Pets face -Y; export
matches the art package (Y-up / -Z-forward, one material per piece so ArtLook can color it; materials
with emission become Neon in Roblox).
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2] / 'art'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SHEET_ONLY = '--sheet-only' in ARGS
ONLY = set(ARGS[ARGS.index('--only') + 1].split(',')) if '--only' in ARGS else None

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- materials
MATS = {}


def srgb_to_linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(hexcolor, glow=False):
    key = hexcolor.lower() + ('_glow' if glow else '')
    if key in MATS:
        return MATS[key]
    r, g, b = (srgb_to_linear(int(hexcolor[i:i + 2], 16)) for i in (0, 2, 4))
    m = bpy.data.materials.new(('C_' if not glow else 'G_') + hexcolor.lower())
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (r, g, b, 1)
    bsdf.inputs['Roughness'].default_value = 0.35
    if glow:
        bsdf.inputs['Emission Color'].default_value = (r, g, b, 1)
        bsdf.inputs['Emission Strength'].default_value = 1.5
    m.diffuse_color = (r, g, b, 1)
    MATS[key] = m
    return m


# ---------------------------------------------------------------- geometry kit
COL = None
COUNT = {}


def finish(name, bm, color, glow=False, smooth=True):
    COUNT[name] = COUNT.get(name, 0) + 1
    unique = name if COUNT[name] == 1 else f'{name}_{COUNT[name]}'
    me = bpy.data.meshes.new(unique)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    o = bpy.data.objects.new(unique, me)
    o.data.materials.append(mat(color, glow))
    COL.objects.link(o)
    return o


def place(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)


def rbox(name, center, size, color, rnd=0.28, glow=False, rot=None):
    """Rounded box. rnd = bevel as a fraction of the smallest side."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if rnd > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=rnd * min(size), segments=3, affect='EDGES', profile=0.5)
    m = Matrix.Translation(center)
    if rot:
        m = m @ rot
    place(bm, m)
    return finish(name, bm, color, glow)


def ball(name, center, scale, color, glow=False, rot=None, seg=20):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1.0)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    m = Matrix.Translation(center)
    if rot:
        m = m @ rot
    place(bm, m)
    return finish(name, bm, color, glow)


def cone(name, base, tip, r1, r2, color, glow=False, seg=12, smooth=True):
    base, tip = Vector(base), Vector(tip)
    axis = tip - base
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=axis.length)
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    place(bm, Matrix.Translation((base + tip) / 2) @ rot)
    return finish(name, bm, color, glow, smooth)


def tube(name, points, color, glow=False, seg=10, cap_tip=True):
    """points: [(Vector position, radius)] along a curve."""
    bm = bmesh.new()
    prev = None
    rings = []
    for k, (pos, radius) in enumerate(points):
        a = points[max(k - 1, 0)][0]
        b = points[min(k + 1, len(points) - 1)][0]
        forward = (b - a).normalized()
        side = forward.cross(Vector((0, 1, 0)))
        if side.length < 1e-3:
            side = forward.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(forward)
        ring = [bm.verts.new(pos + (side * math.cos(2 * math.pi * s / seg) + up * math.sin(2 * math.pi * s / seg)) * radius)
                for s in range(seg)]
        if prev:
            for s in range(seg):
                bm.faces.new((prev[s], prev[(s + 1) % seg], ring[(s + 1) % seg], ring[s]))
        else:
            bm.faces.new(list(reversed(ring)))
        prev = ring
        rings.append(ring)
    if cap_tip:
        end = points[-1][0] + (points[-1][0] - points[-2][0]).normalized() * points[-1][1] * 1.5
        tipv = bm.verts.new(end)
        for s in range(seg):
            bm.faces.new((prev[s], prev[(s + 1) % seg], tipv))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, color, glow)


def curve(start, end, bend, r0, r1, steps=10):
    """Points for a tube bowed by `bend` (a vector added at the middle)."""
    start, end, bend = Vector(start), Vector(end), Vector(bend)
    out = []
    for k in range(steps + 1):
        t = k / steps
        p = start.lerp(end, t) + bend * (4 * t * (1 - t))
        out.append((p, r0 + (r1 - r0) * t))
    return out


def slab(name, outline, thickness, matrix, color, glow=False):
    """A flat shape: outline in the local XZ plane, thickness along local Y, placed by `matrix`."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -thickness / 2, z)) for x, z in outline]
    back = [bm.verts.new((x, thickness / 2, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        bm.faces.new((front[i], back[i], back[(i + 1) % n], front[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    place(bm, matrix)
    return finish(name, bm, color, glow, smooth=False)


def torus(name, center, major, minor, color, glow=False, rot=None, seg=28, tube_seg=8):
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        ring = []
        for j in range(tube_seg):
            b = 2 * math.pi * j / tube_seg
            d = Vector((math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b))) * minor
            ring.append(bm.verts.new(c + d))
        rings.append(ring)
    for i in range(seg):
        for j in range(tube_seg):
            a, b = rings[i], rings[(i + 1) % seg]
            bm.faces.new((a[j], b[j], b[(j + 1) % tube_seg], a[(j + 1) % tube_seg]))
    m = Matrix.Translation(center)
    if rot:
        m = m @ rot
    place(bm, m)
    return finish(name, bm, color, glow)


def gem(name, center, radius, height, color, glow=False, turn=0.0):
    n = 8
    cx, cy, cz = center
    tr, th, ch = radius * 0.55, height * 0.32, height * 0.68
    girdle = [(cx + radius * math.cos(turn + math.pi * i / n), cy + radius * math.sin(turn + math.pi * i / n), cz) for i in range(2 * n)]
    table = [(cx + tr * math.cos(turn + 2 * math.pi * i / n + math.pi / n), cy + tr * math.sin(turn + 2 * math.pi * i / n + math.pi / n), cz + th)
             for i in range(n)]
    bm = bmesh.new()
    V = lambda p: bm.verts.new(p)
    top, cul = V((cx, cy, cz + th)), V((cx, cy, cz - ch))
    g = [V(p) for p in girdle]
    t = [V(p) for p in table]
    for i in range(n):
        bm.faces.new((top, t[i], t[(i + 1) % n]))
        bm.faces.new((t[i], g[2 * i + 1], g[(2 * i + 2) % (2 * n)]))
        bm.faces.new((t[i], g[(2 * i + 2) % (2 * n)], t[(i + 1) % n]))
        bm.faces.new((t[(i + 1) % n], g[(2 * i + 2) % (2 * n)], g[(2 * i + 3) % (2 * n)]))
    for i in range(2 * n):
        bm.faces.new((g[i], cul, g[(i + 1) % (2 * n)]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, color, glow, smooth=False)


def star_outline(r_out, r_in, points=5):
    out = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi / 2 + math.pi * i / points
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'Z')


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'Y')


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 4, 'X')


# ---------------------------------------------------------------- pet builder
class Body:
    """Where the body is, for placing features: center, size (w, d, h), front plane y, top z."""

    def __init__(self, center, size):
        self.c = Vector(center)
        self.w, self.d, self.h = size
        self.front = self.c.y - self.d / 2
        self.top = self.c.z + self.h / 2
        self.bottom = self.c.z - self.h / 2


def build_face(b, spec):
    eyes = spec.get('eyes', 'cute')
    ez = b.c.z + b.h * spec.get('eye_z', 0.08)
    ex = b.w * spec.get('eye_x', 0.22)
    fy = b.front - 0.02
    size = spec.get('eye_size', 1.0) * min(b.w, b.h)
    for s in (-1, 1):
        if eyes == 'cute':
            ball('Eye', (s * ex, fy - 0.02, ez), (0.13 * size, 0.06 * size, 0.17 * size), '14182a')
            ball('EyeShine', (s * ex - 0.04 * size, fy - 0.07 * size, ez + 0.06 * size), (0.045 * size, 0.02 * size, 0.05 * size), 'ffffff', seg=10)
            ball('EyeShine', (s * ex + 0.035 * size, fy - 0.07 * size, ez - 0.05 * size), (0.022 * size, 0.012 * size, 0.024 * size), 'ffffff', seg=8)
        else:
            kind, color = eyes
            tilt = -18 * s if kind == 'angry' else 0
            ball('GlowEye', (s * ex, fy - 0.02, ez), (0.15 * size, 0.05 * size, 0.1 * size if kind == 'angry' else 0.15 * size), color, glow=True,
                 rot=rot_y(tilt))
    mouth = spec.get('mouth', 'smile')
    mz = ez - 0.2 * size
    if mouth == 'smile':
        tube('Mouth', curve((-0.08 * size, fy - 0.02, mz + 0.02 * size), (0.08 * size, fy - 0.02, mz + 0.02 * size),
                            (0, 0, -0.06 * size), 0.018 * size, 0.018 * size, 6), '14182a', seg=6, cap_tip=False)
    elif mouth == 'open':
        ball('Mouth', (0, fy - 0.01, mz), (0.08 * size, 0.04 * size, 0.07 * size), '5a1020')
        ball('Tongue', (0, fy - 0.03, mz - 0.03 * size), (0.05 * size, 0.03 * size, 0.035 * size), 'ff7a9a', seg=10)
    elif mouth == 'fangs':
        ball('Mouth', (0, fy - 0.01, mz), (0.11 * size, 0.04 * size, 0.05 * size), '2a0610')
        for s in (-1, 1):
            cone('Fang', (s * 0.05 * size, fy - 0.03, mz + 0.03 * size), (s * 0.05 * size, fy - 0.03, mz - 0.05 * size), 0.022 * size, 0, 'ffffff', seg=6)
    if spec.get('snout'):
        ball('Snout', (0, fy - 0.03, mz + 0.06 * size), (0.16 * size, 0.08 * size, 0.1 * size), spec['snout'])
        ball('Nose', (0, fy - 0.1 * size, mz + 0.11 * size), (0.05 * size, 0.03 * size, 0.035 * size), '2a1a1a', seg=10)
    if spec.get('beak'):
        cone('Beak', (0, fy + 0.02, mz + 0.06 * size), (0, fy - 0.22 * size, mz + 0.03 * size), 0.09 * size, 0.01, spec['beak'], seg=8)
    if spec.get('blush', True) and eyes == 'cute':
        for s in (-1, 1):
            ball('Blush', (s * (ex + 0.1 * size), fy - 0.005, mz + 0.04 * size), (0.06 * size, 0.02 * size, 0.035 * size), 'ff8fb0', seg=10)


def build_body(spec):
    shape = spec.get('body', 'cube')
    color = spec['color']
    w, d, h = spec.get('size', (1.6, 1.4, 1.5))
    feet = spec.get('feet', True)
    lift = 0.22 if feet else 0.0
    center = (0, 0, lift + h / 2)
    b = Body(center, (w, d, h))
    if shape == 'cube':
        rbox('Body', center, (w, d, h), color, rnd=spec.get('round', 0.28))
    elif shape == 'ball':
        ball('Body', center, (w / 2, d / 2, h / 2), color)
    elif shape == 'gem':
        gem('Body', (0, 0, lift + h * 0.62), w / 2, h, color, glow=spec.get('glow_body', False))
        b = Body((0, 0, lift + h * 0.55), (w * 0.9, d, h * 0.8))
    elif shape == 'chest':
        rbox('Body', (0, 0, lift + h * 0.35), (w, d, h * 0.7), color, rnd=0.12)
        rbox('Lid', (0, 0.05, lift + h * 0.82), (w * 1.02, d * 1.02, h * 0.3), spec.get('lid', color), rnd=0.3)
        for x in (-w * 0.38, w * 0.38):
            rbox('Band', (x, 0, lift + h * 0.5), (w * 0.09, d * 1.05, h * 1.0), spec.get('trim', 'f2c14e'), rnd=0.2)
        b = Body((0, 0, lift + h * 0.5), (w, d, h))
    elif shape == 'tv':
        rbox('Body', center, (w, d, h), color, rnd=0.15)
        rbox('Screen', (0, -d / 2 - 0.01, lift + h * 0.52), (w * 0.8, 0.06, h * 0.7), spec.get('screen', '6ee7ff'), rnd=0.2, glow=True)
        for s in (-1, 1):
            cone('Antenna', (s * 0.15, 0, lift + h), (s * 0.55, 0.1, lift + h + 0.7), 0.04, 0.02, '3b4252', seg=6)
    elif shape == 'mushroom':
        rbox('Body', (0, 0, lift + h * 0.35), (w * 0.72, d * 0.72, h * 0.7), spec.get('stem', 'fff1dc'), rnd=0.35)
        ball('Cap', (0, 0, lift + h * 0.78), (w * 0.72, d * 0.72, h * 0.42), color)
        for k, (x, y, z) in enumerate(((-0.35, -0.45, 0.95), (0.4, -0.35, 1.05), (0.0, -0.2, 1.25), (-0.55, 0.2, 1.1), (0.55, 0.25, 1.0))):
            ball('CapSpot', (x * w, y * d, lift + z * h), (0.12 * w, 0.12 * w, 0.06 * w), spec.get('spots', 'ffffff'), seg=10)
        b = Body((0, 0, lift + h * 0.35), (w * 0.72, d * 0.72, h * 0.7))
    elif shape == 'cupcake':
        cone('Body', (0, 0, lift), (0, 0, lift + h * 0.55), w * 0.36, w * 0.5, spec.get('cup', 'ff8fb8'), seg=16, smooth=False)
        ball('Frosting', (0, 0, lift + h * 0.68), (w * 0.52, d * 0.52, h * 0.32), color)
        ball('Frosting', (0, 0, lift + h * 0.92), (w * 0.3, d * 0.3, h * 0.2), color)
        ball('Cherry', (0, 0, lift + h * 1.12), (0.16, 0.16, 0.16), 'e8243c', seg=12)
        b = Body((0, 0, lift + h * 0.4), (w * 0.9, d * 0.9, h * 0.7))
    elif shape == 'donut':
        torus('Body', (0, 0, lift + h / 2), h * 0.34, h * 0.17, color, rot=rot_x(90))
        torus('Icing', (0, -0.05, lift + h / 2), h * 0.34, h * 0.14, spec.get('icing', 'ff7fc8'), rot=rot_x(90))
        b = Body((0, 0, lift + h / 2), (h * 0.9, d, h * 0.9))
    elif shape == 'hourglass':
        cone('Glass', (0, 0, lift + h * 0.5), (0, 0, lift + 0.08), 0.12, w * 0.45, 'bfe9ff', seg=16)
        cone('Glass', (0, 0, lift + h * 0.5), (0, 0, lift + h - 0.08), 0.12, w * 0.45, 'bfe9ff', seg=16)
        cone('Sand', (0, 0, lift + 0.08), (0, 0, lift + h * 0.3), w * 0.4, w * 0.08, 'ffc94d', glow=True, seg=16)
        for z in (lift, lift + h):
            rbox('Frame', (0, 0, z), (w * 1.05, d * 1.05, 0.16), color, rnd=0.3)
        for x in (-w * 0.5, w * 0.5):
            rbox('Pillar', (x, 0, lift + h / 2), (0.14, 0.14, h), color, rnd=0.3)
        b = Body((0, 0, lift + h * 0.55), (w * 0.7, d * 0.8, h * 0.6))
    elif shape == 'manta':
        slab('Body', [(-w / 2, 0), (-w * 0.2, h * 0.25), (0, h * 0.3), (w * 0.2, h * 0.25), (w / 2, 0), (w * 0.15, -h * 0.2), (0, -h * 0.25),
                      (-w * 0.15, -h * 0.2)], d * 0.35, Matrix.Translation(center) @ rot_x(90), color)
        cone('Tail', (0, d * 0.2, lift + h / 2), (0, d * 1.6, lift + h / 2), 0.08, 0.01, color, seg=6)
        b = Body(center, (w * 0.45, d * 0.35, h * 0.45))
        b.front = -d * 0.28
    if spec.get('belly'):
        ball('Belly', (0, b.front + 0.02, b.c.z - b.h * 0.18), (b.w * 0.3, 0.06, b.h * 0.22), spec['belly'])
    if feet and shape in ('cube', 'ball'):
        fc = spec.get('feet_color', color)
        for x in (-w * 0.28, w * 0.28):
            for y in (-d * 0.25, d * 0.25):
                rbox('Foot', (x, y, 0.14), (w * 0.24, d * 0.24, 0.28), fc, rnd=0.45)
    return b


def ears(b, kind, color, inner=None):
    top, w = b.top, b.w
    for s in (-1, 1):
        if kind == 'cat':
            cone('Ear', (s * w * 0.3, 0, top - 0.08), (s * w * 0.36, 0, top + w * 0.36), w * 0.17, 0.0, color, seg=4)
            if inner:
                cone('EarInner', (s * w * 0.3, -0.06, top - 0.04), (s * w * 0.35, -0.06, top + w * 0.27), w * 0.1, 0.0, inner, seg=4)
        elif kind == 'fox':
            cone('Ear', (s * w * 0.3, 0.02, top - 0.08), (s * w * 0.42, 0.02, top + w * 0.46), w * 0.2, 0.0, color, seg=4)
            if inner:
                cone('EarInner', (s * w * 0.31, -0.07, top - 0.02), (s * w * 0.4, -0.07, top + w * 0.33), w * 0.11, 0.0, inner, seg=4)
        elif kind == 'fennec':
            cone('Ear', (s * w * 0.3, 0.02, top - 0.1), (s * w * 0.62, 0.02, top + w * 0.75), w * 0.24, 0.0, color, seg=4)
            if inner:
                cone('EarInner', (s * w * 0.32, -0.08, top), (s * w * 0.58, -0.08, top + w * 0.6), w * 0.14, 0.0, inner, seg=4)
        elif kind == 'bunny':
            rbox('Ear', (s * w * 0.22, 0.05, top + w * 0.42), (w * 0.2, w * 0.13, w * 0.85), color, rnd=0.45, rot=rot_y(-s * 8))
            if inner:
                rbox('EarInner', (s * w * 0.22, -0.02, top + w * 0.42), (w * 0.1, w * 0.06, w * 0.6), inner, rnd=0.45, rot=rot_y(-s * 8))
        elif kind == 'dog':
            rbox('Ear', (s * (w * 0.47), 0, b.c.z + b.h * 0.22), (w * 0.16, w * 0.3, w * 0.5), color, rnd=0.45, rot=rot_y(s * 25))
        elif kind == 'bear':
            ball('Ear', (s * w * 0.36, 0, top + 0.02), (w * 0.15, w * 0.1, w * 0.15), color)
            if inner:
                ball('EarInner', (s * w * 0.36, -0.07, top + 0.02), (w * 0.08, w * 0.05, w * 0.08), inner, seg=10)
        elif kind == 'owl':
            cone('Ear', (s * w * 0.32, 0, top - 0.05), (s * w * 0.46, 0, top + w * 0.28), w * 0.12, 0.0, color, seg=4)


def wings(b, kind, color, color2=None, glow=False, scale=1.0):
    y = b.c.y + b.d * 0.3
    z = b.c.z + b.h * 0.15
    s_ = scale * max(b.w, b.h)
    if kind == 'feather':
        outline = [(0, 0), (0.25, 0.55), (0.55, 0.85), (0.95, 1.0), (0.85, 0.75), (1.05, 0.62), (0.88, 0.42), (1.02, 0.3), (0.8, 0.12),
                   (0.85, -0.02), (0.55, -0.15), (0.25, -0.2)]
    elif kind == 'bat':
        outline = [(0, 0), (0.2, 0.55), (0.55, 0.95), (1.1, 0.9), (0.9, 0.55), (0.95, 0.2), (0.7, 0.35), (0.62, 0.02), (0.4, 0.2), (0.3, -0.15)]
    elif kind == 'bee':
        outline = [(0.5 + 0.5 * math.cos(a) * 1.0, 0.35 + 0.35 * math.sin(a)) for a in [i * math.pi / 8 for i in range(16)]]
    elif kind == 'fairy':
        outline = [(0.4 + 0.45 * math.cos(a), 0.45 + 0.42 * math.sin(a)) for a in [i * math.pi / 8 for i in range(16)]]
    else:  # 'fire'
        outline = [(0, 0), (0.3, 0.5), (0.45, 1.05), (0.62, 0.62), (0.85, 1.0), (0.9, 0.55), (1.15, 0.7), (0.95, 0.25), (0.6, -0.05), (0.3, -0.2)]
    for s in (-1, 1):
        pts = [(s * x * s_, zz * s_) for x, zz in outline]
        if s < 0:
            pts.reverse()
        m = Matrix.Translation((s * b.w * 0.35, y, z)) @ rot_z(s * 18) @ rot_y(-s * 12)
        slab('Wing', pts, 0.08, m, color, glow)
        if color2 and kind in ('feather', 'fairy', 'bee'):
            inner = [(x * 0.6, zz * 0.6 + 0.08 * s_) for x, zz in pts]
            slab('WingInner', inner, 0.1, m @ Matrix.Translation((0, -0.02, 0)), color2, glow)


def horns(b, color, glow=False, size=1.0):
    for s in (-1, 1):
        base = Vector((s * b.w * 0.28, b.c.y, b.top - 0.1))
        tip = base + Vector((s * 0.45, 0.25, 0.9)) * size * b.w
        tube('Horn', curve(base, tip, Vector((s * 0.25, 0, 0.1)) * size * b.w, 0.14 * size * b.w, 0.02, 9), color, glow)


def antlers(b, color, glow=False):
    for s in (-1, 1):
        base = Vector((s * b.w * 0.25, b.c.y, b.top - 0.05))
        main = base + Vector((s * 0.55, 0.15, 1.0)) * b.w
        tube('Antler', curve(base, main, Vector((s * 0.2, 0, 0)), 0.07 * b.w, 0.03, 8), color, glow, seg=8)
        for t, dx, dz in ((0.45, 0.35, 0.25), (0.75, 0.3, 0.2)):
            p = base.lerp(main, t)
            tube('Antler', curve(p, p + Vector((s * dx * 0.3, 0, dz)) * b.w * 1.4, Vector((0, 0, 0.05)), 0.05 * b.w, 0.02, 5), color, glow, seg=8)


def crown(b, color='ffcc33', gem_color='ff3b6b'):
    z = b.top
    ring = [(math.cos(a) * b.w * 0.3, math.sin(a) * b.d * 0.3) for a in [i * 2 * math.pi / 6 for i in range(6)]]
    torus('CrownBand', (0, b.c.y, z + 0.06), b.w * 0.3, 0.07, color)
    for x, y in ring:
        cone('CrownSpike', (x, b.c.y + y, z + 0.06), (x * 1.1, b.c.y + y * 1.1, z + 0.45), 0.09, 0.02, color, seg=6)
    ball('CrownGem', (0, b.c.y - b.d * 0.3, z + 0.12), (0.08, 0.05, 0.08), gem_color, glow=True, seg=10)


def halo(b, color='fff3a0'):
    torus('Halo', (0, b.c.y, b.top + 0.45), b.w * 0.32, 0.06, color, glow=True)


def tail(b, kind, color, color2=None, glow=False):
    back = b.c.y + b.d / 2
    z = b.c.z - b.h * 0.15
    if kind == 'curl':
        ball('Tail', (0, back + 0.08, z + 0.1), (0.18, 0.18, 0.18), color)
    elif kind == 'fluffy':
        ball('Tail', (0, back + 0.45, z + 0.35), (0.25, 0.5, 0.25), color, rot=rot_x(-35))
        if color2:
            ball('TailTip', (0, back + 0.82, z + 0.62), (0.14, 0.2, 0.14), color2, rot=rot_x(-35))
    elif kind == 'long':
        tube('Tail', curve((0, back - 0.05, z), (0, back + 1.1, z + 0.6), (0, 0.1, 0.4), 0.13, 0.03, 10), color, glow)
    elif kind == 'stinger':
        tube('Tail', curve((0, back - 0.05, z + 0.1), (0, back - 0.1, b.top + 0.55), (0, 0.9, 0.3), 0.14, 0.08, 12), color)
        cone('Stinger', (0, back - 0.1, b.top + 0.55), (0, back - 0.45, b.top + 0.35), 0.1, 0.0, color2 or '2a1a1a', glow, seg=8)
    elif kind == 'flame':
        cone('Tail', (0, back - 0.05, z + 0.1), (0, back + 0.8, z + 0.7), 0.22, 0.02, color, glow=True, seg=8)


def stripes(b, color, n=3):
    for i in range(n):
        z = b.bottom + b.h * (0.25 + 0.5 * i / max(n - 1, 1))
        rbox('Stripe', (0, b.c.y, z), (b.w * 1.02, b.d * 1.02, b.h * 0.1), color, rnd=0.4)


def cracks(b, color):
    for k, (x, z, ang, ln) in enumerate(((-0.3, -0.25, 30, 0.35), (0.25, -0.3, -40, 0.3), (0.38, 0.25, 70, 0.25), (-0.35, 0.3, -60, 0.22))):
        rbox('Crack', (x * b.w, b.front - 0.01, b.c.z + z * b.h), (ln * b.w, 0.04, 0.05), color, rnd=0.3, glow=True, rot=rot_y(ang))


def crystals(b, color, glow=True, n=3):
    for k in range(n):
        x = (k - (n - 1) / 2) * b.w * 0.3
        gem('Crystal', (x, b.c.y + 0.05, b.top + 0.25 + 0.1 * (k % 2)), 0.15, 0.55, color, glow, turn=k)


def shards(b, color, glow=True):
    for k, (x, y, z) in enumerate(((-1.1, -0.3, 0.3), (1.1, -0.2, 0.45), (-0.85, -0.4, 1.25), (0.9, -0.3, 1.2))):
        gem('Shard', (x * b.w, y, b.c.z + (z - 0.6) * b.h), 0.13, 0.4, color, glow, turn=k)


def stars(b, color, glow=True):
    for k, (x, z, sc) in enumerate(((-0.8, 0.9, 0.22), (0.85, 0.75, 0.18), (0.0, 1.15, 0.15))):
        slab('Star', star_outline(sc * 1.5, sc * 0.6), 0.08, Matrix.Translation((x * b.w, b.c.y, b.c.z + z * b.h)), color, glow)


def rings(b, color, glow=True):
    torus('Ring', b.c.copy(), max(b.w, b.h) * 0.72, 0.05, color, glow, rot=rot_x(75) @ rot_y(20))
    torus('Ring', b.c.copy(), max(b.w, b.h) * 0.8, 0.04, color, glow, rot=rot_x(105) @ rot_y(-25))


def flame_crest(b, color):
    for k, (x, hgt) in enumerate(((-0.2, 0.55), (0.0, 0.8), (0.2, 0.55))):
        cone('Flame', (x * b.w, b.c.y, b.top - 0.05), (x * b.w * 1.3, b.c.y + 0.1, b.top + hgt), 0.18, 0.01, color, glow=True, seg=8)


def leaf_crown(b, color, color2=None):
    for k, (x, y) in enumerate(((-0.25, 0.1), (0.25, 0.1), (0.0, -0.05), (0.0, 0.25))):
        ball('Leaf', (x * b.w, b.c.y + y, b.top + 0.18), (0.32 * b.w, 0.22 * b.w, 0.2 * b.w), color if k % 2 == 0 else (color2 or color))


def hump(b, color):
    ball('Hump', (0, b.c.y + 0.1, b.top + 0.1), (b.w * 0.28, b.d * 0.3, 0.32), color)


def headdress(b, c1, c2):
    rbox('Headdress', (0, b.c.y + 0.05, b.c.z + b.h * 0.05), (b.w * 1.12, b.d * 0.95, b.h * 1.05), c1, rnd=0.25)
    for i in range(4):
        rbox('HeaddressStripe', (0, b.c.y + 0.05, b.bottom + b.h * (0.25 + 0.18 * i)), (b.w * 1.14, b.d * 0.97, b.h * 0.07), c2, rnd=0.3)
    rbox('Face', (0, b.front - 0.02, b.c.z - b.h * 0.05), (b.w * 0.72, 0.1, b.h * 0.72), 'ffd98a', rnd=0.25)


def claws(b, color):
    for s in (-1, 1):
        base = Vector((s * b.w * 0.42, b.front, b.c.z - b.h * 0.2))
        ball('Claw', base + Vector((s * 0.1, -0.25, 0.0)), (0.3, 0.32, 0.2), color)
        cone('Pincer', base + Vector((s * 0.02, -0.45, 0.05)), base + Vector((s * -0.12, -0.8, 0.08)), 0.12, 0.02, color, seg=6)
        cone('Pincer', base + Vector((s * 0.2, -0.45, 0.05)), base + Vector((s * 0.3, -0.75, 0.08)), 0.1, 0.02, color, seg=6)


def hood(b, color, color2):
    slab('Hood', [(-b.w * 0.9, 0), (-b.w * 0.7, b.h * 0.7), (0, b.h * 0.95), (b.w * 0.7, b.h * 0.7), (b.w * 0.9, 0), (0, -b.h * 0.2)], 0.12,
         Matrix.Translation((0, b.c.y + b.d * 0.25, b.c.z - b.h * 0.05)), color)
    slab('HoodInner', [(-b.w * 0.55, 0.05), (-b.w * 0.4, b.h * 0.55), (0, b.h * 0.7), (b.w * 0.4, b.h * 0.55), (b.w * 0.55, 0.05)], 0.14,
         Matrix.Translation((0, b.c.y + b.d * 0.2, b.c.z - b.h * 0.05)), color2)


def sprinkles(b, colors):
    import random
    rnd = random.Random(7)
    for k in range(14):
        a = rnd.random() * 2 * math.pi
        r = rnd.random() * 0.45
        x = math.cos(a) * r * b.w
        z = b.top - 0.05 + math.sin(a) * 0.05
        rbox('Sprinkle', (x, b.c.y + (rnd.random() - 0.5) * b.d * 0.6, z + 0.02), (0.14, 0.04, 0.04), colors[k % len(colors)], rnd=0.45,
             rot=rot_z(rnd.random() * 180))


def gem_eye_glow(b, color):
    ball('ForeheadGem', (0, b.front - 0.02, b.c.z + b.h * 0.34), (0.1, 0.05, 0.1), color, glow=True, seg=12)


EXTRAS = {
    'ears': lambda b, *a: ears(b, *a), 'wings': lambda b, *a: wings(b, *a), 'horns': lambda b, *a: horns(b, *a),
    'antlers': lambda b, *a: antlers(b, *a), 'crown': lambda b, *a: crown(b, *a), 'halo': lambda b, *a: halo(b, *a),
    'tail': lambda b, *a: tail(b, *a), 'stripes': lambda b, *a: stripes(b, *a), 'cracks': lambda b, *a: cracks(b, *a),
    'crystals': lambda b, *a: crystals(b, *a), 'shards': lambda b, *a: shards(b, *a), 'stars': lambda b, *a: stars(b, *a),
    'rings': lambda b, *a: rings(b, *a), 'flame': lambda b, *a: flame_crest(b, *a), 'leaves': lambda b, *a: leaf_crown(b, *a),
    'hump': lambda b, *a: hump(b, *a), 'headdress': lambda b, *a: headdress(b, *a), 'claws': lambda b, *a: claws(b, *a),
    'hood': lambda b, *a: hood(b, *a), 'sprinkles': lambda b, *a: sprinkles(b, *a), 'forehead': lambda b, *a: gem_eye_glow(b, *a),
}


# ---------------------------------------------------------------- the pets
C = 'cube'
PETS = [
    # Grasslands
    ('Grasslands', 'Puppy', dict(color='e8b577', snout='fff0d8', ears=('dog', 'b07a45'), tail=('curl', 'e8b577'), mouth='open')),
    ('Grasslands', 'Bunny', dict(color='ffffff', ears=('bunny', 'ffffff', 'ffb3c8'), tail=('curl', 'ffffff'), belly='ffe6ef')),
    ('Grasslands', 'Bee', dict(color='ffd23f', size=(1.5, 1.3, 1.4), extras=[('stripes', '2b2b36', 2), ('wings', 'bee', 'e9fbff', 'c8f1ff')],
                               antennae=True, feet_color='2b2b36', tail=('stinger_small',))),
    ('Grasslands', 'Fox', dict(color='ff8a3d', snout='fff4e6', ears=('fox', 'ff8a3d', 'fff4e6'), tail=('fluffy', 'ff8a3d', 'ffffff'), belly='fff4e6')),
    ('Grasslands', 'Leaf Dragon', dict(color='5fd068', belly='c8f7a8', extras=[('horns', 'fff3b0'), ('wings', 'bat', '3fae4f'), ('leaves', '2f9e4f', '7be07b')],
                                       tail=('long', '5fd068'), mouth='open')),
    ('Grasslands', 'Crowned Stag', dict(color='b87a4b', snout='f3dcc0', extras=[('antlers', 'ffd24a', True), ('crown',)], ears=('cat', 'b87a4b', 'f3dcc0'),
                                        eyes=('angry', 'ffe066'))),
    ('Grasslands', 'World Tree Guardian', dict(color='8a5a36', size=(1.8, 1.5, 1.8), eyes=('glow', '7dff8a'), mouth=None,
                                               extras=[('leaves', '3fbf5f', '7be07b'), ('cracks', '7dff8a'), ('crystals', '7dff8a')])),
    # Desert
    ('Desert', 'Camel', dict(color='e2b77a', snout='f4dcb4', extras=[('hump', 'e2b77a')], ears=('bear', 'c99a5c'), tail=('curl', 'c99a5c'))),
    ('Desert', 'Cobra', dict(color='67c04d', size=(1.3, 1.2, 1.7), feet=False, belly='f6e27a', mouth='fangs', extras=[('hood', '4f9e3b', 'f6e27a')])),
    ('Desert', 'Scorpion', dict(color='d0553a', size=(1.6, 1.5, 1.2), extras=[('claws', 'd0553a')], tail=('stinger', 'd0553a', '2a1a1a'))),
    ('Desert', 'Fennec', dict(color='f2c587', snout='fff6e6', ears=('fennec', 'f2c587', 'ffd9d9'), tail=('fluffy', 'f2c587', 'fff6e6'))),
    ('Desert', 'Scarab', dict(color='1fb5a8', size=(1.6, 1.5, 1.3), eyes=('glow', 'ffd24a'), mouth=None,
                              extras=[('stripes', 'ffd24a', 2), ('forehead', 'ffd24a')], feet_color='0f6e67')),
    ('Desert', 'Sphinx', dict(color='f2c26b', extras=[('headdress', '2c5fd6', 'ffd24a'), ('crown', 'ffd24a', '2c5fd6')], eyes=('glow', '66e0ff'),
                              tail=('long', 'f2c26b'))),
    ('Desert', 'Sandclock Colossus', dict(body='hourglass', color='c98a3a', size=(1.5, 1.4, 2.0), feet=False, eyes=('glow', 'ffe066'), mouth=None,
                                          extras=[('shards', 'ffd24a')])),
    # Ice
    ('Ice', 'Penguin', dict(color='27324a', belly='ffffff', beak='ffb030', mouth=None, feet_color='ffb030', extras=[('wings', 'bat', '27324a')])),
    ('Ice', 'Polar Cub', dict(color='f5fbff', snout='ffffff', ears=('bear', 'f5fbff', 'cfe8ff'), belly='e3f2ff')),
    ('Ice', 'Snow Bunny', dict(color='dff4ff', ears=('bunny', 'dff4ff', 'a8dcff'), tail=('curl', 'ffffff'), extras=[('crystals', 'a8e6ff')])),
    ('Ice', 'Ice Wolf', dict(color='9fd4ff', snout='e8f6ff', ears=('fox', '9fd4ff', 'e8f6ff'), tail=('fluffy', '9fd4ff', 'e8f6ff'), eyes=('angry', '66e0ff'))),
    ('Ice', 'Frost Dragon', dict(color='7cc8ff', belly='e0f4ff', extras=[('horns', 'e0f4ff'), ('wings', 'bat', 'a8dcff'), ('crystals', 'bff0ff')],
                                 tail=('long', '7cc8ff'), mouth='open')),
    ('Ice', 'Aurora Owl', dict(color='5a6bd6', belly='d9e0ff', beak='ffb030', mouth=None, ears=('owl', '5a6bd6'), eyes=('glow', '7dfff0'),
                               extras=[('wings', 'feather', '8ef0d8', 'c89bff', True)])),
    ('Ice', 'Frozen TV', dict(body='tv', color='9fb4c8', screen='6ee7ff', size=(1.7, 1.2, 1.4), eyes=('glow', 'ffffff'), mouth=None,
                              extras=[('crystals', 'bff0ff')])),
    # Enchanted
    ('Enchanted', 'Fairy Cat', dict(color='c9a4ff', ears=('cat', 'c9a4ff', 'ffc2e8'), tail=('long', 'c9a4ff'), extras=[('wings', 'fairy', 'ffc2f0', 'bff0ff')])),
    ('Enchanted', 'Mushroom', dict(body='mushroom', color='ff5a6e', spots='ffffff', feet=False)),
    ('Enchanted', 'Crystal Bunny', dict(color='e9dcff', ears=('bunny', 'c9a4ff', 'ff9bdc'), extras=[('crystals', 'd28bff')], tail=('curl', 'ffffff'))),
    ('Enchanted', 'Spirit Fox', dict(color='8fe8ff', ears=('fox', '8fe8ff', 'ffffff'), tail=('fluffy', '8fe8ff', 'ffffff'), eyes=('glow', 'ffffff'),
                                     extras=[('forehead', 'ff8cf0')])),
    ('Enchanted', 'Mystic Dragon', dict(color='9b5cff', belly='e0cbff', extras=[('horns', 'ffd24a'), ('wings', 'bat', '6f3ad6'), ('forehead', 'ff8cf0')],
                                        tail=('long', '9b5cff'), mouth='open')),
    ('Enchanted', 'Crystal Deer', dict(color='f5d7ff', snout='ffffff', extras=[('antlers', 'b58cff', True), ('crown', 'ffd24a', 'ff8cf0')],
                                       ears=('cat', 'f5d7ff', 'ffc2e8'), eyes=('glow', 'd28bff'))),
    ('Enchanted', 'Moon Mask', dict(body='cube', color='f3f0ff', size=(1.6, 0.8, 1.9), feet=False, eyes=('angry', '9b5cff'), mouth='fangs',
                                    extras=[('horns', 'c9a4ff', True), ('stars', 'ffe066')])),
    # Crystal Seraph (Secret) has its own script: build_crystal_seraph.py
    # Volcano
    ('Volcano', 'Lava Pup', dict(color='3a2a2e', snout='5a3a3e', ears=('dog', '2a1e22'), tail=('flame', 'ff6a1a'), extras=[('cracks', 'ff6a1a')],
                                 eyes=('glow', 'ffb030'))),
    ('Volcano', 'Fire Bat', dict(color='4a2a3a', ears=('cat', '4a2a3a', 'ff6a1a'), extras=[('wings', 'bat', 'ff5a2a', None, True)], mouth='fangs',
                                 eyes=('glow', 'ffd24a'))),
    ('Volcano', 'Ember Lizard', dict(color='ff7a2a', belly='ffd07a', tail=('long', 'ff7a2a'), extras=[('flame', 'ffb030')], mouth='open')),
    ('Volcano', 'Demon', dict(color='d62d3a', extras=[('horns', '2a1a1a'), ('wings', 'bat', '8a1a24')], mouth='fangs', eyes=('angry', 'ffd24a'),
                              tail=('long', 'd62d3a'))),
    ('Volcano', 'Magma Golem', dict(color='4a3a3a', size=(1.8, 1.5, 1.7), eyes=('glow', 'ff8a1a'), mouth=None, extras=[('cracks', 'ff6a1a'), ('flame', 'ff6a1a')])),
    ('Volcano', 'Phoenix', dict(color='ff5a2a', belly='ffd07a', beak='ffd24a', mouth=None, eyes=('glow', 'fff1a0'),
                                extras=[('wings', 'fire', 'ff8a1a', None, True), ('flame', 'ffd24a')], tail=('flame', 'ff8a1a'))),
    ('Volcano', 'Infernal Chest', dict(body='chest', color='6a2a2a', lid='8a3a2a', trim='ffd24a', size=(1.8, 1.3, 1.6), feet=False, eyes=('angry', 'ff6a1a'),
                                       mouth='fangs', extras=[('horns', '2a1a1a')])),
    # Candy
    ('Candy', 'Cupcake', dict(body='cupcake', color='fff0f6', cup='ff8fb8', size=(1.6, 1.6, 1.6), feet=False, eye_z=-0.12,
                              extras=[('sprinkles', ['ff5a8a', '5ad0ff', 'ffe066', '7be07b'])])),
    ('Candy', 'Marshmallow', dict(color='fff6fb', size=(1.5, 1.4, 1.4), round=0.4, belly='ffe0ee')),
    ('Candy', 'Gummy Bear', dict(color='ff5a7a', ears=('bear', 'ff5a7a'), glow_parts=False, belly='ff8fa4')),
    ('Candy', 'Donut', dict(body='donut', color='e0a45a', icing='ff7fc8', size=(1.6, 0.8, 1.6), feet=False, eye_z=0.28, eye_x=0.2,
                            extras=[('sprinkles', ['ffffff', '5ad0ff', 'ffe066'])])),
    ('Candy', 'Candy Dog', dict(color='ffb3d9', snout='ffffff', ears=('dog', 'ff7fc8'), tail=('curl', 'ff7fc8'), extras=[('stripes', 'ffffff', 3)])),
    ('Candy', 'Cake Dragon', dict(color='ffd6e8', belly='fff6fb', extras=[('horns', 'ffffff'), ('wings', 'bat', 'ff8fc8'), ('sprinkles', ['ff5a8a', '5ad0ff'])],
                                  tail=('long', 'ffd6e8'), mouth='open', eyes=('glow', 'ff5fa8'))),
    ('Candy', 'Chocolate Chicken', dict(color='7a4a2e', belly='a8693e', beak='ffb030', mouth=None, eyes=('glow', 'ffd24a'),
                                        extras=[('wings', 'feather', '5a3420', 'a8693e'), ('crown', 'ffd24a', 'ff5a8a')], feet_color='ffb030')),
    # Celestial
    ('Celestial', 'Star Pup', dict(color='2c3a8c', snout='e8ecff', ears=('dog', '1f2a6c'), extras=[('stars', 'ffe066')], tail=('curl', 'ffe066'))),
    ('Celestial', 'Cosmic Cat', dict(color='5b2c8c', ears=('cat', '5b2c8c', 'ff8cf0'), extras=[('stars', 'ff8cf0'), ('forehead', '7dfff0')],
                                     tail=('long', '5b2c8c'))),
    ('Celestial', 'Star Sprite', dict(body='ball', color='ffe066', size=(1.4, 1.3, 1.4), feet=False, extras=[('wings', 'fairy', 'fff6c0', 'bff0ff'), ('halo',)])),
    ('Celestial', 'Angel', dict(color='ffffff', extras=[('wings', 'feather', 'ffffff', 'e6f0ff'), ('halo',)], ears=('bear', 'ffffff', 'ffe0ee'))),
    ('Celestial', 'Void Ray', dict(color='2a1a4a', size=(1.8, 1.4, 1.2), feet=False, eyes=('angry', 'c86bff'), mouth='fangs', round=0.4,
                                   extras=[('wings', 'bat', '6b2fd6', None, True, 1.2), ('stars', 'c86bff')], tail=('long', '2a1a4a'))),
    ('Celestial', 'Celestial Dragon', dict(color='f5f0ff', belly='fff3c0', extras=[('horns', 'ffd24a'), ('wings', 'feather', 'ffe066', 'fff6c0', True),
                                                                                   ('halo',)], tail=('long', 'f5f0ff'), eyes=('glow', '66e0ff'))),
    ('Celestial', 'Orbit Guardian', dict(body='ball', color='232c6c', size=(1.6, 1.5, 1.6), feet=False, eyes=('angry', '66e0ff'), mouth=None,
                                         extras=[('rings', 'ffd24a'), ('halo', '7dfff0'), ('stars', '66e0ff')])),
]


def build(biome, name, spec):
    global COL
    col_name = f'Pet_{biome}_{name.replace(" ", "")}' if name != 'Crystal Seraph' else 'Pet_Secret_CrystalSeraph'
    COL = bpy.data.collections.new(col_name)
    scene.collection.children.link(COL)
    COUNT.clear()
    b = build_body(spec)
    build_face(b, spec)
    if spec.get('ears'):
        ears(b, *spec['ears'])
    if spec.get('antennae'):
        for s in (-1, 1):
            tube('Antenna', curve((s * 0.2, 0, b.top - 0.05), (s * 0.45, -0.1, b.top + 0.6), (s * 0.05, 0, 0.1), 0.04, 0.03, 6), '2b2b36', seg=6)
            ball('AntennaTip', (s * 0.46, -0.12, b.top + 0.65), (0.1, 0.1, 0.1), '2b2b36', seg=10)
    if spec.get('tail'):
        kind = spec['tail'][0]
        if kind == 'stinger_small':
            cone('Stinger', (0, b.c.y + b.d / 2 - 0.05, b.c.z - 0.2), (0, b.c.y + b.d / 2 + 0.4, b.c.z - 0.3), 0.12, 0, '2b2b36', seg=8)
        else:
            tail(b, *spec['tail'])
    for extra in spec.get('extras', []):
        EXTRAS[extra[0]](b, *extra[1:])
    return col_name, COL


# ---------------------------------------------------------------- output
def objects_of(col):
    return [o for o in col.objects if o.type == 'MESH']


def export(col_name, col):
    bpy.ops.object.select_all(action='DESELECT')
    objs = objects_of(col)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=str(ROOT / 'exports' / f'{col_name}.fbx'), use_selection=True, object_types={'MESH'}, axis_forward='-Z',
                             axis_up='Y', add_leaf_bones=False, bake_anim=False)


def setup_render():
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.view_settings.view_transform = 'Standard'
    scene.render.film_transparent = True
    world = bpy.data.worlds.new('World')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.9, 0.92, 1.0, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
    sun.data.energy = 2.5
    sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(-25))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
    cam.data.type = 'ORTHO'
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame(cam, objs, margin=1.15, direction=(0.45, -1.0, 0.35)):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    size = max(hi.x - lo.x, hi.z - lo.z) * margin
    direction = Vector(direction).normalized()
    cam.location = center + direction * 30
    cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = size
    cam.data.clip_end = 100


def main():
    cam = setup_render()
    built = []
    for biome, name, spec in PETS:
        if ONLY and name not in ONLY:
            continue
        col_name, col = build(biome, name, spec)
        built.append((col_name, col))
        if not SHEET_ONLY:
            export(col_name, col)
            for other, oc in built:
                oc.hide_render = other != col_name
            frame(cam, objects_of(col))
            scene.render.resolution_x = scene.render.resolution_y = 256
            (ROOT / 'icons_bgs').mkdir(exist_ok=True)
            scene.render.filepath = str(ROOT / 'icons_bgs' / f'{col_name}.png')
            bpy.ops.render.render(write_still=True)
    # Contact sheet: everything in a grid.
    per_row = 8
    for i, (col_name, col) in enumerate(built):
        col.hide_render = False
        offset = Vector(((i % per_row) * 4.2, 0, -(i // per_row) * 4.4))
        for o in objects_of(col):
            o.location += offset
    bpy.context.view_layer.update()
    frame(cam, [o for _, c in built for o in objects_of(c)], margin=1.08, direction=(0.0, -1.0, 0.12))
    scene.render.resolution_x, scene.render.resolution_y = 2000, 1500
    scene.render.filepath = str(ROOT / 'renders' / 'bgs_pets_sheet.png')
    bpy.ops.render.render(write_still=True)
    print('BUILT', len(built))


main()
