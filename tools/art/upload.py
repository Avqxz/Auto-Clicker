"""Uploads the art package to Roblox with Open Cloud (Assets API) and records the asset ids.

Key: an Open Cloud API key with Assets read+write, read from ~/.roblox/opencloud_key.
Results go to tools/art/uploaded.json (re-running skips files that already have an id).

  python3 tools/art/upload.py            # world, pets, props, variants, icons
  python3 tools/art/upload.py Pet_Ice    # only files whose name contains "Pet_Ice"
"""
import json, os, ssl, sys, time, uuid, urllib.request, urllib.error
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import fbxfix

ART = Path(__file__).resolve().parents[2] / 'art'
OUT = Path(__file__).resolve().parent / 'uploaded.json'
USER_ID = '2027344055'  # the place owner (game.CreatorId)
KEY = (Path.home() / '.roblox' / 'opencloud_key').read_text().strip()
API = 'https://apis.roblox.com/assets/v1/'
SSL = ssl.create_default_context(cafile='/etc/ssl/cert.pem')  # python.org builds ship without CA certs

def request(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={'x-api-key': KEY, **(headers or {})})
    for attempt in range(8):
        try:
            with urllib.request.urlopen(req, timeout=120, context=SSL) as r:
                return json.loads(r.read() or b'{}')
        except urllib.error.HTTPError as e:
            text = e.read().decode('utf-8', 'replace')
            if e.code in (429, 500, 502, 503, 504) and attempt < 7:
                time.sleep(min(60, 2 ** attempt * 2)); continue
            raise RuntimeError(f'{e.code} {text}') from None

def upload(path, asset_type, content_type, name):
    boundary = uuid.uuid4().hex
    meta = {'assetType': asset_type, 'displayName': name[:50],
            'description': 'Clicking Simulator art package',
            'creationContext': {'creator': {'userId': USER_ID}}}
    parts = [
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{json.dumps(meta)}\r\n'.encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
        f'Content-Type: {content_type}\r\n\r\n'.encode(), path.read_bytes(), f'\r\n--{boundary}--\r\n'.encode()]
    op = request('POST', API + 'assets', b''.join(parts), {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    for _ in range(120):
        if op.get('done'):
            if 'error' in op: raise RuntimeError(json.dumps(op['error']))
            return op['response']['assetId']
        time.sleep(2)
        op = request('GET', API + op['path'])
    raise RuntimeError('timed out waiting for ' + path.name)

def jobs():
    exports = ART / 'exports'
    manifest = json.loads((exports / 'manifest.json').read_text())
    yield exports / 'World_Assembled.fbx', 'Model', 'model/fbx'
    for m in manifest:
        if m['file'].startswith(('Pet_', 'Props_', 'Variant_')):
            yield exports / m['file'], 'Model', 'model/fbx'
    for icon in sorted((ART / 'icons').glob('*.png')):
        yield icon, 'Image', 'image/png'

def main():
    done = json.loads(OUT.read_text()) if OUT.exists() else {}
    only = sys.argv[1] if len(sys.argv) > 1 else None
    failures = 0
    for path, kind, ctype in jobs():
        key = ('icon:' if kind == 'Image' else '') + path.stem
        if key in done or (only and only not in path.name): continue
        source = path
        if path.suffix == '.fbx':  # Blender's cm units -> studs, see fbxfix.py
            source = ART / 'build_fixed' / path.name
            source.parent.mkdir(exist_ok=True)
            fbxfix.fix(path, source)
        try:
            asset_id = upload(source, kind, ctype, path.stem)
        except RuntimeError as e:
            if kind == 'Image' and 'assetType' in str(e):  # older API: images go up as Decals
                asset_id = upload(source, 'Decal', ctype, path.stem)
            else:
                print('FAILED', path.name, e); failures += 1; continue
        done[key] = asset_id
        OUT.write_text(json.dumps(done, indent=1))
        print('ok', key, asset_id, flush=True)
    print(f'{len(done)} uploaded, {failures} failed')

if __name__ == '__main__':
    main()
