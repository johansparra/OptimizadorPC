# ============================================================
# ui/Engine/Markdown.ps1
# Leer Markdown: texto -> bloques -> trozos de línea.
#
# Es un MECANISMO: no sabe de controles ni de colores. Devuelve
# datos y quien pinta es ui/Components/Layout/MarkdownDocument.ps1.
#
# Entiende lo que usan las guías de ui/Data/Guides, no todo
# CommonMark, y lo que no entiende sale como texto:
#
#   # ## ###          títulos
#   ```lang ... ```   bloques de código
#   | a | b |         tablas (con la fila |---| debajo de la cabecera)
#   - * + / 1.        listas, anidadas por sangría
#   >                 citas
#   ---               separador
#   **negrita**  *cursiva*  `código`  [texto](url)  https://...
#
# UNA DECISIÓN QUE NO ES DE CommonMark: los saltos de línea dentro
# de un párrafo. Las guías hacen dos cosas distintas con ellos:
#
#   **Qué hace:** Limita...        <- una línea por dato: el salto
#   **Valores:** `0x0A`...            ES el formato
#
#   Todo esto en `taskschd.msc`, dentro de **Biblioteca del Programador de
#   tareas > Microsoft > Windows**.  <- párrafo cortado a mano a 80
#                                      columnas: el salto NO significa nada
#
# CommonMark juntaría las dos cosas. Aquí una línea que EMPIEZA con
# negrita abre línea nueva (es una etiqueta, como "Qué hace:"), igual
# que la que acaba en dos espacios o en "\"; el resto se junta con la
# anterior.
#
# Ojo con el nombre: ConvertFrom-Markdown ya existe en PowerShell 7.
# ============================================================

<#
    El texto entero en bloques, en orden. Cada bloque es un objeto
    con Type y lo suyo:

        heading    Level (1-6), Text
        paragraph  Lines   (ya juntadas: una por línea visible)
        quote      Lines
        code       Lang, Text
        list       Items   (cada una: Level, Ordered, Number, Text)
        table      Header (celdas), Rows (filas de celdas)
        rule

    Los textos van con sus marcas (**, `...): los trozos los saca
    Get-MarkdownInlines al pintar.
#>
function Get-MarkdownBlocks {
    param([AllowEmptyString()][string]$Text)

    $blocks = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Text)) { return $blocks.ToArray() }

    $lines = ($Text.TrimStart([char]0xFEFF) -replace "`r`n", "`n" -replace "`r", "`n") -split "`n"
    $para = New-Object System.Collections.Generic.List[string]
    $i = 0

    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        # --- bloque de código: hasta la valla que lo cierra ---
        if ($line -match '^\s*```\s*([\w#+.-]*)\s*$') {
            Add-MarkdownParagraph $blocks $para
            $lang = $Matches[1]
            $code = New-Object System.Collections.Generic.List[string]
            $i++
            while ($i -lt $lines.Count -and $lines[$i] -notmatch '^\s*```\s*$') {
                $code.Add($lines[$i])
                $i++
            }
            $i++   # la valla de cierre
            $blocks.Add([PSCustomObject]@{ Type = 'code'; Lang = $lang; Text = ($code.ToArray() -join "`n") })
            continue
        }

        if ($line.Trim() -eq '') {
            Add-MarkdownParagraph $blocks $para
            $i++
            continue
        }

        if ($line -match '^(#{1,6})\s+(.*?)\s*#*\s*$') {
            Add-MarkdownParagraph $blocks $para
            $blocks.Add([PSCustomObject]@{ Type = 'heading'; Level = $Matches[1].Length; Text = $Matches[2] })
            $i++
            continue
        }

        if ($line -match '^\s*([-*_])(\s*\1){2,}\s*$') {
            Add-MarkdownParagraph $blocks $para
            $blocks.Add([PSCustomObject]@{ Type = 'rule' })
            $i++
            continue
        }

        # --- tabla: una fila con barras y debajo la de guiones ---
        if ($line -match '^\s*\|' -and ($i + 1) -lt $lines.Count -and $lines[$i + 1] -match '^\s*\|?\s*:?-{3,}') {
            Add-MarkdownParagraph $blocks $para
            $header = @(Split-MarkdownRow $line)
            $rows = New-Object System.Collections.Generic.List[object]
            $i += 2
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s*\|') {
                $rows.Add(@(Split-MarkdownRow $lines[$i]))
                $i++
            }
            $blocks.Add([PSCustomObject]@{ Type = 'table'; Header = $header; Rows = $rows.ToArray() })
            continue
        }

        if ($line -match '^\s*>') {
            Add-MarkdownParagraph $blocks $para
            $quoted = New-Object System.Collections.Generic.List[string]
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s*>') {
                $quoted.Add(($lines[$i] -replace '^\s*>\s?', ''))
                $i++
            }
            $blocks.Add([PSCustomObject]@{ Type = 'quote'; Lines = @(Join-MarkdownLines $quoted.ToArray()) })
            continue
        }

        if (Test-MarkdownListLine $line) {
            Add-MarkdownParagraph $blocks $para
            $items = New-Object System.Collections.Generic.List[object]
            $indents = New-Object System.Collections.Generic.List[int]
            while ($i -lt $lines.Count -and $lines[$i].Trim() -ne '') {
                $l = $lines[$i]
                if ($l -match '^(\s*)([-*+]|(\d+)[.)])\s+(.*)$') {
                    $indent = ($Matches[1] -replace "`t", '    ').Length
                    # El nivel sale de la sangría RELATIVA: subir abre un
                    # nivel, bajar cierra los que hagan falta. Así da igual
                    # que la guía sangre con 2, 3 o 4 espacios.
                    while ($indents.Count -gt 0 -and $indent -lt $indents[$indents.Count - 1]) { $indents.RemoveAt($indents.Count - 1) }
                    if ($indents.Count -eq 0 -or $indent -gt $indents[$indents.Count - 1]) { $indents.Add($indent) }
                    $number = 0
                    if ($Matches[3]) { $number = [int]$Matches[3] }
                    $items.Add([PSCustomObject]@{
                        Level = $indents.Count - 1; Ordered = [bool]$Matches[3]; Number = $number; Text = $Matches[4].Trim()
                    })
                }
                elseif ($items.Count -gt 0 -and $l -match '^\s+\S' -and -not (Test-MarkdownBlockStart $l)) {
                    # Continuación de la línea de arriba, sangrada.
                    $last = $items[$items.Count - 1]
                    $last.Text = $last.Text + ' ' + $l.Trim()
                }
                else { break }
                $i++
            }
            $blocks.Add([PSCustomObject]@{ Type = 'list'; Items = $items.ToArray() })
            continue
        }

        $para.Add($line)
        $i++
    }

    Add-MarkdownParagraph $blocks $para
    $blocks.ToArray()
}

function Test-MarkdownListLine {
    param([string]$Line)
    $Line -match '^\s*([-*+]|\d+[.)])\s+\S'
}

# ¿Empieza aquí otro bloque? Para no tragarse un título o una tabla
# como continuación de la última línea de una lista.
function Test-MarkdownBlockStart {
    param([string]$Line)
    ($Line -match '^\s*(#{1,6}\s|```|\||>)') -or (Test-MarkdownListLine $Line)
}

# Cierra el párrafo pendiente, si lo hay, y vacía la lista.
function Add-MarkdownParagraph {
    param($Blocks, $Pending)
    if ($Pending.Count -eq 0) { return }
    $Blocks.Add([PSCustomObject]@{ Type = 'paragraph'; Lines = @(Join-MarkdownLines $Pending.ToArray()) })
    $Pending.Clear()
}

<#
    Junta las líneas de un párrafo en las líneas que se VEN (ver la
    cabecera): una que empieza con negrita, o una tras otra acabada en
    dos espacios o en "\", abre línea; el resto se pega a la anterior.
#>
function Join-MarkdownLines {
    param([string[]]$Raw)

    $out = New-Object System.Collections.Generic.List[string]
    $current = $null
    $hardBreak = $false
    foreach ($r in $Raw) {
        $t = $r.Trim()
        $startsLabel = $t.StartsWith('**')
        if ($null -eq $current) { $current = $t }
        elseif ($startsLabel -or $hardBreak) { $out.Add($current); $current = $t }
        else { $current = $current + ' ' + $t }
        $hardBreak = $r.EndsWith('  ') -or $t.EndsWith('\')
        if ($t.EndsWith('\')) { $current = $current.Substring(0, $current.Length - 1).TrimEnd() }
    }
    if ($null -ne $current) { $out.Add($current) }
    $out.ToArray()
}

<#
    Las celdas de una fila de tabla. Parte por "|" salvo dentro de
    `código` o escapada como "\|", y quita las barras de los extremos.
#>
function Split-MarkdownRow {
    param([string]$Line)

    $t = $Line.Trim()
    if ($t.StartsWith('|')) { $t = $t.Substring(1) }
    if ($t.EndsWith('|') -and -not $t.EndsWith('\|')) { $t = $t.Substring(0, $t.Length - 1) }

    $cells = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $inCode = $false
    for ($k = 0; $k -lt $t.Length; $k++) {
        $c = $t[$k]
        if ($c -eq '\' -and ($k + 1) -lt $t.Length -and $t[$k + 1] -eq '|') {
            $null = $sb.Append('|'); $k++; continue
        }
        if ($c -eq '`') { $inCode = -not $inCode }
        if ($c -eq '|' -and -not $inCode) {
            $cells.Add($sb.ToString().Trim()); $null = $sb.Clear(); continue
        }
        $null = $sb.Append($c)
    }
    $cells.Add($sb.ToString().Trim())
    $cells.ToArray()
}

# ---- dentro de una línea --------------------------------------

# Código antes que nada (lo de dentro no se interpreta), luego
# negrita, enlaces, direcciones sueltas y cursiva.
$MarkdownInlinePattern = [regex](
    '(?<code>`[^`]+`)' +
    '|(?<bold>\*\*(?=\S)(?<boldtext>.+?)(?<=\S)\*\*)' +
    '|(?<link>\[(?<linktext>[^\]]+)\]\((?<linkurl>https?://[^)\s]+)\))' +
    '|(?<url>https?://[^\s<>()]*[^\s<>().,;:!?''"*])' +
    '|(?<ital>(?<![\w*])\*(?=\S)(?<italtext>[^*]+?)(?<=\S)\*(?![\w*]))'
)

<#
    Una línea en trozos, cada uno con su formato:

        Text, Bold, Italic, Code, Url

    La negrita y la cursiva pueden llevar dentro código o un enlace:
    se parten otra vez heredando el formato.
#>
function Get-MarkdownInlines {
    param([AllowEmptyString()][string]$Text, [bool]$Bold = $false, [bool]$Italic = $false)

    $out = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Text)) { return $out.ToArray() }

    $pos = 0
    foreach ($m in $MarkdownInlinePattern.Matches($Text)) {
        if ($m.Index -gt $pos) {
            $out.Add((New-MarkdownInline $Text.Substring($pos, $m.Index - $pos) $Bold $Italic))
        }
        if ($m.Groups['code'].Success) {
            $inline = New-MarkdownInline $m.Value.Trim('`') $Bold $Italic
            $inline.Code = $true
            $out.Add($inline)
        }
        elseif ($m.Groups['bold'].Success) {
            foreach ($t in @(Get-MarkdownInlines $m.Groups['boldtext'].Value $true $Italic)) { $out.Add($t) }
        }
        elseif ($m.Groups['link'].Success) {
            $inline = New-MarkdownInline $m.Groups['linktext'].Value $Bold $Italic
            $inline.Url = $m.Groups['linkurl'].Value
            $out.Add($inline)
        }
        elseif ($m.Groups['url'].Success) {
            $inline = New-MarkdownInline $m.Value $Bold $Italic
            $inline.Url = $m.Value
            $out.Add($inline)
        }
        elseif ($m.Groups['ital'].Success) {
            foreach ($t in @(Get-MarkdownInlines $m.Groups['italtext'].Value $Bold $true)) { $out.Add($t) }
        }
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $Text.Length) { $out.Add((New-MarkdownInline $Text.Substring($pos) $Bold $Italic)) }
    $out.ToArray()
}

function New-MarkdownInline {
    param([string]$Text, [bool]$Bold, [bool]$Italic)
    [PSCustomObject]@{ Text = $Text; Bold = $Bold; Italic = $Italic; Code = $false; Url = $null }
}

# La línea sin marcas, como se lee. Para títulos y resúmenes.
function Get-MarkdownPlainText {
    param([AllowEmptyString()][string]$Text)
    (@(Get-MarkdownInlines $Text) | ForEach-Object { $_.Text }) -join ''
}
