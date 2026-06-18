# Open Brush Stroke Generator - Godot GDScript Port

This Godot 4.5+ project ports the Open Brush/Tilt Brush stroke generation runtime from C# to GDScript.

## Status

- Core runtime scripts are implemented in GDScript under `Scripts/`.
- Brush implementations are implemented in GDScript under `Scripts/Brushes/`.
- Utility code is implemented in GDScript under `Scripts/Util/`.
- Runtime scenes reference GDScript scripts only.
- GDScript parity tests live under `Tests/GDScript/`.

## Quick Start

1. Open the `Assets/` folder as the Godot project.
2. Run `Scenes/SampleScene.tscn` for desktop pointer testing.
3. Run `Scenes/XrSampleScene.tscn` for XR testing when OpenXR is available.

The project loads the included brush manifests and Unity `.asset` brush descriptors directly at runtime.

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
