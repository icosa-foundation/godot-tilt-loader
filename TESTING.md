# Testing Runtime Stroke Generation

`Scenes/StrokeDrawingTest.tscn` is configured for desktop stroke testing with GDScript scripts.

## Scene Structure

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

## Manual Controls

- Hold `Space` to draw.
- Press `M` to toggle automatic pointer movement.
- Press `C` to clear the canvas.
- Press left/right arrows to cycle brushes.
- Press `R` to reset the controller state.

## Automated Validation

Run the GDScript parity suite from the repository root:

```powershell
$godot = 'godot'
Get-ChildItem -Path Tests\GDScript -Filter *.gd | Sort-Object Name | ForEach-Object {
  & $godot --headless --xr-mode off --path . --script "res://Tests/GDScript/$($_.Name)"
  if ($LASTEXITCODE -ne 0) { throw "Failed $($_.Name)" }
}
```

## Expected Runtime Behavior

On startup, `BrushSystemSetup.gd` loads brush manifests and initializes `BrushCatalog.gd`. `MinimalExample.gd` assigns the current brush and canvas to `PointerScript.gd`. Drawing creates stroke nodes under the runtime canvas.
