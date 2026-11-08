# ============================================================
# Componente: tarjetas de la sección Guías
#
#   New-GuideCard          una fila de la lista, como las de Optimizar:
#                          [icono] [título / resumen] [secciones · min] [>]
#   New-GuideDocument      la guía abierta: el documento Markdown dentro
#                          de una tarjeta (ui/Components/Layout/MarkdownDocument.ps1)
#   New-GuideCopyButton    "Copiar todo" de la cabecera
#   New-GuideEmptyState    la lista sin ninguna guía
#
# Título, resumen y texto son del USUARIO (los .md de ui/Data/Guides):
# no pasan por T. Lo que sí se traduce es el marco: "N secciones",
# "N min de lectura", los botones.
# ============================================================

function New-GuideCard {
    param($Window, $Guide)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 20, 17, 22, 17

    # El ratón y el clic, en el envoltorio quieto (regla 21).
    $slot = Add-HoverLift $card -Glow 'Accent'
    $slot.Cursor = 'Hand'

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto', 'Auto'

    $tile = New-IconTile 'Article' 'Accent' 'AccentSoft' 44
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 16, 0
    $tile.VerticalAlignment = 'Top'
    Add-ToColumn $grid $tile 0

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Guide.Title
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 15.5
    $name.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $name 'Text'
    $text.Children.Add($name) | Out-Null

    # Dos líneas como mucho: un resumen es para reconocer la guía, no
    # para leerla aquí.
    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Guide.Summary
    $desc.FontSize = 12.5
    $desc.LineHeight = 18
    $desc.MaxHeight = 36
    $desc.TextWrapping = 'Wrap'
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 4, 24, 0
    Set-TextFg $desc 'TextMuted'
    $text.Children.Add($desc) | Out-Null
    Add-ToColumn $grid $text 1

    $stats = New-Object System.Windows.Controls.StackPanel
    $stats.Orientation = 'Horizontal'
    $stats.VerticalAlignment = 'Center'
    if ($Guide.Sections -gt 0) {
        # Singular aparte: "1 secciones" se lee mal (break-ui).
        $label = if ($Guide.Sections -eq 1) { T '1 section' } else { (T '{0} sections') -f $Guide.Sections }
        $stats.Children.Add((New-Pill 'Menu' $label 'TextMuted' 'SurfaceSunken')) | Out-Null
    }
    $stats.Children.Add((New-Pill 'Clock' ((T '{0} min read') -f $Guide.Minutes) 'Accent' 'AccentSoft')) | Out-Null
    Add-ToColumn $grid $stats 2

    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 16, 0, 2, 0
    Add-ToColumn $grid $chev 3

    $card.Child = $grid

    # La guía en el Tag (regla 4) y por Show-View (regla 17).
    $slot.Tag = $Guide
    $slot.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-View -Name 'Show-GuideView' -Arguments @{ Guide = $s.Tag }
    })
    $slot
}

# La guía abierta: una tarjeta quieta con el documento dentro.
function New-GuideDocument {
    param($Window, $Guide)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')
    $card.Padding = New-Object System.Windows.Thickness 32, 26, 32, 22
    $card.Margin = New-Object System.Windows.Thickness 0, 4, 0, 8
    $card.Child = New-MarkdownDocument -Window $Window -Blocks @(Get-GuideBlocks $Guide) -Toc
    $card
}

<#
    "Buscar en esta guía": una caja en la cabecera. Al escribir marca la
    primera aparición; Enter salta a la siguiente. Al lado dice cuántas
    hay. El documento y el rótulo viajan en el Tag de la caja (regla 4).
#>
function New-GuideFindBox {
    param($Window, $DocumentBox)

    $search = New-SearchBox -Window $Window -Placeholder 'Find in this guide' -Width 220

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Orientation = 'Horizontal'
    $panel.VerticalAlignment = 'Center'

    $status = New-Object System.Windows.Controls.TextBlock
    $status.FontSize = 11.5
    $status.VerticalAlignment = 'Center'
    $status.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
    Set-TextFg $status 'TextFaint'

    $panel.Children.Add($status) | Out-Null
    $panel.Children.Add($search.Root) | Out-Null

    $search.Box.Tag = [PSCustomObject]@{ Document = $DocumentBox; Status = $status }
    $search.Box.Add_TextChanged({ param($s, $e) Update-GuideFind $s -FromStart })
    $search.Box.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Return') { Update-GuideFind $s; $e.Handled = $true }
    })
    $panel
}

function Update-GuideFind {
    param($Box, [switch]$FromStart)

    $info = $Box.Tag
    $n = Select-MarkdownMatch $info.Document $Box.Text -FromStart:$FromStart
    $info.Status.Text = if (-not $Box.Text) { '' }
                        elseif ($n -eq 0) { T 'No matches' }
                        elseif ($n -eq 1) { T '1 match' }
                        else { (T '{0} matches') -f $n }
}

<#
    "Copiar todo": la guía entera como texto normal -sin asteriscos ni
    barras de tabla- al portapapeles, y un aviso en la cabecera.
#>
function New-GuideCopyButton {
    param($Window, $Guide)

    $chip = New-ChipButton $Window 'Copy all' 'Copy'
    $chip.ToolTip = T 'Copy the whole guide as plain text'
    $chip.Tag = $Guide
    $chip.Add_Click({
        param($s, $e)
        Copy-GuideText ([System.Windows.Window]::GetWindow($s)) $s.Tag | Out-Null
    })
    $chip
}

# Devuelve $true si se copió. El portapapeles es de todo Windows y
# otro programa puede tenerlo tomado: entonces no se avisa de nada.
function Copy-GuideText {
    param($Window, $Guide)

    $text = ConvertTo-GuidePlainText $Guide
    if (-not $text) { return $false }
    try { [System.Windows.Clipboard]::SetText($text) }
    catch { return $false }
    if ($Window) { Show-PageToast $Window 'Guide copied to the clipboard' }
    $true
}

function New-GuideEmptyState {
    $box = New-Object System.Windows.Controls.StackPanel
    $box.Margin = New-Object System.Windows.Thickness 0, 70, 0, 0
    $box.HorizontalAlignment = 'Center'

    $box.Children.Add((New-Icon 'Book' 30 'TextFaint')) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'No guides yet'
    $title.FontSize = 13
    $title.FontWeight = 'SemiBold'
    $title.HorizontalAlignment = 'Center'
    $title.Margin = New-Object System.Windows.Thickness 0, 12, 0, 0
    Set-TextFg $title 'TextMuted'
    $box.Children.Add($title) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'Put .md files in ui\Data\Guides and they will show up here'
    $hint.FontSize = 11.5
    $hint.TextAlignment = 'Center'
    $hint.TextWrapping = 'Wrap'
    $hint.MaxWidth = 340
    $hint.Margin = New-Object System.Windows.Thickness 0, 5, 0, 0
    Set-TextFg $hint 'TextFaint'
    $box.Children.Add($hint) | Out-Null
    $box
}
