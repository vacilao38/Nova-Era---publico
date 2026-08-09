param(
  [string]$OutDir = "C:\Users\Rogerin\Documents\Obsidian Vault\NOVA ERA MANAGE\7 Regras\SISTEMA\D&D 5e - Livro do Jogador",
  [string]$RawTextPath = "C:\Users\Rogerin\Documents\Obsidian Vault\NOVA ERA MANAGE\7 Regras\SISTEMA\D&D 5e - Livro do Jogador\_extração\poppler-raw.txt"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$TextInfo = (Get-Culture).TextInfo

function Join-Part { param([string]$A,[string]$B) [IO.Path]::Combine($A,$B) }
function Ensure-Dir { param([string]$Path) if(-not(Test-Path -Path $Path)){ New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8 { param([string]$Path,[string]$Text) $parent=Split-Path -Parent $Path; if($parent){Ensure-Dir $parent}; [IO.File]::WriteAllText($Path,$Text,$Utf8NoBom) }
function Escape-Yaml { param([string]$Text) if($null -eq $Text){return ""}; return ($Text -replace '"','\"') }
function Slugify-FileName {
  param([string]$Name)
  $clean = $Name.Trim()
  foreach($ch in [IO.Path]::GetInvalidFileNameChars()){ $clean = $clean.Replace([string]$ch,"-") }
  $clean = $clean -replace '\s+',' '
  $clean = $clean.Trim('. ')
  if($clean.Length -gt 120){ $clean = $clean.Substring(0,120).Trim() }
  if($clean.Length -eq 0){ $clean = "Sem titulo" }
  return $clean
}

function New-Section {
  param([string]$Title,[string]$Folder,[int]$PageStart,[string]$Chapter,[string[]]$Tags)
  [pscustomobject]@{ Title=$Title; Folder=$Folder; PageStart=$PageStart; PageEnd=$PageStart; Chapter=$Chapter; Tags=$Tags }
}

function Get-Sections {
  $s = New-Object Collections.ArrayList
  [void]$s.Add((New-Section "Prefacio" "Índices" 3 "Pré-texto" @("dnd/regras/indice")))
  [void]$s.Add((New-Section "Introdução" "Índices" 5 "Introdução" @("dnd/regras/introducao")))
  [void]$s.Add((New-Section "Mundos de Aventura" "Índices" 5 "Introdução" @("dnd/regras/introducao")))
  [void]$s.Add((New-Section "Usando Este Livro" "Índices" 6 "Introdução" @("dnd/regras/introducao")))
  [void]$s.Add((New-Section "Como Jogar" "Índices" 6 "Introdução" @("dnd/regras/introducao")))
  [void]$s.Add((New-Section "Aventuras" "Índices" 7 "Introdução" @("dnd/regras/aventura")))
  [void]$s.Add((New-Section "Criação de Personagem" "01 Criação de Personagem" 11 "Capítulo 1" @("dnd/regras/personagem")))
  [void]$s.Add((New-Section "Escolha uma Raça" "01 Criação de Personagem" 11 "Capítulo 1" @("dnd/regras/personagem","dnd/regras/racas")))
  [void]$s.Add((New-Section "Escolha uma Classe" "01 Criação de Personagem" 12 "Capítulo 1" @("dnd/regras/personagem","dnd/regras/classes")))
  [void]$s.Add((New-Section "Determinando Valores de Habilidade" "01 Criação de Personagem" 13 "Capítulo 1" @("dnd/regras/personagem","dnd/regras/atributos")))
  [void]$s.Add((New-Section "Além do 1° Nível" "01 Criação de Personagem" 15 "Capítulo 1" @("dnd/regras/personagem","dnd/regras/nivel")))
  [void]$s.Add((New-Section "Raças" "02 Raças" 17 "Capítulo 2" @("dnd/regras/racas")))
  foreach($r in @(@("Escolhendo uma Raça",17),@("Anão",18),@("Elfo",21),@("Halfling",26),@("Humano",29),@("Draconato",32),@("Gnomo",35),@("Meio-Elfo",38),@("Meio-Orc",40),@("Tiefling",42))){ [void]$s.Add((New-Section $r[0] "02 Raças" $r[1] "Capítulo 2" @("dnd/regras/racas"))) }
  [void]$s.Add((New-Section "Classes" "03 Classes" 45 "Capítulo 3" @("dnd/regras/classes")))
  [void]$s.Add((New-Section "Características de Classe" "03 Classes" 45 "Capítulo 3" @("dnd/regras/classes")))
  foreach($c in @(@("Bárbaro",46),@("Bardo",51),@("Bruxo",56),@("Clérigo",63),@("Druida",71),@("Feiticeiro",77),@("Guerreiro",83),@("Ladino",89),@("Mago",94),@("Monge",102),@("Paladino",108),@("Patrulheiro",115))){ [void]$s.Add((New-Section $c[0] "03 Classes" $c[1] "Capítulo 3" @("dnd/regras/classes"))) }
  [void]$s.Add((New-Section "Personalidade e Antecedentes" "04 Personalidade e Antecedentes" 121 "Capítulo 4" @("dnd/regras/antecedentes")))
  foreach($p in @(@("Detalhes do Personagem",123),@("Inspiração",127),@("Antecedentes",127))){ [void]$s.Add((New-Section $p[0] "04 Personalidade e Antecedentes" $p[1] "Capítulo 4" @("dnd/regras/antecedentes"))) }
  [void]$s.Add((New-Section "Equipamento" "05 Equipamento" 143 "Capítulo 5" @("dnd/regras/equipamento")))
  foreach($e in @(@("Equipamento Inicial",145),@("Riqueza",145),@("Armaduras e Escudos",146),@("Armas",148),@("Equipamento de Aventura",150),@("Ferramentas",156),@("Montarias e Veículos",157),@("Comércio de Bens",159),@("Despesas",159),@("Bugigangas",161))){ [void]$s.Add((New-Section $e[0] "05 Equipamento" $e[1] "Capítulo 5" @("dnd/regras/equipamento"))) }
  [void]$s.Add((New-Section "Opções de Customização" "06 Opções de Customização" 163 "Capítulo 6" @("dnd/regras/customizacao")))
  [void]$s.Add((New-Section "Multiclasse" "06 Opções de Customização" 165 "Capítulo 6" @("dnd/regras/customizacao","dnd/regras/classes")))
  [void]$s.Add((New-Section "Talentos" "06 Opções de Customização" 167 "Capítulo 6" @("dnd/regras/customizacao","dnd/regras/talentos")))
  [void]$s.Add((New-Section "Atributos" "07 Atributos" 175 "Capítulo 7" @("dnd/regras/atributos")))
  foreach($a in @(@("Valores de Habilidades e Modificadores",175),@("Vantagem e Desvantagem",175),@("Bônus de Proficiência",175),@("Testes de Habilidade",176),@("Usando Cada Habilidade",177),@("Testes de Resistência",181))){ [void]$s.Add((New-Section $a[0] "07 Atributos" $a[1] "Capítulo 7" @("dnd/regras/atributos"))) }
  [void]$s.Add((New-Section "Aventurando-se" "08 Aventurando-se" 183 "Capítulo 8" @("dnd/regras/aventura")))
  foreach($av in @(@("Tempo",183),@("Movimento",183),@("O Ambiente",185),@("Interação Social",187),@("Descanso",188),@("Entre Aventuras",188))){ [void]$s.Add((New-Section $av[0] "08 Aventurando-se" $av[1] "Capítulo 8" @("dnd/regras/aventura"))) }
  [void]$s.Add((New-Section "Combate" "09 Combate" 191 "Capítulo 9" @("dnd/regras/combate")))
  foreach($co in @(@("A Ordem do Combate",191),@("Movimento e Posição",192),@("Ações em Combate",194),@("Realizando um Ataque",195),@("Cobertura",198),@("Dano e Cura",198),@("Combate Montado",200),@("Combate Submerso",200))){ [void]$s.Add((New-Section $co[0] "09 Combate" $co[1] "Capítulo 9" @("dnd/regras/combate"))) }
  [void]$s.Add((New-Section "Magia" "10 Magia" 203 "Capítulo 10" @("dnd/regras/magia")))
  [void]$s.Add((New-Section "O que é uma Magia" "10 Magia" 203 "Capítulo 10" @("dnd/regras/magia")))
  [void]$s.Add((New-Section "Conjurando uma Magia" "10 Magia" 204 "Capítulo 10" @("dnd/regras/magia")))
  [void]$s.Add((New-Section "Magias" "11 Magias" 209 "Capítulo 11" @("dnd/regras/magias")))
  [void]$s.Add((New-Section "Lista de Magias" "11 Magias" 209 "Capítulo 11" @("dnd/regras/magias")))
  [void]$s.Add((New-Section "Descrição de Magias" "11 Magias" 215 "Capítulo 11" @("dnd/regras/magias")))
  [void]$s.Add((New-Section "Condições" "Apêndices" 290 "Apêndice A" @("dnd/regras/condicoes")))
  [void]$s.Add((New-Section "Deuses do Multiverso" "Apêndices" 293 "Apêndice B" @("dnd/regras/apendices")))
  [void]$s.Add((New-Section "Os Planos de Existência" "Apêndices" 300 "Apêndice C" @("dnd/regras/apendices")))
  [void]$s.Add((New-Section "O Plano Material" "Apêndices" 301 "Apêndice C" @("dnd/regras/apendices")))
  [void]$s.Add((New-Section "Além do Material" "Apêndices" 302 "Apêndice C" @("dnd/regras/apendices")))
  [void]$s.Add((New-Section "Estatísticas de Criaturas" "Apêndices" 304 "Apêndice D" @("dnd/regras/apendices")))
  [void]$s.Add((New-Section "Leitura Inspiradora" "Apêndices" 312 "Apêndice E" @("dnd/regras/apendices")))
  [void]$s.Add((New-Section "Ficha de Personagem" "Índices" 313 "Ficha" @("dnd/regras/ficha")))
  @($s)
}

function Set-SectionEnds {
  param([object[]]$Sections)
  $ordered = @($Sections | Sort-Object @{Expression={[int]$_.PageStart}}, @{Expression={[string]$_.Title}})
  for($i=0; $i -lt $ordered.Count; $i++){
    $next = $null
    for($j=$i+1; $j -lt $ordered.Count; $j++){
      if([int]$ordered[$j].PageStart -gt [int]$ordered[$i].PageStart){ $next=[int]$ordered[$j].PageStart; break }
    }
    $ordered[$i].PageEnd = if($next){ [Math]::Max($ordered[$i].PageStart, $next-1) } else { 314 }
  }
  $Sections
}

function Get-RelatedLinks {
  param($Section)
  $links = New-Object Collections.ArrayList
  [void]$links.Add("00 Sumário")
  switch -Regex ($Section.Folder) {
    "01 Criação" { foreach($x in @("Raças","Classes","Atributos","Equipamento","Antecedentes")){[void]$links.Add($x)}; break }
    "02 Raças" { foreach($x in @("Criação de Personagem","Classes","Atributos")){[void]$links.Add($x)}; break }
    "03 Classes" { foreach($x in @("Criação de Personagem","Atributos","Equipamento","Magia","Lista de Magias")){[void]$links.Add($x)}; break }
    "04 Personalidade" { foreach($x in @("Criação de Personagem","Inspiração","Testes de Habilidade")){[void]$links.Add($x)}; break }
    "05 Equipamento" { foreach($x in @("Criação de Personagem","Classes","Combate","Armas","Armaduras e Escudos")){[void]$links.Add($x)}; break }
    "06 Opções" { foreach($x in @("Classes","Talentos","Atributos")){[void]$links.Add($x)}; break }
    "07 Atributos" { foreach($x in @("Testes de Habilidade","Testes de Resistência","Combate")){[void]$links.Add($x)}; break }
    "08 Aventurando" { foreach($x in @("Atributos","Testes de Habilidade","Combate","Descanso")){[void]$links.Add($x)}; break }
    "09 Combate" { foreach($x in @("Ações em Combate","Dano e Cura","Condições","Armas","Magia")){[void]$links.Add($x)}; break }
    "10 Magia" { foreach($x in @("Conjurando uma Magia","Lista de Magias","Descrição de Magias","Classes")){[void]$links.Add($x)}; break }
    "11 Magias" { foreach($x in @("Magia","Conjurando uma Magia","Lista de Magias","Classes")){[void]$links.Add($x)}; break }
    "Apêndices" { foreach($x in @("Condições","Combate","Magia","Aventurando-se")){[void]$links.Add($x)}; break }
    default { foreach($x in @("Criação de Personagem","Combate","Magia")){[void]$links.Add($x)} }
  }
  @($links | Where-Object { $_ -and $_ -ne $Section.Title } | Select-Object -Unique)
}

function Get-PrintedPage {
  param([string]$PageText,[int]$Fallback)
  $lines = @($PageText -split "`r?`n")
  $sample = @()
  $sample += $lines | Select-Object -First 5
  $sample += $lines | Select-Object -Last 5
  foreach($line in $sample){
    if($line -match '^\s*(\d{1,3})\s*$'){ return [int]$Matches[1] }
  }
  return $Fallback
}

function Is-UpperHeading {
  param([string]$Line)
  $t = $Line.Trim()
  if($t.Length -lt 3 -or $t.Length -gt 90){ return $false }
  if($t -match '^\d+$'){ return $false }
  if($t -cmatch '\p{Ll}'){ return $false }
  if($t -cnotmatch '[A-ZÁÉÍÓÚÂÊÔÃÕÇ]'){ return $false }
  if($t -match '[\.,;]$'){ return $false }
  return $true
}

function Normalize-Key {
  param([string]$Text)
  if($null -eq $Text){ return "" }
  $d = $Text.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach($ch in $d.ToCharArray()){
    if([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark){
      [void]$sb.Append($ch)
    }
  }
  (($sb.ToString()).ToUpperInvariant() -replace '[^A-Z0-9]+','')
}

function Trim-ToSectionStart {
  param([object[]]$LineObjects,[string]$Title)
  if($LineObjects.Count -eq 0){ return $LineObjects }
  $target = Normalize-Key $Title
  for($i=0; $i -lt $LineObjects.Count; $i++){
    $line = $LineObjects[$i].Text.Trim()
    if($line.Length -eq 0){ continue }
    $norm = Normalize-Key $line
    $nextNorm = ""
    if($i + 1 -lt $LineObjects.Count){ $nextNorm = Normalize-Key ($line + " " + $LineObjects[$i+1].Text.Trim()) }
    $isCandidate = (Is-UpperHeading $line) -or ($norm -match '^CAPITULO\d+')
    if($isCandidate -and ($norm -eq $target -or $norm.EndsWith($target) -or $nextNorm -eq $target -or $nextNorm.EndsWith($target))){
      return @($LineObjects[$i..($LineObjects.Count-1)])
    }
  }
  return $LineObjects
}

function To-NiceHeading {
  param([string]$Line)
  $t = ($Line.Trim() -replace '\s+',' ')
  if($t -match '^CAPÍTULO|^PARTE|^APÊNDICE'){ return $t }
  return $TextInfo.ToTitleCase($t.ToLower())
}

function Flush-Para {
  param([Collections.ArrayList]$Out,[ref]$Para)
  $p = $Para.Value.Trim()
  $Para.Value = ""
  if($p.Length -gt 0){ [void]$Out.Add($p); [void]$Out.Add("") }
}

function Add-ParaLine {
  param([ref]$Para,[string]$Line)
  $t = ($Line.Trim() -replace '\s+',' ')
  if($t.Length -eq 0){ return }
  if($t -cmatch '^([A-ZÁÉÍÓÚÂÊÔÃÕÇ][A-Za-zÀ-ÿ0-9çÇ\- ]{2,45})\.\s+(.+)$'){
    $t = "**$($Matches[1]).** $($Matches[2])"
  }
  if($Para.Value.EndsWith("-")){
    $Para.Value = $Para.Value + $t
  } elseif($Para.Value.Length -gt 0){
    $Para.Value = $Para.Value + " " + $t
  } else {
    $Para.Value = $t
  }
}

function Try-TableBlock {
  param([string[]]$Lines,[int]$Index,[ref]$NextIndex,[ref]$Converted)
  $line = $Lines[$Index].Trim()
  if($Index + 2 -ge $Lines.Count){ return @() }
  $next = $Lines[$Index+1].Trim()
  if($line.Length -gt 80){ return @() }
  if($line -cnotmatch '^(Tamanho|Nível|Nivel|Classe|Arma|Armadura|Item|Serviço|Servico|Custo|Ritmo|Terreno|Magia|Dado|Categoria)\b'){ return @() }
  if($next.Length -eq 0 -or (Is-UpperHeading $next)){ return @() }
  $block = New-Object Collections.ArrayList
  $j = $Index
  while($j -lt $Lines.Count){
    $t = $Lines[$j].Trim()
    if($t.Length -eq 0){ break }
    if($j -gt $Index -and (Is-UpperHeading $t)){ break }
    if($t.Length -gt 140){ break }
    if($j -gt $Index -and $t -match '\.\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ]'){ break }
    [void]$block.Add($t)
    $j++
    if($block.Count -ge 18){ break }
  }
  if($block.Count -lt 3){ return @() }
  $rows = New-Object Collections.ArrayList
  foreach($b in $block){
    if($b -match '\s{2,}'){
      $cols = @($b -split '\s{2,}' | Where-Object { $_.Trim().Length -gt 0 })
    } else {
      $m = [regex]::Match($b,'^(\S+(?:\s+\S+){0,2})\s+(.+)$')
      if(-not $m.Success){ return @() }
      $cols = @($m.Groups[1].Value.Trim(), $m.Groups[2].Value.Trim())
    }
    if($cols.Count -lt 2){ return @() }
    [void]$rows.Add($cols)
  }
  $max = ($rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
  if($max -lt 2){ return @() }
  $out = New-Object Collections.ArrayList
  $header = @($rows[0]); while($header.Count -lt $max){ $header += "" }
  [void]$out.Add("| " + ($header -join " | ") + " |")
  [void]$out.Add("| " + ((1..$max | ForEach-Object { "---" }) -join " | ") + " |")
  for($r=1; $r -lt $rows.Count; $r++){
    $row = @($rows[$r]); while($row.Count -lt $max){ $row += "" }
    [void]$out.Add("| " + ($row -join " | ") + " |")
  }
  $NextIndex.Value = $j
  $Converted.Value++
  @($out)
}

function Format-RawLines {
  param([string[]]$Lines,[ref]$TableCount,[ref]$TableCandidates)
  $clean = New-Object Collections.ArrayList
  foreach($line in $Lines){
    $t = $line.TrimEnd()
    if($t -match '^\s*\d{1,3}\s*$'){ continue }
    if($t -match '^\s*(LIVRO DO JOGADOR|DUNGEONS & DRAGONS)\s*$'){ continue }
    [void]$clean.Add($t)
  }
  $out = New-Object Collections.ArrayList
  $para = ""
  $i = 0
  while($i -lt $clean.Count){
    $line = [string]$clean[$i]
    $trim = $line.Trim()
    if($trim.Length -eq 0){ Flush-Para $out ([ref]$para); $i++; continue }

    if(Is-UpperHeading $trim){
      $heading = $trim
      if($heading -notmatch '^CAPÍTULO|^PARTE|^APÊNDICE'){
        while($i + 1 -lt $clean.Count -and (Is-UpperHeading ([string]$clean[$i+1])) -and ($heading.Length + ([string]$clean[$i+1]).Trim().Length) -lt 95){
          $candidate = ([string]$clean[$i+1]).Trim()
          if($candidate -match '^CAPÍTULO|^PARTE|^APÊNDICE'){ break }
          $heading += " " + $candidate
          $i++
        }
      }
      Flush-Para $out ([ref]$para)
      [void]$out.Add("## " + (To-NiceHeading $heading))
      [void]$out.Add("")
      $i++
      continue
    }

    $nextIndex = $i
    $converted = $TableCount.Value
    $tbl = Try-TableBlock (@($clean)) $i ([ref]$nextIndex) ([ref]$converted)
    if($tbl.Count -gt 0){
      Flush-Para $out ([ref]$para)
      foreach($row in $tbl){ [void]$out.Add($row) }
      [void]$out.Add("")
      $TableCount.Value = $converted
      $i = $nextIndex
      continue
    }
    if($trim -match '(?i)\btabela\b'){ [void]$TableCandidates.Value.Add($trim) }

    if($trim -match '^(Tempo de Conjuração|Alcance|Componentes|Duração):\s*(.*)$'){
      Flush-Para $out ([ref]$para)
      [void]$out.Add("- **$($Matches[1]):** $($Matches[2])")
      $i++
      continue
    }

    if($trim -match '^(\d+\.|•|-)\s+'){
      Flush-Para $out ([ref]$para)
      [void]$out.Add($trim)
      $i++
      continue
    }

    Add-ParaLine ([ref]$para) $trim
    $i++
  }
  Flush-Para $out ([ref]$para)
  (@($out) -join "`n").Trim()
}

function Format-PageObjects {
  param([object[]]$LineObjects,[ref]$TableCount,[ref]$TableCandidates)
  $out = New-Object Collections.ArrayList
  foreach($grp in @($LineObjects | Group-Object Page)){
    [void]$out.Add("> Fonte: Livro do Jogador, p. $($grp.Name)")
    [void]$out.Add("")
    $formatted = Format-RawLines (@($grp.Group | ForEach-Object { $_.Text })) $TableCount $TableCandidates
    if($formatted.Trim().Length -gt 0){ [void]$out.Add($formatted); [void]$out.Add("") }
  }
  (@($out) -join "`n").Trim()
}

function FrontMatter {
  param($Title,$Chapter,$Start,$End,$Tags)
  $tagBlock = @($Tags | ForEach-Object { "  - $_" }) -join "`n"
  @(
    "---",
    "title: `"$((Escape-Yaml $Title))`"",
    "capitulo: `"$((Escape-Yaml $Chapter))`"",
    "pagina_inicial: $Start",
    "pagina_final: $End",
    "fonte: `"Livro do Jogador`"",
    "tipo: regra",
    "status_editorial: formatado_automaticamente",
    "tags:",
    $tagBlock,
    "---",
    ""
  ) -join "`n"
}

function Make-Note {
  param($Section,[string]$Body)
  $related = Get-RelatedLinks $Section
  $relatedBlock = ""
  if($related.Count -gt 0){ $relatedBlock = "## Relacionados`n" + (@($related | ForEach-Object { "- [[$_]]" }) -join "`n") + "`n`n" }
  (FrontMatter $Section.Title $Section.Chapter $Section.PageStart $Section.PageEnd $Section.Tags) + "# $($Section.Title)`n`n" + $relatedBlock + $Body.Trim() + "`n"
}

function Validate-Wikilinks {
  param([string[]]$Files)
  $titles = @{}
  foreach($file in $Files){ $titles[[IO.Path]::GetFileNameWithoutExtension($file)] = $true }
  $broken = New-Object Collections.ArrayList
  foreach($file in $Files){
    $text = [IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)
    foreach($m in [regex]::Matches($text,'\[\[([^\]#\|]+)(#[^\]\|]+)?(\|[^\]]+)?\]\]')){
      $target = $m.Groups[1].Value.Trim()
      if(-not $titles.ContainsKey($target)){ [void]$broken.Add([pscustomobject]@{File=$file; Link=$target}) }
    }
  }
  @($broken)
}

function Is-SpellHeader {
  param([string]$Line,[string]$Next)
  $t = $Line.Trim()
  if($t.Length -lt 2 -or $t.Length -gt 70){ return $false }
  if($t -match '[\.;:,]$'){ return $false }
  if($t -match '^(Tempo de Conjuração|Alcance|Componentes|Duração|Em Níveis Superiores)'){ return $false }
  if($Next -notmatch '^(?i)(Truque|\d+[°ºo]\s+n[ií]vel)'){ return $false }
  return $true
}

if(-not(Test-Path -Path $RawTextPath)){ throw "Arquivo raw nao encontrado: $RawTextPath" }
Ensure-Dir $OutDir

$raw = [IO.File]::ReadAllText($RawTextPath,[Text.Encoding]::UTF8)
$rawPages = @($raw -split "`f")
if($rawPages[-1].Trim().Length -eq 0){ $rawPages = $rawPages[0..($rawPages.Count-2)] }

$pageObjects = New-Object Collections.ArrayList
for($i=0; $i -lt $rawPages.Count; $i++){
  $printed = Get-PrintedPage $rawPages[$i] ($i+1)
  $lines = @($rawPages[$i] -split "`r?`n" | ForEach-Object { [pscustomobject]@{ Page=$printed; Text=$_ } })
  [void]$pageObjects.Add([pscustomobject]@{ PdfPage=$i+1; PrintedPage=$printed; Lines=$lines })
}

$sections = Set-SectionEnds (Get-Sections)
$tableCount = 0
$tableCandidates = New-Object Collections.ArrayList
$written = New-Object Collections.ArrayList

$spellDir = Join-Part (Join-Part $OutDir "11 Magias") "Descrições de Magias"
if(Test-Path -Path $spellDir){
  $backup = Join-Part (Join-Part $OutDir "_extração") ("backup-magias-pre-formatacao-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
  Ensure-Dir $backup
  Copy-Item -Path $spellDir -Destination $backup -Recurse -Force
  Get-ChildItem -Path $spellDir -Filter "*.md" | Remove-Item -Force
} else {
  Ensure-Dir $spellDir
  $backup = $null
}

foreach($sec in $sections){
  $folder = Join-Part $OutDir $sec.Folder
  Ensure-Dir $folder
  if($sec.Title -eq "Descrição de Magias"){ continue }
  $objs = @($pageObjects | Where-Object { $_.PrintedPage -ge $sec.PageStart -and $_.PrintedPage -le $sec.PageEnd } | ForEach-Object { $_.Lines })
  $objs = Trim-ToSectionStart $objs $sec.Title
  $body = Format-PageObjects $objs ([ref]$tableCount) ([ref]$tableCandidates)
  if($body.Trim().Length -eq 0){ $body = "_Texto não localizado na extração raw. Ver relatório editorial._" }
  $path = Join-Part $folder ((Slugify-FileName $sec.Title) + ".md")
  Write-Utf8 $path (Make-Note $sec $body)
  [void]$written.Add($path)
}

$spellLines = @($pageObjects | Where-Object { $_.PrintedPage -ge 215 -and $_.PrintedPage -le 289 } | ForEach-Object { $_.Lines })
$spellStarts = New-Object Collections.ArrayList
for($i=0; $i -lt $spellLines.Count-1; $i++){
  $line = $spellLines[$i].Text.Trim()
  $next = $spellLines[$i+1].Text.Trim()
  if(Is-SpellHeader $line $next){ [void]$spellStarts.Add([pscustomobject]@{Index=$i; Title=$line; Page=$spellLines[$i].Page}) }
}

$spellIndexLinks = New-Object Collections.ArrayList
$usedNames = @{}
for($s=0; $s -lt $spellStarts.Count; $s++){
  $start = $spellStarts[$s].Index
  $end = if($s+1 -lt $spellStarts.Count){ $spellStarts[$s+1].Index - 1 } else { $spellLines.Count - 1 }
  $title = $TextInfo.ToTitleCase($spellStarts[$s].Title.ToLower())
  $block = @($spellLines[$start..$end])
  $startPage = ($block | Select-Object -First 1).Page
  $endPage = ($block | Select-Object -Last 1).Page
  $sec = [pscustomobject]@{ Title=$title; Folder="11 Magias\Descrições de Magias"; PageStart=$startPage; PageEnd=$endPage; Chapter="Capítulo 11"; Tags=@("dnd/regras/magias","dnd/regras/magia") }
  $body = Format-PageObjects $block ([ref]$tableCount) ([ref]$tableCandidates)
  $fileBase = Slugify-FileName $title
  if($usedNames.ContainsKey($fileBase)){ $usedNames[$fileBase]++; $fileBase = "$fileBase - $($usedNames[$fileBase])" } else { $usedNames[$fileBase] = 1 }
  $path = Join-Part $spellDir ($fileBase + ".md")
  Write-Utf8 $path (Make-Note $sec $body)
  [void]$written.Add($path)
  [void]$spellIndexLinks.Add("- [[$fileBase|$title]] — p. $startPage-$endPage")
}

$descSec = ($sections | Where-Object { $_.Title -eq "Descrição de Magias" } | Select-Object -First 1)
$descBody = "Índice das descrições de magias extraídas em notas individuais.`n`n" + (@($spellIndexLinks) -join "`n")
$descPath = Join-Part (Join-Part $OutDir "11 Magias") "Descrição de Magias.md"
Write-Utf8 $descPath (Make-Note $descSec $descBody)
[void]$written.Add($descPath)

$summary = New-Object Collections.ArrayList
[void]$summary.Add("---")
[void]$summary.Add('title: "D&D 5e - Livro do Jogador"')
[void]$summary.Add("tipo: sumario")
[void]$summary.Add("status_editorial: formatado_automaticamente")
[void]$summary.Add("tags:")
[void]$summary.Add("  - dnd/regras")
[void]$summary.Add("  - obsidian/sumario")
[void]$summary.Add("---")
[void]$summary.Add("")
[void]$summary.Add("# D&D 5e - Livro do Jogador")
[void]$summary.Add("")
[void]$summary.Add("> Base regenerada com Poppler pdftotext -raw e pós-processamento editorial automático.")
[void]$summary.Add("")
foreach($folder in @("01 Criação de Personagem","02 Raças","03 Classes","04 Personalidade e Antecedentes","05 Equipamento","06 Opções de Customização","07 Atributos","08 Aventurando-se","09 Combate","10 Magia","11 Magias","Apêndices","Índices")){
  [void]$summary.Add("## $folder")
  foreach($sec in @($sections | Where-Object { $_.Folder -eq $folder })){
    [void]$summary.Add("- [[$($sec.Title)]] - p. $($sec.PageStart)-$($sec.PageEnd)")
  }
  if($folder -eq "11 Magias"){ [void]$summary.Add("- Pasta: 11 Magias/Descrições de Magias/ ($($spellStarts.Count) magias detectadas)") }
  [void]$summary.Add("")
}
[void]$summary.Add("## Relatórios")
[void]$summary.Add("- [[relatorio-editorial]]")
[void]$summary.Add("- [[validacao]]")
[void]$summary.Add("- [[links-quebrados]]")
$summaryPath = Join-Part $OutDir "00 Sumário.md"
Write-Utf8 $summaryPath (@($summary) -join "`n")
[void]$written.Add($summaryPath)

$allMd = @(Get-ChildItem -Path $OutDir -Filter "*.md" -Recurse | Where-Object { $_.FullName -notmatch '\\_extração\\' } | ForEach-Object { $_.FullName })
$broken = @(Validate-Wikilinks $allMd)

$report = New-Object Collections.ArrayList
[void]$report.Add("# Relatório editorial")
[void]$report.Add("")
[void]$report.Add("- Fonte textual usada: _extração/poppler-raw.txt")
[void]$report.Add("- Notas reescritas/geradas nesta etapa: $($written.Count)")
[void]$report.Add("- Magias detectadas: $($spellStarts.Count)")
[void]$report.Add("- Tabelas convertidas automaticamente: $tableCount")
[void]$report.Add("- Links quebrados após validação: $($broken.Count)")
if($backup){ [void]$report.Add("- Backup das magias antigas: $backup") }
[void]$report.Add("")
[void]$report.Add("## Revisão manual recomendada")
[void]$report.Add("- Tabelas complexas com muitas colunas, especialmente equipamentos, classes e listas de magia.")
[void]$report.Add("- Páginas em que o livro usa caixas laterais ou texto em paralelo.")
[void]$report.Add("- Magias cujo título foi detectado por heurística; nomes duplicados receberam sufixo numérico.")
[void]$report.Add("")
[void]$report.Add("## Candidatas a tabela mencionadas no texto")
foreach($c in @($tableCandidates | Select-Object -Unique | Select-Object -First 200)){ [void]$report.Add("- $c") }
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "relatorio-editorial.md") (@($report) -join "`n")

$brokenReport = New-Object Collections.ArrayList
[void]$brokenReport.Add("# Links quebrados")
[void]$brokenReport.Add("")
if($broken.Count -eq 0){ [void]$brokenReport.Add("Nenhum wikilink quebrado encontrado na validação simples.") }
else { foreach($b in $broken){ [void]$brokenReport.Add("- $($b.File) -> [[$($b.Link)]]") } }
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "links-quebrados.md") (@($brokenReport) -join "`n")

$validation = New-Object Collections.ArrayList
[void]$validation.Add("# Validação")
[void]$validation.Add("")
[void]$validation.Add("- Arquivo raw existe: " + (Test-Path -Path $RawTextPath))
[void]$validation.Add("- Páginas lidas: $($pageObjects.Count)")
[void]$validation.Add("- Notas Markdown encontradas: $($allMd.Count)")
[void]$validation.Add("- Magias em arquivo: " + (@(Get-ChildItem -Path $spellDir -Filter "*.md").Count))
[void]$validation.Add("- Links quebrados: $($broken.Count)")
[void]$validation.Add("- Tabelas convertidas automaticamente: $tableCount")
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "validacao.md") (@($validation) -join "`n")

Write-Host "Concluido."
Write-Host "Notas Markdown: $($allMd.Count); magias: $($spellStarts.Count); links quebrados: $($broken.Count); tabelas convertidas: $tableCount"
