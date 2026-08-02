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
        foreach ($versionDirectory in (
            Get-ChildItem -LiteralPath $blenderRoot -Directory |
                Sort-Object -Property Name -Descending
        )) {
            $candidate = Join-Path $versionDirectory.FullName "blender.exe"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    throw @"
Blender was not found.
Pass its executable path explicitly:
  .\tools\assets\export-asteroid-pack.ps1 -BlenderBin "C:\path\to\blender.exe"
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
$exporterPath = Join-Path $repoRoot "tools\assets\export_asteroid_family.py"
$validatorPath = Join-Path $repoRoot "tools\assets\asteroid_pack_contract.py"

$families = @(
    [ordered]@{
        Id = "bennu"
        Name = "Bennu"
        Input = "assets\source\environment\asteroids\bennu\asteroid_bennu_textured.blend"
        Sha = "e01e7aa3364d8f7dc91aeaf4149b8aa82111f986467bec00ed7fa9ecd2f0bd5a"
        Output = "assets\runtime\environment\asteroids\bennu.glb"
        Manifest = "assets\runtime\environment\asteroids\bennu.manifest.json"
        Provenance = "development_only_pending_source_license"
    },
    [ordered]@{
        Id = "eros"
        Name = "Eros"
        Input = "assets\source\environment\asteroids\eros\asteroid_eros_true_color.glb"
        Sha = "73994d18c12b696d273abdb2c79d132f755ada014dde972a8ba3b480c7eb95ef"
        Output = "assets\runtime\environment\asteroids\eros.glb"
        Manifest = "assets\runtime\environment\asteroids\eros.manifest.json"
        Provenance = "cc_by_4_0_attributed"
    },
    [ordered]@{
        Id = "legacy_a"
        Name = "LegacyA"
        Input = "assets\source\environment\asteroids\legacy_a\asteroid_legacy_a.blend"
        Sha = "8bfa230c83fa9ebeea952b21d2a64d96aa81599413c907fd994372df88185032"
        Output = "assets\runtime\environment\asteroids\legacy_a.glb"
        Manifest = "assets\runtime\environment\asteroids\legacy_a.manifest.json"
        Provenance = "development_only_pending_source_license"
    },
    [ordered]@{
        Id = "legacy_b"
        Name = "LegacyB"
        Input = "assets\source\environment\asteroids\legacy_b\asteroid_legacy_b.blend"
        Sha = "5012f846592e69b955bdae10d5e98ac43eb5116541ddbfdb0d3cd489b16035d6"
        Output = "assets\runtime\environment\asteroids\legacy_b.glb"
        Manifest = "assets\runtime\environment\asteroids\legacy_b.manifest.json"
        Provenance = "development_only_pending_source_license"
    }
)

foreach ($requiredPath in @($exporterPath, $validatorPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required asteroid export tool missing: $requiredPath"
    }
}

$blenderExecutable = Resolve-BlenderExecutable -RequestedExecutable $BlenderBin
$pythonExecutable = Resolve-PythonExecutable

& $pythonExecutable $validatorPath --repo-root $repoRoot --sources-only
if ($LASTEXITCODE -ne 0) {
    throw "Asteroid source contract validation failed with exit code $LASTEXITCODE"
}

Write-Host "Using Blender: $blenderExecutable"
Write-Host "Using Python: $pythonExecutable"

foreach ($family in $families) {
    $inputPath = Join-Path $repoRoot $family.Input
    $outputPath = Join-Path $repoRoot $family.Output
    $manifestPath = Join-Path $repoRoot $family.Manifest
    $sourceHashBefore = (
        Get-FileHash -LiteralPath $inputPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($sourceHashBefore -ne $family.Sha) {
        throw "$($family.Id): unexpected source SHA $sourceHashBefore"
    }

    $outputDirectory = Split-Path -Parent $outputPath
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    foreach ($stalePath in @($outputPath, $manifestPath)) {
        if (Test-Path -LiteralPath $stalePath -PathType Leaf) {
            Remove-Item -LiteralPath $stalePath -Force
        }
    }

    Write-Host ""
    Write-Host "Exporting asteroid family: $($family.Id)"
    Write-Host "Source: $inputPath"
    Write-Host "Output: $outputPath"

    $startupArguments = @("--background")
    if ([System.IO.Path]::GetExtension($inputPath).ToLowerInvariant() -eq ".blend") {
        $startupArguments += $inputPath
    }
    else {
        $startupArguments += "--factory-startup"
    }

    $blenderArguments = $startupArguments + @(
        "--python-exit-code",
        "1",
        "--python",
        $exporterPath,
        "--",
        "--source-id",
        $family.Id,
        "--canonical-name",
        $family.Name,
        "--input",
        $inputPath,
        "--output",
        $outputPath,
        "--manifest",
        $manifestPath,
        "--source-sha",
        $family.Sha,
        "--provenance-status",
        $family.Provenance
    )

    & $blenderExecutable @blenderArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$($family.Id): Blender asteroid export failed with exit code $LASTEXITCODE"
    }

    $sourceHashAfter = (
        Get-FileHash -LiteralPath $inputPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($sourceHashAfter -ne $sourceHashBefore) {
        throw @"
$($family.Id): preserved asteroid source changed during export.
Before: $sourceHashBefore
After:  $sourceHashAfter
"@
    }

    foreach ($generatedPath in @($outputPath, $manifestPath)) {
        if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf)) {
            throw "$($family.Id): generated output missing: $generatedPath"
        }
        if ((Get-Item -LiteralPath $generatedPath).Length -le 0) {
            throw "$($family.Id): generated output empty: $generatedPath"
        }
    }
}

& $pythonExecutable $validatorPath --repo-root $repoRoot
if ($LASTEXITCODE -ne 0) {
    throw "Canonical asteroid pack validation failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Canonical four-family asteroid pack completed without modifying sources."
foreach ($family in $families) {
    Write-Host "  $(Join-Path $repoRoot $family.Output)"
    Write-Host "  $(Join-Path $repoRoot $family.Manifest)"
}
