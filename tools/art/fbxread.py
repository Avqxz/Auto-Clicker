"""Minimal binary FBX reader for the art package: meshes, model transforms, materials.

Returns world-space triangles (FBX Y-up space, which matches Roblox axes) per mesh object.
"""
import struct, zlib, math

def _read_props(f, n):
    props = []
    for _ in range(n):
        t = f.read(1)
        if t == b'Y': props.append(struct.unpack('<h', f.read(2))[0])
        elif t == b'C': props.append(f.read(1) != b'\x00')
        elif t == b'I': props.append(struct.unpack('<i', f.read(4))[0])
        elif t == b'F': props.append(struct.unpack('<f', f.read(4))[0])
        elif t == b'D': props.append(struct.unpack('<d', f.read(8))[0])
        elif t == b'L': props.append(struct.unpack('<q', f.read(8))[0])
        elif t in b'fdlib':
            length, enc, clen = struct.unpack('<III', f.read(12))
            data = f.read(clen)
            if enc: data = zlib.decompress(data)
            code = {b'f': 'f', b'd': 'd', b'l': 'q', b'i': 'i', b'b': 'b'}[t]
            props.append(list(struct.unpack('<%d%s' % (length, code), data)))
        elif t in b'SR':
            ln = struct.unpack('<I', f.read(4))[0]
            d = f.read(ln)
            props.append(d.decode('utf-8', 'replace') if t == b'S' else d)
        else:
            raise ValueError('bad prop type %r' % t)
    return props

class Node:
    __slots__ = ('name', 'props', 'children')
    def __init__(s, name, props, children): s.name, s.props, s.children = name, props, children
    def find(s, name): return next((c for c in s.children if c.name == name), None)
    def findall(s, name): return [c for c in s.children if c.name == name]

def _read_node(f, v64):
    if v64: end, nprops, plen = struct.unpack('<QQQ', f.read(24))
    else: end, nprops, plen = struct.unpack('<III', f.read(12))
    nlen = f.read(1)[0]
    if end == 0: return None
    name = f.read(nlen).decode()
    props = _read_props(f, nprops)
    children = []
    sentinel = 25 if v64 else 13
    while f.tell() < end:
        if end - f.tell() == sentinel:
            f.read(sentinel); break
        c = _read_node(f, v64)
        if c is None: break
        children.append(c)
    f.seek(end)
    return Node(name, props, children)

def parse(path):
    with open(path, 'rb') as f:
        head = f.read(27)
        assert head[:18] == b'Kaydara FBX Binary', path
        version = struct.unpack('<I', head[23:27])[0]
        v64 = version >= 7500
        nodes = []
        while True:
            n = _read_node(f, v64)
            if n is None: break
            nodes.append(n)
    return Node('root', [], nodes)

def _p70(node):
    out = {}
    p = node.find('Properties70')
    if p:
        for c in p.children:
            out[c.props[0]] = c.props[4:]
    return out

# 4x4 matrices as row-major lists; points are column vectors.
def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def _translate(t): return [[1,0,0,t[0]],[0,1,0,t[1]],[0,0,1,t[2]],[0,0,0,1]]
def _scale(s): return [[s[0],0,0,0],[0,s[1],0,0],[0,0,s[2],0],[0,0,0,1]]
def _rot_xyz(r):
    # FBX eEulerXYZ: R = Rz * Ry * Rx (X applied first)
    x, y, z = (math.radians(v) for v in r)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = [[1,0,0,0],[0,cx,-sx,0],[0,sx,cx,0],[0,0,0,1]]
    ry = [[cy,0,sy,0],[0,1,0,0],[-sy,0,cy,0],[0,0,0,1]]
    rz = [[cz,-sz,0,0],[sz,cz,0,0],[0,0,1,0],[0,0,0,1]]
    return _mat_mul(rz, _mat_mul(ry, rx))
def _apply(m, v, w=1.0):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] + m[i][3] * w for i in range(3))

def load(path):
    """-> {'materials': {id: (name, (r,g,b))}, 'meshes': [ {name, parent_names, tris:[(p1,p2,p3,n1,n2,n3,matname)]} ], 'empties': [(name, pos)]}"""
    root = parse(path)
    objects = root.find('Objects')
    conns = root.find('Connections')
    gs = _p70(root.find('GlobalSettings'))
    unit = gs.get('UnitScaleFactor', [1.0])[0]
    models, geoms, mats = {}, {}, {}
    for o in objects.children:
        oid = o.props[0]
        if o.name == 'Model': models[oid] = o
        elif o.name == 'Geometry': geoms[oid] = o
        elif o.name == 'Material': mats[oid] = o
    parent, model_geom, model_mats = {}, {}, {}
    for c in conns.children:
        if c.props[0] != 'OO': continue
        child, par = c.props[1], c.props[2]
        if child in models and (par in models or par == 0): parent[child] = par
        elif child in geoms and par in models: model_geom[par] = child
        elif child in mats and par in models: model_mats.setdefault(par, []).append(child)

    def nm(n): return n.props[1].split('\x00')[0]

    local_cache = {}
    def local(mid):
        if mid in local_cache: return local_cache[mid]
        p = _p70(models[mid])
        t = p.get('Lcl Translation', [0, 0, 0]); r = p.get('Lcl Rotation', [0, 0, 0]); s = p.get('Lcl Scaling', [1, 1, 1])
        pre = p.get('PreRotation', [0, 0, 0]); post = p.get('PostRotation', [0, 0, 0])
        m = _mat_mul(_translate(t), _mat_mul(_rot_xyz(pre), _mat_mul(_rot_xyz(r), _mat_mul(_rot_xyz([-v for v in post]), _scale(s)))))
        local_cache[mid] = m
        return m
    world_cache = {}
    def world(mid):
        if mid in world_cache: return world_cache[mid]
        m = local(mid)
        par = parent.get(mid, 0)
        if par: m = _mat_mul(world(par), m)
        world_cache[mid] = m
        return m
    def geometric(mid):
        p = _p70(models[mid])
        return _mat_mul(_translate(p.get('GeometricTranslation', [0, 0, 0])),
               _mat_mul(_rot_xyz(p.get('GeometricRotation', [0, 0, 0])), _scale(p.get('GeometricScaling', [1, 1, 1]))))

    unit_m = _scale([unit / 100.0] * 3) if unit != 100.0 else _scale([1, 1, 1])
    materials = {}
    for mid, m in mats.items():
        p = _p70(m)
        col = p.get('DiffuseColor', p.get('Diffuse', [0.8, 0.8, 0.8]))
        emis = p.get('EmissiveFactor', [0])[0] if 'EmissiveFactor' in p else 0
        materials[mid] = (nm(m), tuple(col[:3]), emis)

    meshes, empties = [], []
    for mid, mnode in models.items():
        chain, par = [], parent.get(mid, 0)
        while par: chain.append(nm(models[par])); par = parent.get(par, 0)
        W = _mat_mul(unit_m, _mat_mul(world(mid), geometric(mid)))
        if mid not in model_geom:
            empties.append((nm(mnode), _apply(W, (0, 0, 0)), chain))
            continue
        g = geoms[model_geom[mid]]
        verts = g.find('Vertices').props[0]
        idx = g.find('PolygonVertexIndex').props[0]
        nl = g.find('LayerElementNormal')
        normals = nl.find('Normals').props[0] if nl else None
        nmap = nl.find('MappingInformationType').props[0] if nl else None
        nref = nl.find('ReferenceInformationType').props[0] if nl else None
        nidx = nl.find('NormalsIndex').props[0] if nl and nl.find('NormalsIndex') else None
        ml = g.find('LayerElementMaterial')
        mat_ids = model_mats.get(mid, [])
        mat_of_poly = ml.find('Materials').props[0] if ml else [0]
        mat_all = ml.find('MappingInformationType').props[0] == 'AllSame' if ml else True
        # Normal matrix: inverse-transpose of the 3x3 (uniform-ish scales here, so normalize after rotate).
        def tn(n):
            v = _apply(W, n, 0.0); l = math.sqrt(sum(c * c for c in v)) or 1
            return (v[0] / l, v[1] / l, v[2] / l)
        tris = []
        poly, pi, corner = [], 0, 0
        for i, raw in enumerate(idx):
            vi = raw if raw >= 0 else ~raw
            if normals is None: n = None
            else:
                if nmap == 'ByPolygonVertex': k = i
                elif nmap == 'ByVertice' or nmap == 'ByVertex': k = vi
                else: k = pi
                if nref == 'IndexToDirect': k = nidx[k]
                n = (normals[3 * k], normals[3 * k + 1], normals[3 * k + 2])
            poly.append((vi, n))
            if raw < 0:
                mi = mat_of_poly[0] if mat_all else mat_of_poly[pi]
                mname = materials[mat_ids[mi]][0] if mat_ids and mi < len(mat_ids) else None
                pts = [(_apply(W, (verts[3 * v], verts[3 * v + 1], verts[3 * v + 2])), tn(n) if n else None) for v, n in poly]
                for k in range(1, len(pts) - 1):
                    a, b, c = pts[0], pts[k], pts[k + 1]
                    tris.append((a[0], b[0], c[0], a[1], b[1], c[1], mname))
                poly = []; pi += 1
        meshes.append({'name': nm(mnode), 'chain': chain, 'tris': tris})
    return {'materials': materials, 'meshes': meshes, 'empties': empties, 'unit': unit}
