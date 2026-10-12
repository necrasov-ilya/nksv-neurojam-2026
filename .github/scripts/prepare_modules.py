#!/usr/bin/env python3
"""Package the approved worlds, preserving original sources and bundled logic."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / 'assets/campaign/module_catalog.json'
VENDOR = ROOT / 'web/vendor'
CACHE = ROOT / 'build/tools/vendor-cache'
CDN_THREE = 'https://cdn.jsdelivr.net/npm/three@0.170.0/'
FONT_FAMILIES = ['barlow', 'barlowcondensed', 'ibmplexmono', 'manrope', 'unbounded']


def download(url, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        request = urllib.request.Request(url, headers={'User-Agent': 'LATENTPUNK-offline-package/0.2'})
        with urllib.request.urlopen(request, timeout=90) as response:
            data = response.read()
        target.write_bytes(data)
    return target.read_bytes()


def vendor_dependencies(sources):
    VENDOR.mkdir(parents=True, exist_ok=True)
    needed = {'build/three.module.js', 'LICENSE', 'package.json'}
    font_urls = set()
    font_pattern = r'https://fonts\.googleapis\.com/css2?[^\s\"\'<>)]+'
    for source in sources:
        for path in source.rglob('*'):
            if path.is_file() and path.suffix in ('.html', '.css', '.js'):
                text = path.read_text(encoding='utf-8', errors='replace')
                needed.update('examples/jsm/' + item for item in re.findall(r"['\"]three/(?:addons|examples/jsm)/([^'\"]+\.js)['\"]", text))
                needed.update(item for item in re.findall(re.escape(CDN_THREE) + r'([^\s\"\'<>`]+\.js)', text))
                font_urls.update(re.findall(font_pattern, text))
    # GLTFLoader's optional Draco worker libraries are assets, not import statements.
    needed.update('examples/jsm/libs/draco/gltf/' + item for item in ['draco_decoder.js', 'draco_decoder.wasm', 'draco_wasm_wrapper.js'])
    needed.add('examples/jsm/libs/draco/README.md')
    metadata_bytes = download('https://registry.npmjs.org/three/0.170.0', CACHE / 'three-0.170.0.json')
    metadata = json.loads(metadata_bytes)
    tarball = CACHE / 'three-0.170.0.tgz'
    data = download(metadata['dist']['tarball'], tarball)
    integrity = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
    if integrity != metadata['dist']['integrity']:
        raise RuntimeError('Three.js package integrity mismatch')
    written = set()
    with tarfile.open(tarball, 'r:gz') as archive:
        queue = list(needed)
        while queue:
            relative = queue.pop()
            if relative in written:
                continue
            member = archive.getmember('package/' + relative)
            payload = archive.extractfile(member).read()
            destination = VENDOR / 'three' / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(payload)
            written.add(relative)
            if relative.endswith('.js'):
                for specifier in re.findall(r"(?:from\s*|import\s*(?:\(\s*)?)['\"]([^'\"]+)['\"]", payload.decode(errors='replace')):
                    if specifier.startswith('.') and specifier.endswith('.js'):
                        queue.append(os.path.normpath(str(PurePosixPath(relative).parent / specifier)).replace(os.sep, '/'))
    fonts = {}
    draco_license = download('https://raw.githubusercontent.com/google/draco/1.5.7/LICENSE', VENDOR / 'licenses/draco-Apache-2.0.txt')
    font_sources = []
    for url in sorted(font_urls):
        name = hashlib.sha256(url.encode()).hexdigest()[:16] + '.css'
        original = download(url.replace('&amp;', '&'), CACHE / ('font-' + name)).decode()
        def local_font(match):
            asset_url = match.group(1).strip('"\'')
            extension = Path(asset_url.split('?')[0]).suffix
            filename = hashlib.sha256(asset_url.encode()).hexdigest()[:20] + extension
            target = VENDOR / 'fonts' / filename
            payload = download(asset_url, target)
            font_sources.append({'url': asset_url, 'file': 'fonts/' + filename, 'sha256': hashlib.sha256(payload).hexdigest()})
            return 'url(../fonts/' + filename + ')'
        rewritten = re.sub(r'url\((https://fonts\.gstatic\.com/[^)]+)\)', local_font, original)
        target = VENDOR / 'font_styles' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(rewritten, encoding='utf-8')
        fonts[url] = '../../vendor/font_styles/' + name
    for family in FONT_FAMILIES:
        download('https://raw.githubusercontent.com/google/fonts/main/ofl/' + family + '/OFL.txt', VENDOR / 'licenses' / (family + '-OFL.txt'))
    provenance = {'three': {'version': '0.170.0', 'url': metadata['dist']['tarball'], 'integrity': integrity, 'files': sorted(written)}, 'draco_license': {'url': 'https://raw.githubusercontent.com/google/draco/1.5.7/LICENSE', 'sha256': hashlib.sha256(draco_license).hexdigest()}, 'font_stylesheets': sorted(font_urls), 'font_assets': font_sources}
    (VENDOR / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return fonts


def rebase_markup(text, file, game_root, font_map):
    relative = os.path.relpath(game_root, file.parent).replace(os.sep, '/')
    prefix = './' if relative == '.' else relative + '/'
    top_names = [entry.name for entry in game_root.iterdir() if entry.name not in ['index.html', 'game.json']]
    for name in top_names:
        text = re.sub(r'([\"\'(])/' + re.escape(name) + r'(?=[/\"\')])', lambda match: match.group(1) + prefix + name, text)
    for original, replacement in font_map.items():
        filename = replacement.rsplit('/', 1)[-1]
        font_prefix = os.path.relpath(game_root.parent.parent / 'vendor/font_styles', file.parent).replace(os.sep, '/')
        text = text.replace(original, font_prefix + '/' + filename).replace(original.replace('&', '&amp;'), font_prefix + '/' + filename)
    text = text.replace(CDN_THREE, '../../vendor/three/' if file.name == 'index.html' else prefix + '../../vendor/three/')
    if file.name == 'index.html':
        injection = '<script src="../../campaign-frame.js"></script>'
        text, count = re.subn(r'(<head(?:\s[^>]*)?>)', lambda match: match.group(1) + '\n' + injection, text, count=1, flags=re.I)
        if count != 1:
            raise RuntimeError('No HTML head in ' + str(file))
    return text


def prepare_modules(output=None, build_sources=True):
    output = Path(output or ROOT / 'build/campaign-modules')
    (ROOT / 'build').mkdir(parents=True, exist_ok=True)
    (ROOT / 'build/.gdignore').write_text('', encoding='utf-8')
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    sources = []
    for info in catalog['modules']:
        if not info['source_dir']:
            continue
        source = ROOT / 'games' / info['source_dir']
        if info['id'] in ('dustfall', 'deadparade'):
            if build_sources:
                if not (source / 'node_modules').is_dir():
                    subprocess.run(['npm', 'ci'], cwd=source, check=True)
                subprocess.run(['npm', 'run', 'build', '--', '--base', './'], cwd=source, check=True)
            source /= 'dist'
        if not (source / 'index.html').is_file():
            raise RuntimeError('Missing complete game entry: ' + str(source))
        sources.append(source)
    font_map = vendor_dependencies(sources)
    output.mkdir(parents=True, exist_ok=True)
    for filename in ['campaign-host.js', 'campaign-frame.js', 'simulation-host.html']:
        shutil.copyfile(ROOT / 'web' / filename, output / filename)
    shutil.copytree(VENDOR, output / 'vendor', dirs_exist_ok=True)
    shutil.copytree(ROOT / 'assets/ui/authors', output / 'authors', ignore=shutil.ignore_patterns('*.import'), dirs_exist_ok=True)
    shutil.copyfile(CATALOG, output / 'module_catalog.json')
    selected_ids = {info['id'] for info in catalog['modules'] if info['source_dir']}
    games_output = output / 'games'
    if games_output.is_dir():
        for directory in games_output.iterdir():
            if directory.is_dir() and directory.name not in selected_ids:
                shutil.rmtree(directory)
    packaged = []
    source_index = 0
    for info in catalog['modules']:
        if not info['source_dir']:
            continue
        source = sources[source_index]
        source_index += 1
        target = output / 'games' / info['id']
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(source, target, ignore=shutil.ignore_patterns('node_modules', '.git', '.godot'))
        # Source projects retain their notices even though the runtime uses dist.
        original = ROOT / 'games' / info['source_dir']
        for notice in ['LICENSE', 'LICENSE.txt', 'NOTICE', 'NOTICE.txt', 'game.json']:
            if (original / notice).is_file() and not (target / notice).exists():
                shutil.copyfile(original / notice, target / notice)
        for file in target.rglob('*'):
            if file.is_file() and file.suffix in ('.html', '.css'):
                text = file.read_text(encoding='utf-8')
                rewritten = rebase_markup(text, file, target, font_map)
                if rewritten != text:
                    file.write_text(rewritten, encoding='utf-8')
        entry = target / 'index.html'
        packaged.append({'id': info['id'], 'source': str(source.relative_to(ROOT)), 'entry': str(entry.relative_to(output)), 'files': sum(path.is_file() for path in target.rglob('*'))})
    manifest = {'portal_revision': catalog['revision'], 'worlds': packaged, 'launch_policy': 'Staged HTML bootstrap and local asset URLs only; original bundled JS remains unchanged.'}
    (output / 'package-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Prepared %d worlds at %s' % (len(packaged), output))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    parser.add_argument('--skip-build', action='store_true')
    args = parser.parse_args()
    prepare_modules(args.output, not args.skip_build)
