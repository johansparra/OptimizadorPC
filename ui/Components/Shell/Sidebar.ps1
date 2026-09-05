# ============================================================
# Componente: barra de navegación lateral
#
# Construye los botones a partir de ui/Index/NavigationIndex.ps1 y
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

    # El indicador no puede colocarse todavía: sin medidas no se
    # sabe a qué altura está cada botón. Se coloca al primer
    # SizeChanged del panel, que es cuando WPF le da tamaño.
    #
    # Se ata UNA sola vez, porque Build-Sidebar se repite al cambiar
    # de idioma y cada pasada dejaría otro manejador enganchado. El
    # Tag del Border lo marca: ahí no vive ningún otro dato.
    $sidebar = $Window.FindName('Sidebar')
    if ($sidebar -and $sidebar.Tag -ne 'wired') {
        $sidebar.Tag = 'wired'
        $sidebar.Add_SizeChanged({
            param($s, $e)
            Move-NavIndicator ([System.Windows.Window]::GetWindow($s))
        })
    }

    Move-NavIndicator $Window
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
    $label.Text = T $Item.Label
    $label.FontSize = 9.5
    $label.HorizontalAlignment = 'Center'
    $label.Margin = New-Object System.Windows.Thickness 0, 5, 0, 0
    Set-TextFg $label 'TextMuted'
    $stack.Children.Add($label) | Out-Null

    $button.Content = $stack

    if ($Item.Locked) {
        $button.IsEnabled = $false
        $button.Opacity = 0.4
        $button.ToolTip = (T '{0}: locked') -f (T $Item.Label)
        $icon.Text = Glyph 'Lock'
    }
    elseif ($Item.Default) {
        $button.Tag = 'sel'
    }

    # El Uid guarda el Id de la entrada: así el handler puede
    # averiguar a qué vista lleva sin recurrir a un closure.
    $button.Uid = $Item.Id
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

    # Cada entrada declara su vista en ui/Index/NavigationIndex.ps1.
    #
    # Sin View, la sección aún no tiene pantalla y el clic se queda
    # aquí: NADA de mandar a una vista de relleno -eso deja el menú
    # marcando una cosa y la pantalla enseñando otra-. El botón se ve
    # y responde como los demás, pero no navega ni mueve la
    # selección, así que el usuario sigue exactamente donde estaba.
    $item = Get-NavigationItem $Button.Uid
    if (-not $item -or -not $item.View) { return }

    # Marcar el botón NO se hace aquí: lo hace Sync-NavSelection al
    # terminar de navegar. Así hay un solo sitio que decida qué está
    # marcado, y da igual si se ha llegado pulsando o de otra forma.
    Show-View -Name $item.View
}

<#
    Deja marcada la entrada del menú que enseña la pantalla actual.

    Hace falta porque a una vista se puede llegar SIN pulsar su
    botón: a la de búsqueda se entra también con Enter desde la caja
    de la cabecera. Sin esto el menú marcaría "Optimizar" mientras la
    pantalla enseña la búsqueda — exactamente lo que la regla 13 pide
    evitar.

    Si la pantalla actual no es la de ninguna entrada -el detalle de
    una sección, por ejemplo- NO se toca nada: se sigue marcando
    aquella desde la que se entró, que es lo que uno espera al bajar
    un nivel.
#>
function Sync-NavSelection {
    param($Window, [string]$ViewName)

    if (-not $Window -or -not $ViewName) { return }

    $item = @(Get-NavigationItems | Where-Object { $_.View -eq $ViewName })[0]
    if (-not $item) { return }

    $button = $Window.FindName((Get-NavElementName $item.Id))
    # Sin menú construido no hay nada que marcar: pasa en las pruebas,
    # que pintan vistas sobre una ventana pelada.
    if (-not $button) { return }

    foreach ($nav in Get-NavigationItems) {
        $otro = $Window.FindName((Get-NavElementName $nav.Id))
        if ($otro) { $otro.Tag = $null }
    }
    $button.Tag = 'sel'
    Update-NavColors $Window
    Move-NavIndicator -Window $Window -Animate
}

<#
    Lleva la marca del menú a la entrada seleccionada.

    Es UN solo indicador que se desliza, no uno por botón que se
    enciende y se apaga: el recorrido es lo que dice de dónde
    vienes, y sin él el ojo tiene que volver a buscar dónde está
    la marca cada vez.

    Vive en el Border NavIndicator del XAML y se mueve con un
    TranslateTransform, no cambiando su Margin: mover el margen
    obliga a WPF a medir el panel entero en cada fotograma.

    SIN MEDIDAS NO SE COLOCA. Al arrancar, main.ps1 pinta la
    primera pantalla antes de que la ventana exista de verdad, así
    que aquí todo vale cero; el indicador se queda escondido y
    vuelve por el SizeChanged que ata Build-Sidebar. El fondo del
    botón marcado ya distingue la entrada mientras tanto, de modo
    que ni un solo instante hay nada sin marcar.

    -Animate solo al navegar. El SizeChanged llama sin él: durante
    el plegado del menú se dispara decenas de veces y una animación
    por cada una se pelearía consigo misma.
#>
function Move-NavIndicator {
    param($Window, [switch]$Animate)

    $indicator = $Window.FindName('NavIndicator')
    $anchor    = $Window.FindName('NavHost')
    if (-not $indicator -or -not $anchor) { return }

    $selected = $null
    foreach ($item in Get-NavigationItems) {
        $button = $Window.FindName((Get-NavElementName $item.Id))
        if ($button -and $button.Tag -eq 'sel') { $selected = $button; break }
    }

    if (-not $selected -or $selected.ActualHeight -le 0) {
        $indicator.Opacity = 0
        return
    }

    # TranslatePoint lanza si los dos controles no comparten árbol
    # visual, y eso pasa mientras se está reconstruyendo el menú.
    # Un indicador escondido es mejor que una ventana caída.
    try {
        $origin = $selected.TranslatePoint((New-Object System.Windows.Point 0, 0), $anchor)
    }
    catch {
        $indicator.Opacity = 0
        return
    }

    $y = $origin.Y + (($selected.ActualHeight - $indicator.Height) / 2)

    if ($indicator.RenderTransform -isnot [System.Windows.Media.TranslateTransform]) {
        $indicator.RenderTransform = New-Object System.Windows.Media.TranslateTransform
    }

    if ($Animate -and $indicator.Opacity -gt 0) {
        $indicator.RenderTransform.BeginAnimation(
            [System.Windows.Media.TranslateTransform]::YProperty,
            (New-Anim $indicator.RenderTransform.Y $y 300 0 (New-Ease -Kind 'Quint')))
    }
    else {
        # Pasar $null suelta la animación anterior: sin eso, un valor
        # animado gana siempre al que se escribe a mano y el
        # indicador se quedaría clavado donde lo dejó la última.
        $indicator.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $null)
        $indicator.RenderTransform.Y = $y
    }

    $indicator.Opacity = 1
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
        if ($Expanded) { $button.ToolTip = T 'Hide the menu' } else { $button.ToolTip = T 'Show the menu' }
    }

    $script:SidebarExpanded = $Expanded
}

function Switch-Sidebar {
    param($Window)
    Set-SidebarExpanded -Window $Window -Expanded (-not $SidebarExpanded)
}

function Get-SidebarExpanded { $script:SidebarExpanded }
