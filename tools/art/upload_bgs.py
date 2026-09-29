"""Uploads the rebuilt pets from build_bgs_pets.py (art/exports/Pet_*.fbx + art/icons_bgs/*.png) with
Open Cloud, recording ids in uploaded.json under 'bgs:<name>' and 'bgs_icon:<name>'.

  python3 tools/art/upload_bgs.py [filter]
"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import fbxfix
from upload import ART, OUT, upload

def main():
    done = json.loads(OUT.read_text())
    only = sys.argv[1] if len(sys.argv) > 1 else None
    failures = 0
    for icon in sorted((ART / 'icons_bgs').glob('Pet_*.png')):
        stem = icon.stem
        if only and only not in stem:
            continue
        model = ART / 'exports' / f'{stem}.fbx'
        for key, path, kind, ctype in ((f'bgs:{stem}', model, 'Model', 'model/fbx'), (f'bgs_icon:{stem}', icon, 'Image', 'image/png')):
            if key in done:
                continue
            source = path
            if kind == 'Model':
                source = ART / 'build_fixed' / path.name
                source.parent.mkdir(exist_ok=True)
                fbxfix.fix(path, source)
            try:
                done[key] = upload(source, kind, ctype, stem)
            except RuntimeError as e:
                print('FAILED', key, e); failures += 1; continue
            OUT.write_text(json.dumps(done, indent=1))
            print('ok', key, done[key], flush=True)
    print(f'{failures} failed')

if __name__ == '__main__':
    main()
