param(
    [ValidateSet("template_debug", "template_release")]
    [string] $Target = "template_debug",
    [switch] $ForceApiDump
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Deps = Join-Path $Root ".deps"
$GodotCpp = Join-Path $Deps "godot-cpp"
$QuickHull = Join-Path $Deps "quickhull"
$GodotCppRepo = "https://github.com/godotengine/godot-cpp.git"
$QuickHullRepo = "https://github.com/akuukka/quickhull.git"
$GodotCppCommit = "f8a4e78f47f199e3591d2bedcaadcb905b6d7d7b"
$QuickHullCommit = "4ef66c68950cb4db11d3b75bfe4034d807485ad0"

if (-not (Test-Path $Deps)) {
    New-Item -ItemType Directory -Path $Deps | Out-Null
}

function Ensure-GitDependency {
    param(
        [string] $Path,
        [string] $Repo,
        [string] $Commit
    )

    $NeedsCheckout = $false
    if (-not (Test-Path $Path)) {
        git clone --no-checkout $Repo $Path
        if ($LASTEXITCODE -ne 0) {
            throw "git clone failed for $Repo with exit code $LASTEXITCODE"
        }
        $NeedsCheckout = $true
    }

    Push-Location $Path
    try {
        $CurrentCommit = git rev-parse HEAD
        if ($LASTEXITCODE -ne 0 -or $CurrentCommit -ne $Commit) {
            git fetch --depth 1 origin $Commit
            if ($LASTEXITCODE -ne 0) {
                throw "git fetch failed for $Repo commit $Commit with exit code $LASTEXITCODE"
            }
            $NeedsCheckout = $true
        }
        if ($NeedsCheckout) {
            git checkout --detach $Commit
            if ($LASTEXITCODE -ne 0) {
                throw "git checkout failed for $Repo commit $Commit with exit code $LASTEXITCODE"
            }
        }
    }
    finally {
        Pop-Location
    }
}

Ensure-GitDependency -Path $GodotCpp -Repo $GodotCppRepo -Commit $GodotCppCommit
Ensure-GitDependency -Path $QuickHull -Repo $QuickHullRepo -Commit $QuickHullCommit

$Godot = "C:\Program Files\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
if (-not (Test-Path $Godot)) {
    throw "Godot console executable not found at $Godot"
}

Push-Location $PSScriptRoot
try {
    if ($ForceApiDump -or -not (Test-Path "extension_api.json")) {
        & $Godot --dump-extension-api
        if ($LASTEXITCODE -ne 0) {
            throw "Godot extension API dump failed with exit code $LASTEXITCODE"
        }
    }

    $env:PROCESSOR_ARCHITECTURE = "AMD64"
    scons platform=windows target=$Target custom_api_file=extension_api.json silence_msvc=no -j1
    if ($LASTEXITCODE -ne 0) {
        throw "SCons build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
