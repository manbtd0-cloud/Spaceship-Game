[CmdletBinding()]
param(
    [string]$BlenderBin = $env:BLENDER_BIN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-BlenderExecutable {
    param([string]$RequestedExecutable)

    if ($RequestedExecutable) {
        $requestedCommand = Get-Command $RequestedExecutable -ErrorAction SilentlyContinue
        if ($requestedCommand) {
            return $requestedCommand.Source
        }
        if (Test-Path -LiteralPath $RequestedExecutable -PathType Leaf) {
            return (Resolve-Path -LiteralPath $RequestedExecutable).Path
        }
        throw "Blender executable not found: $RequestedExecutable"
    }

    $pathCommand = Get-Command "blender" -ErrorAction SilentlyContinue
    if ($pathCommand) {
        return $pathCommand.Source
    }

    $blenderRoot = "C:\Program Files\Blender Foundation"
    if (Test-Path -LiteralPath $blenderRoot -PathType Container) {
        $installedVersions = Get-ChildItem -LiteralPath $blenderRoot -Directory |
            Sort-Object -Property Name -Descending
        foreach ($versionDirectory in $installedVersions) {
            $candidate = Join-Path $versionDirectory.FullName "blender.exe"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    foreach ($candidate in @(
        (Join-Path $HOME "Downloads\blender\blender.exe"),
        (Join-Path $HOME "Desktop\blender\blender.exe"),
        "C:\Blender\blender.exe"
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw @"
Blender was not found.
Pass its executable path explicitly:
  .\tools\assets\export-small-fighter.ps1 -BlenderBin "C:\path\to\blender.exe"
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

$expectedSourceSha = "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fi_fighter\Small Sci-Fi Fighter.blend"
$scriptPath = Join-Path $repoRoot "tools\assets\export_small_sci_fi_fighter_v3.py"
$validatorPath = Join-Path $repoRoot "tools\assets\canonical_fighter_contract_v3.py"
$outputPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.glb"
$manifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"

foreach ($requiredPath in @($sourcePath, $scriptPath, $validatorPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required canonical export input missing: $requiredPath"
    }
}

$blenderExecutable = Resolve-BlenderExecutable -RequestedExecutable $BlenderBin
$pythonExecutable = Resolve-PythonExecutable
$sourceShaBefore = (
    Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256
).Hash.ToLowerInvariant()
if ($sourceShaBefore -ne $expectedSourceSha) {
    throw "Unexpected fighter source SHA: $sourceShaBefore"
}

$outputDirectory = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

foreach ($stalePath in @($outputPath, $manifestPath)) {
    if (Test-Path -LiteralPath $stalePath -PathType Leaf) {
        Remove-Item -LiteralPath $stalePath -Force
    }
}

Write-Host "Using Blender: $blenderExecutable"
Write-Host "Using Python: $pythonExecutable"
Write-Host "Source: $sourcePath"
Write-Host "Source SHA-256: $sourceShaBefore"
Write-Host "Canonical GLB: $outputPath"
Write-Host "Schema-3 manifest: $manifestPath"
Write-Host "Thruster visual strategy: source-exact EngineFire geometry"

$blenderArguments = @(
    "--background",
    $sourcePath,
    "--python-exit-code",
    "1",
    "--python",
    $scriptPath,
    "--",
    "--output",
    $outputPath,
    "--manifest",
    $manifestPath
)

& $blenderExecutable @blenderArguments
if ($LASTEXITCODE -ne 0) {
    throw "Blender schema-3 fighter export failed with exit code $LASTEXITCODE"
}

$sourceShaAfter = (
    Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256
).Hash.ToLowerInvariant()
if ($sourceShaAfter -ne $sourceShaBefore) {
    throw @"
The preserved Blender source changed during canonical export.
Before: $sourceShaBefore
After:  $sourceShaAfter
"@
}

foreach ($generatedPath in @($outputPath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf)) {
        throw "Expected canonical export output missing: $generatedPath"
    }
    if ((Get-Item -LiteralPath $generatedPath).Length -le 0) {
        throw "Expected canonical export output is empty: $generatedPath"
    }
}

& $pythonExecutable $validatorPath `
    --glb $outputPath `
    --manifest $manifestPath `
    --source-sha $sourceShaBefore
if ($LASTEXITCODE -ne 0) {
    throw "Schema-3 source-exact fighter validation failed with exit code $LASTEXITCODE"
}

Write-Host "Schema-3 fighter export completed without modifying the source."
Write-Host "Source SHA-256: $sourceShaAfter"
Write-Host "Generated exact source exhaust geometry for twelve runtime effects."
Write-Host "Generated:"
Write-Host "  $outputPath"
Write-Host "  $manifestPath"