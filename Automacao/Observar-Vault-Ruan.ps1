[CmdletBinding()]
param(
    [string]$Origem = 'C:\Users\Rogerin\Documents\nvera\NOVA ERA MANAGE',
    [int]$EsperaMs = 3000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sincronizador = Join-Path $PSScriptRoot 'Sincronizar-Vault-Ruan.ps1'
if (-not (Test-Path -LiteralPath $sincronizador -PathType Leaf)) {
    throw "Sincronizador nao encontrado: $sincronizador"
}

& $sincronizador -Origem $Origem -Commit -Push

$watcher = [IO.FileSystemWatcher]::new($Origem)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true

Write-Host "Observando alteracoes em $Origem. Pressione Ctrl+C para encerrar."

try {
    while ($true) {
        $mudanca = $watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 60000)
        if ($mudanca.TimedOut) { continue }

        # Agrupa salvamentos em varias etapas feitos pelo Obsidian/editor.
        do {
            $proxima = $watcher.WaitForChanged([IO.WatcherChangeTypes]::All, $EsperaMs)
        } while (-not $proxima.TimedOut)

        try {
            & $sincronizador -Origem $Origem -Commit -Push
        }
        catch {
            Write-Error $_
        }
    }
}
finally {
    $watcher.Dispose()
}

