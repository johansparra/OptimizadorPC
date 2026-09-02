# ============================================================
# Componente: barra de navegación lateral
#
# Construye los botones a partir de ui/NavigationIndex.ps1 y
# gestiona el plegado animado.
#
# El XAML solo aporta dos contenedores vacíos (NavTop y
# NavBottom) dentro del Border llamado Sidebar; todo lo demás
# se crea aquí.
# ============================================================

# Ancho del panel desplegado. Al plegarse se anima hasta 0.
$SidebarWidth = 88.0
$SidebarExpanded = $true

# ---- Construcción -------------------------------------------

function Build-Sidebar {
    param($Window)

    $top    = $Window.FindName('NavTop')
    $bottom = $Window.FindName('NavBottom')
    $top.Children.Clear()
    $bottom.Children.Clear()

    foreach ($item in Get-NavigationItems) {
        $button = New-NavButton -Window $Window -Item $item
        if ($item.Group -eq 'Bottom') {
            $bottom.Children.Add($button) | Out-Null
        } else {
            $top.Children.Add($button) | Out-Null
        }
    }

    Update-NavColors $Window
}

function New-NavButton {
    param($Window, $Item)

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $Window.FindResource('NavButtonStyle')

    $stack = New-Object System.Windows.Controls.StackPanel

    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.FontFamily = $Window.FindResource('IconFont')
    $icon.Text = Glyph $Item.Icon
    $icon.FontSize = 19
    $icon.HorizontalAlignment = 'Center'
    Set-TextFg $icon 'TextMuted'
    $stack.Children.Add($icon) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Item.Label
    $label.FontSize = 9.5
    $label.HorizontalAlignment = 'Center'
    $label.Margin = New-Object System.Windows.Thickness 0, 5, 0, 0
    Set-TextFg $label 'TextMuted'
    $stack.Children.Add($label) | Out-Null

    $button.Content = $stack

    if ($Item.Locked) {
        $button.IsEnabled = $false
        $button.Opacity = 0.4
        $button.ToolTip = "$($Item.Label): bloqueado"
        $icon.Text = Glyph 'Lock'
    }
    elseif ($Item.Default) {
        $button.Tag = 'sel'
    }

    $button.Add_Click({ param($s, $e) Set-NavSelection $s })

    # Se registra con su nombre para que $Window.FindName siga
    # encontrándolo aunque el botón ya no exista en el XAML.
    $name = Get-NavElementName $Item.Id
    try { $Window.UnregisterName($name) } catch { }
    $Window.RegisterName($name, $button)

    $button
}

# ---- Selección ----------------------------------------------

function Set-NavSelection {
    param($Button)

    $window = [System.Windows.Window]::GetWindow($Button)
    foreach ($item in Get-NavigationItems) {
        $window.FindName((Get-NavElementName $item.Id)).Tag = $null
    }
    $Button.Tag = 'sel'
    Update-NavColors $window

    # Todas las entradas llevan de momento a la misma vista.
    Show-OptimizationsListView -Window $window
}

# El estilo del XAML pinta el fondo del botón seleccionado; el
# color del icono y de la etiqueta se ajusta aquí.
function Update-NavColors {
    param($Window)

    foreach ($item in Get-NavigationItems) {
        $button = $Window.FindName((Get-NavElementName $item.Id))
        if (-not $button) { continue }

        if ($button.Tag -eq 'sel') { $key = 'Accent'; $weight = 'SemiBold' }
        else                       { $key = 'TextMuted'; $weight = 'Normal' }

        $icon  = $button.Content.Children[0]
        $label = $button.Content.Children[1]
        Set-TextFg $icon  $key
        Set-TextFg $label $key
        $label.FontWeight = $weight
    }
}

# ---- Plegado animado ----------------------------------------

function Set-SidebarExpanded {
    param($Window, [bool]$Expanded, [int]$Ms = 220)

    $sidebar = $Window.FindName('Sidebar')
    $button  = $Window.FindName('BtnMenu')

    if ($Expanded) { $to = $SidebarWidth } else { $to = 0.0 }

    # El borde derecho de 1px impide que el ancho llegue de verdad
    # a cero: se quita al plegar y se repone al desplegar.
    if ($Expanded) {
        $sidebar.BorderThickness = New-Object System.Windows.Thickness 0, 1, 1, 0
    } else {
        $sidebar.BorderThickness = New-Object System.Windows.Thickness 0
    }

    # Se anima el ancho del Border, no la columna del Grid: la
    # columna es Auto, así que sigue al Border sola. Animar un
    # GridLength requiere una animación propia que WPF no trae.
    $sidebar.BeginAnimation(
        [System.Windows.FrameworkElement]::WidthProperty,
        (New-Anim $sidebar.ActualWidth $to $Ms))

    # El contenido se desvanece un poco antes de terminar de
    # plegarse, para que no se vea recortado a media animación.
    if ($Expanded) { $fade = New-Anim 0 1 $Ms } else { $fade = New-Anim 1 0 ([int]($Ms * 0.6)) }
    $sidebar.Child.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)

    if ($button) {
        if ($Expanded) { $button.ToolTip = 'Ocultar el menú' } else { $button.ToolTip = 'Mostrar el menú' }
    }

    $script:SidebarExpanded = $Expanded
}

function Switch-Sidebar {
    param($Window)
    Set-SidebarExpanded -Window $Window -Expanded (-not $SidebarExpanded)
}

function Get-SidebarExpanded { $script:SidebarExpanded }
