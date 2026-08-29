# Open Brush Mesh Fixture Full-Corpus Status

## Snapshot

1. Open Brush producer commit: `56881962ca7ced358407fd62d842649978dbd4a0` (`Ngon fixtures for hull brushes`).
2. Raw fixtures converted: 95.
3. Normalized fixture size: 10,813,776 bytes (`10.31 MiB`).
4. Registered Godot live brushes covered: 95 of 97.
5. Brushes without source fixtures remain `Slice` and `PassthroughHull`.
6. Full deterministic converter check completes in approximately one second.
7. Full Godot replay comparison completes in approximately three seconds on the measured Windows development machine.

## Current Full-Corpus Result

1. Passing fixtures: 90.
2. Failing fixtures: 5.
3. Every fixture loads, resolves its brush descriptor, replays, and emits a comparison summary.
4. Remaining mismatches stay strict test failures; this report records the comparator's absolute and relative numeric allowances explicitly.
5. The initial full-corpus run passed 71 fixtures and failed 24. Runtime, replay, and numeric-comparison corrections now classify nineteen more fixtures as matching.

## Failure Classification

1. Deferred MIConvexHull/QuickHull boundary classification (5):
   `DiamondHull`, `MatteHull`, `ShinyHull`, `SmoothHull`, and `UnlitHull`.
   Each reproduces the documented 43-versus-44 boundary-vertex result and ten polygon-face mismatches.

## Resolved Families

1. Shared spray coordinate conversion (7): `CoarseBristles`, `DanceFloor`, `DotMarker`, `HyperGrid`, `Leaves2`, `Splatter`, and `WaveformParticles`.
   The runtime now converts surface normals, tangent handedness, and random position offsets at the Unity-to-Godot boundary while retaining the source rotation axis. Reference replay also uses deterministic export birth times. All seven now match within tolerance.
2. Geometry orientation (3): `3D Printing Brush`, `SquarePaper`, and `ThickGeometry`.
   The square and thick generators now convert the surface frame and tangent handedness consistently with other reflected geometry brushes. The 3D-print generator now uses reflected Unity forward for its indicator plane. All three now match within tolerance.
3. Zero-aspect tube cap normals (1): `Muscle`.
   The tube generator now reproduces Unity `Mathf.Sign(0)` behavior instead of allowing Godot `signf(0)` to zero the cap normal.
4. Hue-shifted backface color conversion (1): `WetPaint`.
   Generated HSL backface colors now use Unity-compatible rounded Color32 conversion without changing the general color and alpha paths.
5. Current prefab routing (1): `BubbleWand`.
   The brush descriptor points to `TubeStretchUV.prefab`, whose script is `TubeBrush.cs`. Removing the durable-name-only `BubbleWandBrush` override restores the fixture's regular tube positions, UVs, tangents, and bounds.
6. Empty source/runtime output (1): `ConcaveHull`.
   Both runtimes produce an empty finalized mesh for the deterministic stroke. The comparator now verifies empty geometry and attributes without requiring a successful internal native-hull object. It also accounts for all 97 live brushes and verifies that the 95-fixture corpus omits only `Slice` and `PassthroughHull`.
7. Accumulated distance-UV precision (5): `Charcoal`, `DuctTape`, `Flat`, `Highlighter`, and `Streamers`.
   Their UV offsets were six float32 representable steps after repeated cross-runtime vector-length accumulation. UV comparisons now retain the `0.00001` absolute tolerance and add a one-part-per-million relative allowance; no runtime arithmetic changed.

## Reproduction

Convert and verify the complete corpus from the repository root:

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tools/OpenBrushMeshFixtures/ConvertOpenBrushMeshFixtures.gd -- `
  --source-dir=<open-brush>/Support/BrushFixtures `
  --source-commit=56881962ca7ced358407fd62d842649978dbd4a0 `
  --check
```

Run all comparisons:

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd -- `
  --require-open-brush-reference-fixtures
```

## Next Work

1. Keep the five hull-family failures deferred under the existing hull-boundary classification.
2. Re-run the full corpus after any fixture, adapter, or relevant runtime change and update these counts.
