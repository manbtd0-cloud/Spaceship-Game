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

$godotExecutable = Resolve-GodotExecutable -RequestedExecutable $GodotBin
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

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
