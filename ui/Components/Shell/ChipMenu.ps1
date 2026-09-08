# ============================================================
# Componente: chip con menú de acciones
#
# El hermano "de acción" de ui/Components/Shell/ViewMenu.ps1: un chip
# con chevron que despliega un Popup con una lista de órdenes de un
# solo disparo. La diferencia con ViewMenu es la mecánica, no el
# aspecto: allí cada fila es una CASILLA que alterna una opción de
# vista y repinta la pantalla; aquí cada fila es una ORDEN que se
# ejecuta y ya está, sin marca de selección ni repintado. Comparten
# la tarjeta flotante con sombra y las filas con hover; fundirlos
# obligaría a churnear un componente ya probado para poco.
#
# Uso (ver New-DisclosureBulkButtons en ui/Views/CategoryDetailView.ps1):
#
#   New-ChipMenu $Window 'Expand' 'ChevronDown' @(
#       [PSCustomObject]@{ Label = 'Reference';        Icon = 'OpenIn'
#                          OnClick = { Set-CategoryDisclosures -Open $true -Kind 'reference' } }
#       [PSCustomObject]@{ Label = 'Technical details'; Icon = 'Info'
#                          OnClick = { Set-CategoryDisclosures -Open $true -Kind 'technical' } }
#       [PSCustomObject]@{ Label = 'All';              Icon = 'Apps'
#                          OnClick = { Set-CategoryDisclosures -Open $true } }
#   )
#
# Devuelve el Grid con el chip y el Popup dentro, listo para
# Add-PageAction. El Popup TIENE que colgar de ese Grid o los
# SetResourceReference del tema no resuelven (igual que ViewMenu).
#
# Cada OnClick es un scriptblock SIN parámetros que se invoca con &.
# No captura variables locales: solo llama a funciones del script
# (regla 4). Viaja en el Tag de la fila, nunca en un closure. Es el
# mismo patrón que ui/Components/Cards/PreferenceCard.ps1 con
# $Preference.Set.
# ============================================================

# Ancho del desplegable. También lo usa el cálculo del offset.
$ChipMenuWidth = 220.0

function New-ChipMenu {
    param($Window, [string]$Label, [string]$Icon, [object[]]$Items)

    $shell = New-Object System.Windows.Controls.Grid
    $shell.VerticalAlignment = 'Center'

    $button = New-ChipButton $Window $Label $Icon -Chevron
    $shell.Children.Add($button) | Out-Null

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.PlacementTarget = $button
    $popup.Placement = 'Bottom'
    $popup.VerticalOffset = 4
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'Fade'
    $popup.Child = (New-ChipMenuCard $Window $popup $Items)
    $shell.Children.Add($popup) | Out-Null

    # El popup viaja en el Tag del botón: nada de closures (regla 4).
    $button.Tag = $popup
    $button.Add_Click({
        param($s, $e)
        $pop = $s.Tag
        # El desplegable se alinea por la derecha con el chip, que
        # vive pegado al borde de la ventana. El ancho real solo se
        # conoce una vez medido, de ahí que se calcule aquí.
        $pop.HorizontalOffset = $s.ActualWidth - $ChipMenuWidth
        $pop.IsOpen = -not $pop.IsOpen
    })

    $shell
}

# La tarjeta flotante: marco con sombra + una fila por acción.
function New-ChipMenuCard {
    param($Window, $Popup, [object[]]$Items)

    # AllowsTransparency recorta lo que se salga del Popup, así que
    # la sombra necesita este margen para caber.
    $room = New-Object System.Windows.Controls.Grid
    $room.Margin = New-Object System.Windows.Thickness 10, 0, 10, 14

    $card = New-Object System.Windows.Controls.Border
    $card.Width = $ChipMenuWidth
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.BorderThickness = New-Object System.Windows.Thickness 1
    $card.Padding = New-Object System.Windows.Thickness 6, 7, 6, 7
    Set-BoxBg   $card 'Surface'
    Set-BoxLine $card 'Stroke'

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 3
    $shadow.BlurRadius = 16; $shadow.Opacity = 0.18
    $card.Effect = $shadow

    $rows = New-Object System.Windows.Controls.StackPanel
    foreach ($item in $Items) {
        $rows.Children.Add((New-ChipMenuRow $Window $item $Popup)) | Out-Null
    }

    $card.Child = $rows
    $room.Children.Add($card) | Out-Null
    $room
}

# Una fila: [icono] etiqueta, con hover. Al pulsarla cierra el menú
# y ejecuta su acción.
function New-ChipMenuRow {
    param($Window, $Item, $Popup)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 8
    $row.Padding = New-Object System.Windows.Thickness 9, 8, 10, 9
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*'

    if ($Item.Icon) {
        $icon = New-Icon $Item.Icon 13 'TextMuted'
        $icon.Margin = New-Object System.Windows.Thickness 0, 0, 9, 0
        $icon.VerticalAlignment = 'Center'
        Add-ToColumn $grid $icon 0
    }

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T $Item.Label
    $label.FontSize = 12.5
    $label.FontWeight = 'SemiBold'
    $label.VerticalAlignment = 'Center'
    Set-TextFg $label 'Text'
    Add-ToColumn $grid $label 1

    $row.Child = $grid

    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceSunken' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    # La orden y el popup viajan en el Tag: nada de closures (regla 4).
    $row.Tag = [PSCustomObject]@{ OnClick = $Item.OnClick; Popup = $Popup }
    $row.Add_MouseLeftButtonUp({
        param($s, $e)
        $s.Tag.Popup.IsOpen = $false
        if ($s.Tag.OnClick) { & $s.Tag.OnClick }
    })

    $row
}
