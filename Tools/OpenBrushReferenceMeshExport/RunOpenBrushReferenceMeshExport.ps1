param(
    [string] $GodotRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string] $OpenBrushRoot = "C:\Users\andyb\Documents\open-brush-fast",
    [string] $UnityExe = "C:\Program Files\Unity\Hub\Editor\2022.3.62f2\Editor\Unity.exe",
    [string] $TestFilter = "TiltBrush.OpenBrushReferenceMeshExportTest.ExportRepresentativeCafeFixtures"
)

$ErrorActionPreference = "Stop"

$expectedFixtures = @(
    "cafe_ink_stroke_150.json",
    "cafe_duct_tape_geometry_stroke_496.json",
    "cafe_stars_stroke_130.json",
    "cafe_sparks_stroke_463.json",
    "cafe_matte_hull_stroke_11.json"
)

function Read-LogText {
    param([string] $Path)

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -LiteralPath $Path -Raw
    }
    return ""
}

function Test-ExpectedFixturesExist {
    param(
        [string] $Directory,
        [string[]] $Fixtures
    )

    foreach ($fixture in $Fixtures) {
        $fixturePath = Join-Path $Directory $fixture
        if (-not (Test-Path -LiteralPath $fixturePath)) {
            return $false
        }
    }
    return $true
}

function Test-LogHasTerminalMarker {
    param([string] $Text)

    return `
        $Text.Contains("OPEN_BRUSH_REFERENCE_EXPORT wrote") -or `
        $Text.Contains("another Unity instance is running") -or `
        $Text.Contains("Multiple Unity instances cannot open the same project") -or `
        $Text.Contains("Fatal Error") -or `
        $Text.Contains("Crash!!!")
}

$logDirectory = Join-Path $GodotRoot "Temp"
$logPath = Join-Path $logDirectory "open_brush_reference_export.log"
$outputDirectory = Join-Path $GodotRoot "Resources\Fixtures\OpenBrushReferenceMeshes"

New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue

$env:OPEN_BRUSH_STROKE_GEN_GODOT_ROOT = $GodotRoot
& $UnityExe `
    -batchmode `
    -nographics `
    -projectPath $OpenBrushRoot `
    -runTests `
    -testPlatform EditMode `
    -testFilter $TestFilter `
    -logFile $logPath

$unityExitCode = $LASTEXITCODE
$logText = Read-LogText -Path $logPath
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    if ((Test-LogHasTerminalMarker -Text $logText) -or (Test-ExpectedFixturesExist -Directory $outputDirectory -Fixtures $expectedFixtures)) {
        break
    }
    Start-Sleep -Milliseconds 250
    $logText = Read-LogText -Path $logPath
}

if ($logText.Contains("another Unity instance is running") -or $logText.Contains("Multiple Unity instances cannot open the same project")) {
    throw "Unity reference export did not run because the Open Brush project is already open. See $logPath"
}

if ($logText.Contains("Fatal Error") -or $logText.Contains("Crash!!!")) {
    throw "Unity reference export logged a fatal error. See $logPath"
}

if ($null -ne $unityExitCode -and $unityExitCode -ne 0) {
    throw "Unity reference export exited with code $unityExitCode. See $logPath"
}

$missingFixtures = @()
foreach ($fixture in $expectedFixtures) {
    $fixturePath = Join-Path $outputDirectory $fixture
    if (-not (Test-Path -LiteralPath $fixturePath)) {
        $missingFixtures += $fixture
    }
}

if ($missingFixtures.Count -gt 0) {
    throw "Unity reference export completed but did not produce expected fixture(s): $($missingFixtures -join ', '). See $logPath"
}

Write-Host "OPEN_BRUSH_REFERENCE_EXPORT_RUNNER wrote $($expectedFixtures.Count) reference fixtures to $outputDirectory"
