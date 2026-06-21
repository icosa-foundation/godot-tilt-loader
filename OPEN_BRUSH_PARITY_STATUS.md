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
| `GeometryBrush.gd` | `GeometryBrush.cs` | Partially audited, active repair started | Shared `SetVert` now uses Open Brush `Color32` truncation for RGB and alpha. Lifecycle/finalization still needs full audit before child classes can be considered complete. |
| `QuadStripBrush.gd` | `QuadStripBrush.cs` | Partially audited, active repair started | Sharp-bend shrink/break behavior, double-sided backside consistency, backface color/hue-shift behavior, append-time `Color32` truncation, and single-sided batched weld finalization have been ported. Full line-by-line audit still required. |
| `QuadStripBrushStretchUV.gd` | `QuadStripBrushStretchUV.cs` | Partially tested | UV tests exist. Needs line-by-line audit after base `QuadStripBrush` settles. |
| `QuadStripBrushDistanceUV.gd` | `QuadStripBrushDistanceUV.cs` | Partially audited, active repair started | Backface UV/color/tangent mirroring has been ported and tested. Needs full line-by-line audit. |
| `QuadStripUnitizedUVBrush.gd` | `QuadStripUnitizedUVBrush.cs` | Partially audited, active repair started | Backface UV/tangent mirroring has been ported and tested. Needs full line-by-line audit. |
| `FlatGeometryBrush.gd` | `FlatGeometryBrush.cs` | Partially tested | Existing parity tests cover selected behavior. Needs full branch audit. |
| `ThickGeometryBrush.gd` | `ThickGeometryBrush.cs` | Partially tested | Existing parity tests cover selected behavior. Needs full branch audit. |
| `TubeBrush.gd` | `TubeBrush.cs` | Partially tested | Existing parity tests cover selected behavior. Needs full branch audit. |
| `HullBrush.gd` | `HullBrush.cs` | Partially tested | Native hull backend and degenerate cases need explicit parity review. |
| `ConcaveHullBrush.gd` | `ConcaveHullBrush.cs` | Partially tested | Known degenerate hull behavior needs explicit classification. |
| `SprayBrush.gd` | `SprayBrush.cs` | Partially tested | Particle layout and seed behavior need full audit. |
| `GeniusParticlesBrush.gd` | `GeniusParticlesBrush.cs` | Partially tested | Particle layout and seed behavior need full audit. |
| `BubbleWandBrush.gd` | `BubbleWandBrush.cs` | Partially tested | Needs full branch audit. |
| `BlocksBrushScript.gd` | `BlocksBrushScript.cs` | Partially tested | Needs full branch audit. |
| `TetraBrush.gd` | `TetraBrush.cs` | Partially tested | Needs full branch audit. |
| `SquareBrush.gd` | `SquareBrush.cs` | Partially tested | Needs full branch audit. |
| `Square3DPrintBrush.gd` | `Square3DPrintBrush.cs` | Partially tested | Needs full branch audit. |
| `SliceBrush.gd` | `SliceBrush.cs` | Partially tested | Needs full branch audit. |
| `PrintableBrush.gd` | `PrintableBrush.cs` | Partially tested | Needs full branch audit. |
| `PbrBrushScript.gd` | `PbrBrushScript.cs` | Not fully audited | Material/export interaction needs separation from mesh parity. |
| `EnvironmentBrushScript.gd` | `EnvironmentBrushScript.cs` | Not fully audited | Need confirm whether this participates in runtime mesh generation. |
| `SvgBrushScript.gd` | `SvgBrushScript.cs` | Not fully audited | Need confirm whether this participates in runtime mesh generation. |
| `MidpointPlusLifetimeSprayBrush.gd` | `MidpointPlusLifetimeSprayBrush.cs` | Not fully audited | Needs particle path and lifetime data audit. |

## Missing Godot Runtime Equivalents To Investigate

Open Brush source files present without obvious Godot class equivalents:

- `CandyCane.cs`
- `HolidayTree.cs`
- `ParentBrush.cs`
- `PlaitBrush.cs`
- `SnowflakeBrush.cs`

These may be unsupported, compatibility-only, or mapped through another runtime class. Each needs an explicit catalog/registry decision.

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

Focused tests added/updated:

- `Tests/GDScript/QuadStripParityTest.gd`
  - checks sharp-bend shrink behavior through the brush lifecycle,
  - checks intentional strip-break behavior on double-back turns,
  - checks double-sided backfaces mirror fused front quads,
  - checks batched finalization welds connected single-sided quad strips to shared-edge topology,
  - checks double-sided append-time backface color pattern and hue shifting,
  - checks double-sided DistanceUV backface UV/color/tangent channel mirroring,
  - checks double-sided UnitizedUV backface UV/tangent channel mirroring,
  - checks DistanceUV fade opacity is quantized to Unity `Color32` byte alpha,
  - checks quad-strip append-time colors, opacity, previous-edge carryover, and hue-shifted backfaces use Unity `Color32` byte truncation.
- `Tests/GDScript/FlatGeometryBrushParityTest.gd`
  - checks generated flat geometry vertex colors use Unity `Color32` byte truncation for RGB and alpha.
- `Tests/GDScript/ThickGeometryBrushParityTest.gd`
  - checks generated thick geometry vertex colors use Unity `Color32` byte truncation for RGB and alpha.
- `Tests/GDScript/BrushRuntimeRegistryMetadataTest.gd`
  - walks the real manifest/catalog and verifies all normal `Line`, `LineWithWidth`, `UnitizedUV`, and `DistanceUV` prefabs route to the repaired quad-strip runtime classes.
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
