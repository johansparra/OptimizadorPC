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

# Pulsa un botón del menú lateral por su evento Click, que es lo que
# dispara al manejador de verdad -llamar a Set-NavSelection a mano se
# saltaría justamente el cableado que se quiere probar-.
function Push-NavButton {
    param($Window, [string]$Id)

    $boton = $Window.FindName((Get-NavElementName $Id))
    $boton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
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

    It 'una entrada con pantalla navega y se marca' {
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana

        Push-NavButton $ventana 'settings'

        Assert-Equal 'Show-SettingsView' (Get-CurrentViewName)
        Assert-Equal 'sel' ([string]$ventana.FindName('NavSettings').Tag)
    }

    It 'una entrada sin pantalla no navega ni mueve la selección' {
        # Las secciones sin implementar siguen en el menú para que se
        # vea la estructura, pero pulsarlas no puede llevar a ningún
        # sitio: ni a una vista vacía ni de vuelta a la lista. El
        # usuario se queda mirando exactamente lo mismo.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Push-NavButton $ventana 'settings'

        $antesVista     = Get-CurrentViewName
        $antesContenido = $ventana.FindName('MainContent').Content

        foreach ($nav in Get-NavigationItems) {
            if ($nav.View) { continue }

            $boton = $ventana.FindName((Get-NavElementName $nav.Id))
            Assert-True $boton.IsEnabled "'$($nav.Id)' tiene que seguir habilitado a la vista"
            Assert-NoThrow { Push-NavButton $ventana $nav.Id } "pulsar '$($nav.Id)'"

            Assert-Equal $antesVista (Get-CurrentViewName) "'$($nav.Id)' ha navegado"
            Assert-True ([object]::ReferenceEquals($antesContenido, $ventana.FindName('MainContent').Content)) "'$($nav.Id)' ha repintado la pantalla"
            Assert-Null $boton.Tag "'$($nav.Id)' se ha quedado marcado en el menú"
            Assert-Equal 'sel' ([string]$ventana.FindName('NavSettings').Tag) "'$($nav.Id)' ha desmarcado la sección en la que estabas"
        }
    }

    It 'la entrada Buscar abre la pantalla de búsqueda que ya existía' {
        # No una copia: la MISMA función de vista que usa la caja de
        # la cabecera. Si algún día se duplicara, esto lo caza.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Set-SearchQuery ''

        Push-NavButton $ventana 'search'

        Assert-Equal 'Show-SearchResultsView' (Get-CurrentViewName)
        Assert-Equal 'sel' ([string]$ventana.FindName('NavSearch').Tag)
        Assert-NotNull $ventana.FindName('MainContent').Content
    }

    It 'llegar a una pantalla sin pulsar su botón también lo marca' {
        # A la búsqueda se entra con Enter desde la caja de la
        # cabecera. Sin sincronizar, el menú marcaría una cosa y la
        # pantalla enseñaría otra.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Push-NavButton $ventana 'optimize'

        Set-SearchQuery ''
        Show-View -Name 'Show-SearchResultsView'

        Assert-Equal 'sel' ([string]$ventana.FindName('NavSearch').Tag) 'el menú no ha seguido a la pantalla'
        Assert-Null $ventana.FindName('NavOptimize').Tag 'han quedado dos entradas marcadas'
    }

    It 'bajar a una pantalla que no está en el menú no desmarca nada' {
        # El detalle de una sección no tiene botón propio: se sigue
        # marcando aquella desde la que se entró.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Push-NavButton $ventana 'optimize'

        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }

        Assert-Equal 'sel' ([string]$ventana.FindName('NavOptimize').Tag) 'entrar en una sección ha desmarcado Optimizar'
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

        $conPantalla = 0
        foreach ($nav in Get-NavigationItems) {
            # Una entrada sin View es una sección todavía sin pantalla.
            if (-not $nav.View) { continue }

            $conPantalla++
            Assert-NoThrow { Show-View -Name $nav.View } "la vista de '$($nav.Id)'"
            Assert-NotNull $ventana.FindName('MainContent').Content "'$($nav.View)' no ha dejado nada en pantalla"
        }
        Assert-True ($conPantalla -gt 0) 'ninguna entrada del menú lleva a una pantalla'
    }

    It 'una vista que no existe se queja con nombre y apellidos' {
        Assert-Throws { Show-View -Name 'Show-EstaVistaNoExiste' }
    }

    It 'las tarjetas de la lista se elevan dentro de un envoltorio quieto' {
        # El efecto de elevación mueve la tarjeta, y en WPF el
        # RenderTransform mueve con ella su zona sensible al ratón. Si
        # quien escuchara fuese la propia tarjeta, con el cursor parado
        # sobre sus últimos píxeles la animación no pararía nunca:
        # sube -> MouseLeave -> baja -> MouseEnter -> sube...
        $ventana = New-AppWindow
        Show-View -Name 'Show-OptimizationsListView'
        $lista = $ventana.FindName('MainContent').Content

        Assert-Equal @(Get-OptimizationCategories).Count $lista.Children.Count

        foreach ($envoltorio in $lista.Children) {
            $tarjeta = $envoltorio.Children[0]

            Assert-NotNull $envoltorio.Background 'el envoltorio tiene que oír al ratón en todo su hueco'
            Assert-True $envoltorio.RenderTransform.Value.IsIdentity 'el envoltorio no se mueve; la que se mueve es la tarjeta'
            Assert-True ($tarjeta.RenderTransform -is [System.Windows.Media.TranslateTransform]) 'la tarjeta es la que sube y baja'

            # El hueco entre tarjetas queda FUERA del envoltorio, o se
            # iluminaría y se podría pulsar el aire entre dos secciones.
            Assert-Equal 0 $tarjeta.Margin.Bottom 'el margen se muda al envoltorio'
            Assert-True ($envoltorio.Margin.Bottom -gt 0) 'el envoltorio se queda el margen de la tarjeta'

            # Y el clic va en el mismo sitio que la escucha.
            Assert-NotNull $envoltorio.Tag 'la categoría viaja en el Tag del envoltorio'
            Assert-Equal 'Hand' ([string]$envoltorio.Cursor)
        }
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

    It 'la tarjeta enseña el estado real, no las etiquetas declaradas' {
        # Lo que el usuario acaba leyendo: "Optimizado", "Recomendado
        # de fábrica" o "Personalizado" según lo que haya AHORA en el
        # registro de este equipo. Como el resultado depende de la
        # máquina, se comprueba contra lo que ha decidido core/: cada
        # estado que tenga algún ajuste sale, y ningún otro. La sección
        # tiene varios ajustes y pueden estar en estados distintos, así
        # que se mira el CONJUNTO, no ajuste por ajuste.
        $ventana = New-AppWindow
        $cat = Get-CategoryById 'regedit'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        $texto = Get-VisualText $ventana.FindName('MainContent').Content

        $presentes = @{}
        foreach ($ajuste in @($cat.Items)) {
            Assert-NotNull $ajuste.Status "el ajuste '$($ajuste.Name)' tendría que traer estado"
            $presentes[$ajuste.Status] = $true
        }

        foreach ($estado in Get-SettingStatusNames) {
            $etiqueta = [regex]::Escape((T (Get-StatusStyle $estado).Label))
            if ($presentes.ContainsKey($estado)) {
                Assert-Match $etiqueta $texto "falta la etiqueta de '$estado'"
            }
            else {
                Assert-False ($texto -match $etiqueta) "no debería salir la etiqueta de '$estado'"
            }
        }
    }

    It 'el resumen de la cabecera cuenta por estado real' {
        $ventana = New-AppWindow
        $cat = Get-CategoryById 'regedit'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        $cuentas = Get-CategoryStatusCounts $cat
        Assert-NotNull $cuentas 'Regedit lee el registro: tiene que contar por estado'
        Assert-Equal @($cat.Items).Count $cuentas.Total

        # Cada ajuste cae en un estado y en uno solo, así que la suma
        # de los cuatro es el total. Con las etiquetas declaradas esto
        # no se cumplía: el mismo ajuste salía en las tres píldoras.
        $suma = 0
        foreach ($estado in Get-SettingStatusNames) { $suma += [int]$cuentas.$estado }
        Assert-Equal $cuentas.Total $suma

        $fila = $ventana.FindName('HeaderSummaryArea').Children[0]
        $texto = Get-VisualText $fila
        foreach ($estado in Get-SettingStatusNames) {
            $n = [int]$cuentas.$estado
            if ($estado -eq 'unknown' -and $n -eq 0) { continue }

            Assert-Match ([regex]::Escape((T (Get-StatusStyle $estado).Label))) $texto
            Assert-Match ([regex]::Escape("$n/$($cuentas.Total)")) $texto "el recuento de '$estado'"
        }
    }

    It 'una sección que no lee el registro sigue con sus etiquetas' {
        # El resto del programa no se mueve: sin claves declaradas no
        # hay estado que calcular, y la fila cuenta por etiquetas.
        $ventana = New-AppWindow
        $cat = Get-OptimizationCategories | Where-Object { (Get-CategoryRegistryKeyCount $_) -eq 0 } | Select-Object -First 1
        if (-not $cat) { Skip-Test 'todas las secciones leen ya el registro' }

        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        Assert-Null (Get-CategoryStatusCounts $cat)
        Assert-Match 'Recommended' (Get-VisualText $ventana.FindName('HeaderSummaryArea').Children[0])
    }

    It 'la barra de progreso se recoge al terminar de leer' {
        $ventana = New-AppWindow
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }

        Assert-Equal 'Collapsed' ([string]$ventana.FindName('ProgressStrip').Visibility)
        Assert-True $ventana.Content.IsHitTestVisible 'la ventana tiene que volver a oír al ratón'
    }
}

Describe 'ui/Views/CategoryDetailView.ps1 - refrescar' {

    It 'toda sección trae el botón, apagado si no hay nada que leer' {
        $ventana = New-AppWindow

        foreach ($cat in Get-OptimizationCategories) {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

            $boton = $ventana.FindName('BtnRefresh')
            Assert-NotNull $boton "la sección '$($cat.Id)' no ha puesto el botón"

            # Leer no cambia nada, así que el bloqueo de la sección
            # no lo apaga: lo apaga no tener claves declaradas.
            $hayClaves = (Get-CategoryRegistryKeyCount $cat) -gt 0
            Assert-Equal $hayClaves $boton.IsEnabled "en la sección '$($cat.Id)'"
        }
    }

    It 'pulsarlo vuelve a leer el registro entero y lo dice' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-CategoryById 'regedit'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        # Desde cero para poder contar exactamente lo que deja la
        # segunda lectura, sin lo que hayan apuntado las de arriba.
        Clear-AppLog
        $boton = $ventana.FindName('BtnRefresh')
        $boton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))

        # El repintado se aplaza al Dispatcher, como el cambio de
        # idioma: sin bombear la cola no ha pasado nada todavía.
        Sync-Dispatcher 'Background'

        # Un [read] y un [checked] por clave, más la cabecera del bloque y su resumen.
        $esperadas = (Get-CategoryRegistryKeyCount $cat) * 2 + 2
        Assert-Equal $esperadas (Get-AppLogCount) 'la segunda lectura no ha leído todas las claves'

        $texto = Get-VisualText $ventana.FindName('HeaderActionsArea')
        Assert-Match 'Registry values updated' $texto 'no se avisa de que ya se ha refrescado'
        Assert-Match 'Updated \d\d:\d\d:\d\d' $texto 'falta la hora de la última lectura'

        Assert-Equal 'Collapsed' ([string]$ventana.FindName('ProgressStrip').Visibility)
        Assert-True $ventana.Content.IsHitTestVisible 'la ventana tiene que volver a oír al ratón'
    }
}

Describe 'ui/Engine/Router.ps1' {

    It 'recuerda la pantalla en la que estás' {
        $null = New-AppWindow
        Show-View -Name 'Show-SettingsView'
        Assert-Equal 'Show-SettingsView' (Get-CurrentViewName)
    }

    It 'repintar la pantalla actual no lanza' {
        $null = New-AppWindow
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

    It 'no se navega mientras se está navegando' {
        # Leer el registro cede el hilo (Update-UiNow) y en esa pausa
        # WPF entrega los clics pendientes. Un clic en el desplegable
        # del buscador -que es una ventana aparte y no se entera del
        # blindaje de la vista- entraba aquí otra vez con la pantalla
        # anterior a medio construir.
        $null = New-AppWindow -Language 'en'
        Show-View -Name 'Show-OptimizationsListView'

        # Una vista de mentira que intenta navegar mientras la pintan.
        function Show-ViewReentrante {
            param($Window)
            $script:ReentradaAceptada = $true
            Show-View -Name 'Show-SettingsView'
        }

        $script:ReentradaAceptada = $false
        Show-View -Name 'Show-ViewReentrante'

        Assert-True $script:ReentradaAceptada 'la vista de prueba no llegó a ejecutarse'
        Assert-Equal 'Show-ViewReentrante' (Get-CurrentViewName) 'la navegación reentrante debería descartarse'
        Assert-False (Get-ViewBusy) 'la marca tiene que soltarse al terminar'

        Show-View -Name 'Show-OptimizationsListView'
    }

    It 'la marca se suelta aunque la vista lance' {
        # Sin el finally, un fallo dentro de una vista dejaría la
        # navegación congelada para el resto de la sesión.
        function Show-ViewQueLanza { param($Window) throw 'fallo de prueba' }

        try { Show-View -Name 'Show-ViewQueLanza' } catch { $null = $_ }

        Assert-False (Get-ViewBusy) 'la marca se quedó puesta'
        Assert-NoThrow { Show-View -Name 'Show-OptimizationsListView' } 'ya no se puede navegar'
    }
}

Describe 'ui/Engine/UiGuard.ps1 - la red de seguridad' {

    It 'se engancha una sola vez por ventana' {
        $ventana = New-AppWindow
        Assert-True  (Register-UiErrorGuard -Window $ventana) 'la primera vez debería enganchar'
        Assert-False (Register-UiErrorGuard -Window $ventana) 'la segunda no, o el fallo se apuntaría dos veces'
    }

    It 'sin ventana no lanza' {
        Assert-False (Register-UiErrorGuard -Window $null)
    }

    It 'un fallo tragado queda apuntado en el registro de actividad' {
        Clear-AppLog
        Reset-UiGuardCount

        Write-UiGuardLog (New-Object System.InvalidOperationException 'Glifo desconocido: ')

        Assert-Equal 1 (Get-UiGuardCount)
        $ultima = @(Get-AppLog)[-1]
        Assert-Equal 'error' ([string]$ultima.Level)
        Assert-Match 'Glifo desconocido' ([string]$ultima.Message)
    }

    It 'una excepción sin mensaje ni traza tampoco lo rompe' {
        Clear-AppLog
        Assert-NoThrow { Write-UiGuardLog $null }
        Assert-Equal 1 (Get-AppLogCount) 'debería apuntar algo igualmente'
    }
}
