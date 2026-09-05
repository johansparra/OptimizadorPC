# ============================================================
# Componente: barra de título
#
# El XAML deja los textos en inglés porque no puede llamar a T;
# aquí se traducen al arrancar y cada vez que cambia el idioma.
# ============================================================

function Update-TitleBarTexts {
    param($Window)

    $Window.FindName('BtnModeNormal').Content  = T 'Normal'
    $Window.FindName('BtnModeBuilder').Content = T 'Builder'
    $Window.FindName('BtnModeConfig').Content  = T 'Config Review'

    $Window.FindName('BtnLog').ToolTip   = T 'Activity log'
    $Window.FindName('BtnTheme').ToolTip = T 'Change theme'
    $Window.FindName('BtnHelp').ToolTip  = T 'Help'

    $menu = $Window.FindName('BtnMenu')
    if (Get-SidebarExpanded) { $menu.ToolTip = T 'Hide the menu' } else { $menu.ToolTip = T 'Show the menu' }

    # Los textos que acaban de cambiar son los de los botones de
    # modo: en español ocupan otra cosa, así que la pastilla se
    # queda del ancho del idioma anterior si no se recoloca.
    Move-ModeIndicator $Window
}

<#
    La pastilla del selector de modo (Normal / Builder / Config).

    Misma idea que Move-NavIndicator: UNA pastilla que se desliza
    en vez de tres fondos que se encienden y se apagan. Aquí se
    anima además el ANCHO, porque los tres botones miden distinto y
    una pastilla de ancho fijo dejaría el texto asomando.

    Como allí: sin medidas no se coloca -y el botón marcado se
    distingue igual por el color del texto-, se anima solo si ya
    estaba visible, y el manejador de tamaño se ata una sola vez.
#>
function Move-ModeIndicator {
    param($Window, [switch]$Animate)

    $indicator = $Window.FindName('ModeIndicator')
    $track     = $Window.FindName('ModeTrack')
    $buttons   = $Window.FindName('ModeButtons')
    if (-not $indicator -or -not $track -or -not $buttons) { return }

    if ($track.Uid -ne 'wired') {
        $track.Uid = 'wired'
        $track.Add_SizeChanged({
            param($s, $e)
            Move-ModeIndicator ([System.Windows.Window]::GetWindow($s))
        })
    }

    $selected = $null
    foreach ($button in $buttons.Children) {
        if ($button.Tag -eq 'sel') { $selected = $button; break }
    }

    if (-not $selected -or $selected.ActualWidth -le 0) {
        $indicator.Opacity = 0
        return
    }

    try {
        $origin = $selected.TranslatePoint((New-Object System.Windows.Point 0, 0), $track)
    }
    catch {
        $indicator.Opacity = 0
        return
    }

    if ($indicator.RenderTransform -isnot [System.Windows.Media.TranslateTransform]) {
        $indicator.RenderTransform = New-Object System.Windows.Media.TranslateTransform
    }

    if ($Animate -and $indicator.Opacity -gt 0) {
        $ease = New-Ease -Kind 'Quint'
        $indicator.RenderTransform.BeginAnimation(
            [System.Windows.Media.TranslateTransform]::XProperty,
            (New-Anim $indicator.RenderTransform.X $origin.X 280 0 $ease))
        $indicator.BeginAnimation(
            [System.Windows.FrameworkElement]::WidthProperty,
            (New-Anim $indicator.ActualWidth $selected.ActualWidth 280 0 $ease))
    }
    else {
        $indicator.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null)
        $indicator.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $null)
        $indicator.RenderTransform.X = $origin.X
        $indicator.Width = $selected.ActualWidth
    }

    $indicator.Opacity = 1
}

# El glifo del botón de tema refleja a qué tema se cambiaría:
# con tema claro se ve una luna, con tema oscuro un sol.
function Sync-ThemeButton {
    $window = Get-AppWindow
    if (-not $window) { return }

    $button = $window.FindName('BtnTheme')
    if ((Get-AppTheme) -eq 'Dark') { $button.Content = Glyph 'Sun' } else { $button.Content = Glyph 'Moon' }
}
