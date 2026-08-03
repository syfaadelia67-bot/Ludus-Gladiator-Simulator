param(
    [string]$PackPath = ".\assets\placeholders\pack_000"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PackPath)) {
    Write-Error "No existe el Pack 000 en: $PackPath"
    exit 1
}

$resolved = (Resolve-Path -LiteralPath $PackPath).Path
Write-Host "Auditando Pack 000: $resolved"

$files = Get-ChildItem -LiteralPath $resolved -Recurse -File
$pngs = $files | Where-Object { $_.Extension -ieq ".png" }

Write-Host ""
Write-Host "Archivos totales: $($files.Count)"
Write-Host "PNG totales:      $($pngs.Count)"

$zeroByte = $files | Where-Object { $_.Length -eq 0 }
if ($zeroByte) {
    Write-Warning "Archivos vacíos:"
    $zeroByte | ForEach-Object { Write-Host " - $($_.FullName)" }
}

$unexpected = $files | Where-Object {
    $_.Extension.ToLowerInvariant() -notin @(".png", ".md", ".txt", ".ps1")
}
if ($unexpected) {
    Write-Warning "Extensiones inesperadas:"
    $unexpected | ForEach-Object { Write-Host " - $($_.FullName)" }
}

$badNames = $files | Where-Object {
    $_.Name -cmatch "[A-Z ]"
}
if ($badNames) {
    Write-Warning "Nombres con mayúsculas o espacios:"
    $badNames | ForEach-Object { Write-Host " - $($_.FullName)" }
}

$nameGroups = $files | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($nameGroups) {
    Write-Warning "Nombres repetidos en distintas rutas:"
    foreach ($group in $nameGroups) {
        Write-Host " - $($group.Name)"
        $group.Group | ForEach-Object { Write-Host "   $($_.FullName)" }
    }
}

$hashGroups = $pngs |
    Get-FileHash -Algorithm SHA256 |
    Group-Object Hash |
    Where-Object { $_.Count -gt 1 }

if ($hashGroups) {
    Write-Warning "PNG con contenido idéntico:"
    foreach ($group in $hashGroups) {
        Write-Host " - SHA256 $($group.Name)"
        $group.Group | ForEach-Object { Write-Host "   $($_.Path)" }
    }
}

$pngSignatureErrors = @()
foreach ($png in $pngs) {
    $bytes = [System.IO.File]::ReadAllBytes($png.FullName)
    $valid = $bytes.Length -ge 8 `
        -and $bytes[0] -eq 137 `
        -and $bytes[1] -eq 80 `
        -and $bytes[2] -eq 78 `
        -and $bytes[3] -eq 71 `
        -and $bytes[4] -eq 13 `
        -and $bytes[5] -eq 10 `
        -and $bytes[6] -eq 26 `
        -and $bytes[7] -eq 10

    if (-not $valid) {
        $pngSignatureErrors += $png
    }
}

if ($pngSignatureErrors) {
    Write-Warning "Archivos .png con firma inválida:"
    $pngSignatureErrors | ForEach-Object { Write-Host " - $($_.FullName)" }
}

Write-Host ""
if (-not $zeroByte -and -not $unexpected -and -not $pngSignatureErrors) {
    Write-Host "Auditoría básica completada sin errores críticos."
    exit 0
}

Write-Error "La auditoría encontró errores críticos."
exit 2
