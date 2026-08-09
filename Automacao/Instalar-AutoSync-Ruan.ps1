[CmdletBinding()]
param(
    [string]$NomeTarefa = 'Nova Era - Sincronizar Vault para Ruan'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$observador = Join-Path $PSScriptRoot 'Observar-Vault-Ruan.ps1'
$pwsh = (Get-Command powershell.exe).Source
$argumentos = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$observador`""

$instaladoComo = ''
try {
    $acao = New-ScheduledTaskAction -Execute $pwsh -Argument $argumentos
    $gatilho = New-ScheduledTaskTrigger -AtLogOn
    $config = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask -TaskName $NomeTarefa -Action $acao -Trigger $gatilho -Settings $config -Description 'Sincroniza a versao filtrada do vault Nova Era e envia commits ao repositorio remoto.' -Force | Out-Null
    Start-ScheduledTask -TaskName $NomeTarefa
    $instaladoComo = 'tarefa agendada'
}
catch [Microsoft.Management.Infrastructure.CimException] {
    # Contas sem permissao para o Agendador usam a pasta Inicializar do usuario.
    $startup = [Environment]::GetFolderPath('Startup')
    $atalhoPath = Join-Path $startup 'Nova Era - AutoSync Ruan.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $atalho = $shell.CreateShortcut($atalhoPath)
    $atalho.TargetPath = $pwsh
    $atalho.Arguments = $argumentos
    $atalho.WorkingDirectory = Split-Path -Parent $observador
    $atalho.Description = 'Sincroniza o vault Nova Era para o Ruan.'
    $atalho.Save()

    Start-Process -FilePath $pwsh -ArgumentList $argumentos -WindowStyle Hidden
    $instaladoComo = "atalho de Inicializacao: $atalhoPath"
}

Write-Host "AutoSync instalado e iniciado como $instaladoComo"
