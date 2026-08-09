[CmdletBinding()]
param(
    [string]$NomeTarefa = 'Nova Era - Sincronizar Vault para Ruan'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$observador = Join-Path $PSScriptRoot 'Observar-Vault-Ruan.ps1'
$pwsh = (Get-Command powershell.exe).Source
$argumentos = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$observador`""

$acao = New-ScheduledTaskAction -Execute $pwsh -Argument $argumentos
$gatilho = New-ScheduledTaskTrigger -AtLogOn
$config = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $NomeTarefa -Action $acao -Trigger $gatilho -Settings $config -Description 'Sincroniza a versao filtrada do vault Nova Era e envia commits ao repositorio remoto.' -Force | Out-Null
Start-ScheduledTask -TaskName $NomeTarefa

Write-Host "Tarefa instalada e iniciada: $NomeTarefa"

