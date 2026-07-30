#!/usr/bin/env python3

import argparse
import configparser
import sys
from pathlib import Path


EXTENSION_NAME = "open_brush_hull"
NATIVE_SUFFIXES = {".dll", ".so", ".dylib", ".wasm"}
BUILD_ONLY_SUFFIXES = {".exp", ".lib", ".pdb"}


def expected_libraries() -> dict[str, str]:
    libraries: dict[str, str] = {}
    targets = {
        "windows": ["x86_64", "x86_32", "arm64"],
        "linux": ["x86_64", "x86_32", "arm64", "arm32"],
        "android": ["x86_64", "x86_32", "arm64", "arm32"],
    }
    extensions = {"windows": ".dll", "linux": ".so", "android": ".so"}
    prefixes = {"windows": "", "linux": "lib", "android": "lib"}

    for platform, architectures in targets.items():
        for architecture in architectures:
            for build, target in (("debug", "template_debug"), ("release", "template_release")):
                key = f"{platform}.{architecture}.single.{build}"
                filename = (
                    f"{prefixes[platform]}{EXTENSION_NAME}.{platform}.{target}.{architecture}"
                    f"{extensions[platform]}"
                )
                libraries[key] = f"./bin/{platform}/{filename}"

    for build, target in (("debug", "template_debug"), ("release", "template_release")):
        libraries[f"macos.single.{build}"] = (
            f"./bin/macos/lib{EXTENSION_NAME}.macos.{target}.dylib"
        )
        libraries[f"ios.arm64.single.{build}"] = (
            f"./bin/ios/lib{EXTENSION_NAME}.ios.{target}.arm64.dylib"
        )
        libraries[f"web.wasm32.single.{build}"] = (
            f"./bin/web/lib{EXTENSION_NAME}.web.{target}.wasm32.nothreads.wasm"
        )
    return libraries


def read_manifest(manifest_path: Path) -> dict[str, str]:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    with manifest_path.open("r", encoding="utf-8") as manifest_file:
        parser.read_file(manifest_file)

    if parser.get("configuration", "entry_symbol") != '"open_brush_hull_library_init"':
        raise ValueError("manifest entry_symbol is not open_brush_hull_library_init")
    if parser.get("configuration", "compatibility_minimum") != '"4.3"':
        raise ValueError("manifest compatibility_minimum is not 4.3")
    return {key: value.strip('"') for key, value in parser.items("libraries")}


def binary_format(path: Path) -> str:
    header = path.read_bytes()[:8]
    if header.startswith(b"MZ"):
        return "pe"
    if header.startswith(b"\x7fELF"):
        return "elf"
    if header.startswith(b"\x00asm"):
        return "wasm"
    if header[:4] in {
        b"\xca\xfe\xba\xbe",
        b"\xbe\xba\xfe\xca",
        b"\xfe\xed\xfa\xcf",
        b"\xcf\xfa\xed\xfe",
    }:
        return "macho"
    return "unknown"


def validate(package_root: Path, require_files: bool = True) -> list[str]:
    errors: list[str] = []
    manifest_path = package_root / "open_brush_hull.gdextension"
    if not manifest_path.is_file():
        return [f"missing manifest: {manifest_path}"]

    expected = expected_libraries()
    try:
        actual = read_manifest(manifest_path)
    except (configparser.Error, KeyError, ValueError) as error:
        return [f"invalid manifest: {error}"]

    missing_keys = sorted(set(expected) - set(actual))
    extra_keys = sorted(set(actual) - set(expected))
    if missing_keys:
        errors.append(f"missing manifest entries: {', '.join(missing_keys)}")
    if extra_keys:
        errors.append(f"unexpected manifest entries: {', '.join(extra_keys)}")

    for key, expected_path in expected.items():
        actual_path = actual.get(key)
        if actual_path != expected_path:
            errors.append(f"{key}: expected {expected_path}, found {actual_path}")
            continue
        if not require_files:
            continue
        binary_path = package_root / actual_path.removeprefix("./")
        if not binary_path.is_file():
            errors.append(f"{key}: missing binary {binary_path}")
            continue
        expected_format = {
            "windows": "pe",
            "linux": "elf",
            "android": "elf",
            "macos": "macho",
            "ios": "macho",
            "web": "wasm",
        }[key.split(".", 1)[0]]
        actual_format = binary_format(binary_path)
        if actual_format != expected_format:
            errors.append(
                f"{key}: expected {expected_format} binary, detected {actual_format}: {binary_path}"
            )

    if require_files:
        referenced = {
            (package_root / path.removeprefix("./")).resolve()
            for path in actual.values()
        }
        discovered = {
            path.resolve()
            for path in (package_root / "bin").rglob("*")
            if path.is_file() and path.suffix.lower() in NATIVE_SUFFIXES
        }
        unreferenced = sorted(discovered - referenced)
        if unreferenced:
            errors.append(
                "unreferenced native binaries: "
                + ", ".join(str(path.relative_to(package_root.resolve())) for path in unreferenced)
            )
        build_only = sorted(
            path
            for path in (package_root / "bin").rglob("*")
            if path.is_file() and path.suffix.lower() in BUILD_ONLY_SUFFIXES
        )
        if build_only:
            errors.append(
                "build-only files in package: "
                + ", ".join(str(path.relative_to(package_root)) for path in build_only)
            )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an open_brush_hull package")
    parser.add_argument(
        "package_root",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument(
        "--manifest-only",
        action="store_true",
        help="validate all manifest entries and paths without requiring binaries",
    )
    args = parser.parse_args()

    errors = validate(args.package_root.resolve(), require_files=not args.manifest_only)
    if errors:
        for error in errors:
            print(f"OPEN_BRUSH_HULL_VALIDATE: ERROR: {error}", file=sys.stderr)
        return 1
    mode = "manifest" if args.manifest_only else "package"
    print(f"OPEN_BRUSH_HULL_VALIDATE: {mode}=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
