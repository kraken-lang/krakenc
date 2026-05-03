# vendor-clang.ps1 — copy a minimal clang toolchain into tools/llvm/
#
# Pulls clang.exe + lld-link.exe + the lib/clang/<v>/include headers from a
# system LLVM install into tools/llvm/, so krakenc has a self-contained
# toolchain it can invoke without the user having clang on PATH.
#
# Usage:   pwsh tools/vendor-clang.ps1
# Optional: -Source 'C:\Path\To\LLVM'   (default: C:\Program Files\LLVM)
#          -Force                       (overwrite existing tools/llvm/)
#
# tools/llvm/ is gitignored — each contributor runs this once locally.

param(
    [string]$Source = 'C:\Program Files\LLVM',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $projectRoot 'tools\llvm'

if ((Test-Path $dest) -and -not $Force) {
    Write-Host "tools/llvm already exists. Pass -Force to overwrite."
    exit 0
}

if (-not (Test-Path $Source)) {
    Write-Error "Source LLVM directory not found: $Source"
    exit 1
}

$srcBin = Join-Path $Source 'bin'
$srcLib = Join-Path $Source 'lib\clang'

foreach ($p in @($srcBin, $srcLib)) {
    if (-not (Test-Path $p)) {
        Write-Error "Required path missing: $p"
        exit 1
    }
}

Write-Host "Vendoring from: $Source"
Write-Host "           to: $dest"

if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'bin') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'lib\clang') | Out-Null

# Essentials only (the full bin/ is ~2.5GB; we only need the build pipeline)
$exes = @(
    'clang.exe',
    'lld-link.exe'
)

foreach ($exe in $exes) {
    $src = Join-Path $srcBin $exe
    if (-not (Test-Path $src)) {
        Write-Warning "Skipping missing: $exe"
        continue
    }
    $dst = Join-Path $dest "bin\$exe"
    Copy-Item $src $dst
    $size = (Get-Item $dst).Length
    Write-Host ("  bin/{0,-20} {1,8:N1} MB" -f $exe, ($size/1MB))
}

# Resource headers (stddef.h, stdint.h, etc.)
$clangVerDirs = Get-ChildItem $srcLib -Directory
foreach ($v in $clangVerDirs) {
    $dst = Join-Path $dest "lib\clang\$($v.Name)"
    Copy-Item -Recurse $v.FullName $dst
    $size = (Get-ChildItem $dst -Recurse -File | Measure-Object Length -Sum).Sum
    Write-Host ("  lib/clang/{0,-15} {1,8:N1} MB" -f $v.Name, ($size/1MB))
}

# Ship the upstream LICENSE so redistribution is legal (Apache 2.0 with LLVM exceptions)
$licenseSrc = Join-Path $Source 'LICENSE.TXT'
if (Test-Path $licenseSrc) {
    Copy-Item $licenseSrc (Join-Path $dest 'LICENSE.TXT')
    Write-Host "  LICENSE.TXT copied"
} else {
    Write-Warning "No LICENSE.TXT in $Source - fetch one from the LLVM release before redistributing"
}

# Stamp version for sanity
$verOutput = & (Join-Path $dest 'bin\clang.exe') --version 2>&1 | Select-Object -First 1
$verOutput | Out-File -Encoding utf8 (Join-Path $dest 'VERSION.txt')

$totalSize = (Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ""
Write-Host ("Done. Total bundle: {0:N1} MB" -f ($totalSize/1MB))
Write-Host "Version: $verOutput"
