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
  .\tools\assets\audit-small-fighter.ps1 -BlenderBin "C:\path\to\blender.exe"
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

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fi_fighter\Small Sci-Fi Fighter.blend"
$scriptPath = Join-Path $repoRoot "tools\assets\audit_small_sci_fi_fighter.py"
$validatorPath = Join-Path $repoRoot "tools\assets\hero_ship_audit_contract.py"
$outputDirectory = Join-Path $repoRoot "artifacts\hero_ship_audit"

foreach ($requiredPath in @($sourcePath, $scriptPath, $validatorPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required audit input missing: $requiredPath"
    }
}

$blenderExecutable = Resolve-BlenderExecutable -RequestedExecutable $BlenderBin
$pythonExecutable = Resolve-PythonExecutable
$sourceHashBefore = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath
).Hash.ToLowerInvariant()

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

Write-Host "Using Blender: $blenderExecutable"
Write-Host "Using Python: $pythonExecutable"
Write-Host "Source: $sourcePath"
Write-Host "Source SHA-256: $sourceHashBefore"
Write-Host "Audit output: $outputDirectory"

$blenderArguments = @(
    "--background",
    $sourcePath,
    "--python",
    $scriptPath,
    "--",
    "--output-dir",
    $outputDirectory,
    "--source-sha",
    $sourceHashBefore
)

& $blenderExecutable @blenderArguments
if ($LASTEXITCODE -ne 0) {
    throw "Blender fighter audit failed with exit code $LASTEXITCODE"
}

$sourceHashAfter = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath
).Hash.ToLowerInvariant()
if ($sourceHashAfter -ne $sourceHashBefore) {
    throw @"
The preserved Blender source changed during the audit.
Before: $sourceHashBefore
After:  $sourceHashAfter
"@
}

& $pythonExecutable $validatorPath `
    --audit-dir $outputDirectory `
    --source $sourcePath
if ($LASTEXITCODE -ne 0) {
    throw "Hero ship audit contract validation failed with exit code $LASTEXITCODE"
}

$generatedPaths = @(
    "front.png",
    "rear.png",
    "left.png",
    "right.png",
    "top.png",
    "bottom.png",
    "perspective_front.png",
    "perspective_rear.png",
    "ship_audit.json"
) | ForEach-Object { Join-Path $outputDirectory $_ }

foreach ($generatedPath in $generatedPaths) {
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf)) {
        throw "Expected audit output missing: $generatedPath"
    }
    if ((Get-Item -LiteralPath $generatedPath).Length -le 0) {
        throw "Expected audit output is empty: $generatedPath"
    }
}

Write-Host "Hero ship audit completed without modifying the source."
Write-Host "Source SHA-256: $sourceHashAfter"
Write-Host "Generated evidence:"
foreach ($generatedPath in $generatedPaths) {
    Write-Host "  $generatedPath"
}
