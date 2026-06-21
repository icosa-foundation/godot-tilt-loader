# Open Brush Mesh Parity Status

## Reference Source

- Open Brush path inspected: `C:/Users/andyb/Documents/open-brush-fast`
- Reference commit: `3d4436ab93843ffd2c56f51222c78e770f20d520`
- Reference status at time of inspection: dirty worktree with unrelated changes outside `Assets/Scripts/Brushes`.
- Brush source directory: `Assets/Scripts/Brushes`
- Godot port directory: `Scripts/Brushes`

The commit above is the current mesh-generation parity reference unless this file is deliberately updated.

## Audit Status

| Godot class | Open Brush source | Status | Notes |
| --- | --- | --- | --- |
| `BaseBrushScript.gd` | `BaseBrushScript.cs` | Not fully audited | Core lifecycle and coordinate shims need line-by-line comparison. |
| `GeometryBrush.gd` | `GeometryBrush.cs` | Partially audited, active repair started | Shared `SetVert` now uses Open Brush `Color32` truncation for RGB and alpha. Batched finalization now copies/releases geometry directly instead of re-entering subclass solitary finalizers. Lifecycle/finalization still needs full audit before child classes can be considered complete. |
| `QuadStripBrush.gd` | `QuadStripBrush.cs` | Partially audited, active repair started | Sharp-bend shrink/break behavior, double-sided backside consistency, backface color/hue-shift behavior, append-time `Color32` truncation, and single-sided batched weld finalization have been ported. Full line-by-line audit still required. |
| `QuadStripBrushStretchUV.gd` | `QuadStripBrushStretchUV.cs` | Partially audited, active repair started | UV tests cover stretch remapping, width-in-UV0.z export, backface mirroring, and texture atlas branch behavior. Needs full line-by-line audit after base `QuadStripBrush` settles. |
| `QuadStripBrushDistanceUV.gd` | `QuadStripBrushDistanceUV.cs` | Partially audited, active repair started | Backface UV/color/tangent mirroring has been ported and tested. UV tests now cover distance atlas branch behavior and `Color32` fade quantization. Needs full line-by-line audit. |
| `QuadStripUnitizedUVBrush.gd` | `QuadStripUnitizedUVBrush.cs` | Partially audited, active repair started | Backface UV/tangent mirroring has been ported and tested. Needs full line-by-line audit. |
| `FlatGeometryBrush.gd` | `FlatGeometryBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. Batched finalization now trims short post-break tails like Open Brush. Needs full branch audit. |
| `ThickGeometryBrush.gd` | `ThickGeometryBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. Texture atlas count handling now matches Open Brush directly, with distance/stretch atlas branch coverage. Needs full branch audit. |
| `TubeBrush.gd` | `TubeBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. Texture atlas count handling and UV-rate division now match Open Brush directly, with distance atlas branch coverage. Needs full branch audit. |
| `HullBrush.gd` | `HullBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Batched finalization now runs the Open Brush `SimplifyAtEnd` geometry pass and simplification tolerance path. Native hull backend and degenerate cases need explicit parity review. |
| `ConcaveHullBrush.gd` | `ConcaveHullBrush.cs` | Partially tested | Vertex color writes now use Open Brush `Color32` truncation. Known degenerate hull behavior needs explicit classification. |
| `SprayBrush.gd` | `SprayBrush.cs` | Partially audited, active repair started | Shared `GeometryBrush.SetVert` color parity is covered. Preview decay now advances with elapsed time instead of a zero delta. Random salt wraparound now matches Open Brush `kSaltMaxQuadsPerKnot`. Particle layout still needs full audit. |
| `GeniusParticlesBrush.gd` | `GeniusParticlesBrush.cs` | Partially audited, active repair started | Shared `GeometryBrush.SetVert` color parity is covered. Preview decay now advances with elapsed time instead of a zero delta. Batched finalization now explicitly runs particle finalization like Open Brush. UV0.w now stores Open Brush particle birth time, negative in preview mode. Texture atlas UVs and finalization/length-cache control flow now have focused parity coverage. Particle layout and seed behavior still need full audit. |
| `BubbleWandBrush.gd` | `BubbleWandBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. BubbleWand-specific UVW post-processing, original-position UV1 storage, and direct finalization control flow now have focused coverage. Needs full branch audit. |
| `BlocksBrushScript.gd` | `BlocksBrushScript.cs` | Partially audited, active repair started | Existing parity tests cover the no-op contract and vertex layout. Batched finalization is now explicitly no-op like Open Brush. Needs full catalog usage audit. |
| `TetraBrush.gd` | `TetraBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Texture atlas count handling now matches Open Brush directly, with distance atlas and texture-edge chop coverage. Needs full branch audit. |
| `SquareBrush.gd` | `SquareBrush.cs` | Partially tested | Vertex color writes now use Open Brush `Color32` truncation. Needs full branch audit. |
| `Square3DPrintBrush.gd` | `Square3DPrintBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover straight topology, shared-ring continuation, and parity-flip ring-face insertion. Needs full branch audit. |
| `SliceBrush.gd` | `SliceBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Initial frame direction now matches Open Brush `ComputeSurfaceFrameNew` + `Quaternion.LookRotation` semantics, with normal-direction coverage. Needs full branch audit. |
| `PrintableBrush.gd` | `PrintableBrush.cs` | Partially tested | Vertex color writes now use Open Brush `Color32` truncation. Needs full branch audit. |
| `PbrBrushScript.gd` | `PbrBrushScript.cs` | Not fully audited | Material/export interaction needs separation from mesh parity. |
| `EnvironmentBrushScript.gd` | `EnvironmentBrushScript.cs` | Not fully audited | Need confirm whether this participates in runtime mesh generation. |
| `SvgBrushScript.gd` | `SvgBrushScript.cs` | Not fully audited | Need confirm whether this participates in runtime mesh generation. |
| `MidpointPlusLifetimeSprayBrush.gd` | `MidpointPlusLifetimeSprayBrush.cs` | Partially audited, active repair started | Removed non-Open-Brush finalization rewrite and the leftover unused particle helper copied from Genius-style particle behavior; finalization now preserves generated midpoint particles. UV1.w now stores Open Brush particle birth time. Particle layout and seed behavior still need full audit. |

## Missing Godot Runtime Equivalents To Investigate

Open Brush source files present without obvious Godot class equivalents:

- `CandyCane.cs`
- `HolidayTree.cs`
- `ParentBrush.cs`
- `PlaitBrush.cs`
- `SnowflakeBrush.cs`

Current catalog/registry classification:

- `ParentBrush.cs` is a C# source helper/base class, not a manifest brush prefab.
- `CandyCane.cs`, `HolidayTree.cs`, `PlaitBrush.cs`, and `SnowflakeBrush.cs` are not referenced by the active Godot `Manifest.asset` + `Manifest_Experimental.asset` catalog as normal or compatibility durable names/prefab names.
- The active manifest contains `Snow`, but it routes through the supported `GeniusParticle` prefab/runtime path; it is not `SnowflakeBrush.cs`.

`Tests/GDScript/BrushRuntimeRegistryParityTest.gd` now keeps this classification executable while also verifying every normal manifest brush has a runtime factory and every compatibility brush is excluded from live registration.

## Current Repair Evidence

The first concrete parity repair targets `QuadStripBrush` because flat strip brushes were visibly splitting into disconnected quads.

Implemented so far:

- sharp bend double-back detection,
- intentional strip-break creation,
- `UpdateUVsForSegment` call when a break is inserted,
- shrink behavior for self-intersecting turns,
- `m_LastSizeShrink` update behavior,
- forward/right recomputation after shrink,
- backside consistency updates after smoothing/fusing front quads,
- `finalize_for_runtime()` routing for live/replayed strokes,
- single-sided quad-strip batched welding from Open Brush `WeldSingleSidedQuadStrip`,
- pending UV/tangent flushes before batched finalization for stretch and distance UV quad-strip subclasses,
- Open Brush backface color pattern and `m_BackfaceHueShift` handling in `AppendLeadingQuad`,
- Open Brush append-time `Color32` truncation for quad-strip vertex colors,
- backface UV/color/tangent mirroring for `QuadStripBrushDistanceUV`,
- backface UV/tangent mirroring for `QuadStripUnitizedUVBrush`.
- Open Brush `Color32` alpha truncation for `QuadStripBrushDistanceUV` opacity fade.
- Open Brush `GeometryBrush.SetVert` `Color32` truncation for shared flat/thick geometry brush color and alpha writes.
- Open Brush `Color32` truncation for direct vertex-color writes in hull, concave hull, tube, tetra, square, square 3D print, slice, and printable brush classes.
- Open Brush particle birth-time packing for `GeniusParticlesBrush` UV0.w and `MidpointPlusLifetimeSprayBrush` UV1.w.
- Open Brush explicit `GeniusParticlesBrush.FinalizeBatchedBrush` behavior, with `GeometryBrush` batched finalization made non-reentrant for subclasses.
- Open Brush `GeniusParticlesBrush` finalization and length-cache update control flow, removing non-reference defensive guards in the covered paths.
- Open Brush `SprayBrush.CalculateSalt` modulo behavior for dense knots.
- Removal of the unused non-Open-Brush `MidpointPlusLifetimeSprayBrush.create_particle_geometry` helper.
- Open Brush texture-atlas branch coverage for `QuadStripBrushStretchUV` and `QuadStripBrushDistanceUV`.
- Open Brush `ThickGeometryBrush` texture atlas count handling and atlas branch coverage for distance/stretch UVs.
- Open Brush `TubeBrush` texture atlas count handling and direct UV-rate division behavior, with atlas branch coverage for distance UVs.
- Open Brush `BubbleWandBrush` finalization control flow, UVW formula behavior, and UV1 original-position storage coverage.
- Open Brush `BlocksBrushScript` explicit no-op batched finalization behavior.
- Open Brush `TetraBrush` texture atlas count handling and distance atlas branch coverage, including texture edge chop.
- Open Brush `Square3DPrintBrush` parity-flip topology branch coverage for double-back strokes.
- Open Brush `SliceBrush` initial frame direction/normal orientation behavior, routed through the shared `ComputeSurfaceFrameNew` parity helper.
- Open Brush `HullBrush` `SimplifyAtEnd` batched finalization route and simplification tolerance pass.
- Open Brush `MathUtils.ComputeMinimalRotationFrame` forward-axis convention for Godot `Basis.looking_at`.

Focused tests added/updated:

- `Tests/GDScript/QuadStripParityTest.gd`
  - checks sharp-bend shrink behavior through the brush lifecycle,
  - checks intentional strip-break behavior on double-back turns,
  - checks double-sided backfaces mirror fused front quads,
  - checks batched finalization welds connected single-sided quad strips to shared-edge topology,
  - checks double-sided append-time backface color pattern and hue shifting,
  - checks double-sided DistanceUV backface UV/color/tangent channel mirroring,
  - checks double-sided UnitizedUV backface UV/tangent channel mirroring,
  - checks StretchUV and DistanceUV texture atlas branch formulas for `m_TextureAtlasV > 1`,
  - checks DistanceUV fade opacity is quantized to Unity `Color32` byte alpha,
  - checks quad-strip append-time colors, opacity, previous-edge carryover, and hue-shifted backfaces use Unity `Color32` byte truncation.
- `Tests/GDScript/FlatGeometryBrushParityTest.gd`
  - checks generated flat geometry vertex colors use Unity `Color32` byte truncation for RGB and alpha.
  - checks batched finalization trims short non-compatibility post-break tails before mesh export, matching Open Brush `FinalizeBatchedBrush`.
- `Tests/GDScript/ThickGeometryBrushParityTest.gd`
  - checks generated thick geometry vertex colors use Unity `Color32` byte truncation for RGB and alpha.
  - checks Thick distance and stretch UV texture atlas branch formulas for `m_TextureAtlasV > 1`.
- Existing focused brush tests for `HullBrush`, `ConcaveHullBrush`, `SprayBrush`, `MidpointPlusLifetimeSprayBrush`, `TubeBrush`, `SliceBrush`, `PrintableBrush`, `SquareBrush`, `Square3DPrintBrush`, and `TetraBrush`
  - now check generated vertex colors use Unity `Color32` byte truncation at their covered write points.
- `Tests/GDScript/HullBrushParityTest.gd`
  - checks convex hull helper coverage, tetrahedron conversion, double-sided hull geometry, faceted polygonal cube faces, interior tracking, and the `SimplifyAtEnd` batched finalization route.
- `Tests/GDScript/SliceBrushParityTest.gd`
  - checks shared-quad geometry, UVW distance accumulation, triangle winding, opaque `Color32` writes, and Open Brush normal direction for initial/front quads.
- `Tests/GDScript/Square3DPrintBrushParityTest.gd`
  - checks single-segment topology, shared-ring continuation topology, and flip-branch topology where Open Brush closes the previous ring face and adds an extra current-orientation ring.
- `Tests/GDScript/TetraBrushParityTest.gd`
  - checks Tetra distance and unitized UV geometry, generated topology, vertex color truncation, and distance UV texture atlas branch formulas for `m_TextureAtlasV > 1` with texture edge chop.
- `Tests/GDScript/TubeBrushParityTest.gd`
  - checks default soft tube geometry, hard-edge radius-in-UV layout, stretch UV remapping, shape modifier displacement, and distance UV texture atlas branch formulas for `m_TextureAtlasV > 1`.
- `Tests/GDScript/BubbleWandBrushParityTest.gd`
  - checks BubbleWand layout, Tube-derived generated geometry, UVW post-processing formula across cap/ring/mid/tail vertices, computed bubble radius/center, finalization smoothing, release time capture, and original geometry position storage in UV1.
- `Tests/GDScript/BlocksBrushParityTest.gd`
  - checks BlocksBrush layout flags, no-op update/spawn contract, solitary finalization, and runtime batched finalization no-op behavior.
- `Tests/GDScript/SprayBrushParityTest.gd`
  - checks Spray geometry layout, double-sided output, single-sided descriptor handling, UV/tangent generation, batched runtime finalization, Open Brush salt wraparound, and preview decay aging with elapsed time.
- `Tests/GDScript/GeniusParticlesBrushParityTest.gd`
  - checks Genius particle geometry layout, generated UV channels, texture atlas UV branch behavior for `m_TextureAtlasV > 1`, solitary and batched hanging-particle finalization, single-particle pressure behavior, preview decay aging with elapsed time, and Open Brush birth-time sign packing in UV0.w.
- `Tests/GDScript/MidpointSprayBrushParityTest.gd`
  - checks Midpoint Plus Lifetime Spray geometry layout, generated UV0/UV1 channels, tangent/color output, finalization preserving the generated particle mesh rather than applying Genius Particles hanging-particle removal, and Open Brush birth-time packing in UV1.w.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd`
  - walks the real manifest/catalog and verifies all normal `Line`, `LineWithWidth`, `UnitizedUV`, and `DistanceUV` prefabs route to the repaired quad-strip runtime classes.
  - verifies every mesh-affecting prefab field in the active manifest/catalog is applied to the created runtime brush instance, including quad-strip width storage, flat/thick/tube UV style, flat offset flags, hull parameters, concave hull parameters, and tube shape parameters.
- `Tests/GDScript/UtilityParityTest.gd`
  - checks shared utility behavior including `MathUtils.ComputeMinimalRotationFrame` forward-axis parity.
- `Tests/GDScript/CafeStrokeFixturesReplayTest.gd`
  - replays checked-in cafe stroke fixtures through `OpenBrushStrokeBridge` and `BrushStrokeReplay` without loading the full cafe `.tilt`,
  - verifies the cafe legacy Ink GUID resolves to the runtime `Ink` descriptor and `QuadStripBrushStretchUV`,
  - verifies `Resources/Fixtures/cafe_ink_stroke_150.json` produces 600 vertices, 600 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_duct_tape_geometry_stroke_496.json` resolves to `DuctTapeGeometry` / `FlatGeometryBrush` and produces 104 vertices, 300 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_stars_stroke_130.json` resolves to `Stars` / `GeniusParticlesBrush` and produces 4 vertices, 6 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_sparks_stroke_463.json` resolves to `Sparks` / `TubeBrush` and produces 34 vertices, 96 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_matte_hull_stroke_11.json` resolves to `MatteHull` / `HullBrush` and produces 36 vertices, 36 indices, full UV0/color channels, and stable cafe-space bounds.
- `Tests/GDScript/CafeStrokeFixtureExtractProbe.gd`
  - extracts a source fixture from `res://Temp/TiltEvidence/brush_cafe_experimental.tilt`,
  - defaults to stroke index 150 and accepts `--source-stroke-index=...`,
  - this is a fixture-generation probe, not part of the normal fast parity suite.
- `Tests/GDScript/CafeFixtureCandidateProbe.gd`
  - lists first runtime-supported cafe stroke candidates by descriptor prefab and runtime class so new fixture choices are reproducible.
- `Tests/GDScript/TiltImporterRuntimeReplayTest.gd`
  - verifies the `.tilt` importer and runtime scene builder do not contain the old fallback tessellator entry points,
  - loads the cafe `.tilt` through runtime replay and checks it creates substantial geometry/material coverage without unresolved normal-brush errors.

Focused validation command run:

```powershell
$godot = "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
@(
  "QuadStripParityTest.gd",
  "BrushRuntimeRegistryMetadataTest.gd",
  "LiveVsTiltUvParityTest.gd",
  "TiltBridgeReplayParityTest.gd",
  "SingleBrushStrokeInspectorTest.gd",
  "CafeStrokeFixturesReplayTest.gd"
) | ForEach-Object {
  & $godot --headless --xr-mode off --path . --script "res://Tests/GDScript/$($_)"
  if ($LASTEXITCODE -ne 0) { throw "Test failed: $($_)" }
}
```

Result: command exited successfully.

Heavier cafe importer validation also run:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: command exited successfully.

Known validation noise:

- Godot reported an existing resource-leak warning after a scene-style test.
- Catalog loading still reports existing missing GUID and duplicate GUID warnings.
- Cafe importer validation reports legacy GUID remaps, compatibility-brush skips, and several material UID warnings; these do not currently fail the runtime replay test.
- The cafe Stars fixture reports a material UID warning for `Stars.tres`; this does not currently fail fixture replay.

## Next Required Work

1. Continue `QuadStripBrush` and quad-strip subclass audit:
   - compare stretch/distance/unitized UV methods line-by-line for any remaining non-backface differences,
   - confirm all normal flat strip brushes route through the repaired runtime path.
2. Extract additional lightweight real-stroke fixtures for any brush the inspector identifies as suspect.
3. Generate or import authoritative Open Brush reference mesh fixtures; the current cafe fixture verifies Godot runtime stability for a real stroke but does not yet compare against Open Brush vertex-by-vertex output.
4. Convert current helper tests into generated-mesh parity tests where possible.
5. Audit all remaining brush classes line-by-line against the reference source.
6. Remove or quarantine any remaining production fallback geometry paths for normal brushes.
