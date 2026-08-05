[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$lockPath = Join-Path $PSScriptRoot "gut.lock.json"
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
$targetPath = Join-Path $projectRoot "addons/gut"
$markerPath = Join-Path $targetPath ".ludus-gut-lock.json"
$templateRoot = Join-Path $projectRoot "tests/gut_templates"
$generatedRoot = Join-Path $projectRoot "tests/gut"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Test-MatchingInstall {
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        return $false
    }
    try {
        $installed = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        return ([string]$installed.version -eq [string]$lock.version) -and
            ([string]$installed.commit -eq [string]$lock.commit)
    }
    catch {
        return $false
    }
}

function Install-GutAddon {
    if (Test-Path -LiteralPath $targetPath) {
        if ((Test-MatchingInstall) -and -not $Force) {
            Write-Host "GUT $($lock.version) ya está instalado desde $($lock.commit)."
            return
        }
        if (-not $Force) {
            throw "Existe $targetPath, pero no coincide con tools/gut.lock.json. Repetí con -Force para reemplazarlo."
        }
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }

    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ludus-gut-" + [System.Guid]::NewGuid().ToString("N"))
    $archivePath = Join-Path $temporaryRoot "gut.zip"
    $extractPath = Join-Path $temporaryRoot "extract"

    try {
        New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
        Write-Host "Descargando GUT $($lock.version) desde el commit inmutable $($lock.commit)..."
        Invoke-WebRequest -Uri ([string]$lock.archive_url) -OutFile $archivePath
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        $archiveRoot = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
        if ($null -eq $archiveRoot) {
            throw "El archivo descargado no contiene la raíz esperada."
        }

        $sourceAddon = Join-Path $archiveRoot.FullName "addons/gut"
        $sourcePlugin = Join-Path $sourceAddon "plugin.cfg"
        if (-not (Test-Path -LiteralPath $sourcePlugin -PathType Leaf)) {
            throw "El commit descargado no contiene addons/gut/plugin.cfg."
        }

        $pluginText = Get-Content -LiteralPath $sourcePlugin -Raw
        $expectedVersionLine = 'version="' + [string]$lock.version + '"'
        if (-not $pluginText.Contains($expectedVersionLine)) {
            throw "La versión declarada por plugin.cfg no coincide con $($lock.version)."
        }

        New-Item -ItemType Directory -Path (Split-Path $targetPath -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $sourceAddon -Destination $targetPath -Recurse -Force
        Write-Utf8NoBom -Path $markerPath -Content ($lock | ConvertTo-Json -Depth 4)
        Write-Host "GUT $($lock.version) instalado en $targetPath."
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

function Materialize-GutTests {
    if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
        throw "No existe el directorio de plantillas: $templateRoot"
    }

    if (Test-Path -LiteralPath $generatedRoot) {
        Remove-Item -LiteralPath $generatedRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $generatedRoot -Force | Out-Null

    $templates = Get-ChildItem -LiteralPath $templateRoot -Filter "*.gd.in" -File -Recurse
    if ($templates.Count -eq 0) {
        throw "No se encontraron plantillas GUT en $templateRoot."
    }

    foreach ($template in $templates) {
        $relativePath = $template.FullName.Substring($templateRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $generatedRelativePath = $relativePath.Substring(0, $relativePath.Length - 3)
        $destination = Join-Path $generatedRoot $generatedRelativePath
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Write-Utf8NoBom -Path $destination -Content (Get-Content -LiteralPath $template.FullName -Raw)
    }

    Write-Host "$($templates.Count) scripts GUT materializados en $generatedRoot."
}

Install-GutAddon
Materialize-GutTests
Write-Host "Instalación reproducible de GUT completada."
