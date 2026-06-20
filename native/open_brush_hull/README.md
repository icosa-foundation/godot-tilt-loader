# Open Brush Hull GDExtension

Native convex hull backend for Godot hull brushes.

The GDScript hull fallback is intentionally kept, but real `.tilt` hull strokes should use `NativeConvexHullUtil` when this extension is built and loaded. The native backend wraps Antti Kuukka's public-domain QuickHull implementation.

The GDScript brush code passes the same tolerance scale used by the Unity hull brushes (`1e-6 * App.METERS_TO_UNITS * pointer_to_local()`). The native wrapper rejects too-small, collinear, and coplanar point sets before calling QuickHull so degenerate inputs behave like Unity's null-hull path instead of producing a synthetic thin hull. QuickHull's triangle buffer is converted back into ordered polygon faces for truly coplanar facets; brush geometry still fan-triangulates those faces when writing mesh indices.

## Parity Status

QuickHull is a geometric convex hull backend, not an exact port of Unity's `MIConvexHull35.dll`. It matches the representative regular hull samples checked from `brush_cafe_experimental.tilt` by hull point count and fan-triangulated triangle count, and it matches two of the three ConcaveHull sliding-window samples exported from that file.

The remaining known mismatch is ConcaveHull stroke 95's final 10-point window. Unity/MIConvexHull returns 6 points and 8 faces; this native backend returns 8 points and 12 faces for the same points and tolerance. Inspection of MIConvexHull shows that it keeps original vertex indices, does not pre-deduplicate equal positions, and has singular-vertex handling. That can make duplicate geometric points affect the final hull topology in ways QuickHull does not reproduce.

Godot's public `Geometry2D.convex_hull` API is 2D-only. The public `Geometry3D` API exposes helpers such as `compute_convex_mesh_points`, but not a point-cloud-to-3D-hull topology method that can replace this extension.

## Dependencies

The build uses local, ignored dependency checkouts:

- `.deps/godot-cpp`
- `.deps/quickhull`

The build script pins those checkouts to the commits currently validated with this project:

- `godot-cpp`: `f8a4e78f47f199e3591d2bedcaadcb905b6d7d7b`
- QuickHull: `4ef66c68950cb4db11d3b75bfe4034d807485ad0`

Do not commit those folders or generated build outputs under `bin/`. A separate distribution repo should eventually build release artifacts for all supported platforms; see `NATIVE_GDEXTENSION_DISTRIBUTION_PLAN.md`.

## Current Platform Status

Windows x86_64 debug and release binaries have been built locally. The debug/editor path has been runtime-smoked with Godot headless. Unsupported platforms fall back to the GDScript hull implementation through `Scripts/Util/ConvexHullUtil.gd`, which is not fast enough for large `.tilt` hull strokes.

## Build

From the repository root:

```powershell
.\native\open_brush_hull\build_native_hull.ps1 -Target template_debug
```

The debug DLL is written to:

```text
native/open_brush_hull/bin/open_brush_hull.windows.template_debug.x86_64.dll
```

The corresponding release target is expected at:

```text
native/open_brush_hull/bin/open_brush_hull.windows.template_release.x86_64.dll
```

`open_brush_hull.gdextension` points at those filenames for Windows debug and release runs.

Verify the extension from the repository root:

```powershell
$godot = 'C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
$log = Join-Path $env:TEMP ('open-brush-hull-' + [guid]::NewGuid().ToString('N') + '.log')
& $godot --headless --xr-mode off --log-file $log --path . --script res://Tests/GDScript/NativeHullProbe.gd
```

Representative parity CSVs can be regenerated from the cafe tilt fixture:

```powershell
$userData = 'C:/Users/andyb/AppData/Roaming/Godot/app_userdata/open-brush-stroke-gen-godot'
& $godot --headless --xr-mode off --log-file $log --path . --script res://Tests/GDScript/HullBrushTiltProbe.gd -- --tilt=res://Temp/TiltEvidence/brush_cafe_experimental.tilt --max-hull-strokes=120 --detail-hull-indices=3,31,85,89,91,92,98,99,111 --detail-output-prefix=$userData/hull_compare
& $godot --headless --xr-mode off --log-file $log --path . --script res://Tests/GDScript/HullBrushTiltProbe.gd -- --tilt=res://Temp/TiltEvidence/brush_cafe_experimental.tilt --max-hull-strokes=100 --detail-hull-indices=95,96,97 --detail-output-prefix=$userData/concave_compare_current
```

`HullBrushTiltProbe.gd` writes the same hull input that `HullBrush` uses at runtime, including interior-vertex filtering and duplicate-tail omission. Example pass/fail count assertions:

```powershell
& $godot --headless --xr-mode off --log-file $log --path . --script res://Tests/GDScript/NativeHullParitySuite.gd
& $godot --headless --xr-mode off --log-file $log --path . --script res://Tests/GDScript/NativeHullProbe.gd -- --csv='C:\Users\andyb\AppData\Roaming\Godot\app_userdata\open-brush-stroke-gen-godot\hull_compare_085.csv' --tolerance=0.000014966814 --expect-points=221 --expect-triangles=438
& $godot --headless --xr-mode off --log-file $log --path . --script res://Tests/GDScript/NativeHullProbe.gd -- --csv='C:\Users\andyb\AppData\Roaming\Godot\app_userdata\open-brush-stroke-gen-godot\hull_compare_111.csv' --tolerance=0.000010017480 --expect-points=190 --expect-triangles=376
```

Use an explicit `--log-file` for scripted/headless runs. In this local Godot 4.6.1 setup, the default project log rotation path can fail intermittently when launching repeated headless processes.

The parity suite checks the representative regular hull samples plus ConcaveHull windows 96 and 97. For polygon faces, it verifies point count and fan-triangulated triangle count while separately logging polygon face count. It also reports ConcaveHull 95 as a known mismatch and verifies the current native result remains 8 points / 12 fan triangles rather than silently changing. Unity/MIConvexHull returns 6 points / 8 triangles for that degenerate duplicate-tail window.
