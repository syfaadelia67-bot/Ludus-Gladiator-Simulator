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

function Resolve-GodotExecutable {
    param([string]$Command)

    if (Test-Path -LiteralPath $Command -PathType Leaf) {
        return [System.IO.Path]::GetFullPath($Command)
    }

    $resolved = Get-Command -Name $Command -CommandType Application -ErrorAction Stop | Select-Object -First 1
    if ($null -eq $resolved -or [string]::IsNullOrWhiteSpace([string]$resolved.Source)) {
        throw "No se pudo resolver el ejecutable de Godot: $Command"
    }
    return [string]$resolved.Source
}

function Invoke-GodotProcess {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    # Windows PowerShell may return immediately for GUI-subsystem executables
    # and leave LASTEXITCODE undefined. Start-Process -Wait guarantees strict
    # ordering between the import pass and the GUT process.
    $process = Start-Process `
        -FilePath $Executable `
        -ArgumentList $Arguments `
        -WorkingDirectory $projectRoot `
        -NoNewWindow `
        -Wait `
        -PassThru
    return [int]$process.ExitCode
}

$godotExecutable = Resolve-GodotExecutable -Command $GodotCommand
$quotedProjectRoot = '"' + $projectRoot + '"'
$previousTestMode = [Environment]::GetEnvironmentVariable("LUDUS_GUT_MODE", "Process")
$env:LUDUS_GUT_MODE = "1"
$exitCode = 1

try {
    $importArguments = @(
        "--headless",
        "--import",
        "--path", $quotedProjectRoot
    )
    $importExitCode = Invoke-GodotProcess -Executable $godotExecutable -Arguments $importArguments
    if ($importExitCode -ne 0) {
        throw "Godot no pudo importar el proyecto y registrar las clases de GUT (exit $importExitCode)."
    }

    $gutArguments = @(
        "--headless",
        "-d",
        "--path", $quotedProjectRoot,
        "-s", "tools/ludus_gut_cmdln.gd",
        "-gconfig=res://.gutconfig.json",
        "-gexit"
    )
    if (-not [string]::IsNullOrWhiteSpace($Select)) {
        $gutArguments += "-gselect=$Select"
    }

    $exitCode = Invoke-GodotProcess -Executable $godotExecutable -Arguments $gutArguments
}
finally {
    if ($null -eq $previousTestMode) {
        Remove-Item Env:LUDUS_GUT_MODE -ErrorAction SilentlyContinue
    }
    else {
        $env:LUDUS_GUT_MODE = $previousTestMode
    }
}

exit $exitCode
