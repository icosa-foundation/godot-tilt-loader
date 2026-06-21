# Open Brush Parity Test Inventory

This inventory classifies the current Godot test and probe scripts against the test strategy in `OPEN_BRUSH_MESH_PARITY_PLAN.md`.

The key distinction is source authority. Current focused brush tests prove translated GDScript behavior against source-derived formulas, expected topology, and path consistency. They do not yet prove full vertex-for-vertex parity against exported Open Brush C# reference meshes. That remains required by Phase 4 and Phase 5 of the mesh parity plan.

## Categories

| Category | Meaning |
| --- | --- |
| `helper-method parity` | Covers small utility or helper methods derived from Open Brush source. |
| `lifecycle parity` | Drives brush creation, control point updates, finalization, and mesh export behavior. |
| `generated mesh parity` | Checks generated vertex/index/channel data for a focused brush behavior or source formula. |
| `path equivalence` | Compares two Godot runtime paths for the same stroke data. |
| `importer path test` | Verifies `.tilt` import/rebuild routing and importer behavior. |
| `metadata/material test` | Verifies catalog, registry, descriptor, material, or prefab metadata handling. |
| `visual smoke test` | Exercises a scene/tool intended primarily for human inspection. |
| `diagnostic probe` | Prints data or extracts fixtures; not part of the normal pass/fail parity suite. |
| `Open Brush reference mesh parity` | Compares Godot output against authoritative Open Brush mesh fixtures. The harness exists, but no authoritative fixtures are checked in yet. |
| `reference fixture contract` | Verifies the checked-in lightweight cafe fixtures, Unity exporter source, and reference fixture documentation stay aligned. |
| `inventory contract` | Verifies checked-in parity inventory documents still cover the current runtime/catalog surface. |

## Focused Brush Tests

| Test | Primary category | What it proves | Current limitation |
| --- | --- | --- | --- |
| `Tests/GDScript/QuadStripParityTest.gd` | `generated mesh parity` | Quad-strip UV modes, backfaces, bend/shrink/break behavior, color quantization, and batched weld finalization. | Source-derived expectations, not C# reference fixture comparison. |
| `Tests/GDScript/FlatGeometryBrushParityTest.gd` | `generated mesh parity` | Flat distance/stretch geometry branches and tail trimming finalization behavior. | Does not cover every branch or reference fixture shape. |
| `Tests/GDScript/FlatStripCatalogReplayTest.gd` | `generated mesh parity` | Every normal catalog quad-strip and flat-geometry prefab replays through the shared runtime path with descriptor-driven UV0/UV1/normal/color/tangent channel layouts, including `LineWithWidth` and `MidpointPlusOffset` channel behavior. | Stable Godot catalog replay, not Open Brush reference mesh comparison. |
| `Tests/GDScript/ThickGeometryBrushParityTest.gd` | `generated mesh parity` | Thick distance/stretch UV geometry and atlas branches. | Does not cover every branch or reference fixture shape. |
| `Tests/GDScript/SolidCatalogReplayTest.gd` | `generated mesh parity` | Every remaining active normal solid/hull/square/slice prefab replays through the shared runtime path with expected UV0/normal/color/tangent channel layouts. | Stable Godot catalog replay, not Open Brush reference mesh comparison; surfaces existing material/shader gaps for PassthroughHull and Slice. |
| `Tests/GDScript/TubeBrushParityTest.gd` | `generated mesh parity` | Tube soft/hard edges, UV modes, atlas branch, and shape modifier output. | Does not cover every tube prefab family or reference fixture shape. |
| `Tests/GDScript/TubeCatalogReplayTest.gd` | `generated mesh parity` | Every normal catalog tube-derived prefab replays through the shared runtime path with descriptor-driven UV0/UV1/normal/color/tangent channel layouts, including BubbleWand routing. | Stable Godot catalog replay, not Open Brush reference mesh comparison. |
| `Tests/GDScript/HullBrushParityTest.gd` | `generated mesh parity` | Hull conversion, native/fallback hull helper behavior, double-sided output, faceting, interior tracking, and simplify-at-end finalization route. | Native backend has known degenerate differences that still need classification. |
| `Tests/GDScript/ConcaveHullBrushParityTest.gd` | `generated mesh parity` | Concave hull knot-conversion formulas and smooth cube hull geometry. | Degenerate hull behavior still needs explicit classification. |
| `Tests/GDScript/SprayBrushParityTest.gd` | `generated mesh parity` | Spray geometry, salt wraparound, double/single-sided behavior, preview decay, and batched finalization. | Particle layout and seed behavior still need full source audit. |
| `Tests/GDScript/SprayCatalogReplayTest.gd` | `generated mesh parity` | Every normal catalog `Spray` and `MiddpointPlusLifetimeGeomSpray` brush replays through the shared runtime path with particle-quad-aligned mesh data and complete expected UV/color/normal/tangent channels. | Stable Godot catalog replay, not Open Brush reference mesh comparison. |
| `Tests/GDScript/GeniusParticlesBrushParityTest.gd` | `generated mesh parity` | Genius particle geometry, UV channels, atlas branch, random alpha/offset/roll formulas, birth-time sign, decay, and hanging-particle finalization. | Still not compared against Open Brush reference mesh fixtures. |
| `Tests/GDScript/GeniusParticlesCatalogReplayTest.gd` | `generated mesh parity` | Every normal catalog `GeniusParticle` brush replays through the shared runtime path with particle-quad-aligned mesh data and complete normal/color/UV0 Vector4/UV1 Vector3 channels. | Stable Godot catalog replay, not Open Brush reference mesh comparison. |
| `Tests/GDScript/MidpointSprayBrushParityTest.gd` | `generated mesh parity` | Midpoint Plus Lifetime Spray UV0/UV1/tangent/color output, birth time, and finalization behavior. | Particle layout and seed behavior still need full source audit. |
| `Tests/GDScript/BubbleWandBrushParityTest.gd` | `generated mesh parity` | BubbleWand Tube-derived geometry, UVW formula, release time, smoothing, and original-position UV1 storage. | Does not cover all Tube-derived branches. |
| `Tests/GDScript/BlocksBrushParityTest.gd` | `lifecycle parity` | Blocks brush no-op mesh contract and runtime finalization behavior. | Layout provider only; no generated mesh. |
| `Tests/GDScript/TetraBrushParityTest.gd` | `generated mesh parity` | Tetra distance/unitized UV geometry, atlas branch, topology, and color truncation. | Does not cover every pressure/rotation branch. |
| `Tests/GDScript/SquareBrushParityTest.gd` | `generated mesh parity` | Square straight segment topology, shared-ring continuation, sharp-turn segment break behavior, normals, UV default, caps, and color truncation. | Needs full source audit completion and reference fixture comparison. |
| `Tests/GDScript/Square3DPrintBrushParityTest.gd` | `generated mesh parity` | Single segment, shared-ring continuation, and flip branch topology. | Needs full branch audit and more shape fixtures. |
| `Tests/GDScript/SliceBrushParityTest.gd` | `generated mesh parity` | Slice shared-quad geometry, UVW distance, winding, color, and initial normal direction. | Needs full branch audit. |
| `Tests/GDScript/PrintableBrushParityTest.gd` | `generated mesh parity` | Printable straight segment topology, envelope behavior, shared-ring continuation, sharp-turn segment break behavior, normals, UV default, caps, and color truncation. | Needs full source audit completion and reference fixture comparison. |
| `Tests/GDScript/LayoutBrushParityTest.gd` | `lifecycle parity` | PBR, Environment, and SVG fake layout brush no-op contracts and layout flags. | Non-mesh provider coverage only. |

## Runtime, Importer, and Path Tests

| Test | Primary category | What it proves | Current limitation |
| --- | --- | --- | --- |
| `Tests/GDScript/BrushLifecycleParityTest.gd` | `lifecycle parity` | Shared geometry brush lifecycle, initial knot defaults, dirty tracking, resizing, finalization release, and base helpers. | Shared lifecycle only; not every subclass path. |
| `Tests/GDScript/PointerScriptParityTest.gd` | `path equivalence` | Pointer stroke lifecycle, control point replacement, and recreation from memory. | Limited sample strokes. |
| `Tests/GDScript/LiveVsTiltUvParityTest.gd` | `path equivalence` | Direct replay, pointer-memory replay, pointer math, and live object path produce matching vertices and primary UVs for selected brushes, including promoted normal brushes. | Compares Godot paths to each other, not Open Brush reference meshes. |
| `Tests/GDScript/TiltBridgeReplayParityTest.gd` | `path equivalence` | `.tilt` scene builder runtime mesh data matches bridge-created stroke replay for sample cafe strokes. | Checks first supported sample strokes only. |
| `Tests/GDScript/TiltImporterRuntimeReplayTest.gd` | `importer path test` | Importer has no old fallback tessellator entry points and cafe `.tilt` rebuilds through runtime brushes with substantial geometry. | Heavy scene-level check, not per-brush numeric reference parity. |
| `Tests/GDScript/CafeStrokeFixturesReplayTest.gd` | `generated mesh parity` | Lightweight extracted cafe fixtures replay through runtime classes with stable counts, channels, descriptor resolution, and bounds. | Stable Godot fixture replay, not Open Brush reference mesh comparison. |
| `Tests/GDScript/OpenBrushReferenceExporterCoverageTest.gd` | `reference fixture contract` | Verifies the Unity exporter source and reference fixture README still include the representative cafe fixture set: Ink, DuctTapeGeometry, Stars, Sparks, and MatteHull. | Contract coverage only; it does not generate or compare Open Brush mesh data. |
| `Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd` | `Open Brush reference mesh parity` | Scans `Resources/Fixtures/OpenBrushReferenceMeshes/*.json`, replays each referenced stroke through Godot, and compares positions, triangle indices, normals, colors, tangents, and full-width UV0/UV1/UV2 against Open Brush-exported fixture data. | Harness only until authoritative Open Brush C# mesh fixture JSON files are generated and checked in. |
| `Tests/GDScript/SingleBrushStrokeInspectorTest.gd` | `visual smoke test` | Single-brush inspector can instantiate and step through supported brush strokes for inspection. | Human-inspection support, not numeric parity proof. |
| `Tests/GDScript/MinimalExamplesParityTest.gd` | `visual smoke test` | 2D and XR example setup/drawing paths can be constructed without the full runtime. | Scene setup only; not enough to prove brush mesh parity. |
| `Tests/GDScript/SimpleControllersParityTest.gd` | `visual smoke test` | Simple drawing controller setup and controls behave as expected. | Controller/UI behavior only. |
| `Tests/GDScript/TiltEvidenceViewerLoadModeTest.gd` | `visual smoke test` | Cafe evidence viewer load mode defaults and scene routing are configured as intended. | Viewer behavior only. |
| `Tests/GDScript/TiltFileRenderValidation.gd` | `visual smoke test` | Tilt rendering validation script exercises imported scenes for broad regressions. | Broad render smoke, not brush-by-brush parity. |

## Metadata, Material, and Utility Tests

| Test | Primary category | What it proves | Current limitation |
| --- | --- | --- | --- |
| `Tests/GDScript/BrushCatalogParityTest.gd` | `metadata/material test` | Manifest/catalog loading and representative descriptor fields. | Does not prove every prefab field is applied. |
| `Tests/GDScript/BrushRuntimeRegistryParityTest.gd` | `metadata/material test` | Live registry excludes compatibility brushes and classifies unsupported experimental ParentBrush composites explicitly. | Registry policy only; ParentBrush composite generation is not ported yet. |
| `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd` | `metadata/material test` | Mesh-affecting prefab fields from active catalog are applied to runtime brush instances. | Limited to recognized field set. |
| `Tests/GDScript/BrushClassInventoryCoverageTest.gd` | `inventory contract` | Verifies `OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md` lists expected runtime classes, registry prefab families, compatibility prefab families, unsupported ParentBrush composites, source-only Open Brush helper classes, and every catalog prefab referenced by `Resources/BrushCatalog/brush_catalog.json`. | Documentation coverage only; it does not prove mesh parity. |
| `Tests/GDScript/BrushMaterialResolverParityTest.gd` | `metadata/material test` | Live brush material resolution uses the expected shared resolver path. | Material routing only, not mesh parity. |
| `Tests/GDScript/GeometryPoolParityTest.gd` | `helper-method parity` | GeometryPool append/copy/transform/shift behavior. | Pool behavior only. |
| `Tests/GDScript/MeshDataArrayExportParityTest.gd` | `helper-method parity` | MeshData export preserves wide texcoord arrays. | Mesh array conversion only. |
| `Tests/GDScript/UtilityParityTest.gd` | `helper-method parity` | Stateless RNG, quaternion utilities, transforms, pool, GUID, and minimal frame helpers. | Utility-level checks only. |
| `Tests/GDScript/SharedRuntimeParityTest.gd` | `helper-method parity` | Shared HSL, transform, and control point behavior. | Shared runtime helpers only. |
| `Tests/GDScript/IcosaBridgeSmokeTest.gd` | `importer path test` | Icosa bridge smoke coverage. | Connector/import bridge smoke only. |

## Diagnostic Probes

These scripts are useful for investigation or fixture generation, but they should not be counted as normal parity gates unless a command explicitly runs and evaluates them.

- `Tests/GDScript/CafeFixtureCandidateProbe.gd`
- `Tests/GDScript/CafeInkStrokeCompareProbe.gd`
- `Tests/GDScript/CafeStrokeFixtureExtractProbe.gd`
- `Tests/GDScript/HullBrushTiltProbe.gd`
- `Tests/GDScript/ImportedVsRuntimeCafeInkProbe.gd`
- `Tests/GDScript/NativeHullProbe.gd`
- `Tests/GDScript/NativeHullParitySuite.gd`
- `Tests/GDScript/TiltBrushStatsProbe.gd`
- `Tests/GDScript/TiltReaderProbe.gd`
- `Tests/GDScript/TiltSanityProbe.gd`

`NativeHullParitySuite.gd` is stricter than most probes and is useful as a focused native-extension validation gate, but it depends on external CSV data in the Godot user data directory and the native hull extension being available.

## Remaining Reference Fixture Gap

`Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd` now provides the `Open Brush reference mesh parity` harness. It intentionally passes with an explicit `OPEN_BRUSH_REFERENCE_MESH no reference fixtures found` message when no fixtures exist, so normal local smoke runs are not blocked before the exporter is ready.

The next major evidence upgrade is still to generate compact Open Brush C# reference mesh fixtures into `Resources/Fixtures/OpenBrushReferenceMeshes/` and compare Godot output against them numerically for representative brushes and stroke shapes. To force the harness to fail when no fixtures are available, run it with `--require-open-brush-reference-fixtures`.
