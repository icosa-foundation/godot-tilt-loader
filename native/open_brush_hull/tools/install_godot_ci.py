#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import stat
import time
import urllib.request
import zipfile
from pathlib import Path


EXTENSION_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = EXTENSION_ROOT.parents[1]


def download(url: str, destination: Path) -> None:
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            print(f"Downloading {url} (attempt {attempt})")
            urllib.request.urlretrieve(url, destination)
            return
        except Exception as error:
            last_error = error
            if attempt < 3:
                time.sleep(attempt * 2)
    raise RuntimeError(f"failed to download {url}") from last_error


def template_install_dir(version: str, platform: str) -> Path:
    if platform == "windows":
        root = Path(os.environ["APPDATA"]) / "Godot"
    elif platform == "macos":
        root = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
        root = data_home / "godot"
    return root / "export_templates" / f"{version}.stable"


def main() -> None:
    parser = argparse.ArgumentParser(description="Install the pinned Godot editor for CI")
    parser.add_argument("--platform", required=True, choices=["windows", "linux", "macos"])
    parser.add_argument("--version", help="Godot version override")
    parser.add_argument("--install-templates", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=REPOSITORY_ROOT / ".godot-ci")
    args = parser.parse_args()

    config = json.loads((EXTENSION_ROOT / "dependencies.json").read_text(encoding="utf-8"))
    version = args.version or config["godot"]["test_version"]
    release_base = (
        f"https://github.com/godotengine/godot-builds/releases/download/{version}-stable"
    )
    asset_names = {
        "windows": f"Godot_v{version}-stable_win64.exe.zip",
        "linux": f"Godot_v{version}-stable_linux.x86_64.zip",
        "macos": f"Godot_v{version}-stable_macos.universal.zip",
    }

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    editor_archive = output_dir / asset_names[args.platform]
    if editor_archive.exists() and not zipfile.is_zipfile(editor_archive):
        editor_archive.unlink()
    if not editor_archive.exists():
        download(f"{release_base}/{asset_names[args.platform]}", editor_archive)
    with zipfile.ZipFile(editor_archive) as archive:
        archive.extractall(output_dir)

    if args.platform == "windows":
        executable = next(output_dir.glob(f"Godot_v{version}-stable_win64.exe"))
    elif args.platform == "linux":
        executable = next(output_dir.glob(f"Godot_v{version}-stable_linux.x86_64"))
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    else:
        executable = output_dir / "Godot.app" / "Contents" / "MacOS" / "Godot"
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    if args.install_templates:
        template_name = f"Godot_v{version}-stable_export_templates.tpz"
        template_archive = output_dir / template_name
        if template_archive.exists() and not zipfile.is_zipfile(template_archive):
            template_archive.unlink()
        if not template_archive.exists():
            download(f"{release_base}/{template_name}", template_archive)
        extracted_templates = output_dir / "export-templates"
        if extracted_templates.exists():
            shutil.rmtree(extracted_templates)
        with zipfile.ZipFile(template_archive) as archive:
            archive.extractall(extracted_templates)
        source_templates = extracted_templates / "templates"
        install_dir = template_install_dir(version, args.platform)
        install_dir.mkdir(parents=True, exist_ok=True)
        for source in source_templates.iterdir():
            if source.is_file():
                shutil.copy2(source, install_dir / source.name)
        print(f"OPEN_BRUSH_HULL_TEMPLATE_DIR={install_dir}")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8") as output:
            output.write(f"executable={executable}\n")
            output.write(f"version={version}\n")
    print(f"OPEN_BRUSH_HULL_GODOT={executable}")


if __name__ == "__main__":
    main()
