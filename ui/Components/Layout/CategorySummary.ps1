# ============================================================
# Componente: resumen de una sección
#
# La fila centrada que va bajo el título en la pantalla de
# detalle. Una píldora por etiqueta, con los mismos colores que
# las etiquetas de cada tarjeta y que las píldoras de la lista:
#
#     (estrella) Recomendado 6/6   (rejilla) De fábrica 5/6
#     (mando) Personalizado 6/6
#
# Los números salen de Get-CategoryCounts (ui/Engine/CategoryRegistry.ps1),
# que los cuenta sobre los Items reales del archivo de la sección.
#
# Update-CategorySummary vuelve a contar y repinta la fila. Está
# enganchado a los controles de ui/Components/Cards/SettingCard.ps1, así
# que en cuanto la lógica real cambie las etiquetas de un ajuste
# el resumen se moverá solo.
# ============================================================

# Etiqueta -> icono y colores. Mismo criterio que New-Tag (UiKit).
$SummaryStyles = @(
    @{ Tag = 'Recommended'; Icon = 'StarFill'; Fg = 'Success';   Bg = 'SuccessSoft'
       Tip = 'Recommended: {0} of {1}' }
    @{ Tag = 'Default';     Icon = 'Grid';     Fg = 'TextMuted'; Bg = 'SurfaceSunken'
       Tip = 'Factory defaults: {0} of {1}' }
    @{ Tag = 'Custom';      Icon = 'Sliders';  Fg = 'Warn';      Bg = 'WarnSoft'
       Tip = 'Customised: {0} of {1}' }
)

function New-CategorySummary {
    param($Window, $Category)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.HorizontalAlignment = 'Center'
    $row.Margin = New-Object System.Windows.Thickness 0, 14, 0, 0

    # La categoría viaja en el Tag para que Update-CategorySummary
    # pueda recontar sin closures (regla 4 de CLAUDE.md).
    $row.Tag = $Category

    $counts = Get-CategoryCounts $Category
    $total = $counts.Total

    foreach ($style in $SummaryStyles) {
        $n = $counts.($style.Tag)

        $pill = New-Pill $style.Icon "$n/$total" $style.Fg $style.Bg ((T $style.Tip) -f $n, $total)
        $pill.Margin = New-Object System.Windows.Thickness 4, 0, 4, 0

        # La píldora lleva su propio texto, así que el nombre de la
        # etiqueta se añade delante dentro de la misma píldora.
        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = (T $style.Tag) + '  '
        $label.FontSize = 11
        $label.FontWeight = 'SemiBold'
        $label.VerticalAlignment = 'Center'
        Set-TextFg $label $style.Fg
        $pill.Child.Children.Insert(1, $label)

        $row.Children.Add($pill) | Out-Null
    }

    $row
}

<#
    Vuelve a contar y repinta la fila del resumen.

    No hace nada si la pantalla actual no la tiene (la lista y la
    de Settings no la usan), así que se puede llamar sin comprobar
    dónde estamos.
#>
function Update-CategorySummary {
    $window = Get-AppWindow
    if (-not $window) { return }

    $area = $window.FindName('HeaderSummaryArea')
    if (-not $area -or $area.Children.Count -eq 0) { return }

    $category = $area.Children[0].Tag
    if (-not $category) { return }

    $area.Children.Clear()
    $area.Children.Add((New-CategorySummary -Window $window -Category $category)) | Out-Null
}
