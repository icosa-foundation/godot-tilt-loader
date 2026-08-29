# Open Brush Hull Cross-Platform CI Plan

## Goal

Build, test, package, and publish the `open_brush_hull` GDExtension with GitHub Actions for:

- Windows
- Linux
- macOS
- Android
- iOS
- Web

The deliverable is one versioned package that can be copied into
`native/open_brush_hull/` and loaded through a single
`open_brush_hull.gdextension` file. Users should not need a compiler or local
copies of `godot-cpp` and QuickHull.

This plan does not cover visionOS, BSD, consoles, or uncommon Linux
architectures for which Godot does not publish standard binaries. Those can be
added separately without changing the package design.

## Current State and Required Changes

The current native build is Windows-specific in several ways:

- It downloads dependencies only through PowerShell.
- `SConstruct` assumes ignored checkouts at `.deps/godot-cpp` and
  `.deps/quickhull`.
- The generated API file comes from the locally installed Godot executable.
- `open_brush_hull.gdextension` lists only Windows x86_64 debug and release
  DLLs.
- Output files all share one `bin/` directory instead of predictable
  per-platform directories.

The C++ wrapper itself uses portable C++ and has no Windows API dependency.
QuickHull is compiled from source into the extension, so the main work is build
configuration, toolchains, packaging, and validation rather than a rewrite of
the hull implementation.

## Supported Build Matrix

Use single-precision Godot builds because this project uses the normal
single-precision engine. Produce both `template_debug` and `template_release`
for every row.

| Platform | Architectures | GitHub runner | Output |
|---|---|---|---|
| Windows | `x86_64`, `x86_32`, `arm64` | `windows-latest` | `.dll` |
| Linux | `x86_64`, `x86_32`, `arm64`, `arm32` | Ubuntu x64/Arm runners, with multilib for x86_32 | `.so` |
| macOS | `universal` (`x86_64` + `arm64`) | `macos-latest` | universal `.dylib` |
| Android | `x86_64`, `x86_32`, `arm64`, `arm32` | `ubuntu-22.04` with Android NDK | `.so` |
| iOS | `arm64` | `macos-latest` with Xcode | `.dylib` or framework form required by the pinned `godot-cpp` version |
| Web | `wasm32`, non-threaded | `ubuntu-22.04` with pinned Emscripten | `.wasm` |

This follows the full-build matrix in the official `godot-cpp-template`.
If an architecture is removed from or added to that upstream matrix, review it
deliberately rather than allowing a floating dependency update to silently
change this project's support.

## Phase 1: Make the Build Reproducible

1. Define dependency and tool versions in one tracked file:
   - Godot version used for tests and export templates.
   - `godot-cpp` commit.
   - QuickHull repository and commit.
   - Emscripten version.
   - Android NDK version.
   - Minimum Xcode/macOS runner expectation.
2. Keep the currently validated QuickHull commit
   `4ef66c68950cb4db11d3b75bfe4034d807485ad0` unless a source or license review
   requires a change.
3. Replace CI dependency cloning hidden inside the Windows PowerShell script
   with either:
   - git submodules pinned to exact commits; or
   - a cross-platform bootstrap script that verifies the fetched commit.
4. Do not use a developer machine's `--dump-extension-api` output in CI.
   Select one compatibility strategy and document it:
   - preferably build with a `godot-cpp` version capable of targeting
     `api_version=4.3`, matching `compatibility_minimum = "4.3"`; or
   - pin and check in the Godot 4.3 `extension_api.json`.
5. Test the resulting extension with the current project Godot version as well
   as the minimum supported version. Building against a newer API while merely
   declaring a 4.3 minimum is not sufficient.
6. Retain `build_native_hull.ps1` as a Windows developer convenience, but make
   it call the same SCons entry point and version definitions used by CI.

## Phase 2: Refactor SCons for Every Target

1. Base the build structure on the pinned `godot-cpp-template` `SConstruct`
   rather than adding platform branches one at a time.
2. Accept normal `godot-cpp` SCons arguments:
   `platform`, `arch`, `target`, `precision`, and platform toolchain options.
3. Pass a configured environment into `godot-cpp/SConstruct`, so Android,
   Apple, Web, and cross-compilation settings are preserved.
4. Compile these sources into every target:
   - `src/register_types.cpp`
   - `src/native_convex_hull_util.cpp`
   - pinned QuickHull source
5. Write binaries to platform directories:

   ```text
   native/open_brush_hull/bin/
     windows/
     linux/
     macos/
     android/
     ios/
     web/
   ```

6. Derive filenames from the actual `godot-cpp` suffix and shared-library
   prefix/suffix. Do not hand-construct filenames independently in the
   workflow.
7. Remove build-only files such as Windows `.lib`, `.exp`, and `.pdb` from the
   distributable package unless symbols are intentionally published as a
   separate artifact.
8. Confirm that QuickHull compiles cleanly with MSVC, Clang, GCC, Android NDK
   Clang, Apple Clang, and Emscripten. Fix warnings or portability defects in
   source under this project's control; do not patch fetched dependency
   checkouts in CI.

## Phase 3: Complete the GDExtension Manifest

Update `open_brush_hull.gdextension` with entries matching every produced
binary. Include the most-specific feature tags first: platform, architecture,
precision, and debug/release.

Expected entry families are:

- `windows.<arch>.single.<debug|release>`
- `linux.<arch>.single.<debug|release>`
- `macos.single.<debug|release>`
- `android.<arch>.single.<debug|release>`
- `ios.arm64.single.<debug|release>`
- `web.wasm32.single.<debug|release>`

Use paths relative to the `.gdextension` file so the packaged directory can be
moved within a Godot project. Add a validation script that:

1. parses the manifest;
2. verifies every required matrix entry exists;
3. verifies every referenced file exists in the assembled package; and
4. rejects unreferenced native binaries.

For Web, use the exact non-threaded filename and feature-tag convention emitted
by the pinned `godot-cpp` version. The exported Godot Web template must support
dynamic linking/GDExtension and must use the same thread mode.

## Phase 4: GitHub Actions Design

### Pull Request and Push CI

Add `.github/workflows/native-ci.yml` triggered by changes to:

- `native/open_brush_hull/**`
- dependency/version files;
- native test scripts; and
- the workflow itself.

Use a small representative matrix on pull requests to control runner use while
still exercising each toolchain family:

- Linux x86_64 debug
- Windows x86_64 debug
- macOS universal debug
- Android arm64 debug
- iOS arm64 debug
- Web wasm32 release

Run the full matrix on pushes to the default branch, tags, and manual
dispatches. Set `fail-fast: false` so one platform failure does not hide the
others.

### Reusable Build Job

Create a reusable workflow or composite action that receives `platform`,
`arch`, and `target`. It should:

1. check out the repository and pinned dependencies;
2. install Python and SCons;
3. invoke the pinned `godot-cpp` toolchain setup, including NDK, Xcode, or
   Emscripten where applicable;
4. restore an SCons cache keyed by platform, architecture, target, dependency
   lock hash, compiler version, and SCons inputs;
5. build the extension;
6. inspect the output architecture and linkage;
7. upload a uniquely named intermediate artifact.

Pin third-party GitHub Actions to immutable commit SHAs, and give workflows only
`contents: read` except for the release job that needs write access.

### Package and Release

Add `.github/workflows/native-release.yml`, triggered by a version tag and
optionally `workflow_dispatch`. It should:

1. call the full build matrix;
2. download all intermediate artifacts;
3. assemble the platform-directory layout;
4. add `open_brush_hull.gdextension`, README, license, dependency notices, and a
   machine-readable build manifest containing all pinned versions;
5. run the manifest-completeness validator;
6. create deterministic `.zip` and checksum files;
7. upload the package as a workflow artifact; and
8. on a version tag, attach the same files to the corresponding GitHub Release.

Commit the validated distributable binaries under their
`native/open_brush_hull/bin/<platform>/` directories so a clean checkout is
immediately runnable. Keep compiler intermediates and non-distributable linker
outputs ignored. The release workflow remains the reproducible source for the
committed binary set.

## Phase 5: Validation Strategy

Compilation is necessary but does not prove that Godot can load the library.
Use three validation levels.

### 1. Static Validation for Every Matrix Entry

- Confirm the expected file is produced.
- Check architecture and binary format using appropriate tools such as
  `dumpbin`, `file`, `lipo`, `readelf`, or WebAssembly inspection tools.
- Check that the extension entry symbol is exported.
- Check that desktop/mobile binaries do not acquire unexpected dynamic
  dependencies.
- Run the package/manifest completeness validator.

### 2. Godot Runtime Smoke Tests Where GitHub Can Execute the Target

Package `Tests/GDScript/NativeHullProbe.gd` and
`Tests/GDScript/NativeHullParitySuite.gd` as the canonical runtime checks.
Each runtime job must prove:

- Godot loaded the native library rather than using the GDScript fallback.
- `NativeConvexHullUtil` is registered.
- representative valid, degenerate, and known-mismatch inputs retain their
  expected results.

Run these directly on:

- Windows x86_64
- Linux x86_64
- both halves of the macOS universal binary when suitable GitHub runners are
  available

Use a unique log prefix such as `OBH_CI_<run-id>_` and capture the complete
Godot log as an artifact. The test must fail if the prefix does not include an
explicit native-extension-loaded marker.

### 3. Platform Packaging/Execution Checks

- **Android:** export a minimal probe project containing the extension and
  verify the correct ABI libraries are inside the APK. Run the x86_64 build in
  an emulator when runner reliability and duration are acceptable; retain
  arm64 physical-device testing as a release qualification outside hosted CI
  until an appropriate runner exists.
- **iOS:** export or link a minimal Xcode project and verify the arm64 library
  is included. Hosted CI can prove compilation and packaging, but a real-device
  runtime test requires signing credentials and device infrastructure. Do not
  add signing secrets for the initial implementation.
- **Web:** export a minimal probe with a dynamic-link-enabled, non-threaded Web
  template, serve it over HTTP in CI, run it in a headless browser, and fail
  unless the native-loaded marker and probe assertions appear.
- **Windows/Linux/macOS:** export a minimal release probe in addition to
  running editor/headless debug tests, so both debug and release manifest paths
  are exercised.

## Phase 6: Rollout Order

Implement and stabilize the work in this order:

1. Reproducible dependency/API baseline and cross-platform `SConstruct`.
2. Linux and existing Windows builds, including native runtime tests.
3. macOS universal build and runtime test.
4. Android four-ABI build and APK inspection.
5. iOS arm64 build and Xcode export/link validation.
6. Web non-threaded build and browser smoke test.
7. Full `.gdextension` manifest and package validator.
8. Release packaging, checksums, and documentation.
9. Switch the project/addon consumption path from developer-local binaries to
   the validated CI binaries committed from the packaged artifact.

Keep each phase mergeable: the existing GDScript fallback remains available
for platforms whose native lane has not yet passed.

## Acceptance Criteria

The work is complete when:

- CI builds debug and release binaries for every row in the matrix.
- Every required binary is referenced by the packaged `.gdextension` file.
- Static format, architecture, entry-symbol, and package checks pass for every
  binary.
- Windows, Linux, macOS, and Web execute the native probe in automated CI.
- Android passes APK ABI inspection and at least one emulator smoke lane.
- iOS passes arm64 compilation and Xcode export/link validation; the documented
  device-signing limitation is not represented as a runtime pass.
- The existing parity suite passes on every executable CI platform, including
  its intentional assertion for the known ConcaveHull 95 mismatch.
- A tagged workflow produces one deterministic package, checksums, dependency
  notices, version metadata, and retained logs.
- A clean checkout can consume the package without `.deps/`, SCons, a compiler,
  or a locally installed Godot editor.

## Reference Baseline

- Godot 4.7 platform list:
  <https://docs.godotengine.org/en/4.7/about/list_of_features.html>
- Godot build platform and architecture options:
  <https://docs.godotengine.org/en/stable/engine_details/development/compiling/introduction_to_the_buildsystem.html>
- GDExtension manifest format:
  <https://docs.godotengine.org/en/4.5/tutorials/scripting/gdextension/gdextension_file.html>
- Official C++ bindings and compatibility guidance:
  <https://github.com/godotengine/godot-cpp>
- Official full cross-platform GDExtension workflow:
  <https://github.com/godotengine/godot-cpp-template/blob/main/.github/workflows/make_build.yml>
- Official example cross-platform `.gdextension` manifest:
  <https://github.com/godotengine/godot-cpp-template/blob/main/project/bin/example.gdextension>
