# Open Brush Mesh Fixture Full-Corpus Status

## Snapshot

1. Open Brush producer commit: `cd1c6529cffbbc897df43d3087a668306418f4a7` (`Deduplicate fixture hull triangles`).
2. Raw fixtures converted: 95.
3. Normalized fixture size: 11,491,376 bytes (`10.96 MiB`).
4. Registered Godot live brushes covered: 95 of 97.
5. Brushes without source fixtures remain `Slice` and `PassthroughHull`.
6. Full deterministic converter check completes in approximately one second.
7. Full Godot replay comparison completes in under one second on the measured Windows development machine.

## Current Full-Corpus Result

1. Passing fixtures: 34.
2. Failing fixtures: 61.
3. Every fixture loads, resolves its brush descriptor, replays, and emits a comparison summary.
4. Remaining mismatches stay strict test failures; this report records the comparator's absolute and relative numeric allowances explicitly.
5. The earlier planar corpus reached 90 passing fixtures and 5 deferred hull
   failures. The spatial corpus deliberately varies all three position axes,
   orientation, pressure, segment length, and turn angle, exposing behavior the
   planar input did not exercise.

## Failure Classification

1. Spatial orientation/curvature discrepancies (55). Every affected fixture
   reports position and normal differences; 50 also report tangent differences,
   34 report UV0 differences, 6 report UV1 differences, and the resulting bounds
   account for 64 assertions. Tube-family fixtures generally remain matching,
   while flat/Quill-derived, spray, and several geometry brushes are affected.
2. Deferred MIConvexHull/QuickHull boundary classification (6):
   `ConcaveHull`, `DiamondHull`, `MatteHull`, `ShinyHull`, `SmoothHull`, and
   `UnlitHull`. The five convex hull fixtures each have 24 of 148 Open Brush
   polygon faces without a native match. `ConcaveHull` has 326 reference faces
   and no native Godot hull result.

## Earlier Planar-Baseline Resolutions

These fixes remain in the runtime, but a brush listed here may fail the stronger
spatial baseline for a newly exercised branch.

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
6. Empty source/runtime output handling was validated by the planar corpus. The
   spatial baseline intentionally supersedes that input: Open Brush now emits a
   non-empty `ConcaveHull` with 1,476 vertices and 326 polygon faces, exposing
   the native Godot failure described above. Coverage still verifies that the
   95-fixture corpus omits only `Slice` and `PassthroughHull`.
7. Accumulated distance-UV precision (5): `Charcoal`, `DuctTape`, `Flat`, `Highlighter`, and `Streamers`.
   Their UV offsets were six float32 representable steps after repeated cross-runtime vector-length accumulation. UV comparisons now retain the `0.00001` absolute tolerance and add a one-part-per-million relative allowance; no runtime arithmetic changed.

## Reproduction

Convert and verify the complete corpus from the repository root:

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tools/OpenBrushMeshFixtures/ConvertOpenBrushMeshFixtures.gd -- `
  --source-dir=<open-brush>/Support/BrushFixtures `
  --source-commit=cd1c6529cffbbc897df43d3087a668306418f4a7 `
  --check
```

Run all comparisons:

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd -- `
  --require-open-brush-reference-fixtures
```

## Next Work

1. Keep the six hull-family failures deferred under the existing hull-backend classification.
2. Investigate the shared orientation/curvature discrepancy before selecting a
   first runtime family to modify.
3. Audit material-generator branch coverage and add only targeted named input
   profiles for branches the spatial baseline does not reach.
4. Re-run the full corpus after any fixture, adapter, or relevant runtime change and update these counts.
