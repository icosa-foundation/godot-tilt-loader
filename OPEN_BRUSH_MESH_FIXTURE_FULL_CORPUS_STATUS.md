# Open Brush Mesh Fixture Full-Corpus Status

## Snapshot

1. Open Brush producer commit: `56881962ca7ced358407fd62d842649978dbd4a0` (`Ngon fixtures for hull brushes`).
2. Raw fixtures converted: 95.
3. Normalized fixture size: 10,813,776 bytes (`10.31 MiB`).
4. Registered Godot live brushes covered: 95 of 97.
5. Brushes without source fixtures remain `Slice` and `PassthroughHull`.
6. Full deterministic converter check completes in approximately one second.
7. Full Godot replay comparison completes in approximately three seconds on the measured Windows development machine.

## First Full-Corpus Result

1. Passing fixtures: 71.
2. Failing fixtures: 24.
3. Every fixture loads, resolves its brush descriptor, replays, and emits a comparison summary.
4. Failures remain strict test failures; this report classifies them without weakening comparisons or changing runtime behavior.

## Failure Classification

1. Deferred MIConvexHull/QuickHull boundary classification (5):
   `DiamondHull`, `MatteHull`, `ShinyHull`, `SmoothHull`, and `UnlitHull`.
   Each reproduces the documented 43-versus-44 boundary-vertex result and ten polygon-face mismatches.
2. Empty source/runtime hull case (1): `ConcaveHull`.
   The deterministic source stroke produces no Open Brush live mesh, so this needs an explicit empty-fixture classification rather than polygon comparison.
3. UV precision just beyond the current `0.00001` tolerance (5):
   `Charcoal`, `DuctTape`, `Flat`, `Highlighter`, and `Streamers`.
   Their first reported UV deltas range from approximately `0.00001144` to `0.00002289`.
4. Surface-frame or particle handedness (4):
   `DanceFloor`, `DotMarker`, `HyperGrid`, and `WaveformParticles`.
   The first reported mismatch is a reflected normal; some also differ in tangent handedness or shader-facing attributes.
5. Geometry orientation or generator-specific displacement (6):
   `3D Printing Brush`, `CoarseBristles`, `Leaves2`, `Splatter`, `SquarePaper`, and `ThickGeometry`.
   These have matching element counts but material position/topology signatures differ.
6. Shaped-tube configuration/attributes (1): `BubbleWand`.
   Positions, tangents, UVs, and bounds differ while element counts match.
7. Missing or zeroed surface data (1): `Muscle`.
   The first reported mismatch is a zero actual normal where Open Brush emits a unit normal.
8. Color generation (1): `WetPaint`.
   The first color delta is `0.00392157`, equivalent to one 8-bit color step.

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
2. Investigate failure families rather than individual durable names, starting with shared surface-frame handedness because one correction may cover four fixtures.
3. Keep the five hull-family failures deferred under the existing hull-boundary classification.
4. Re-run the full corpus after each family-level correction and update these counts.
