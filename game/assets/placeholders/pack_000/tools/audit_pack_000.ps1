param(
    [string]$PackPath = ".\assets\placeholders\pack_000"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PackPath)) {
    Write-Error "Pack 000 not found: $PackPath"
    exit 1
}

$resolved = (Resolve-Path -LiteralPath $PackPath).Path
Write-Host "Auditing Pack 000: $resolved"

$files = Get-ChildItem -LiteralPath $resolved -Recurse -File
$pngs = $files | Where-Object { $_.Extension -ieq ".png" }

Write-Host ""
Write-Host "Total files: $($files.Count)"
Write-Host "Total PNG:   $($pngs.Count)"

$zeroByte = $files | Where-Object { $_.Length -eq 0 }
if ($zeroByte) {
    Write-Warning "Empty files:"
    $zeroByte | ForEach-Object { Write-Host " - $($_.FullName)" }
}

$unexpected = $files | Where-Object {
    $_.Extension.ToLowerInvariant() -notin @(".png", ".md", ".txt", ".ps1")
}
if ($unexpected) {
    Write-Warning "Unexpected extensions:"
    $unexpected | ForEach-Object { Write-Host " - $($_.FullName)" }
}

# Naming convention is enforced only for production PNG files.
$badPngNames = $pngs | Where-Object {
    $_.Name -cmatch "[A-Z ]"
}
if ($badPngNames) {
    Write-Warning "PNG names with uppercase letters or spaces:"
    $badPngNames | ForEach-Object { Write-Host " - $($_.FullName)" }
}

$nameGroups = $pngs | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($nameGroups) {
    Write-Warning "Repeated PNG names in different paths:"
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
    Write-Warning "PNG files with identical content (manual review):"
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
    Write-Warning "Files with .png extension but invalid PNG signature:"
    $pngSignatureErrors | ForEach-Object { Write-Host " - $($_.FullName)" }
}

Write-Host ""
if (-not $zeroByte -and -not $unexpected -and -not $pngSignatureErrors) {
    Write-Host "Audit completed without critical errors."
    exit 0
}

Write-Error "Audit found critical errors."
exit 2
