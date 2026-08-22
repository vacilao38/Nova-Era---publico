[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Origem = 'C:\Users\Rogerin\Documents\nvera\NOVA ERA MANAGE',
    [string]$Destino = '',
    [switch]$Commit,
    [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Destino)) {
    $Destino = Split-Path -Parent $PSScriptRoot
}

function Get-CaminhoRelativo {
    param([string]$Base, [string]$Caminho)

    return $Caminho.Substring($Base.Length).TrimStart('\', '/')
}

function Test-CaminhoOculto {
    param([string]$Relativo)

    foreach ($parte in ($Relativo -split '[\\/]')) {
        if ($parte.StartsWith('.')) {
            return $true
        }
    }
    return $false
}

function Test-MaterialPrivado {
    param([string]$Relativo)

    $r = $Relativo.Replace('\', '/')

    # Infraestrutura, backups e fontes brutas nao pertencem ao vault compartilhado.
    # O padrao de Exportacoes e propositalmente ASCII para funcionar no Windows PowerShell 5.1.
    if ($r -match '^0 Area de trabalho/(Backups|Exporta[^/]*)/') { return $true }
    if ($r -match '^8 INPUT/(Fontes WhatsApp [^/]+/|Temp(?: 2)?\.md$)') { return $true }
    # Apenas ASCII no padrao: Windows PowerShell 5.1 pode interpretar scripts UTF-8 sem BOM como ANSI.
    if ($r -match '(^|/)Anota[^/]*pedro\.md$') { return $true }

    # Todo o ramo de Pedro permanece na versao curada do destino e nunca e sobrescrito.
    if ($r -match '^1 Jogadores/Pedro(?:/|$)') { return $true }
    if ($r -match '^1 Jogadores/[^/]+/notas - [^/]+(?:/|$)') { return $true }
    if ($r -match '^2 Personagens/Personagens de jogadores/[^/]+/notas - [^/]+(?:/|$)') { return $true }
    if ($r -match '^0 Area de trabalho/Ideias/Minhas Ideias(?:/|$)') { return $true }
    if ($r -match '^0 Area de trabalho/Visao geral/VIsao geral - Personagens(?:/|$)') { return $true }
    if ($r -in @(
        '0 Area de trabalho/Pontos da Historia.md',
        '0 Area de trabalho/Revisao completa do Vault - Elder.md'
    )) { return $true }

    # As notas publicas da Elder ja foram sanitizadas no destino. Nao se pode
    # sobrescreve-las automaticamente com suas versoes completas da origem.
    $elder = '2 Personagens/Personagens de jogadores/Elder/'
    if ($r.StartsWith($elder, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    # O mesmo vale para NPCs ligados a trama pessoal da Elder/Pedro.
    $npcElder = '2 Personagens/NPCs/NPCs dos personagens dos Players/NPC - Elder/'
    if ($r.StartsWith($npcElder, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $false
}

function Test-ConteudoIgual {
    param([string]$A, [string]$B)

    if (-not (Test-Path -LiteralPath $B -PathType Leaf)) { return $false }
    $extensao = [IO.Path]::GetExtension($A)
    if ($extensao -in @('.md', '.txt', '.ps1')) {
        $textoA = [IO.File]::ReadAllText($A).Replace("`r`n", "`n").TrimEnd("`r", "`n")
        $textoB = [IO.File]::ReadAllText($B).Replace("`r`n", "`n").TrimEnd("`r", "`n")
        return $textoA -ceq $textoB
    }

    if ((Get-Item -LiteralPath $A).Length -ne (Get-Item -LiteralPath $B).Length) { return $false }
    return (Get-FileHash -LiteralPath $A -Algorithm SHA256).Hash -eq
           (Get-FileHash -LiteralPath $B -Algorithm SHA256).Hash
}

$origemResolvida = (Resolve-Path -LiteralPath $Origem).Path.TrimEnd('\')
$destinoResolvido = (Resolve-Path -LiteralPath $Destino).Path.TrimEnd('\')

if ($origemResolvida -eq $destinoResolvido) {
    throw 'Origem e destino nao podem ser a mesma pasta.'
}

$gitDir = Join-Path $destinoResolvido '.git'
if (-not (Test-Path -LiteralPath $gitDir -PathType Container)) {
    throw "O destino ainda nao e um repositorio Git: $destinoResolvido"
}

$estadoPath = Join-Path $gitDir 'ruan-sync-state.json'
$estadoAnterior = @()
$possuiEstado = Test-Path -LiteralPath $estadoPath -PathType Leaf
if ($possuiEstado) {
    $estadoLido = Get-Content -LiteralPath $estadoPath -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($null -ne $estadoLido.arquivos) {
        $estadoAnterior = @($estadoLido.arquivos)
    }
}

$permitidos = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$criados = 0
$atualizados = 0
$inalterados = 0
$removidos = 0

foreach ($arquivo in Get-ChildItem -LiteralPath $origemResolvida -Recurse -File -Force) {
    $relativo = Get-CaminhoRelativo -Base $origemResolvida -Caminho $arquivo.FullName
    if (Test-CaminhoOculto -Relativo $relativo) { continue }
    if (Test-MaterialPrivado -Relativo $relativo) { continue }

    [void]$permitidos.Add($relativo)
    $alvo = Join-Path $destinoResolvido $relativo

    if (Test-ConteudoIgual -A $arquivo.FullName -B $alvo) {
        $inalterados++
        continue
    }

    $jaExistia = Test-Path -LiteralPath $alvo -PathType Leaf
    if ($PSCmdlet.ShouldProcess($alvo, "Copiar de $($arquivo.FullName)")) {
        $pastaAlvo = Split-Path -Parent $alvo
        if (-not (Test-Path -LiteralPath $pastaAlvo)) {
            New-Item -ItemType Directory -Path $pastaAlvo -Force | Out-Null
        }
        Copy-Item -LiteralPath $arquivo.FullName -Destination $alvo -Force
        if ($jaExistia) { $atualizados++ } else { $criados++ }
    }
}

# Na primeira execucao, arquivos curados que so existem no Pinheral sao preservados.
# Depois dela, exclusoes da origem sao aplicadas apenas aos arquivos gerenciados.
if ($possuiEstado) {
    foreach ($relativo in $estadoAnterior) {
        if ($permitidos.Contains([string]$relativo)) { continue }
        $alvo = Join-Path $destinoResolvido ([string]$relativo)
        if (Test-Path -LiteralPath $alvo -PathType Leaf) {
            if ($PSCmdlet.ShouldProcess($alvo, 'Remover arquivo que deixou de existir na origem')) {
                Remove-Item -LiteralPath $alvo -Force
                $removidos++
            }
        }
    }
}

$estado = [ordered]@{
    origem = $origemResolvida
    destino = $destinoResolvido
    atualizado_em = (Get-Date).ToString('o')
    arquivos = @($permitidos | Sort-Object)
}
if (-not $WhatIfPreference) {
    $estado | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $estadoPath -Encoding UTF8
}

Write-Host "Sincronizacao concluida: $criados criado(s), $atualizados atualizado(s), $removidos removido(s), $inalterados inalterado(s)."

if ($Commit -and -not $WhatIfPreference) {
    & git -C $destinoResolvido add -A
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar as alteracoes no Git.' }

    & git -C $destinoResolvido diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        $mensagem = 'Sincroniza vault para Ruan - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        & git -C $destinoResolvido commit -m $mensagem
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o commit automatico.' }
    }
    elseif ($LASTEXITCODE -ne 0) {
        throw 'Falha ao verificar as alteracoes preparadas.'
    }

    if ($Push) {
        $remotos = @(& git -C $destinoResolvido remote)
        if ($remotos.Count -eq 0) {
            Write-Warning 'Push ignorado: nenhum remoto foi configurado ainda.'
        }
        else {
            & git -C $destinoResolvido push
            if ($LASTEXITCODE -ne 0) { throw 'Falha ao enviar as alteracoes ao remoto.' }
        }
    }
}
