# Open Brush Source Baseline

This file records the source snapshots used for mesh parity work.

## Immediate Conversion Oracle

- Repository: `C:/Users/andyb/Documents/open-brush-stroke-gen-only`
- Branch/ref: `origin/feature/godot`
- Commit: `737f46875a97bbb3fc139929f3c029370777d5fa`
- C# brush source directory: `Assets/Scripts/Brushes`
- GDScript brush source directory: `Scripts/Brushes`

The Godot .NET C# port is the immediate oracle for C# to GDScript conversion
parity in this repository. When the GDScript port and this C# port disagree,
assume the GDScript port is wrong unless the C# port is proven to diverge from
upstream Open Brush intentionally or because of a compile-time integration
condition.

## Upstream Open Brush Reference

- Historical upstream checkout path: `C:/Users/andyb/Documents/open-brush-fast`
- Historical reference commit recorded by previous audits:
  `3d4436ab93843ffd2c56f51222c78e770f20d520`
- Current rule: do not use or modify that checkout for parity exporter work.
- Exporter worktree: `C:/Users/andyb/Documents/open-brush-reference-exporter-worktree`

Use upstream Open Brush C# to resolve intended behavior. Use the separate
exporter worktree for fixture export work so unrelated Open Brush development
does not mix with this repo.

## Brush Source Files

The active runtime brush comparison set is:

- `BaseBrushScript.cs` -> `BaseBrushScript.gd`
- `BlocksBrushScript.cs` -> `BlocksBrushScript.gd`
- `BubbleWandBrush.cs` -> `BubbleWandBrush.gd`
- `ConcaveHullBrush.cs` -> `ConcaveHullBrush.gd`
- `EnvironmentBrushScript.cs` -> `EnvironmentBrushScript.gd`
- `FlatGeometryBrush.cs` -> `FlatGeometryBrush.gd`
- `GeniusParticlesBrush.cs` -> `GeniusParticlesBrush.gd`
- `GeometryBrush.cs` -> `GeometryBrush.gd`
- `GeometryPool.cs` -> `GeometryPool.gd`
- `HullBrush.cs` -> `HullBrush.gd`
- `MidpointPlusLifetimeSprayBrush.cs` -> `MidpointPlusLifetimeSprayBrush.gd`
- `PbrBrushScript.cs` -> `PbrBrushScript.gd`
- `PrintableBrush.cs` -> `PrintableBrush.gd`
- `QuadStripBrush.cs` -> `QuadStripBrush.gd`
- `QuadStripBrushDistanceUV.cs` -> `QuadStripBrushDistanceUV.gd`
- `QuadStripBrushStretchUV.cs` -> `QuadStripBrushStretchUV.gd`
- `QuadStripUnitizedUVBrush.cs` -> `QuadStripUnitizedUVBrush.gd`
- `SliceBrush.cs` -> `SliceBrush.gd`
- `SprayBrush.cs` -> `SprayBrush.gd`
- `Square3DPrintBrush.cs` -> `Square3DPrintBrush.gd`
- `SquareBrush.cs` -> `SquareBrush.gd`
- `SvgBrushScript.cs` -> `SvgBrushScript.gd`
- `TetraBrush.cs` -> `TetraBrush.gd`
- `ThickGeometryBrush.cs` -> `ThickGeometryBrush.gd`
- `TubeBrush.cs` -> `TubeBrush.gd`

Shared runtime and integration files that affect parity include:

- `BrushDescriptor.cs` -> `BrushDescriptor.gd`
- `MasterBrush.cs` -> `MasterBrush.gd`
- `BrushRuntimeRegistry.gd`
- `BrushStrokeReplay.gd`
- `BrushMaterialResolver.gd`
- `MeshData.gd`

## Fixture Baseline

Open Brush reference mesh fixture exports belong under
`Resources/Fixtures/OpenBrushReferenceMeshes/` and must identify the source C#
commit that generated them. Until authoritative exported mesh JSON fixtures are
checked in, the existing Godot fixture tests prove runtime stability but not
full Open Brush vertex-for-vertex parity.
