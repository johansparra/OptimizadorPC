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
# La fila se cuenta de dos maneras, y la sección decide cuál:
#
#   - Si sus ajustes leen el registro, por su ESTADO REAL
#     (Get-CategoryStatusCounts): optimizado, de fábrica o a medida,
#     lo que core/Registry/SettingStatus.ps1 acaba de sacar del equipo.
#     Es el mismo dato -y el mismo catálogo de colores- que la
#     etiqueta de cada tarjeta, así que fila y tarjetas no pueden
#     contradecirse.
#   - Si no, por las etiquetas declaradas a mano en el archivo de la
#     sección (Get-CategoryCounts). Es lo que había siempre.
#
# Update-CategorySummary vuelve a contar y repinta la fila. Está
# enganchado a los controles de ui/Components/Cards/SettingCard.ps1: el
# día que tocar un interruptor escriba en el registro, los números
# se moverán solos.
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

    # Si la sección lee el registro, sus ajustes traen un estado de
    # verdad y se cuentan por él. Si no, por las etiquetas declaradas,
    # que es todo lo que hay.
    $counts = Get-CategoryStatusCounts $Category
    if ($counts) { Add-StatusPills $row $counts } else { Add-TagPills $row (Get-CategoryCounts $Category) }

    $row
}

# Una píldora por estado real. La de 'desconocido' solo sale si hay
# alguno: en cuanto se lee todo bien, sobra de la fila.
function Add-StatusPills {
    param($Row, $Counts)

    foreach ($status in Get-SettingStatusNames) {
        $n = [int]$Counts.$status
        if ($status -eq 'unknown' -and $n -eq 0) { continue }

        $style = Get-StatusStyle $status
        $tip = (T $style.Count) -f $n, $Counts.Total
        $Row.Children.Add((New-SummaryPill $style (T $style.Label) $n $Counts.Total $tip)) | Out-Null
    }
}

# Una píldora por etiqueta declarada. Es lo de siempre, y lo que
# siguen enseñando las secciones que aún no leen nada del equipo.
function Add-TagPills {
    param($Row, $Counts)

    foreach ($style in $SummaryStyles) {
        $n = [int]$Counts.($style.Tag)
        $tip = (T $style.Tip) -f $n, $Counts.Total
        $Row.Children.Add((New-SummaryPill $style (T $style.Tag) $n $Counts.Total $tip)) | Out-Null
    }
}

# La píldora del resumen: icono, nombre y recuento, todo dentro de la
# misma cápsula. New-Pill solo trae el icono y el texto, así que el
# nombre se cuela entre los dos.
function New-SummaryPill {
    param($Style, [string]$Label, [int]$Count, [int]$Total, [string]$Tip)

    $pill = New-Pill $Style.Icon "$Count/$Total" $Style.Fg $Style.Bg $Tip
    $pill.Margin = New-Object System.Windows.Thickness 4, 0, 4, 0

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Label + '  '
    $text.FontSize = 11
    $text.FontWeight = 'SemiBold'
    $text.VerticalAlignment = 'Center'
    Set-TextFg $text $Style.Fg
    $pill.Child.Children.Insert(1, $text)

    $pill
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
