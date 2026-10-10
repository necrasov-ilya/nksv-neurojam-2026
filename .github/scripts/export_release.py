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


ROOT = Path(__file__).resolve().parents[2]
TARGETS = (
    ("Linux", "linux-x86_64", "LATENTPUNK.x86_64"),
    ("Windows", "windows-x86_64", "LATENTPUNK.exe"),
    ("macOS", "macos-universal", "LATENTPUNK.zip"),
    ("Web", "web", "index.html"),
)
INSTRUCTIONS = {
    "Linux": "Extract the archive and run ./LATENTPUNK.x86_64. Keep the .pck beside it.",
    "Windows": "Extract the archive and run LATENTPUNK.exe. Keep the .pck beside it.",
    "macOS": (
        "Extract the archive and open LATENTPUNK.app. This alpha is unsigned and not notarized. "
        "macOS may require approval in System Settings > Privacy & Security."
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
        "Playable content: voiced prologue, city introduction and interview.\n"
        "The three-day campaign and independent web games are not integrated yet.\n\n"
        f"{INSTRUCTIONS[platform]}\n\n"
        "Controls: WASD, mouse, E; Escape pauses; hold Enter to skip the prologue.\n"
        "Source and resource credits: SOURCES.md and the in-game credits.\n"
        "Project: https://github.com/necrasov-ilya/nksv-neurojam-2026\n",
    )
    archive.write(ROOT / "assets/SOURCES.md", "SOURCES.md")
    for name in ("Notice.txt", "FISH_AUDIO_LICENSE.txt"):
        archive.write(ROOT / "assets/audio/dialogue" / name, f"licenses/{name}")


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
                add_notices(archive, preset, version)
            with archive_path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            checksums.append(f"{digest}  {archive_path.name}\n")
            print(f"RELEASE_ASSET {archive_path.name} ({archive_path.stat().st_size} bytes)", flush=True)
    (output / "SHA256SUMS").write_text("".join(checksums), encoding="utf-8")


if __name__ == "__main__":
    main()
