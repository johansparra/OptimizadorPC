# ============================================================
# Componente: menú del botón "Vista"
#
# El chip "Vista" de la cabecera y el desplegable que abre. Las
# filas salen de ui/Index/ViewOptionsIndex.ps1, así que este archivo
# no sabe cuáles son ni cuántas hay.
#
# Devuelve un Grid con el botón y el Popup dentro. El Popup TIENE
# que colgar de ese Grid: si se creara suelto quedaría fuera del
# árbol lógico y los SetResourceReference del tema no resolverían.
#
# Cada fila cambia una opción de vista y repinta la pantalla
# actual, porque las insignias y los detalles técnicos se deciden
# al construir cada tarjeta.
# ============================================================

function New-ViewMenu {
    param($Window, [string]$Label = 'View')

    $shell = New-Object System.Windows.Controls.Grid
    $shell.VerticalAlignment = 'Center'

    $button = New-ChipButton $Window $Label 'Filter' -Chevron
    $shell.Children.Add($button) | Out-Null

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.PlacementTarget = $button
    $popup.Placement = 'Bottom'
    $popup.VerticalOffset = 4
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'Fade'
    $popup.Child = (New-ViewMenuCard $Window $popup)
    $shell.Children.Add($popup) | Out-Null

    # El popup viaja en el Tag del botón: nada de closures
    # (regla 4 de CLAUDE.md).
    $button.Tag = $popup
    $button.Add_Click({
        param($s, $e)
        $pop = $s.Tag
        # El desplegable se alinea por la derecha con el botón,
        # que vive pegado al borde de la ventana. El ancho real
        # solo se conoce una vez medido, de ahí que se calcule
        # aquí y no al construirlo.
        $pop.HorizontalOffset = $s.ActualWidth - $ViewMenuWidth
        $pop.IsOpen = -not $pop.IsOpen
    })

    $shell
}

# Ancho del desplegable. También lo usa el cálculo del offset.
$ViewMenuWidth = 300.0

# La tarjeta flotante: marco + una fila por opción.
function New-ViewMenuCard {
    param($Window, $Popup)

    # AllowsTransparency recorta lo que se salga del Popup, así que
    # la sombra necesita este margen para caber.
    $room = New-Object System.Windows.Controls.Grid
    $room.Margin = New-Object System.Windows.Thickness 10, 0, 10, 14

    $card = New-Object System.Windows.Controls.Border
    $card.Width = $ViewMenuWidth
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

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Show on screen'
    $title.FontSize = 10.5
    $title.FontWeight = 'SemiBold'
    $title.Margin = New-Object System.Windows.Thickness 11, 4, 0, 7
    Set-TextFg $title 'TextFaint'
    $rows.Children.Add($title) | Out-Null

    foreach ($option in Get-ViewOptions) {
        $rows.Children.Add((New-ViewMenuRow $Window $option $Popup)) | Out-Null
    }

    $card.Child = $rows
    $room.Children.Add($card) | Out-Null
    $room
}

# Una fila con casilla: [check] [icono] [etiqueta + pista]
function New-ViewMenuRow {
    param($Window, $Option, $Popup)

    $checked = Get-ViewOption $Option.Id

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 8
    $row.Padding = New-Object System.Windows.Thickness 9, 8, 10, 9
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', 'Auto', '*'

    # --- columna 0: la marca de verificación ---
    # Los dos iconos se alinean arriba para quedar a la altura del
    # título, no del centro de la fila, que con la pista de debajo
    # los dejaría junto al texto pequeño.
    $check = New-Icon 'Check' 13 'Accent'
    $check.Width = 18
    $check.HorizontalAlignment = 'Left'
    $check.VerticalAlignment = 'Top'
    $check.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
    if ($checked) { $check.Visibility = 'Visible' } else { $check.Visibility = 'Hidden' }
    Add-ToColumn $grid $check 0

    # --- columna 1: icono de la opción ---
    $icon = New-Icon $Option.Icon 13 'TextMuted'
    $icon.Margin = New-Object System.Windows.Thickness 0, 2, 9, 0
    $icon.VerticalAlignment = 'Top'
    Add-ToColumn $grid $icon 1

    # --- columna 2: etiqueta y pista ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T $Option.Label
    $label.FontSize = 12.5
    $label.FontWeight = 'SemiBold'
    Set-TextFg $label 'Text'
    $texts.Children.Add($label) | Out-Null

    if ($Option.Hint) {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = T $Option.Hint
        $hint.FontSize = 11
        $hint.TextWrapping = 'Wrap'
        $hint.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
        Set-TextFg $hint 'TextMuted'
        $texts.Children.Add($hint) | Out-Null
    }

    Add-ToColumn $grid $texts 2
    $row.Child = $grid

    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceSunken' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    # Todo lo que hace falta al pulsar, por el Tag.
    $row.Tag = [PSCustomObject]@{ Id = $Option.Id; Check = $check; Popup = $Popup }
    $row.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        $new = -not (Get-ViewOption $info.Id)
        Set-ViewOption $info.Id $new
        if ($new) { $info.Check.Visibility = 'Visible' } else { $info.Check.Visibility = 'Hidden' }

        $info.Popup.IsOpen = $false

        # Repintar destruye la cabecera donde vive este mismo menú,
        # así que se aplaza al Dispatcher para que el evento termine
        # antes (mismo motivo que en Update-UiLanguage).
        (Get-AppWindow).Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{ Show-CurrentView }) | Out-Null
    })

    $row
}
