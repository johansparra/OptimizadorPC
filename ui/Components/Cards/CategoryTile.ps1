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

# Ancho de cada baldosa. El WrapPanel decide cuántas caben por
# fila a partir de esto y del ancho de la ventana.
$CategoryTileWidth = 268.0

function New-CategoryTile {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 18, 18, 18, 16
    $card.Width = $CategoryTileWidth

    # En cuadrícula el hueco va también a la derecha, no solo abajo:
    # el margen se lo queda el envoltorio (ver Add-HoverLift).
    $card.Margin = New-Object System.Windows.Thickness 0, 0, 14, 14

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
    $desc.FontSize = 11.5
    $desc.TextWrapping = 'Wrap'
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Height = 33
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
