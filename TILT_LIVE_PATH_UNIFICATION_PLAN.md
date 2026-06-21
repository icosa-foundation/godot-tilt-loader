# Tilt Loading and Live Stroke Path Unification Plan

## Goal

Tilt file loading and live XR stroke drawing should use the same brush runtime wherever they are rendering the same Open Brush stroke data. Imported `.tilt` strokes and live-painted strokes should not have separate brush selection, geometry generation, UV generation, mesh export, or material assignment logic unless there is a deliberately documented compatibility-only exception.

The intended ownership boundary is:

- `open-brush-stroke-gen-only` owns `.tilt` reading, `.tilt` scene importing, live stroke generation, and runtime brush mesh generation.
- `icosa-godot-addon` owns Open Brush GLTF/GLB import support, brush material assets, environment helpers, and gallery/editor integration.
- `icosa-godot-addon` must not depend on `res://Scripts/...` from stroke-gen.
- Stroke-gen may depend on Icosa material/environment helpers and assets.

## Current State

Already fixed:

- `.tilt` reader and `.tilt` scene importer have moved from Icosa into `addons/open_brush_stroke_integration`.
- Icosa no longer registers a `.tilt` scene importer.
- Icosa no longer references stroke-gen scripts.
- `MeshData.to_mesh_arrays()` is now the shared runtime mesh export path.
- Live strokes now resolve Icosa/Open Brush materials through `BrushMaterialResolver`.
- `MeshData` now preserves wider UV data into Godot custom channels instead of dropping `uv0.z/w`, `uv1`, and `uv2`.

Remaining problems:

- `OpenBrushTiltSceneImporter` still has duplicated brush selection/factory logic.
- `OpenBrushTiltSceneImporter` still contains bespoke particle and fallback ribbon tessellators.
- `.tilt` import material assignment is not fully centralized through `BrushMaterialResolver`.
- Normal brush import failures can still be hidden by fallback geometry paths.

## Architectural Rule

For every non-compatibility brush:

1. Load the brush descriptor from the manifest/catalog.
2. Instantiate the brush through `BrushRuntimeRegistry`.
3. Replay `.tilt` control points through the same runtime brush API used by live drawing.
4. Export through `MeshData.to_mesh_arrays()`.
5. Assign material through `BrushMaterialResolver`.

If a normal brush cannot instantiate or generate geometry, that is a bug and should fail loudly with a specific brush name, GUID, prefab, and stroke index.

Compatibility brushes are a separate class and should be handled explicitly. They should not accidentally enter the live/runtime brush path.

## Work Plan

### 1. Add Explicit Import Classifications

Create a small import decision layer in stroke-gen, probably near `BrushRuntimeRegistry`, that answers:

- Is this brush in `manifest.CompatibilityBrushes`?
- Is this brush a normal runtime brush?
- Is this brush missing from the manifest/catalog?

Expected result:

- Normal brushes must use runtime brush generation.
- Compatibility brushes must go through an explicit compatibility path or produce a clear unsupported warning.
- Unknown brushes must produce a clear import warning or error, not silently render with fallback geometry.

Implementation notes:

- Reuse `BrushRuntimeRegistry.is_compatibility_brush()`.
- Avoid duplicating GUID normalization logic.
- Include stroke index and brush GUID in import diagnostics.

### 2. Replace Importer Brush Factory Logic

Remove duplicated prefab-family selection from `OpenBrushTiltSceneImporter`.

Current duplicated logic includes:

- `_uses_runtime_flat_brush()`
- `_uses_runtime_quad_strip_brush()`
- `_uses_runtime_hull_brush()`
- direct construction of `_FlatGeometryBrush`, `_QuadStripBrushDistanceUV`, `_QuadStripBrushStretchUV`, `_HullBrush`, `_ConcaveHullBrush`
- local descriptor field application

Replacement:

- Load/register manifests once at importer startup or per import.
- Resolve each stroke's `brush_guid` to a `BrushDescriptor`.
- Call `BrushRuntimeRegistry.register_supported_brushes(manifest)`.
- Instantiate via `BrushRuntimeRegistry.create_brush_for_descriptor(desc)` or `BaseBrushScript.create_brush()` using the same route as live drawing.

Expected result:

- New prefab mappings are added in exactly one place.
- `.tilt` import and live drawing cannot drift on brush class selection.

### 3. Add a Single Stroke Replay Helper

Create a helper that can build a runtime brush from serialized stroke data:

```gdscript
func build_mesh_data_from_tilt_stroke(
    desc: BrushDescriptor,
    stroke: Dictionary,
    scene_scale: float
) -> MeshData
```

Responsibilities:

- Convert first control point into the initial `TrTransform`.
- Set color, size, random seed, brush scale, and loading mode.
- Feed remaining control points through `update_position_ls()`.
- Call `apply_changes_to_visuals()`.
- Call `finalize_solitary_brush()`.
- Return `brush.mesh_data`.

Important behavior:

- Use the same coordinate assumptions currently used by the tilt reader.
- Preserve stroke seed.
- Preserve brush scale and scene scale.
- Do not use fallback geometry if runtime generation returns no mesh for a normal brush; report a bug-level diagnostic.

### 4. Remove Broad Fallback Tessellation

Delete or quarantine these production paths from `OpenBrushTiltSceneImporter`:

- `_tessellate_particle_strokes()`
- `_tessellate_strokes()`
- `PARTICLE_BRUSHES`
- `BRUSH_ATLAS_V`
- `BRUSH_TILE_RATE`
- fallback ribbon subdivision/tessellation helpers

Temporary option:

- Move them into a clearly named diagnostic-only file if they are still useful for comparison.
- Do not call them from the normal `.tilt` import path.

Expected result:

- Normal imported strokes either use the real runtime brush or fail loudly.
- No hidden geometry/UV divergence remains for normal brushes.

### 5. Centralize Material Assignment

Extend `BrushMaterialResolver` so both live strokes and `.tilt` imports can resolve materials through one API:

```gdscript
static func find_material_for_descriptor(desc: BrushDescriptor) -> Material
static func find_material_for_guid(guid: String) -> Material
static func find_material_for_name(durable_name: String) -> Material
```

Then update `OpenBrushTiltSceneImporter` to use `BrushMaterialResolver` rather than calling Icosa directly.

Expected result:

- Live and imported runtime meshes use identical material lookup rules.
- Fallback material behavior is centralized and testable.

### 6. Merge Runtime Meshes by Brush Safely

The current importer groups strokes by brush name and merges mesh data. Keep batching, but perform it after runtime generation:

- Generate `MeshData` per stroke through runtime brush replay.
- Append all compatible `MeshData` instances with the shared append helper.
- Export once through `MeshData.to_mesh_arrays()`.
- Assign one material through `BrushMaterialResolver`.

Rules:

- Only merge strokes with the same brush descriptor/material.
- Keep hull ordering behavior explicit if it is genuinely required.
- If hull strokes need source-order preservation, document that as a rendering-order rule, not a fallback path.

### 7. Make Failures Loud and Searchable

Add a unique import log prefix, for example:

`TILT_RUNTIME_IMPORT`

For every failure, include:

- brush name
- brush GUID
- prefab name
- stroke index
- reason

Examples:

- `TILT_RUNTIME_IMPORT ERROR normal brush failed factory brush=Ink guid=... prefab=... stroke=42`
- `TILT_RUNTIME_IMPORT WARN compatibility brush skipped brush=... guid=... stroke=42`

Do not log only to the Godot console for runtime debugging. For scene/play debugging, write to `user://debug.log` or `user://xr_debug.log` as appropriate.

### 8. Tests

Add or update tests so the intended architecture is enforced.

Required tests:

- Importer uses `BrushRuntimeRegistry` for normal brushes.
- Importer rejects/fails loudly for normal brush factory failures.
- Compatibility brushes do not enter the normal runtime path.
- `MeshData.to_mesh_arrays()` preserves UV/custom channels.
- Material resolver returns the same material for a descriptor and for the corresponding imported brush name/GUID.
- A representative `.tilt` file imports without using fallback tessellation.

Useful representative brush coverage:

- `Ink`
- `Dots` or another particle brush
- `BubbleWand`
- a tube brush using `uv0.z` radius
- a hull brush
- `TubeToonInverted`

### 9. Remove Dead Code

After tests pass:

- Remove unused fallback constants and functions.
- Remove duplicated descriptor lookup helpers if replaced by shared catalog access.
- Remove duplicated material lookup calls in the importer.
- Verify `rg "res://Scripts" C:\Users\andyb\Documents\icosa-godot-addon` stays empty.
- Verify `rg "open_brush_tilt_reader|open_brush_scene|IcosaOpenBrushScene|IcosaOpenBrushTiltReader" C:\Users\andyb\Documents\icosa-godot-addon` stays empty.

## Acceptance Criteria

The cleanup is done when:

- Icosa imports GLTF/GLB and contains no `.tilt` reader/importer.
- Stroke-gen imports `.tilt`.
- Stroke-gen live drawing and `.tilt` import share:
  - brush descriptor resolution
  - brush factory selection
  - runtime geometry generation
  - `MeshData` export
  - material resolution
- No production `.tilt` import path uses bespoke fallback tessellation for normal brushes.
- Any unsupported/compatibility brush behavior is explicit and tested.
- Existing focused tests pass, including:
  - `TiltReaderProbe.gd`
  - `TiltSanityProbe.gd`
  - `MeshDataArrayExportParityTest.gd`
  - `BrushMaterialResolverParityTest.gd`
  - brush parity tests for flat, quad strip, tube, particle, and hull brushes.

## Risks

- Removing fallback tessellation may expose real gaps in runtime brush behavior that were previously hidden.
- Runtime replay may change imported `.tilt` batching/order behavior, especially for hull brushes.
- Some imported Tilt files may contain compatibility brushes or obsolete GUIDs; those need explicit policy instead of implicit fallback.
- Material/UV parity can still be affected by shader expectations around `CUSTOM0`, `CUSTOM1`, and `UV2`.

## Recommended Sequence

1. Centralize material assignment through `BrushMaterialResolver`.
2. Add the stroke replay helper and test it on a small set of descriptors.
3. Replace importer factory logic with `BrushRuntimeRegistry`.
4. Switch normal `.tilt` import to runtime replay only.
5. Add diagnostics and tests proving no fallback path was used.
6. Delete or quarantine fallback tessellators.
7. Run full focused parity/import tests.
