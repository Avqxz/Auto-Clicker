"""Builds the Crystal Seraph (Secret), an endgame "divine gem" pet in the Godly Gem's visual language:
a massive faceted hot-pink diamond (about half the pet's height, its lit facets glowing), huge
symmetrical wings of chunky faceted crystal feathers (white / pastel pink / lavender, slightly
translucent in game), two tall crystal bunny ears behind the gem fading from white to glowing pink,
chunky floating shards at the sides, and radiant beams fanning out behind the gem. No face.

The in-game aura (white rim light, pink glow, star sparkles, floating motes, flare flashes) is added by
PetModelFactory for pets with `Aura = true` in GameConfig.PetArt.

  Blender --background --python tools/art/build_crystal_seraph.py

Colorways: Regular (pink)  -> art/exports/Pet_Secret_CrystalSeraph.fbx
           Shiny (ice blue) -> art/exports/Pet_Secret_CrystalSeraph_Shiny.fbx
Icon: art/icons_bgs/Pet_Secret_CrystalSeraph.png; review render: art/renders/crystal_seraph.png.
Pets face -Y; one material per piece. Piece names matter in game: "Glass" pieces are slightly
translucent and "Beam" pieces more so (PetModelFactory).
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2] / 'art'

COLORWAYS = {
    'Regular': dict(
        gem=('ff9ad2', 'ff40a0', 'c8117c'),  # lit (glowing), mid, shaded facets
        feathers=('ffffff', 'ffc4e1', 'ece4ff'),  # white, pastel pink, very light lavender
        horn=('ffffff', 'ffb8dc', 'ff2d95'),  # ear: base, middle, glowing tip
        ear_inner='ff7cbf',
        shard=('ff5fb0', 'ffc4e1', 'e9e0ff'),
        beam='ffe3f2',
    ),
    'Shiny': dict(
        gem=('a8e4ff', '3fb0ff', '1f7fe0'),
        feathers=('ffffff', 'c9ecff', 'e4e8ff'),
        horn=('ffffff', 'b5e3ff', '3fb0ff'),
        ear_inner='6cc8ff',
        shard=('6cc8ff', 'c9ecff', 'e4e8ff'),
        beam='e3f4ff',
    ),
}
EXPORT = {'Regular': 'Pet_Secret_CrystalSeraph', 'Shiny': 'Pet_Secret_CrystalSeraph_Shiny'}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
MATS = {}
COL = None
COUNT = {}


def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(hexcolor, glow=False):
    key = hexcolor + ('_glow' if glow else '')
    if key not in MATS:
        r, g, b = (lin(int(hexcolor[i:i + 2], 16)) for i in (0, 2, 4))
        m = bpy.data.materials.new(('G_' if glow else 'C_') + hexcolor)
        m.use_nodes = True
        bsdf = m.node_tree.nodes['Principled BSDF']
        bsdf.inputs['Base Color'].default_value = (r, g, b, 1)
        bsdf.inputs['Roughness'].default_value = 0.2
        if glow:
            bsdf.inputs['Emission Color'].default_value = (r, g, b, 1)
            bsdf.inputs['Emission Strength'].default_value = 1.5
        m.diffuse_color = (r, g, b, 1)
        MATS[key] = m
    return MATS[key]


def finish(name, bm, color, glow=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    COUNT[name] = COUNT.get(name, 0) + 1
    unique = name if COUNT[name] == 1 else f'{name}_{COUNT[name]}'
    me = bpy.data.meshes.new(unique)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False  # flat facets everywhere: it's all crystal
    o = bpy.data.objects.new(unique, me)
    o.data.materials.append(mat(color, glow))
    COL.objects.link(o)
    return o


def mirror_x():
    return Matrix.Scale(-1, 4, (1, 0, 0))


def side_place(side, pos, angle):
    """Place a piece built along +X at `pos` (x mirrored for side -1), turned `angle` degrees up from horizontal."""
    return Matrix.Translation((side * pos[0], pos[1], pos[2])) @ (mirror_x() if side < 0 else Matrix()) @ \
        Matrix.Rotation(math.radians(-angle), 4, 'Y')


# ------------------------------------------------------------------ pieces
def diamond(c, center, radius, height):
    """A chunky brilliant cut standing on its point (the classic diamond silhouette), facets split by
    the light they catch; the lit ones glow."""
    n = 8
    tr, crown, pav = radius * 0.58, height * 0.34, height * 0.66
    bm = bmesh.new()
    top = bm.verts.new((0, 0, crown))
    cul = bm.verts.new((0, 0, -pav))
    turn = math.pi / 2 + math.pi / (2 * n)  # a girdle edge faces the viewer
    g = [bm.verts.new((radius * math.cos(turn + math.pi * i / n), radius * 0.8 * math.sin(turn + math.pi * i / n), 0)) for i in range(2 * n)]
    t = [bm.verts.new((tr * math.cos(turn + 2 * math.pi * i / n + math.pi / n), tr * 0.8 * math.sin(turn + 2 * math.pi * i / n + math.pi / n), crown))
         for i in range(n)]
    for i in range(n):
        bm.faces.new((top, t[i], t[(i + 1) % n]))
        bm.faces.new((t[i], g[2 * i + 1], g[(2 * i + 2) % (2 * n)]))
        bm.faces.new((t[i], g[(2 * i + 2) % (2 * n)], t[(i + 1) % n]))
        bm.faces.new((t[(i + 1) % n], g[(2 * i + 2) % (2 * n)], g[(2 * i + 3) % (2 * n)]))
    # Pavilion: a mid ring breaks each long face into chunky facets.
    mid = [bm.verts.new((radius * 0.5 * math.cos(turn + math.pi * i / n), radius * 0.4 * math.sin(turn + math.pi * i / n), -pav * 0.5))
           for i in range(0, 2 * n, 2)]
    for i in range(n):
        a, b, cc = g[2 * i], g[2 * i + 1], g[(2 * i + 2) % (2 * n)]
        m0, m1 = mid[i], mid[(i + 1) % n]
        bm.faces.new((a, m0, b))
        bm.faces.new((b, m0, m1))
        bm.faces.new((b, m1, cc))
        bm.faces.new((m0, cul, m1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ Matrix.Rotation(math.radians(-8), 4, 'X'), verts=bm.verts)
    bm.normal_update()
    light = Vector((0.3, -0.85, 0.45)).normalized()
    groups = {0: [], 1: [], 2: []}
    for f in bm.faces:
        d = f.normal.dot(light)
        groups[0 if d > 0.62 else 1 if d > 0.15 else 2].append(f.index)
    for key, name, glow in ((0, 'GemLight', True), (1, 'GemMid', False), (2, 'GemDark', False)):
        part = bm.copy()
        part.faces.ensure_lookup_table()
        keep = set(groups[key])
        bmesh.ops.delete(part, geom=[f for f in part.faces if f.index not in keep], context='FACES')
        finish(name, part, c['gem'][key], glow)
    bm.free()


def crystal_blade(pieces, length, width, bend, place, thick=0.45, ear=False):
    """A chunky crystal feather/horn along +X: a diamond cross-section (edges above and below, ridges front
    and back), widest a third of the way, tapering to a point that curls by `bend`. `pieces` splits it
    along its length: [(t0, t1, name, color, glow)], so an ear can fade from base to tip. ear=True gives a
    bunny-ear profile instead: narrow at the base, widest past the middle, with a rounded tip."""
    def section(t):
        x, z = length * t, bend * length * t * t
        dx, dz = length, 2 * bend * length * t
        ln = math.hypot(dx, dz)
        nx, nz = -dz / ln, dx / ln
        if ear:
            w = width * max(0.35, math.sin(math.pi * (0.12 + 0.8 * t)) ** 0.7) * min(1.0, (1 - t) / 0.1) ** 0.5
        else:
            w = width * max(0.08, min(1.0, t / 0.3) ** 0.5) * max(0.0, 1 - t) ** 0.6 * 1.1
        d = w * thick / 2
        return [Vector((x + nx * w / 2, 0, z + nz * w / 2)), Vector((x, -d, z)), Vector((x - nx * w / 2, 0, z - nz * w / 2)), Vector((x, d, z))]

    for t0, t1, name, color, glow in pieces:
        bm = bmesh.new()
        steps = max(2, round((t1 - t0) * 12))
        rings = []
        for k in range(steps + 1):
            t = t0 + (t1 - t0) * k / steps
            if t >= 0.999:
                rings.append([bm.verts.new((length, 0, bend * length))])
            else:
                rings.append([bm.verts.new(v) for v in section(t)])
        for r0, r1 in zip(rings, rings[1:]):
            if len(r1) == 1:
                for s in range(4):
                    bm.faces.new((r0[s], r0[(s + 1) % 4], r1[0]))
            else:
                for s in range(4):
                    bm.faces.new((r0[s], r0[(s + 1) % 4], r1[(s + 1) % 4]))
                    bm.faces.new((r0[s], r1[(s + 1) % 4], r1[s]))
        bm.faces.new(list(reversed(rings[0])))
        if len(rings[-1]) == 4:
            bm.faces.new(rings[-1])
        bmesh.ops.transform(bm, matrix=place, verts=bm.verts)
        finish(name, bm, color, glow)


def shard(name, center, radius, height, tilt, color, glow=False):
    """A chunky floating crystal: an elongated octahedron."""
    bm = bmesh.new()
    top, bot = bm.verts.new((0, 0, height / 2)), bm.verts.new((0, 0, -height / 2))
    ring = [bm.verts.new((radius * math.cos(math.pi / 2 * i + 0.4), radius * 0.8 * math.sin(math.pi / 2 * i + 0.4), height * 0.08)) for i in range(4)]
    for i in range(4):
        bm.faces.new((top, ring[i], ring[(i + 1) % 4]))
        bm.faces.new((bot, ring[(i + 1) % 4], ring[i]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ Matrix.Rotation(math.radians(tilt), 4, 'Y'), verts=bm.verts)
    return finish(name, bm, color, glow)


def beam(name, center, angle, length, width, color):
    """A flat tapered ray from `center`, pointing `angle` degrees round from +X (counter-clockwise)."""
    bm = bmesh.new()
    outline = [(0, -width / 2), (length, 0), (0, width / 2)]
    front = [bm.verts.new((x, -0.03, z)) for x, z in outline]
    back = [bm.verts.new((x, 0.03, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(3):
        bm.faces.new((front[i], back[i], back[(i + 1) % 3], front[(i + 1) % 3]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ Matrix.Rotation(math.radians(-angle), 4, 'Y'), verts=bm.verts)
    return finish(name, bm, color, glow=True)


def build(c):
    gem_center = (0, 0, 2.2)
    diamond(c, gem_center, 1.7, 3.0)
    white, pink, lavender = c['feathers']
    for side in (1, -1):
        # Wing, built like a real wing: a crystal arm sweeping up and out from behind the gem to the wrist,
        # long primaries fanning far out from the wrist (tips curling up), shorter secondaries hanging
        # along the arm, and a row of coverts in front. White / pastel pink / lavender crystal.
        shoulder, wrist = Vector((1.0, 0.5, 2.9)), Vector((2.5, 0.5, 4.3))
        arm_angle = math.degrees(math.atan2(wrist.z - shoulder.z, wrist.x - shoulder.x))
        crystal_blade([(0, 1, 'WingArmGlass', white, False)], (wrist - shoulder).length * 1.25, 1.0, -0.05,
                      side_place(side, shoulder, arm_angle), thick=0.6)
        for k, (ang, ln, col) in enumerate(((44, 3.3, white), (28, 3.5, pink), (12, 3.3, white), (-4, 2.9, lavender))):
            crystal_blade([(0, 1, 'WingGlass', col, False)], ln, 1.1, 0.12, side_place(side, wrist + Vector((0, 0.1 + 0.1 * k, -0.15 * k)), ang))
        for k, (t, ang, ln, col) in enumerate(((0.7, -16, 2.7, pink), (0.4, -30, 2.3, white), (0.1, -44, 1.9, lavender))):
            base = shoulder.lerp(wrist, t)
            crystal_blade([(0, 1, 'WingGlass', col, False)], ln, 1.05, 0.14, side_place(side, base + Vector((0, 0.5 + 0.1 * k, -0.1)), ang))
        for k, (t, ang, ln, col) in enumerate(((0.85, 10, 1.8, lavender), (0.55, -8, 1.6, pink), (0.25, -24, 1.4, white))):
            base = shoulder.lerp(wrist, t)
            crystal_blade([(0, 1, 'WingCovertGlass', col, False)], ln, 1.0, 0.12, side_place(side, base + Vector((0, -0.25, 0)), ang))
        # Bunny ear behind the gem: tall and rounded, leaning a little outward, white at the base and
        # glowing pink at the tip, with a pastel inner-ear panel in front.
        base, mid, tip = c['horn']
        ear_place = side_place(side, (0.55, 0.3, 3.0), 74)
        crystal_blade([(0, 0.6, 'Ear', base, False), (0.6, 0.82, 'Ear', mid, False), (0.82, 1, 'EarTip', tip, True)],
                      3.2, 1.55, -0.05, ear_place, thick=0.45, ear=True)
        crystal_blade([(0, 1, 'EarInner', c['ear_inner'], False)], 2.3, 0.75, -0.05,
                      ear_place @ Matrix.Translation((0.45, -0.34, 0.0)), thick=0.25, ear=True)
        # Chunky floating shards beside the gem.
        s_hot, s_pink, s_lav = c['shard']
        shard('Shard', (side * 1.95, -0.3, 1.2), 0.34, 1.1, side * 20, s_hot, glow=True)
        shard('ShardGlass', (side * 2.55, -0.1, 2.2), 0.26, 0.8, side * -15, s_pink)
        shard('ShardGlass', (side * 1.5, -0.5, 0.35), 0.24, 0.7, side * 30, s_lav)
    # Radiant beams fanning out behind the gem, longest straight up, shortest at the sides.
    for k in range(13):
        ang = -30 + 20 * k
        up = max(0.0, math.sin(math.radians(ang)))
        beam('Beam', (0, 1.2, gem_center[2] + 0.4), ang, (2.4 + 1.4 * up) if k % 2 == 0 else (1.8 + 1.0 * up), 0.8, c['beam'])


# ------------------------------------------------------------------ output
def objects_of(col):
    return [o for o in col.objects if o.type == 'MESH']


def settle(col):
    """Centre on X/Y and put the lowest point on the floor (baked into the meshes)."""
    objs = objects_of(col)
    pts = [o.matrix_world @ Vector(v) for o in objs for v in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in objs:
        o.data.transform(shift)
    return hi - lo


def export(col, name):
    bpy.ops.object.select_all(action='DESELECT')
    objs = objects_of(col)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=str(ROOT / 'exports' / f'{name}.fbx'), use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', add_leaf_bones=False, bake_anim=False)


def setup_render():
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('World')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.9, 0.92, 1.0, 1)
    scene.world = world
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
    sun.data.energy = 2.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-20))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
    cam.data.type = 'ORTHO'
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame(cam, objs, direction, margin=1.1):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(v) for o in objs for v in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    cam.location = center + Vector(direction).normalized() * 30
    cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = max(hi.x - lo.x, hi.z - lo.z) * margin
    cam.data.clip_end = 100


def main():
    global COL
    cam = setup_render()
    cols = []
    for label, colors in COLORWAYS.items():
        COL = bpy.data.collections.new(label)
        scene.collection.children.link(COL)
        COUNT.clear()
        build(colors)
        size = settle(COL)
        print(label, 'size', tuple(round(v, 2) for v in size))
        if label in EXPORT:
            export(COL, EXPORT[label])
        cols.append(COL)
    # Icon: the Regular one, alone, on transparent.
    scene.render.film_transparent = True
    for col in cols[1:]:
        col.hide_render = True
    frame(cam, objects_of(cols[0]), (0.15, -1.0, 0.2), margin=1.04)
    scene.render.resolution_x = scene.render.resolution_y = 256
    (ROOT / 'icons_bgs').mkdir(exist_ok=True)
    scene.render.filepath = str(ROOT / 'icons_bgs' / 'Pet_Secret_CrystalSeraph.png')
    bpy.ops.render.render(write_still=True)
    # Review sheet: both side by side on a dark background.
    scene.render.film_transparent = False
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.04, 0.08, 1)
    for i, col in enumerate(cols):
        col.hide_render = False
        for o in objects_of(col):
            o.location = (i * 12, 0, 0)
    frame(cam, [o for col in cols for o in objects_of(col)], (0.15, -1.0, 0.2), margin=1.05)
    scene.render.resolution_x, scene.render.resolution_y = 1800, 800
    scene.render.filepath = str(ROOT / 'renders' / 'crystal_seraph.png')
    bpy.ops.render.render(write_still=True)
    print('DONE')


main()
