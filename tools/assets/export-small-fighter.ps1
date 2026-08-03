[CmdletBinding()]
param(
    [string]$BlenderBin = $env:BLENDER_BIN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-BlenderExecutable {
    param([string]$RequestedExecutable)

    if ($RequestedExecutable) {
        $command = Get-Command $RequestedExecutable -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
        if (Test-Path -LiteralPath $RequestedExecutable -PathType Leaf) {
            return (Resolve-Path -LiteralPath $RequestedExecutable).Path
        }
        throw "Blender executable not found: $RequestedExecutable"
    }

    $command = Get-Command "blender" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $blenderRoot = "C:\Program Files\Blender Foundation"
    if (Test-Path -LiteralPath $blenderRoot -PathType Container) {
        foreach ($directory in @(
            Get-ChildItem -LiteralPath $blenderRoot -Directory |
                Sort-Object -Property Name -Descending
        )) {
            $candidate = Join-Path $directory.FullName "blender.exe"
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

function Remove-PublicationArtifacts {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Restore-PublicationBackups {
    param(
        [hashtable]$BackupToLive,
        [string[]]$LivePaths
    )

    Remove-PublicationArtifacts -Paths $LivePaths
    foreach ($backupPath in $BackupToLive.Keys) {
        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            Move-Item `
                -LiteralPath $backupPath `
                -Destination $BackupToLive[$backupPath] `
                -Force
        }
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
$sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fighter\Small Sci-Fi Fighter.blend"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    $sourcePath = Join-Path $repoRoot "assets\source\ships\player_candidates\small_sci_fi_fighter\Small Sci-Fi Fighter.blend"
}
$scriptPath = Join-Path $repoRoot "tools\assets\export_small_sci_fi_fighter_v5.py"
$validatorPath = Join-Path $repoRoot "tools\assets\canonical_fighter_contract_v5.py"
$matrixGeneratorPath = Join-Path $repoRoot "tools\assets\generate_fighter_thruster_action_matrix.py"
$matrixValidatorPath = Join-Path $repoRoot "tools\assets\fighter_thruster_action_contract.py"
$outputPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.glb"
$manifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"
$matrixPath = Join-Path $repoRoot "config\ships\small_sci_fi_fighter_thruster_actions.json"
$pendingOutputPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.pending.glb"
$pendingManifestPath = Join-Path $repoRoot "assets\runtime\ships\player\small_sci_fi_fighter.pending.manifest.json"
$pendingMatrixPath = Join-Path $repoRoot "config\ships\small_sci_fi_fighter_thruster_actions.pending.json"
$outputBackupPath = "$outputPath.publish-backup"
$manifestBackupPath = "$manifestPath.publish-backup"
$matrixBackupPath = "$matrixPath.publish-backup"
$pendingPaths = @($pendingOutputPath, $pendingManifestPath, $pendingMatrixPath)
$backupPaths = @($outputBackupPath, $manifestBackupPath, $matrixBackupPath)
$livePaths = @($outputPath, $manifestPath, $matrixPath)

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
Remove-PublicationArtifacts -Paths @($pendingPaths + $backupPaths)

Write-Host "Using Blender: $blenderExecutable"
Write-Host "Using Python: $pythonExecutable"
Write-Host "Source: $sourcePath"
Write-Host "Source SHA-256: $sourceShaBefore"
Write-Host "Pending GLB: $pendingOutputPath"
Write-Host "Pending schema-5 manifest: $pendingManifestPath"
Write-Host "Pending action matrix: $pendingMatrixPath"
Write-Host "Live GLB after validation: $outputPath"
Write-Host "Thruster visual strategy: source-exact nozzle-local EngineFire geometry"
Write-Host "Primary muzzle strategy: source-derived forward boundary loops"

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
        throw "Blender schema-5 fighter export failed with exit code $LASTEXITCODE"
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

    $pendingManifest = Get-Content -LiteralPath $pendingManifestPath -Raw |
        ConvertFrom-Json
    if ($pendingManifest.schema_version -ne 5) {
        throw "Pending fighter manifest schema_version must be 5"
    }
    $expectedMuzzlePaths = @(
        "Weapons/Primary/LeftMuzzle",
        "Weapons/Primary/RightMuzzle"
    )
    $actualMuzzlePaths = @(
        $pendingManifest.primary_muzzles |
            ForEach-Object { [string]$_.path }
    )
    Assert-ExactPathSet `
        -Expected $expectedMuzzlePaths `
        -Actual $actualMuzzlePaths `
        -Label "Primary muzzle"

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
        throw "Schema-5 fighter validation failed with exit code $LASTEXITCODE"
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

    if (
        -not (Test-Path -LiteralPath $pendingMatrixPath -PathType Leaf) -or
        (Get-Item -LiteralPath $pendingMatrixPath).Length -le 0
    ) {
        throw "Expected pending matrix output is missing or empty: $pendingMatrixPath"
    }

    function Publish-ValidatedFiles {
        $backupToLive = @{
            $outputBackupPath = $outputPath
            $manifestBackupPath = $manifestPath
            $matrixBackupPath = $matrixPath
        }
        $published = $false
        try {
            foreach ($pair in @(
                @($outputPath, $outputBackupPath),
                @($manifestPath, $manifestBackupPath),
                @($matrixPath, $matrixBackupPath)
            )) {
                if (Test-Path -LiteralPath $pair[0] -PathType Leaf) {
                    Copy-Item `
                        -LiteralPath $pair[0] `
                        -Destination $pair[1] `
                        -Force
                }
            }

            Move-Item -LiteralPath $pendingOutputPath -Destination $outputPath -Force
            Move-Item -LiteralPath $pendingManifestPath -Destination $manifestPath -Force
            Move-Item -LiteralPath $pendingMatrixPath -Destination $matrixPath -Force
            $published = $true
        }
        catch {
            Restore-PublicationBackups `
                -BackupToLive $backupToLive `
                -LivePaths $livePaths
            throw
        }
        finally {
            if ($published) {
                Remove-PublicationArtifacts -Paths $backupPaths
            }
        }
    }

    Publish-ValidatedFiles
}
finally {
    Remove-PublicationArtifacts -Paths @($pendingPaths + $backupPaths)
}

Write-Host "Schema-5 fighter export completed without modifying the source."
Write-Host "Source SHA-256: $sourceShaBefore"
Write-Host "Generated twelve source-exact thruster effects and two source-derived primary muzzles."
Write-Host "Published validated assets:"
Write-Host "  $outputPath"
Write-Host "  $manifestPath"
Write-Host "  $matrixPath"
