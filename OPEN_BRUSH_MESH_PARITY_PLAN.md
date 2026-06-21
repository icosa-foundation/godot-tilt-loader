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

## Current Highest-Priority Gap

The largest remaining visual gap from quick scene inspection is the `GeniusParticle`
brush family:

- `Embers`
- `Smoke`
- `Snow`
- `Stars`
- `Bubbles`
- `Dots`
- `Rising Bubbles`

These brushes are more fragile than ordinary tube and flat-strip brushes because
the generated mesh is only part of the contract. The shader also depends on
Open Brush particle attributes being delivered through the same render-facing
Godot arrays as imported Tilt/GLTF strokes:

- texture UV in `Mesh.ARRAY_TEX_UV`,
- birth time in `Mesh.ARRAY_TEX_UV2.x`,
- generated/runtime particle rotation in `Mesh.ARRAY_TEX_UV2.y`,
- vertex id in `Mesh.ARRAY_CUSTOM0.x`,
- particle center in `Mesh.ARRAY_CUSTOM0.yzw`,
- no ordinary normal stream for particle centers.

Godot `ArrayMesh` normalizes tangent vectors at the renderable surface
boundary, so raw particle rotation cannot be preserved in `TANGENT.z` for live
generated meshes. Runtime material duplicates for Genius particle shaders must
read generated rotation from `UV2.y`. The original tangent-compatible value can
still be emitted for importer comparison, but it is not the generated runtime
source of truth.

The immediate priority for particle brushes is to compare the GDScript port
against the Godot .NET C# source, then confirm generated strokes and imported
Tilt/GLTF strokes reach the particle shaders with the same mesh arrays and
materials. Do not spend time broadening unrelated tests until this visual gap is
understood.

Current particle-specific findings:

- live pointer creation now follows the Godot C# lifecycle: creating a brush
  initializes the line but does not record a synthetic first control point;
  only control points actually sent through `UpdatePosition_LS` are recorded
  and replayed,
- generated 2D/inspector sample strokes now preserve Open Brush stroke
  semantics by storing path scale in `Stroke.m_BrushScale` rather than
  control-point pressure,
- generated `GeniusParticle` mesh data now exports the same shader-facing Godot
  arrays used by imported Tilt/GLTF particle strokes,
- generated/runtime particle rotation is preserved through `UV2.y` after
  `ArrayMesh` creation because Godot normalizes tangent vectors,
- live, `.tilt` runtime rebuild, and bridge-created strokes now resolve
  Genius particle materials through the shared `BrushMaterialResolver` path, so
  the runtime shader channel rewrite is not bypassed,
- the seven normal `GeniusParticle` materials are now classified explicitly:
  six billboard-style particle shaders use `CUSTOM0` plus `UV2.y`, while
  `Rising Bubbles` is the simple UV/COLOR shader outlier and does not require
  the particle rotation/center contract,
- generated live meshes now apply catalog `m_BoundsPadding` as
  `ArrayMesh.custom_aabb` so shader-displaced particle brushes are not culled
  against their undisplaced source quads,
- this padding is a Godot rendering integration requirement, not a vertex
  geometry change.
- focused path-equivalence validation now reports zero vertex, primary UV,
  `UV2`, and `CUSTOM0` deltas for representative `Stars` and `Embers`
  strokes across direct replay, memory replay, pointer math, and live object
  drawing. This proves the current Godot paths agree with each other; it still
  does not replace Open Brush C# reference mesh fixture comparison.

## Working Rules

1. Open Brush source is the authority.
2. The Godot .NET C# port is the immediate conversion oracle for this repo's GDScript port.
3. The translated GDScript must be directly comparable to the Godot C# implementation wherever practical.
4. Do not replace missing behavior with new approximations.
5. Do not hide missing behavior behind fallback geometry.
6. Runtime generation, `.tilt` loading, 2D drawing, and XR drawing must call the same brush runtime code for normal brushes.
7. Unknown normal brushes should fail loudly. They should not silently render with substitute geometry.
8. Compatibility brushes must be classified explicitly and kept out of the normal live/runtime brush list unless intentionally reimplemented.
9. Tests are confirmation and regression protection. They must not become a substitute for fixing obvious C# to GDScript translation drift.

## Immediate Execution Strategy

The fastest route to working brushes is not broad manual test expansion. The
priority is to compare the GDScript port against the working Godot .NET C#
port and fix clear translation discrepancies.

Use this loop:

1. Identify the current visibly broken or suspect brush by durable name, prefab
   family, and runtime class.
2. Open the Godot .NET C# brush implementation and the GDScript translation
   side by side.
3. Look first for large conversion drift:
   - missing blocks,
   - different conditionals,
   - different vector/axis conventions,
   - wrong UV channel writes,
   - missing state reset or finalization logic,
   - different random/seed/salt handling,
   - alternate fallback geometry paths,
   - integration paths that bypass the translated runtime.
4. Fix clear GDScript translation mismatches directly.
5. Use upstream Open Brush C# only when the Godot C# behavior itself needs
   explanation.
6. Confirm the fix with the smallest useful check:
   - visual inspector if the bug is visual,
   - a focused regression test if the mismatch is easy to encode,
   - C# vs GDScript mesh fixture comparison when numeric proof is needed.
7. Only expand broad fixture coverage after the currently broken brushes are
   working.

Current evidence should be kept separate from stale observations. Do not keep
targeting a brush family because it was broken earlier if visual checks or
later fixes show it is now healthy.

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

1. Open the Godot .NET C# port and GDScript side by side.
2. Compare fields and defaults.
3. Compare constructor/init behavior.
4. Compare control point lifecycle methods.
5. Compare geometry append/fuse methods.
6. Compare UV generation methods.
7. Compare color/normal/tangent generation.
8. Compare finalization behavior.
9. Compare random seed usage.
10. Check that import/live/example paths call the same translated runtime.
11. Use upstream Open Brush C# to resolve questions about intended behavior.
12. Record every intentional and unintentional difference.

For currently broken brushes, prioritize obvious translation drift over
comprehensive branch proof. No method should be marked complete because it
looks structurally similar. It is complete only when all meaningful behavior
paths are accounted for or proven equivalent by direct C# vs GDScript output.

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

1. Create or use a local worktree for this repo's `feature/godot` branch so the
   Godot .NET C# implementation is available as the immediate conversion
   source. Do not modify unrelated Open Brush checkouts.
2. Build a current suspect list from visual evidence, not stale assumptions.
   Record exact brush durable name, prefab family, runtime class, and what is
   visually wrong.
3. For the top suspect brush, compare Godot C# vs GDScript side by side and fix
   obvious translation drift first.
4. Verify the fix with the visual inspector or the smallest focused regression
   test that proves the changed behavior.
5. Repeat for the next suspect brush.
6. In parallel only where useful, wire compact C# mesh fixture export from the
   Godot C# port so C# vs GDScript numeric comparison can confirm fixes without
   relying on manual expectations.
7. Use upstream Open Brush C# as the authority when the Godot C# branch and
   GDScript disagree in a way that is not obviously a translation mistake.
8. Keep runtime replay, `.tilt` import, 2D drawing, and XR drawing on the same
   translated runtime path; remove fallback geometry from normal brush paths.
9. Once the known broken brushes are working, broaden C#-vs-GDScript reference
   fixture coverage across representative brush families.
10. Remove temporary instrumentation and dead fallback code.

## Non-Goals

- Rewriting brushes into more idiomatic GDScript.
- Designing new Godot-specific brush behavior.
- Optimizing before parity is proven.
- Treating visual similarity as sufficient proof.
- Supporting compatibility brushes as live brushes unless they are intentionally reimplemented.
