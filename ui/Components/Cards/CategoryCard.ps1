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

    # La tarjeta se eleva al pasar el ratón, y en WPF eso mueve también
    # su zona sensible. Por eso quien oye al ratón -y quien recibe el
    # clic- es el envoltorio quieto que la sostiene, no ella misma:
    # es lo que devuelve Add-HoverLift (ver ui/Design/Theme.ps1).
    $slot = Add-HoverLift $card
    $slot.Cursor = 'Hand'

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
    $name.Text = T $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 14.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    # La insignia se apaga desde el botón "Vista" de la cabecera.
    if ($Category.Badge -and (Get-ViewOption 'badges')) {
        $nameRow.Children.Add((New-Badge $Category.Badge)) | Out-Null
    }

    # Candado si la sección está bloqueada en ui/Index/CategoryIndex.ps1.
    if ($Category.Locked) {
        $lock = New-Icon 'Lock' 12 'TextFaint'
        $lock.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
        $lock.ToolTip = T 'Locked section: you can look, not change'
        $nameRow.Children.Add($lock) | Out-Null
    }

    $text.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $Category.Description
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
    #
    # Se abre con Show-View, NO llamando a la vista (regla 17): si se
    # llamara directamente, el enrutador seguiría creyendo que estamos
    # en la lista y cualquier repintado -cambiar de idioma, tocar una
    # casilla del botón "Vista"- saltaría de vuelta a ella.
    $slot.Tag = $Category
    $slot.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $s.Tag }
    })

    $slot
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
            ((T 'Recommended: {0} of {1}') -f $Category.Recommended, $total))) | Out-Null
    } else {
        $stats.Children.Add((New-Pill 'Star' "0/$total" 'TextFaint' 'SurfaceSunken' `
            (T 'No recommended settings'))) | Out-Null
    }

    $stats.Children.Add((New-Pill 'Grid' "$($Category.Default)/$total" 'TextMuted' 'SurfaceSunken' `
        ((T 'Factory defaults: {0} of {1}') -f $Category.Default, $total))) | Out-Null

    if ($Category.Custom -gt 0) {
        $stats.Children.Add((New-Pill 'Sliders' "$($Category.Custom)/$total" 'Warn' 'WarnSoft' `
            ((T 'Customised: {0} of {1}') -f $Category.Custom, $total))) | Out-Null
    }

    $stats
}
