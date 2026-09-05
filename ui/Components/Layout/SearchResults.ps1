# ============================================================
# Componente: piezas de la búsqueda que no son el resultado
#
#   New-SearchGroupHeader   la cabecera de cada sección en la lista
#                           de resultados: icono, nombre y cuántos
#   New-SearchEmptyState    lo que sale cuando no hay coincidencias
#   New-SearchCountLine     "12 resultados para «telemetría»"
#
# Agrupar por sección es lo que evita que una lista larga se lea
# como un montón: primero se ve dónde está lo que buscas y luego
# qué es. Los grupos los arma ui/Engine/Search.ps1; aquí solo se
# dibujan.
# ============================================================

function New-SearchGroupHeader {
    param($Window, $Category, [int]$Count)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Margin = New-Object System.Windows.Thickness 2, 16, 0, 9

    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 24
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 9, 0
    $row.Children.Add($tile) | Out-Null

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontSize = 12.5
    $name.FontWeight = 'SemiBold'
    $name.VerticalAlignment = 'Center'
    Set-TextFg $name 'Text'
    $row.Children.Add($name) | Out-Null

    $badge = New-Object System.Windows.Controls.TextBlock
    $badge.Text = [string]$Count
    $badge.FontSize = 11
    $badge.VerticalAlignment = 'Center'
    $badge.Margin = New-Object System.Windows.Thickness 8, 1, 0, 0
    Set-TextFg $badge 'TextFaint'
    $row.Children.Add($badge) | Out-Null

    $row
}

# "12 resultados para «telemetría»". Va en el cuerpo y no en el
# subtítulo de la cabecera a propósito: el número cambia con cada
# tecla y la cabecera no se rehace en cada tecla.
function New-SearchCountLine {
    param($Window, [int]$Count, [string]$Query)

    $texto = (T '{0} results for "{1}"') -f $Count, $Query
    if ($Count -eq 1) { $texto = (T '1 result for "{0}"') -f $Query }

    $line = New-Object System.Windows.Controls.TextBlock
    $line.Text = $texto
    $line.FontSize = 12
    $line.Margin = New-Object System.Windows.Thickness 2, 0, 0, 2
    Set-TextFg $line 'TextMuted'
    $line
}

<#
    Sin coincidencias. Ni error ni pantalla en blanco: se dice qué se
    buscó y se sugiere qué probar, que en esta aplicación suele ser
    un trozo de ruta del registro.
#>
function New-SearchEmptyState {
    param($Window, [string]$Query, [switch]$Compact)

    $box = New-Object System.Windows.Controls.StackPanel
    $box.HorizontalAlignment = 'Center'
    if ($Compact) { $box.Margin = New-Object System.Windows.Thickness 0, 14, 0, 16 }
    else          { $box.Margin = New-Object System.Windows.Thickness 0, 60, 0, 0 }

    $icon = New-Icon 'Search' 30 'TextFaint'
    if ($Compact) { $icon.FontSize = 20 }
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    $box.Children.Add($icon) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = (T 'Nothing matches "{0}"') -f $Query
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 14
    $title.FontWeight = 'SemiBold'
    $title.TextAlignment = 'Center'
    $title.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $title 'Text'
    $box.Children.Add($title) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'Try another word, or part of a registry path'
    $hint.FontSize = 11.5
    $hint.TextAlignment = 'Center'
    $hint.Margin = New-Object System.Windows.Thickness 0, 6, 0, 0
    Set-TextFg $hint 'TextMuted'
    $box.Children.Add($hint) | Out-Null

    $box
}

<#
    La página de resultados sin nada escrito -se llega borrando la
    caja-. No es lo mismo que "no hay coincidencias": ahí no se ha
    buscado nada todavía, así que decir «nada coincide con ""»
    sería mentira.
#>
function New-SearchPromptState {
    param($Window)

    $box = New-Object System.Windows.Controls.StackPanel
    $box.HorizontalAlignment = 'Center'
    $box.Margin = New-Object System.Windows.Thickness 0, 60, 0, 0

    $icon = New-Icon 'Search' 30 'TextFaint'
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    $box.Children.Add($icon) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Type to search'
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 14
    $title.FontWeight = 'SemiBold'
    $title.TextAlignment = 'Center'
    Set-TextFg $title 'Text'
    $box.Children.Add($title) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'Sections, settings, registry keys and their values'
    $hint.FontSize = 11.5
    $hint.TextAlignment = 'Center'
    $hint.Margin = New-Object System.Windows.Thickness 0, 6, 0, 0
    Set-TextFg $hint 'TextMuted'
    $box.Children.Add($hint) | Out-Null

    $box
}
