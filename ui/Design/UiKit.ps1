# ============================================================
# UiKit.ps1
# Componentes visuales reutilizables construidos por código.
# Todos usan recursos dinámicos del tema (ver Theme.ps1), así
# que cambian de color solos al alternar claro/oscuro.
# ============================================================

$IconFont = New-Object System.Windows.Media.FontFamily 'Segoe Fluent Icons, Segoe MDL2 Assets'

# ---- Ayudantes de rejilla -----------------------------------
# Declara las columnas de un Grid de una sola línea:
#     Add-GridColumns $grid 'Auto', '*', 'Auto'
# Acepta 'Auto', '*' o un ancho fijo en píxeles ('120').
function Add-GridColumns {
    param($Grid, [string[]]$Widths)
    foreach ($w in $Widths) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        if ($w -eq '*')         { $cd.Width = [System.Windows.GridLength]::new(1, 'Star') }
        elseif ($w -eq 'Auto')  { $cd.Width = [System.Windows.GridLength]::Auto }
        else                    { $cd.Width = [System.Windows.GridLength]::new([double]$w) }
        $Grid.ColumnDefinitions.Add($cd)
    }
}

# Coloca un elemento en una columna del Grid.
function Add-ToColumn {
    param($Grid, $Element, [int]$Column)
    [System.Windows.Controls.Grid]::SetColumn($Element, $Column)
    $Grid.Children.Add($Element) | Out-Null
}

function New-Icon {
    param([string]$Name, [double]$Size = 16, [string]$Fg = 'Text')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.FontFamily = $IconFont
    $t.Text = Glyph $Name
    $t.FontSize = $Size
    $t.VerticalAlignment = 'Center'
    $t.HorizontalAlignment = 'Center'
    Set-TextFg $t $Fg
    $t
}

# Cuadro redondeado con el icono de la categoría.
function New-IconTile {
    param([string]$Name, [string]$Fg = 'Accent', [string]$Bg = 'AccentSoft', [double]$Size = 42)
    $b = New-Object System.Windows.Controls.Border
    $b.Width = $Size; $b.Height = $Size
    $b.CornerRadius = New-Object System.Windows.CornerRadius 12
    $b.VerticalAlignment = 'Center'
    Set-BoxBg $b $Bg
    $b.Child = (New-Icon $Name ($Size * 0.44) $Fg)
    $b
}

# Píldora de estadística: icono + texto sobre fondo suave.
function New-Pill {
    param([string]$Icon, [string]$Text, [string]$Fg, [string]$Bg, [string]$Tip)
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 999
    $b.Padding = New-Object System.Windows.Thickness 9, 4, 11, 5
    $b.Margin = New-Object System.Windows.Thickness 6, 0, 0, 0
    $b.VerticalAlignment = 'Center'
    if ($Tip) { $b.ToolTip = $Tip }
    Set-BoxBg $b $Bg

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $ic = New-Icon $Icon 10.5 $Fg
    $ic.Margin = New-Object System.Windows.Thickness 0, 0, 5, 0
    $sp.Children.Add($ic) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = 11; $t.FontWeight = 'SemiBold'
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t $Fg
    $sp.Children.Add($t) | Out-Null

    $b.Child = $sp
    $b
}

<#
    Cómo se enseña cada estado de los que calcula
    core/Registry/SettingStatus.ps1 mirando el registro de verdad.

    Un único sitio con el nombre, el icono, los colores y el pie de
    ayuda de cada estado: lo usan la etiqueta de la tarjeta de ajuste
    y las píldoras del resumen de la sección, así que no pueden
    acabar diciendo cosas distintas. Añadir un estado es añadir una
    línea aquí y otra en core/.

    Los textos se guardan en inglés y se traducen al pintarlos
    (regla 15): aquí no se llama a T.
#>
$SettingStatusStyles = @{
    'optimized' = @{ Label = 'Optimized';           Icon = 'StarFill'; Fg = 'Success';   Bg = 'SuccessSoft'
                     Tip   = 'The registry value is the one this program recommends'
                     Count = 'Optimized: {0} of {1}' }

    'factory'   = @{ Label = 'Factory recommended'; Icon = 'Grid';     Fg = 'TextMuted'; Bg = 'SurfaceSunken'
                     Tip   = 'The registry value is the Windows factory one'
                     Count = 'Factory recommended: {0} of {1}' }

    'custom'    = @{ Label = 'Custom';              Icon = 'Sliders';  Fg = 'Warn';      Bg = 'WarnSoft'
                     Tip   = 'The registry value is neither the recommended nor the factory one'
                     Count = 'Customised: {0} of {1}' }

    'unknown'   = @{ Label = 'Unknown';             Icon = 'Help';     Fg = 'TextFaint'; Bg = 'SurfaceSunken'
                     Tip   = 'The registry value could not be read'
                     Count = 'Unknown: {0} of {1}' }
}

# Un estado que no esté en el catálogo se enseña como desconocido,
# que es exactamente lo que es: nadie sabe qué significa.
function Get-StatusStyle {
    param([string]$Status)

    $style = $SettingStatusStyles[[string]$Status]
    if (-not $style) { $style = $SettingStatusStyles['unknown'] }
    $style
}

<#
    Etiqueta del estado REAL de un ajuste: icono, nombre y un pie de
    ayuda que explica por qué está ahí.

    Sustituye a las etiquetas declaradas (New-Tag) en los ajustes que
    sí leen el registro; ver ui/Components/Cards/SettingCard.ps1.
#>
function New-StatusTag {
    param([string]$Status)

    $style = Get-StatusStyle $Status

    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 6
    $b.Padding = New-Object System.Windows.Thickness 8, 2.5, 9, 3.5
    $b.Margin = New-Object System.Windows.Thickness 0, 0, 6, 0
    $b.ToolTip = T $style.Tip
    Set-BoxBg $b $style.Bg

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $icon = New-Icon $style.Icon 10 $style.Fg
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 5, 0
    $sp.Children.Add($icon) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $style.Label
    $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t $style.Fg
    $sp.Children.Add($t) | Out-Null

    $b.Child = $sp
    $b
}

# Etiqueta de clasificación (Recommended / Default / Custom).
function New-Tag {
    param([string]$Text)
    $map = @{
        'Recommended' = @{ Fg = 'Success';   Bg = 'SuccessSoft' }
        'Default'     = @{ Fg = 'TextMuted'; Bg = 'SurfaceSunken' }
        'Custom'      = @{ Fg = 'Warn';      Bg = 'WarnSoft' }
    }
    $c = $map[$Text]
    if (-not $c) { $c = @{ Fg = 'TextMuted'; Bg = 'SurfaceSunken' } }

    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 6
    $b.Padding = New-Object System.Windows.Thickness 8, 2.5, 8, 3.5
    $b.Margin = New-Object System.Windows.Thickness 0, 0, 6, 0
    Set-BoxBg $b $c.Bg

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $Text; $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'
    Set-TextFg $t $c.Fg
    $b.Child = $t
    $b
}

# Distintivo rojo "NEW n". Se traduce la PALABRA y se respeta el
# número ('NEW 45' -> 'NUEVO 45'), de modo que ui/Data/Lang/ solo
# necesita la línea de 'NEW' y no una por cada cifra.
function New-Badge {
    param([string]$Text)
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 999
    $b.Padding = New-Object System.Windows.Thickness 7, 1.5, 7, 2.5
    $b.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
    $b.VerticalAlignment = 'Center'
    Set-BoxBg $b 'Danger'

    $t = New-Object System.Windows.Controls.TextBlock
    if ($Text -match '^(.*\S)\s+(\d+)$') { $t.Text = (T $Matches[1]) + ' ' + $Matches[2] }
    else                                 { $t.Text = T $Text }
    $t.FontSize = 9.5; $t.FontWeight = 'Bold'
    $t.Foreground = [System.Windows.Media.Brushes]::White
    $b.Child = $t
    $b
}

# ---- Interruptor animado ------------------------------------
# El estado vive en el Tag del propio control, nunca en un
# closure (ver la regla 4 de CLAUDE.md).
function New-ToggleSwitch {
    param($Window, [bool]$InitialState, $Label)

    $w = 40.0; $h = 22.0; $k = 16.0; $pad = 3.0
    $travel = $w - $k - ($pad * 2)
    $onColor  = ([System.Windows.Media.SolidColorBrush](Get-Brush $Window 'Accent')).Color
    $offColor = ([System.Windows.Media.SolidColorBrush](Get-Brush $Window 'TrackOff')).Color

    $track = New-Object System.Windows.Controls.Border
    $track.Width = $w; $track.Height = $h
    $track.CornerRadius = New-Object System.Windows.CornerRadius ($h / 2)
    $track.Cursor = 'Hand'
    $track.VerticalAlignment = 'Center'
    if ($InitialState) { $start = $onColor } else { $start = $offColor }
    $track.Background = New-Object System.Windows.Media.SolidColorBrush $start

    $knob = New-Object System.Windows.Controls.Border
    $knob.Width = $k; $knob.Height = $k
    $knob.CornerRadius = New-Object System.Windows.CornerRadius ($k / 2)
    $knob.HorizontalAlignment = 'Left'
    $knob.VerticalAlignment = 'Center'
    $knob.Margin = New-Object System.Windows.Thickness $pad, 0, 0, 0
    Set-BoxBg $knob 'Knob'

    $sh = New-Object System.Windows.Media.Effects.DropShadowEffect
    $sh.Color = [System.Windows.Media.Colors]::Black
    $sh.Direction = 270; $sh.ShadowDepth = 1; $sh.BlurRadius = 3; $sh.Opacity = 0.25
    $knob.Effect = $sh

    $tt = New-Object System.Windows.Media.TranslateTransform
    if ($InitialState) { $tt.X = $travel } else { $tt.X = 0 }
    $knob.RenderTransform = $tt
    $track.Child = $knob

    $track.Tag = [PSCustomObject]@{
        State = $InitialState; On = $onColor; Off = $offColor
        Travel = $travel; Label = $Label
    }

    $track.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        $new = -not $info.State
        $info.State = $new

        $ca = New-Object System.Windows.Media.Animation.ColorAnimation
        if ($new) { $ca.To = $info.On } else { $ca.To = $info.Off }
        $ca.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(170))
        $ca.EasingFunction = New-Ease
        $s.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty, $ca)

        if ($new) { $to = $info.Travel } else { $to = 0.0 }
        $s.Child.RenderTransform.BeginAnimation(
            [System.Windows.Media.TranslateTransform]::XProperty,
            (New-Anim $s.Child.RenderTransform.X $to 190))

        if ($info.Label) {
            if ($new) { $info.Label.Text = T 'On' } else { $info.Label.Text = T 'Off' }
        }
    })

    $track
}

# ---- Caja de búsqueda con icono y marcador de posición -------
function New-SearchBox {
    param($Window, [string]$Placeholder = 'Search optimizations...', [double]$Width = 260)

    $shell = New-Object System.Windows.Controls.Grid
    $shell.Width = $Width

    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Style = $Window.FindResource('SearchBoxStyle')
    $shell.Children.Add($tb) | Out-Null

    $ph = New-Object System.Windows.Controls.StackPanel
    $ph.Orientation = 'Horizontal'
    $ph.IsHitTestVisible = $false
    $ph.VerticalAlignment = 'Center'
    $ph.Margin = New-Object System.Windows.Thickness 13, 0, 0, 0

    $ic = New-Icon 'Search' 13 'TextFaint'
    $ic.Margin = New-Object System.Windows.Thickness 0, 0, 8, 0
    $ph.Children.Add($ic) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $Placeholder; $t.FontSize = 12.5
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t 'TextFaint'
    $ph.Children.Add($t) | Out-Null

    $shell.Children.Add($ph) | Out-Null

    # El marcador se oculta en cuanto hay texto.
    $tb.Tag = $ph
    $tb.Add_TextChanged({
        param($s, $e)
        if ($s.Text.Length -gt 0) { $s.Tag.Visibility = 'Collapsed' } else { $s.Tag.Visibility = 'Visible' }
    })

    [PSCustomObject]@{ Root = $shell; Box = $tb }
}

# Botón secundario con icono opcional y chevron.
function New-ChipButton {
    param($Window, [string]$Text, [string]$Icon, [switch]$Chevron)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $Window.FindResource('ChipButtonStyle')

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    if ($Icon) {
        $ic = New-Icon $Icon 13 'TextMuted'
        $ic.Margin = New-Object System.Windows.Thickness 0, 0, 7, 0
        $sp.Children.Add($ic) | Out-Null
    }

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $Text; $t.FontSize = 12.5; $t.FontWeight = 'SemiBold'
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t 'Text'
    $sp.Children.Add($t) | Out-Null

    if ($Chevron) {
        $cv = New-Icon 'ChevronDown' 10 'TextFaint'
        $cv.Margin = New-Object System.Windows.Thickness 7, 1, 0, 0
        $sp.Children.Add($cv) | Out-Null
    }

    $btn.Content = $sp
    $btn
}
