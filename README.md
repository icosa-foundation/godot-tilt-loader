# Open Brush Stroke Generator - Godot GDScript Port

This Godot 4.5+ project ports the Open Brush/Tilt Brush stroke generation runtime from C# to GDScript.

## Status

- Core runtime scripts are implemented in GDScript under `Scripts/`.
- Brush implementations are implemented in GDScript under `Scripts/Brushes/`.
- Utility code is implemented in GDScript under `Scripts/Util/`.
- Runtime scenes reference GDScript scripts only.
- GDScript parity tests live under `Tests/GDScript/`.

## Quick Start

1. Open the repository root as the Godot project.
2. Install addon dependencies with gd-plug if you need Icosa `.tilt` loading or brush materials.
3. Run `Scenes/SampleScene.tscn` for desktop pointer testing.
4. Run `Scenes/XrSampleScene.tscn` for XR testing when OpenXR is available.

The project loads `Resources/BrushCatalog/brush_catalog.json`, a generated catalog containing the brush descriptor and prefab settings that used to come from Unity YAML assets.

## Addon Dependencies

The Icosa Godot addon is kept as a separate local codebase and installed into this project with gd-plug instead of being vendored or added as a git submodule.

Expected local Icosa addon path:

```text
C:\Users\andyb\Documents\icosa-godot-addon\addons\icosa
```

`plug.gd` points at the Icosa repository git URL and includes `addons/icosa` so gd-plug installs the addon at `addons/icosa`.

Install the dependency from the repository root:

```powershell
$godot = 'C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
& $godot --headless --xr-mode off --path . --script res://plug.gd install
```

gd-plug requires Godot and git. This project remains GDScript-only and can be opened with normal non-.NET Godot.

## Native Hull Backend

Real `.tilt` files can contain hull brush strokes with thousands of hull input points. The Unity/Open Brush implementation delegates convex hull generation to `MIConvexHull`; this Godot port uses a local GDExtension for the same hot path.

Build the debug native hull DLL from the repository root:

```powershell
.\native\open_brush_hull\build_native_hull.ps1 -Target template_debug
```

The build script uses ignored local checkouts under `.deps/` and writes ignored binaries under `native/open_brush_hull/bin/`. See `native/open_brush_hull/README.md` for details.

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
└── BrushCatalog/
    └── brush_catalog.json

Scenes/
├── SampleScene.tscn
├── XrSampleScene.tscn
├── MinimalExample.gd
└── MinimalXrExample.gd

Tests/GDScript/
```

## Validation

Run parity tests headlessly with Godot:

```powershell
$godot = 'C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
Get-ChildItem -Path Tests\GDScript -Filter *.gd | Sort-Object Name | ForEach-Object {
  & $godot --headless --xr-mode off --path . --script "res://Tests/GDScript/$($_.Name)"
  if ($LASTEXITCODE -ne 0) { throw "Failed $($_.Name)" }
}
```

## Notes

- Godot uses a right-handed coordinate system; the port keeps explicit conversions where Unity-style forward direction matters.
- Brush rendering still depends on the current Godot material/shader coverage.
- XR debug logging writes to `user://xr_debug.log`.
