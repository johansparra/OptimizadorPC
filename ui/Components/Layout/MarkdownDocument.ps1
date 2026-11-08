# ============================================================
# Componente: documento Markdown
#
# Pinta los bloques que da Get-MarkdownBlocks (ui/Engine/Markdown.ps1)
# en un FlowDocument dentro de un RichTextBox de SOLO LECTURA. Por qué
# esa pieza y no TextBlocks sueltos:
#
#   - El texto se SELECCIONA con el ratón y se COPIA (Ctrl+C, menú del
#     botón derecho) de punta a punta, títulos y tablas incluidos, como
#     texto normal. Con un TextBlock por párrafo no se podría.
#   - El FlowDocument ya sabe de párrafos, listas anidadas y tablas.
#
# Cada bloque de código lleva encima su botón de copiar (el mismo de
# los detalles técnicos, New-CopyButton). Los enlaces abren el navegador
# por core/Shell/ExternalLink.ps1, que solo deja pasar http y https.
#
# Colores siempre por recurso del tema (regla 9). Un FlowDocument no es
# un Border: el fondo y el borde de sus piezas son OTRAS propiedades
# (TextElement.Background, Block.BorderBrush, TableCell.BorderBrush), de
# ahí Set-DocBrush.
#
# LA RUEDA DEL RATÓN. Un RichTextBox trae su propio ScrollViewer, que
# se queda la rueda aunque no tenga nada que desplazar: con el puntero
# encima del documento, la página no bajaba. Se le reenvía a quien lo
# contiene (Send-MarkdownWheel).
# ============================================================

function Set-DocBrush {
    param($El, $Property, [string]$Key)
    $El.SetResourceReference($Property, $Key)
}

<#
    El documento entero, listo para colgar en la página.

        New-MarkdownDocument -Window $Window -Blocks @(Get-GuideBlocks $guia)
#>
function New-MarkdownDocument {
    # -Toc pone un índice con las secciones ("## ") al principio, si hay
    # al menos tres: cada entrada lleva a la suya.
    param($Window, [object[]]$Blocks, [switch]$Toc)

    $doc = New-Object System.Windows.Documents.FlowDocument
    $doc.PagePadding = New-Object System.Windows.Thickness 0
    $doc.FontFamily = $Window.FindResource('BodyFont')
    $doc.FontSize = 13.5
    $doc.LineHeight = 21
    $doc.TextAlignment = 'Left'
    Set-TextFg $doc 'Text'

    $sections = New-Object System.Collections.Generic.List[object]
    foreach ($b in @($Blocks)) {
        $block = New-MarkdownBlock $Window $b
        if (-not $block) { continue }
        $doc.Blocks.Add($block)
        if ($b.Type -eq 'heading' -and [int]$b.Level -eq 2) {
            $sections.Add([PSCustomObject]@{ Text = (Get-MarkdownPlainText $b.Text); Target = $block })
        }
    }
    if ($Toc -and $sections.Count -ge 3) {
        $index = New-MarkdownToc $Window $sections.ToArray()
        $first = $doc.Blocks.FirstBlock
        if ($first -and @($Blocks)[0].Type -eq 'heading' -and [int]@($Blocks)[0].Level -eq 1) {
            $doc.Blocks.InsertAfter($first, $index)
        }
        else { $doc.Blocks.InsertBefore($first, $index) }
    }

    $box = New-Object System.Windows.Controls.RichTextBox
    $box.Document = $doc
    $box.IsReadOnly = $true
    $box.IsReadOnlyCaretVisible = $false
    # Lo encontrado con "Buscar en esta guía" se ve marcado aunque el
    # foco esté en la caja de búsqueda.
    $box.IsInactiveSelectionHighlightEnabled = $true
    # Sin esto, ni los enlaces ni los botones de copiar responden.
    $box.IsDocumentEnabled = $true
    $box.BorderThickness = New-Object System.Windows.Thickness 0
    $box.Background = [System.Windows.Media.Brushes]::Transparent
    $box.Padding = New-Object System.Windows.Thickness 0
    $box.VerticalScrollBarVisibility = 'Disabled'
    $box.HorizontalScrollBarVisibility = 'Disabled'
    Set-TextFg $box 'Text'
    $box.Add_PreviewMouseWheel({ param($s, $e) Send-MarkdownWheel $s $e })
    $box
}

# Reenvía la rueda al primer elemento de arriba, para que la página
# se desplace con el puntero encima del documento.
function Send-MarkdownWheel {
    param($Box, $E)

    if ($E.Handled) { return }
    $E.Handled = $true
    $forward = New-Object System.Windows.Input.MouseWheelEventArgs $E.MouseDevice, $E.Timestamp, $E.Delta
    $forward.RoutedEvent = [System.Windows.UIElement]::MouseWheelEvent
    $forward.Source = $Box

    $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($Box)
    while ($parent -and -not ($parent -is [System.Windows.UIElement])) {
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
    }
    if ($parent) { $parent.RaiseEvent($forward) }
}

# Un bloque de Get-MarkdownBlocks -> un Block del FlowDocument.
function New-MarkdownBlock {
    param($Window, $Block)

    switch ($Block.Type) {
        'heading'   { return (New-MarkdownHeading $Window $Block) }
        'paragraph' { return (New-MarkdownParagraph $Window $Block.Lines) }
        'quote'     { return (New-MarkdownQuote $Window $Block.Lines) }
        'code'      { return (New-MarkdownCode $Window $Block) }
        'list'      { return (New-MarkdownList $Window $Block.Items) }
        'table'     { return (New-MarkdownTable $Window $Block.Header $Block.Rows) }
        'rule'      { return (New-MarkdownRule) }
    }
    $null
}

<#
    Los trozos de una línea (negrita, cursiva, código, enlaces) dentro
    de una colección de Inlines.
#>
function Add-MarkdownInlines {
    param($Window, $Target, [string]$Text)

    foreach ($t in @(Get-MarkdownInlines $Text)) {
        $run = New-Object System.Windows.Documents.Run $t.Text
        if ($t.Bold)   { $run.FontWeight = 'SemiBold' }
        if ($t.Italic) { $run.FontStyle = 'Italic' }
        if ($t.Code) {
            $run.FontFamily = $Window.FindResource('MonoFont')
            Set-DocBrush $run ([System.Windows.Documents.TextElement]::BackgroundProperty) 'SurfaceSunken'
            Set-TextFg $run 'Accent'
        }

        if ($t.Url) {
            $link = New-Object System.Windows.Documents.Hyperlink $run
            $link.Tag = $t.Url
            $link.ToolTip = $t.Url
            Set-TextFg $link 'Accent'
            # La dirección viaja en el Tag: nada de closures (regla 4).
            $link.Add_Click({ param($s, $e) Invoke-ExternalLink ([string]$s.Tag) | Out-Null })
            $Target.Add($link)
        }
        else { $Target.Add($run) }
    }
}

function New-MarkdownHeading {
    param($Window, $Block)

    $p = New-Object System.Windows.Documents.Paragraph
    $p.FontFamily = $Window.FindResource('DisplayFont')
    switch ([int]$Block.Level) {
        1 {
            $p.FontSize = 25; $p.FontWeight = 'Bold'; $p.LineHeight = 32
            $p.Margin = New-Object System.Windows.Thickness 0, 0, 0, 14
        }
        2 {
            # Las secciones llevan una línea debajo: en una guía larga
            # es lo que deja ver dónde empieza cada una.
            $p.FontSize = 19; $p.FontWeight = 'SemiBold'; $p.LineHeight = 26
            $p.Margin = New-Object System.Windows.Thickness 0, 24, 0, 10
            $p.Padding = New-Object System.Windows.Thickness 0, 0, 0, 6
            $p.BorderThickness = New-Object System.Windows.Thickness 0, 0, 0, 1
            Set-DocBrush $p ([System.Windows.Documents.Block]::BorderBrushProperty) 'Stroke'
        }
        3 {
            $p.FontSize = 15.5; $p.FontWeight = 'SemiBold'; $p.LineHeight = 22
            $p.Margin = New-Object System.Windows.Thickness 0, 16, 0, 4
        }
        default {
            $p.FontSize = 14; $p.FontWeight = 'SemiBold'
            $p.Margin = New-Object System.Windows.Thickness 0, 12, 0, 4
        }
    }
    Add-MarkdownInlines $Window $p.Inlines $Block.Text
    $p
}

# Un párrafo: sus líneas visibles separadas por saltos de línea.
function New-MarkdownParagraph {
    param($Window, [string[]]$Lines)

    $p = New-Object System.Windows.Documents.Paragraph
    $p.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    $first = $true
    foreach ($line in @($Lines)) {
        if (-not $first) { $p.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) }
        Add-MarkdownInlines $Window $p.Inlines $line
        $first = $false
    }
    $p
}

function New-MarkdownQuote {
    param($Window, [string[]]$Lines)

    $p = New-MarkdownParagraph $Window $Lines
    $p.Margin = New-Object System.Windows.Thickness 0, 4, 0, 14
    $p.Padding = New-Object System.Windows.Thickness 14, 9, 12, 9
    $p.BorderThickness = New-Object System.Windows.Thickness 3, 0, 0, 0
    Set-DocBrush $p ([System.Windows.Documents.Block]::BorderBrushProperty) 'Accent'
    Set-DocBrush $p ([System.Windows.Documents.TextElement]::BackgroundProperty) 'AccentSoft'
    $p
}

<#
    Un bloque de código: una franja con el lenguaje y el botón de
    copiar, y debajo el código tal cual (respetando la sangría), en
    monoespaciada.
#>
function New-MarkdownCode {
    param($Window, $Block)

    $section = New-Object System.Windows.Documents.Section
    $section.Margin = New-Object System.Windows.Thickness 0, 4, 0, 16
    $section.Padding = New-Object System.Windows.Thickness 14, 8, 10, 12
    $section.BorderThickness = New-Object System.Windows.Thickness 1
    Set-DocBrush $section ([System.Windows.Documents.TextElement]::BackgroundProperty) 'SurfaceSunken'
    Set-DocBrush $section ([System.Windows.Documents.Block]::BorderBrushProperty) 'Stroke'

    $bar = New-Object System.Windows.Controls.Grid
    Add-GridColumns $bar '*', 'Auto'
    $lang = New-Object System.Windows.Controls.TextBlock
    $lang.Text = ([string]$Block.Lang).ToUpperInvariant()
    $lang.FontFamily = $Window.FindResource('MonoFont')
    $lang.FontSize = 10.5
    $lang.VerticalAlignment = 'Center'
    Set-TextFg $lang 'TextFaint'
    Add-ToColumn $bar $lang 0
    Add-ToColumn $bar (New-CopyButton ([string]$Block.Text) 'Copy the code') 1
    $section.Blocks.Add((New-Object System.Windows.Documents.BlockUIContainer $bar))

    $code = New-Object System.Windows.Documents.Paragraph
    $code.Margin = New-Object System.Windows.Thickness 0, 4, 0, 0
    $code.FontFamily = $Window.FindResource('MonoFont')
    $code.FontSize = 12.5
    $code.LineHeight = 18
    $first = $true
    foreach ($line in ([string]$Block.Text -split "`n")) {
        if (-not $first) { $code.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) }
        $code.Inlines.Add((New-Object System.Windows.Documents.Run $line))
        $first = $false
    }
    $section.Blocks.Add($code)
    $section
}

<#
    Una lista, anidada por niveles: cada nivel nuevo es una List dentro
    del último elemento del nivel de arriba. Los números empiezan donde
    empiece la lista de la guía.
#>
function New-MarkdownList {
    param($Window, [object[]]$Items)

    $root = $null
    $stack = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Items)) {
        while ($stack.Count -gt ($item.Level + 1)) { $stack.RemoveAt($stack.Count - 1) }
        while ($stack.Count -lt ($item.Level + 1)) {
            $list = New-MarkdownListBlock $item $stack.Count
            if ($stack.Count -eq 0) { $root = $list }
            else {
                $parent = $stack[$stack.Count - 1]
                if ($parent.ListItems.Count -eq 0) { $parent.ListItems.Add((New-Object System.Windows.Documents.ListItem)) }
                $parent.ListItems.LastListItem.Blocks.Add($list)
            }
            $stack.Add($list)
        }

        $p = New-Object System.Windows.Documents.Paragraph
        $p.Margin = New-Object System.Windows.Thickness 0, 1, 0, 2
        Add-MarkdownInlines $Window $p.Inlines $item.Text
        $stack[$stack.Count - 1].ListItems.Add((New-Object System.Windows.Documents.ListItem $p))
    }
    $root
}

function New-MarkdownListBlock {
    param($Item, [int]$Depth)

    $list = New-Object System.Windows.Documents.List
    if ($Item.Ordered) {
        $list.MarkerStyle = 'Decimal'
        if ($Item.Number -gt 1) { $list.StartIndex = $Item.Number }
    }
    else {
        $list.MarkerStyle = if ($Depth -eq 0) { 'Disc' } else { 'Circle' }
    }
    $list.Padding = New-Object System.Windows.Thickness 24, 0, 0, 0
    $bottom = if ($Depth -eq 0) { 12 } else { 2 }
    $list.Margin = New-Object System.Windows.Thickness 0, 2, 0, $bottom
    $list
}

<#
    Una tabla. Las columnas se reparten el ancho según lo que lleva
    cada una (la media de largo de sus celdas, con tope por arriba y
    por abajo): en la guía de la tarjeta de red, la columna del "por
    qué" es diez veces la del valor, y a partes iguales se leía mal.
#>
function New-MarkdownTable {
    param($Window, [string[]]$Header, [object[]]$Rows)

    $count = @($Header).Count
    foreach ($r in @($Rows)) { if (@($r).Count -gt $count) { $count = @($r).Count } }

    $table = New-Object System.Windows.Documents.Table
    $table.CellSpacing = 0
    $table.Margin = New-Object System.Windows.Thickness 0, 4, 0, 18
    $table.BorderThickness = New-Object System.Windows.Thickness 1, 1, 0, 0
    Set-DocBrush $table ([System.Windows.Documents.Block]::BorderBrushProperty) 'Stroke'

    for ($c = 0; $c -lt $count; $c++) {
        $total = 0; $n = 0
        foreach ($r in (@(, $Header) + @($Rows))) {
            if ($c -lt @($r).Count) { $total += ([string]@($r)[$c]).Length; $n++ }
        }
        $avg = if ($n -gt 0) { $total / $n } else { 1 }
        $weight = [Math]::Min(60, [Math]::Max(6, $avg))
        $col = New-Object System.Windows.Documents.TableColumn
        $col.Width = New-Object System.Windows.GridLength ($weight, [System.Windows.GridUnitType]::Star)
        $table.Columns.Add($col)
    }

    $group = New-Object System.Windows.Documents.TableRowGroup
    $group.Rows.Add((New-MarkdownTableRow $Window $Header $count $true))
    foreach ($r in @($Rows)) { $group.Rows.Add((New-MarkdownTableRow $Window @($r) $count $false)) }
    $table.RowGroups.Add($group)
    $table
}

function New-MarkdownTableRow {
    param($Window, [string[]]$Cells, [int]$Count, [bool]$Header)

    $row = New-Object System.Windows.Documents.TableRow
    if ($Header) { Set-DocBrush $row ([System.Windows.Documents.TextElement]::BackgroundProperty) 'SurfaceSunken' }

    for ($k = 0; $k -lt $Count; $k++) {
        $text = if ($k -lt @($Cells).Count) { [string]@($Cells)[$k] } else { '' }
        $p = New-Object System.Windows.Documents.Paragraph
        $p.Margin = New-Object System.Windows.Thickness 0
        $p.FontSize = 12.5
        $p.LineHeight = 18
        if ($Header) { $p.FontWeight = 'SemiBold' }
        Add-MarkdownInlines $Window $p.Inlines $text

        $cell = New-Object System.Windows.Documents.TableCell $p
        $cell.Padding = New-Object System.Windows.Thickness 10, 7, 10, 7
        $cell.BorderThickness = New-Object System.Windows.Thickness 0, 0, 1, 1
        Set-DocBrush $cell ([System.Windows.Documents.TableCell]::BorderBrushProperty) 'Stroke'
        $row.Cells.Add($cell)
    }
    $row
}

function New-MarkdownRule {
    $p = New-Object System.Windows.Documents.Paragraph
    $p.Margin = New-Object System.Windows.Thickness 0, 10, 0, 18
    $p.FontSize = 1
    $p.LineHeight = 1
    $p.BorderThickness = New-Object System.Windows.Thickness 0, 0, 0, 1
    Set-DocBrush $p ([System.Windows.Documents.Block]::BorderBrushProperty) 'Stroke'
    $p
}

# ---- índice ----------------------------------------------------------

<#
    "Contenido": una lista con las secciones de la guía. Cada entrada es
    un enlace que lleva a la suya (BringIntoView desplaza la página).
#>
function New-MarkdownToc {
    param($Window, [object[]]$Sections)

    $section = New-Object System.Windows.Documents.Section
    $section.Margin = New-Object System.Windows.Thickness 0, 0, 0, 18
    $section.Padding = New-Object System.Windows.Thickness 14, 10, 14, 10
    $section.BorderThickness = New-Object System.Windows.Thickness 1
    Set-DocBrush $section ([System.Windows.Documents.TextElement]::BackgroundProperty) 'SurfaceSunken'
    Set-DocBrush $section ([System.Windows.Documents.Block]::BorderBrushProperty) 'Stroke'

    $title = New-Object System.Windows.Documents.Paragraph (New-Object System.Windows.Documents.Run (T 'Contents'))
    $title.FontWeight = 'SemiBold'
    $title.FontSize = 12.5
    $title.Margin = New-Object System.Windows.Thickness 0, 0, 0, 4
    Set-TextFg $title 'TextMuted'
    $section.Blocks.Add($title)

    $list = New-Object System.Windows.Documents.List
    $list.MarkerStyle = 'None'
    $list.Padding = New-Object System.Windows.Thickness 0
    $list.Margin = New-Object System.Windows.Thickness 0
    foreach ($s in @($Sections)) {
        $link = New-Object System.Windows.Documents.Hyperlink (New-Object System.Windows.Documents.Run $s.Text)
        $link.Tag = $s.Target
        $link.TextDecorations = $null
        Set-TextFg $link 'Accent'
        # El destino en el Tag (regla 4).
        $link.Add_Click({ param($s, $e) $s.Tag.BringIntoView() })
        $p = New-Object System.Windows.Documents.Paragraph $link
        $p.Margin = New-Object System.Windows.Thickness 0, 1, 0, 1
        $p.FontSize = 12.5
        $list.ListItems.Add((New-Object System.Windows.Documents.ListItem $p))
    }
    $section.Blocks.Add($list)
    $section
}

# ---- buscar dentro del documento -------------------------------------

<#
    Busca $Text en el documento (sin distinguir mayúsculas) a partir de
    $From y devuelve el TextRange de la primera aparición, o $null. Va
    trozo de texto a trozo de texto: una palabra partida entre negrita y
    texto normal no se encuentra, y para unas notas basta.
#>
function Find-MarkdownRange {
    param($Document, [string]$Text, $From)

    $p = if ($From) { $From } else { $Document.ContentStart }
    $end = $Document.ContentEnd
    while ($p -and $p.CompareTo($end) -lt 0) {
        if ($p.GetPointerContext('Forward') -eq 'Text') {
            $run = $p.GetTextInRun('Forward')
            $i = $run.IndexOf($Text, [System.StringComparison]::OrdinalIgnoreCase)
            if ($i -ge 0) {
                $start = $p.GetPositionAtOffset($i)
                return (New-Object System.Windows.Documents.TextRange $start, $start.GetPositionAtOffset($Text.Length))
            }
            $p = $p.GetPositionAtOffset($run.Length)
        }
        else { $p = $p.GetNextContextPosition('Forward') }
    }
    $null
}

# Cuántas veces aparece $Text en el documento.
function Measure-MarkdownMatches {
    param($Document, [string]$Text)
    if (-not $Text) { return 0 }
    $n = 0
    $r = Find-MarkdownRange $Document $Text $null
    while ($r) {
        $n++
        $r = Find-MarkdownRange $Document $Text $r.End
    }
    $n
}

<#
    Marca la siguiente aparición de $Text después de la selección actual
    (o la primera, con -FromStart) y la trae a la vista; al llegar al
    final vuelve a empezar. Devuelve cuántas hay en total.
#>
function Select-MarkdownMatch {
    param($Box, [string]$Text, [switch]$FromStart)

    $doc = $Box.Document
    if (-not $Text) {
        $Box.Selection.Select($doc.ContentStart, $doc.ContentStart)
        return 0
    }
    $from = if ($FromStart) { $null } else { $Box.Selection.End }
    $r = Find-MarkdownRange $doc $Text $from
    if (-not $r -and $from) { $r = Find-MarkdownRange $doc $Text $null }
    if (-not $r) { return 0 }

    $Box.Selection.Select($r.Start, $r.End)
    $paragraph = $r.Start.Paragraph
    if ($paragraph) { $paragraph.BringIntoView() }
    Measure-MarkdownMatches $doc $Text
}
