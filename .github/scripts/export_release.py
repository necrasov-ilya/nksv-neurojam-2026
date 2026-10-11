#!/usr/bin/env python3
"""Export the current Godot game for all release platforms using one version."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

from prepare_modules import prepare_modules
from prepare_cef import prepare_cef


ROOT = Path(__file__).resolve().parents[2]
TARGETS = (
    ("Linux", "linux-x86_64", "LATENTPUNK.x86_64"),
    ("Windows", "windows-x86_64", "LATENTPUNK.exe"),
    ("macOS", "macos-universal", "LATENTPUNK.zip"),
    ("Web", "web", "index.html"),
)
INSTRUCTIONS = {
    "Linux": "Extract the complete archive and run ./LATENTPUNK.x86_64. Keep .pck, Chromium runtime files and campaign-modules beside it. Simulations run inside the game window; finish via the host toolbar.",
    "Windows": "Extract the complete archive and run LATENTPUNK.exe. Keep .pck, Chromium runtime files and campaign-modules beside it. Simulations run inside the game window; finish via the host toolbar.",
    "macOS": (
        "Extract the archive and open LATENTPUNK.app. This alpha is unsigned and not notarized. "
        "macOS may require approval in System Settings > Privacy & Security. Keep the complete app bundle, including its Chromium frameworks and campaign-modules."
    ),
    "Web": (
        "Extract the archive, run python3 -m http.server 8060 in this directory, "
        "then open http://localhost:8060/. Do not open index.html via file://. "
        "For hosting, upload the complete directory, not just the HTML file."
    ),
}


def project_version():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^config/version\s*=\s*"([^"]+)"\s*$', project, re.MULTILINE)
    if match is None:
        raise ValueError("Set application/config/version in project.godot before exporting.")
    return match.group(1)


def add_notices(archive, platform, version):
    archive.writestr(
        "README.txt",
        f"LATENTPUNK: TEST SUBJECT 0 — {version}\n\n"
        "Campaign: voiced prologue, city, interview, three shifts, apartment and endings.\n"
        "Included independent games run through a host; finish each sample to submit a report.\n\n"
        f"{INSTRUCTIONS[platform]}\n\n"
        "Controls: WASD, mouse, E; Shift runs after the interview (camera motion can be disabled in Settings). LMB picks up/drops, E places, R resets calibration. Escape pauses or closes the tablet. Hold Enter to skip the prologue; F8 captures a game sample. The host report button unlocks after 15 active seconds; loading and pause do not count.\n"
        "Source and resource credits: SOURCES.md and the in-game credits.\n"
        "Project: https://github.com/necrasov-ilya/nksv-neurojam-2026\n",
    )
    archive.write(ROOT / "assets/SOURCES.md", "SOURCES.md")
    for name in ("Notice.txt", "FISH_AUDIO_LICENSE.txt"):
        archive.write(ROOT / "assets/audio/dialogue" / name, f"licenses/{name}")
    if platform != "Web":
        for name in ("GODOT_CEF_LICENSE.txt", "CEF_LICENSE.txt", "CHROMIUM_LICENSE.txt"):
            archive.write(ROOT / "addons/godot_cef" / name, "licenses/" + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--print-version", action="store_true")
    args = parser.parse_args()
    version = project_version()
    if args.print_version:
        print(version)
        return

    output = ROOT / "build/release" / version
    output.mkdir(parents=True, exist_ok=True)
    prepare_cef()
    modules = prepare_modules()
    subprocess.run(
        [args.godot, "--headless", "--path", str(ROOT), "--editor", "--import", "--quit"],
        check=True,
    )
    checksums = []
    with tempfile.TemporaryDirectory(prefix="export-", dir=output) as temporary:
        staging = Path(temporary)
        for preset, suffix, entry in TARGETS:
            platform_dir = staging / suffix
            platform_dir.mkdir()
            export_path = platform_dir / entry
            subprocess.run(
                [args.godot, "--headless", "--path", str(ROOT), "--export-release", preset, str(export_path)],
                check=True,
            )
            if preset != "macOS":
                destination = platform_dir if preset == "Web" else platform_dir / "campaign-modules"
                shutil.copytree(modules, destination, dirs_exist_ok=True)
            archive_path = output / f"LATENTPUNK-{version}-{suffix}.zip"
            if preset == "macOS":
                # Keep Godot's app bundle entries, executable modes and symlinks intact.
                shutil.copyfile(export_path, archive_path)
                mode = "a"
            else:
                mode = "w"
            with zipfile.ZipFile(archive_path, mode, zipfile.ZIP_DEFLATED) as archive:
                if preset != "macOS":
                    for path in sorted(platform_dir.rglob("*")):
                        if path.is_file():
                            archive.write(path, path.relative_to(platform_dir))
                else:
                    bundles = {name.split("/", 1)[0] for name in archive.namelist() if ".app/" in name}
                    if len(bundles) != 1:
                        raise RuntimeError("Expected one macOS app bundle")
                    bundle = bundles.pop()
                    for path in sorted(modules.rglob("*")):
                        if path.is_file():
                            archive.write(path, f"{bundle}/Contents/Resources/campaign-modules/{path.relative_to(modules).as_posix()}")
                add_notices(archive, preset, version)
            with archive_path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            checksums.append(f"{digest}  {archive_path.name}\n")
            print(f"RELEASE_ASSET {archive_path.name} ({archive_path.stat().st_size} bytes)", flush=True)
    (output / "SHA256SUMS").write_text("".join(checksums), encoding="utf-8")


if __name__ == "__main__":
    main()
