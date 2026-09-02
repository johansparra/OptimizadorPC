# ============================================================
# CategoryDetailView.ps1
# Pantalla de detalle: breadcrumb + tarjetas de cada ítem con
# etiquetas, interruptor animado o desplegable.
# ============================================================

function New-ItemCard {
    param($Window, $Item)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')
    $card.Padding = New-Object System.Windows.Thickness 20, 15, 20, 16

    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::new(1, 'Star')
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c1)
    $grid.ColumnDefinitions.Add($c2)

    # ---- izquierda: nombre, descripción, etiquetas ----
    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Item.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 13.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    if ($Item.Badge) { $nameRow.Children.Add((New-Badge $Item.Badge)) | Out-Null }
    $left.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Item.Description
    $desc.FontSize = 11.5
    $desc.TextWrapping = 'Wrap'
    $desc.LineHeight = 17
    $desc.Margin = New-Object System.Windows.Thickness 0, 5, 30, 9
    Set-TextFg $desc 'TextMuted'
    $left.Children.Add($desc) | Out-Null

    $tags = New-Object System.Windows.Controls.StackPanel
    $tags.Orientation = 'Horizontal'
    foreach ($tag in $Item.Tags) { $tags.Children.Add((New-Tag $tag)) | Out-Null }
    $left.Children.Add($tags) | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($left, 0)
    $grid.Children.Add($left) | Out-Null

    # ---- derecha: indicadores + control ----
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'

    if ($Item.Tags -contains 'Recommended') {
        $star = New-Icon 'StarFill' 13 'Success'
        $star.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        $right.Children.Add($star) | Out-Null
    }
    if ($Item.Tags -contains 'Default') {
        $gr = New-Icon 'Grid' 13 'TextFaint'
        $gr.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
        $right.Children.Add($gr) | Out-Null
    }

    if ($Item.Type -eq 'Toggle') {
        $state = New-Object System.Windows.Controls.TextBlock
        if ($Item.Value) { $state.Text = 'On' } else { $state.Text = 'Off' }
        $state.FontSize = 11.5
        $state.FontWeight = 'SemiBold'
        $state.Width = 24
        $state.TextAlignment = 'Right'
        $state.VerticalAlignment = 'Center'
        $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        Set-TextFg $state 'TextMuted'
        $right.Children.Add($state) | Out-Null
        $right.Children.Add((New-ToggleSwitch -Window $Window -InitialState $Item.Value -Label $state)) | Out-Null
    }
    elseif ($Item.Type -eq 'Dropdown') {
        $combo = New-Object System.Windows.Controls.ComboBox
        $combo.Style = $Window.FindResource('ModernComboStyle')
        $combo.Width = 262
        foreach ($opt in $Item.Options) { $combo.Items.Add($opt) | Out-Null }
        $combo.SelectedItem = $Item.Value
        $right.Children.Add($combo) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    $grid.Children.Add($right) | Out-Null

    $card.Child = $grid
    $card
}

function Show-CategoryDetailView {
    param($Window, $Category)

    $titleArea   = $Window.FindName('HeaderTitleArea')
    $actionsArea = $Window.FindName('HeaderActionsArea')
    $mainContent = $Window.FindName('MainContent')

    # ---- Breadcrumb ----
    $titleArea.Children.Clear()
    $crumb = New-Object System.Windows.Controls.StackPanel
    $crumb.Orientation = 'Horizontal'

    $back = New-Object System.Windows.Controls.Border
    $back.CornerRadius = New-Object System.Windows.CornerRadius 9
    $back.Width = 34; $back.Height = 34
    $back.Cursor = 'Hand'
    $back.BorderThickness = New-Object System.Windows.Thickness 1
    $back.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
    $back.VerticalAlignment = 'Center'
    Set-BoxBg $back 'Surface'
    Set-BoxLine $back 'Stroke'
    $back.Child = (New-Icon 'Back' 13 'TextMuted')
    $back.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-OptimizationsListView -Window ([System.Windows.Window]::GetWindow($s))
    })
    $crumb.Children.Add($back) | Out-Null

    $look = $CategoryLook[$Category.Id]
    if (-not $look) { $look = @{ Icon = 'Sliders'; Fg = 'Accent'; Bg = 'AccentSoft' } }
    $tile = New-IconTile $look.Icon $look.Fg $look.Bg 38
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 13, 0
    $crumb.Children.Add($tile) | Out-Null

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $trail = New-Object System.Windows.Controls.StackPanel
    $trail.Orientation = 'Horizontal'
    $root = New-Object System.Windows.Controls.TextBlock
    $root.Text = 'Optimizations'
    $root.FontSize = 11
    $root.Cursor = 'Hand'
    Set-TextFg $root 'TextFaint'
    $root.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-OptimizationsListView -Window ([System.Windows.Window]::GetWindow($s))
    })
    $trail.Children.Add($root) | Out-Null
    $sep = New-Icon 'ChevronRight' 8 'TextFaint'
    $sep.Margin = New-Object System.Windows.Thickness 6, 1, 6, 0
    $trail.Children.Add($sep) | Out-Null
    $leaf = New-Object System.Windows.Controls.TextBlock
    $leaf.Text = $Category.Name
    $leaf.FontSize = 11
    Set-TextFg $leaf 'TextMuted'
    $trail.Children.Add($leaf) | Out-Null
    $texts.Children.Add($trail) | Out-Null

    $curr = New-Object System.Windows.Controls.TextBlock
    $curr.Text = $Category.Name
    $curr.FontFamily = $Window.FindResource('DisplayFont')
    $curr.FontSize = 21
    $curr.FontWeight = 'Bold'
    $curr.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
    Set-TextFg $curr 'Text'
    $texts.Children.Add($curr) | Out-Null

    $crumb.Children.Add($texts) | Out-Null
    $titleArea.Children.Add($crumb) | Out-Null

    # ---- Acciones ----
    $actionsArea.Children.Clear()
    $count = New-Object System.Windows.Controls.TextBlock
    $count.Text = "$($Category.Items.Count) settings"
    $count.FontSize = 12
    $count.VerticalAlignment = 'Center'
    $count.Margin = New-Object System.Windows.Thickness 0, 0, 4, 0
    Set-TextFg $count 'TextFaint'
    $actionsArea.Children.Add($count) | Out-Null
    $actionsArea.Children.Add((New-ChipButton $Window 'Reset' 'Sync')) | Out-Null

    # ---- Lista de ítems ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($item in $Category.Items) {
        $list.Children.Add((New-ItemCard -Window $Window -Item $item)) | Out-Null
    }

    $mainContent.Content = $list
    Start-EnterTransition $list
}
