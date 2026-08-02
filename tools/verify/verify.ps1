[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-GodotExecutable {
    param([string]$RequestedExecutable)

    if ($RequestedExecutable) {
        $requestedCommand = Get-Command $RequestedExecutable -ErrorAction SilentlyContinue
        if ($requestedCommand) {
            return $requestedCommand.Source
        }
        if (Test-Path -LiteralPath $RequestedExecutable -PathType Leaf) {
            return (Resolve-Path -LiteralPath $RequestedExecutable).Path
        }
        throw "Godot executable not found: $RequestedExecutable"
    }

    foreach ($candidate in @("godot", "godot4")) {
        $candidateCommand = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($candidateCommand) {
            return $candidateCommand.Source
        }
    }

    $commonPaths = @(
        (Join-Path $HOME "Downloads\Godot_v4.7.1-stable_win64.exe"),
        (Join-Path $HOME "Desktop\Godot_v4.7.1-stable_win64.exe"),
        (Join-Path $HOME "Packages\Godot_v4.7.1-stable_win64.exe"),
        "C:\Godot\Godot_v4.7.1-stable_win64.exe"
    )
    foreach ($candidatePath in $commonPaths) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidatePath).Path
        }
    }

    throw @"
Godot 4.7.1 was not found.
Pass its Windows executable path explicitly:
  .\tools\verify\verify.ps1 -GodotBin "C:\path\to\Godot_v4.7.1-stable_win64.exe"
"@
}

function Resolve-PythonExecutable {
    foreach ($candidate in @("python", "python3")) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }
    throw "Python 3 was not found on PATH."
}

function Invoke-GodotStep {
    param(
        [string]$Executable,
        [string[]]$GodotArguments,
        [string]$Description
    )

    Write-Host "==> $Description"
    & $Executable @GodotArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Godot exited with code $LASTEXITCODE during: $Description"
    }
}

function Assert-ExactPathSet {
    param(
        [string[]]$Expected,
        [string[]]$Actual,
        [string]$Label
    )

    $missing = @($Expected | Where-Object { $_ -notin $Actual })
    $unexpected = @($Actual | Where-Object { $_ -notin $Expected })
    $unique = @($Actual | Sort-Object -Unique)
    if (
        $missing.Count -gt 0 -or
        $unexpected.Count -gt 0 -or
        $unique.Count -ne $Expected.Count
    ) {
        throw (
            "{0} paths mismatch. Missing: [{1}] Unexpected: [{2}]" -f
            $Label,
            ($missing -join ", "),
            ($unexpected -join ", ")
        )
    }
}

$expectedSourceSha = "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$glbPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.glb"
$manifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"
$matrixPath = Join-Path $repoRoot "config\ships\small_sci_fi_fighter_thruster_actions.json"
$fighterValidatorPath = Join-Path $repoRoot "tools\assets\canonical_fighter_contract_v4.py"
$matrixValidatorPath = Join-Path $repoRoot "tools\assets\fighter_thruster_action_contract.py"

foreach ($requiredPath in @(
    $glbPath,
    $manifestPath,
    $matrixPath,
    $fighterValidatorPath,
    $matrixValidatorPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required verification file missing: $requiredPath"
    }
    if ((Get-Item -LiteralPath $requiredPath).Length -le 0) {
        throw "Required verification file is empty: $requiredPath"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 4) {
    throw "Hero fighter manifest schema_version must be 4"
}
if (
    $manifest.thruster_visual_strategy -ne
    "source_exact_nozzle_local_enginefire_geometry"
) {
    throw "Hero fighter must use source_exact_nozzle_local_enginefire_geometry"
}
if ($manifest.procedural_exhaust_geometry -ne $false) {
    throw "Hero fighter procedural_exhaust_geometry must be false"
}
if ($null -eq $manifest.canonical_frame) {
    throw "Hero fighter manifest canonical_frame is missing"
}
if (
    $manifest.canonical_frame.godot_forward -ne "-Z" -or
    $manifest.canonical_frame.godot_up -ne "+Y" -or
    $manifest.canonical_frame.godot_right -ne "+X" -or
    -not $manifest.canonical_frame.root_identity
) {
    throw "Hero fighter canonical frame must be +X right, -Z forward, +Y up, identity root"
}

$expectedSocketPaths = @(
    "Thrusters/Main/MainLeft",
    "Thrusters/Main/MainRight",
    "Thrusters/Retro/RetroLeft",
    "Thrusters/Retro/RetroRight",
    "Thrusters/Maneuver/FrontUpperLeft",
    "Thrusters/Maneuver/FrontUpperRight",
    "Thrusters/Maneuver/RearUpperLeft",
    "Thrusters/Maneuver/RearUpperRight",
    "Thrusters/Maneuver/RearLowerLeft",
    "Thrusters/Maneuver/RearLowerRight",
    "Thrusters/Maneuver/FrontLowerLeft",
    "Thrusters/Maneuver/FrontLowerRight"
)
$actualSocketPaths = @($manifest.sockets | ForEach-Object { [string]$_.path })
Assert-ExactPathSet -Expected $expectedSocketPaths -Actual $actualSocketPaths -Label "Hero fighter socket"

$expectedEffectPaths = @(
    "ThrusterEffects/MainEffects/MainLeftEffect",
    "ThrusterEffects/MainEffects/MainRightEffect",
    "ThrusterEffects/RetroEffects/RetroLeftEffect",
    "ThrusterEffects/RetroEffects/RetroRightEffect",
    "ThrusterEffects/ManeuverEffects/FrontUpperLeftEffect",
    "ThrusterEffects/ManeuverEffects/FrontUpperRightEffect",
    "ThrusterEffects/ManeuverEffects/RearUpperLeftEffect",
    "ThrusterEffects/ManeuverEffects/RearUpperRightEffect",
    "ThrusterEffects/ManeuverEffects/RearLowerLeftEffect",
    "ThrusterEffects/ManeuverEffects/RearLowerRightEffect",
    "ThrusterEffects/ManeuverEffects/FrontLowerLeftEffect",
    "ThrusterEffects/ManeuverEffects/FrontLowerRightEffect"
)
$actualEffectPaths = @($manifest.thruster_effects | ForEach-Object { [string]$_.path })
Assert-ExactPathSet -Expected $expectedEffectPaths -Actual $actualEffectPaths -Label "Hero fighter effect"

$actualEffectSocketPaths = @(
    $manifest.thruster_effects | ForEach-Object { [string]$_.socket_path }
)
Assert-ExactPathSet `
    -Expected $expectedSocketPaths `
    -Actual $actualEffectSocketPaths `
    -Label "Hero fighter effect socket"

foreach ($effect in $manifest.thruster_effects) {
    if (-not $effect.source_exact_geometry) {
        throw "Every fighter effect must use source-exact geometry"
    }
    if ([string]$effect.geometry_sha256 -notmatch '^[0-9a-f]{64}$') {
        throw "Every fighter effect must include a valid geometry SHA-256"
    }
    if ($null -eq $effect.node_transform_basis) {
        throw "Every fighter effect must include node_transform_basis"
    }
    if ($null -eq $effect.node_transform_origin) {
        throw "Every fighter effect must include node_transform_origin"
    }
    if ($null -eq $effect.local_exhaust_axis) {
        throw "Every fighter effect must include local_exhaust_axis"
    }
    if (
        [double]$effect.maximum_reconstruction_error_m -gt 0.0001 -or
        [double]$effect.maximum_reconstruction_error_m -lt 0.0
    ) {
        throw "Every fighter effect maximum_reconstruction_error_m must be within [0, 0.0001]"
    }
}

$pythonExecutable = Resolve-PythonExecutable
Write-Host "==> Validate schema-four fighter asset contract"
& $pythonExecutable $fighterValidatorPath `
    --glb $glbPath `
    --manifest $manifestPath `
    --source-sha $expectedSourceSha
if ($LASTEXITCODE -ne 0) {
    throw "Schema-four fighter validation failed with exit code $LASTEXITCODE"
}

Write-Host "==> Validate deterministic fighter thruster matrix"
& $pythonExecutable $matrixValidatorPath `
    --manifest $manifestPath `
    --matrix $matrixPath
if ($LASTEXITCODE -ne 0) {
    throw "Fighter thruster action matrix validation failed with exit code $LASTEXITCODE"
}

$godotExecutable = Resolve-GodotExecutable -RequestedExecutable $GodotBin
Write-Host "Using Godot: $godotExecutable"
Write-Host "Project root: $repoRoot"

Push-Location $repoRoot
try {
    Invoke-GodotStep -Executable $godotExecutable -Description "Import project" -GodotArguments @(
        "--headless", "--path", ".", "--editor", "--quit"
    )
    Invoke-GodotStep -Executable $godotExecutable -Description "Run test suites" -GodotArguments @(
        "--headless", "--path", ".", "--script", "res://tests/test_runner.gd"
    )
    Invoke-GodotStep -Executable $godotExecutable -Description "Boot main scene briefly" -GodotArguments @(
        "--headless", "--path", ".", "--quit-after", "2"
    )
}
finally {
    Pop-Location
}
