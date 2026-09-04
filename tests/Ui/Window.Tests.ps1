# ============================================================
# Pruebas de la interfaz: la ventana, el tema, la barra de
# título, el menú lateral y las vistas.
#
# Se construyen controles de WPF DE VERDAD, pero sin enseñar la
# ventana: para comprobar que el árbol es el que debe ser no
# hace falta pintar nada. Eso las deja rápidas y sin ventanas
# apareciendo por la pantalla mientras corren.
#
# Lo que NO cubren es el aspecto -si una tarjeta se ve torcida o
# si un color queda ilegible-, y no hay forma razonable de que
# lo hagan. Para eso está mirar la aplicación (ver tests/README.md).
# ============================================================

$UiWindow = New-AppWindow

Describe 'ui/MainWindow.xaml - la carcasa' {

    It 'el XAML se carga sin lanzar' {
        Assert-NoThrow { New-AppWindow }
    }

    It 'están todos los nombres que el código busca con FindName' {
        # Un FindName que devuelve $null no falla: deja un $null
        # rodando hasta que alguien le pide una propiedad, y el
        # error sale muy lejos de donde está la causa.
        $nombres = @(
            'TitleBar', 'BtnMenu', 'BtnLog', 'BtnTheme', 'BtnHelp'
            'BtnMinimize', 'BtnMaximize', 'BtnClose'
            'BtnModeNormal', 'BtnModeBuilder', 'BtnModeConfig'
            'HeaderTitleArea', 'HeaderActionsArea', 'HeaderSummaryArea'
            'Sidebar', 'NavTop', 'NavBottom'
            'MainScroll', 'MainContent'
            'ProgressStrip', 'ProgressText', 'ProgressCount', 'ProgressDone', 'ProgressLeft'
            'LogOverlay', 'LogScrim', 'LogDrawer'
        )
        foreach ($nombre in $nombres) {
            Assert-NotNull $UiWindow.FindName($nombre) "falta '$nombre' en MainWindow.xaml"
        }
    }

    It 'el botón del log está justo al lado del de tema' {
        $acciones = $UiWindow.FindName('BtnTheme').Parent
        $log      = $UiWindow.FindName('BtnLog')

        Assert-True $acciones.Children.Contains($log) 'debería estar en la misma zona de acciones'
        $distancia = [Math]::Abs($acciones.Children.IndexOf($log) - $acciones.Children.IndexOf($UiWindow.FindName('BtnTheme')))
        Assert-Equal 1 $distancia 'debería ser el botón contiguo'
    }

    It 'el cajón del log arranca colapsado' {
        # Colapsado no ocupa ni existe para el ratón: con el log
        # cerrado no hay nada estorbando delante del contenido.
        Assert-Equal 'Collapsed' ([string]$UiWindow.FindName('LogOverlay').Visibility)
    }

    It 'los estilos que el código pide por nombre existen' {
        foreach ($estilo in @('GlyphButtonStyle', 'ChipButtonStyle', 'SearchBoxStyle', 'ModernComboStyle', 'CardStyle')) {
            Assert-NoThrow { $UiWindow.FindResource($estilo) } "falta el estilo '$estilo'"
        }
        foreach ($fuente in @('IconFont', 'DisplayFont', 'BodyFont', 'MonoFont')) {
            Assert-NoThrow { $UiWindow.FindResource($fuente) } "falta la fuente '$fuente'"
        }
    }
}

Describe 'ui/Design/Theme.ps1 - claro y oscuro' {

    It 'cambiar de tema repinta los pinceles' {
        $ventana = New-AppWindow -Theme 'Light'
        $claro = ([System.Windows.Media.SolidColorBrush]$ventana.FindResource('Bg0')).Color

        Set-AppTheme -Window $ventana -Name 'Dark'
        $oscuro = ([System.Windows.Media.SolidColorBrush]$ventana.FindResource('Bg0')).Color

        Assert-NotEqual $claro $oscuro
        Assert-Equal ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-Palette 'Dark').Bg0)) $oscuro
    }

    It 'volver al tema claro deshace el cambio' {
        $ventana = New-AppWindow -Theme 'Dark'
        Set-AppTheme -Window $ventana -Name 'Light'
        $color = ([System.Windows.Media.SolidColorBrush]$ventana.FindResource('Bg0')).Color
        Assert-Equal ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-Palette 'Light').Bg0)) $color
    }

    It 'las dos paletas definen exactamente las mismas claves' {
        # Una clave que solo esté en una de las dos deja el color
        # anterior puesto al cambiar de tema, y el fallo es sutil:
        # un solo elemento que no se entera.
        $claro  = (Get-Palette 'Light').Keys | Sort-Object
        $oscuro = (Get-Palette 'Dark').Keys  | Sort-Object
        Assert-Equal ($claro -join ',') ($oscuro -join ',')
    }

    It 'un glifo que no está en el catálogo se queja' {
        # Mejor un error ruidoso que un cuadrado vacío en pantalla.
        Assert-Throws { Glyph 'EsteGlifoNoExiste' }
    }

    It 'todos los iconos que se piden existen en el catálogo' {
        foreach ($cat in Get-OptimizationCategories) {
            Assert-NoThrow { Glyph $cat.Icon } "el icono de la sección '$($cat.Id)'"
        }
        foreach ($nav in Get-NavigationItems) {
            Assert-NoThrow { Glyph $nav.Icon } "el icono del botón '$($nav.Id)'"
        }
        foreach ($opcion in Get-ViewOptions) {
            Assert-NoThrow { Glyph $opcion.Icon } "el icono de la opción '$($opcion.Id)'"
        }
    }
}

Describe 'ui/Components/Shell/TitleBar.ps1' {

    It 'pone los textos que el XAML no puede traducir' {
        $ventana = New-AppWindow -Language 'en'
        Update-TitleBarTexts $ventana

        Assert-Equal 'Activity log' ([string]$ventana.FindName('BtnLog').ToolTip)
        Assert-Equal 'Change theme' ([string]$ventana.FindName('BtnTheme').ToolTip)
        Assert-Equal 'Normal'       ([string]$ventana.FindName('BtnModeNormal').Content)
    }

    It 'en español salen traducidos' {
        $ventana = New-AppWindow -Language 'es'
        Update-TitleBarTexts $ventana

        Assert-Equal 'Registro de actividad' ([string]$ventana.FindName('BtnLog').ToolTip)
        Assert-Equal 'Cambiar tema'          ([string]$ventana.FindName('BtnTheme').ToolTip)

        Set-AppLanguage 'en'
    }

    It 'el glifo del tema enseña a qué tema se cambiaría' {
        $ventana = New-AppWindow -Theme 'Light'
        Sync-ThemeButton
        Assert-Equal (Glyph 'Moon') ([string]$ventana.FindName('BtnTheme').Content) 'con tema claro, una luna'

        Set-AppTheme -Window $ventana -Name 'Dark'
        Sync-ThemeButton
        Assert-Equal (Glyph 'Sun') ([string]$ventana.FindName('BtnTheme').Content) 'con tema oscuro, un sol'
    }
}

Describe 'ui/Components/Shell/Sidebar.ps1' {

    It 'crea un botón por cada entrada visible del índice' {
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana

        $arriba = $ventana.FindName('NavTop').Children.Count
        $abajo  = $ventana.FindName('NavBottom').Children.Count
        Assert-Equal @(Get-NavigationItems).Count ($arriba + $abajo)
    }

    It 'los botones siguen encontrándose por su nombre' {
        # Se construyen por código, pero se registran con
        # RegisterName para que FindName('NavSettings') funcione
        # igual que cuando estaban escritos en el XAML.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana

        foreach ($nav in Get-NavigationItems) {
            $nombre = Get-NavElementName $nav.Id
            Assert-NotNull $ventana.FindName($nombre) "no se ha registrado '$nombre'"
        }
        Assert-NotNull $ventana.FindName('NavSettings')
    }

    It 'reconstruirlo dos veces no lanza' {
        # Pasa de verdad al cambiar de idioma: Update-UiLanguage
        # vuelve a llamar a Build-Sidebar sobre la misma ventana.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Assert-NoThrow { Build-Sidebar -Window $ventana }
    }

    It 'plegar y desplegar deja el estado bien' {
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana

        Set-SidebarExpanded -Window $ventana -Expanded $false
        Assert-False (Get-SidebarExpanded)

        Switch-Sidebar $ventana
        Assert-True (Get-SidebarExpanded)
    }
}

Describe 'ui/Views - las pantallas se pintan' {

    It 'cada vista del índice de navegación se dibuja' {
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana

        foreach ($nav in Get-NavigationItems) {
            Assert-NoThrow { Show-View -Name $nav.View } "la vista de '$($nav.Id)'"
            Assert-NotNull $ventana.FindName('MainContent').Content "'$($nav.View)' no ha dejado nada en pantalla"
        }
    }

    It 'una vista que no existe se queja con nombre y apellidos' {
        Assert-Throws { Show-View -Name 'Show-EstaVistaNoExiste' }
    }

    It 'el detalle de cada sección pinta una tarjeta por ajuste' {
        $ventana = New-AppWindow

        foreach ($cat in Get-OptimizationCategories) {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

            $lista = $ventana.FindName('MainContent').Content
            Assert-NotNull $lista "la sección '$($cat.Id)' no ha pintado nada"
            Assert-Equal @($cat.Items).Count $lista.Children.Count "en la sección '$($cat.Id)'"
        }
    }

    It 'el detalle enseña el valor leído del equipo, no el declarado' {
        # Es la prueba de que la lectura del registro llega hasta la
        # pantalla: se busca en el texto de las tarjetas el valor que
        # core/ acaba de sacar del equipo.
        $ventana = New-AppWindow
        $cat = Get-CategoryById 'regedit'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        $leidas = @()
        foreach ($ajuste in @($cat.Items)) {
            foreach ($clave in @($ajuste.Registry)) {
                if ($clave.State -eq 'read') { $leidas += $clave }
            }
        }
        if ($leidas.Count -eq 0) { Skip-Test 'en este equipo no hay ninguna de esas claves definida' }

        $texto = Get-VisualText $ventana.FindName('MainContent').Content
        Assert-Match ([regex]::Escape($leidas[0].Current)) $texto
    }

    It 'la barra de progreso se recoge al terminar de leer' {
        $ventana = New-AppWindow
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }

        Assert-Equal 'Collapsed' ([string]$ventana.FindName('ProgressStrip').Visibility)
        Assert-True $ventana.Content.IsHitTestVisible 'la ventana tiene que volver a oír al ratón'
    }
}

Describe 'ui/Engine/Router.ps1' {

    It 'recuerda la pantalla en la que estás' {
        $ventana = New-AppWindow
        Show-View -Name 'Show-SettingsView'
        Assert-Equal 'Show-SettingsView' (Get-CurrentViewName)
    }

    It 'repintar la pantalla actual no lanza' {
        $ventana = New-AppWindow
        Show-View -Name 'Show-OptimizationsListView'
        Assert-NoThrow { Show-CurrentView }
        Sync-Dispatcher
    }

    It 'cambiar de idioma repinta y deja la interfaz en pie' {
        $ventana = New-AppWindow -Language 'en'
        Build-Sidebar -Window $ventana
        Show-View -Name 'Show-OptimizationsListView'

        Set-AppLanguage 'es'
        Update-UiLanguage
        Sync-Dispatcher 'Background'
        Sync-Dispatcher

        Assert-Equal 'Ajustes' ([string]$ventana.FindName('NavSettings').Content.Children[1].Text)
        Assert-NotNull $ventana.FindName('MainContent').Content

        Set-AppLanguage 'en'
    }
}
