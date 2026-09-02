# ============================================================
# OptimizationsListView.ps1
# Pantalla principal: tarjetas de categoría con icono, badge,
# estadísticas y elevación al pasar el ratón.
# ============================================================

# Icono y color de acento por categoría.
$CategoryLook = @{
    privacy       = @{ Icon = 'Shield'; Fg = 'Accent';  Bg = 'AccentSoft' }
    power         = @{ Icon = 'Power';  Fg = 'Success'; Bg = 'SuccessSoft' }
    gaming        = @{ Icon = 'Game';   Fg = 'Warn';    Bg = 'WarnSoft' }
    update        = @{ Icon = 'Sync';   Fg = 'Accent';  Bg = 'AccentSoft' }
    notifications = @{ Icon = 'Bell';   Fg = 'Warn';    Bg = 'WarnSoft' }
    sound         = @{ Icon = 'Volume'; Fg = 'Success'; Bg = 'SuccessSoft' }
}

function New-CategoryCard {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 18, 15, 20, 15
    $card.Cursor = 'Hand'
    Add-HoverLift $card

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($width in @('Auto', '*', 'Auto', 'Auto')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = [System.Windows.GridLength]::new(1, $(if ($width -eq '*') { 'Star' } else { 'Auto' }))
        $grid.ColumnDefinitions.Add($cd)
    }

    # --- icono ---
    $look = $CategoryLook[$Category.Id]
    if (-not $look) { $look = @{ Icon = 'Sliders'; Fg = 'Accent'; Bg = 'AccentSoft' } }
    $tile = New-IconTile $look.Icon $look.Fg $look.Bg 44
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 16, 0
    [System.Windows.Controls.Grid]::SetColumn($tile, 0)
    $grid.Children.Add($tile) | Out-Null

    # --- nombre, badge y descripción ---
    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 14.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    if ($Category.Badge) { $nameRow.Children.Add((New-Badge $Category.Badge)) | Out-Null }
    $text.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Category.Description
    $desc.FontSize = 12
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 4, 24, 0
    Set-TextFg $desc 'TextMuted'
    $text.Children.Add($desc) | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    $grid.Children.Add($text) | Out-Null

    # --- píldoras de estadísticas ---
    $stats = New-Object System.Windows.Controls.StackPanel
    $stats.Orientation = 'Horizontal'
    $stats.VerticalAlignment = 'Center'

    $total = $Category.Total
    if ($Category.Recommended -gt 0) {
        $stats.Children.Add((New-Pill 'StarFill' "$($Category.Recommended)/$total" 'Success' 'SuccessSoft' "Recommended: $($Category.Recommended) de $total")) | Out-Null
    } else {
        $stats.Children.Add((New-Pill 'Star' "0/$total" 'TextFaint' 'SurfaceSunken' 'Sin ajustes recomendados')) | Out-Null
    }
    $stats.Children.Add((New-Pill 'Grid' "$($Category.Default)/$total" 'TextMuted' 'SurfaceSunken' "Default: $($Category.Default) de $total")) | Out-Null
    if ($Category.Custom -gt 0) {
        $stats.Children.Add((New-Pill 'Sliders' "$($Category.Custom)/$total" 'Warn' 'WarnSoft' "Custom: $($Category.Custom) de $total")) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetColumn($stats, 2)
    $grid.Children.Add($stats) | Out-Null

    # --- chevron ---
    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 16, 0, 2, 0
    [System.Windows.Controls.Grid]::SetColumn($chev, 3)
    $grid.Children.Add($chev) | Out-Null

    $card.Child = $grid

    # La categoría viaja en el Tag: nada de closures (regla 4 de CLAUDE.md).
    $card.Tag = $Category
    $card.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-CategoryDetailView -Window ([System.Windows.Window]::GetWindow($s)) -Category $s.Tag
    })

    $card
}

function Show-OptimizationsListView {
    param($Window)

    $categories  = Get-OptimizationCategories
    $titleArea   = $Window.FindName('HeaderTitleArea')
    $actionsArea = $Window.FindName('HeaderActionsArea')
    $mainContent = $Window.FindName('MainContent')

    # ---- Cabecera: título + subtítulo ----
    $titleArea.Children.Clear()
    $stack = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'Optimizations'
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 27
    $title.FontWeight = 'Bold'
    Set-TextFg $title 'Text'
    $stack.Children.Add($title) | Out-Null

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text = 'Optimize your Windows system performance, privacy and power usage'
    $sub.FontSize = 12.5
    $sub.Margin = New-Object System.Windows.Thickness 0, 3, 0, 0
    Set-TextFg $sub 'TextMuted'
    $stack.Children.Add($sub) | Out-Null

    $titleArea.Children.Add($stack) | Out-Null

    # ---- Cabecera: acciones ----
    $actionsArea.Children.Clear()
    $search = New-SearchBox $Window
    $actionsArea.Children.Add($search.Root) | Out-Null
    $actionsArea.Children.Add((New-ChipButton $Window 'Quick Actions' 'Bolt' -Chevron)) | Out-Null
    $actionsArea.Children.Add((New-ChipButton $Window 'View' 'Filter' -Chevron)) | Out-Null

    # ---- Contenido ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($cat in $categories) {
        $list.Children.Add((New-CategoryCard -Window $Window -Category $cat)) | Out-Null
    }

    $mainContent.Content = $list
    Start-EnterTransition $list
}
