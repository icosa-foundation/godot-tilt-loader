param(
    [ValidateSet("template_debug", "template_release")]
    [string] $Target = "template_debug",
    [ValidateSet("x86_64", "x86_32", "arm64")]
    [string] $Arch = "x86_64"
)

$ErrorActionPreference = "Stop"

$ConfigPath = Join-Path $PSScriptRoot "dependencies.json"
$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$SetupScript = Join-Path $PSScriptRoot "tools/setup_dependencies.py"

# Some managed PowerShell hosts omit this standard Windows variable. SCons
# queries it while discovering the installed MSVC toolchain.
if (-not (Test-Path Env:PROCESSOR_ARCHITECTURE)) {
    $env:PROCESSOR_ARCHITECTURE = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToUpperInvariant()
}

python $SetupScript
if ($LASTEXITCODE -ne 0) {
    throw "Dependency setup failed with exit code $LASTEXITCODE"
}

Push-Location $PSScriptRoot
try {
    scons `
        platform=windows `
        arch=$Arch `
        target=$Target `
        precision=single `
        api_version=$($Config.godot.api_version)
    if ($LASTEXITCODE -ne 0) {
        throw "SCons build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$WindowsBin = Join-Path $PSScriptRoot "bin/windows"
Get-ChildItem -LiteralPath $WindowsBin -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @(".exp", ".lib", ".pdb") } |
    Remove-Item -Force

$Output = Join-Path $PSScriptRoot "bin/windows/open_brush_hull.windows.$Target.$Arch.dll"
if (-not (Test-Path -LiteralPath $Output)) {
    throw "Expected output was not produced: $Output"
}
Write-Output "OPEN_BRUSH_HULL_OUTPUT=$Output"
