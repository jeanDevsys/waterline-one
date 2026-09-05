[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$secretDirectory = Join-Path $projectDirectory '.secrets'
[System.IO.Directory]::CreateDirectory($secretDirectory) | Out-Null

# Solo la cuenta actual y SYSTEM leen las claves.
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$systemIdentity = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$secretAcl = Get-Acl -LiteralPath $secretDirectory
$secretAcl.SetAccessRuleProtection($true, $false)
foreach ($existingRule in @($secretAcl.Access)) {
    $secretAcl.RemoveAccessRuleAll($existingRule)
}
foreach ($identity in @($currentIdentity, $systemIdentity)) {
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $secretAcl.AddAccessRule($rule)
}
[System.IO.Directory]::SetAccessControl($secretDirectory, $secretAcl)

foreach ($secretName in @('mysql_root_password.txt', 'mysql_app_password.txt')) {
    $secretPath = Join-Path $secretDirectory $secretName
    if (Test-Path -LiteralPath $secretPath) {
        if ([System.IO.File]::ReadAllText($secretPath) -cnotmatch '^[0-9a-f]{64}$') {
            throw "El secreto existente $secretName tiene formato invalido. No se ha reemplazado."
        }
        continue
    }
    $randomBytes = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($randomBytes) } finally { $generator.Dispose() }
    $secretValue = [System.BitConverter]::ToString($randomBytes).Replace('-', '').ToLowerInvariant()
    [System.IO.File]::WriteAllText($secretPath, $secretValue, [System.Text.UTF8Encoding]::new($false))
    [Array]::Clear($randomBytes, 0, $randomBytes.Length)
    $secretValue = $null
}
Write-Host 'Credenciales locales preparadas en .secrets; las existentes se conservan.'
