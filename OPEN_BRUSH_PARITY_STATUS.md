# Open Brush Mesh Parity Status

## Reference Source

- Open Brush path inspected: `C:/Users/andyb/Documents/open-brush-fast`
- Reference commit: `3d4436ab93843ffd2c56f51222c78e770f20d520`
- Reference status at time of inspection: dirty worktree with unrelated changes outside `Assets/Scripts/Brushes`.
- Brush source directory: `Assets/Scripts/Brushes`
- Godot port directory: `Scripts/Brushes`
- Current test classification inventory: `OPEN_BRUSH_PARITY_TEST_INVENTORY.md`
- Brush class inventory: `OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md`
- Open Brush reference mesh fixture contract: `Resources/Fixtures/OpenBrushReferenceMeshes/README.md`
- Open Brush reference mesh exporter source: `Tools/OpenBrushReferenceMeshExport/OpenBrushReferenceMeshExportTest.cs`

The commit above is the current mesh-generation parity reference unless this file is deliberately updated.

## Audit Status

| Godot class | Open Brush source | Status | Notes |
| --- | --- | --- | --- |
| `BaseBrushScript.gd` | `BaseBrushScript.cs` | Partially audited, active repair started | Lifecycle helper coverage now includes scale conversions, random seed setter, exact surface-frame output, pressured size/opacity, backface init, and `m_LastSpawnXf` update gating. Core lifecycle and coordinate shims still need full line-by-line comparison. |
| `GeometryBrush.gd` | `GeometryBrush.cs` | Partially audited, active repair started | Shared `SetVert` now uses Open Brush `Color32` truncation for RGB and alpha. Initial knot smoothed pressure now matches Open Brush struct defaults. Batched finalization now copies/releases geometry directly instead of re-entering subclass solitary finalizers. Lifecycle/finalization still needs full audit before child classes can be considered complete. |
| `QuadStripBrush.gd` | `QuadStripBrush.cs` | Partially audited, active repair started | Spawn interval, pressure smoothing, out-of-verts threshold, small-move no-update behavior, short preview move state restoration, strip-break disabled behavior, sharp-bend shrink/break behavior, double-sided backside consistency, backface color/hue-shift behavior, append-time `Color32` truncation, previous lone-segment squash cleanup, debug used counts, `GetNumUsedVerts` edge cases, preview reset layout/index behavior, destroy-time geometry-pool release, single-sided batched weld finalization including UV0.z, and double-sided batched non-weld export have focused coverage. Full line-by-line audit and Open Brush reference fixture comparison still required. |
| `QuadStripBrushStretchUV.gd` | `QuadStripBrushStretchUV.cs` | Partially audited, active repair started | UV method formulas now have line-by-line source comparison coverage for stretch remapping, width-in-UV0.z export, backface mirroring, texture atlas branch behavior, and pending-request union/flush behavior. Godot runtime finalization flushes pending requests before export because this integration does not always pass through Unity's visual mesh update step. Base `QuadStripBrush` still needs full audit. |
| `QuadStripBrushDistanceUV.gd` | `QuadStripBrushDistanceUV.cs` | Partially audited, active repair started | UV method formulas now have line-by-line source comparison coverage for distance atlas behavior, opacity fade quantization, backface UV/color/tangent mirroring, tangent-request union/flush behavior, preview reset clearing, and the no-op per-quad hook. Godot runtime finalization flushes pending tangents before export for the same integration reason as stretch UV. Base `QuadStripBrush` still needs full audit. |
| `QuadStripUnitizedUVBrush.gd` | `QuadStripUnitizedUVBrush.cs` | Partially audited, active repair started | Unitized UV method layout, tangent generation range, backface UV/tangent mirroring, and no-op per-quad/per-segment hooks now have line-by-line source comparison coverage. Base `QuadStripBrush` still needs full audit. |
| `FlatGeometryBrush.gd` | `FlatGeometryBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. Distance/stretch UV texture-atlas branches now use the descriptor atlas count directly like Open Brush, with focused atlas coverage. UV1 offset vectors for offset-in-texcoord1 brushes, non-M11 smoothing/shared-vertex output, continuation tangents, double-back break behavior, self-intersection size clipping, growth limiting, and M11 break-angle behavior now have focused coverage. Batched finalization trims short post-break tails like Open Brush. Needs full line-by-line audit and reference mesh fixture comparison. |
| `ThickGeometryBrush.gd` | `ThickGeometryBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. Texture atlas count handling now matches Open Brush directly, with distance/stretch atlas branch coverage. Needs full branch audit. |
| `TubeBrush.gd` | `TubeBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. Texture atlas count handling, UV-rate division, and minimal-frame routing now match Open Brush directly, with distance atlas branch coverage. Needs full branch audit. |
| `HullBrush.gd` | `HullBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Batched finalization now runs the Open Brush `SimplifyAtEnd` geometry pass and simplification tolerance path. Native hull backend and degenerate cases need explicit parity review. |
| `ConcaveHullBrush.gd` | `ConcaveHullBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Source-formula knot conversions and smooth hull geometry now have focused parity coverage. Known degenerate hull behavior needs explicit classification. |
| `SprayBrush.gd` | `SprayBrush.cs` | Partially audited, active repair started | Shared `GeometryBrush.SetVert` color parity is covered. Preview decay now advances with elapsed time instead of a zero delta. Random salt wraparound now matches Open Brush `kSaltMaxQuadsPerKnot`. Particle layout still needs full audit. |
| `GeniusParticlesBrush.gd` | `GeniusParticlesBrush.cs` | Partially audited, active repair started | Shared `GeometryBrush.SetVert` color parity is covered. Preview decay now advances with elapsed time instead of a zero delta. Batched finalization now explicitly runs particle finalization like Open Brush. UV0.w now stores Open Brush particle birth time, negative in preview mode. Texture atlas UVs, randomized alpha/offset/roll branches, and finalization/length-cache control flow now have focused parity coverage. Particle layout and seed behavior still need full audit. |
| `BubbleWandBrush.gd` | `BubbleWandBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. BubbleWand-specific UVW post-processing, original-position UV1 storage, and direct finalization control flow now have focused coverage. Needs full branch audit. |
| `BlocksBrushScript.gd` | `BlocksBrushScript.cs` | Partially audited, active repair started | Existing parity tests cover the no-op contract and vertex layout. Batched finalization is now explicitly no-op like Open Brush. Needs full catalog usage audit. |
| `TetraBrush.gd` | `TetraBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Texture atlas count handling now matches Open Brush directly, with distance atlas and texture-edge chop coverage. Needs full branch audit. |
| `SquareBrush.gd` | `SquareBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover straight topology, shared-ring continuation, and sharp-turn segment break behavior. Needs full branch audit. |
| `Square3DPrintBrush.gd` | `Square3DPrintBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover straight topology, shared-ring continuation, and parity-flip ring-face insertion. Needs full branch audit. |
| `SliceBrush.gd` | `SliceBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Initial frame direction now matches Open Brush `ComputeSurfaceFrameNew` + `Quaternion.LookRotation` semantics, with normal-direction coverage. Needs full branch audit. |
| `PrintableBrush.gd` | `PrintableBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover straight topology, envelope behavior, shared-ring continuation, and sharp-turn segment break behavior. Needs full branch audit. |
| `PbrBrushScript.gd` | `PbrBrushScript.cs` | Audited as non-mesh layout provider | Matches Open Brush fake-brush role: layout only, update returns true, zero used verts, zero spawn interval, and explicit no-op solitary/batched finalization. |
| `EnvironmentBrushScript.gd` | `EnvironmentBrushScript.cs` | Audited as non-mesh layout provider | Matches Open Brush fake-brush role: layout only, optional UV1 layout, update returns true, zero used verts, zero spawn interval, and explicit no-op solitary/batched finalization. |
| `SvgBrushScript.gd` | `SvgBrushScript.cs` | Audited as non-mesh layout provider | Matches Open Brush fake-brush role: layout only, update returns true, zero used verts, zero spawn interval, and explicit no-op solitary/batched finalization. |
| `MidpointPlusLifetimeSprayBrush.gd` | `MidpointPlusLifetimeSprayBrush.cs` | Partially audited, active repair started | Removed non-Open-Brush finalization rewrite and the leftover unused particle helper copied from Genius-style particle behavior; finalization now preserves generated midpoint particles. UV1.w now stores Open Brush particle birth time. Particle layout and seed behavior still need full audit. |

## Unsupported Godot Runtime Equivalents To Implement

Open Brush experimental ParentBrush composites present in `Manifest_Experimental`
without Godot runtime equivalents:

- `CandyCane.cs`
- `HolidayTree.cs`
- `PlaitBrush.cs`
- `SnowflakeBrush.cs`

Current catalog/registry classification:

- `ParentBrush.cs` is the abstract C# helper/base class for these composite brushes.
- `CandyCane`, `HolidayTree`, `Braid3`, and `Snowflake` are present in the Open Brush experimental manifest and tagged `experimental` + `broken`.
- `Resources/BrushCatalog/brush_catalog.json` records them under `unsupported_brushes` with their asset GUID, durable GUID, prefab name, source class, and unsupported reason.
- `UnityAssetLoader` skips them explicitly while loading catalog manifests instead of reporting them as missing descriptors.
- The active manifest also contains the normal brush `Snow`, which routes through the supported `GeniusParticle` prefab/runtime path; it is not `SnowflakeBrush.cs`.

`Tests/GDScript/BrushRuntimeRegistryParityTest.gd` now keeps this classification executable while also verifying every loaded normal manifest brush has a runtime factory and every compatibility brush is excluded from live registration.

## Current Repair Evidence

The first concrete parity repair targets `QuadStripBrush` because flat strip brushes were visibly splitting into disconnected quads.

Implemented so far:

- Open Brush quad-strip spawn interval, pressure smoothing, out-of-verts threshold, and sub-threshold movement no-update behavior,
- Open Brush quad-strip short preview movement state restoration and strip-break disabled update-position branch behavior,
- sharp bend double-back detection,
- intentional strip-break creation,
- `UpdateUVsForSegment` call when a break is inserted,
- shrink behavior for self-intersecting turns,
- `m_LastSizeShrink` update behavior,
- forward/right recomputation after shrink,
- Open Brush `GetNumUsedVerts` edge-case behavior for unattached leading edges, previous lone segments, one-solid leading segments, and double-sided equivalents,
- Open Brush `ResetBrushForPreview` layout/index reset behavior for quad-strip subclasses,
- Open Brush `QuadStripBrush.OnDestroy` geometry-pool release behavior for brushes destroyed before finalization,
- Open Brush `DebugGetGeometry` used-count behavior for quad strips,
- backside consistency updates after smoothing/fusing front quads,
- `finalize_for_runtime()` routing for live/replayed strokes,
- single-sided quad-strip batched welding from Open Brush `WeldSingleSidedQuadStrip`,
- single-sided batched welding coverage now verifies 3-component UV0 width data is preserved,
- double-sided quad-strip batched finalization coverage now verifies direct non-welded export with mirrored backside channels,
- pending UV/tangent flushes before batched finalization for stretch and distance UV quad-strip subclasses,
- Open Brush backface color pattern and `m_BackfaceHueShift` handling in `AppendLeadingQuad`,
- Open Brush append-time `Color32` truncation for quad-strip vertex colors,
- Open Brush `AppendLeadingQuad` previous lone-segment squash cleanup for single-sided and double-sided strips,
- backface UV/color/tangent mirroring for `QuadStripBrushDistanceUV`,
- backface UV/tangent mirroring for `QuadStripUnitizedUVBrush`.
- Open Brush `Color32` alpha truncation for `QuadStripBrushDistanceUV` opacity fade.
- Open Brush `GeometryBrush.SetVert` `Color32` truncation for shared flat/thick geometry brush color and alpha writes.
- Open Brush `Color32` truncation for direct vertex-color writes in hull, concave hull, tube, tetra, square, square 3D print, slice, and printable brush classes.
- Open Brush particle birth-time packing for `GeniusParticlesBrush` UV0.w and `MidpointPlusLifetimeSprayBrush` UV1.w.
- Open Brush explicit `GeniusParticlesBrush.FinalizeBatchedBrush` behavior, with `GeometryBrush` batched finalization made non-reentrant for subclasses.
- Open Brush `GeniusParticlesBrush` finalization and length-cache update control flow, removing non-reference defensive guards in the covered paths.
- Open Brush `GeniusParticlesBrush` randomized alpha, size variance, positional scatter, and roll packing formulas now have focused coverage.
- Open Brush `SprayBrush.CalculateSalt` modulo behavior for dense knots.
- Catalog replay coverage now verifies all normal `Spray` and `MiddpointPlusLifetimeGeomSpray` brushes generate complete particle mesh channels through the shared runtime replay path.
- Removal of the unused non-Open-Brush `MidpointPlusLifetimeSprayBrush.create_particle_geometry` helper.
- Removal of unused `GeometryPool.append_mesh_data` fallback color/texcoord fill parameters; mesh appends now require complete source channel data instead of carrying dormant substitute-channel behavior.
- Open Brush texture-atlas branch coverage for `QuadStripBrushStretchUV` and `QuadStripBrushDistanceUV`.
- Open Brush pending-request behavior coverage for `QuadStripBrushStretchUV` and `QuadStripBrushDistanceUV`, plus complete unitized UV layout/no-op hook coverage for `QuadStripUnitizedUVBrush`.
- Catalog replay coverage now verifies every normal quad-strip and flat-geometry prefab family generates complete descriptor-driven mesh channels through the shared runtime replay path.
- Open Brush `FlatGeometryBrush` texture atlas count handling now matches Open Brush directly, with distance/stretch atlas branch coverage.
- Open Brush `FlatGeometryBrush` offset-in-texcoord1 UV1 vector behavior now has focused coverage and remains covered by catalog replay for all normal `MidpointPlusOffset` brushes.
- Open Brush `FlatGeometryBrush` non-M11 smoothing/shared-vertex output, continuation tangent generation, double-back break behavior, self-intersection size clipping, growth limiting, and M11 break-angle behavior now have focused lifecycle coverage.
- Open Brush `ThickGeometryBrush` texture atlas count handling and atlas branch coverage for distance/stretch UVs.
- Open Brush `TubeBrush` texture atlas count handling and direct UV-rate division behavior, with atlas branch coverage for distance UVs.
- Catalog replay coverage now verifies every normal tube-derived brush, including `BubbleWand`, generates complete descriptor-driven mesh channels through the shared runtime replay path.
- Open Brush `BubbleWandBrush` finalization control flow, UVW formula behavior, and UV1 original-position storage coverage.
- Open Brush `BlocksBrushScript` explicit no-op batched finalization behavior.
- Open Brush `TetraBrush` texture atlas count handling and distance atlas branch coverage, including texture edge chop.
- Catalog replay coverage now verifies every remaining active normal solid/hull/square/slice prefab family generates complete descriptor-driven mesh channels through the shared runtime replay path.
- Open Brush `SquareBrush` and `PrintableBrush` shared-ring continuation and sharp-turn segment-break topology now have focused lifecycle coverage.
- Open Brush `Square3DPrintBrush` parity-flip topology branch coverage for double-back strokes.
- Open Brush `SliceBrush` initial frame direction/normal orientation behavior, routed through the shared `ComputeSurfaceFrameNew` parity helper.
- Open Brush `HullBrush` `SimplifyAtEnd` batched finalization route and simplification tolerance pass.
- Open Brush `ConcaveHullBrush` knot-conversion formulas are now covered directly for every conversion mode, and smooth cube hull geometry is covered through the native polygon-face triangulation adaptation.
- Open Brush `MathUtils.ComputeMinimalRotationFrame` forward-axis convention for Godot `Basis.looking_at`.
- Open Brush `TubeBrush` routing through shared `MathUtils.ComputeMinimalRotationFrame` instead of a local alternate frame path.
- Open Brush `BaseBrushScript` lifecycle helper behavior for pointer/local scale conversions, random seed setter, exact identity-orientation `ComputeSurfaceFrameNew`, pressured size/opacity formulas, backface initialization, and `m_LastSpawnXf` update gating.
- Open Brush `GeometryBrush` initial knot `smoothedPressure` default behavior before the first update.
- Direct runtime finalization for `QuadStripBrushDistanceUV` now flushes pending tangent requests like the visual update path, matching the established stretch UV finalization behavior.
- Open Brush fake layout brushes (`PbrBrushScript`, `EnvironmentBrushScript`, `SvgBrushScript`) are classified as non-mesh layout providers with explicit no-op batched finalization.
- Converted Godot brush material coverage now exists for the catalog `Digital`, `Race`, and `PassthroughHull` normal brushes, and `Slice.gdshader` now stages CUSTOM0 data through a vertex varying so headless shader validation compiles.
- Current Godot parity tests and probes are classified in `OPEN_BRUSH_PARITY_TEST_INVENTORY.md`, including the remaining evidence gap that no authoritative Open Brush reference mesh fixtures have been exported yet.
- An Open Brush reference mesh fixture harness now exists at `Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd`. It scans `Resources/Fixtures/OpenBrushReferenceMeshes/*.json`, replays each referenced stroke through Godot, and compares vertex positions, triangle indices, normals, colors, tangents, and full-width UV0/UV1/UV2 data against Open Brush-exported mesh data.
- The Unity-side exporter source now exists at `Tools/OpenBrushReferenceMeshExport/OpenBrushReferenceMeshExportTest.cs`. It is installed in the Open Brush Unity editor test assembly and exports finalized `BatchSubset` mesh data plus `GeometryPool` layout/channel data for the representative cafe Ink, DuctTapeGeometry, Stars, Sparks, and MatteHull fixtures.
- `Tools/OpenBrushReferenceMeshExport/RunOpenBrushReferenceMeshExport.ps1` now defaults to the separate `open-brush-reference-exporter-worktree` checkout and refuses to run against the main `open-brush-fast` checkout unless `-AllowMainOpenBrushProject` is passed explicitly.
- `Tests/GDScript/OpenBrushReferenceExporterCoverageTest.gd` now keeps the representative cafe fixture contract executable by checking that the Unity exporter source, runner safety guard, and reference fixture README stay aligned.
- `OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md` now records the Phase 1.2 brush class inventory: runtime class, Open Brush source file, catalog prefab families, geometry/UV role, finalization requirement, coverage, and current status. `Tests/GDScript/BrushClassInventoryCoverageTest.gd` keeps that inventory aligned with the catalog prefab families and expected source/runtime classes.
- The four Open Brush experimental ParentBrush composites (`CandyCane`, `HolidayTree`, `Braid3`, and `Snowflake`) are now explicitly recorded as unsupported catalog brushes instead of surfacing as generic missing GUID warnings during manifest loading.
- `TiltBrushManifest.append_from()` now de-duplicates merged manifests by brush GUID instead of object identity and lets normal-brush entries take precedence over compatibility entries. This removes duplicate catalog GUID warnings and registers 97 live normal brushes when `Manifest.asset` and `Manifest_Experimental.asset` are combined.
- `Tests/GDScript/BrushRuntimeRegistryParityTest.gd` now explicitly checks the promoted normal brushes that used to be masked by compatibility entries: `DotMarker` routes to `SprayBrush`, `Plasma` routes to `QuadStripBrushDistanceUV`, and `TaperedMarker_Flat` routes to `FlatGeometryBrush`.
- `Tests/GDScript/BrushRuntimeRegistryParityTest.gd` now checks that a normal brush descriptor with no runtime factory is not registered and that replaying it through `BrushStrokeReplay` returns no mesh instead of generating fallback geometry.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd` now checks all 97 merged-manifest normal brushes route to the expected runtime class and verifies the expected normal prefab-family counts, including the merged `Line` count of 20.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd` now checks all seven normal catalog `GeniusParticle` brushes initialize the Open Brush particle formulas from their real descriptor metadata, including particle rate, particle speed, random alpha, initial rotation range, spawn interval, particle size scale, and UV channel layout.
- `Tests/GDScript/FlatStripCatalogReplayTest.gd` now replays every normal catalog `Line`, `LineWithWidth`, `DistanceUV`, `UnitizedUV`, `FlatDistance`, `FlatStretch`, and `MidpointPlusOffset` brush through the shared runtime path and verifies descriptor-driven UV0, UV1, normal, color, tangent, and runtime-class expectations.
- `Tests/GDScript/GeniusParticlesCatalogReplayTest.gd` now replays every normal catalog `GeniusParticle` brush through the shared runtime replay path and verifies generated particle mesh channel completeness: vertices, triangle indices, normals, colors, UV0 Vector4, UV1 Vector3, and no tangents.
- `Tests/GDScript/SprayCatalogReplayTest.gd` now replays every normal catalog `Spray` and `MiddpointPlusLifetimeGeomSpray` brush through the shared runtime replay path and verifies generated particle mesh channel completeness for UV0, UV1, normals, colors, and tangents.
- `Tests/GDScript/TubeCatalogReplayTest.gd` now replays every normal catalog tube-derived prefab through the shared runtime replay path and verifies descriptor-driven UV0, UV1, normal, color, tangent, and runtime-class channel expectations, including the BubbleWand-specific no-tangent/UV1 Vector4 layout.
- `Tests/GDScript/SolidCatalogReplayTest.gd` now replays every normal catalog `ThickDistance`, `HullPrefab`, `HullPrefabPassthrough`, `HullPrefabSmooth`, `ConcaveHullPrefab`, `Square3DPrintBrush`, `SquareBrush_prefab`, and `Slice` brush through the shared runtime path and verifies descriptor-driven UV0, normal, color, tangent, and runtime-class expectations.
- `Tests/GDScript/CatalogReplayCoverageTest.gd` now proves the catalog replay tests collectively cover every active normal merged-manifest prefab family and all 97 normal live brushes.
- `Tests/GDScript/LiveVsTiltUvParityTest.gd` now compares vertex positions as well as primary UVs and includes the promoted normal brushes `DotMarker`, `Plasma`, and `TaperedMarker_Flat` across direct replay, memory replay, pointer math, and live object paths.

Focused tests added/updated:

- `Tests/GDScript/QuadStripParityTest.gd`
  - checks sharp-bend shrink behavior through the brush lifecycle,
  - checks intentional strip-break behavior on double-back turns,
  - checks double-sided backfaces mirror fused front quads,
  - checks batched finalization welds connected single-sided quad strips to shared-edge topology,
  - checks double-sided append-time backface color pattern and hue shifting,
  - checks `AppendLeadingQuad` squashes a previous one-solid segment when a new segment starts, including double-sided backside consistency,
  - checks double-sided DistanceUV backface UV/color/tangent channel mirroring,
  - checks double-sided UnitizedUV backface UV/tangent channel mirroring,
  - checks StretchUV and DistanceUV texture atlas branch formulas for `m_TextureAtlasV > 1`,
  - checks DistanceUV fade opacity is quantized to Unity `Color32` byte alpha,
  - checks DistanceUV direct solitary finalization flushes pending tangent requests before mesh export,
  - checks quad-strip append-time colors, opacity, previous-edge carryover, and hue-shifted backfaces use Unity `Color32` byte truncation,
  - checks quad-strip destroy-time geometry release returns unfinalized `MasterBrush` instances to the pool and does not double-release after finalization.
- `Tests/GDScript/FlatGeometryBrushParityTest.gd`
  - checks generated flat geometry vertex colors use Unity `Color32` byte truncation for RGB and alpha.
  - checks Flat distance and stretch UV texture atlas branch formulas for `m_TextureAtlasV > 1`.
  - checks `m_bOffsetInTexcoord1` UV1 offset vector layout and exported `MeshData` channel values.
  - checks non-M11 smoothing/shared-vertex output, continuation tangents, double-back break behavior, self-intersection size clipping, growth limiting, and M11 break-angle behavior through the runtime lifecycle.
  - checks batched finalization trims short non-compatibility post-break tails before mesh export, matching Open Brush `FinalizeBatchedBrush`.
- `Tests/GDScript/FlatStripCatalogReplayTest.gd`
  - replays all normal catalog `Line`, `LineWithWidth`, `DistanceUV`, `UnitizedUV`, `FlatDistance`, `FlatStretch`, and `MidpointPlusOffset` brushes through `BrushStrokeReplay`,
  - verifies each replay produces non-empty mesh data with complete descriptor-driven UV0, UV1, normal, color, and tangent channel layouts, including `LineWithWidth` width-in-UV0.z and `MidpointPlusOffset` UV1 offset behavior.
- `Tests/GDScript/ThickGeometryBrushParityTest.gd`
  - checks generated thick geometry vertex colors use Unity `Color32` byte truncation for RGB and alpha.
  - checks Thick distance and stretch UV texture atlas branch formulas for `m_TextureAtlasV > 1`.
- Existing focused brush tests for `HullBrush`, `ConcaveHullBrush`, `SprayBrush`, `MidpointPlusLifetimeSprayBrush`, `TubeBrush`, `SliceBrush`, `PrintableBrush`, `SquareBrush`, `Square3DPrintBrush`, and `TetraBrush`
  - now check generated vertex colors use Unity `Color32` byte truncation at their covered write points.
- `Tests/GDScript/SolidCatalogReplayTest.gd`
  - replays all normal catalog `ThickDistance`, `HullPrefab`, `HullPrefabPassthrough`, `HullPrefabSmooth`, `ConcaveHullPrefab`, `Square3DPrintBrush`, `SquareBrush_prefab`, and `Slice` brushes through `BrushStrokeReplay`,
  - verifies each replay produces non-empty mesh data with the expected descriptor-driven channel layout: thick UV0/tangents, hull UV0 Vector3/no tangents, concave hull no UV/tangents, square UV0/no tangents, 3D print color-only geometry, and Slice UV0 Vector3/no tangents.
- `Tests/GDScript/CatalogReplayCoverageTest.gd`
  - loads the merged manifest and checks that every active normal prefab family is assigned to one of the catalog replay tests,
  - verifies the covered replay family counts sum to the current 97 normal live brushes, preventing future catalog additions from bypassing replay coverage silently.
- `Tests/GDScript/ConcaveHullBrushParityTest.gd`
  - checks exact source-derived vertex generation for Rapidograph, Quill Pen, Tetrahedron, Octahedron, and Cube knot conversion modes,
  - checks ConcaveHull smooth cube geometry exports shared vertices, double-wound triangles, normalized normals, and correct fan-triangulated index counts through the native hull backend.
- `Tests/GDScript/HullBrushParityTest.gd`
  - checks convex hull helper coverage, tetrahedron conversion, double-sided hull geometry, faceted polygonal cube faces, interior tracking, and the `SimplifyAtEnd` batched finalization route.
- `Tests/GDScript/SliceBrushParityTest.gd`
  - checks shared-quad geometry, UVW distance accumulation, triangle winding, opaque `Color32` writes, and Open Brush normal direction for initial/front quads.
- `Tests/GDScript/Square3DPrintBrushParityTest.gd`
  - checks single-segment topology, shared-ring continuation topology, and flip-branch topology where Open Brush closes the previous ring face and adds an extra current-orientation ring.
- `Tests/GDScript/SquareBrushParityTest.gd`
  - checks straight segment topology, shared-ring continuation, sharp-turn segment break topology, caps, normals, default UVs, and opaque `Color32` writes.
- `Tests/GDScript/PrintableBrushParityTest.gd`
  - checks straight segment topology, envelope behavior, shared-ring continuation, sharp-turn segment break topology, caps, normals, default UVs, and opaque `Color32` writes.
- `Tests/GDScript/TetraBrushParityTest.gd`
  - checks Tetra distance and unitized UV geometry, generated topology, vertex color truncation, and distance UV texture atlas branch formulas for `m_TextureAtlasV > 1` with texture edge chop.
- `Tests/GDScript/TubeBrushParityTest.gd`
  - checks default soft tube geometry, hard-edge radius-in-UV layout, stretch UV remapping, shape modifier displacement, and distance UV texture atlas branch formulas for `m_TextureAtlasV > 1`.
- `Tests/GDScript/TubeCatalogReplayTest.gd`
  - replays all normal catalog `TubeDistanceUV`, `TubeDistanceUVSin`, `TubeStretchUV`, `Tube_Petal`, `Tube_Rain`, `Tube_Sparks`, `Tube_Spikes`, `Tube_Tapered`, `TubeBrush_Comet`, `Lofted`, and `LoftedHueShift` brushes through `BrushStrokeReplay`,
  - verifies each replay produces non-empty mesh data with complete descriptor-driven UV0, UV1, normal, color, and tangent channel layouts, including BubbleWand routing and UV channel behavior.
- `Tests/GDScript/BubbleWandBrushParityTest.gd`
  - checks BubbleWand layout, Tube-derived generated geometry, UVW post-processing formula across cap/ring/mid/tail vertices, computed bubble radius/center, finalization smoothing, release time capture, and original geometry position storage in UV1.
- `Tests/GDScript/BlocksBrushParityTest.gd`
  - checks BlocksBrush layout flags, no-op update/spawn contract, solitary finalization, and runtime batched finalization no-op behavior.
- `Tests/GDScript/SprayBrushParityTest.gd`
  - checks Spray geometry layout, double-sided output, single-sided descriptor handling, UV/tangent generation, batched runtime finalization, Open Brush salt wraparound, and preview decay aging with elapsed time.
- `Tests/GDScript/SprayCatalogReplayTest.gd`
  - replays all four normal catalog `Spray` brushes and all three normal catalog `MiddpointPlusLifetimeGeomSpray` brushes through `BrushStrokeReplay`,
  - verifies each replay produces particle-quad-aligned mesh data with complete normal/color/UV0/tangent channels and the expected UV1 presence or absence for each prefab family.
- `Tests/GDScript/GeniusParticlesBrushParityTest.gd`
  - checks Genius particle geometry layout, generated UV channels, texture atlas UV branch behavior for `m_TextureAtlasV > 1`, solitary and batched hanging-particle finalization, single-particle pressure behavior, preview decay aging with elapsed time, and Open Brush birth-time sign packing in UV0.w.
  - checks randomized alpha, position scatter from particle speed, size variance, and roll packing against the source formulas.
- `Tests/GDScript/GeniusParticlesCatalogReplayTest.gd`
  - replays all seven normal catalog `GeniusParticle` brushes through `BrushStrokeReplay`,
  - verifies each one produces particle-quad-aligned mesh data with complete normal/color/UV0 Vector4/UV1 Vector3 channels and no tangents.
- `Tests/GDScript/MidpointSprayBrushParityTest.gd`
  - checks Midpoint Plus Lifetime Spray geometry layout, generated UV0/UV1 channels, tangent/color output, finalization preserving the generated particle mesh rather than applying Genius Particles hanging-particle removal, and Open Brush birth-time packing in UV1.w.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd`
  - walks the real manifest/catalog and verifies all normal `Line`, `LineWithWidth`, `UnitizedUV`, and `DistanceUV` prefabs route to the repaired quad-strip runtime classes.
  - verifies every mesh-affecting prefab field in the active manifest/catalog is applied to the created runtime brush instance, including quad-strip width storage, flat/thick/tube UV style, flat offset flags, hull parameters, concave hull parameters, and tube shape parameters.
  - verifies all normal catalog `GeniusParticle` brushes use nonzero Open Brush particle formula inputs and initialize spawn interval, particle size scale, random alpha, initial rotation range, and UV channel layout from descriptor metadata.
- `Tests/GDScript/UtilityParityTest.gd`
  - checks shared utility behavior including `MathUtils.ComputeMinimalRotationFrame` forward-axis parity.
- `Tests/GDScript/BrushLifecycleParityTest.gd`
  - checks shared base brush lifecycle helpers, including pointer/local scale conversions, random seed setter, exact surface frame output, pressured size/opacity, backface initialization, and `m_LastSpawnXf` update gating,
  - checks shared geometry brush lifecycle, including initial knot defaults, first-update dirty tracking, geometry resize/copy, and finalization release behavior.
- `Tests/GDScript/LayoutBrushParityTest.gd`
  - checks fake layout brush vertex layouts and no-op update/solitary/runtime finalization contracts for PBR, environment, and SVG layout providers.
- `Tests/GDScript/CafeStrokeFixturesReplayTest.gd`
  - replays checked-in cafe stroke fixtures through `OpenBrushStrokeBridge` and `BrushStrokeReplay` without loading the full cafe `.tilt`,
  - verifies the cafe legacy Ink GUID resolves to the runtime `Ink` descriptor and `QuadStripBrushStretchUV`,
  - verifies `Resources/Fixtures/cafe_ink_stroke_150.json` produces 600 vertices, 600 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_duct_tape_geometry_stroke_496.json` resolves to `DuctTapeGeometry` / `FlatGeometryBrush` and produces 104 vertices, 300 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_stars_stroke_130.json` resolves to `Stars` / `GeniusParticlesBrush` and produces 4 vertices, 6 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_sparks_stroke_463.json` resolves to `Sparks` / `TubeBrush` and produces 34 vertices, 96 indices, full UV0/color channels, and stable cafe-space bounds,
  - verifies `Resources/Fixtures/cafe_matte_hull_stroke_11.json` resolves to `MatteHull` / `HullBrush` and produces 36 vertices, 36 indices, full UV0/color channels, and stable cafe-space bounds.
- `Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd`
  - provides the source-of-truth mesh comparison harness for future Open Brush C# mesh fixtures,
  - scans `Resources/Fixtures/OpenBrushReferenceMeshes/*.json`,
  - supports referenced stroke fixtures via `source_stroke_fixture`,
  - compares positions, triangle indices, normals, colors, tangents, and full-width UV0/UV1/UV2 values directly from `MeshData`,
  - accepts `--require-open-brush-reference-fixtures` to fail when no fixtures are present.
- `Tests/GDScript/OpenBrushReferenceExporterCoverageTest.gd`
  - checks the checked-in Unity exporter source still includes the representative cafe fixture export set,
  - checks the exporter runner defaults to a separate Open Brush worktree and refuses the main Open Brush checkout by default,
  - checks the reference fixture README names the same representative cafe fixtures,
  - verifies the explicit `OpenBrushReferenceExport` category and `ExportRepresentativeCafeFixtures` entry point are present.
- `Tests/GDScript/BrushClassInventoryCoverageTest.gd`
  - checks `OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md` lists every expected runtime brush class,
  - checks all registry-supported normal prefab families, compatibility prefab families, and source-only Open Brush classes are documented,
  - checks representative audit-status snippets stay current for BaseBrush, layout brush, and source-only class coverage,
  - parses `Resources/BrushCatalog/brush_catalog.json` and verifies every referenced catalog prefab appears in the inventory.
- `Tests/GDScript/BrushCatalogParityTest.gd`
  - now checks manifest merging de-duplicates by brush GUID and removes a brush from compatibility when an appended manifest lists it as a normal brush.
- `Tests/GDScript/BrushRuntimeRegistryParityTest.gd`
  - now checks `DotMarker`, `Plasma`, and `TaperedMarker_Flat` remain normal live brushes after `Manifest_Experimental` is merged over `Manifest`.
  - now checks an unknown normal prefab with no factory fails replay without producing fallback mesh data.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd`
  - now checks every normal merged-manifest prefab family has the expected route and count before validating mesh-affecting prefab fields.
- `Tests/GDScript/LiveVsTiltUvParityTest.gd`
  - now checks vertex and primary-UV equivalence for `Ink`, `Paper`, `TaperedMarker`, `LightWire`, `DotMarker`, `Plasma`, and `TaperedMarker_Flat` across direct runtime replay, pointer-memory replay, pointer math, and live object drawing paths.
- `Tests/GDScript/CafeStrokeFixtureExtractProbe.gd`
  - extracts a source fixture from `res://Temp/TiltEvidence/brush_cafe_experimental.tilt`,
  - defaults to stroke index 150 and accepts `--source-stroke-index=...`,
  - this is a fixture-generation probe, not part of the normal fast parity suite.
- `Tests/GDScript/CafeFixtureCandidateProbe.gd`
  - lists first runtime-supported cafe stroke candidates by descriptor prefab and runtime class so new fixture choices are reproducible.
- `Tests/GDScript/TiltImporterRuntimeReplayTest.gd`
  - verifies the `.tilt` importer and runtime scene builder do not contain the old fallback tessellator entry points,
  - verifies the `.tilt` path does not contain importer-local brush-family factory tokens or old fallback constants,
  - verifies the `.tilt` path contains the shared `BrushRuntimeRegistry`, `BrushStrokeReplay`, and `BrushMaterialResolver` routing points,
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

Additional validation after expanding `BaseBrushScript` lifecycle-helper coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushLifecycleParityTest.gd
```

Result: command exited successfully without cleanup warnings.

Heavier cafe importer validation also run:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: command exited successfully.

Additional validation after removing unused `GeometryPool` fallback fill behavior:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/GeometryPoolParityTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: both commands exited successfully. A repository search now leaves `fallback` mentions only in test/probe assertions or documentation, not in production runtime/importer fallback geometry paths.

Additional validation after adding the missing catalog material assets and fixing `Slice.gdshader` CUSTOM0 access:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/SliceBrushParityTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/SolidCatalogReplayTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
```

Result: all three commands exited successfully. The previous `Digital`, `Race`, `PassthroughHull`, and `Slice.gdshader` material/shader failures no longer appear.

Additional validation after correcting stale shader UIDs in Godot brush materials:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/CafeStrokeFixturesReplayTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: all three commands exited successfully. The previous shader UID warnings for `Electricity.tres`, `Stars.tres`, and the cafe-imported `Snow`, `Dots`, `Smoke`, `Embers`, and `Bubbles` materials no longer appear.

Additional validation after strengthening the importer fallback regression guard:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: command exited successfully. The guard now rejects the old importer-local family dispatch helpers, fallback tessellator entry points, and fallback constants, and requires the shared registry, replay, and material resolver path.

Additional validation after adding the exporter-runner main-checkout safety guard:

```powershell
& .\Tools\OpenBrushReferenceMeshExport\RunOpenBrushReferenceMeshExport.ps1 -OpenBrushRoot "C:\Users\andyb\Documents\open-brush-fast"
```

Result: command stopped before launching Unity with `Refusing to run reference export against the main Open Brush checkout`.

The exporter was then attempted against `C:\Users\andyb\Documents\open-brush-reference-exporter-worktree`:

```powershell
& .\Tools\OpenBrushReferenceMeshExport\RunOpenBrushReferenceMeshExport.ps1 -OpenBrushRoot "C:\Users\andyb\Documents\open-brush-reference-exporter-worktree"
```

Result: Unity opened the separate worktree but failed before running tests during package resolution: `The "path" argument must be of type string. Received undefined.` No reference mesh fixtures were generated.

Exporter contract validation after the runner guard change:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/OpenBrushReferenceExporterCoverageTest.gd
```

Result: command exited successfully.

Additional validation after tightening brush class inventory status coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushClassInventoryCoverageTest.gd
```

Result: command exited successfully.

Additional validation after tightening quad-strip base and UV subclass audit coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after extending quad-strip finalization/export coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip pressure/threshold/no-update coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip preview-move and strip-break-disabled branch coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip destroy-time geometry-pool release coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip previous lone-segment squash coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after repairing `FlatGeometryBrush` atlas count handling:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushClassInventoryCoverageTest.gd
```

Result: all three commands exited successfully.

Additional validation after adding `FlatGeometryBrush` UV1 offset vector coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
```

Result: both commands exited successfully.

Additional validation after adding `FlatGeometryBrush` non-M11 smoothing and break coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
& "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
```

Result: both commands exited successfully.

Additional validation after adding `FlatGeometryBrush` non-M11 clipping/growth-limit and M11 break-angle coverage:

```powershell
& "C:\Program Files\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
```

Result: command exited successfully.

Open Brush Unity editor project compile check also run after installing the exporter:

```powershell
dotnet build Assembly-CSharp-Editor.csproj
```

Result: command exited successfully with existing warning noise.

Known validation noise:

- Godot reported an existing resource-leak warning after a scene-style test.
- Catalog loading now explicitly logs unsupported experimental ParentBrush composite skips instead of missing GUID or duplicate GUID warnings.
- Cafe importer validation reports legacy GUID remaps; these do not currently fail the runtime replay test.
- Unity reference fixture export from the separate Open Brush worktree is currently blocked by Unity Package Manager failing during fresh package resolution before tests run.

## Next Required Work

1. Continue base `QuadStripBrush` audit:
   - compare remaining append/fuse branch details line-by-line,
   - confirm all normal flat strip brushes route through the repaired runtime path.
2. Continue `FlatGeometryBrush` branch audit:
   - compare any remaining descriptor/frame-layout branches line-by-line,
   - add Open Brush reference mesh fixture comparison for representative flat geometry strokes.
3. Extract additional lightweight real-stroke fixtures for any brush the inspector identifies as suspect.
4. Generate or import authoritative Open Brush reference mesh fixtures; the current cafe fixture verifies Godot runtime stability for a real stroke but does not yet compare against Open Brush vertex-by-vertex output.
5. Convert current helper tests into generated-mesh parity tests where possible.
6. Audit all remaining brush classes line-by-line against the reference source.
