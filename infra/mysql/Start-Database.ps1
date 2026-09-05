[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Get-Command docker -ErrorAction Stop | Out-Null
& (Join-Path $PSScriptRoot 'Initialize-Secrets.ps1')
Push-Location $projectDirectory
try {
    docker info --format '{{.ServerVersion}}'
    if ($LASTEXITCODE -ne 0) { throw 'Docker no esta disponible. Inicie Docker Desktop con contenedores Linux.' }
    docker compose up -d --build --wait --wait-timeout 240
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar MySQL. Revise docker compose logs mysql.' }
    docker compose ps
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el estado de MySQL.' }
    Write-Host 'Base waterline_one lista. Consulte BASE_DE_DATOS_MYSQL.txt para conectarse.'
} finally { Pop-Location }
