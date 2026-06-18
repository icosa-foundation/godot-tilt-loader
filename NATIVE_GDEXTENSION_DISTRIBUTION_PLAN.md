# Native GDExtension Distribution Plan

## Problem

The current hull acceleration path depends on a local GDExtension built from source:

- `native/open_brush_hull/`
- `.deps/godot-cpp/`
- `.deps/quickhull/`

This proves the approach locally, but it does not solve distribution. End users and addon consumers should not need a compiler, SCons, Godot headers, or local dependency cloning just to load `.tilt` files with hull brushes.

The binary that matters is not a standalone QuickHull library. It is the Godot extension binary that wraps the hull implementation and exposes `NativeConvexHullUtil` to GDScript.

## Target Shape

Create a separate native extension repository, for example:

```text
open-brush-godot-native
  native/open_brush_hull/
  thirdparty/quickhull/
  thirdparty/godot-cpp/ or pinned fetch scripts
  .github/workflows/build.yml
  README.md
  LICENSE notices
```

That repository owns:

- The C++ GDExtension source.
- The selected hull backend, initially QuickHull unless replaced.
- Pinned dependency versions.
- Platform build scripts.
- GitHub Actions workflows.
- Release artifacts for Godot projects/addons to consume.

The Godot project and the Icosa addon should consume built artifacts from that repo rather than building native code during normal use.

## Why Not A QuickHull Binary Repo

QuickHull is only the algorithm dependency. Shipping `quickhull.dll` would not be enough because Godot needs a GDExtension binary built against:

- The target Godot/GDExtension API.
- `godot-cpp`.
- Our wrapper class and binding code.
- Platform-specific compiler and linker settings.

If QuickHull needs patches, we can fork or vendor it. But the CI artifact should be the complete `open_brush_hull` GDExtension, not a generic QuickHull library.

## CI Outputs

Initial required artifacts:

```text
open_brush_hull.windows.template_debug.x86_64.dll
open_brush_hull.windows.template_release.x86_64.dll
open_brush_hull.linux.template_debug.x86_64.so
open_brush_hull.linux.template_release.x86_64.so
open_brush_hull.macos.template_debug.framework or dylib
open_brush_hull.macos.template_release.framework or dylib
```

Later targets to evaluate:

- Web/WASM, if the Godot Web GDExtension path is practical for this project.
- Android.
- iOS.

Each release should include:

- Built binaries.
- Matching `.gdextension` file.
- Dependency license notices.
- The Godot version and `godot-cpp` commit used.
- A simple smoke-test log or CI summary.

## Consumption Model

For this project, continue using a local junction/addon workflow while the renderer is still changing.

Once native CI exists:

1. Keep the addon separately useful.
2. Do not merge the Icosa addon and the brush runtime into one addon just to share native binaries.
3. Consume the native extension as a downloaded artifact or copied release package under `native/open_brush_hull/`.
4. Keep the GDScript hull fallback for unsupported platforms, but treat it as degraded behavior for large hull strokes.

## Near-Term Steps

1. Keep the current local native build while validating hull correctness.
2. Pin the current QuickHull source to a specific upstream commit.
3. Decide whether QuickHull parity is good enough or whether an MIConvexHull-compatible backend is required.
4. Move or copy the native extension source into a dedicated repo once the API surface stabilizes.
5. Add CI matrix builds for Windows, Linux, and macOS.
6. Publish a release and update this project to consume those artifacts.
7. Document fallback behavior for unsupported platforms.

## Current Local Status

The current project has Windows debug and release native binaries built locally. The debug/editor path has been runtime-smoked through Godot headless. Non-Windows binaries are not currently built.

Unsupported platforms fall back to GDScript through `Scripts/Util/ConvexHullUtil.gd`, which is functionally useful for small inputs but too slow for large `.tilt` hull strokes.

The current backend wraps QuickHull. That is fast enough for the cafe hull smoke test, but it is not bit-for-bit or topology-for-topology identical to Unity's `MIConvexHull35.dll`. Representative regular hull samples match Unity/MIConvexHull point and face counts at the calibrated tolerance. Two of the three sampled ConcaveHull windows match; ConcaveHull stroke 95's final window is a known mismatch where MIConvexHull returns 6 points / 8 faces and QuickHull returns 8 points / 12 faces for the same 10 input points.

Godot's exposed geometry API does not currently remove the need for this extension. `Geometry2D.convex_hull` is 2D-only, and `Geometry3D` does not expose a point-cloud-to-3D-hull topology method equivalent to Unity's MIConvexHull usage.
