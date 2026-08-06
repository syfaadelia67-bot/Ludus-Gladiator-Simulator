[CmdletBinding()]
param(
    [string]$GodotCommand = "godot",
    [string]$Select = "",
    [switch]$Reinstall,
    [switch]$ShowFullOutput,
    [int]$ImportTimeoutSeconds = 180,
    [int]$GutTimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$installer = Join-Path $PSScriptRoot "install_gut_9_5.ps1"
$resultsRoot = Join-Path $projectRoot "test-results"
$installArguments = @()
if ($Reinstall) {
    $installArguments += "-Force"
}
& $installer @installArguments

New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null

$importStdOut = Join-Path $resultsRoot "gut-import.stdout.log"
$importStdErr = Join-Path $resultsRoot "gut-import.stderr.log"
$gutStdOut = Join-Path $resultsRoot "gut.stdout.log"
$gutStdErr = Join-Path $resultsRoot "gut.stderr.log"
$combinedLog = Join-Path $resultsRoot "gut-console.log"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Initialize-LogFile {
    param([string]$Path)
    [System.IO.File]::WriteAllText($Path, "", $utf8NoBom)
}

foreach ($logPath in @($importStdOut, $importStdErr, $gutStdOut, $gutStdErr, $combinedLog)) {
    Initialize-LogFile -Path $logPath
}

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
        [string[]]$Arguments,
        [string]$StandardOutputPath,
        [string]$StandardErrorPath,
        [int]$TimeoutSeconds
    )

    Initialize-LogFile -Path $StandardOutputPath
    Initialize-LogFile -Path $StandardErrorPath

    $process = Start-Process `
        -FilePath $Executable `
        -ArgumentList $Arguments `
        -WorkingDirectory $projectRoot `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $StandardOutputPath `
        -RedirectStandardError $StandardErrorPath

    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        try {
            $process.Kill()
            $process.WaitForExit()
        }
        catch {
            Add-Content -LiteralPath $StandardErrorPath -Value "No se pudo terminar el proceso Godot bloqueado: $($_.Exception.Message)"
        }
        Add-Content -LiteralPath $StandardErrorPath -Value "TIMEOUT: Godot superó $TimeoutSeconds segundos y fue terminado por run_gut.ps1."
        return [pscustomobject]@{
            ExitCode = 124
            TimedOut = $true
        }
    }

    return [pscustomobject]@{
        ExitCode = [int]$process.ExitCode
        TimedOut = $false
    }
}

function Get-LogLines {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
}

function Write-CombinedLog {
    $sections = @(
        "===== GUT IMPORT STDOUT =====",
        (Get-LogLines -Path $importStdOut),
        "===== GUT IMPORT STDERR =====",
        (Get-LogLines -Path $importStdErr),
        "===== GUT TEST STDOUT =====",
        (Get-LogLines -Path $gutStdOut),
        "===== GUT TEST STDERR =====",
        (Get-LogLines -Path $gutStdErr)
    )
    $sections | Set-Content -LiteralPath $combinedLog -Encoding UTF8
}

function Show-ConciseResult {
    param([int]$ExitCode)

    Write-CombinedLog
    $allLines = @(Get-LogLines -Path $gutStdOut) + @(Get-LogLines -Path $gutStdErr)

    if ($ShowFullOutput) {
        $allLines | ForEach-Object { Write-Host $_ }
    }
    else {
        $importantPattern = "(?i)(SCRIPT ERROR|ERROR:|FAILED|FAIL:|FAILURES|PASSING|PENDING|ORPHAN|TESTS|ASSERT|SUMMARY|TOTALS|PARSE ERROR|COMPILE ERROR|TIMEOUT)"
        $important = @($allLines | Where-Object { $_ -match $importantPattern })
        if ($important.Count -gt 0) {
            Write-Host ""
            Write-Host "Resumen de GUT (últimas líneas relevantes):"
            $important | Select-Object -Last 120 | ForEach-Object { Write-Host $_ }
        }
        elseif ($allLines.Count -gt 0) {
            Write-Host ""
            Write-Host "Últimas líneas de GUT:"
            $allLines | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
        }
    }

    Write-Host ""
    Write-Host "Código de salida GUT: $ExitCode"
    Write-Host "Log completo: $combinedLog"
    Write-Host "JUnit XML: $(Join-Path $resultsRoot 'gut.xml')"
}

$godotExecutable = Resolve-GodotExecutable -Command $GodotCommand
$quotedProjectRoot = '"' + $projectRoot + '"'
$previousTestMode = [Environment]::GetEnvironmentVariable("LUDUS_GUT_MODE", "Process")
$env:LUDUS_GUT_MODE = "1"
$exitCode = 1

try {
    Write-Host "Importando clases de GUT (timeout: $ImportTimeoutSeconds s)..."
    $importArguments = @(
        "--headless",
        "--import",
        "--path", $quotedProjectRoot
    )
    $importResult = Invoke-GodotProcess `
        -Executable $godotExecutable `
        -Arguments $importArguments `
        -StandardOutputPath $importStdOut `
        -StandardErrorPath $importStdErr `
        -TimeoutSeconds $ImportTimeoutSeconds
    if ($importResult.ExitCode -ne 0) {
        Write-CombinedLog
        Write-Host "La importación de Godot falló con código $($importResult.ExitCode)."
        Write-Host "Log completo: $combinedLog"
        @(Get-LogLines -Path $importStdOut) + @(Get-LogLines -Path $importStdErr) |
            Select-Object -Last 80 |
            ForEach-Object { Write-Host $_ }
        throw "Godot no pudo importar el proyecto y registrar las clases de GUT (exit $($importResult.ExitCode))."
    }

    Write-Host "Ejecutando GUT 9.5.0 (timeout: $GutTimeoutSeconds s)..."
    $gutArguments = @(
        "--headless",
        "--path", $quotedProjectRoot,
        "-s", "tools/ludus_gut_cmdln.gd",
        "-gconfig=res://.gutconfig.json",
        "-gexit"
    )
    if (-not [string]::IsNullOrWhiteSpace($Select)) {
        $gutArguments += "-gselect=$Select"
    }

    $gutResult = Invoke-GodotProcess `
        -Executable $godotExecutable `
        -Arguments $gutArguments `
        -StandardOutputPath $gutStdOut `
        -StandardErrorPath $gutStdErr `
        -TimeoutSeconds $GutTimeoutSeconds
    $exitCode = $gutResult.ExitCode
    Show-ConciseResult -ExitCode $exitCode
}
finally {
    Write-CombinedLog
    if ($null -eq $previousTestMode) {
        Remove-Item Env:LUDUS_GUT_MODE -ErrorAction SilentlyContinue
    }
    else {
        $env:LUDUS_GUT_MODE = $previousTestMode
    }
}

exit $exitCode
