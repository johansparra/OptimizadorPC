# ============================================================
# Pruebas de ui/Components/Cards/SettingCard.ps1 — la "Descripción".
#
# La descripción de la tarjeta es SOLO el "Qué hace": el texto de
# -WhatItDoes si el ajuste lo declara, y si no la -Description de
# siempre. Los valores, el gaming y el enlace NO van aquí: viven
# en la franja plegable "Referencia" (opt-in desde el menú Vista,
# ver SettingReference.Tests.ps1).
# ============================================================

$CardWindow = New-AppWindow

# Un ajuste con clave de registro y todos los campos de referencia.
function New-DescSetting {
    param([string]$WhatItDoes)
    New-Setting -Name 'Ajuste de prueba' -Description 'Descripción de una línea' `
        -WhatItDoes $WhatItDoes `
        -Values 'un rango de valores' -GamingOptimal 'yes' -GamingNote 'nota de gaming' `
        -Link 'https://example.com/docs' -Value $true `
        -Registry @(
            @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test'; Name = 'V'; Type = 'DWord'
               Recommended = '1'; Default = '0' }
        )
}

Describe 'ui/Components/Cards/SettingCard.ps1 - la descripción es el "Qué hace"' {

    It 'usa -WhatItDoes cuando el ajuste lo declara' {
        $texto = Get-VisualText (New-SettingCard $CardWindow (New-DescSetting -WhatItDoes 'Explicacion funcional resumida'))

        Assert-Match 'Explicacion funcional resumida' $texto
        Assert-False ($texto -match 'Descripción de una línea') 'con -WhatItDoes no se enseña la -Description'
    }

    It 'cae en -Description si el ajuste no declara -WhatItDoes' {
        $ajuste = New-Setting -Name 'Sin WhatItDoes' -Description 'Esto es lo que hace la clave' -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test'; Name = 'V'; Type = 'DWord'
                   Recommended = '1'; Default = '0' }
            )

        Assert-Match 'Esto es lo que hace la clave' (Get-VisualText (New-SettingCard $CardWindow $ajuste))
    }

    It 'los datos de referencia NO salen en la descripción (van en su franja)' {
        # "Referencia" está oculta por defecto: valores, gaming y
        # enlace no aparecen hasta que se activa la opción de Vista.
        $texto = Get-VisualText (New-SettingCard $CardWindow (New-DescSetting -WhatItDoes 'qué hace'))

        foreach ($fuera in @('Values', 'Good for gaming', 'un rango de valores',
                             'nota de gaming', 'https://example.com/docs')) {
            Assert-False ($texto -match [regex]::Escape($fuera)) "'$fuera' no debería salir con Referencia apagada"
        }
    }
}

Describe 'ui/Components/Cards/SettingCard.ps1 - el toggle refleja el estado real' {

    # El interruptor de la columna derecha: Border cuyo Tag lleva
    # el Payload (el ajuste), lo pone New-ToggleSwitch.
    function Get-CardToggle {
        param($Card)
        (Find-Visuals $Card {
            param($el)
            $el -is [System.Windows.Controls.Border] -and
            $el.Tag -and $el.Tag.PSObject.Properties['Payload']
        })[0]
    }

    function New-RegSetting {
        param([string]$Status)
        $s = New-Setting -Name 'Con clave' -Description 'x' -Value $true -Registry @(
            @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test'; Name = 'V'; Type = 'DWord'
               Recommended = '1'; Default = '0' }
        )
        $s.Status = $Status
        $s
    }

    It 'con clave: ON solo si el estado real es optimizado' {
        Assert-True  (Get-CardToggle (New-SettingCard $CardWindow (New-RegSetting 'optimized'))).Tag.State
        Assert-False (Get-CardToggle (New-SettingCard $CardWindow (New-RegSetting 'factory'))).Tag.State
        Assert-False (Get-CardToggle (New-SettingCard $CardWindow (New-RegSetting 'custom'))).Tag.State
        Assert-False (Get-CardToggle (New-SettingCard $CardWindow (New-RegSetting 'unknown'))).Tag.State
    }

    It 'sin clave: la posición sale del -Value declarado, como siempre' {
        $on  = New-Setting -Name 'A' -Description 'x' -Value $true
        $off = New-Setting -Name 'B' -Description 'x' -Value $false
        Assert-True  (Get-CardToggle (New-SettingCard $CardWindow $on)).Tag.State
        Assert-False (Get-CardToggle (New-SettingCard $CardWindow $off)).Tag.State
    }

    It 'el ajuste viaja en el Tag del toggle' {
        $s = New-RegSetting 'factory'
        Assert-Equal $s (Get-CardToggle (New-SettingCard $CardWindow $s)).Tag.Payload
    }

    It 'pulsar el toggle actualiza SOLO su tarjeta, sin repintar la sección' {
        # La escritura la tiene desarmada el arnés: Set-SettingOptimization
        # no toca el registro, pero Update-SettingCard sí reemplaza la
        # tarjeta en el sitio. Se pulsa la primera tarjeta y se comprueba
        # con Toast y con que la LISTA no se recrea (mismo Count, mismo
        # objeto Content).
        $ventana = New-AppWindow
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }

        $contenido = $ventana.FindName('MainContent').Content
        $lista = $contenido
        $tarjetaVieja = $lista.Children[0]
        $nCards = $lista.Children.Count

        $toggle = Get-CardToggle $tarjetaVieja
        Assert-NotNull $toggle

        $clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
        $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
        Assert-NoThrow { $toggle.RaiseEvent($clic) }

        # MainContent.Content NO ha cambiado -> el ScrollViewer conserva
        # su posición (no se ha hecho Content = new).
        Assert-Equal $contenido $ventana.FindName('MainContent').Content 'la sección se ha recreado entera'
        # La misma StackPanel, con el mismo número de tarjetas.
        Assert-Equal $lista $ventana.FindName('MainContent').Content
        Assert-Equal $nCards $lista.Children.Count

        # Pero la tarjeta afectada SÍ es nueva (estado real releído).
        Assert-NotEqual $tarjetaVieja $lista.Children[0] 'la tarjeta no se ha actualizado'
    }

    It 'con varias tarjetas, tocar una no toca a las demás' {
        # Sección de mentira con 3 ajustes con clave, contra la rama
        # HKCU de pruebas (armada solo aquí).
        New-TestRegFixture
        Set-RegistryWriteArmed $true
        try {
            $cat = [PSCustomObject]@{
                Id = 'multi'; Name = 'Multi'; Icon = 'Shield'
                Items = @(
                    (New-Setting -Name 'Uno' -Description 'x' -Value $true -Registry @((New-TestKey 'M1' -Recommended '1' -Default '0'))),
                    (New-Setting -Name 'Dos' -Description 'x' -Value $true -Registry @((New-TestKey 'M2' -Recommended '1' -Default '0'))),
                    (New-Setting -Name 'Tres' -Description 'x' -Value $true -Registry @((New-TestKey 'M3' -Recommended '1' -Default '0')))
                )
            }
            $ventana = New-AppWindow
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
            $lista = $ventana.FindName('MainContent').Content

            $c0 = $lista.Children[0]; $c1 = $lista.Children[1]; $c2 = $lista.Children[2]
            $toggle1 = Get-CardToggle $c1

            $clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
            $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
            $toggle1.RaiseEvent($clic)

            Assert-Equal    $c0 $lista.Children[0] 'la tarjeta de arriba no debía tocarse'
            Assert-NotEqual $c1 $lista.Children[1] 'la tarjeta pulsada sí se actualiza'
            Assert-Equal    $c2 $lista.Children[2] 'la tarjeta de abajo no debía tocarse'
            Assert-Equal 3 $lista.Children.Count
        }
        finally {
            Set-RegistryWriteArmed $false
            Remove-TestRegFixture
        }
    }
}

Describe 'ui/Components/Cards/SettingCard.ps1 - las tarjetas normales no cambian' {

    It 'un ajuste sin -Registry sigue con su descripción de una línea' {
        $ajuste = New-Setting -Name 'Toggle normal' -Description 'Una sola línea de descripción' `
            -Tags 'Recommended' -Value $true

        Assert-Match 'Una sola línea de descripción' (Get-VisualText (New-SettingCard $CardWindow $ajuste))
    }

    It 'un ajuste sin -Registry no recibe "Referencia" ni con la opción encendida' {
        Set-ViewOption 'reference' $true
        try {
            $ajuste = New-Setting -Name 'Toggle' -Description 'x' -WhatItDoes 'y' `
                -Values 'z' -GamingOptimal 'yes' -Value $true

            Assert-False ((Get-VisualText (New-SettingCard $CardWindow $ajuste)) -match 'Good for gaming') `
                'sin -Registry no hay franja Referencia'
        }
        finally { Set-ViewOption 'reference' $false }
    }
}
