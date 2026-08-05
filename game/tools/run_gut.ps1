[CmdletBinding()]
param(
    [string]$GodotCommand = "godot",
    [string]$Select = "",
    [switch]$Reinstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$installer = Join-Path $PSScriptRoot "install_gut_9_5.ps1"
$installArguments = @()
if ($Reinstall) {
    $installArguments += "-Force"
}
& $installer @installArguments

New-Item -ItemType Directory -Path (Join-Path $projectRoot "test-results") -Force | Out-Null

$previousTestMode = [Environment]::GetEnvironmentVariable("LUDUS_GUT_MODE", "Process")
$env:LUDUS_GUT_MODE = "1"
$exitCode = 1

try {
    Push-Location $projectRoot

    & $GodotCommand --headless --editor --path $projectRoot --quit
    if ($LASTEXITCODE -ne 0) {
        throw "Godot no pudo importar el proyecto y registrar las clases de GUT."
    }

    $arguments = @(
        "--headless",
        "-d",
        "--path", $projectRoot,
        "-s", "tools/ludus_gut_cmdln.gd",
        "-gconfig=res://.gutconfig.json",
        "-gexit"
    )
    if (-not [string]::IsNullOrWhiteSpace($Select)) {
        $arguments += "-gselect=$Select"
    }

    & $GodotCommand @arguments
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
    if ($null -eq $previousTestMode) {
        Remove-Item Env:LUDUS_GUT_MODE -ErrorAction SilentlyContinue
    }
    else {
        $env:LUDUS_GUT_MODE = $previousTestMode
    }
}

exit $exitCode
