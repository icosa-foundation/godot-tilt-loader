# Native Hull Polygon Face Plan

## Objective

Replace the current GDScript-side `HullBrush` triangle coalescing prototype with native convex hull output that returns Unity-compatible polygon faces for coplanar hull surfaces.

The immediate motivation is `HullBrush` parity for Open Brush `.tilt` files. Unity uses MIConvexHull, which is QuickHull-based but can expose hull faces as polygons. Our native Godot backend currently exposes triangular facets, so `CreateFacetedGeometry` treats each triangle as a separate visual face and produces overly faceted/lumpy hull surfaces.

## Current State

- `Scripts/Util/ConvexHullUtil.gd` calls the native `NativeConvexHullUtil` when available.
- The native backend returns hull points plus triangle faces.
- `Scripts/Brushes/HullBrush.gd` currently contains `merge_similar_faceted_faces(...)`, which groups similar triangle normals and reconstructs larger faces before `create_faceted_geometry(...)`.
- That GDScript merge is a temporary compatibility bridge. It is heuristic, import-time GDScript work, and not the desired long-term hull API contract.

## Desired Backend Contract

The native hull backend should return:

- `ok: bool`
- `points: Array[Vector3]`
- `faces: Array`

Each face should contain:

- `indices`: ordered polygon vertex indices, length >= 3
- `normal`: outward face normal

Faces may be triangles, quads, or larger n-gons. Coplanar adjacent facets should be represented as one polygon face when they belong to the same hull plane.

## Proposed Approach

1. Fetch MIConvexHull source at the commit used by the Unity project.
   - The Unity `main` branch notes `MIConvexHull35.dll` was built from commit `62aa861`.
   - Use it as a reference for QuickHull face representation, adjacency, tolerance, and output behavior.

2. Inspect the existing native hull implementation.
   - Identify the internal triangle/facet data structures.
   - Confirm whether facet adjacency is already available.
   - Confirm how tolerance is applied to point/plane classification.

3. Add native polygon-face finalization.
   - Group facets by geometric plane using both normal and plane offset tolerance.
   - Prefer adjacency-aware grouping, not global normal-only grouping.
   - Build each merged face from the boundary edges of the grouped facets.
   - Order boundary vertices consistently around the face normal.
   - Preserve outward winding.

4. Return polygon faces from native code.
   - Keep the Godot-facing dictionary shape unchanged.
   - Allow `HullBrush.create_faceted_geometry(...)` to fan-triangulate polygon faces like Unity does.
   - Avoid introducing viewer/cafe-specific logic.

5. Remove the GDScript merge prototype.
   - Delete or bypass `merge_similar_faceted_faces(...)` once native output is polygonal.
   - Keep `m_TrackInterior` behavior because that mirrors Unity and is independent of polygon-face output.

## Verification Criteria

### Native Hull Unit/Parity Checks

- Existing native hull parity tests pass:
  - `Tests/GDScript/NativeHullParitySuite.gd`
  - `Tests/GDScript/HullBrushParityTest.gd`
- Add or update a test where many coplanar points form a box/slab:
  - Expected hull has six polygon faces, not many triangle faces.
  - Large planar sides return ordered faces with four or more vertices where appropriate.
  - Face normals point outward.
  - Face winding renders correctly with backface culling enabled.

### HullBrush Geometry Checks

- For `HullBrush` with `m_Faceted = true`, flat slab/cube-like inputs produce:
  - one visual normal per planar hull side
  - no GDScript face merge required
  - mesh triangle count equal to fan triangulation of returned polygon faces
- For `HullBrush` with `m_Faceted = false`, smooth path remains unchanged except for consuming the same polygon face data.
- `m_TrackInterior` still reduces repeated hull input over time and does not remove hull boundary vertices incorrectly.

### Cafe Scene Evidence

- Force a fresh import of `Temp/TiltEvidence/brush_cafe_experimental.tilt`.
- Render `Scenes/TiltEvidenceViewer.tscn`.
- Visual result must show:
  - checker floor visible
  - checker tiles materially closer to the embedded thumbnail than the pre-fix missing/lumpy floor
  - no regression in major cafe objects: sign, umbrellas, table, chairs, surrounding hull base
- Record the output screenshot path in the final status.

### Regression Checks

- Render at least one non-cafe `.tilt` file containing Hull brushes, if available.
- Confirm unsupported/native-missing platforms still use the existing GDScript fallback without crashing.
- Confirm no Godot processes remain running after automated verification.

### Cleanup Criteria

- GDScript `merge_similar_faceted_faces(...)` is removed or no longer called.
- No ignored `addons/icosa` shader edits are required for the geometry fix.
- `git status --short` clearly separates intended changes from unrelated local docs or project settings drift.

## Non-Goals

- Do not port the full MIConvexHull generic N-dimensional API.
- Do not add cafe-specific stroke IDs, brush-name exceptions, or scene-specific geometry rules.
- Do not solve every Open Brush material/shader fidelity issue as part of this hull topology task.
- Do not require Git submodules for this work.

