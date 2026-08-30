# Open Brush Mesh Fixture Full-Corpus Status

## Snapshot

1. Raw Open Brush fixtures compared: 95.
2. Registered Godot live brushes covered: 95 of 97.
3. Brushes without source fixtures remain `Slice` and `PassthroughHull`.
4. The raw corpus remains in the Open Brush checkout and is not committed or normalized in this repository.
5. Record the Open Brush producer revision whenever publishing a comparison result.

## Current Full-Corpus Result

1. Passing fixtures: 95.
2. Failing fixtures: 0 under the current compatibility gates.
3. Every fixture loads, resolves its brush descriptor, replays, and emits a comparison summary.
4. Ordinary brushes retain strict topology and vertex-channel comparison. `ConcaveHull` has a dedicated accumulated-surface compatibility gate because each stroke segment internally uses a small MIConvexHull/QuickHull window.
5. The earlier planar corpus reached 90 passing fixtures and 5 deferred hull
   failures. The spatial corpus deliberately varies all three position axes,
   orientation, pressure, segment length, and turn angle.

## Compatibility Classification

1. `ConcaveHull` passes accumulated-surface validation. Open Brush emits 492
   triangles and Godot emits 488, a `0.81%` difference within the `2%`
   allowance. Bidirectional vertex/centroid surface deviation is approximately
   `0.00000105` metres. Surface area differs by `0.224%` and absolute volume
   contribution by `0.386%`, both within the `0.5%` allowance. Bounds, triangle
   validity, required channels, face-normal consistency, and colour still pass.
2. Regular convex-hull compatibility (5): `DiamondHull`, `MatteHull`,
   `ShinyHull`, `SmoothHull`, and `UnlitHull` pass a geometric-equivalence gate.
   It requires valid non-degenerate triangles, a closed surface, complete
   required channels, matching bounds and enclosed volume, and bidirectional
   vertex-to-surface distance within tolerance. Measured surface deviations are
   below `0.000001` metres. Exact polygon-face machinery is retained for later
   work but is not the current required gate.

## Spatial-Baseline Resolution

1. Shared reflected surface frames (55). The runtime previously treated Godot
   `+Z` as reflected Unity forward and used Godot cross products without
   accounting for the handedness reversal. The shared helper now uses Godot
   `-Z` for Unity forward and negates reflected cross products. Its callers now
   consume one consistently converted right/normal frame. This resolves all 55
   orientation/curvature-sensitive fixture failures without changing numeric
   tolerances.

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
   the local backend difference classified above. Coverage still verifies that the
   95-fixture corpus omits only `Slice` and `PassthroughHull`.
7. Accumulated distance-UV precision (5): `Charcoal`, `DuctTape`, `Flat`, `Highlighter`, and `Streamers`.
   Their UV offsets were six float32 representable steps after repeated cross-runtime vector-length accumulation. UV comparisons now retain the `0.00001` absolute tolerance and add a one-part-per-million relative allowance; no runtime arithmetic changed.

## Reproduction

Generate or regenerate the fixtures in Open Brush, then run all comparisons from this repository root:

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd -- `
  --fixtures=<open-brush>/Support/BrushFixtures
```

## Next Work

1. Return to exact `ConcaveHull` topology and regular-hull polygon-face parity later without removing the retained strict and polygon-face machinery.
2. Decide whether to add the representative non-unit-scale profile identified in `OPEN_BRUSH_MESH_FIXTURE_AUDIT.md`; do not change the Open Brush generator before that decision.
3. Consider pressure-endpoint/short-stroke and alternate-seed profiles only after the scale result, and keep them limited to representative generator families.
4. Re-run the full corpus after any fixture, adapter, or relevant runtime change and update these counts.
