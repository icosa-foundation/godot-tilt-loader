#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

from validate_package import expected_libraries, validate


EXTENSION_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = EXTENSION_ROOT.parents[1]
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def write_deterministic_zip(source_root: Path, output_path: Path) -> None:
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(source_root.rglob("*")):
            if not path.is_file():
                continue
            relative_path = path.relative_to(source_root).as_posix()
            info = zipfile.ZipInfo(relative_path, FIXED_ZIP_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes(), compresslevel=9)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Package a complete open_brush_hull release")
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output-dir", type=Path, default=REPOSITORY_ROOT / "dist")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.version):
        raise ValueError(f"invalid package version: {args.version}")

    errors = validate(EXTENSION_ROOT, require_files=True)
    if errors:
        raise RuntimeError("\n".join(errors))

    dependencies = json.loads((EXTENSION_ROOT / "dependencies.json").read_text(encoding="utf-8"))
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    archive_path = output_dir / f"open_brush_hull-{args.version}.zip"

    with tempfile.TemporaryDirectory(prefix="open-brush-hull-package-") as temporary:
        staging_root = Path(temporary)
        package_root = staging_root / "open_brush_hull"
        package_root.mkdir()
        shutil.copy2(EXTENSION_ROOT / "open_brush_hull.gdextension", package_root)
        shutil.copy2(EXTENSION_ROOT / "open_brush_hull.gdextension.uid", package_root)
        shutil.copy2(EXTENSION_ROOT / "README.md", package_root)
        shutil.copy2(EXTENSION_ROOT / "THIRD_PARTY_NOTICES.md", package_root)
        shutil.copy2(EXTENSION_ROOT / "dependencies.json", package_root)
        shutil.copytree(EXTENSION_ROOT / "bin", package_root / "bin")
        shutil.copy2(REPOSITORY_ROOT / "LICENSE", package_root / "LICENSE")

        license_dir = package_root / "licenses"
        license_dir.mkdir()
        shutil.copy2(
            REPOSITORY_ROOT / ".deps" / "godot-cpp" / "LICENSE.md",
            license_dir / "godot-cpp-LICENSE.md",
        )
        shutil.copy2(
            REPOSITORY_ROOT / ".deps" / "quickhull" / "README.md",
            license_dir / "quickhull-LICENSE.md",
        )

        source_date_epoch = os.environ.get("SOURCE_DATE_EPOCH")
        created_utc = (
            datetime.fromtimestamp(int(source_date_epoch), timezone.utc)
            if source_date_epoch
            else datetime.now(timezone.utc)
        )
        build_manifest = {
            "name": "open_brush_hull",
            "version": args.version,
            "source_commit": args.source_commit,
            "created_utc": created_utc.replace(microsecond=0).isoformat(),
            "dependencies": dependencies,
            "libraries": expected_libraries(),
        }
        (package_root / "build_manifest.json").write_text(
            json.dumps(build_manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        write_deterministic_zip(staging_root, archive_path)

    checksum_path = archive_path.with_suffix(f"{archive_path.suffix}.sha256")
    checksum_path.write_text(f"{sha256(archive_path)}  {archive_path.name}\n", encoding="utf-8")
    print(f"OPEN_BRUSH_HULL_PACKAGE={archive_path}")
    print(f"OPEN_BRUSH_HULL_CHECKSUM={checksum_path}")


if __name__ == "__main__":
    main()
