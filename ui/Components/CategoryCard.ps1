# ============================================================
# Componente: tarjeta de categoría
#
# Es cada una de las filas de la pantalla principal. Estructura
# en 4 columnas:
#
#   [icono] [nombre + badge + descripción] [píldoras] [ >]
#
# Al hacer clic abre el detalle de esa categoría.
# ============================================================

function New-CategoryCard {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 18, 15, 20, 15
    $card.Cursor = 'Hand'
    Add-HoverLift $card

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto', 'Auto'

    # --- columna 0: icono ---
    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 44
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 16, 0
    Add-ToColumn $grid $tile 0

    # --- columna 1: nombre, badge y descripción ---
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

    # Candado si la sección está bloqueada en ui/CategoryIndex.ps1.
    if ($Category.Locked) {
        $lock = New-Icon 'Lock' 12 'TextFaint'
        $lock.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
        $lock.ToolTip = 'Sección bloqueada: se puede consultar, no modificar'
        $nameRow.Children.Add($lock) | Out-Null
    }

    $text.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Category.Description
    $desc.FontSize = 12
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 4, 24, 0
    Set-TextFg $desc 'TextMuted'
    $text.Children.Add($desc) | Out-Null

    Add-ToColumn $grid $text 1

    # --- columna 2: píldoras de estadísticas ---
    Add-ToColumn $grid (New-CategoryStats $Category) 2

    # --- columna 3: chevron ---
    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 16, 0, 2, 0
    Add-ToColumn $grid $chev 3

    $card.Child = $grid

    # La categoría viaja en el Tag: nada de closures (regla 4 de CLAUDE.md).
    $card.Tag = $Category
    $card.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-CategoryDetailView -Window ([System.Windows.Window]::GetWindow($s)) -Category $s.Tag
    })

    $card
}

# Las tres píldoras de la derecha: Recommended / Default / Custom.
function New-CategoryStats {
    param($Category)

    $stats = New-Object System.Windows.Controls.StackPanel
    $stats.Orientation = 'Horizontal'
    $stats.VerticalAlignment = 'Center'

    $total = $Category.Total

    if ($Category.Recommended -gt 0) {
        $stats.Children.Add((New-Pill 'StarFill' "$($Category.Recommended)/$total" 'Success' 'SuccessSoft' `
            "Recommended: $($Category.Recommended) de $total")) | Out-Null
    } else {
        $stats.Children.Add((New-Pill 'Star' "0/$total" 'TextFaint' 'SurfaceSunken' `
            'Sin ajustes recomendados')) | Out-Null
    }

    $stats.Children.Add((New-Pill 'Grid' "$($Category.Default)/$total" 'TextMuted' 'SurfaceSunken' `
        "Default: $($Category.Default) de $total")) | Out-Null

    if ($Category.Custom -gt 0) {
        $stats.Children.Add((New-Pill 'Sliders' "$($Category.Custom)/$total" 'Warn' 'WarnSoft' `
            "Custom: $($Category.Custom) de $total")) | Out-Null
    }

    $stats
}
