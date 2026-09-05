# ============================================================
# Pruebas de la capa visual: degradados, fondo vivo, entrada en
# cascada, indicadores deslizantes, cuadrícula y material.
#
# Igual que el resto de tests/Ui, aquí NO se enseña ninguna
# ventana: se arma el árbol de controles y se mira.
#
# LO QUE ESTO NO PUEDE COMPROBAR, y hay que mirar a ojo:
#
#   - Que un degradado quede bonito. Aquí solo se comprueba que
#     esté puesto y que salga de colores que existen.
#   - Que las animaciones se vean bien. Sin ventana abierta el
#     reloj de WPF no avanza, así que lo que se comprueba es que
#     la animación quede COLGADA de la propiedad correcta, no
#     cómo se ve. Ese es justo el fallo que se cuela: animar el
#     envoltorio en vez de la tarjeta (ver la regla 21).
#   - Mica y Acrílico. Necesitan una ventana con descriptor y un
#     Windows 11 22H2; aquí se comprueba que sin nada de eso la
#     aplicación se quede exactamente como estaba.
# ============================================================

Describe 'tests/Harness/AppHost.ps1 - las pruebas no tocan tus ajustes' {

    It 'las preferencias se guardan en un archivo temporal, no en el tuyo' {
        # Varias pruebas de aquí cambian opciones de vista, y sin
        # esto reescribirían %APPDATA%\OptimizadorPC\settings.json
        # entero: la tabla arranca vacía porque nadie llama a
        # Import-AppSettings, así que guardar dejaría SOLO la clave
        # que acaba de tocar la prueba.
        #
        # Ojo con comprobarlo mirando si la ruta lleva 'APPDATA':
        # la carpeta temporal de Windows cuelga de AppData\Local, así
        # que eso da positivo siempre. Lo que hay que descartar es el
        # archivo concreto.
        $ruta = Get-AppSettingsPath
        Assert-Equal (Get-TestSettingsPath) $ruta
        Assert-False ($ruta -like '*OptimizadorPC\settings.json')
        Assert-Match ([regex]::Escape([string]$PID)) $ruta
    }
}

Describe 'ui/Design/Theme.ps1 - degradados' {

    It 'el tema publica un pincel por cada token de degradado' {
        $ventana = New-AppWindow

        foreach ($clave in $GradientTokens.Keys) {
            $pincel = $ventana.Resources[$clave]
            Assert-NotNull $pincel "falta el degradado '$clave'"
            Assert-True ($pincel -is [System.Windows.Media.GradientBrush]) "'$clave' no es un degradado"
        }
    }

    It 'las manchas del fondo se desvanecen hasta transparente' {
        # Si la parada exterior no llevara alfa 0 se vería el borde
        # de la elipse, y la mancha dejaría de ser una mancha.
        $ventana = New-AppWindow

        foreach ($clave in 'Glow1Brush', 'Glow2Brush', 'Glow3Brush') {
            $pincel = $ventana.Resources[$clave]
            Assert-True ($pincel -is [System.Windows.Media.RadialGradientBrush]) "'$clave' tiene que ser radial"
            Assert-Equal 0 $pincel.GradientStops[1].Color.A "'$clave' no acaba en transparente"
        }
    }

    It 'cambiar de tema repinta también los degradados' {
        $ventana = New-AppWindow -Theme 'Light'
        $claro = $ventana.Resources['AccentGradient'].GradientStops[0].Color

        Set-AppTheme -Window $ventana -Name 'Dark'
        $oscuro = $ventana.Resources['AccentGradient'].GradientStops[0].Color

        Assert-NotEqual $claro $oscuro 'el degradado se ha quedado con el color del tema anterior'
    }

    It 'un color con degradado devuelve el suyo, y uno sin él se queda igual' {
        Assert-Equal 'WarnGradient'     (Get-GradientKey 'Warn')
        Assert-Equal 'WarnSoftGradient' (Get-GradientKey 'WarnSoft')
        Assert-Equal 'TextMuted'        (Get-GradientKey 'TextMuted')
    }

    It 'Get-ThemeKeys trae las dos familias' {
        $claves = Get-ThemeKeys
        Assert-Contains 'Accent'         $claves
        Assert-Contains 'AccentGradient' $claves
    }
}

Describe 'ui/Design/Theme.ps1 - entrada en cascada' {

    It 'cada hijo entra con su propio retardo' {
        $panel = New-Object System.Windows.Controls.StackPanel
        foreach ($i in 1..4) {
            $panel.Children.Add((New-Object System.Windows.Controls.Border)) | Out-Null
        }

        Start-StaggeredEnter $panel -StepMs 50

        # Sin reloj corriendo, la opacidad se queda en el valor de
        # partida: eso es exactamente lo que hace que las tarjetas
        # esperen su turno invisibles en vez de aparecer y moverse.
        foreach ($hijo in $panel.Children) {
            Assert-Equal 0 $hijo.Opacity 'el hijo tendría que arrancar invisible'
            Assert-True ($hijo.RenderTransform -is [System.Windows.Media.TranslateTransform]) 'le falta el desplazamiento'
        }
    }

    It 'en una tarjeta con elevación se mueve la de dentro, no el envoltorio' {
        # Es la regla 21: mover el envoltorio movería su zona
        # sensible al ratón y el efecto de elevación entraría en
        # bucle. Get-EnterTarget existe para esto.
        $tarjeta = New-Object System.Windows.Controls.Border
        $tarjeta.Margin = New-Object System.Windows.Thickness 0, 0, 0, 10
        $envoltorio = Add-HoverLift $tarjeta

        $panel = New-Object System.Windows.Controls.StackPanel
        $panel.Children.Add($envoltorio) | Out-Null

        Start-StaggeredEnter $panel

        Assert-True $envoltorio.RenderTransform.Value.IsIdentity 'el envoltorio no puede moverse'
        Assert-Equal $tarjeta (Get-EnterTarget $envoltorio) 'la que se mueve es la tarjeta'
    }

    It 'el halo de una tarjeta guarda su clave de color, no el color' {
        # Resolverlo al crear la tarjeta dejaría el halo del tema
        # anterior al alternar claro/oscuro.
        $tarjeta = New-Object System.Windows.Controls.Border
        Add-HoverLift $tarjeta -Glow 'Warn' | Out-Null
        Assert-Equal 'Warn' $tarjeta.Tag
    }

    It 'sin ventana, teñir el halo no lanza' {
        $tarjeta = New-Object System.Windows.Controls.Border
        Add-HoverLift $tarjeta -Glow 'Warn' | Out-Null
        Assert-NoThrow { Set-GlowColor $tarjeta }
    }
}

Describe 'ui/Components/Shell/Backdrop.ps1' {

    It 'pinta una mancha por cada una declarada' {
        $ventana = New-AppWindow
        Build-Backdrop -Window $ventana

        $lienzo = $ventana.FindName('Backdrop')
        Assert-Equal $BackdropBlobs.Count $lienzo.Children.Count
    }

    It 'cada mancha lleva su pincel del tema y su vaivén' {
        $ventana = New-AppWindow
        Build-Backdrop -Window $ventana

        foreach ($elipse in $ventana.FindName('Backdrop').Children) {
            Assert-True ($elipse -is [System.Windows.Shapes.Ellipse]) 'las manchas son elipses'
            Assert-True ($elipse.Fill -is [System.Windows.Media.RadialGradientBrush]) 'sin degradado radial no se difumina'
            Assert-True ($elipse.RenderTransform -is [System.Windows.Media.TranslateTransform]) 'le falta el vaivén'
            Assert-False $elipse.IsHitTestVisible 'el fondo no puede comerse los clics'
        }
    }

    It 'sin medidas no se coloca nada, y no lanza' {
        # Al arrancar, main.ps1 pinta antes de que la ventana exista
        # de verdad: el lienzo mide cero y aquí no hay nada que hacer.
        $ventana = New-AppWindow
        Build-Backdrop -Window $ventana
        Assert-NoThrow { Set-BackdropLayout $ventana.FindName('Backdrop') }
    }

    It 'construirlo dos veces no duplica las manchas' {
        $ventana = New-AppWindow
        Build-Backdrop -Window $ventana
        Build-Backdrop -Window $ventana

        Assert-Equal $BackdropBlobs.Count $ventana.FindName('Backdrop').Children.Count
    }
}

Describe 'ui/Views/OptimizationsListView.ps1 - lista y cuadrícula' {

    It 'sin la opción marcada sigue saliendo la lista de siempre' {
        Set-ViewOption 'grid' $false
        $ventana = New-AppWindow
        Show-View -Name 'Show-OptimizationsListView'

        $cuerpo = $ventana.FindName('MainContent').Content
        Assert-True ($cuerpo -is [System.Windows.Controls.StackPanel]) 'la lista es un StackPanel'
        Assert-Equal @(Get-OptimizationCategories).Count $cuerpo.Children.Count
    }

    It 'con la opción marcada salen baldosas en un WrapPanel' {
        Set-ViewOption 'grid' $true
        try {
            $ventana = New-AppWindow
            Show-View -Name 'Show-OptimizationsListView'

            $cuerpo = $ventana.FindName('MainContent').Content
            Assert-True ($cuerpo -is [System.Windows.Controls.WrapPanel]) 'la cuadrícula es un WrapPanel'
            Assert-Equal @(Get-OptimizationCategories).Count $cuerpo.Children.Count

            # Todas del mismo ancho: es lo que deja las filas
            # cuadradas en vez de dentadas.
            foreach ($envoltorio in $cuerpo.Children) {
                Assert-Equal $CategoryTileWidth $envoltorio.Children[0].Width
            }
        }
        finally { Set-ViewOption 'grid' $false }
    }

    It 'la baldosa enseña lo mismo que la fila' {
        Set-ViewOption 'grid' $true
        try {
            $ventana = New-AppWindow
            $categoria = @(Get-OptimizationCategories)[0]
            $baldosa = New-CategoryTile -Window $ventana -Category $categoria

            $texto = Get-VisualText $baldosa
            Assert-Match ([regex]::Escape((T $categoria.Name))) $texto
            Assert-Equal $categoria $baldosa.Tag 'la categoría viaja en el Tag del envoltorio'
            Assert-Equal 'Hand' ([string]$baldosa.Cursor)
        }
        finally { Set-ViewOption 'grid' $false }
    }
}

Describe 'ui/Components/Shell/Sidebar.ps1 - el indicador que se desliza' {

    It 'existe uno solo y arranca escondido' {
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana

        $marca = $ventana.FindName('NavIndicator')
        Assert-NotNull $marca
        # Sin ventana abierta los botones miden cero, así que no hay
        # adónde colocarlo: escondido es la respuesta correcta.
        Assert-Equal 0 $marca.Opacity
    }

    It 'moverlo sin medidas no lanza' {
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Assert-NoThrow { Move-NavIndicator -Window $ventana }
        Assert-NoThrow { Move-NavIndicator -Window $ventana -Animate }
    }

    It 'navegar deja marcada la entrada aunque el indicador no se vea' {
        # El fondo del botón es lo que distingue la entrada mientras
        # el indicador no tiene sitio: sin eso, al arrancar no habría
        # NADA marcado.
        $ventana = New-AppWindow
        Build-Sidebar -Window $ventana
        Show-View -Name 'Show-SettingsView'

        Assert-Equal 'sel' $ventana.FindName('NavSettings').Tag
    }
}

Describe 'ui/Components/Shell/TitleBar.ps1 - la pastilla del modo' {

    It 'existe y arranca escondida' {
        $ventana = New-AppWindow
        Update-TitleBarTexts $ventana

        $pastilla = $ventana.FindName('ModeIndicator')
        Assert-NotNull $pastilla
        Assert-Equal 0 $pastilla.Opacity
    }

    It 'moverla sin medidas no lanza' {
        $ventana = New-AppWindow
        Assert-NoThrow { Move-ModeIndicator -Window $ventana }
        Assert-NoThrow { Move-ModeIndicator -Window $ventana -Animate }
    }

    It 'el modo marcado sigue siendo el del Tag' {
        # La pastilla es adorno: quien manda es el Tag, que es lo que
        # miran main.ps1 y Ui/Wiring.Tests.ps1.
        $ventana = New-AppWindow
        Assert-Equal 'sel' $ventana.FindName('BtnModeNormal').Tag
    }
}

Describe 'ui/Design/UiKit.ps1 - números que cuentan' {

    It 'sin ventana viva escribe el número final' {
        # Es lo que evita que la cifra se quede clavada en cero
        # cuando no hay bucle de mensajes: aquí, y en el .exe
        # mientras la ventana todavía no está.
        $texto = New-Object System.Windows.Controls.TextBlock
        Start-CountUp $null $texto '{0}/112' 65
        Assert-Equal '65/112' $texto.Text
    }

    It 'con una ventana sin abrir, tampoco cuenta' {
        $ventana = New-AppWindow
        $texto = New-Object System.Windows.Controls.TextBlock
        Start-CountUp $ventana $texto '{0}/7' 3
        Assert-Equal '3/7' $texto.Text
    }

    It 'un cero se escribe tal cual, sin poner en marcha nada' {
        $texto = New-Object System.Windows.Controls.TextBlock
        Start-CountUp $null $texto '{0}/9' 0
        Assert-Equal '0/9' $texto.Text
    }
}

Describe 'ui/Components/Shell/WindowMaterial.ps1' {

    It 'de fábrica la ventana es opaca' {
        Assert-Equal 'None' (Get-WindowMaterial)
    }

    It 'un material que no existe se trata como opaco' {
        Set-AppSetting 'Material' 'Cristal de Bohemia'
        try { Assert-Equal 'None' (Get-WindowMaterial) }
        finally { Set-AppSetting 'Material' 'None' }
    }

    It 'sin descriptor de ventana no se toca nada y no lanza' {
        # New-AppWindow no enseña la ventana, así que no tiene
        # descriptor: es el caso de "Windows no lo admite" y la
        # ventana tiene que quedarse exactamente como estaba.
        $ventana = New-AppWindow
        Set-AppSetting 'Material' 'Mica'
        try {
            Assert-NoThrow { Sync-WindowMaterial -Window $ventana }
            $raiz = $ventana.FindName('WindowRoot')
            Assert-Equal $ventana.Resources['BgGradient'] $raiz.Background 'se ha quedado translúcida sin material detrás'
        }
        finally { Set-AppSetting 'Material' 'None' }
    }

    It 'sin ventana no hace nada' {
        Assert-NoThrow { Sync-WindowMaterial -Window $null }
    }

    It 'core/ contesta sin lanzar aunque el descriptor sea cero' {
        Assert-False (Set-WindowBackdrop -Handle ([IntPtr]::Zero) -Kind 'Mica')
        Assert-False (Set-WindowBackdrop -Handle ([IntPtr]::Zero) -Kind 'Ninguno')
    }
}
