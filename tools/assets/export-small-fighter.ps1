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
$sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fighter\Small Sci-Fi Fighter.blend"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    $sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fi_fighter\Small Sci-Fi Fighter.blend"
}
$scriptPath = Join-Path $repoRoot "tools\assets\export_small_sci_fi_fighter_v4.py"
$validatorPath = Join-Path $repoRoot "tools\assets\canonical_fighter_contract_v4.py"
$matrixGeneratorPath = Join-Path $repoRoot "tools\assets\generate_fighter_thruster_action_matrix.py"
$matrixValidatorPath = Join-Path $repoRoot "tools\assets\fighter_thruster_action_contract.py"
$outputPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.glb"
$manifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"
$matrixPath = Join-Path $repoRoot "config\ships\small_sci_fi_fighter_thruster_actions.json"
$pendingOutputPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.pending.glb"
$pendingManifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.pending.manifest.json"
$pendingMatrixPath = Join-Path $repoRoot "config\ships\small_sci_fi_fighter_thruster_actions.pending.json"

foreach ($requiredPath in @(
    $sourcePath,
    $scriptPath,
    $validatorPath,
    $matrixGeneratorPath,
    $matrixValidatorPath
)) {
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

New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $matrixPath) -Force | Out-Null
foreach ($pendingPath in @(
    $pendingOutputPath,
    $pendingManifestPath,
    $pendingMatrixPath
)) {
    if (Test-Path -LiteralPath $pendingPath -PathType Leaf) {
        Remove-Item -LiteralPath $pendingPath -Force
    }
}

Write-Host "Using Blender: $blenderExecutable"
Write-Host "Using Python: $pythonExecutable"
Write-Host "Source: $sourcePath"
Write-Host "Source SHA-256: $sourceShaBefore"
Write-Host "Pending GLB: $pendingOutputPath"
Write-Host "Pending schema-4 manifest: $pendingManifestPath"
Write-Host "Pending action matrix: $pendingMatrixPath"
Write-Host "Live GLB after validation: $outputPath"
Write-Host "Thruster visual strategy: source-exact nozzle-local EngineFire geometry"

$blenderArguments = @(
    "--background",
    $sourcePath,
    "--python-exit-code",
    "1",
    "--python",
    $scriptPath,
    "--",
    "--output",
    $pendingOutputPath,
    "--manifest",
    $pendingManifestPath
)

try {
    & $blenderExecutable @blenderArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Blender schema-4 fighter export failed with exit code $LASTEXITCODE"
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

    foreach ($generatedPath in @($pendingOutputPath, $pendingManifestPath)) {
        if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf)) {
            throw "Expected pending canonical export output missing: $generatedPath"
        }
        if ((Get-Item -LiteralPath $generatedPath).Length -le 0) {
            throw "Expected pending canonical export output is empty: $generatedPath"
        }
    }

    $pendingManifest = Get-Content -LiteralPath $pendingManifestPath -Raw | ConvertFrom-Json
    $pendingManifest.output_path = $outputPath.Replace("\", "/")
    $manifestJson = $pendingManifest | ConvertTo-Json -Depth 100
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText(
        $pendingManifestPath,
        $manifestJson + [Environment]::NewLine,
        $utf8WithoutBom
    )

    & $pythonExecutable $validatorPath `
        --glb $pendingOutputPath `
        --manifest $pendingManifestPath `
        --source-sha $sourceShaBefore
    if ($LASTEXITCODE -ne 0) {
        throw "Schema-4 nozzle-local fighter validation failed with exit code $LASTEXITCODE"
    }

    & $pythonExecutable $matrixGeneratorPath `
        --manifest $pendingManifestPath `
        --output $pendingMatrixPath
    if ($LASTEXITCODE -ne 0) {
        throw "Fighter thruster action matrix generation failed with exit code $LASTEXITCODE"
    }

    & $pythonExecutable $matrixValidatorPath `
        --manifest $pendingManifestPath `
        --matrix $pendingMatrixPath
    if ($LASTEXITCODE -ne 0) {
        throw "Fighter thruster action matrix validation failed with exit code $LASTEXITCODE"
    }

    foreach ($generatedPath in @($pendingMatrixPath)) {
        if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf)) {
            throw "Expected pending matrix output missing: $generatedPath"
        }
        if ((Get-Item -LiteralPath $generatedPath).Length -le 0) {
            throw "Expected pending matrix output is empty: $generatedPath"
        }
    }

    Move-Item -LiteralPath $pendingOutputPath -Destination $outputPath -Force
    Move-Item -LiteralPath $pendingManifestPath -Destination $manifestPath -Force
    Move-Item -LiteralPath $pendingMatrixPath -Destination $matrixPath -Force
}
finally {
    foreach ($pendingPath in @(
        $pendingOutputPath,
        $pendingManifestPath,
        $pendingMatrixPath
    )) {
        if (Test-Path -LiteralPath $pendingPath -PathType Leaf) {
            Remove-Item -LiteralPath $pendingPath -Force
        }
    }
}

Write-Host "Schema-4 fighter export completed without modifying the source."
Write-Host "Source SHA-256: $sourceShaBefore"
Write-Host "Generated nozzle-local source exhaust geometry for twelve runtime effects."
Write-Host "Published validated outputs:"
Write-Host "  $outputPath"
Write-Host "  $manifestPath"
Write-Host "  $matrixPath"
