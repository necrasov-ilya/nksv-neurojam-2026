#!/usr/bin/env python3
"""Install the pinned native Godot CEF addon without tracking runtime binaries."""

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = '2.0.0'
URL = 'https://github.com/dsh0416/godot-cef/releases/download/v2.0.0/godot_cef-store-v2.0.0.zip'
SHA256 = '6d58235aa47b654a0a9410dfd40e9d7cb43ffe13d034d9f24fdb44cc2cea1b33'
ADDON = ROOT / 'addons/godot_cef'
ARCHIVE = ROOT / 'build/tools/godot_cef-store-v2.0.0.zip'
MARKER = 'latentpunk-install.json'
NOTICES = {
    'GODOT_CEF_LICENSE.txt': 'https://raw.githubusercontent.com/dsh0416/godot-cef/v2.0.0/LICENSE',
    'CEF_LICENSE.txt': 'https://raw.githubusercontent.com/chromiumembedded/cef/564dd6c/LICENSE.txt',
    'CHROMIUM_LICENSE.txt': 'https://raw.githubusercontent.com/chromium/chromium/154.0.8037.58/LICENSE',
}
REQUIRED = (
    'godot_cef.gdextension',
    'bin/x86_64-unknown-linux-gnu/libgdcef.so',
    'bin/x86_64-unknown-linux-gnu/libcef.so',
    'bin/x86_64-unknown-linux-gnu/gdcef_helper',
    'bin/x86_64-pc-windows-msvc/gdcef.dll',
    'bin/x86_64-pc-windows-msvc/gdcef_helper.exe',
    'bin/universal-apple-darwin/Godot CEF.framework/libgdcef.dylib',
)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare_notices(directory):
    for filename, url in NOTICES.items():
        destination = directory / filename
        if destination.is_file():
            continue
        request = urllib.request.Request(url, headers={'User-Agent': 'LATENTPUNK-build'})
        with urllib.request.urlopen(request, timeout=30) as response:
            destination.write_bytes(response.read())


def prepare_cef():
    marker = ADDON / MARKER
    if marker.is_file():
        installed = json.loads(marker.read_text(encoding='utf-8'))
        if installed.get('sha256') == SHA256 and all((ADDON / item).exists() for item in REQUIRED):
            prepare_notices(ADDON)
            return ADDON
    if ADDON.exists() and not marker.exists():
        raise RuntimeError('An unmanaged addons/godot_cef already exists; do not overwrite it.')
    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.is_file() or digest(ARCHIVE) != SHA256:
        temporary_download = ARCHIVE.with_suffix('.download')
        request = urllib.request.Request(URL, headers={'User-Agent': 'LATENTPUNK-build'})
        with urllib.request.urlopen(request, timeout=120) as response, temporary_download.open('wb') as output:
            shutil.copyfileobj(response, output, 1024 * 1024)
        if digest(temporary_download) != SHA256:
            temporary_download.unlink()
            raise RuntimeError('Godot CEF release SHA-256 mismatch')
        temporary_download.replace(ARCHIVE)
    with tempfile.TemporaryDirectory(prefix='cef-install-', dir=ARCHIVE.parent) as temporary:
        staging = Path(temporary) / 'godot_cef'
        staging.mkdir()
        with zipfile.ZipFile(ARCHIVE) as archive:
            prefix = 'dist/addons/godot_cef/'
            members = [item for item in archive.infolist() if item.filename.startswith(prefix)]
            if not members:
                raise RuntimeError('Godot CEF archive has an unexpected layout')
            links = []
            for item in members:
                relative = PurePosixPath(item.filename[len(prefix):])
                if not relative.parts:
                    continue
                if relative.is_absolute() or '..' in relative.parts:
                    raise RuntimeError('Unsafe path in Godot CEF archive')
                destination = staging.joinpath(*relative.parts)
                mode = item.external_attr >> 16
                if item.is_dir():
                    destination.mkdir(parents=True, exist_ok=True)
                elif stat.S_ISLNK(mode):
                    links.append((destination, archive.read(item).decode('utf-8')))
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with archive.open(item) as source, destination.open('wb') as output:
                        shutil.copyfileobj(source, output, 1024 * 1024)
                    if mode & 0o777:
                        destination.chmod(mode & 0o777)
            for destination, target in links:
                resolved = (destination.parent / target).resolve()
                if not resolved.is_relative_to(staging.resolve()):
                    raise RuntimeError('Unsafe symlink in Godot CEF archive')
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.symlink_to(target)
        # Helpers must remain executable even when a ZIP producer omitted Unix modes.
        for path in staging.rglob('*'):
            if path.is_file() and path.name in ('gdcef_helper', 'chrome-sandbox'):
                path.chmod(path.stat().st_mode | 0o111)
        if not all((staging / item).exists() for item in REQUIRED):
            raise RuntimeError('Godot CEF package is missing a required native runtime')
        prepare_notices(staging)
        (staging / MARKER).write_text(json.dumps({'version': VERSION, 'url': URL, 'sha256': SHA256, 'licenses': NOTICES}, indent=2) + '\n', encoding='utf-8')
        ADDON.parent.mkdir(parents=True, exist_ok=True)
        if ADDON.exists():
            shutil.rmtree(ADDON)
        shutil.move(str(staging), ADDON)
    print('Installed Godot CEF ' + VERSION + ' at ' + str(ADDON), flush=True)
    return ADDON


if __name__ == '__main__':
    prepare_cef()
