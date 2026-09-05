[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$backupDirectory = Join-Path $projectDirectory 'backups'
[System.IO.Directory]::CreateDirectory($backupDirectory) | Out-Null
$backupName = 'waterline_one_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N') + '.sql'
$backupPath = Join-Path $backupDirectory $backupName
$containerBackupPath = '/tmp/' + $backupName
Push-Location $projectDirectory
try {
    # El respaldo se crea dentro del contenedor; la clave no se expone.
    try {
        docker compose exec -T mysql bash /usr/local/bin/waterline-backup.sh $containerBackupPath
        if ($LASTEXITCODE -ne 0) { throw 'Fallo el respaldo SQL; no se copio ningun archivo.' }
        docker compose cp ('mysql:' + $containerBackupPath) $backupPath
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo copiar el respaldo a la carpeta local.' }
    } finally {
        docker compose exec -T mysql rm -f -- $containerBackupPath
        if ($LASTEXITCODE -ne 0) { Write-Warning 'No se pudo limpiar el archivo temporal del respaldo dentro del contenedor.' }
    }
    Write-Host "Respaldo creado: $backupPath"
} finally { Pop-Location }
