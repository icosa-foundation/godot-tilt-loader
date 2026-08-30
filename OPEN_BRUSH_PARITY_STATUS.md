# Open Brush Mesh Parity Status

## Reference Source

- Source baseline: `OPEN_BRUSH_SOURCE_BASELINE.md`
- Immediate C# conversion oracle: `origin/feature/godot`
- Immediate C# oracle commit: `737f46875a97bbb3fc139929f3c029370777d5fa`
- Historical upstream Open Brush reference commit recorded by prior audits: `3d4436ab93843ffd2c56f51222c78e770f20d520`
- Current rule: do not use or modify `C:/Users/andyb/Documents/open-brush-fast` for exporter work.
- Godot C# brush source directory: `Assets/Scripts/Brushes`
- Godot port directory: `Scripts/Brushes`
- Current test classification inventory: `OPEN_BRUSH_PARITY_TEST_INVENTORY.md`
- Brush class inventory: `OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md`
- Raw Open Brush reference fixtures: generated in the Open Brush checkout under `Support/BrushFixtures`

The Godot C# commit above is the current immediate conversion reference unless
this file is deliberately updated. Upstream Open Brush C# remains the intended
behavior reference when the Godot C# port itself needs explanation.

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
| `SprayBrush.gd` | `SprayBrush.cs` | Partially audited, active repair started | Shared `GeometryBrush.SetVert` color parity is covered. Preview decay now advances with elapsed time instead of a zero delta. Random salt wraparound now matches Open Brush `kSaltMaxQuadsPerKnot`. Spawn interval, random size, rotation variance, position variance, randomized alpha, atlas UV selection, multi-particle spacing, and tangent/backface output now have focused source-formula coverage. Full Open Brush reference fixture comparison still required. |
| `GeniusParticlesBrush.gd` | `GeniusParticlesBrush.cs` | Partially audited, active repair started | Shared `GeometryBrush.SetVert` color parity is covered. Preview decay now advances with elapsed time instead of a zero delta. Batched finalization now explicitly runs particle finalization like Open Brush. UV0.w now matches the Godot C# port's non-`OPENBRUSH` behavior. Generated ArrayMesh export now remaps Genius particle data for the Godot runtime shader contract: UV xy, UV2.x birth time, UV2.y rotation, importer-compatible tangent rotation, and `CUSTOM0` vertex id plus particle center. Generated live meshes now apply catalog `m_BoundsPadding` as `ArrayMesh.custom_aabb` for shader-displaced particle culling without changing vertex geometry. Runtime particle material duplicates read rotation from UV2.y because Godot normalizes renderable tangents. Texture atlas UVs, randomized alpha/offset/roll branches, pointer-travel distance override, straight-edge proxy flag, decay length-cache reduction, salt offset after decay, and finalization/length-cache control flow now have focused parity coverage. Full Open Brush reference fixture comparison remains. |
| `BubbleWandBrush.gd` | `BubbleWandBrush.cs` | Partially audited, active repair started | Existing parity tests cover selected behavior. BubbleWand-specific UVW post-processing, original-position UV1 storage, and direct finalization control flow now have focused coverage. Needs full branch audit. |
| `BlocksBrushScript.gd` | `BlocksBrushScript.cs` | Partially audited, active repair started | Existing parity tests cover the no-op contract and vertex layout. Batched finalization is now explicitly no-op like Open Brush. Needs full catalog usage audit. |
| `TetraBrush.gd` | `TetraBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Texture atlas count handling now matches Open Brush directly, with distance atlas and texture-edge chop coverage. Needs full branch audit. |
| `SquareBrush.gd` | `SquareBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover layout/spawn interval, straight topology, shared-ring continuation, sharp-turn segment break behavior, sub-minimum segment break/restart behavior, and invisible-back frame selection. Needs full reference fixture comparison. |
| `Square3DPrintBrush.gd` | `Square3DPrintBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover layout/spawn interval clamp behavior, straight topology, shared-ring continuation, parity-flip ring-face insertion, and close-knot break/restart behavior. Needs full reference fixture comparison. |
| `SliceBrush.gd` | `SliceBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Initial frame direction now matches Open Brush `ComputeSurfaceFrameNew` + `Quaternion.LookRotation` semantics. Spawn interval/layout, shared-quad continuation, short-segment break/restart behavior, UVW distance reset, and penultimate detection now have focused coverage. Full reference fixture comparison still required. |
| `PrintableBrush.gd` | `PrintableBrush.cs` | Partially audited, active repair started | Vertex color writes now use Open Brush `Color32` truncation. Tests now cover layout/spawn interval, straight topology, envelope behavior, shared-ring continuation, sharp-turn segment break behavior, sub-minimum segment break/restart behavior, and invisible-back frame selection. Needs full reference fixture comparison. |
| `PbrBrushScript.gd` | `PbrBrushScript.cs` | Audited as non-mesh layout provider | Matches Open Brush fake-brush role: layout only, update returns true, zero used verts, zero spawn interval, and explicit no-op solitary/batched finalization. |
| `EnvironmentBrushScript.gd` | `EnvironmentBrushScript.cs` | Audited as non-mesh layout provider | Matches Open Brush fake-brush role: layout only, optional UV1 layout, update returns true, zero used verts, zero spawn interval, and explicit no-op solitary/batched finalization. |
| `SvgBrushScript.gd` | `SvgBrushScript.cs` | Audited as non-mesh layout provider | Matches Open Brush fake-brush role: layout only, update returns true, zero used verts, zero spawn interval, and explicit no-op solitary/batched finalization. |
| `MidpointPlusLifetimeSprayBrush.gd` | `MidpointPlusLifetimeSprayBrush.cs` | Partially audited, active repair started | Removed non-Open-Brush finalization rewrite and the leftover unused particle helper copied from Genius-style particle behavior; finalization now preserves generated midpoint particles. Spawn interval, seeded random size/rotation/position/alpha branches, atlas UV selection, multi-particle spacing, tangent output, UV1 offset packing, and UV1.w birth time now have focused source-formula coverage. Full Open Brush reference fixture comparison still required. |

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
- Godot C# port particle birth-time packing for `GeniusParticlesBrush` UV0.w and Open Brush particle birth-time packing for `MidpointPlusLifetimeSprayBrush` UV1.w.
- Generated Genius particle ArrayMesh export now matches the Godot runtime particle shader contract: normals-as-centers move to `CUSTOM0.yzw`, vertex id goes to `CUSTOM0.x`, UV0.z rotation moves to `UV2.y`, UV0.w birth time moves to `UV2.x`, and texture UV remains UV0.xy. The importer-compatible tangent value is still emitted, but renderable `ArrayMesh` tangent normalization means runtime particle shaders must not use `TANGENT.z` for raw rotation.
- The standalone Icosa stroke bridge now resolves stroke materials through `BrushMaterialResolver` instead of calling the Icosa helper directly, so bridge-created GeniusParticle strokes receive the same runtime particle shader channel rewrite as live drawing and `.tilt` runtime rebuilds.
- The standalone Icosa stroke bridge now initializes the merged runtime manifest/catalog on demand before resolving stroke GUIDs, matching the setup assumption used by the `.tilt` scene builder instead of requiring callers to initialize `BrushCatalog` first.
- GeniusParticle material coverage now classifies the material side explicitly: `Bubbles`, `Dots`, `Embers`, `Smoke`, `Snow`, and `Stars` use the billboard particle shader contract, while `Rising Bubbles` is the simple UV/COLOR shader outlier. All seven generated runtime materials are checked to avoid normalized `TANGENT.z` after resolver processing.
- Generated live meshes and Tilt runtime-rebuild grouped meshes now apply descriptor `m_BoundsPadding` as `ArrayMesh.custom_aabb`; this currently matters for catalog particle brushes such as `Embers` and `Snow` whose shaders can displace outside the source quad bounds. Runtime replay carries this as `MeshData.bounds_padding_ls` so grouped meshes merge padding by maximum local-space value instead of dropping it.
- Open Brush explicit `GeniusParticlesBrush.FinalizeBatchedBrush` behavior, with `GeometryBrush` batched finalization made non-reentrant for subclasses.
- Open Brush `GeniusParticlesBrush` finalization and length-cache update control flow, removing non-reference defensive guards in the covered paths.
- Open Brush `GeniusParticlesBrush` randomized alpha, size variance, positional scatter, and roll packing formulas now have focused coverage.
- Open Brush `GeniusParticlesBrush` pointer-travel distance override, straight-edge proxy flag, preview decay length-cache reduction, and decayed-knot salt offset now have focused coverage.
- Live pointer creation now matches the Godot C# lifecycle more closely: `CreateNewLine` no longer records a synthetic first control point, so recorded live strokes contain only points that were actually passed through `UpdatePosition_LS`. This matters most for `GeniusParticlesBrush`, where first-update state drives pointer-travel distance, particle positions, UVs, and custom particle attributes.
- `BrushStrokeReplay` now replays every stored control point, matching the Godot C# `UpdateLineFromStroke` path.
- `MinimalExample.draw_stroke` now treats generated sample path scale as `Stroke.m_BrushScale` and records normal control-point pressure. The previous path passed transform scale through as pressure while hard-coding brush scale, which could make generated 2D/inspector strokes diverge from Tilt replay semantics and distort pressure-sensitive particle formulas.
- Open Brush `SprayBrush.CalculateSalt` modulo behavior for dense knots.
- Open Brush `SprayBrush` spawn interval formula and seeded random particle layout branches now have focused coverage, including random size, rotation variance, position scatter, randomized alpha, atlas UV selection, multi-particle spacing, and tangent/backface sign output.
- Open Brush `MidpointPlusLifetimeSprayBrush` spawn interval formula and seeded random particle layout branches now have focused coverage, including random size, rotation variance, position scatter, randomized alpha, atlas UV selection, multi-particle spacing, tangent output, and UV1 offset packing.
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
- Open Brush `SquareBrush` layout/spawn interval, shared-ring continuation, sharp-turn segment-break topology, sub-minimum segment break/restart behavior, and invisible-back frame selection now have focused lifecycle coverage.
- Open Brush `PrintableBrush` layout/spawn interval, envelope behavior, shared-ring continuation, sharp-turn segment-break topology, sub-minimum segment break/restart behavior, and invisible-back frame selection now have focused lifecycle coverage.
- Open Brush `Square3DPrintBrush` layout/spawn interval clamp behavior, parity-flip topology branch coverage for double-back strokes, and close-knot break/restart behavior now have focused lifecycle coverage.
- Open Brush `SliceBrush` initial frame direction/normal orientation behavior, routed through the shared `ComputeSurfaceFrameNew` parity helper.
- Open Brush `SliceBrush` spawn interval formula, UV0 Vector3/no-tangent layout, short-segment strip-break/restart path, UVW distance reset, and penultimate detection now have focused coverage.
- Open Brush `HullBrush` `SimplifyAtEnd` batched finalization route and simplification tolerance pass.
- Open Brush `ConcaveHullBrush` knot-conversion formulas are now covered directly for every conversion mode, and smooth cube hull geometry is covered through the native polygon-face triangulation adaptation.
- Open Brush `MathUtils.ComputeMinimalRotationFrame` forward-axis convention for Godot `Basis.looking_at`.
- Open Brush `TubeBrush` routing through shared `MathUtils.ComputeMinimalRotationFrame` instead of a local alternate frame path.
- Open Brush `BaseBrushScript` lifecycle helper behavior for pointer/local scale conversions, random seed setter, exact identity-orientation `ComputeSurfaceFrameNew`, pressured size/opacity formulas, backface initialization, and `m_LastSpawnXf` update gating.
- Open Brush `GeometryBrush` initial knot `smoothedPressure` default behavior before the first update.
- Direct runtime finalization for `QuadStripBrushDistanceUV` now flushes pending tangent requests like the visual update path, matching the established stretch UV finalization behavior.
- Open Brush fake layout brushes (`PbrBrushScript`, `EnvironmentBrushScript`, `SvgBrushScript`) are classified as non-mesh layout providers with explicit no-op batched finalization.
- Converted Godot brush material coverage now exists for the catalog `Digital`, `Race`, and `PassthroughHull` normal brushes, and `Slice.gdshader` now stages CUSTOM0 data through a vertex varying so headless shader validation compiles.
- Current Godot parity tests and probes are classified in `OPEN_BRUSH_PARITY_TEST_INVENTORY.md`.
- `Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd` reads raw `.mesh.json` files directly from an explicitly supplied Open Brush `Support/BrushFixtures` directory. Ordinary brushes retain strict topology and vertex-channel comparison. `ConcaveHull` uses accumulated-surface validation for its sequence of small backend-dependent windows, and the five regular convex-hull brushes use geometric equivalence. Exact comparison machinery is retained for later work. All 95 current fixtures pass their compatibility gates.
- `OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md` now records the Phase 1.2 brush class inventory: runtime class, Open Brush source file, catalog prefab families, geometry/UV role, finalization requirement, coverage, and current status. `Tests/GDScript/BrushClassInventoryCoverageTest.gd` keeps that inventory aligned with the catalog prefab families and expected source/runtime classes.
- The four Open Brush experimental ParentBrush composites (`CandyCane`, `HolidayTree`, `Braid3`, and `Snowflake`) are now explicitly recorded as unsupported catalog brushes instead of surfacing as generic missing GUID warnings during manifest loading.
- `TiltBrushManifest.append_from()` now de-duplicates merged manifests by brush GUID instead of object identity and lets normal-brush entries take precedence over compatibility entries. This removes duplicate catalog GUID warnings and registers 97 live normal brushes when `Manifest.asset` and `Manifest_Experimental.asset` are combined.
- `Tests/GDScript/BrushRuntimeRegistryParityTest.gd` now explicitly checks the promoted normal brushes that used to be masked by compatibility entries: `DotMarker` routes to `SprayBrush`, `Plasma` routes to `QuadStripBrushDistanceUV`, and `TaperedMarker_Flat` routes to `FlatGeometryBrush`.
- `Tests/GDScript/BrushRuntimeRegistryParityTest.gd` now checks that a normal brush descriptor with no runtime factory is not registered and that replaying it through `BrushStrokeReplay` returns no mesh instead of generating fallback geometry.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd` now checks all 97 merged-manifest normal brushes route to the expected runtime class and verifies the expected normal prefab-family counts, including the merged `Line` count of 20.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd` now checks all seven normal catalog `GeniusParticle` brushes initialize the Open Brush particle formulas from their real descriptor metadata, including particle rate, particle speed, random alpha, initial rotation range, spawn interval, particle size scale, and UV channel layout.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd` now checks all normal catalog `Spray` and `MiddpointPlusLifetimeGeomSpray` brushes initialize the Open Brush particle formulas from their real descriptor metadata, including spray rate multiplier, size ratio, spawn interval, UV channel layout, normals, colors, and tangents.
- `Tests/GDScript/FlatStripCatalogReplayTest.gd` now replays every normal catalog `Line`, `LineWithWidth`, `DistanceUV`, `UnitizedUV`, `FlatDistance`, `FlatStretch`, and `MidpointPlusOffset` brush through the shared runtime path and verifies descriptor-driven UV0, UV1, normal, color, tangent, and runtime-class expectations.
- `Tests/GDScript/GeniusParticlesCatalogReplayTest.gd` now replays every normal catalog `GeniusParticle` brush through the shared runtime replay path and verifies generated particle mesh channel completeness: vertices, triangle indices, normals, colors, UV0 Vector4, UV1 Vector3, no source tangents, render-facing arrays for UV, UV2 birth time/rotation, importer-compatible tangent rotation, `CUSTOM0` particle id/center data, and generated mesh bounds padding for `Embers`/`Snow`.
- `Tests/GDScript/BrushMaterialResolverParityTest.gd` now checks all seven normal catalog `GeniusParticle` brushes resolve to real Icosa shader materials, keep brush textures, and that the duplicated runtime particle-shader materials read the expected `CUSTOM0` particle attributes and `UV2.y` rotation instead of normalized `TANGENT.z`.
- `Tests/GDScript/LiveVsTiltUvParityTest.gd` now includes representative Genius particle brushes `Stars` and `Embers`, comparing direct runtime replay, pointer memory replay, pointer math, and live object drawing for vertices, primary UVs, UV2 birth/rotation data, `CUSTOM0` particle id/center data, particle attribute flags, and bounds padding.
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
  - checks spawn interval formula, UV0 Vector3/no-tangent layout, shared-quad geometry, UVW distance accumulation, short-segment break/restart behavior, penultimate detection, triangle winding, opaque `Color32` writes, and Open Brush normal direction for initial/front quads.
- `Tests/GDScript/Square3DPrintBrushParityTest.gd`
  - checks layout flags, spawn interval clamp formulas, single-segment topology, shared-ring continuation topology, flip-branch topology where Open Brush closes the previous ring face and adds an extra current-orientation ring, and close-knot break/restart behavior.
- `Tests/GDScript/SquareBrushParityTest.gd`
  - checks layout flags, spawn interval formula, straight segment topology, shared-ring continuation, sharp-turn segment break topology, sub-minimum segment break/restart behavior, invisible-back frame selection, caps, normals, default UVs, and opaque `Color32` writes.
- `Tests/GDScript/PrintableBrushParityTest.gd`
  - checks layout flags, spawn interval formula, straight segment topology, envelope behavior, shared-ring continuation, sharp-turn segment break topology, sub-minimum segment break/restart behavior, invisible-back frame selection, caps, normals, default UVs, and opaque `Color32` writes.
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
  - checks Spray geometry layout, double-sided output, single-sided descriptor handling, spawn interval metadata, seeded random size/rotation/position/alpha formulas, atlas UV selection, UV/tangent generation, batched runtime finalization, Open Brush salt wraparound, and preview decay aging with elapsed time.
- `Tests/GDScript/SprayCatalogReplayTest.gd`
  - replays all four normal catalog `Spray` brushes and all three normal catalog `MiddpointPlusLifetimeGeomSpray` brushes through `BrushStrokeReplay`,
  - verifies each replay produces particle-quad-aligned mesh data with complete normal/color/UV0/tangent channels and the expected UV1 presence or absence for each prefab family.
- `Tests/GDScript/GeniusParticlesBrushParityTest.gd`
  - checks Genius particle geometry layout, generated UV channels, texture atlas UV branch behavior for `m_TextureAtlasV > 1`, pointer-travel distance override, straight-edge proxy flag, generated mesh particle-attribute export flag, solitary and batched hanging-particle finalization, single-particle pressure behavior, preview decay aging with elapsed time, preview length-cache reduction, decayed-knot salt offset, and Godot C# port birth-time packing in UV0.w.
  - checks randomized alpha, position scatter from particle speed, size variance, and roll packing against the source formulas.
- `Tests/GDScript/MeshDataArrayExportParityTest.gd`
  - checks ordinary wide-texcoord ArrayMesh export, `MeshData.bounds_padding_ls` copy/merge behavior, and the generated particle mesh export contract used by Genius particle shaders, including surface-level proof that `UV2.y` survives `ArrayMesh` creation as the runtime rotation channel.
- `Tests/GDScript/GeniusParticlesCatalogReplayTest.gd`
  - replays all seven normal catalog `GeniusParticle` brushes through `BrushStrokeReplay`,
  - verifies each one produces particle-quad-aligned mesh data with complete normal/color/UV0 Vector4/UV1 Vector3 channels and no tangents,
  - verifies each generated catalog stroke exports the render-facing particle arrays needed by the runtime shader: UV, UV2 birth time/rotation, importer-compatible tangent rotation, and `CUSTOM0` vertex id plus particle center.
- `Tests/GDScript/MidpointSprayBrushParityTest.gd`
  - checks Midpoint Plus Lifetime Spray geometry layout, spawn interval metadata, seeded random size/rotation/position/alpha formulas, atlas UV selection, generated UV0/UV1 channels, UV1 offset packing, tangent/color output, finalization preserving the generated particle mesh rather than applying Genius Particles hanging-particle removal, and Open Brush birth-time packing in UV1.w.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd`
  - walks the real manifest/catalog and verifies all normal `Line`, `LineWithWidth`, `UnitizedUV`, and `DistanceUV` prefabs route to the repaired quad-strip runtime classes.
  - verifies every mesh-affecting prefab field in the active manifest/catalog is applied to the created runtime brush instance, including quad-strip width storage, flat/thick/tube UV style, flat offset flags, hull parameters, concave hull parameters, and tube shape parameters.
  - verifies all normal catalog `GeniusParticle` brushes use nonzero Open Brush particle formula inputs and initialize spawn interval, particle size scale, random alpha, initial rotation range, and UV channel layout from descriptor metadata.
  - verifies all normal catalog `Spray` and `MiddpointPlusLifetimeGeomSpray` brushes use nonzero Open Brush spray formula inputs and initialize spawn interval, size ratio, UV layout, normal/color/tangent channels, and midpoint UV1 layout from descriptor metadata.
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
  - provides the source-of-truth mesh comparison harness for raw Open Brush C# mesh fixtures,
  - scans the directory supplied through `--fixtures=<directory>` for `.mesh.json` files,
  - compares positions, triangle indices, normals, colors, tangents, and full-width UV0/UV1/UV2 values directly from `MeshData`,
  - skips when no directory is supplied and fails when an explicitly supplied directory is missing or empty.
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
  - now checks vertex and primary-UV equivalence for `Ink`, `Paper`, `TaperedMarker`, `LightWire`, `DotMarker`, `Plasma`, `TaperedMarker_Flat`, `Stars`, and `Embers` across direct runtime replay, pointer-memory replay, pointer math, and live object drawing paths.
  - for `Stars` and `Embers`, also checks UV2 birth/rotation data, `CUSTOM0` particle id/center data, particle attribute flags, and bounds padding across those paths.
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
$godot = "godot"
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
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushLifecycleParityTest.gd
```

Result: command exited successfully without cleanup warnings.

Heavier cafe importer validation also run:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: command exited successfully.

Additional validation after removing unused `GeometryPool` fallback fill behavior:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeometryPoolParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: both commands exited successfully. A repository search now leaves `fallback` mentions only in test/probe assertions or documentation, not in production runtime/importer fallback geometry paths.

Additional validation after adding the missing catalog material assets and fixing `Slice.gdshader` CUSTOM0 access:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SliceBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SolidCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
```

Result: all three commands exited successfully. The previous `Digital`, `Race`, `PassthroughHull`, and `Slice.gdshader` material/shader failures no longer appear.

Additional validation after correcting stale shader UIDs in Godot brush materials:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/CafeStrokeFixturesReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: all three commands exited successfully. The previous shader UID warnings for `Electricity.tres`, `Stars.tres`, and the cafe-imported `Snow`, `Dots`, `Smoke`, `Embers`, and `Bubbles` materials no longer appear.

Additional validation after strengthening the importer fallback regression guard:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
```

Result: command exited successfully. The guard now rejects the old importer-local family dispatch helpers, fallback tessellator entry points, and fallback constants, and requires the shared registry, replay, and material resolver path.

Additional validation after tightening brush class inventory status coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushClassInventoryCoverageTest.gd
```

Result: command exited successfully.

Additional validation after tightening quad-strip base and UV subclass audit coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after extending quad-strip finalization/export coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip pressure/threshold/no-update coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip preview-move and strip-break-disabled branch coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip destroy-time geometry-pool release coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after adding quad-strip previous lone-segment squash coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/QuadStripParityTest.gd
```

Result: command exited successfully.

Additional validation after repairing `FlatGeometryBrush` atlas count handling:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushClassInventoryCoverageTest.gd
```

Result: all three commands exited successfully.

Additional validation after adding `FlatGeometryBrush` UV1 offset vector coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
```

Result: both commands exited successfully.

Additional validation after adding `FlatGeometryBrush` non-M11 smoothing and break coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatStripCatalogReplayTest.gd
```

Result: both commands exited successfully.

Additional validation after adding `FlatGeometryBrush` non-M11 clipping/growth-limit and M11 break-angle coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/FlatGeometryBrushParityTest.gd
```

Result: command exited successfully.

Additional validation after adding `GeniusParticlesBrush` pointer-travel, decay length-cache, and salt-offset coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd
```

Result: all three commands exited successfully.

Additional validation after moving generated/runtime Genius particle rotation off normalized `ArrayMesh` tangents and onto `UV2.y`:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/MeshDataArrayExportParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushMaterialResolverParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushLifecycleParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltImporterRuntimeReplayTest.gd
git diff --check
```

Result: all commands exited successfully. The mesh export test now includes a
surface-level `ArrayMesh` check that would fail if generated particle rotation
were still treated as raw `TANGENT.z`. `TiltImporterRuntimeReplayTest.gd` now
also checks that grouped cafe `Embers` and `Snow` runtime meshes keep custom
bounds padding.

Additional validation after extending live-vs-replay path equivalence to
representative Genius particle brushes:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/LiveVsTiltUvParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/MeshDataArrayExportParityTest.gd
git diff --check
```

Result: all commands exited successfully. `LiveVsTiltUvParityTest.gd` now
reports zero deltas for `Stars` and `Embers` across direct runtime replay,
pointer-memory replay, pointer math, and live object drawing for vertices,
primary UVs, UV2 particle birth/rotation, and `CUSTOM0` particle id/center data.

Additional validation after aligning live pointer control-point recording with
the Godot C# lifecycle and replaying every stored control point:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/PointerScriptParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/LiveVsTiltUvParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/MeshDataArrayExportParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushMaterialResolverParityTest.gd
```

Result: all commands exited successfully. `LiveVsTiltUvParityTest.gd` reports
zero vertex, primary UV, UV2, and `CUSTOM0` deltas for `Stars` and `Embers`
across direct runtime replay, memory replay, pointer math, and live object
drawing. This closes the immediate Godot path divergence that was specific to
Genius particle first-update state; the raw Open Brush fixture comparison is the
final C# parity evidence for this path.

Additional validation after correcting generated minimal/inspector stroke
scale-vs-pressure semantics:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/MinimalExamplesParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SingleBrushStrokeInspectorTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/LiveVsTiltUvParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesCatalogReplayTest.gd
git diff --check
```

Result: all commands exited successfully. `MinimalExamplesParityTest.gd` now
checks that generated path scale becomes `m_BrushScale` and that generated
control-point pressure remains `1.0` instead of inheriting path scale.

Additional validation after unifying Icosa bridge material resolution through
`BrushMaterialResolver` and making bridge catalog initialization explicit:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/IcosaBridgeSmokeTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushMaterialResolverParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/TiltBridgeReplayParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/MeshDataArrayExportParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/GeniusParticlesCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/LiveVsTiltUvParityTest.gd
```

Result: all commands exited successfully. The bridge material regression now
checks `Embers` specifically and verifies that bridge-created GeniusParticle
materials read generated rotation from `UV2.y` instead of normalized
`TANGENT.z`. `BrushMaterialResolverParityTest.gd` also classifies the full
normal GeniusParticle material set as six billboard particle shaders plus the
simple `Rising Bubbles` UV/COLOR shader outlier, and checks all seven resolved
runtime shaders have no `TANGENT.z` dependency. `TiltBridgeReplayParityTest.gd`
still reports zero vertex and UV deltas for the checked cafe strokes.

Additional validation after adding `SprayBrush` seeded particle layout and spawn-interval coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SprayBrushParityTest.gd
```

Result: command exited successfully.

Additional validation after adding `MidpointPlusLifetimeSprayBrush` seeded particle layout, UV1 offset, and spawn-interval coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/MidpointSprayBrushParityTest.gd
```

Result: command exited successfully.

Additional validation after adding Spray/Midpoint catalog metadata coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd
```

Result: command exited successfully with the known Godot resource-leak warning after test shutdown.

Additional validation after adding `SliceBrush` short-segment restart and spawn-interval coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SliceBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SolidCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushClassInventoryCoverageTest.gd
```

Result: all three commands exited successfully.

Additional validation after adding `SquareBrush` layout, short-segment restart, and invisible-back frame coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SquareBrushParityTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/SolidCatalogReplayTest.gd
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/BrushClassInventoryCoverageTest.gd
```

Result: all three commands exited successfully.

Additional validation after adding `PrintableBrush` layout, short-segment restart, and invisible-back frame coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/PrintableBrushParityTest.gd
```

Result: command exited successfully without missing-material warnings.

Additional validation after adding `Square3DPrintBrush` layout/spawn interval and close-knot restart coverage:

```powershell
& "godot" --headless --xr-mode off --path . --script res://Tests/GDScript/Square3DPrintBrushParityTest.gd
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
4. Run the direct raw Open Brush fixture comparison after relevant runtime or fixture-generator changes and classify any new discrepancies.
5. Convert current helper tests into generated-mesh parity tests where possible.
6. Audit all remaining brush classes line-by-line against the reference source.
