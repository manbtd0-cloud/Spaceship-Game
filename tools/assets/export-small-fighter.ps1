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

    $commonPaths = @(
        (Join-Path $HOME "Downloads\blender\blender.exe"),
        (Join-Path $HOME "Desktop\blender\blender.exe"),
        "C:\Blender\blender.exe"
    )
    foreach ($candidate in $commonPaths) {
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

$blenderExecutable = Resolve-BlenderExecutable -RequestedExecutable $BlenderBin
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fi_fighter\Small Sci-Fi Fighter.blend"
$scriptPath = Join-Path $repoRoot "tools\assets\export_small_sci_fi_fighter.py"
$outputPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.glb"
$manifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"

foreach ($requiredPath in @($sourcePath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required export input missing: $requiredPath"
    }
}

$outputDirectory = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

Write-Host "Using Blender: $blenderExecutable"
Write-Host "Source: $sourcePath"
Write-Host "Runtime output: $outputPath"
Write-Host "Manifest output: $manifestPath"

$blenderArguments = @(
    "--background",
    $sourcePath,
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
    throw "Blender fighter export failed with exit code $LASTEXITCODE"
}

foreach ($generatedPath in @($outputPath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf)) {
        throw "Expected export output missing: $generatedPath"
    }
    if ((Get-Item -LiteralPath $generatedPath).Length -le 0) {
        throw "Expected export output is empty: $generatedPath"
    }
}

Write-Host "Fighter export completed successfully."
