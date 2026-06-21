# Open Brush Brush Class Inventory

This inventory satisfies Phase 1.2 of `OPEN_BRUSH_MESH_PARITY_PLAN.md`.

Reference source:

- Open Brush repo: `C:/Users/andyb/Documents/open-brush-fast`
- Reference commit: `3d4436ab93843ffd2c56f51222c78e770f20d520`
- Open Brush source directory: `Assets/Scripts/Brushes`
- Godot port directory: `Scripts/Brushes`
- Catalog source: `Resources/BrushCatalog/brush_catalog.json`
- Registry source of truth: `Scripts/Brushes/BrushRuntimeRegistry.gd`

The active Godot catalog currently registers 97 live normal brushes. The
registry tests treat compatibility brushes separately and require every loaded
normal brush descriptor to have a runtime factory.

Four Open Brush experimental brushes in `Manifest_Experimental` are explicitly
classified as unsupported ParentBrush composites rather than being loaded as
normal live brushes:

- `CandyCane` from `CandyCane.cs` / `CandyCane_prefab`
- `HolidayTree` from `HolidayTree.cs` / `HolidayTree_prefab`
- `Braid3` from `PlaitBrush.cs` / `Plait_prefab`
- `Snowflake` from `SnowflakeBrush.cs` / `Snowflake_prefab`

They are tagged `experimental` and `broken` in the Open Brush assets and depend
on `ParentBrush.cs` child-stroke generation, which has not been ported.

## Runtime Brush Classes

| Godot class | Open Brush source | Catalog prefab families | Geometry / UV role | Finalization requirement | Current coverage | Current status |
| --- | --- | --- | --- | --- | --- | --- |
| `BaseBrushScript.gd` | `BaseBrushScript.cs` | Base for all runtime brushes. | Lifecycle, registration, descriptor plumbing, generic finalize entry points. | Must route live/replay/import strokes into Open Brush-equivalent solitary or batched finalization. | `BrushLifecycleParityTest.gd`, path-equivalence tests. | Not fully audited. |
| `GeometryBrush.gd` | `GeometryBrush.cs` | Base for most mesh-generating brushes. | Shared knot lifecycle, geometry pool writes, color conversion. | Batched finalization must copy/release geometry without re-entering subclass solitary behavior. | `BrushLifecycleParityTest.gd`, brush family tests. | Partially audited. |
| `QuadStripBrush.gd` | `QuadStripBrush.cs` | Base for `Line`, `LineWithWidth`, `UnitizedUV`, `DistanceUV`. | Flat strip topology, bend/shrink/break logic, double-sided backsides. | Solitary and batched paths must preserve strip breaks and weld single-sided strips like Open Brush. | `QuadStripParityTest.gd`, cafe Ink fixture replay. | Partially audited, active repair started. |
| `QuadStripBrushStretchUV.gd` | `QuadStripBrushStretchUV.cs` | `Line`, `LineWithWidth`. | Primary diffuse stretch UV; optional width stored in UV0.z. | Must flush pending UV/tangent data before final mesh export. | `QuadStripParityTest.gd`, metadata test. | Partially audited. |
| `QuadStripBrushDistanceUV.gd` | `QuadStripBrushDistanceUV.cs` | `DistanceUV`. | Primary diffuse distance UV plus opacity/fade behavior. | Must flush pending tangent requests in solitary and batched finalization. | `QuadStripParityTest.gd`, metadata test. | Partially audited. |
| `QuadStripUnitizedUVBrush.gd` | `QuadStripUnitizedUVBrush.cs` | `UnitizedUV`. | Unitized strip UV behavior. | Inherits quad-strip finalization and backside requirements. | `QuadStripParityTest.gd`, metadata test. | Partially audited. |
| `FlatGeometryBrush.gd` | `FlatGeometryBrush.cs` | `FlatDistance`, `FlatStretch`, `MidpointPlusOffset`. | Flat ribbon geometry, distance/stretch UV, optional offset in texcoord1. | Batched finalization trims short post-break tails like Open Brush. | `FlatGeometryBrushParityTest.gd`, cafe DuctTapeGeometry fixture replay. | Partially audited. |
| `ThickGeometryBrush.gd` | `ThickGeometryBrush.cs` | `ThickDistance`. | Thick ribbon geometry, distance/stretch UV atlas handling. | Uses geometry brush lifecycle/finalization. | `ThickGeometryBrushParityTest.gd`. | Partially audited. |
| `TubeBrush.gd` | `TubeBrush.cs` | `TubeDistanceUV`, `TubeDistanceUVSin`, `TubeStretchUV`, `Tube_Petal`, `Tube_Rain`, `Tube_Sparks`, `Tube_Spikes`, `Tube_Tapered`, `TubeBrush_Comet`, `Lofted`, `LoftedHueShift`. | Tube/ring geometry, cap options, distance/stretch UV, shape modifiers. | Uses Open Brush minimal-frame and tube finalization behavior. | `TubeBrushParityTest.gd`, cafe Sparks fixture replay. | Partially audited. |
| `BubbleWandBrush.gd` | `BubbleWandBrush.cs` | `TubeStretchUV` when durable name is `BubbleWand`. | Tube-derived bubble post-processing, UVW formula, original-position UV1 storage. | Bubble-specific solitary finalization must match Open Brush. | `BubbleWandBrushParityTest.gd`. | Partially audited. |
| `HullBrush.gd` | `HullBrush.cs` | `HullPrefab`, `HullPrefabPassthrough`, `HullPrefabSmooth`. | Convex hull geometry, faceted/interior/simplification modes. | Batched finalization must run Open Brush `SimplifyAtEnd` behavior. | `HullBrushParityTest.gd`, cafe MatteHull fixture replay. | Partially audited; native degenerate behavior still needs classification. |
| `ConcaveHullBrush.gd` | `ConcaveHullBrush.cs` | `ConcaveHullPrefab`. | Concave hull knot conversion and native polygon-face triangulation adaptation. | Uses hull-style generated mesh output; degenerate cases need explicit source comparison. | `ConcaveHullBrushParityTest.gd`. | Partially audited. |
| `SprayBrush.gd` | `SprayBrush.cs` | `Spray`. | Spray particle quads, salt wraparound, preview decay. | Particle finalization must preserve Open Brush lifecycle semantics. | `SprayBrushParityTest.gd`. | Partially audited; particle layout/seed audit remains. |
| `GeniusParticlesBrush.gd` | `GeniusParticlesBrush.cs` | `GeniusParticle`. | Genius particle quads, atlas UVs, randomized alpha/offset/roll, birth time in UV0.w. | Must run Open Brush particle finalization and hanging-particle removal behavior. | `GeniusParticlesBrushParityTest.gd`, cafe Stars fixture replay. | Partially audited; full particle parity remains. |
| `MidpointPlusLifetimeSprayBrush.gd` | `MidpointPlusLifetimeSprayBrush.cs` | `MiddpointPlusLifetimeGeomSpray`. | Midpoint lifetime particle geometry, UV0/UV1/tangent/color output, birth time in UV1.w. | Must preserve generated midpoint particles and avoid Genius-specific finalization behavior. | `MidpointSprayBrushParityTest.gd`. | Partially audited; full particle layout/seed audit remains. |
| `TetraBrush.gd` | `TetraBrush.cs` | No active normal catalog prefab currently routes here. | Tetra geometry and distance/unitized UV branches. | Uses direct generated topology and color truncation semantics. | `TetraBrushParityTest.gd`. | Partially audited; source class covered but not active live catalog route. |
| `SquareBrush.gd` | `SquareBrush.cs` | `SquareBrush_prefab`. | Square strip/ring geometry, caps, shared-ring continuation. | Must handle sharp-turn segment breaks and cap topology like Open Brush. | `SquareBrushParityTest.gd`. | Partially audited. |
| `Square3DPrintBrush.gd` | `Square3DPrintBrush.cs` | `Square3DPrintBrush`. | 3D-print square topology and parity-flip ring-face branch. | Must preserve flip-branch topology. | `Square3DPrintBrushParityTest.gd`. | Partially audited. |
| `SliceBrush.gd` | `SliceBrush.cs` | `Slice`. | Slice shared-quad geometry and UVW distance accumulation. | Uses direct geometry output with Open Brush frame direction. | `SliceBrushParityTest.gd`. | Partially audited. |
| `PrintableBrush.gd` | `PrintableBrush.cs` | No active normal catalog prefab currently routes here. | Printable strip/ring geometry, envelope behavior, caps. | Must handle shared-ring continuation and sharp-turn breaks like Open Brush. | `PrintableBrushParityTest.gd`. | Partially audited; source class covered but not active live catalog route. |

## Compatibility And Layout Classes

These classes are not normal live-painting brush registrations. They are either
compatibility-brush support or fake layout providers and must remain explicitly
classified instead of silently entering normal runtime generation.

| Godot class | Open Brush source | Catalog prefab families | Role | Current coverage | Current status |
| --- | --- | --- | --- | --- | --- |
| `BlocksBrushScript.gd` | `BlocksBrushScript.cs` | `BlocksFakeBrush` compatibility brushes: `BlocksBasic`, `BlocksGem`, `BlocksGlass`. | Fake/no-op layout brush for block compatibility data. | `BlocksBrushParityTest.gd`, `LayoutBrushParityTest.gd`. | Partially audited as compatibility/layout behavior. |
| `PbrBrushScript.gd` | `PbrBrushScript.cs` | `PbrFakeBrush` compatibility brushes: `PbrTemplate`, `PbrTransparentTemplate`. | Fake/no-op material layout provider. | `LayoutBrushParityTest.gd`. | Audited as non-mesh layout provider. |
| `EnvironmentBrushScript.gd` | `EnvironmentBrushScript.cs` | `EnvironmentFakeBrush`, `EnvironmentLightmapFakeBrush` compatibility brushes. | Fake/no-op environment layout provider. | `LayoutBrushParityTest.gd`. | Audited as non-mesh layout provider. |
| `SvgBrushScript.gd` | `SvgBrushScript.cs` | `SvgFakeBrush` compatibility brush: `SvgTemplate`. | Fake/no-op SVG layout provider. | `LayoutBrushParityTest.gd`. | Audited as non-mesh layout provider. |

## Runtime Registry Prefab Families

The normal live registry currently has factories for these prefab families:

| Prefab family | Runtime class | Active normal brush count | Durable-name examples |
| --- | --- | --- | --- |
| `Line` | `QuadStripBrushStretchUV` | 22 | `Ink`, `Light`, `VelvetInk`, `WetPaint` |
| `LineWithWidth` | `QuadStripBrushStretchUV` | 1 | `Hypercolor` |
| `DistanceUV` | `QuadStripBrushDistanceUV` | 19 | `DuctTape`, `Marker`, `Paper`, `Rainbow` |
| `UnitizedUV` | `QuadStripUnitizedUVBrush` | 1 | `Wireframe` |
| `FlatDistance` | `FlatGeometryBrush` | 1 | `DuctTapeGeometry` |
| `FlatStretch` | `FlatGeometryBrush` | 2 | `InkGeometry`, `TaperedMarker_Flat` |
| `MidpointPlusOffset` | `FlatGeometryBrush` | 3 | `DoubleTaperedFlat`, `DoubleTaperedMarker`, `Electricity` |
| `ThickDistance` | `ThickGeometryBrush` | 1 | `ThickGeometry` |
| `TubeDistanceUV` | `TubeBrush` | 14 | `ChromaticWave`, `Disco`, `FacetedTube`, `Wire` |
| `TubeDistanceUVSin` | `TubeBrush` | 1 | `Muscle` |
| `TubeStretchUV` | `TubeBrush` or `BubbleWandBrush` | 2 | `BubbleWand`, `MylarTube` |
| `Tube_Petal`, `Tube_Rain`, `Tube_Sparks`, `Tube_Spikes`, `Tube_Tapered` | `TubeBrush` | 5 | `Petal`, `Rain`, `Sparks`, `Spikes`, `TaperedWire` |
| `TubeBrush_Comet` | `TubeBrush` | 1 | `Comet` |
| `Lofted`, `LoftedHueShift` | `TubeBrush` | 2 | `Lofted`, `Lofted (Hue Shift)` |
| `HullPrefab` | `HullBrush` | 4 | `DiamondHull`, `MatteHull`, `ShinyHull`, `UnlitHull` |
| `HullPrefabPassthrough` | `HullBrush` | 1 | `PassthroughHull` |
| `HullPrefabSmooth` | `HullBrush` | 1 | `SmoothHull` |
| `ConcaveHullPrefab` | `ConcaveHullBrush` | 1 | `ConcaveHull` |
| `Spray` | `SprayBrush` | 4 | `CoarseBristles`, `DotMarker`, `Leaves2`, `Splatter` |
| `GeniusParticle` | `GeniusParticlesBrush` | 7 | `Bubbles`, `Smoke`, `Snow`, `Stars` |
| `MiddpointPlusLifetimeGeomSpray` | `MidpointPlusLifetimeSprayBrush` | 3 | `DanceFloor`, `HyperGrid`, `WaveformParticles` |
| `SquareBrush_prefab` | `SquareBrush` | 1 | `SquarePaper` |
| `Square3DPrintBrush` | `Square3DPrintBrush` | 1 | `3D Printing Brush` |
| `Slice` | `SliceBrush` | 1 | `Slice` |

## Source-Only Open Brush Classes

`ParentBrush.cs` is the abstract Open Brush source helper for the unsupported
experimental composite brushes listed above. There is no Godot runtime class for
it yet, and no normal live brush should silently route through substitute
geometry in its place.

## Known Inventory Gaps

- This inventory is not a claim that every class is fully audited. Most mesh
  classes remain marked partially audited until line-by-line source comparison
  and Open Brush reference mesh fixtures prove their behavior.
- The four experimental ParentBrush composites are documented in
  `Resources/BrushCatalog/brush_catalog.json` under `unsupported_brushes` and
  skipped by policy while `ParentBrush` child-stroke generation remains unported.
- `TetraBrush.gd` and `PrintableBrush.gd` have source-derived tests, but no
  active normal catalog prefab currently routes to them through
  `BrushRuntimeRegistry.gd`.
