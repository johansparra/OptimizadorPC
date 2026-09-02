# ============================================================
# Componente: cabecera de página
#
# La franja superior del contenido, con dos zonas definidas en
# MainWindow.xaml:
#     HeaderTitleArea    -> izquierda: título o breadcrumb
#     HeaderActionsArea  -> derecha:   buscador y botones
#
# Las vistas no tocan esas zonas directamente: usan estas
# funciones. Así todas las pantallas comparten el mismo aspecto.
# ============================================================

# Vacía las dos zonas. Toda vista debe llamarla antes de pintar.
function Clear-PageHeader {
    param($Window)
    $Window.FindName('HeaderTitleArea').Children.Clear()
    $Window.FindName('HeaderActionsArea').Children.Clear()
}

# Título grande + subtítulo gris (pantalla principal).
function Set-PageTitle {
    param($Window, [string]$Title, [string]$Subtitle)

    $stack = New-Object System.Windows.Controls.StackPanel

    $big = New-Object System.Windows.Controls.TextBlock
    $big.Text = $Title
    $big.FontFamily = $Window.FindResource('DisplayFont')
    $big.FontSize = 27
    $big.FontWeight = 'Bold'
    Set-TextFg $big 'Text'
    $stack.Children.Add($big) | Out-Null

    if ($Subtitle) {
        $sub = New-Object System.Windows.Controls.TextBlock
        $sub.Text = $Subtitle
        $sub.FontSize = 12.5
        $sub.Margin = New-Object System.Windows.Thickness 0, 3, 0, 0
        Set-TextFg $sub 'TextMuted'
        $stack.Children.Add($sub) | Out-Null
    }

    $Window.FindName('HeaderTitleArea').Children.Add($stack) | Out-Null
}

# Breadcrumb de una categoría: botón atrás + icono + ruta + título.
# $OnBack es el nombre de la función a la que vuelve el botón.
function Set-PageBreadcrumb {
    param($Window, $Category, [string]$RootLabel = 'Optimizations')

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'

    # --- botón atrás ---
    $back = New-Object System.Windows.Controls.Border
    $back.Width = 34; $back.Height = 34
    $back.CornerRadius = New-Object System.Windows.CornerRadius 9
    $back.BorderThickness = New-Object System.Windows.Thickness 1
    $back.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
    $back.VerticalAlignment = 'Center'
    $back.Cursor = 'Hand'
    $back.ToolTip = T 'Back to the list'
    Set-BoxBg $back 'Surface'
    Set-BoxLine $back 'Stroke'
    $back.Child = (New-Icon 'Back' 13 'TextMuted')
    $back.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-OptimizationsListView -Window ([System.Windows.Window]::GetWindow($s))
    })
    $row.Children.Add($back) | Out-Null

    # --- icono de la categoría ---
    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 38
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 13, 0
    $row.Children.Add($tile) | Out-Null

    # --- ruta pequeña + título ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $trail = New-Object System.Windows.Controls.StackPanel
    $trail.Orientation = 'Horizontal'

    $rootLink = New-Object System.Windows.Controls.TextBlock
    $rootLink.Text = T $RootLabel
    $rootLink.FontSize = 11
    $rootLink.Cursor = 'Hand'
    Set-TextFg $rootLink 'TextFaint'
    $rootLink.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-OptimizationsListView -Window ([System.Windows.Window]::GetWindow($s))
    })
    $trail.Children.Add($rootLink) | Out-Null

    $sep = New-Icon 'ChevronRight' 8 'TextFaint'
    $sep.Margin = New-Object System.Windows.Thickness 6, 1, 6, 0
    $trail.Children.Add($sep) | Out-Null

    $leaf = New-Object System.Windows.Controls.TextBlock
    $leaf.Text = T $Category.Name
    $leaf.FontSize = 11
    Set-TextFg $leaf 'TextMuted'
    $trail.Children.Add($leaf) | Out-Null

    $texts.Children.Add($trail) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T $Category.Name
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 21
    $title.FontWeight = 'Bold'
    $title.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $row.Children.Add($texts) | Out-Null
    $Window.FindName('HeaderTitleArea').Children.Add($row) | Out-Null
}

# Cabecera de un bloque dentro del contenido ("General",
# "Appearance"...). La usa la pantalla de Settings.
function New-SectionHeader {
    param($Window, [string]$Text)

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $Text
    $header.FontFamily = $Window.FindResource('DisplayFont')
    $header.FontSize = 12
    $header.FontWeight = 'SemiBold'
    $header.Margin = New-Object System.Windows.Thickness 4, 6, 0, 10
    Set-TextFg $header 'TextFaint'
    $header
}

# Añade un control a la zona de acciones (derecha).
function Add-PageAction {
    param($Window, $Element)
    $Window.FindName('HeaderActionsArea').Children.Add($Element) | Out-Null
}

# Texto gris suelto en la zona de acciones ("6 settings").
function Add-PageActionLabel {
    param($Window, [string]$Text)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.FontSize = 12
    $t.VerticalAlignment = 'Center'
    $t.Margin = New-Object System.Windows.Thickness 0, 0, 4, 0
    Set-TextFg $t 'TextFaint'
    Add-PageAction $Window $t
}
