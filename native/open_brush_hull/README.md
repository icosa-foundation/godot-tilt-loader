# Open Brush Hull GDExtension

Native convex-hull backend for Godot hull brushes. The extension wraps Antti
Kuukka's public-domain QuickHull implementation and exposes
`NativeConvexHullUtil` to GDScript.

The GDScript fallback remains available, but real `.tilt` hull strokes should
use this extension. The wrapper rejects too-small, collinear, and coplanar
inputs before calling QuickHull so degenerate inputs follow the Unity
null-hull path instead of producing a synthetic thin hull.

The GDScript brush code passes the same tolerance scale used by the Unity hull brushes (`1e-6 * App.METERS_TO_UNITS * pointer_to_local()`). The native wrapper rejects too-small, collinear, and coplanar point sets before calling QuickHull so degenerate inputs behave like Unity's null-hull path instead of producing a synthetic thin hull. QuickHull's triangle buffer is converted back into ordered polygon faces for truly coplanar facets; brush geometry still fan-triangulates those faces when writing mesh indices.

## Compatibility and Platforms

The extension is compiled against the Godot 4.3 GDExtension API and tested with
the pinned current Godot version in `dependencies.json`. The manifest contains
debug and release entries for:

- Windows: x86_64, x86_32, and arm64
- Linux: x86_64, x86_32, arm64, and arm32
- macOS: universal x86_64 + arm64
- Android: x86_64, x86_32, arm64, and arm32
- iOS: arm64
- Web: wasm32, non-threaded, with GDExtension support

The GitHub Actions implementation is in `.github/workflows/native-ci.yml` and
`.github/workflows/native-release.yml`. Pull requests build one representative
configuration for each platform toolchain. Default-branch pushes, tags, and
manual runs build the complete matrix.

## Dependencies

All dependency and toolchain versions are recorded in `dependencies.json`.
Native dependencies are fetched into the ignored repository `.deps/`
directory:

```text
.deps/godot-cpp
.deps/quickhull
```

Fetch or verify them from the repository root:

```powershell
python native/open_brush_hull/tools/setup_dependencies.py
```

The setup script refuses to replace a dependency checkout containing local
changes. Generated binaries under `bin/` and objects under `build/` are
ignored.

## Local Windows Build

From the repository root:

```powershell
.\native\open_brush_hull\build_native_hull.ps1 -Target template_debug -Arch x86_64
.\native\open_brush_hull\build_native_hull.ps1 -Target template_release -Arch x86_64
```

The outputs are:

```text
native/open_brush_hull/bin/windows/open_brush_hull.windows.template_debug.x86_64.dll
native/open_brush_hull/bin/windows/open_brush_hull.windows.template_release.x86_64.dll
```

Other platforms use the same SCons entry point with the required platform
toolchain installed:

```text
scons platform=<platform> arch=<arch> target=<template_debug|template_release> precision=single api_version=4.3
```

Use `threads=no` for Web. Android also receives the NDK package version and API
level recorded in `dependencies.json`.

## Validation and Packaging

Validate the complete manifest without requiring binaries:

```powershell
python native/open_brush_hull/tools/validate_package.py --manifest-only
```

Inspect one locally built binary:

```powershell
python native/open_brush_hull/tools/inspect_binary.py --platform windows --arch x86_64 --target template_debug
```

When every matrix binary has been assembled under `bin/`, validate the package:

```powershell
python native/open_brush_hull/tools/validate_package.py
```

The release workflow runs the same validator and creates a deterministic ZIP,
SHA-256 checksum, dependency licenses, and machine-readable build manifest.
Generated release binaries are workflow artifacts and GitHub Release assets;
they are not committed.

To consume a tagged package in a clean checkout, download
`open_brush_hull-<version>.zip`, verify it against the adjacent `.sha256` file,
and extract its top-level `open_brush_hull/` directory under this repository's
`native/` directory. The resulting project needs neither `.deps/`, SCons, an
SDK, nor a compiler.

## Runtime Tests

Run the local Windows probe with an explicit log:

```powershell
$godot = 'C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
$probeLog = Join-Path $env:TEMP ('open-brush-hull-probe-' + [guid]::NewGuid().ToString('N') + '.log')
$parityLog = Join-Path $env:TEMP ('open-brush-hull-parity-' + [guid]::NewGuid().ToString('N') + '.log')
$env:OPEN_BRUSH_HULL_LOG_PREFIX = 'OBH_LOCAL_NATIVE_TEST'
& $godot --headless --xr-mode off --log-file $probeLog --path . --script res://Tests/GDScript/NativeHullProbe.gd
& $godot --headless --xr-mode off --log-file $parityLog --path . --script res://Tests/GDScript/NativeHullParitySuite.gd
```

The parity inputs are tracked under `Tests/Fixtures/NativeHull/`, so the suite
does not depend on machine-local Godot user data. CI retains complete Godot
logs and requires a unique native-loaded marker.

CI additionally:

- executes debug editor probes on Windows, Linux, and macOS;
- exports and executes release projects on those desktop platforms;
- inspects Android APK ABI contents and runs an x86_64 emulator probe;
- exports a non-threaded Web release and runs it in headless Chromium; and
- exports an iOS Xcode project and links it for arm64 with signing disabled.

A real iOS-device runtime test still requires signing credentials and device
infrastructure and is not represented as an automated runtime pass.

## Parity Status

QuickHull is a geometric convex-hull backend, not an exact port of Unity's
`MIConvexHull35.dll`. It matches the representative regular hull samples in
the tracked parity suite and two of the three ConcaveHull sliding-window
samples. For polygon faces, the suite verifies point count and fan-triangulated
triangle count while separately logging polygon face count.

The remaining known mismatch is ConcaveHull stroke 95's final 10-point window.
Unity/MIConvexHull returns 6 points and 8 fan triangles; this backend returns 8
points and 12 fan triangles for the same points and tolerance. The suite
asserts the current native result explicitly so it cannot change silently.
