#!/usr/bin/env python3

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from validate_package import binary_format, expected_libraries


EXTENSION_ROOT = Path(__file__).resolve().parents[1]
ENTRY_SYMBOL = "open_brush_hull_library_init"


def run(command: list[str]) -> str:
    result = subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return result.stdout


def find_android_tool(name: str) -> str:
    ndk_root = os.environ.get("ANDROID_NDK_ROOT")
    if not ndk_root:
        raise RuntimeError("ANDROID_NDK_ROOT is not set")
    matches = list(Path(ndk_root).glob(f"toolchains/llvm/prebuilt/*/bin/{name}*"))
    if not matches:
        raise RuntimeError(f"cannot find {name} under {ndk_root}")
    return str(matches[0])


def inspect(platform: str, architecture: str, target: str) -> Path:
    build = "debug" if target == "template_debug" else "release"
    if platform == "macos":
        key = f"macos.single.{build}"
    elif platform == "ios":
        key = f"ios.arm64.single.{build}"
    elif platform == "web":
        key = f"web.wasm32.single.{build}"
    else:
        key = f"{platform}.{architecture}.single.{build}"

    relative_path = expected_libraries()[key].removeprefix("./")
    binary_path = EXTENSION_ROOT / relative_path
    if not binary_path.is_file():
        raise RuntimeError(f"expected binary does not exist: {binary_path}")

    expected_format = {
        "windows": "pe",
        "linux": "elf",
        "macos": "macho",
        "android": "elf",
        "ios": "macho",
        "web": "wasm",
    }[platform]
    detected_format = binary_format(binary_path)
    if detected_format != expected_format:
        raise RuntimeError(
            f"expected {expected_format} format, detected {detected_format}: {binary_path}"
        )

    if platform == "windows":
        header = run(["dumpbin", "/headers", str(binary_path)])
        exports = run(["dumpbin", "/exports", str(binary_path)])
        dependencies = run(["dumpbin", "/dependents", str(binary_path)])
        machine_tokens = {"x86_64": "8664 machine", "x86_32": "14C machine", "arm64": "AA64 machine"}
        if machine_tokens[architecture].lower() not in header.lower():
            raise RuntimeError(f"PE machine type does not match {architecture}")
        if ENTRY_SYMBOL not in exports:
            raise RuntimeError(f"{ENTRY_SYMBOL} is not exported")
        if "godot-cpp" in dependencies.lower() or "quickhull" in dependencies.lower():
            raise RuntimeError("extension has an unexpected native dependency")
    elif platform in {"linux", "android"}:
        readelf = "readelf" if platform == "linux" else find_android_tool("llvm-readelf")
        header = run([readelf, "-h", str(binary_path)])
        symbols = run([readelf, "--dyn-syms", "--wide", str(binary_path)])
        dependencies = run([readelf, "-d", str(binary_path)])
        machine_tokens = {
            "x86_64": "Advanced Micro Devices X86-64",
            "x86_32": "Intel 80386",
            "arm64": "AArch64",
            "arm32": "ARM",
        }
        if machine_tokens[architecture] not in header:
            raise RuntimeError(f"ELF machine type does not match {architecture}")
        if ENTRY_SYMBOL not in symbols:
            raise RuntimeError(f"{ENTRY_SYMBOL} is not exported")
        if "godot-cpp" in dependencies.lower() or "quickhull" in dependencies.lower():
            raise RuntimeError("extension has an unexpected native dependency")
    elif platform in {"macos", "ios"}:
        file_output = run(["file", str(binary_path)])
        if platform == "macos":
            lipo_output = run(["lipo", "-info", str(binary_path)])
            if "x86_64" not in lipo_output or "arm64" not in lipo_output:
                raise RuntimeError("macOS binary is not universal x86_64 + arm64")
        elif "arm64" not in file_output:
            raise RuntimeError("iOS binary is not arm64")
        symbols = run(["nm", "-gU", str(binary_path)])
        if ENTRY_SYMBOL not in symbols:
            raise RuntimeError(f"{ENTRY_SYMBOL} is not exported")
        dependencies = run(["otool", "-L", str(binary_path)])
        dependency_lines = [line.strip() for line in dependencies.splitlines()[1:] if line.strip()]
        unexpected = [
            line
            for line in dependency_lines
            if Path(line.split(" (", 1)[0]).name != binary_path.name
            and not line.startswith("/usr/lib/")
            and not line.startswith("/System/Library/")
        ]
        if unexpected:
            raise RuntimeError(f"unexpected native dependencies: {unexpected}")
    else:
        wasm_tool = shutil.which("wasm-dis") or shutil.which("wasm-objdump")
        if wasm_tool:
            tool_name = Path(wasm_tool).name
            arguments = [wasm_tool, str(binary_path)]
            if tool_name.startswith("wasm-objdump"):
                arguments.insert(1, "-x")
            wasm_text = run(arguments)
            if ENTRY_SYMBOL not in wasm_text:
                raise RuntimeError(f"{ENTRY_SYMBOL} is not exported")
        elif ENTRY_SYMBOL.encode("ascii") not in binary_path.read_bytes():
            raise RuntimeError(f"{ENTRY_SYMBOL} is not present in WebAssembly exports")

    return binary_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect one open_brush_hull build output")
    parser.add_argument("--platform", required=True)
    parser.add_argument("--arch", required=True)
    parser.add_argument("--target", required=True, choices=["template_debug", "template_release"])
    args = parser.parse_args()

    try:
        binary_path = inspect(args.platform, args.arch, args.target)
    except (KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"OPEN_BRUSH_HULL_INSPECT: ERROR: {error}", file=sys.stderr)
        return 1
    print(f"OPEN_BRUSH_HULL_INSPECT: ok={binary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
