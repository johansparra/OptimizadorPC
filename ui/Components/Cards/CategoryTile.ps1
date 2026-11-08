# ============================================================
# Componente: baldosa de categoría (vista de cuadrícula)
#
# La MISMA sección que dibuja CategoryCard, pero en vertical para
# que quepan varias por fila:
#
#     [icono grande]
#     Nombre  (NEW)
#     Descripción en dos líneas...
#     (píldoras)
#
# Se enseña cuando está marcada la opción "Grid view" del botón
# "Vista"; sin marcar sigue saliendo la lista de siempre. Lo
# decide ui/Views/OptimizationsListView.ps1, no esta pieza.
#
# Todo lo demás -el halo del color de la sección, el envoltorio
# quieto que oye al ratón, la categoría viajando en el Tag- es
# igual que en la tarjeta de lista y por los mismos motivos; ahí
# están explicados.
#
# Las píldoras las arma New-CategoryStats, que vive en
# CategoryCard.ps1: son el mismo dato y no pueden acabar contando
# cosas distintas según cómo se mire la pantalla.
# ============================================================

# Ancho MÍNIMO de cada baldosa y hueco entre ellas. Cuántas caben
# por fila lo decide el ancho disponible; el ancho real lo reparte
# Update-CategoryTileWidths para que la fila llegue al borde.
$CategoryTileWidth = 268.0
$CategoryTileGap   = 14.0

<#
    El panel de la cuadrícula.

    Un WrapPanel salta de fila solo, pero con baldosas de ancho fijo
    deja un hueco a la derecha: a 1190 px caben tres y sobran 330.
    Al cambiar de tamaño se recalcula cuántas columnas caben y se
    estira cada baldosa para repartir el sobrante, así la fila acaba
    alineada con el borde de las tarjetas de la lista.
#>
function New-CategoryTilePanel {
    $panel = New-Object System.Windows.Controls.WrapPanel
    $panel.Orientation = 'Horizontal'
    # El hueco va a la derecha de CADA baldosa, también de la última:
    # el panel se mete ese hueco por fuera para que la fila termine
    # justo donde terminan las tarjetas de la lista.
    $panel.Margin = New-Object System.Windows.Thickness 0, 0, (-$CategoryTileGap), 0
    # Sin closures (regla 4): el panel es el emisor.
    $panel.Add_SizeChanged({ param($s, $e) Update-CategoryTileWidths $s })
    $panel
}

function Update-CategoryTileWidths {
    param($Panel)

    $available = $Panel.ActualWidth
    if ($available -le 0) { return }

    # Cada envoltorio lleva el hueco como margen derecho, así que una
    # columna ocupa baldosa + hueco.
    $cols = [Math]::Max(1, [Math]::Floor(($available + 0.5) / ($CategoryTileWidth + $CategoryTileGap)))
    # Nunca más columnas que baldosas: con tres secciones y sitio para
    # cuatro, la cuarta columna sería justo el hueco que se quiere quitar.
    $cols = [Math]::Max(1, [Math]::Min($cols, $Panel.Children.Count))
    $width = [Math]::Floor($available / $cols) - $CategoryTileGap
    if ($width -lt $CategoryTileWidth) { $width = $CategoryTileWidth }

    foreach ($slot in $Panel.Children) {
        # El envoltorio quieto de Add-HoverLift: la baldosa es su hijo.
        if ($slot -is [System.Windows.Controls.Panel] -and $slot.Children.Count -gt 0) { $slot.Children[0].Width = $width }
    }
}

function New-CategoryTile {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 18, 18, 18, 16
    $card.Width = $CategoryTileWidth

    # En cuadrícula el hueco va también a la derecha, no solo abajo:
    # el margen se lo queda el envoltorio (ver Add-HoverLift).
    $card.Margin = New-Object System.Windows.Thickness 0, 0, $CategoryTileGap, $CategoryTileGap

    $slot = Add-HoverLift $card -Glow $Category.Accent
    $slot.Cursor = 'Hand'

    $stack = New-Object System.Windows.Controls.StackPanel

    # --- icono grande ---
    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 52
    $tile.HorizontalAlignment = 'Left'
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 0, 14
    $stack.Children.Add($tile) | Out-Null

    # --- nombre, insignia y candado ---
    # En un Grid y no en un StackPanel: el nombre se lleva la columna
    # estrella, así que se recorta con puntos suspensivos en vez de
    # empujar la insignia fuera de la baldosa. En una fila horizontal
    # no hay ancho que respetar y TextTrimming no llega a actuar.
    $nameRow = New-Object System.Windows.Controls.Grid
    Add-GridColumns $nameRow '*', 'Auto', 'Auto'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 15.5
    $name.VerticalAlignment = 'Center'
    $name.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $name 'Text'
    Add-ToColumn $nameRow $name 0

    if ($Category.Badge -and (Get-ViewOption 'badges')) {
        Add-ToColumn $nameRow (New-Badge $Category.Badge) 1
    }

    if ($Category.Locked) {
        $lock = New-Icon 'Lock' 12 'TextFaint'
        $lock.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
        $lock.ToolTip = T 'Locked section: you can look, not change'
        Add-ToColumn $nameRow $lock 2
    }

    $stack.Children.Add($nameRow) | Out-Null

    # --- descripción, dos líneas ---
    # Alto FIJO, no máximo: en una cuadrícula las baldosas de una
    # misma fila tienen que acabar a la misma altura, y con un alto
    # máximo la de descripción corta sube y deja la fila dentada.
    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $Category.Description
    # Dos líneas exactas: alto de línea fijo (BlockLineHeight) y la
    # caja del doble, así la tercera no asoma recortada por arriba.
    $desc.FontSize = 12
    $desc.LineHeight = 17
    $desc.LineStackingStrategy = 'BlockLineHeight'
    $desc.TextWrapping = 'Wrap'
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Height = 34
    $desc.ToolTip = T $Category.Description
    $desc.Margin = New-Object System.Windows.Thickness 0, 6, 0, 14
    Set-TextFg $desc 'TextMuted'
    $stack.Children.Add($desc) | Out-Null

    # --- píldoras ---
    # Nacen alineadas a la derecha para la vista de lista; aquí van
    # a la izquierda, bajo el texto, y el primer margen sobra.
    $stats = New-CategoryStats $Category
    $stats.HorizontalAlignment = 'Left'
    $stats.Margin = New-Object System.Windows.Thickness -6, 0, 0, 0
    $stack.Children.Add($stats) | Out-Null

    $card.Child = $stack

    $slot.Tag = $Category
    $slot.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $s.Tag }
    })

    $slot
}
