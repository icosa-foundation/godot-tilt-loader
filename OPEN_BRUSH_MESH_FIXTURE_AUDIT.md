# Open Brush Mesh Fixture Audit

## Source Snapshot

1. Open Brush branch: `feature/brush-fixtures`.
2. Open Brush commit inspected: `e5cd33e06018a2a07561ad0b02963e1f281b30e5` (`Use deterministic color for brush fixtures`).
3. Raw schema version: `1` for all fixtures.
4. Coordinate declaration: Unity X-right, Y-up, Z-forward; mesh positions are mesh-local.
5. Every current fixture contains exactly one stroke with an identity local-to-world matrix.
6. The raw schema does not embed the producer commit, so comparison reports must record the Open Brush revision separately.

## Corpus Size

1. Raw mesh JSON: 95 files, 35,690,629 bytes.
2. GLB output: 95 files, 11,534,152 bytes.
3. `ConcaveHull` now contains 1,476 vertices, 1,476 indices, and 326 polygon faces.
4. The raw corpus remains in the Open Brush checkout and is read directly; none of these files are copied into this repository.

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

## Direct Harness

`Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd` accepts an explicit
`--fixtures=<directory>` argument and reads Open Brush's raw `.mesh.json` schema
directly. Without that argument it skips so normal Godot test discovery does not
depend on a second checkout. A supplied missing or empty directory is a failure.

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

1. `Ink`: 408 vertices and 408 indices; UV0 size 2.
2. `DuctTapeGeometry`: 140 vertices and 408 indices; UV0 size 2.
3. `Stars`: 348 vertices and 522 indices; UV0 size 4 plus UV1 size 3 particle-position data.
4. `Sparks`: 331 vertices and 1,680 indices; UV0 size 3 with distance semantics.
5. `MatteHull`: 444 vertices and 444 indices; UV0 size 3 with distance semantics.

These five fixtures cover strip, solid geometry, Genius particle, shaped tube,
and hull generation paths. Despite its name and shader, `Sparks` maps to the
`Tube_Sparks` prefab and `TubeBrush`; it is not a `SprayBrush` fixture.

## Spatial Profile Branch Audit

The current 95-brush baseline uses one shared spatial profile. Its serialized
inputs establish the following coverage:

1. Every fixture has 38 control points with position changes on all three axes and orientation changes on all three rotation axes.
2. Pressure spans `0.25` to approximately `0.9943`, exercising pressure-dependent size and opacity over most of their interior range.
3. The path contains three consecutive moves shorter than `0.0001` Open Brush units; the shortest is approximately `0.0000279`. These exercise minimum-movement and break/restart handling in applicable generators.
4. Consecutive path directions turn by as much as 90 degrees, exercising curved and sharp-turn geometry without an artificial 180-degree reversal.
5. Requested brush size is clamped through each descriptor. The resulting corpus contains ten sizes from `0.05` to `1.0` Open Brush units.
6. The 95 catalog brushes collectively exercise the active descriptor variants for UV style, atlas layout, hard and soft edges, caps, double-sided geometry, shape modifiers, particle layouts, and hull modes.
7. Every fixture uses random seed `0`, brush scale `1`, stroke flags `0`, one deterministic non-neutral colour, and one continuous finalized stroke.

Focused Godot parity tests already cover double-back breaks, short-segment
restarts, atlas choices, seeded random formulas, preview decay, finalization,
double-sided output, and class-specific topology. Those tests reduce the value
of multiplying the external C# corpus merely to exercise the same local branch
again.

## Evidence Gaps and Candidate Profiles

These candidates require a fixture-generator decision before implementation:

1. **Non-unit scale — highest value.** Real checked-in cafe strokes use brush scales from approximately `5.05` to `12.37`, while every raw Open Brush mesh fixture uses `1`. Existing tests cover Godot scale plumbing, but not a same-input C#-versus-GDScript mesh at non-unit scale. A small representative profile should cover quad strip, solid, tube, and particle generation rather than all 95 brushes.
2. **Pressure endpoints and a short stroke.** The baseline does not reach pressure exactly `0` or `1`, and its long stroke does not cover two-control-point particle/finalization behavior against C#. A targeted profile could cover one pressure-sensitive geometry brush and one particle brush.
3. **Alternate random seed.** Seed `0` executes random branches and focused tests cover the formulas, but a second seed would provide cross-runtime evidence for salt progression and atlas/randomized particle choices. One representative from each distinct random particle algorithm is sufficient.
4. **Brush-size boundary.** Each brush currently gets one clamped size. A second size is useful only for generators whose topology changes with the size-to-path-length ratio; it should not be applied indiscriminately to the full catalog.

The audit does not recommend external fixtures for preview decay, UI-only
behavior, `Slice`, `PassthroughHull`, or additional hull-backend investigation.
It also does not recommend colour variants unless a concrete geometry branch is
found to depend on colour.
