# Open Brush reference mesh fixtures

This directory contains compact, normalized fixtures generated from the
authoritative Open Brush brush-fixture corpus. The Godot parity test replays the
exact source stroke through the GDScript runtime and compares its output with
Open Brush's finalized live mesh before `BrushBaker`.

The live mesh is the reference for realtime drawing and `.tilt` playback. GLB
files and post-`BrushBaker` meshes belong in separate end-to-end export/import
tests and are intentionally excluded here.

## Generate fixtures

Run the converter from the project root. Supply a checkout of Open Brush's
`Support/BrushFixtures` directory and the full source commit hash:

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tools/OpenBrushMeshFixtures/ConvertOpenBrushMeshFixtures.gd -- `
  --source-dir=<path-to-Open-Brush>/Support/BrushFixtures `
  --source-commit=<40-character-commit-hash>
```

Use `--brushes=Ink,DuctTapeGeometry` to convert a subset. Add `--check` to verify
that existing normalized fixtures are byte-for-byte current without rewriting
them.

The converter rejects unknown raw schemas, non-identity stroke transforms, and
inconsistent mesh data. It records the source commit, raw filename, and SHA-256
digest in every output file.

## Run the comparator

```powershell
godot --headless --xr-mode off --path . `
  --script res://Tests/GDScript/OpenBrushReferenceMeshFixtureTest.gd -- `
  --require-open-brush-reference-fixtures
```

## Normalized schema

The current schema is `open-brush-reference-mesh-v2`. Each file contains:

1. Source provenance and the fixed shader time used by Open Brush.
2. The exact stroke input in Unity coordinates and Open Brush units.
3. Vertex-layout semantics and full-width live-mesh attributes.
4. Live-mesh indices and bounds.
5. An explicit description of the comparison coordinate boundary.

The comparator converts the source input to Godot handedness for replay. At the
comparison boundary it converts mesh metric values from Open Brush units to
metres, reflects Unity Z, and adjusts tangent handedness. Triangle winding is
preserved because Unity and Godot both use
clockwise front faces. Runtime brush code remains in its normal Godot/Open Brush
coordinate conventions.

Topology is exact. Positions, normals, colors, and UVs use a `0.00001`
tolerance. Normalized tangents use `0.00005`; the pilot established that tangent
normalization can amplify otherwise sub-micrometre vertex differences to
`0.00003678` without a topology or source-channel mismatch.

## Fixture rules

1. Expected mesh data must come from Open Brush C# mesh generation, never from
   the Godot implementation.
2. Preserve exact topology and full attribute widths, including shader-facing
   particle records.
3. Keep the source revision and raw-file digest intact so data is reproducible.
4. Do not weaken a comparison to hide a mismatch; classify or repair the
   underlying conversion or runtime difference.
5. Keep generated GLBs and post-baker data out of this live-mesh suite.

The comparator retains support for legacy `open-brush-reference-mesh-v1`
fixtures while the existing corpus is migrated.
