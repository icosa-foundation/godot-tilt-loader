# Open Brush Mesh Generation Parity Plan

## Goal

`open-brush-stroke-gen-only` must behave as a direct port of Open Brush mesh generation. The Godot runtime should generate the same stroke mesh data as Open Brush for the same brush descriptor, stroke seed, color, size, pressure, control point transforms, and brush scale.

This is not a visual approximation target. It is a behavioral parity target.

The expected lineage is:

1. Open Brush C# brush classes are extracted without behavior changes.
2. Unity API dependencies are isolated behind shim types.
3. C# is translated to GDScript without changing brush behavior.
4. Godot integration code calls the translated runtime without adding alternate geometry paths.

Any difference from Open Brush must be documented as one of:

- a known Godot rendering/material limitation outside mesh generation,
- a compatibility-brush policy decision,
- or a bug.

## Current Failure

Flat strip brushes show visible breaks between adjacent quads in the Godot inspector/live drawing path. That indicates the generated strip topology is not matching Open Brush.

The clearest known divergence is `QuadStripBrush`:

- Open Brush `QuadStripBrush.UpdatePositionImpl` contains bend handling that detects double-backs, shrinks quad edges, and deliberately starts a new strip segment when needed.
- The Godot `QuadStripBrush.gd` currently computes the next quad and appends it without the same sharp-bend/shrink/strip-break block.
- Open Brush updates backside quads after fusing geometry for double-sided strips.
- The Godot port defines backside consistency helpers but does not call them in all the same places.
- Open Brush has batched finalization behavior for single-sided quad strips, including welding connected strips into shared vertices.
- The Godot runtime currently finalizes generated strokes through the solitary brush path.

This means the port preserved the broad class shape but not every behavior path.

## Working Rules

1. Open Brush source is the authority.
2. The translated GDScript must be line-by-line comparable to the extracted C# wherever practical.
3. Do not replace missing behavior with new approximations.
4. Do not hide missing behavior behind fallback geometry.
5. Runtime generation, `.tilt` loading, 2D drawing, and XR drawing must call the same brush runtime code for normal brushes.
6. Unknown normal brushes should fail loudly. They should not silently render with substitute geometry.
7. Compatibility brushes must be classified explicitly and kept out of the normal live/runtime brush list unless intentionally reimplemented.

## Phase 1: Establish the Parity Baseline

### 1.1 Identify the Open Brush Source Snapshot

Record the exact Open Brush source used as the parity reference:

- repository path,
- commit hash,
- relevant brush source file list,
- generated fixture date.

Add this to a small checked-in document or test fixture metadata file so future parity failures can be traced to a specific source version.

### 1.2 Build a Brush Class Inventory

Create a table covering every runtime brush class in this repo:

- GDScript file,
- original Open Brush C# file,
- brush prefab families using it,
- geometry type,
- UV mode,
- finalization requirements,
- current test coverage,
- current parity status.

Initial high-priority files:

- `BaseBrushScript`
- `GeometryBrush`
- `QuadStripBrush`
- `QuadStripBrushStretchUV`
- `QuadStripBrushDistanceUV`
- `QuadStripUnitizedUVBrush`
- `FlatGeometryBrush`
- `ThickGeometryBrush`
- `TubeBrush`
- `HullBrush`
- `ConcaveHullBrush`
- `SprayBrush`
- `GeniusParticlesBrush`
- `BubbleWandBrush`
- `BlocksBrushScript`
- `TetraBrush`
- `SquareBrush`
- `Square3DPrintBrush`
- `SliceBrush`
- `PrintableBrush`
- `PbrBrushScript`
- `EnvironmentBrushScript`
- `SvgBrushScript`

### 1.3 Classify Existing Tests

Mark each parity test as one of:

- lifecycle parity,
- helper-method parity,
- generated mesh parity,
- visual smoke test,
- importer path test,
- material/metadata test.

The current problem escaped because helper tests existed but full generated-strip tests did not.

## Phase 2: Remove Non-Open-Brush Geometry Paths

### 2.1 Runtime Path Rule

For every normal brush, all stroke sources must converge on:

1. resolve `BrushDescriptor`,
2. instantiate via `BrushRuntimeRegistry`,
3. replay control points through the brush lifecycle,
4. finalize through the matching Open Brush semantics,
5. export through `MeshData`.

This applies to:

- `.tilt` import,
- cafe evidence viewer runtime rebuild,
- 2D drawing example,
- XR drawing example,
- generated inspector strokes,
- tests.

### 2.2 Delete or Quarantine Fallback Tessellation

Production `.tilt` loading must not contain alternate tessellators for normal brushes.

If fallback code is retained temporarily, it must be moved to a diagnostic-only location and must not be called by normal import or drawing paths.

Expected production behavior:

- normal brush missing runtime implementation: error,
- normal brush returns no mesh: error,
- unknown GUID: error or explicit unsupported import result,
- compatibility brush: explicit compatibility path or explicit skip.

### 2.3 Centralize Material Assignment

Mesh parity must be tested separately from material parity, but material lookup still needs one source of truth.

Both loaded and live strokes should resolve materials through the same resolver API using the same descriptor fields.

## Phase 3: Direct Code Audit Against Open Brush

### 3.1 Audit Methodology

For each brush class:

1. Open the original C# and GDScript side by side.
2. Compare fields and defaults.
3. Compare constructor/init behavior.
4. Compare control point lifecycle methods.
5. Compare geometry append/fuse methods.
6. Compare UV generation methods.
7. Compare color/normal/tangent generation.
8. Compare finalization behavior.
9. Compare random seed usage.
10. Record every intentional and unintentional difference.

No method should be marked complete because it looks structurally similar. It is complete only when all branches are accounted for.

### 3.2 Immediate `QuadStripBrush` Repair

Port the missing Open Brush behavior exactly:

- sharp bend detection,
- double-back detection,
- strip break handling,
- `UpdateUVsForSegment` call when a strip break is inserted,
- `m_InitialQuadIndex` updates,
- size shrink handling,
- `m_LastSizeShrink` behavior,
- forward/right recomputation after shrink,
- backside consistency updates after fusing.

Then add tests that would have failed before the repair.

### 3.3 Finalization Parity

Audit Open Brush finalization paths:

- solitary brush finalization,
- batched brush finalization,
- single-sided quad strip welding,
- backface handling,
- index ordering,
- vertex channel preservation.

Decide whether Godot should:

- implement both solitary and batched finalization paths, or
- always use one Open Brush-equivalent path and prove the mesh output remains identical for the cases used.

Do not assume duplicated coincident vertices are equivalent if Open Brush welds them. Compare resulting vertex/index/channel data and rendered output.

### 3.4 UV Parity

For every brush family, verify the primary diffuse texture UV channel first.

Then verify secondary channels:

- packed radius,
- packed normal/tangent data,
- color data,
- offset flags,
- custom channels used by Godot shaders.

The source of truth for UV style must be brush catalog metadata, not hand-coded importer assumptions.

## Phase 4: Build Real Parity Fixtures

### 4.1 Generate Open Brush Reference Mesh Fixtures

Create small reference fixtures from Open Brush or the extracted C# runtime for representative strokes.

Each fixture should contain:

- brush GUID,
- brush durable name,
- prefab name,
- color,
- size,
- seed,
- brush scale,
- control point transforms,
- expected vertices,
- expected triangle indices,
- expected normals,
- expected colors,
- expected UV channels.

Fixtures should be small enough for fast tests and large enough to exercise real brush behavior.

### 4.2 Required Stroke Shapes

For each relevant brush family, include:

- straight stroke,
- curved stroke,
- sharp bend,
- pressure/size change,
- short stroke,
- multi-control-point stroke,
- stroke with non-identity rotation,
- stroke with scale changes if supported.

For flat strip brushes, include at least:

- wide curve,
- S curve,
- near-180-degree turn,
- double-sided strip,
- single-sided strip requiring finalization weld.

### 4.3 Extract Representative Real Strokes Once

Extract a small number of real strokes from the cafe `.tilt` file into lightweight fixtures.

Do not load the full cafe scene in every parity test.

Suggested fixtures:

- one `Ink` stroke,
- one flat strip stroke,
- one tube stroke,
- one particle stroke,
- one hull stroke,
- one brush currently suspected broken in the inspector.

These fixtures should be stored as stable test data and referenced by tests.

## Phase 5: Test Strategy

### 5.1 Numeric Mesh Tests

Add tests that compare generated Godot mesh data against reference fixtures.

Compare:

- vertex count,
- triangle count,
- positions,
- normals,
- colors,
- UV0,
- UV1,
- UV2,
- custom channel source data before Godot array conversion,
- index order where relevant.

Use tolerances only for floating-point translation differences. Do not use broad tolerances to hide structural differences.

### 5.2 Lifecycle Tests

Drive brushes through the same lifecycle used by live drawing and `.tilt` loading:

1. create brush,
2. initialize with descriptor,
3. begin stroke,
4. feed control points,
5. apply changes,
6. finalize,
7. export mesh.

Avoid tests that only seed internal arrays unless the test is specifically for a helper method.

### 5.3 Path Equivalence Tests

For the same fixture stroke, verify equivalent mesh output from:

- direct runtime replay,
- `.tilt` import path,
- 2D drawing generated path,
- XR/live drawing path where practical.

The purpose is to catch path drift, not just brush math bugs.

### 5.4 Visual Diagnostic Scenes

Keep visual scenes for human inspection, but do not treat them as the main parity proof.

Useful scenes:

- cafe `.tilt` runtime rebuild viewer,
- single-brush inspector with arrow-key brush stepping,
- 2D drawing scene with generated reference stroke,
- XR drawing scene.

Each visual scene should have an obvious non-black background, camera clipping suitable for close inspection, and on-screen brush name where relevant.

## Phase 6: Brush Metadata Source of Truth

### 6.1 Catalog-Driven Runtime

Brush behavior metadata should come from the brush catalog/manifest:

- geometry mode,
- UV mode,
- compatibility classification,
- texture offset flags,
- material lookup names,
- brush prefab mapping.

Remove duplicated hard-coded assumptions from importers and drawing examples.

### 6.2 Compatibility Brushes

Compatibility brushes are not normal live-painting brushes.

Maintain a single explicit compatibility classification:

- not registered for live painting by default,
- not silently routed through normal runtime generation,
- imported only through a documented compatibility policy.

## Phase 7: Instrumentation

### 7.1 File-Based Logs

Godot debug instrumentation must write to readable files:

- `user://debug.log`,
- `user://xr_debug.log`,
- or a test-specific log under the Godot user data directory.

Do not rely on Godot console output for debugging.

### 7.2 Unique Prefixes

Use unique prefixes for temporary instrumentation, for example:

- `OB_PARITY_QUADSTRIP`
- `OB_PARITY_REPLAY`
- `OB_PARITY_IMPORT`
- `OB_PARITY_FINALIZE`

Each log line should include enough context to identify:

- brush GUID,
- brush name,
- stroke index,
- control point index,
- vertex/triangle counts,
- UV mode,
- finalization mode.

### 7.3 Remove Temporary Logs

Temporary logs should be removed once tests prove the behavior. Permanent diagnostics should be concise and only report real failures or explicit unsupported cases.

## Phase 8: Acceptance Criteria

Mesh generation parity is acceptable when:

1. Every normal brush class has been audited against its Open Brush source.
2. Every missing branch or intentional difference is documented.
3. Flat strip brushes no longer show unintended breaks between adjacent quads.
4. Runtime replay and `.tilt` import generate the same mesh data for the same stroke fixture.
5. 2D drawing and XR drawing use the same brush runtime path as `.tilt` loading.
6. Production import does not use fallback tessellation for normal brushes.
7. Compatibility brushes are explicitly excluded or handled by a documented compatibility path.
8. The cafe viewer defaults to runtime rebuild and does not mask runtime bugs with cached imported scene data.
9. Focused parity tests pass for all brush families.
10. Visual smoke scenes remain available for human inspection.

## Recommended Execution Order

1. Add source snapshot metadata and brush class inventory.
2. Port the missing `QuadStripBrush` bend/shrink/strip-break logic.
3. Add failing-then-passing generated mesh tests for wide curved flat strips.
4. Port missing backside consistency calls.
5. Audit and repair finalization semantics, especially quad strip welding.
6. Extract lightweight cafe stroke fixtures.
7. Replace remaining importer fallback geometry paths with runtime replay or explicit failure.
8. Add path equivalence tests across runtime replay, `.tilt` import, 2D drawing, and XR drawing.
9. Audit remaining brush classes line-by-line.
10. Remove temporary instrumentation and dead fallback code.

## Non-Goals

- Rewriting brushes into more idiomatic GDScript.
- Designing new Godot-specific brush behavior.
- Optimizing before parity is proven.
- Treating visual similarity as sufficient proof.
- Supporting compatibility brushes as live brushes unless they are intentionally reimplemented.

