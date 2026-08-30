# Open Brush Mesh Fixture Parity Plan

## Objective

Establish authoritative same-input mesh parity between the Open Brush C# runtime and this Godot GDScript port. Use Open Brush's deterministic brush fixtures as the oracle, compare against the fixture's finalized live mesh before `BrushBaker`, and keep baking and GLB import/export validation in separate suites.

## Principles

1. Treat the Open Brush live mesh as authoritative reference output.
2. Replay the fixture's exact control points, orientations, pressure, colour, brush size, scale, flags, and seed.
3. Apply Open-Brush-units-to-metres and Unity-to-Godot coordinate conversion only at the fixture comparison boundary.
4. Compare topology exactly. Compare positions, normals, colors, and UVs with a
   tolerance of `0.00001`. Use `0.00005` for normalized tangents because the
   pilot measured a `0.00003678` tangent delta produced by sub-micrometre vertex
   differences, while the corresponding topology and source channels match.
5. Preserve full vertex-channel widths, including shader-facing particle attributes.
6. Diagnose broad failures as possible conversion-boundary defects before changing brush runtime code or relaxing tolerances.
7. Never regenerate expected output from the Godot implementation.
8. Record the Open Brush generator revision with reported results so the external raw fixtures are reproducible.

## Phase 1: Corpus and Harness Audit

1. Inspect the current `OpenBrushReferenceMeshFixtureTest.gd` contract.
2. Inspect representative raw fixtures for strip, solid, particle, and hull brushes.
3. Measure raw JSON and GLB sizes, fixture count, durable-name/GUID coverage, channel layouts, and schema variants.
4. Reconcile the 95 Open Brush fixtures with the Godot catalog and its 97 registered live brushes.
5. Record any missing, duplicate, unsupported, or non-geometric brush cases before importing data.

Deliverable: a schema and coverage report grounded in the actual fixture corpus.

## Phase 2: Direct Raw Fixture Reader

1. Read raw Open Brush `.mesh.json` fixtures directly from an explicitly supplied directory.
2. Reject unknown raw schema versions and coordinate systems.
3. Use the fixture's `input`, `vertexLayout`, `live`, and `polygonFaces` data without writing an intermediate fixture format.
4. Ignore post-`BrushBaker` mesh data and GLBs in the mesh-generation comparison.
5. Keep Unity-to-Godot coordinate and unit conversion at the in-memory comparison boundary.

Deliverable: direct raw reader and focused coordinate-boundary validation.

## Phase 3: Five-Brush Pilot

Start with the existing representative fixture families:

1. Ink for quad-strip behavior.
2. DuctTapeGeometry for solid geometry.
3. Stars for Genius particle data.
4. Sparks for tube geometry with shape-modifier displacement.
5. MatteHull for native/fallback hull behavior.

For each brush, replay the exact fixture input through the shared runtime registry and compare:

1. Vertex and index counts.
2. Triangle indices and topology exactly.
3. Positions, normals, tangents, colours, UV0, UV1, UV2, and bounds.
4. Full-width custom or shader-facing vertex records where present.

Mismatch reports should identify the brush, channel, element index, expected value, actual value, delta, and relevant stroke/control-point context.

Deliverable: five authoritative C#-versus-GDScript fixture tests with actionable failure output.

## Phase 4: Coordinate-Conversion Validation

1. Verify the `0.1` Open Brush units-to-metres scale at the boundary.
2. Verify Unity-to-Godot handedness conversion for positions and orientations.
3. Verify triangle winding after reflection against Godot's front-face convention.
4. Verify normals, tangents, tangent handedness, bounds, and surface-frame behavior.
5. Keep runtime brush code in its native Godot coordinate conventions; do not distribute fixture conversion logic through brush implementations.

Deliverable: a small, independently tested conversion module used by the fixture comparator.

## Phase 5: Full Corpus and Coverage

1. Compare all suitable raw live-mesh fixtures without checking the corpus into this repository.
2. Resolve fixture durable names and GUIDs through the existing Godot manifest and runtime registry.
3. Require every registered live brush to be covered or explicitly classified with a reason.
4. Classify failures as harness/conversion defects, GDScript port defects, known runtime differences, unsupported brushes, or missing source fixtures.
5. Preserve known mismatches as explicit classifications, not silently weakened comparisons.

Deliverable: complete coverage accounting and full-corpus parity results.

## Phase 6: Automation

1. Measure full-suite runtime before deciding where it runs.
2. Run all fixtures on every change if the measured cost is modest.
3. Otherwise run the five-brush pilot as the presubmit gate and the complete corpus as a separate CI job.
4. Retain concise summaries and detailed per-brush mismatch artifacts.

Deliverable: proportionate local and CI validation with reproducible diagnostics.

## Phase 7: Fixture Input Coverage Expansion

The original corpus used one planar path with identity orientations, pressure
`1`, brush scale `1`, brush size `0.1125`, and seed `0`. It was useful as a broad
regression sample but did not establish comprehensive generator coverage. In
particular, it gave `ConcaveHull` only coplanar QuillPen points, so Open Brush
correctly emitted an empty mesh.

Expand fixture inputs in two controlled stages:

1. Replace the planar universal path with a deterministic spatial profile that
   varies all three position axes, control-point orientation, pressure, segment
   length, and turn angle.
2. Require the revised `ConcaveHull` fixture to contain non-empty source
   geometry and polygon faces before treating it as generator coverage.
3. Regenerate and classify the complete baseline corpus before modifying any
   runtime implementation in response to new failures.
4. Audit which material generator branches the spatial profile actually reaches.
5. Add named, family-targeted profiles only where the audit identifies a real
   gap, such as pressure extremes, break/restart transitions, alternate random
   seeds, or size/scale boundaries. Do not multiply every brush by every profile.
6. Keep `Slice` excluded because it is hidden from the Open Brush UI.
7. Keep `PassthroughHull` excluded because its mesh generation is ordinary hull
   behavior and its distinguishing behavior is render-specific.

Deliverable: a non-degenerate spatial baseline plus a small, documented set of
targeted branch profiles with explicit coverage purposes.

## Separate GLB Track

1. Use generated GLBs only for end-to-end export/import validation.
2. Do not compare post-`BrushBaker` JSON as a substitute for live mesh parity.
3. Introduce GLB tests only after the corresponding live mesh passes or has an explicit classification.

## Planned Commit Boundaries

1. Add the schema audit and direct raw fixture reader.
2. Add the five-brush raw fixture pilot.
3. Add strict comparator and coordinate-conversion coverage.
4. Add direct full-corpus coverage accounting.
5. Add CI integration and final documentation.

Each commit should remain independently reviewable and should not mix fixture-data updates with unrelated runtime fixes.

## Current Progress

1. Phase 1 is complete. `OPEN_BRUSH_MESH_FIXTURE_AUDIT.md` records the measured
   corpus size, schema, channel layouts, catalog reconciliation, and the two
   registered Godot brushes absent from the source fixture corpus.
2. Phase 2 is implemented. The comparator reads Open Brush's raw schema directly
   and uses its exact stroke input, layout metadata, finalized live mesh, and
   polygon faces without creating a second on-disk fixture representation.
3. Phase 3 is complete for the five-brush pilot. Ink, DuctTapeGeometry, Stars,
   and Sparks pass strict comparison. MatteHull passes the regular convex-hull
   geometric-equivalence gate.
4. Phase 4 has started. The standalone adapter test passes for input
   handedness, position and semantic metric scaling, normals, tangents, indexed
   winding preservation, triangle-soup record preservation, channel alignment,
   and bounds.
5. Phase 5 has started. The comparator reads all 95 source fixtures directly.
   The measured spatial baseline passes 94 fixtures and exposes one strict
   ordinary-brush failure in `ConcaveHull`. The five regular convex-hull brushes
   pass geometric equivalence while their exact polygon-face matcher remains
   available for later work. The shared
   Unity-to-Godot surface-frame conversion fix resolved the 55 spatial
   orientation/curvature discrepancies without relaxing the comparator.
   Coverage accounting confirms that the 95 fixtures cover all but `Slice` and
   `PassthroughHull` among the 97 live registered brushes.
   `OPEN_BRUSH_MESH_FIXTURE_FULL_CORPUS_STATUS.md` records the measured coverage
   and family-level failure classification.
6. Phase 7's spatial baseline is complete. Every fixture now uses 38 control
   points with varying position on all three axes, orientation, pressure,
   segment length, and turn angle. All 95 raw meshes are non-empty.
   `ConcaveHull` now produces 1,476 vertices and 326 polygon faces. The fixture
   producer removes duplicate geometric triangles before extracting polygon
   boundaries, which prevents double-sided render triangles from creating
   empty face records. Targeted secondary profiles remain pending the branch
   coverage audit.
7. The brush-generator branch audit is complete. The spatial baseline covers
   interior pressure variation, three sub-minimum moves, turns up to 90 degrees,
   ten descriptor-clamped sizes, and the active catalog descriptor variants.
   It does not provide cross-runtime evidence for non-unit brush scale, exact
   pressure endpoints, short-stroke particle finalization, or alternate seeds.
   `OPEN_BRUSH_MESH_FIXTURE_AUDIT.md` records the evidence and ranks a small
   representative non-unit-scale profile as the highest-value next candidate.

## Planar Pilot Classification (Historical)

These results describe the earlier planar fixture and are retained as evidence
of the fixes it supported. They do not override the current spatial-baseline
classification above.

1. DuctTapeGeometry now passes vertex and index counts, exact topology, and all
   attribute comparisons. Its maximum position delta is `0.00000095` metres.
2. Ink now passes vertex and index counts, exact topology, positions, normals,
   colors, and UVs. Its maximum tangent delta is `0.00003678`, within the
   documented tangent-specific `0.00005` numerical tolerance.
3. Exact regular-hull polygon parity remains deferred as a known native-backend
   difference. `DiamondHull`, `MatteHull`, `ShinyHull`, `SmoothHull`, and
   `UnlitHull` pass geometric surface equivalence; their exact polygon-face
   matcher is retained for later work. `ConcaveHull` is not classified as a
   regular hull brush and remains on strict topology and vertex-channel
   comparison, where it currently emits 1,464 vertices/indices against Open
   Brush's 1,476. The earlier report that it returned no native hull was a
   comparator-classification error: `ConcaveHullBrush` is a separate geometry
   generator, not a `HullBrush` subtype.
4. Sparks uses the `Tube_Sparks`/`TubeBrush` generator rather than `SprayBrush`.
   It now passes vertex and index counts, exact topology, positions, normals,
   tangents, colors, UVs, and bounds. Its maximum position delta is `0.00000095`
   metres. The runtime fix uses Godot `-Z` for reflected Unity forward, preserves
   source triangle order, and emits the reflected tangent handedness.
5. Stars now passes vertex and index counts, exact topology, positions, particle
   centers, colors, UVs, particle-render records, and bounds. The fix reflects
   deterministic random sphere offsets and quaternion directions when converting
   the source brush's Unity-space random values into the Godot runtime frame.
