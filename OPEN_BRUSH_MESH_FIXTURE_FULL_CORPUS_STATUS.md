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

1. Passing fixtures: 82.
2. Failing fixtures: 13.
3. Every fixture loads, resolves its brush descriptor, replays, and emits a comparison summary.
4. Failures remain strict test failures; this report classifies them without weakening comparisons or changing runtime behavior.
5. The initial full-corpus run passed 71 fixtures and failed 24. Runtime and replay corrections have brought eleven more fixtures into parity.

## Failure Classification

1. Deferred MIConvexHull/QuickHull boundary classification (5):
   `DiamondHull`, `MatteHull`, `ShinyHull`, `SmoothHull`, and `UnlitHull`.
   Each reproduces the documented 43-versus-44 boundary-vertex result and ten polygon-face mismatches.
2. Empty source/runtime hull case (1): `ConcaveHull`.
   The deterministic source stroke produces no Open Brush live mesh, so this needs an explicit empty-fixture classification rather than polygon comparison.
3. UV precision just beyond the current `0.00001` tolerance (5):
   `Charcoal`, `DuctTape`, `Flat`, `Highlighter`, and `Streamers`.
   Their first reported UV deltas range from approximately `0.00001144` to `0.00002289`.
4. Shaped-tube configuration/attributes (1): `BubbleWand`.
   Positions, tangents, UVs, and bounds differ while element counts match.
5. Color generation (1): `WetPaint`.
   The first color delta is `0.00392157`, equivalent to one 8-bit color step.

## Resolved Families

1. Shared spray coordinate conversion (7): `CoarseBristles`, `DanceFloor`, `DotMarker`, `HyperGrid`, `Leaves2`, `Splatter`, and `WaveformParticles`.
   The runtime now converts surface normals, tangent handedness, and random position offsets at the Unity-to-Godot boundary while retaining the source rotation axis. Reference replay also uses deterministic export birth times. All seven now match within tolerance.
2. Geometry orientation (3): `3D Printing Brush`, `SquarePaper`, and `ThickGeometry`.
   The square and thick generators now convert the surface frame and tangent handedness consistently with other reflected geometry brushes. The 3D-print generator now uses reflected Unity forward for its indicator plane. All three now match within tolerance.
3. Zero-aspect tube cap normals (1): `Muscle`.
   The tube generator now reproduces Unity `Mathf.Sign(0)` behavior instead of allowing Godot `signf(0)` to zero the cap normal.

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

1. Add explicit coverage accounting for the two registered brushes without source fixtures and the empty `ConcaveHull` fixture.
2. Investigate the remaining generator-specific failures, starting with the one-step `WetPaint` color mismatch.
3. Keep the five hull-family failures deferred under the existing hull-boundary classification.
4. Re-run the full corpus after each family-level correction and update these counts.
