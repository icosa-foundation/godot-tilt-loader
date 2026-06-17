# Godot Setup Guide

This project is a GDScript-only Godot port of the Open Brush stroke generation runtime.

## Requirements

- Godot 4.5 or later.
- OpenXR runtime only when testing `Scenes/XrSampleScene.tscn`.

## Open The Project

1. Launch Godot.
2. Import or open the `Assets/` directory.
3. Use `Scenes/SampleScene.tscn` as the default desktop sample.

No .NET SDK, C# solution generation, or C# build step is required.

## Scene Setup

The included sample scene uses:

```text
SampleScene (Node3D)
├── App (App.gd)
├── BrushSystemSetup (BrushSystemSetup.gd)
├── Canvas (MinimalExample.gd)
│   └── Pointer (PointerScript.gd)
├── DrawingController (SimpleDrawingController.gd)
├── Camera3D
└── DirectionalLight3D
```

`BrushSystemSetup.gd` loads the standard and experimental manifests, then initializes `BrushCatalog.gd`.

## Controls

- Hold `Space` to draw in `SampleScene.tscn`.
- Press `M` to toggle automatic pointer movement.
- Press `C` to clear the canvas.
- Press left/right arrows to cycle brushes.
- Press number keys `1` through `5` to change color.

## Troubleshooting

- If no brushes load, check that `Manifest.asset`, `Manifest_Experimental.asset`, and brush resource files are present under the project.
- If XR setup fails in headless or desktop mode, use `--xr-mode off` for non-XR validation.
- For XR diagnostics, inspect `user://xr_debug.log`.

## Validation

Run all parity tests from the `Assets/` project directory:

```powershell
$godot = 'C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
Get-ChildItem -Path Tests\GDScript -Filter *.gd | Sort-Object Name | ForEach-Object {
  & $godot --headless --xr-mode off --path . --script "res://Tests/GDScript/$($_.Name)"
  if ($LASTEXITCODE -ne 0) { throw "Failed $($_.Name)" }
}
```
