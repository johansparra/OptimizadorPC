# ============================================================
# ui/Engine/GuideRegistry.ps1
# Las guías: los .md de ui/Data/Guides, registrados para que la
# sección Guías los enseñe.
#
# CÓMO LLEGAN AQUÍ. Un .md no es código, así que no puede entrar al
# .exe como los .ps1. main.ps1 tiene para ellos su propio marcador
# (# @@EMBED_GUIDES:ui/Data/Guides@@):
#
#   en desarrollo  Import-GuideFolder lee la carpeta del disco
#   en el .exe     build.ps1 escribe, por cada .md,
#                    Register-Guide -FileName '...' -Markdown (ConvertFrom-GuideBase64 '...')
#                  en Base64 para que NINGÚN carácter del .md -una
#                  comilla, un '@ a principio de línea- pueda romper el
#                  script combinado.
#
# Las dos acaban en Register-Guide, y es lo único que ve el resto.
# Añadir una guía = soltar el .md en la carpeta (y recompilar el
# .exe). El orden es el del nombre del archivo.
#
# El contenido es del usuario: NO pasa por T. Ni el título ni el
# resumen ni el texto se traducen.
#
# La guía se lee en bloques (Get-MarkdownBlocks) la primera vez que
# se abre, no al arrancar: Get-GuideBlocks la guarda para la próxima.
# ============================================================

$GuideList = New-Object System.Collections.Generic.List[object]

# Palabras por minuto para el "N min de lectura" de la tarjeta.
$GuideWordsPerMinute = 200

# Largo máximo del resumen de la tarjeta.
$GuideSummaryMax = 220

<#
    Registra una guía. Si ya había una con el mismo archivo, la
    sustituye (volver a importar la carpeta no la duplica).

        Id        el nombre del archivo sin .md
        Title     su primer título "# ..." (sin marcas); si no tiene,
                  el nombre del archivo
        Summary   el texto antes del primer "## "; si no hay, los
                  títulos "## " seguidos
        Sections  cuántos "## " tiene
        Minutes   lectura aproximada
        Markdown  el texto entero, tal cual
#>
function Register-Guide {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Markdown
    )

    $text = $Markdown.TrimStart([char]0xFEFF) -replace "`r`n", "`n"
    $id = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $lines = $text -split "`n"

    $title = $null
    $sections = New-Object System.Collections.Generic.List[string]
    $intro = New-Object System.Collections.Generic.List[string]
    $inCode = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*```') { $inCode = -not $inCode; continue }
        if ($inCode) { continue }
        if (-not $title -and $line -match '^#\s+(.+?)\s*#*\s*$') { $title = Get-MarkdownPlainText $Matches[1]; continue }
        if ($line -match '^##\s+(.+?)\s*#*\s*$') {
            # Sin la numeración de la guía ("1) ", "2b) ", "6-13) "): en el
            # resumen solo estorba.
            $sections.Add((Get-MarkdownPlainText ($Matches[1] -replace '^\s*\d+[a-z]?(\s*[-–]\s*\d+[a-z]?)?\)\s*', '')))
            continue
        }
        # El resumen: la entrada de la guía, antes de su primera sección.
        if ($sections.Count -eq 0 -and $line.Trim() -and $line -notmatch '^\s*(#|\||>|---)') {
            $intro.Add($line.Trim())
        }
    }
    if (-not $title) { $title = $id }

    $summary = Get-MarkdownPlainText ($intro.ToArray() -join ' ')
    if (-not $summary.Trim()) { $summary = $sections.ToArray() -join ' · ' }
    if ($summary.Length -gt $GuideSummaryMax) { $summary = $summary.Substring(0, $GuideSummaryMax - 1).TrimEnd() + '…' }

    $words = @($text -split '\s+' | Where-Object { $_ }).Count
    $minutes = [Math]::Max(1, [int][Math]::Round($words / $GuideWordsPerMinute))

    $guide = [PSCustomObject]@{
        Id       = $id
        FileName = $FileName
        Title    = $title
        Summary  = $summary
        Sections = $sections.Count
        Minutes  = $minutes
        Markdown = $text
        Blocks   = $null
    }

    for ($k = 0; $k -lt $GuideList.Count; $k++) {
        if ($GuideList[$k].Id -eq $id) { $GuideList[$k] = $guide; return }
    }
    $GuideList.Add($guide)
}

# Todas, en el orden en que se registraron. Envuélvelo en @().
function Get-Guides { $GuideList.ToArray() }

function Get-GuideById {
    param([string]$Id)
    foreach ($g in $GuideList) { if ($g.Id -eq $Id) { return $g } }
    $null
}

# Los bloques de una guía, leídos la primera vez que se piden.
function Get-GuideBlocks {
    param($Guide)
    if (-not $Guide) { return @() }
    if ($null -eq $Guide.Blocks) { $Guide.Blocks = @(Get-MarkdownBlocks $Guide.Markdown) }
    $Guide.Blocks
}

<#
    Registra todos los .md de una carpeta (sin subcarpetas), por
    orden de nombre. Es la mitad "desarrollo" del marcador de
    main.ps1, y la que usan las pruebas. Una carpeta que no existe
    o un archivo que no se puede leer no rompen el arranque.
#>
function Import-GuideFolder {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    foreach ($file in @(Get-ChildItem -LiteralPath $Path -Filter '*.md' -File | Sort-Object FullName)) {
        try { Register-Guide -FileName $file.Name -Markdown ([System.IO.File]::ReadAllText($file.FullName)) }
        catch { $null = $_ }
    }
}

<#
    La guía como TEXTO NORMAL, sin marcas de Markdown: lo que copia
    "Copiar todo". Títulos y párrafos tal cual, listas con guion (o su
    número) y sangría, tablas con las celdas separadas por tabulador
    -se pegan bien en una hoja de cálculo- y el código sin tocar.
#>
function ConvertTo-GuidePlainText {
    param($Guide)

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($b in @(Get-GuideBlocks $Guide)) {
        switch ($b.Type) {
            'heading'   { $out.Add((Get-MarkdownPlainText $b.Text)) }
            'paragraph' { foreach ($l in @($b.Lines)) { $out.Add((Get-MarkdownPlainText $l)) } }
            'quote'     { foreach ($l in @($b.Lines)) { $out.Add((Get-MarkdownPlainText $l)) } }
            'code'      { $out.Add([string]$b.Text) }
            'list' {
                foreach ($it in @($b.Items)) {
                    $mark = if ($it.Ordered) { '{0}.' -f $it.Number } else { '-' }
                    $line = '{0}{1} {2}' -f ('  ' * $it.Level), $mark, (Get-MarkdownPlainText $it.Text)
                    $out.Add($line)
                }
            }
            'table' {
                foreach ($row in (@(, $b.Header) + @($b.Rows))) {
                    $out.Add(((@($row) | ForEach-Object { Get-MarkdownPlainText ([string]$_) }) -join "`t"))
                }
            }
        }
        # Una línea en blanco entre bloques; el separador ya es eso.
        if ($b.Type -ne 'rule') { $out.Add('') }
    }
    ($out.ToArray() -join [Environment]::NewLine).Trim()
}

# La mitad "exe": el texto que build.ps1 guardó en Base64 (UTF-8).
function ConvertFrom-GuideBase64 {
    param([string]$Data)
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Data))
}
