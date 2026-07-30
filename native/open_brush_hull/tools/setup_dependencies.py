#!/usr/bin/env python3

import argparse
import json
import subprocess
from pathlib import Path


EXTENSION_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = EXTENSION_ROOT.parents[1]
CONFIG_PATH = EXTENSION_ROOT / "dependencies.json"


def run(command: list[str], cwd: Path | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return result.stdout.strip()


def ensure_dependency(name: str, config: dict[str, str], dependency_root: Path) -> None:
    checkout = dependency_root / name
    repository = config["repository"]
    commit = config["commit"]

    if not (checkout / ".git").exists():
        if checkout.exists() and any(checkout.iterdir()):
            raise RuntimeError(f"{checkout} exists but is not a Git checkout")
        checkout.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--filter=blob:none", repository, str(checkout)])

    current_commit = run(["git", "rev-parse", "HEAD"], checkout)
    if current_commit == commit:
        print(f"{name}: {commit}")
        return

    dirty = run(["git", "status", "--porcelain"], checkout)
    if dirty:
        raise RuntimeError(
            f"{checkout} has local changes; refusing to replace it with pinned commit {commit}"
        )

    run(["git", "fetch", "--depth", "1", "origin", commit], checkout)
    run(["git", "checkout", "--detach", commit], checkout)
    actual_commit = run(["git", "rev-parse", "HEAD"], checkout)
    if actual_commit != commit:
        raise RuntimeError(f"{name}: expected {commit}, checked out {actual_commit}")
    print(f"{name}: {actual_commit}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch pinned open_brush_hull dependencies")
    parser.add_argument(
        "--dependency-root",
        type=Path,
        default=REPOSITORY_ROOT / ".deps",
        help="checkout destination (default: repository .deps directory)",
    )
    args = parser.parse_args()

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    ensure_dependency("godot-cpp", config["godot_cpp"], args.dependency_root.resolve())
    ensure_dependency("quickhull", config["quickhull"], args.dependency_root.resolve())


if __name__ == "__main__":
    main()
