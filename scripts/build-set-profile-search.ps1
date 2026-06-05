#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$project = Join-Path $root 'tools\SetProfileSearch\SetProfileSearch.csproj'
$outDir = Join-Path $root 'tools'
$publishDir = Join-Path $outDir '_publish-search'

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
    throw "SetProfileSearch publish failed with exit code $LASTEXITCODE"
}

$exe = Join-Path $publishDir 'SetProfileSearch.exe'
if (-not (Test-Path $exe)) {
    throw "SetProfileSearch.exe was not produced"
}

Copy-Item $exe (Join-Path $outDir 'SetProfileSearch.exe') -Force
Write-Host "Built: $(Join-Path $outDir 'SetProfileSearch.exe')"
