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
    if ($counts) { Add-StatusPills $Window $row $counts } else { Add-TagPills $Window $row (Get-CategoryCounts $Category) }

    $row
}

# Una píldora por estado real. La de 'desconocido' solo sale si hay
# alguno: en cuanto se lee todo bien, sobra de la fila.
#
# Y son BOTONES DE FILTRO: pulsar una enseña solo los ajustes en ese
# estado; se pueden combinar; sin ninguna marcada se ve todo. Ver
# "El filtro por estado" más abajo.
function Add-StatusPills {
    param($Window, $Row, $Counts)

    $category = $Row.Tag
    $filter = @(Get-CategoryStatusFilter $category)

    foreach ($status in Get-SettingStatusNames) {
        $n = [int]$Counts.$status
        if ($status -eq 'unknown' -and $n -eq 0) { continue }

        $style = Get-StatusStyle $status
        $tip = (T $style.Count) -f $n, $Counts.Total
        if ($n -gt 0) { $tip += "`n" + (T 'Click to show only these settings. Click again to remove the filter.') }

        $pill = New-SummaryPill $Window $style (T $style.Label) $n $Counts.Total $tip
        Set-FilterPillState $pill $style ($filter -contains $status) ($filter.Count -gt 0)

        # Una píldora a cero no filtra nada: no se puede pulsar.
        if ($n -gt 0) {
            $pill.Cursor = 'Hand'
            $pill.Tag = [PSCustomObject]@{ Category = $category; Status = $status }
            $pill.Add_MouseLeftButtonUp({ param($s, $e) Switch-CategoryStatusFilter -Category $s.Tag.Category -Status $s.Tag.Status })
        }
        $Row.Children.Add($pill) | Out-Null
    }

    if ($filter.Count -gt 0) { $Row.Children.Add((New-ClearFilterPill $category)) | Out-Null }
}

# Cómo se ve una píldora según el filtro: marcada, con borde de su
# color y una marca; las demás, atenuadas mientras haya filtro; sin
# filtro, todas normales.
function Set-FilterPillState {
    param($Pill, $Style, [bool]$Selected, [bool]$Active)

    if ($Selected) {
        $Pill.BorderThickness = New-Object System.Windows.Thickness 1.5
        Set-BoxLine $Pill $Style.Fg
        $check = New-Icon 'Check' 10 $Style.Fg
        $check.Margin = New-Object System.Windows.Thickness 0, 0, 5, 0
        $Pill.Child.Children.Insert(0, $check)
        $Pill.Opacity = 1
    }
    else {
        # El mismo grosor de borde, transparente: así marcar una no
        # mueve a las demás de sitio.
        $Pill.BorderThickness = New-Object System.Windows.Thickness 1.5
        $Pill.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $Pill.Opacity = if ($Active) { 0.5 } else { 1 }
    }
}

# "Mostrar todos": quita el filtro. Solo sale si hay alguno puesto.
function New-ClearFilterPill {
    param($Category)

    $pill = New-Pill 'Close' (T 'Show all') 'TextMuted' 'Surface' (T 'Remove the filter')
    $pill.Margin = New-Object System.Windows.Thickness 8, 0, 4, 0
    $pill.BorderThickness = New-Object System.Windows.Thickness 1
    Set-BoxLine $pill 'Stroke'
    $pill.Cursor = 'Hand'
    $pill.Tag = $Category
    $pill.Add_MouseLeftButtonUp({ param($s, $e) Clear-CategoryStatusFilter -Category $s.Tag })
    $pill
}

# ---- El filtro por estado ------------------------------------------
#
# Qué estados se están enseñando en cada sección, por su Id. Vacío =
# todo. Dura la sesión: volver a la sección la deja como estaba, y las
# píldoras marcadas lo dicen.
#
# Al tocar el interruptor de un ajuste su estado cambia, pero la
# tarjeta NO se esconde aunque deje de cumplir el filtro: desaparecer
# bajo el ratón justo después de pulsar desconcierta. El filtro se
# vuelve a aplicar al pulsar una píldora o al entrar en la sección.
$CategoryStatusFilter = @{}

function Get-CategoryStatusFilter {
    param($Category)
    if (-not $Category) { return @() }
    $f = $CategoryStatusFilter[[string]$Category.Id]
    if ($f) { return @($f) }
    @()
}

function Switch-CategoryStatusFilter {
    param($Category, [string]$Status)

    $current = @(Get-CategoryStatusFilter $Category)
    if ($current -contains $Status) { $next = @($current | Where-Object { $_ -ne $Status }) }
    else { $next = $current + $Status }
    $CategoryStatusFilter[[string]$Category.Id] = $next

    Update-CategorySummary
    Update-CategoryFilterView $Category
}

function Clear-CategoryStatusFilter {
    param($Category)
    if (-not $Category) { return }
    $CategoryStatusFilter.Remove([string]$Category.Id)
    Update-CategorySummary
    Update-CategoryFilterView $Category
}

<#
    Enseña u oculta las tarjetas de la pantalla de detalle según el
    filtro. Trabaja sobre las tarjetas ya construidas: no relee el
    registro ni rehace la lista, así que no parpadea.
#>
function Update-CategoryFilterView {
    param($Category)

    $window = Get-AppWindow
    if (-not $window) { return }
    $list = $window.FindName('MainContent').Content
    if ($list -isnot [System.Windows.Controls.Panel]) { return }

    $filter = @(Get-CategoryStatusFilter $Category)
    foreach ($card in $list.Children) {
        $setting = $card.Tag
        if (-not $setting -or -not $setting.PSObject.Properties['Registry']) { continue }
        $show = ($filter.Count -eq 0) -or ($filter -contains [string]$setting.Status)
        $card.Visibility = if ($show) { 'Visible' } else { 'Collapsed' }
    }
}

# Una píldora por etiqueta declarada. Es lo de siempre, y lo que
# siguen enseñando las secciones que aún no leen nada del equipo.
function Add-TagPills {
    param($Window, $Row, $Counts)

    foreach ($style in $SummaryStyles) {
        $n = [int]$Counts.($style.Tag)
        $tip = (T $style.Tip) -f $n, $Counts.Total
        $Row.Children.Add((New-SummaryPill $Window $style (T $style.Tag) $n $Counts.Total $tip)) | Out-Null
    }
}

<#
    La píldora del resumen: icono, nombre y recuento, todo dentro de
    la misma cápsula. New-Pill solo trae el icono y el texto, así que
    el nombre se cuela entre los dos.

    El recuento SUBE desde cero al aparecer (Start-CountUp). Es el
    número que acaba de salir de leer el registro, y verlo contar
    dice justamente eso. La referencia al texto se coge ANTES de
    colar el nombre: después ya no está en la misma posición.
#>
function New-SummaryPill {
    param($Window, $Style, [string]$Label, [int]$Count, [int]$Total, [string]$Tip)

    $pill = New-Pill $Style.Icon "$Count/$Total" $Style.Fg $Style.Bg $Tip
    $pill.Margin = New-Object System.Windows.Thickness 4, 0, 4, 0

    $counter = $pill.Child.Children[1]

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Label + '  '
    $text.FontSize = 11
    $text.FontWeight = 'SemiBold'
    $text.VerticalAlignment = 'Center'
    Set-TextFg $text $Style.Fg
    $pill.Child.Children.Insert(1, $text)

    Start-CountUp $Window $counter ('{0}/' + $Total) $Count

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
