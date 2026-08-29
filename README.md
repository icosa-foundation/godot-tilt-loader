# Open Brush Stroke Generator - Godot GDScript Port

This Godot 4.7+ project ports the Open Brush/Tilt Brush stroke generation runtime from C# to GDScript.

## Status

- Core runtime scripts are implemented in GDScript under `Scripts/`.
- Brush implementations are implemented in GDScript under `Scripts/Brushes/`.
- Utility code is implemented in GDScript under `Scripts/Util/`.
- Runtime scenes reference GDScript scripts only.
- GDScript parity tests live under `Tests/GDScript/`.

## Quick Start

1. Open the repository root as the Godot project.
2. Install addon dependencies with gd-plug for Icosa `.tilt` loading and brush materials.
3. Press Play to run the current main scene, `Scenes/TiltEvidenceViewer.tscn`, with the checked-in cafe fixture.
4. Run `Scenes/StrokeDrawingTest.tscn` for desktop pointer testing without XR, or `Scenes/XrStrokeDrawingTest.tscn` for XR testing.

The project loads `Resources/BrushCatalog/brush_catalog.json`, a generated catalog containing the brush descriptor and prefab settings that used to come from Unity YAML assets.

## Project Scenes

The project has five `.tscn` test scenes. They are intentionally different test surfaces; do not treat them as interchangeable.

### `Scenes/TiltEvidenceViewer.tscn`

Purpose: view the cafe Tilt Brush file and capture evidence renders.

This scene uses `Scripts/TiltEvidenceViewer.gd`. By default it targets:

```text
res://Resources/Fixtures/brush_cafe_experimental.tilt
```

The cafe file is committed as a shared runtime and test fixture, so the default scene works from a clean checkout. Pass `--tilt-file=<path>` after Godot's `--` argument separator to inspect another sketch.

The script reads the `.tilt` file and, by default, rebuilds the scene through the current runtime stroke-generation path. That default avoids masking runtime bugs behind Godot's imported `PackedScene` cache. For fast cached viewing, run with `--imported-packed-scene` or `--load-mode=imported_packed_scene`. It also supports screenshot-oriented command-line options such as `--quit-after-screenshot`, `--render-output=...`, `--thumbnail-output=...`, `--log-output=...`, `--camera-mode=...`, `--only-brushes=...`, and `--load-mode=runtime_rebuild`.

Important distinction: this is a cafe `.tilt` viewing/evidence scene, not the live drawing scene.

### `Scenes/StrokeDrawingTest.tscn`

Purpose: desktop live stroke drawing without XR.

This scene uses `Scenes/MinimalExample.gd`, `Scripts/SimpleDrawingController.gd`, `Scripts/PointerScript.gd`, and `Scripts/BrushSystemSetup.gd`. It initializes the brush catalog, defaults to the Ink brush, and lets a desktop pointer draw into a generated `CanvasScript`.

Controls:

- Hold `Space` to draw.
- Move the mouse to move the pointer on the drawing plane.
- Press `M` to toggle automated torus-knot pointer motion.
- Press `Left` / `Right` to cycle brushes.
- Press `1` through `5` to change color.
- Press `C` to clear the canvas.
- Hold `R` to reset pointer/drawing state.

This scene is the quickest way to debug live mesh generation without headset/OpenXR variables.

### `Scenes/XrStrokeDrawingTest.tscn`

Purpose: XR live stroke drawing proof of concept.

This scene uses `Scripts/App.gd` with `EnableXR = true`, plus `Scenes/MinimalXrExample.gd`, `PointerScript`, and `BrushSystemSetup`. It contains an `XROrigin3D`, `XRCamera3D`, left/right `XRController3D` nodes, visible controller/ray meshes, a blue debug background, a floor plane, and reference cubes so black-screen/controller-visibility problems are easier to separate from drawing problems.

Controls are read from OpenXR actions:

- Right trigger action `trigger_click`: draw.
- Left thumbstick action `primary`: cycle supported runtime brushes.
- Right thumbstick action `primary`: adjust brush size.
- Left controller `by_button`: clear the canvas.

XR logs are written to:

```text
user://xr_debug.log
```

XR can be overridden at launch with `--disable-xr` or `--enable-xr`; otherwise `App.gd` follows the scene's `EnableXR` setting.

### `Scenes/SingleBrushStrokeInspector.tscn`

Purpose: render one synthetic stroke at a time for visual inspection across all supported runtime brushes.

Controls:

1. Press `Left` / `Right` to cycle brushes.
2. Hold `Q` / `E` to rotate the stroke.
3. Press `R` to reset its rotation.
4. Press `F` to toggle the wireframe overlay.
5. Press `C` to cycle culling and cap-debug modes.

### `Scenes/SingleTubeBrushStrokeInspector.tscn`

Purpose: run the same visual inspector over a filtered set of tube-derived brushes.

## Addon Dependencies

The Icosa Godot addon is installed from its Git repository with gd-plug instead of being vendored or added as a git submodule. `plug.gd` includes only the repository's `addons/icosa` directory and installs it at `addons/icosa`.

Install the dependency from the repository root:

```console
godot --headless --xr-mode off --path . --script res://plug.gd install
```

gd-plug requires Godot 4.7+ to be available on `PATH`, plus git. This project remains GDScript-only and can be opened with normal non-.NET Godot.

## Native Hull Backend

Real `.tilt` files can contain hull brush strokes with thousands of hull input points. The Unity/Open Brush implementation delegates convex hull generation to `MIConvexHull`; this Godot port uses a GDExtension for the same hot path.

Validated native libraries for Windows, Linux, macOS, Android, iOS, and Web are committed under `native/open_brush_hull/bin/`, so a clean checkout does not require a native build. Compiler intermediates remain ignored. See `native/open_brush_hull/README.md` for the optional Windows build wrapper, the cross-platform SCons entry point, supported architectures, toolchain requirements, and package validation commands.

## Project Structure

```text
Scripts/
├── App.gd
├── BrushCatalog.gd
├── BrushSystemSetup.gd
├── CanvasScript.gd
├── PointerScript.gd
├── Brushes/
├── Util/
└── UnityAssetLoader.gd

Resources/
├── BrushCatalog/
│   └── brush_catalog.json
└── Fixtures/
    └── brush_cafe_experimental.tilt

Scenes/
├── TiltEvidenceViewer.tscn
├── StrokeDrawingTest.tscn
├── XrStrokeDrawingTest.tscn
├── SingleBrushStrokeInspector.tscn
├── SingleTubeBrushStrokeInspector.tscn
├── MinimalExample.gd
└── MinimalXrExample.gd

Tests/GDScript/
```

## Validation

`Tests/GDScript/` contains both pass/fail tests and diagnostic probes. Run an individual parity test headlessly with Godot:

```console
godot --headless --xr-mode off --path . --script res://Tests/GDScript/BrushLifecycleParityTest.gd
```

To run the normal automated set while excluding diagnostic scripts:

PowerShell:

```powershell
Get-ChildItem -Path Tests\GDScript -Filter *Test.gd |
  Sort-Object Name |
  ForEach-Object {
    godot --headless --xr-mode off --path . --script "res://Tests/GDScript/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { throw "Failed $($_.Name)" }
  }
```

Bash:

```bash
for test_path in Tests/GDScript/*Test.gd; do
  godot --headless --xr-mode off --path . --script "res://$test_path" || exit 1
done
```

See `OPEN_BRUSH_PARITY_TEST_INVENTORY.md` for the distinction between parity tests, visual smoke tests, and diagnostic probes.

## Notes

- Godot uses a right-handed coordinate system; the port keeps explicit conversions where Unity-style forward direction matters.
- Brush rendering still depends on the current Godot material/shader coverage.
- XR debug logging writes to `user://xr_debug.log`.
