#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$project = Join-Path $root 'tools\SetProfileZoom\SetProfileZoom.csproj'
$outDir = Join-Path $root 'tools'
$publishDir = Join-Path $outDir '_publish'

if (-not (Test-Path $project)) {
    throw "Missing project: $project"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}

& dotnet publish $project `
    -c Release `
    --self-contained false `
    -p:PublishSingleFile=true `
    -o $publishDir

if ($LASTEXITCODE -ne 0) {
    throw "SetProfileZoom publish failed with exit code $LASTEXITCODE"
}

$exe = Join-Path $publishDir 'SetProfileZoom.exe'
if (-not (Test-Path $exe)) {
    throw "SetProfileZoom.exe was not produced"
}

Copy-Item $exe (Join-Path $outDir 'SetProfileZoom.exe') -Force
$nativeSqlite = Join-Path $publishDir 'e_sqlite3.dll'
if (Test-Path $nativeSqlite) {
    Copy-Item $nativeSqlite (Join-Path $outDir 'e_sqlite3.dll') -Force
}

Write-Host "Built: $(Join-Path $outDir 'SetProfileZoom.exe')"
