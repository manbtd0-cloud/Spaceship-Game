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

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$requiredRuntimeFiles = @(
    "assets\runtime\ships\player\small_sci_fi_fighter.glb",
    "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"
)

foreach ($relativePath in $requiredRuntimeFiles) {
    $absolutePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Required runtime asset missing: $relativePath"
    }
    if ((Get-Item -LiteralPath $absolutePath).Length -le 0) {
        throw "Required runtime asset is empty: $relativePath"
    }
}

$manifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.godot_forward -ne "-Z" -or $manifest.godot_up -ne "+Y") {
    throw "Hero fighter manifest orientation must be -Z forward and +Y up"
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
