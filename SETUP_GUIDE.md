# Godot Setup Guide

This project is a GDScript-only Godot port of the Open Brush stroke generation runtime.

## Requirements

- Godot 4.5 or later.
- git and gd-plug when installing local addon dependencies.
- OpenXR runtime only when testing `Scenes/XrStrokeDrawingTest.tscn`.

## Open The Project

1. Launch Godot.
2. Import or open the repository root.
3. Press Play to run `Scenes/TiltViewer.tscn`.

No .NET SDK, C# solution generation, or C# build step is required.

## Addon Dependencies

Icosa `.tilt` loading and Open Brush brush shader/material support are provided
by the separate Icosa Godot addon. `plug.gd` points at its Git repository and
includes `addons/icosa` so the installed addon name stays `icosa`.

This project uses gd-plug to install that addon into `addons/icosa` from `plug.gd`:

```powershell
$godot = 'godot'
& $godot --headless --xr-mode off --path . --script res://plug.gd install
```

gd-plug runs through Godot and git. The installed addon folder is ignored by git, so the Icosa addon is not committed here.

## Scene Setup

The default Play scene is `Scenes/TiltViewer.tscn`, which loads the configured `.tilt` file through the Icosa addon.

The desktop stroke test scene uses:

```text
StrokeDrawingTest (Node3D)
├── App (App.gd)
├── BrushSystemSetup (BrushSystemSetup.gd)
├── Canvas (MinimalExample.gd)
│   └── Pointer (PointerScript.gd)
├── DrawingController (SimpleDrawingController.gd)
├── Camera3D
└── DirectionalLight3D
```

`BrushSystemSetup.gd` loads the standard and experimental brush lists from `Resources/BrushCatalog/brush_catalog.json`, then initializes `BrushCatalog.gd`.

## Controls

- Hold `Space` to draw in `StrokeDrawingTest.tscn`.
- Press `M` to toggle automatic pointer movement.
- Press `C` to clear the canvas.
- Press left/right arrows to cycle brushes.
- Press number keys `1` through `5` to change color.

## Troubleshooting

- If no brushes load, check that `Resources/BrushCatalog/brush_catalog.json` is present under the project.
- If XR setup fails in headless or desktop mode, use `--xr-mode off` for non-XR validation.
- For XR diagnostics, inspect `user://xr_debug.log`.

## Validation

Run all parity tests from the repository root:

```powershell
$godot = 'godot'
Get-ChildItem -Path Tests\GDScript -Filter *.gd | Sort-Object Name | ForEach-Object {
  & $godot --headless --xr-mode off --path . --script "res://Tests/GDScript/$($_.Name)"
  if ($LASTEXITCODE -ne 0) { throw "Failed $($_.Name)" }
}
```
