# Open Brush Mesh Fixture Audit

## Source Snapshot

1. Open Brush branch: `feature/brush-fixtures`.
2. Open Brush commit: `80f6362533fd7e4366d915670a71e20df479b364` (`Mesh fixtures for compatibility tests in godot and threejs`).
3. Raw schema version: `1` for all fixtures.
4. Coordinate declaration: Unity X-right, Y-up, Z-forward; mesh positions are mesh-local.
5. Every current fixture contains exactly one stroke with an identity local-to-world matrix.

## Corpus Size

1. Raw mesh JSON: 95 files, 26,064,558 bytes.
2. GLB output: 94 files, 10,968,700 bytes.
3. Estimated compact input-plus-live-mesh JSON: approximately 4,238,000 bytes before final converter formatting.
4. `ConcaveHull` is the only current fixture with an empty live mesh. It accounts for the missing ninety-fifth GLB.

The compact estimate excludes material snapshots, `BrushBaker` diagnostics, post-bake meshes, and GLB metadata.

## Godot Coverage

1. The merged Godot manifests contain 101 unique normal brush GUIDs.
2. Four explicitly unsupported ParentBrush composites reduce the registered live set to 97 brushes.
3. The Open Brush fixture set covers 95 of those 97 live GUIDs.
4. `Slice` (`8d1510b2-1fc5-4c90-8db7-4c07eecfd849`) has no raw fixture.
5. `PassthroughHull` (`cc131ff8-0d17-4677-93e0-d7cd19fea9ac`) has no raw fixture.
6. No raw fixture GUID falls outside the registered Godot live-brush set.
7. Durable names agree for every shared GUID.

## Live-Mesh Schema Variants

The raw fixture stores flattened typed attributes with `itemSize`, semantic, component type, and data. Current live attribute combinations are:

1. `color,normal,position,tangent`: 1 fixture.
2. `color,normal,position,tangent,texcoord0`: 74 fixtures.
3. `color,normal,position,tangent,texcoord0,texcoord1`: 6 fixtures.
4. `color,normal,position,texcoord0`: 6 fixtures.
5. `color,normal,position,texcoord0,texcoord1`: 7 fixtures.
6. `color,position`: 1 fixture.

Current texcoord layout combinations are:

1. No texcoords: 2 fixtures.
2. UV0 size 2 with unspecified semantic: 2 fixtures.
3. UV0 size 2 with `XyIsUv`: 47 fixtures.
4. UV0 size 2 with UV1 size 3 `Vector`: 3 fixtures.
5. UV0 size 2 with UV1 size 4 `Vector`: 3 fixtures.
6. UV0 size 3 with `XyIsUvZIsDistance`: 31 fixtures.
7. UV0 size 4 with UV1 size 3 `Position`: 7 fixtures.

## Existing Harness Gap

`Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd` currently expects the older `open-brush-reference-mesh-v1` format: nested vector rows, an already-converted stroke, and no raw-fixture provenance. The new Open Brush corpus uses flattened raw attributes and retains Unity/Open Brush coordinates. Directly copying the files would not exercise the harness correctly.

## Required Comparison Boundary

1. Reflect source control-point Z from Unity into Godot coordinates.
2. Convert source orientations with `[-x, -y, z, w]` for the Z reflection.
3. Replay in Open Brush runtime units because the Godot port intentionally retains `App.METERS_TO_UNITS = 10` internally.
4. Convert both actual and expected mesh quantities to metres for comparison with a `0.1` scale.
5. Reflect expected position, normal, tangent, and applicable UV/vector Z components.
6. Flip tangent handedness.
7. Preserve triangle winding and triangle-soup record order because Unity and Godot both use clockwise front faces. The Three.js comparator reverses winding because Three.js uses the opposite front-face convention; that step is not equivalent for Godot.
8. Scale semantic position/distance attributes according to their declared vertex-layout semantics.

## Five-Brush Pilot

1. `Ink`: 360 vertices and 360 indices; UV0 size 2.
2. `DuctTapeGeometry`: 124 vertices and 348 indices; UV0 size 2.
3. `Stars`: 288 vertices and 432 indices; UV0 size 4 plus UV1 size 3 particle-position data.
4. `Sparks`: 295 vertices and 1,488 indices; UV0 size 3 with distance semantics.
5. `MatteHull`: 246 vertices and 246 indices; UV0 size 3 with distance semantics.

These five fixtures cover strip, solid geometry, Genius particle, shaped tube,
and hull generation paths. Despite its name and shader, `Sparks` maps to the
`Tube_Sparks` prefab and `TubeBrush`; it is not a `SprayBrush` fixture.
