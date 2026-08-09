param(
  [string]$PdfPath = "C:\Users\Rogerin\Documents\Obsidian Vault\NOVA ERA MANAGE\7 Regras\SISTEMA\livros\dd-5e-livro-do-jogador-fundo-branco-biblioteca-c3a9lfica.pdf",
  [string]$OutDir = "C:\Users\Rogerin\Documents\Obsidian Vault\NOVA ERA MANAGE\7 Regras\SISTEMA\D&D 5e - Livro do Jogador"
)

$ErrorActionPreference = "Stop"

$Latin1 = [Text.Encoding]::GetEncoding(28591)
$Win1252 = [Text.Encoding]::GetEncoding(1252)
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Join-Part {
  param([string]$Root, [string]$Child)
  return [IO.Path]::Combine($Root, $Child)
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Utf8 {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if ($parent) { Ensure-Dir $parent }
  [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Escape-Yaml {
  param([string]$Text)
  if ($null -eq $Text) { return "" }
  return ($Text -replace '"','\"')
}

function Slugify-FileName {
  param([string]$Name)
  $invalid = [IO.Path]::GetInvalidFileNameChars()
  $clean = $Name.Trim()
  foreach ($ch in $invalid) { $clean = $clean.Replace([string]$ch, "-") }
  $clean = $clean -replace '\s+', ' '
  $clean = $clean -replace '\.$', ''
  if ($clean.Length -gt 120) { $clean = $clean.Substring(0, 120).Trim() }
  return $clean
}

function Bytes-From-Latin1String {
  param([string]$Text)
  return $Latin1.GetBytes($Text)
}

function Try-Inflate {
  param([byte[]]$Raw)
  foreach ($mode in @("full", "zlibskip")) {
    try {
      if ($mode -eq "zlibskip") {
        if ($Raw.Length -le 6) { continue }
        $buf = New-Object byte[] ($Raw.Length - 6)
        [Array]::Copy($Raw, 2, $buf, 0, $buf.Length)
      } else {
        $buf = $Raw
      }
      $ms = New-Object IO.MemoryStream(,$buf)
      $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
      $out = New-Object IO.MemoryStream
      $ds.CopyTo($out)
      $ds.Dispose()
      return $out.ToArray()
    } catch {
    }
  }
  return $null
}

function New-PdfObject {
  param(
    [int]$Number,
    [int]$Generation,
    [string]$Body,
    [bool]$Virtual = $false
  )
  $obj = [ordered]@{
    Number = $Number
    Generation = $Generation
    Body = $Body
    Dict = $Body
    IsStream = $false
    StreamBytes = $null
    DecodedBytes = $null
    Virtual = $Virtual
    DecodeProblem = $null
  }
  $streamAt = $Body.IndexOf("stream")
  if ($streamAt -ge 0) {
    $endAt = $Body.LastIndexOf("endstream")
    if ($endAt -gt $streamAt) {
      $dataStart = $streamAt + 6
      if ($dataStart -lt $Body.Length -and $Body[$dataStart] -eq "`r") { $dataStart++ }
      if ($dataStart -lt $Body.Length -and $Body[$dataStart] -eq "`n") { $dataStart++ }
      elseif ($dataStart -lt $Body.Length -and $Body[$dataStart] -eq "`r") { $dataStart++ }
      $dataLen = $endAt - $dataStart
      if ($dataLen -gt 0) {
        $obj.Dict = $Body.Substring(0, $streamAt)
        $obj.IsStream = $true
        $obj.StreamBytes = Bytes-From-Latin1String ($Body.Substring($dataStart, $dataLen))
      }
    }
  }
  return [pscustomobject]$obj
}

function Decode-PdfStream {
  param($Obj)
  if (-not $Obj.IsStream) { return $null }
  if ($null -ne $Obj.DecodedBytes) { return $Obj.DecodedBytes }
  $dict = $Obj.Dict
  if ($dict -match '/FlateDecode') {
    $decoded = Try-Inflate $Obj.StreamBytes
    if ($null -eq $decoded) {
      $Obj.DecodeProblem = "Falha ao descompactar FlateDecode"
      return $null
    }
    $Obj.DecodedBytes = $decoded
    return $decoded
  }
  if ($dict -notmatch '/Filter') {
    $Obj.DecodedBytes = $Obj.StreamBytes
    return $Obj.StreamBytes
  }
  $Obj.DecodeProblem = "Filtro nao suportado: " + (($dict | Select-String -Pattern '/Filter\s*(\[[^\]]+\]|/\w+)' -AllMatches).Matches.Value -join ", ")
  return $null
}

function Read-PdfModel {
  param([string]$Path)
  $bytes = [IO.File]::ReadAllBytes($Path)
  $source = $Latin1.GetString($bytes)
  $markers = [regex]::Matches($source, '(?m)(\d+)\s+(\d+)\s+obj\b')
  $objects = @{}
  $ordered = New-Object Collections.ArrayList

  for ($i = 0; $i -lt $markers.Count; $i++) {
    $m = $markers[$i]
    $num = [int]$m.Groups[1].Value
    $gen = [int]$m.Groups[2].Value
    $bodyStart = $m.Index + $m.Length
    $nextStart = if ($i + 1 -lt $markers.Count) { $markers[$i + 1].Index } else { $source.Length }
    $chunk = $source.Substring($bodyStart, $nextStart - $bodyStart)
    $endObj = $chunk.LastIndexOf("endobj")
    if ($endObj -ge 0) { $chunk = $chunk.Substring(0, $endObj) }
    $obj = New-PdfObject $num $gen $chunk $false
    $objects["$num $gen"] = $obj
    [void]$ordered.Add($obj)
  }

  $expanded = 0
  foreach ($obj in @($ordered)) {
    if ($obj.Dict -match '/Type\s*/ObjStm') {
      $decoded = Decode-PdfStream $obj
      if ($null -eq $decoded) { continue }
      $text = $Latin1.GetString($decoded)
      $nMatch = [regex]::Match($obj.Dict, '/N\s+(\d+)')
      $firstMatch = [regex]::Match($obj.Dict, '/First\s+(\d+)')
      if (-not $nMatch.Success -or -not $firstMatch.Success) { continue }
      $n = [int]$nMatch.Groups[1].Value
      $first = [int]$firstMatch.Groups[1].Value
      if ($first -le 0 -or $first -gt $text.Length) { continue }
      $header = $text.Substring(0, $first)
      $nums = [regex]::Matches($header, '\d+')
      if ($nums.Count -lt ($n * 2)) { continue }
      for ($j = 0; $j -lt $n; $j++) {
        $childNum = [int]$nums[$j * 2].Value
        $offset = [int]$nums[$j * 2 + 1].Value
        $nextOffset = if ($j + 1 -lt $n) { [int]$nums[($j + 1) * 2 + 1].Value } else { $text.Length - $first }
        $start = $first + $offset
        $len = $nextOffset - $offset
        if ($start -lt 0 -or $len -le 0 -or ($start + $len) -gt $text.Length) { continue }
        $body = $text.Substring($start, $len)
        $key = "$childNum 0"
        if (-not $objects.ContainsKey($key)) {
          $child = New-PdfObject $childNum 0 $body $true
          $objects[$key] = $child
          [void]$ordered.Add($child)
          $expanded++
        }
      }
    }
  }

  return [pscustomobject]@{
    Bytes = $bytes
    Source = $source
    Objects = $objects
    OrderedObjects = $ordered
    ObjectMarkers = $markers.Count
    ExpandedObjects = $expanded
  }
}

function Get-Obj {
  param($Model, [int]$Number)
  $key = "$Number 0"
  if ($Model.Objects.ContainsKey($key)) { return $Model.Objects[$key] }
  foreach ($k in $Model.Objects.Keys) {
    if ($k -like "$Number *") { return $Model.Objects[$k] }
  }
  return $null
}

function Get-Refs {
  param([string]$Text)
  $refs = New-Object Collections.ArrayList
  foreach ($m in [regex]::Matches($Text, '(\d+)\s+(\d+)\s+R')) {
    [void]$refs.Add([int]$m.Groups[1].Value)
  }
  return @($refs)
}

function Get-PageTreeOrder {
  param($Model)
  $catalog = $Model.OrderedObjects | Where-Object { $_.Body -match '/Type\s*/Catalog' } | Select-Object -First 1
  $rootPages = $null
  if ($catalog -and $catalog.Body -match '/Pages\s+(\d+)\s+\d+\s+R') {
    $rootPages = [int]$Matches[1]
  }
  if ($null -eq $rootPages) {
    $pages = $Model.OrderedObjects | Where-Object { $_.Body -match '/Type\s*/Pages\b' } | Sort-Object {
      if ($_.Body -match '/Count\s+(\d+)') { -[int]$Matches[1] } else { 0 }
    } | Select-Object -First 1
    if ($pages) { $rootPages = $pages.Number }
  }

  $visited = @{}
  function Walk-Pages([int]$ObjNum) {
    if ($visited.ContainsKey($ObjNum)) { return @() }
    $visited[$ObjNum] = $true
    $obj = Get-Obj $Model $ObjNum
    if ($null -eq $obj) { return @() }
    $body = $obj.Body
    if ($body -match '/Type\s*/Page(?!s)\b') { return @($ObjNum) }
    $kidsMatch = [regex]::Match($body, '(?s)/Kids\s*\[(.*?)\]')
    if ($kidsMatch.Success) {
      $out = New-Object Collections.ArrayList
      foreach ($kid in Get-Refs $kidsMatch.Groups[1].Value) {
        foreach ($p in Walk-Pages $kid) { [void]$out.Add($p) }
      }
      return @($out)
    }
    return @()
  }

  $orderedPages = @()
  if ($null -ne $rootPages) { $orderedPages = Walk-Pages $rootPages }
  if ($orderedPages.Count -eq 0) {
    $orderedPages = @($Model.OrderedObjects | Where-Object { $_.Body -match '/Type\s*/Page(?!s)\b' } | Sort-Object Number | ForEach-Object { $_.Number })
  }
  return @($orderedPages)
}

function Get-PageContentRefs {
  param([string]$PageBody)
  $m = [regex]::Match($PageBody, '(?s)/Contents\s*(\[(.*?)\]|(\d+)\s+\d+\s+R)')
  if (-not $m.Success) { return @() }
  if ($m.Groups[2].Success) { return Get-Refs $m.Groups[2].Value }
  if ($m.Groups[3].Success) { return @([int]$m.Groups[3].Value) }
  return @()
}

function Decode-PdfLiteral {
  param([string]$Raw)
  $bytes = New-Object Collections.Generic.List[byte]
  for ($i = 0; $i -lt $Raw.Length; $i++) {
    $ch = $Raw[$i]
    if ($ch -eq '\') {
      $i++
      if ($i -ge $Raw.Length) { break }
      $n = $Raw[$i]
      switch ($n) {
        'n' { $bytes.Add(10); continue }
        'r' { $bytes.Add(13); continue }
        't' { $bytes.Add(9); continue }
        'b' { $bytes.Add(8); continue }
        'f' { $bytes.Add(12); continue }
        '(' { $bytes.Add(40); continue }
        ')' { $bytes.Add(41); continue }
        '\' { $bytes.Add(92); continue }
        "`r" {
          if ($i + 1 -lt $Raw.Length -and $Raw[$i + 1] -eq "`n") { $i++ }
          continue
        }
        "`n" { continue }
        default {
          if ($n -match '[0-7]') {
            $oct = [string]$n
            for ($j = 0; $j -lt 2 -and ($i + 1) -lt $Raw.Length -and $Raw[$i + 1] -match '[0-7]'; $j++) {
              $i++
              $oct += [string]$Raw[$i]
            }
            $bytes.Add([Convert]::ToByte($oct, 8))
            continue
          }
          $bytes.Add([byte][int][char]$n)
          continue
        }
      }
    } else {
      $bytes.Add([byte][int][char]$ch)
    }
  }
  return Decode-BytesToText $bytes.ToArray()
}

function Decode-HexString {
  param([string]$Hex)
  $clean = ($Hex -replace '\s+', '')
  if (($clean.Length % 2) -eq 1) { $clean += "0" }
  $bytes = New-Object byte[] ($clean.Length / 2)
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = [Convert]::ToByte($clean.Substring($i * 2, 2), 16)
  }
  return Decode-BytesToText $bytes
}

function Decode-BytesToText {
  param([byte[]]$Bytes)
  if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
    return [Text.Encoding]::BigEndianUnicode.GetString($Bytes, 2, $Bytes.Length - 2)
  }
  $zeroEven = 0
  for ($i = 0; $i -lt $Bytes.Length; $i += 2) {
    if ($Bytes[$i] -eq 0) { $zeroEven++ }
  }
  if ($Bytes.Length -gt 4 -and $zeroEven -gt ($Bytes.Length / 4)) {
    try { return [Text.Encoding]::BigEndianUnicode.GetString($Bytes) } catch {}
  }
  return $Win1252.GetString($Bytes)
}

function Read-PdfToken {
  param([string]$Text, [ref]$Index)
  $len = $Text.Length
  while ($Index.Value -lt $len) {
    $c = $Text[$Index.Value]
    if ([char]::IsWhiteSpace($c)) { $Index.Value++; continue }
    if ($c -eq '%') {
      while ($Index.Value -lt $len -and $Text[$Index.Value] -ne "`n" -and $Text[$Index.Value] -ne "`r") { $Index.Value++ }
      continue
    }
    break
  }
  if ($Index.Value -ge $len) { return $null }

  $c = $Text[$Index.Value]
  if ($c -eq '(') {
    $Index.Value++
    $start = $Index.Value
    $depth = 1
    $sb = New-Object Text.StringBuilder
    while ($Index.Value -lt $len -and $depth -gt 0) {
      $ch = $Text[$Index.Value]
      if ($ch -eq '\') {
        [void]$sb.Append($ch)
        $Index.Value++
        if ($Index.Value -lt $len) {
          [void]$sb.Append($Text[$Index.Value])
          $Index.Value++
        }
        continue
      }
      if ($ch -eq '(') { $depth++; [void]$sb.Append($ch); $Index.Value++; continue }
      if ($ch -eq ')') {
        $depth--
        if ($depth -eq 0) { $Index.Value++; break }
        [void]$sb.Append($ch)
        $Index.Value++
        continue
      }
      [void]$sb.Append($ch)
      $Index.Value++
    }
    return [pscustomobject]@{ Type = "String"; Value = (Decode-PdfLiteral $sb.ToString()) }
  }

  if ($c -eq '<' -and ($Index.Value + 1 -lt $len) -and $Text[$Index.Value + 1] -ne '<') {
    $Index.Value++
    $start = $Index.Value
    while ($Index.Value -lt $len -and $Text[$Index.Value] -ne '>') { $Index.Value++ }
    $hex = $Text.Substring($start, $Index.Value - $start)
    if ($Index.Value -lt $len) { $Index.Value++ }
    return [pscustomobject]@{ Type = "String"; Value = (Decode-HexString $hex) }
  }

  if ($c -eq '[') {
    $Index.Value++
    $items = New-Object Collections.ArrayList
    while ($Index.Value -lt $len) {
      while ($Index.Value -lt $len -and [char]::IsWhiteSpace($Text[$Index.Value])) { $Index.Value++ }
      if ($Index.Value -ge $len) { break }
      if ($Text[$Index.Value] -eq ']') { $Index.Value++; break }
      $tok = Read-PdfToken $Text $Index
      if ($null -ne $tok) { [void]$items.Add($tok) }
    }
    return [pscustomobject]@{ Type = "Array"; Value = @($items) }
  }

  if ($c -eq ']') {
    $Index.Value++
    return [pscustomobject]@{ Type = "EndArray"; Value = "]" }
  }

  $startWord = $Index.Value
  while ($Index.Value -lt $len) {
    $ch = $Text[$Index.Value]
    if ([char]::IsWhiteSpace($ch) -or $ch -eq '(' -or $ch -eq ')' -or $ch -eq '[' -or $ch -eq ']' -or $ch -eq '<' -or $ch -eq '>' -or $ch -eq '/') { break }
    $Index.Value++
  }
  if ($Index.Value -eq $startWord -and $Text[$Index.Value] -eq '/') {
    $Index.Value++
    while ($Index.Value -lt $len -and -not [char]::IsWhiteSpace($Text[$Index.Value])) { $Index.Value++ }
  }
  $word = $Text.Substring($startWord, $Index.Value - $startWord)
  if ($word -match '^-?\d+(\.\d+)?$') {
    return [pscustomobject]@{ Type = "Number"; Value = [double]$word }
  }
  return [pscustomobject]@{ Type = "Word"; Value = $word }
}

function Append-TextChunk {
  param([Text.StringBuilder]$Line, [string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return }
  $clean = $Text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
  if ([string]::IsNullOrWhiteSpace($clean)) { return }
  if ($Line.Length -gt 0) {
    $last = $Line.ToString()[$Line.Length - 1]
    $first = $clean[0]
    if (($last -match '[\p{L}\p{N},;:]') -and ($first -match '[\p{L}\p{N}]')) {
      [void]$Line.Append(' ')
    }
  }
  [void]$Line.Append($clean)
}

function Flush-Line {
  param([Collections.ArrayList]$Lines, [Text.StringBuilder]$Line)
  $t = ($Line.ToString() -replace '\s+', ' ').Trim()
  [void]$Line.Clear()
  if ($t.Length -eq 0) { return }
  if ($t -match '^\d+$') { return }
  if ($t -match '^(LIVRO DO JOGADOR|DUNGEONS & DRAGONS)$') { return }
  [void]$Lines.Add($t)
}

function Extract-ContentText {
  param([byte[]]$ContentBytes)
  if ($null -eq $ContentBytes -or $ContentBytes.Length -eq 0) { return "" }
  $text = $Latin1.GetString($ContentBytes)
  $lines = New-Object Collections.ArrayList
  $line = New-Object Text.StringBuilder

  function Decode-StringToken([string]$Token) {
    $t = $Token.Trim()
    if ($t.StartsWith("(") -and $t.EndsWith(")")) {
      return Decode-PdfLiteral $t.Substring(1, $t.Length - 2)
    }
    if ($t.StartsWith("<") -and $t.EndsWith(">")) {
      return Decode-HexString $t.Substring(1, $t.Length - 2)
    }
    return ""
  }

  function Find-PreviousStringToken([string]$Source, [int]$Before) {
    $j = $Before - 1
    while ($j -ge 0 -and [char]::IsWhiteSpace($Source[$j])) { $j-- }
    if ($j -lt 0) { return $null }
    if ($Source[$j] -eq ')') {
      $depth = 1
      $j--
      while ($j -ge 0) {
        if ($Source[$j] -eq '\' -and $j -gt 0) { $j -= 2; continue }
        if ($Source[$j] -eq ')') { $depth++ }
        elseif ($Source[$j] -eq '(') {
          $depth--
          if ($depth -eq 0) { return $Source.Substring($j, $Before - $j).Trim() }
        }
        $j--
      }
    }
    if ($Source[$j] -eq '>') {
      $start = $Source.LastIndexOf('<', $j)
      if ($start -ge 0 -and $start + 1 -lt $Source.Length -and $Source[$start + 1] -ne '<') {
        return $Source.Substring($start, $Before - $start).Trim()
      }
    }
    return $null
  }

  function Find-PreviousArray([string]$Source, [int]$Before) {
    $start = $Source.LastIndexOf('[', $Before)
    if ($start -lt 0) { return $null }
    $end = $Source.LastIndexOf(']', $Before)
    if ($end -lt $start) { return $null }
    $len = $end - $start + 1
    if ($len -le 0 -or $len -gt 20000) { return $null }
    return $Source.Substring($start, $len)
  }

  function Decode-TJArray([string]$ArrayText) {
    if ([string]::IsNullOrWhiteSpace($ArrayText) -or $ArrayText.Length -lt 2) { return "" }
    $inner = $ArrayText.Substring(1, $ArrayText.Length - 2)
    $sb = New-Object Text.StringBuilder
    foreach ($tok in [regex]::Matches($inner, '(?s)\((?:\\.|[^\\()]){0,1000}\)|<[0-9A-Fa-f\s]{2,2000}>|-?\d+(\.\d+)?')) {
      $v = $tok.Value
      if ($v -match '^-?\d') {
        try {
          if ([double]$v -lt -90) { [void]$sb.Append(' ') }
        } catch {
        }
      } else {
        [void]$sb.Append((Decode-StringToken $v))
      }
    }
    return (($sb.ToString()) -replace '\s+', ' ').Trim()
  }

  foreach ($m in [regex]::Matches($text, '\bTJ\b|\bTj\b|\bT\*\b|\bET\b|\bTd\b|\bTD\b|\bTm\b')) {
    $op = $m.Value
    if ($op -eq "TJ") {
      $arr = Find-PreviousArray $text $m.Index
      if ($arr) {
        $decoded = Decode-TJArray $arr
        if ($decoded.Length -gt 0 -and $decoded -match '[\p{L}\p{N}]') { Append-TextChunk $line $decoded }
      }
    } elseif ($op -eq "Tj") {
      $tok = Find-PreviousStringToken $text $m.Index
      if ($tok) {
        $decoded = (Decode-StringToken $tok) -replace '\s+', ' '
        $decoded = $decoded.Trim()
        if ($decoded.Length -gt 0 -and $decoded.Length -le 500 -and $decoded -match '[\p{L}\p{N}]') { Append-TextChunk $line $decoded }
      }
    } else {
      Flush-Line $lines $line
    }
    if ($lines.Count -gt 2500) {
      [void]$lines.Add("_Extração interrompida nesta stream por excesso de fragmentos._")
      break
    }
  }
  Flush-Line $lines $line
  return (@($lines) -join "`n")
}

function Get-PageTexts {
  param($Model, [int[]]$PageObjects)
  $pages = New-Object Collections.ArrayList
  $problems = New-Object Collections.ArrayList
  $cacheDir = Join-Part (Join-Part $OutDir "_extração") "paginas"
  Ensure-Dir $cacheDir
  for ($i = 0; $i -lt $PageObjects.Count; $i++) {
    if (($i + 1) -eq 1 -or (($i + 1) % 25) -eq 0) {
      Write-Host "Extraindo pagina $($i + 1) de $($PageObjects.Count)..."
    }
    $pageObj = Get-Obj $Model $PageObjects[$i]
    $refs = @()
    if ($pageObj) { $refs = Get-PageContentRefs $pageObj.Body }
    $cacheFile = Join-Part $cacheDir ("p{0:000}.txt" -f ($i + 1))
    if (Test-Path -Path $cacheFile) {
      $cached = [IO.File]::ReadAllText($cacheFile, [Text.Encoding]::UTF8)
      [void]$pages.Add([pscustomobject]@{
        PdfPage = $i + 1
        PageObject = $PageObjects[$i]
        ContentRefs = $refs
        Text = $cached
      })
      continue
    }
    $chunks = New-Object Collections.ArrayList
    foreach ($ref in $refs) {
      $contentObj = Get-Obj $Model $ref
      if ($null -eq $contentObj) {
        [void]$problems.Add("Pagina $($i + 1): objeto de conteudo ausente $ref")
        continue
      }
      $decoded = Decode-PdfStream $contentObj
      if ($null -eq $decoded) {
        [void]$problems.Add("Pagina $($i + 1): $($contentObj.DecodeProblem)")
        continue
      }
      if ($decoded.Length -gt 2000000) {
        [void]$problems.Add("Pagina $($i + 1): stream $ref ignorada por tamanho incomum ($($decoded.Length) bytes)")
        continue
      }
      $txt = Extract-ContentText $decoded
      if ($txt.Trim().Length -gt 0) { [void]$chunks.Add($txt.Trim()) }
    }
    $pageText = (@($chunks) -join "`n")
    Write-Utf8 $cacheFile $pageText
    [void]$pages.Add([pscustomobject]@{
      PdfPage = $i + 1
      PageObject = $PageObjects[$i]
      ContentRefs = $refs
      Text = $pageText
    })
  }
  return [pscustomobject]@{ Pages = @($pages); Problems = @($problems) }
}

function New-Section {
  param([string]$Title, [string]$Folder, [int]$PageStart, [string]$Chapter, [string[]]$Tags)
  return [pscustomobject]@{
    Title = $Title
    Folder = $Folder
    PageStart = $PageStart
    PageEnd = $PageStart
    Chapter = $Chapter
    Tags = $Tags
  }
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
  foreach ($r in @(@("Escolhendo uma Raça",17),@("Anão",18),@("Elfo",21),@("Halfling",26),@("Humano",29),@("Draconato",32),@("Gnomo",35),@("Meio-Elfo",38),@("Meio-Orc",40),@("Tiefling",42))) {
    [void]$s.Add((New-Section $r[0] "02 Raças" $r[1] "Capítulo 2" @("dnd/regras/racas")))
  }

  [void]$s.Add((New-Section "Classes" "03 Classes" 45 "Capítulo 3" @("dnd/regras/classes")))
  [void]$s.Add((New-Section "Características de Classe" "03 Classes" 45 "Capítulo 3" @("dnd/regras/classes")))
  foreach ($c in @(@("Bárbaro",46),@("Bardo",51),@("Bruxo",56),@("Clérigo",63),@("Druida",71),@("Feiticeiro",77),@("Guerreiro",83),@("Ladino",89),@("Mago",94),@("Monge",102),@("Paladino",108),@("Patrulheiro",115))) {
    [void]$s.Add((New-Section $c[0] "03 Classes" $c[1] "Capítulo 3" @("dnd/regras/classes")))
  }

  [void]$s.Add((New-Section "Personalidade e Antecedentes" "04 Personalidade e Antecedentes" 121 "Capítulo 4" @("dnd/regras/antecedentes")))
  foreach ($p in @(@("Detalhes do Personagem",123),@("Inspiração",127),@("Antecedentes",127))) {
    [void]$s.Add((New-Section $p[0] "04 Personalidade e Antecedentes" $p[1] "Capítulo 4" @("dnd/regras/antecedentes")))
  }

  [void]$s.Add((New-Section "Equipamento" "05 Equipamento" 143 "Capítulo 5" @("dnd/regras/equipamento")))
  foreach ($e in @(@("Equipamento Inicial",145),@("Riqueza",145),@("Armaduras e Escudos",146),@("Armas",148),@("Equipamento de Aventura",150),@("Ferramentas",156),@("Montarias e Veículos",157),@("Comércio de Bens",159),@("Despesas",159),@("Bugigangas",161))) {
    [void]$s.Add((New-Section $e[0] "05 Equipamento" $e[1] "Capítulo 5" @("dnd/regras/equipamento")))
  }

  [void]$s.Add((New-Section "Opções de Customização" "06 Opções de Customização" 163 "Capítulo 6" @("dnd/regras/customizacao")))
  [void]$s.Add((New-Section "Multiclasse" "06 Opções de Customização" 165 "Capítulo 6" @("dnd/regras/customizacao","dnd/regras/classes")))
  [void]$s.Add((New-Section "Talentos" "06 Opções de Customização" 167 "Capítulo 6" @("dnd/regras/customizacao","dnd/regras/talentos")))

  [void]$s.Add((New-Section "Atributos" "07 Atributos" 175 "Capítulo 7" @("dnd/regras/atributos")))
  foreach ($a in @(@("Valores de Habilidades e Modificadores",175),@("Vantagem e Desvantagem",175),@("Bônus de Proficiência",175),@("Testes de Habilidade",176),@("Usando Cada Habilidade",177),@("Testes de Resistência",181))) {
    [void]$s.Add((New-Section $a[0] "07 Atributos" $a[1] "Capítulo 7" @("dnd/regras/atributos")))
  }

  [void]$s.Add((New-Section "Aventurando-se" "08 Aventurando-se" 183 "Capítulo 8" @("dnd/regras/aventura")))
  foreach ($av in @(@("Tempo",183),@("Movimento",183),@("O Ambiente",185),@("Interação Social",187),@("Descanso",188),@("Entre Aventuras",188))) {
    [void]$s.Add((New-Section $av[0] "08 Aventurando-se" $av[1] "Capítulo 8" @("dnd/regras/aventura")))
  }

  [void]$s.Add((New-Section "Combate" "09 Combate" 191 "Capítulo 9" @("dnd/regras/combate")))
  foreach ($co in @(@("A Ordem do Combate",191),@("Movimento e Posição",192),@("Ações em Combate",194),@("Realizando um Ataque",195),@("Cobertura",198),@("Dano e Cura",198),@("Combate Montado",200),@("Combate Submerso",200))) {
    [void]$s.Add((New-Section $co[0] "09 Combate" $co[1] "Capítulo 9" @("dnd/regras/combate")))
  }

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
  return @($s)
}

function Get-SectionEndPages {
  param([object[]]$Sections, [int]$PageCount)
  $ordered = @($Sections | Sort-Object @{ Expression = { [int]$_.PageStart } }, @{ Expression = { [string]$_.Title } })
  for ($i = 0; $i -lt $ordered.Count; $i++) {
    $next = $null
    for ($j = $i + 1; $j -lt $ordered.Count; $j++) {
      if ([int]$ordered[$j].PageStart -gt [int]$ordered[$i].PageStart) { $next = [int]$ordered[$j].PageStart; break }
    }
    $end = if ($null -ne $next) { [Math]::Max([int]$ordered[$i].PageStart, $next - 1) } else { $PageCount }
    $ordered[$i].PageEnd = [Math]::Min($end, $PageCount)
  }
  return $Sections
}

function Get-PagesRangeText {
  param([object[]]$Pages, [int]$Start, [int]$End)
  $out = New-Object Collections.ArrayList
  foreach ($p in @($Pages | Where-Object { $_.PdfPage -ge $Start -and $_.PdfPage -le $End })) {
    if ($p.Text.Trim().Length -gt 0) {
      [void]$out.Add("> Fonte: Livro do Jogador, p. $($p.PdfPage)")
      [void]$out.Add("")
      [void]$out.Add($p.Text.Trim())
      [void]$out.Add("")
    }
  }
  return (@($out) -join "`n").Trim()
}

function Convert-PossibleTables {
  param([string]$Text, [ref]$Report, [string]$Title)
  $lines = $Text -split "`n"
  $out = New-Object Collections.ArrayList
  $i = 0
  while ($i -lt $lines.Count) {
    $line = $lines[$i]
    if ($line -match '\S+\s{3,}\S+' -and $line -notmatch '^\s*>' -and $line.Length -lt 180) {
      $block = New-Object Collections.ArrayList
      while ($i -lt $lines.Count -and $lines[$i] -match '\S+\s{3,}\S+' -and $lines[$i].Length -lt 180) {
        [void]$block.Add($lines[$i])
        $i++
      }
      if ($block.Count -ge 3) {
        $rows = @($block | ForEach-Object { @($_.Trim() -split '\s{3,}') })
        $maxCols = ($rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
        if ($maxCols -ge 2) {
          $Report.Value.Add("${Title}: possivel tabela convertida ou revisavel com $($block.Count) linhas.") | Out-Null
          $header = $rows[0]
          while ($header.Count -lt $maxCols) { $header += "" }
          [void]$out.Add("| " + ($header -join " | ") + " |")
          [void]$out.Add("| " + ((1..$maxCols | ForEach-Object { "---" }) -join " | ") + " |")
          for ($r = 1; $r -lt $rows.Count; $r++) {
            $row = $rows[$r]
            while ($row.Count -lt $maxCols) { $row += "" }
            [void]$out.Add("| " + ($row -join " | ") + " |")
          }
          continue
        }
      }
      foreach ($b in $block) { [void]$out.Add($b) }
      continue
    }
    [void]$out.Add($line)
    $i++
  }
  return (@($out) -join "`n")
}

function Build-LinkMap {
  param([object[]]$Sections)
  $map = @{}
  foreach ($sec in $Sections) {
    $map[$sec.Title.ToLowerInvariant()] = $sec.Title
  }
  $aliases = @{
    "atributos" = "Atributos"
    "valores de habilidade" = "Valores de Habilidades e Modificadores"
    "valor de habilidade" = "Valores de Habilidades e Modificadores"
    "força" = "Usando Cada Habilidade"
    "destreza" = "Usando Cada Habilidade"
    "constituição" = "Usando Cada Habilidade"
    "inteligência" = "Usando Cada Habilidade"
    "sabedoria" = "Usando Cada Habilidade"
    "carisma" = "Usando Cada Habilidade"
    "perícias" = "Testes de Habilidade"
    "perícia" = "Testes de Habilidade"
    "combate" = "Combate"
    "magia" = "Magia"
    "magias" = "Magias"
    "classe" = "Classes"
    "classes" = "Classes"
    "raça" = "Raças"
    "raças" = "Raças"
    "equipamento" = "Equipamento"
    "condições" = "Condições"
    "condição" = "Condições"
    "criação de personagem" = "Criação de Personagem"
    "antecedentes" = "Antecedentes"
    "armaduras" = "Armaduras e Escudos"
    "escudos" = "Armaduras e Escudos"
    "armas" = "Armas"
    "talentos" = "Talentos"
    "multiclasse" = "Multiclasse"
  }
  foreach ($k in $aliases.Keys) { $map[$k] = $aliases[$k] }
  return $map
}

function Apply-Wikilinks {
  param([string]$Text, [hashtable]$LinkMap, [string]$CurrentTitle)
  $lines = $Text -split "`n"
  $keys = @($LinkMap.Keys | Sort-Object Length -Descending)
  $inYaml = $false
  $result = New-Object Collections.ArrayList
  foreach ($line in $lines) {
    $work = $line
    if ($work.Trim() -eq "---") {
      $inYaml = -not $inYaml
      [void]$result.Add($work)
      continue
    }
    if ($inYaml -or $work -match '^\s*(#|>|```|\|)') {
      [void]$result.Add($work)
      continue
    }
    foreach ($key in $keys) {
      $target = $LinkMap[$key]
      if ($target -eq $CurrentTitle) { continue }
      $escaped = [regex]::Escape($key)
      $pattern = "(?i)(?<![\p{L}\p{N}\[\|])$escaped(?![\p{L}\p{N}\]\|])"
      $work = [regex]::Replace($work, $pattern, {
        param($m)
        if ($m.Value -eq $target) { return "[[$target]]" }
        return "[[$target|$($m.Value)]]"
      }, 1)
    }
    [void]$result.Add($work)
  }
  return (@($result) -join "`n")
}

function Get-RelatedLinks {
  param([object]$Section)
  $links = New-Object Collections.ArrayList
  [void]$links.Add("00 Sumário")
  switch -Regex ($Section.Folder) {
    "01 Criação" {
      foreach ($x in @("Raças","Classes","Atributos","Equipamento","Antecedentes")) { [void]$links.Add($x) }
      break
    }
    "02 Raças" {
      foreach ($x in @("Criação de Personagem","Classes","Atributos")) { [void]$links.Add($x) }
      break
    }
    "03 Classes" {
      foreach ($x in @("Criação de Personagem","Atributos","Equipamento","Magia","Lista de Magias")) { [void]$links.Add($x) }
      break
    }
    "04 Personalidade" {
      foreach ($x in @("Criação de Personagem","Inspiração","Testes de Habilidade")) { [void]$links.Add($x) }
      break
    }
    "05 Equipamento" {
      foreach ($x in @("Criação de Personagem","Classes","Combate","Armas","Armaduras e Escudos")) { [void]$links.Add($x) }
      break
    }
    "06 Opções" {
      foreach ($x in @("Classes","Talentos","Atributos")) { [void]$links.Add($x) }
      break
    }
    "07 Atributos" {
      foreach ($x in @("Testes de Habilidade","Testes de Resistência","Combate")) { [void]$links.Add($x) }
      break
    }
    "08 Aventurando" {
      foreach ($x in @("Atributos","Testes de Habilidade","Combate","Descanso")) { [void]$links.Add($x) }
      break
    }
    "09 Combate" {
      foreach ($x in @("Ações em Combate","Dano e Cura","Condições","Armas","Magia")) { [void]$links.Add($x) }
      break
    }
    "10 Magia" {
      foreach ($x in @("Conjurando uma Magia","Lista de Magias","Descrição de Magias","Classes")) { [void]$links.Add($x) }
      break
    }
    "11 Magias" {
      foreach ($x in @("Magia","Conjurando uma Magia","Lista de Magias","Classes")) { [void]$links.Add($x) }
      break
    }
    "Apêndices" {
      foreach ($x in @("Condições","Combate","Magia","Aventurando-se")) { [void]$links.Add($x) }
      break
    }
    default {
      foreach ($x in @("Criação de Personagem","Combate","Magia")) { [void]$links.Add($x) }
    }
  }
  $unique = @($links | Where-Object { $_ -and $_ -ne $Section.Title } | Select-Object -Unique)
  return $unique
}

function Make-Note {
  param(
    [object]$Section,
    [string]$Body,
    [hashtable]$LinkMap,
    [ref]$TableReport
  )
  $title = $Section.Title
  $tags = @($Section.Tags) -join "`n  - "
  if ($tags.Length -gt 0) { $tags = "  - " + $tags }
  $front = @(
    "---",
    "title: `"$((Escape-Yaml $title))`"",
    "capitulo: `"$((Escape-Yaml $Section.Chapter))`"",
    "pagina_inicial: $($Section.PageStart)",
    "pagina_final: $($Section.PageEnd)",
    "fonte: `"Livro do Jogador`"",
    "tipo: regra",
    "tags:",
    $tags,
    "---",
    ""
  ) -join "`n"
  $content = if ($Body.Trim().Length -gt 0) { $Body.Trim() } else { "_Texto não extraído nesta passagem. Ver relatório de extração._" }
  $content = Convert-PossibleTables $content $TableReport $title
  $related = Get-RelatedLinks $Section
  $relatedBlock = ""
  if ($related.Count -gt 0) {
    $relatedBlock = "## Relacionados`n" + (@($related | ForEach-Object { "- [[$_]]" }) -join "`n") + "`n`n"
  }
  return $front + "# $title`n`n" + $relatedBlock + $content.Trim() + "`n"
}

function Try-SplitSpellNotes {
  param(
    [string]$SpellText,
    [string]$Folder,
    [hashtable]$LinkMap,
    [ref]$Created,
    [ref]$TableReport
  )
  $lines = @($SpellText -split "`n")
  $headers = New-Object Collections.ArrayList
  for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
    $a = $lines[$i].Trim()
    $b = $lines[$i + 1].Trim()
    if ($a.Length -ge 3 -and $a.Length -le 70 -and $a -notmatch '^[>#|_-]' -and $a -notmatch '[.;:]$' -and $b -match '(?i)(truque|\d+\s*[°ºo]\s*n[ií]vel).*(abjura|adivinha|conjura|encanta|evoca|ilus|necrom|transmuta)') {
      [void]$headers.Add([pscustomobject]@{ Index = $i; Title = $a })
    }
  }
  if ($headers.Count -lt 20) { return 0 }
  $spellDir = Join-Part $Folder "Descrições de Magias"
  Ensure-Dir $spellDir
  for ($h = 0; $h -lt $headers.Count; $h++) {
    $start = $headers[$h].Index
    $end = if ($h + 1 -lt $headers.Count) { $headers[$h + 1].Index - 1 } else { $lines.Count - 1 }
    $title = Slugify-FileName $headers[$h].Title
    if ($title.Length -lt 2) { continue }
    $body = (@($lines[$start..$end]) -join "`n").Trim()
    $sec = [pscustomobject]@{
      Title = $title
      Folder = "11 Magias\Descrições de Magias"
      PageStart = 215
      PageEnd = 289
      Chapter = "Capítulo 11"
      Tags = @("dnd/regras/magias","dnd/regras/magia")
    }
    $note = Make-Note $sec $body $LinkMap $TableReport
    $path = Join-Part $spellDir ((Slugify-FileName $title) + ".md")
    Write-Utf8 $path $note
    $Created.Value.Add($path) | Out-Null
  }
  return $headers.Count
}

function Validate-Wikilinks {
  param([string[]]$Files, [hashtable]$TitleToPath)
  $broken = New-Object Collections.ArrayList
  foreach ($file in $Files) {
    $text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($text, '\[\[([^\]#\|]+)(#[^\]\|]+)?(\|[^\]]+)?\]\]')) {
      $target = $m.Groups[1].Value.Trim()
      if (-not $TitleToPath.ContainsKey($target)) {
        [void]$broken.Add([pscustomobject]@{ File = $file; Link = $target })
      }
    }
  }
  return @($broken)
}

function Relative-ToOut {
  param([string]$Path, [string]$Root)
  $full = [IO.Path]::GetFullPath($Path)
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
  if ($full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($rootFull.Length)
  }
  return $Path
}

$requiredDirs = @(
  "01 Criação de Personagem",
  "02 Raças",
  "03 Classes",
  "04 Personalidade e Antecedentes",
  "05 Equipamento",
  "06 Opções de Customização",
  "07 Atributos",
  "08 Aventurando-se",
  "09 Combate",
  "10 Magia",
  "11 Magias",
  "Apêndices",
  "Índices",
  "_extração",
  "_relatórios"
)

Ensure-Dir $OutDir
foreach ($d in $requiredDirs) { Ensure-Dir (Join-Part $OutDir $d) }

Write-Host "Lendo PDF..."
$model = Read-PdfModel $PdfPath
$pageObjects = Get-PageTreeOrder $model
Write-Host "Paginas detectadas: $($pageObjects.Count)"
$pageResult = Get-PageTexts $model $pageObjects
$pages = @($pageResult.Pages)
$sections = Get-SectionEndPages (Get-Sections) $pages.Count
$linkMap = Build-LinkMap $sections
$created = New-Object Collections.ArrayList
$tableReport = New-Object Collections.ArrayList
$titleToPath = @{}

foreach ($sec in $sections) {
  $folderPath = Join-Part $OutDir $sec.Folder
  Ensure-Dir $folderPath
  $body = Get-PagesRangeText $pages ([int]$sec.PageStart) ([int]$sec.PageEnd)
  $note = Make-Note $sec $body $linkMap ([ref]$tableReport)
  $fileName = (Slugify-FileName $sec.Title) + ".md"
  $path = Join-Part $folderPath $fileName
  Write-Utf8 $path $note
  [void]$created.Add($path)
  $titleToPath[$sec.Title] = $path
}

$spellMainPath = Join-Part (Join-Part $OutDir "11 Magias") "Descrição de Magias.md"
if (Test-Path -Path $spellMainPath) {
  $spellText = [IO.File]::ReadAllText($spellMainPath, [Text.Encoding]::UTF8)
  $spellCount = Try-SplitSpellNotes $spellText (Join-Part $OutDir "11 Magias") $linkMap ([ref]$created) ([ref]$tableReport)
} else {
  $spellCount = 0
}

$titleToPath = @{}
foreach ($file in @($created)) {
  $name = [IO.Path]::GetFileNameWithoutExtension($file)
  if (-not $titleToPath.ContainsKey($name)) { $titleToPath[$name] = $file }
}

$summary = New-Object Collections.ArrayList
[void]$summary.Add("---")
[void]$summary.Add('title: "D&D 5e - Livro do Jogador"')
[void]$summary.Add('tipo: sumario')
[void]$summary.Add('tags:')
[void]$summary.Add('  - dnd/regras')
[void]$summary.Add('  - obsidian/sumario')
[void]$summary.Add("---")
[void]$summary.Add("")
[void]$summary.Add("# D&D 5e - Livro do Jogador")
[void]$summary.Add("")
[void]$summary.Add("> Fonte: PDF local. Base gerada automaticamente; revise tabelas e trechos com layout complexo.")
[void]$summary.Add("")
foreach ($folder in $requiredDirs | Where-Object { $_ -notmatch '^_' }) {
  [void]$summary.Add("## $folder")
  foreach ($sec in @($sections | Where-Object { $_.Folder -eq $folder })) {
    [void]$summary.Add("- [[$($sec.Title)]] - p. $($sec.PageStart)-$($sec.PageEnd)")
  }
  if ($folder -eq "11 Magias" -and $spellCount -gt 0) {
    [void]$summary.Add("- [[Descrição de Magias]]")
    [void]$summary.Add("- Pasta: 11 Magias/Descrições de Magias/ ($spellCount notas detectadas automaticamente)")
  }
  [void]$summary.Add("")
}
[void]$summary.Add("## Relatórios")
[void]$summary.Add("- [[relatorio-extracao]]")
[void]$summary.Add("- [[arquivos-criados]]")
[void]$summary.Add("- [[validacao]]")
[void]$summary.Add("- [[links-quebrados]]")
$summaryPath = Join-Part $OutDir "00 Sumário.md"
Write-Utf8 $summaryPath (@($summary) -join "`n")
[void]$created.Add($summaryPath)
$titleToPath["D&D 5e - Livro do Jogador"] = $summaryPath

$createdReport = New-Object Collections.ArrayList
[void]$createdReport.Add("# Arquivos criados")
[void]$createdReport.Add("")
foreach ($file in @($created | Sort-Object)) {
  [void]$createdReport.Add("- " + (Relative-ToOut $file $OutDir))
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "arquivos-criados.md") (@($createdReport) -join "`n")

$allMd = @(Get-ChildItem -Path $OutDir -Filter "*.md" -Recurse | ForEach-Object { $_.FullName })
$titleIndex = @{}
foreach ($file in $allMd) {
  $titleIndex[[IO.Path]::GetFileNameWithoutExtension($file)] = $file
}
$broken = Validate-Wikilinks $allMd $titleIndex

$brokenReport = New-Object Collections.ArrayList
[void]$brokenReport.Add("# Links quebrados")
[void]$brokenReport.Add("")
if ($broken.Count -eq 0) {
  [void]$brokenReport.Add("Nenhum wikilink quebrado encontrado na validação simples.")
} else {
  foreach ($b in $broken) {
    [void]$brokenReport.Add("- " + (Relative-ToOut $b.File $OutDir) + " -> [[" + $b.Link + "]]")
  }
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "links-quebrados.md") (@($brokenReport) -join "`n")

$validation = New-Object Collections.ArrayList
[void]$validation.Add("# Validação")
[void]$validation.Add("")
[void]$validation.Add("- PDF lido: " + (Test-Path -Path $PdfPath))
[void]$validation.Add("- Diretório de destino: " + (Test-Path -Path $OutDir))
[void]$validation.Add("- Sumário principal: " + (Test-Path -Path $summaryPath))
[void]$validation.Add("- Páginas detectadas: $($pages.Count)")
[void]$validation.Add("- Objetos PDF brutos: $($model.ObjectMarkers)")
[void]$validation.Add("- Objetos expandidos de ObjStm: $($model.ExpandedObjects)")
[void]$validation.Add("- Notas Markdown encontradas: $($allMd.Count)")
[void]$validation.Add("- Notas de magia individuais: $spellCount")
[void]$validation.Add("- Links quebrados: $($broken.Count)")
[void]$validation.Add("")
[void]$validation.Add("## Pastas esperadas")
foreach ($d in $requiredDirs) {
  [void]$validation.Add("- " + $d + ": " + (Test-Path -Path (Join-Part $OutDir $d)))
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "validacao.md") (@($validation) -join "`n")

$streamCount = ([regex]::Matches($model.Source, '(?s)stream\r?\n')).Count
$flateCount = ($model.OrderedObjects | Where-Object { $_.Dict -match '/FlateDecode' }).Count
$textPages = @($pages | Where-Object { $_.Text.Trim().Length -gt 0 }).Count
$extractReport = New-Object Collections.ArrayList
[void]$extractReport.Add("# Relatório de extração")
[void]$extractReport.Add("")
[void]$extractReport.Add("## Diagnóstico")
[void]$extractReport.Add("- O PDF possui texto extraível: sim, há operadores de texto em streams decodificadas.")
[void]$extractReport.Add("- OCR obrigatório: não para esta primeira versão.")
[void]$extractReport.Add("- Observação: o PDF usa object streams; por isso o script expande ObjStm antes de reconstruir a ordem das páginas.")
[void]$extractReport.Add("- Tabelas e colunas podem exigir revisão manual, porque o texto de PDF nem sempre preserva layout.")
[void]$extractReport.Add("")
[void]$extractReport.Add("## Métricas")
[void]$extractReport.Add("- Bytes do PDF: $($model.Bytes.Length)")
[void]$extractReport.Add("- Objetos PDF brutos: $($model.ObjectMarkers)")
[void]$extractReport.Add("- Objetos expandidos: $($model.ExpandedObjects)")
[void]$extractReport.Add("- Streams detectadas: $streamCount")
[void]$extractReport.Add("- Streams com FlateDecode: $flateCount")
[void]$extractReport.Add("- Páginas detectadas: $($pages.Count)")
[void]$extractReport.Add("- Páginas com texto extraído: $textPages")
[void]$extractReport.Add("- Notas criadas: $($created.Count)")
[void]$extractReport.Add("- Notas individuais de magia: $spellCount")
[void]$extractReport.Add("")
[void]$extractReport.Add("## Problemas de extração")
if ($pageResult.Problems.Count -eq 0) {
  [void]$extractReport.Add("- Nenhum problema de stream registrado.")
} else {
  foreach ($p in $pageResult.Problems) { [void]$extractReport.Add("- $p") }
}
[void]$extractReport.Add("")
[void]$extractReport.Add("## Tabelas para revisar")
if ($tableReport.Count -eq 0) {
  [void]$extractReport.Add("- Nenhuma tabela candidata foi convertida automaticamente.")
} else {
  foreach ($t in $tableReport) { [void]$extractReport.Add("- $t") }
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "relatorio-extracao.md") (@($extractReport) -join "`n")

$allMd = @(Get-ChildItem -Path $OutDir -Filter "*.md" -Recurse | ForEach-Object { $_.FullName })
$titleIndex = @{}
foreach ($file in $allMd) {
  $titleIndex[[IO.Path]::GetFileNameWithoutExtension($file)] = $file
}
$broken = Validate-Wikilinks $allMd $titleIndex
$actualSpellDir = Join-Part (Join-Part $OutDir "11 Magias") "Descrições de Magias"
$actualSpellFiles = 0
if (Test-Path -Path $actualSpellDir) {
  $actualSpellFiles = @(Get-ChildItem -Path $actualSpellDir -Filter "*.md" | ForEach-Object { $_.FullName }).Count
}

$createdReport = New-Object Collections.ArrayList
[void]$createdReport.Add("# Arquivos criados")
[void]$createdReport.Add("")
foreach ($file in @($allMd | Sort-Object)) {
  [void]$createdReport.Add("- " + (Relative-ToOut $file $OutDir))
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "arquivos-criados.md") (@($createdReport) -join "`n")

$brokenReport = New-Object Collections.ArrayList
[void]$brokenReport.Add("# Links quebrados")
[void]$brokenReport.Add("")
if ($broken.Count -eq 0) {
  [void]$brokenReport.Add("Nenhum wikilink quebrado encontrado na validação simples.")
} else {
  foreach ($b in $broken) {
    [void]$brokenReport.Add("- " + (Relative-ToOut $b.File $OutDir) + " -> [[" + $b.Link + "]]")
  }
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "links-quebrados.md") (@($brokenReport) -join "`n")

$validation = New-Object Collections.ArrayList
[void]$validation.Add("# Validação")
[void]$validation.Add("")
[void]$validation.Add("- PDF lido: " + (Test-Path -Path $PdfPath))
[void]$validation.Add("- Diretório de destino: " + (Test-Path -Path $OutDir))
[void]$validation.Add("- Sumário principal: " + (Test-Path -Path $summaryPath))
[void]$validation.Add("- Páginas detectadas: $($pages.Count)")
[void]$validation.Add("- Objetos PDF brutos: $($model.ObjectMarkers)")
[void]$validation.Add("- Objetos expandidos de ObjStm: $($model.ExpandedObjects)")
[void]$validation.Add("- Notas Markdown encontradas: $($allMd.Count)")
[void]$validation.Add("- Notas de magia individuais em arquivo: $actualSpellFiles")
[void]$validation.Add("- Cabeçalhos de magia detectados: $spellCount")
[void]$validation.Add("- Links quebrados: $($broken.Count)")
[void]$validation.Add("")
[void]$validation.Add("## Pastas esperadas")
foreach ($d in $requiredDirs) {
  [void]$validation.Add("- " + $d + ": " + (Test-Path -Path (Join-Part $OutDir $d)))
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "validacao.md") (@($validation) -join "`n")

$extractReport = New-Object Collections.ArrayList
[void]$extractReport.Add("# Relatório de extração")
[void]$extractReport.Add("")
[void]$extractReport.Add("## Diagnóstico")
[void]$extractReport.Add("- O PDF possui texto extraível: sim, há operadores de texto em streams decodificadas.")
[void]$extractReport.Add("- OCR obrigatório: não para esta primeira versão.")
[void]$extractReport.Add("- Observação: o PDF usa object streams; por isso o script expande ObjStm antes de reconstruir a ordem das páginas.")
[void]$extractReport.Add("- Tabelas e colunas podem exigir revisão manual, porque o texto de PDF nem sempre preserva layout.")
[void]$extractReport.Add("- A extração por página fica cacheada em _extração/paginas para reruns rápidos.")
[void]$extractReport.Add("")
[void]$extractReport.Add("## Métricas")
[void]$extractReport.Add("- Bytes do PDF: $($model.Bytes.Length)")
[void]$extractReport.Add("- Objetos PDF brutos: $($model.ObjectMarkers)")
[void]$extractReport.Add("- Objetos expandidos: $($model.ExpandedObjects)")
[void]$extractReport.Add("- Streams detectadas: $streamCount")
[void]$extractReport.Add("- Streams com FlateDecode: $flateCount")
[void]$extractReport.Add("- Páginas detectadas: $($pages.Count)")
[void]$extractReport.Add("- Páginas com texto extraído: $textPages")
[void]$extractReport.Add("- Notas Markdown encontradas: $($allMd.Count)")
[void]$extractReport.Add("- Notas individuais de magia em arquivo: $actualSpellFiles")
[void]$extractReport.Add("- Cabeçalhos de magia detectados: $spellCount")
[void]$extractReport.Add("")
[void]$extractReport.Add("## Problemas de extração")
if ($pageResult.Problems.Count -eq 0) {
  [void]$extractReport.Add("- Nenhum problema de stream registrado.")
} else {
  foreach ($p in $pageResult.Problems) { [void]$extractReport.Add("- $p") }
}
[void]$extractReport.Add("")
[void]$extractReport.Add("## Tabelas para revisar")
if ($tableReport.Count -eq 0) {
  [void]$extractReport.Add("- Nenhuma tabela candidata foi convertida automaticamente.")
} else {
  foreach ($t in $tableReport) { [void]$extractReport.Add("- $t") }
}
Write-Utf8 (Join-Part (Join-Part $OutDir "_relatórios") "relatorio-extracao.md") (@($extractReport) -join "`n")

Write-Host "Concluido."
Write-Host "Destino: $OutDir"
Write-Host "Paginas: $($pages.Count); notas markdown: $($allMd.Count); links quebrados: $($broken.Count); magias em arquivo: $actualSpellFiles; cabecalhos de magia: $spellCount"
