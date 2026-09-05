# ============================================================
# Componente: resultado de búsqueda
#
# El mismo resultado se enseña de dos maneras:
#
#   New-SearchResultRow    fila estrecha, para el desplegable que
#                          cuelga de la caja de búsqueda
#   New-SearchResultCard   tarjeta completa, para la página de
#                          resultados
#
# Las dos dicen lo mismo: dónde vive el resultado, cómo se llama y
# POR QUÉ ha salido -"Ruta del registro: HKEY_LOCAL_MACHINE\..."-,
# que es lo que evita el "¿y esto por qué me lo enseña?" cuando la
# coincidencia está en un campo que no se ve.
#
# Pulsar lleva a la sección con el ajuste resaltado. El dato viaja
# en el Tag: nada de closures (regla 4 de CLAUDE.md).
# ============================================================

# Lo que se guarda en el Tag de cualquier cosa pulsable de aquí.
function New-SearchResultTag {
    param($Entry, $Popup)
    [PSCustomObject]@{ Category = $Entry.Category; Setting = $Entry.Setting; Popup = $Popup }
}

<#
    Abre el resultado que lleva el emisor en el Tag.

    Un resultado de sección lleva a la sección; uno de ajuste lleva a
    la sección Y le dice cuál resaltar, que es lo que hace que al
    buscar una clave del registro acabes mirándola directamente.
#>
function Open-SearchResult {
    param($Element)

    $info = $Element.Tag
    if (-not $info) { return }

    if ($info.Popup) { $info.Popup.IsOpen = $false }

    $destino = @{ Category = $info.Category }
    if ($info.Setting) { $destino['Highlight'] = $info.Setting }

    Show-View -Name 'Show-CategoryDetailView' -Arguments $destino
}

# El título del resultado: el ajuste, o la sección si la coincidencia
# es de la sección entera.
function Get-SearchResultTitle {
    param($Entry)
    if ($Entry.Setting) { return (T $Entry.Setting.Name) }
    T $Entry.Category.Name
}

# "Ruta del registro: HKEY_LOCAL_MACHINE\..." — el campo por el que
# ha encajado, con su etiqueta traducida y el dato tal cual.
function New-SearchMatchLine {
    param($Window, $Entry, [double]$Size = 11)

    $line = New-Object System.Windows.Controls.TextBlock
    $line.FontFamily = $Window.FindResource('MonoFont')
    $line.FontSize = $Size
    $line.TextTrimming = 'CharacterEllipsis'
    $line.Margin = New-Object System.Windows.Thickness 0, 4, 0, 0

    if (-not $Entry.Match) {
        $line.Visibility = 'Collapsed'
        return $line
    }

    $etiqueta = New-Object System.Windows.Documents.Run ((T $Entry.Match.Label) + ': ')
    Set-TextFg $etiqueta 'TextFaint'
    $line.Inlines.Add($etiqueta)

    $dato = New-Object System.Windows.Documents.Run $Entry.Match.Text
    Set-TextFg $dato 'TextMuted'
    $line.Inlines.Add($dato)

    $line
}

# ---- Fila del desplegable -----------------------------------

function New-SearchResultRow {
    param($Window, $Entry, $Popup)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 9
    $row.Padding = New-Object System.Windows.Thickness 10, 7, 10, 8
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $texts = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = Get-SearchResultTitle $Entry
    $title.FontSize = 12
    $title.FontWeight = 'SemiBold'
    $title.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $texts.Children.Add((New-SearchMatchLine $Window $Entry 10.5)) | Out-Null

    $row.Child = $texts

    $row.Tag = New-SearchResultTag $Entry $Popup
    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $row.Add_MouseLeftButtonUp({ param($s, $e) Open-SearchResult $s })

    $row
}

# ---- Tarjeta de la página -----------------------------------

function New-SearchResultCard {
    param($Window, $Entry)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 16, 13, 18, 14
    $card.Cursor = 'Hand'

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    # --- icono de la sección a la que pertenece ---
    $tile = New-IconTile $Entry.Category.Icon $Entry.Category.Accent $Entry.Category.AccentSoft 34
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
    Add-ToColumn $grid $tile 0

    # --- nombre, descripción y el porqué ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = Get-SearchResultTitle $Entry
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 13
    $title.FontWeight = 'SemiBold'
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $descripcion = $Entry.Category.Description
    if ($Entry.Setting) { $descripcion = $Entry.Setting.Description }

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $descripcion
    $desc.FontSize = 11.5
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 3, 20, 0
    Set-TextFg $desc 'TextMuted'
    $texts.Children.Add($desc) | Out-Null

    $texts.Children.Add((New-SearchMatchLine $Window $Entry)) | Out-Null

    Add-ToColumn $grid $texts 1

    # --- a la derecha, el estado si lo tiene, y el chevron ---
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'

    if ($Entry.Setting -and $Entry.Setting.Status) {
        $right.Children.Add((New-StatusTag $Entry.Setting.Status)) | Out-Null
    }

    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 8, 0, 2, 0
    $right.Children.Add($chev) | Out-Null

    Add-ToColumn $grid $right 2

    $card.Child = $grid

    $card.Tag = New-SearchResultTag $Entry $null
    $card.Add_MouseLeftButtonUp({ param($s, $e) Open-SearchResult $s })

    $card
}
