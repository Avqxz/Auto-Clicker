"""Rewrites Blender FBX exports to 1 unit = 1 stud for Roblox's Open Cloud importer.

Blender stores root objects with Lcl Scaling 100 and translations in centimeters; Open Cloud applies
those literally, so imports come in 100x too big. This patches (in place, same byte length) every
root Model's Lcl Scaling /100 and Lcl Translation /100.
"""
import struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import fbxread

def _walk(data, pos, v64, visit, path):
    """Parses one node at pos; calls visit(path, name, props_with_offsets). Returns end offset or None."""
    if v64: end, nprops, _ = struct.unpack_from('<QQQ', data, pos); pos += 24
    else: end, nprops, _ = struct.unpack_from('<III', data, pos); pos += 12
    nlen = data[pos]; pos += 1
    if end == 0: return None
    name = data[pos:pos + nlen].decode(); pos += nlen
    props = []
    for _ in range(nprops):
        t = data[pos:pos + 1]; pos += 1
        if t == b'D': props.append(('D', pos, struct.unpack_from('<d', data, pos)[0])); pos += 8
        elif t == b'L': props.append(('L', pos, struct.unpack_from('<q', data, pos)[0])); pos += 8
        elif t == b'I': props.append(('I', pos, None)); pos += 4
        elif t == b'F': props.append(('F', pos, None)); pos += 4
        elif t == b'Y': pos += 2; props.append(('Y', 0, None))
        elif t == b'C': pos += 1; props.append(('C', 0, None))
        elif t in b'fdlib':
            _, _, clen = struct.unpack_from('<III', data, pos); pos += 12 + clen; props.append(('A', 0, None))
        elif t in b'SR':
            ln = struct.unpack_from('<I', data, pos)[0]; pos += 4
            props.append(('S', 0, data[pos:pos + ln].decode('utf-8', 'replace'))); pos += ln
        else: raise ValueError(t)
    visit(path, name, props)
    sentinel = 25 if v64 else 13
    while pos < end:
        if end - pos == sentinel: break
        nxt = _walk(data, pos, v64, visit, path + [(name, props)])
        if nxt is None: break
        pos = nxt
    return end

def fix(src, dst):
    data = bytearray(Path(src).read_bytes())
    version = struct.unpack_from('<I', data, 23)[0]
    v64 = version >= 7500
    # Root models: connected to scene root (id 0).
    tree = fbxread.parse(src)
    roots = {c.props[1] for c in tree.find('Connections').children if c.props[0] == 'OO' and c.props[2] == 0}
    patched = 0
    def visit(path, name, props):
        nonlocal patched
        if name != 'P' or len(path) < 2 or path[-2][0] != 'Model' or path[-1][0] != 'Properties70': return
        model_id = path[-2][1][0][2]
        if model_id not in roots: return
        pname = props[0][2]
        if pname in ('Lcl Scaling', 'Lcl Translation'):
            for kind, off, val in props[4:7]:
                if kind == 'D': struct.pack_into('<d', data, off, val / 100.0)
            patched += 1
    pos = 27
    while pos < len(data):
        nxt = _walk(data, pos, v64, visit, [])
        if nxt is None: break
        pos = nxt
    Path(dst).write_bytes(bytes(data))
    return patched

if __name__ == '__main__':
    print(fix(sys.argv[1], sys.argv[2]))
