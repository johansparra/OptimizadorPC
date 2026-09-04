# ============================================================
# Pruebas de ui/Components/Shell/LogWindow.ps1 — el log sacado a
# su propia ventana.
#
# Aquí NO se enseña ninguna ventana, igual que en el resto de
# tests/Ui: se arma el árbol y se mira. Lo que sí queda fuera de
# lo que se puede comprobar así:
#
#   - Que la ventana sea usable estando la principal en
#     ShowDialog. Depende de que Owner esté puesto, y Owner solo
#     admite una ventana ya mostrada, cosa que aquí no pasa.
#   - Arrastrarla, redimensionarla desde el borde y el aspecto.
#
# Lo primero se comprobó a mano con una sonda aparte; lo segundo
# hay que mirarlo. Lo que sí caza Ui/Wiring.Tests.ps1 es que los
# botones de sacar y acoplar respondan al pulsarlos de verdad.
# ============================================================

Describe 'ui/Components/Shell/LogWindow.ps1 - estado' {

    It 'arranca acoplado' {
        Assert-False (Get-LogDetached) 'no debería haber ventana suelta al empezar'
        Assert-False (Get-LogFloating) 'ni preferencia de sacarlo'
    }

    It 'el alojamiento por defecto es la ventana principal' {
        $ventana = New-AppWindow
        Assert-Equal $ventana (Get-LogHostWindow)
    }

    It 'acoplar sin ventana suelta no lanza y deja el cajón abierto' {
        # El caso del botón pulsado dos veces seguidas: la segunda
        # llega cuando ya no hay nada que acoplar.
        $ventana = New-AppWindow
        New-TestLogEntries 2

        Assert-NoThrow { Join-LogPanel }
        Assert-True (Get-LogPanelOpen)
        Assert-False (Get-LogFloating)

        Hide-LogPanel $ventana
    }
}

Describe 'ui/Components/Shell/LogWindow.ps1 - la cabecera cambia de botones' {

    It 'acoplado trae sacar y cerrar' {
        $ventana = New-AppWindow
        New-LogContent $ventana | Out-Null

        Assert-NotNull $ventana.FindName('LogBtnPopOut') 'falta el botón de sacar'
        Assert-NotNull $ventana.FindName('LogBtnClose')  'falta el de cerrar'
    }

    It 'flotante trae acoplar, minimizar, maximizar y cerrar' {
        $ventana = New-AppWindow
        New-LogContent $ventana -Floating | Out-Null

        foreach ($nombre in @('LogBtnDock', 'LogBtnMinimize', 'LogBtnMaximize', 'LogBtnClose')) {
            Assert-NotNull $ventana.FindName($nombre) "falta '$nombre' en la cabecera flotante"
        }
    }

    It 'es el mismo contenido en los dos sitios: cuatro filas' {
        # Cabecera, barra de botones, lista y pie. Si alguna vez se
        # separan las dos construcciones, esto se entera.
        $ventana = New-AppWindow

        $acoplado = New-LogContent $ventana
        $flotante = New-LogContent $ventana -Floating

        Assert-Equal 4 $acoplado.RowDefinitions.Count
        Assert-Equal 4 $flotante.RowDefinitions.Count
        Assert-Equal $acoplado.Children.Count $flotante.Children.Count
    }
}

Describe 'ui/Components/Shell/LogWindow.ps1 - la ventana' {

    It 'se construye sin cromo de Windows y redimensionable' {
        $ventana = New-AppWindow
        $suelta = New-LogWindow $ventana

        Assert-Equal 'None'      ([string]$suelta.WindowStyle)
        Assert-Equal 'CanResize' ([string]$suelta.ResizeMode)
        Assert-True  ($suelta.MinWidth -gt 0)  'sin ancho mínimo se puede encoger hasta desaparecer'
        Assert-True  ($suelta.MinHeight -gt 0) 'ni alto mínimo'
    }

    It 'hereda los pinceles del tema de la principal' {
        # Sin esto, cada DynamicResource de dentro se quedaría sin
        # resolver y la ventana saldría en blanco y negro.
        $ventana = New-AppWindow -Theme 'Dark'
        $suelta = New-LogWindow $ventana

        Assert-NotNull ($suelta.TryFindResource('Accent'))     'no llega la paleta'
        Assert-NotNull ($suelta.TryFindResource('DisplayFont')) 'ni la tipografía'
    }

    It 'trae dentro las filas del registro' {
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog
        Write-AppLog -Source 'registry' -Level 'info' -Status 'read' `
                     -Message 'HKEY_LOCAL_MACHINE\SOFTWARE\Prueba\MiValor' -Detail '5 - DWord'

        $suelta = New-LogWindow $ventana
        Update-LogList $suelta

        $texto = Get-VisualText $suelta.Content
        Assert-Match 'Activity log' $texto 'debería llevar su propia cabecera'
        Assert-Match 'MiValor'      $texto 'y las filas'
    }

    It 'maximizar y restaurar alternan' {
        $ventana = New-AppWindow
        $suelta = New-LogWindow $ventana

        Switch-LogWindowState $suelta
        Assert-Equal 'Maximized' ([string]$suelta.WindowState)
        Switch-LogWindowState $suelta
        Assert-Equal 'Normal' ([string]$suelta.WindowState)
    }

    It 'el cambio de tema alcanza a la ventana suelta' {
        # Comparten el diccionario de recursos, así que Set-AppTheme
        # sobre la principal tiene que repintar también esta. Es la
        # regla 10: los pinceles congelados se SUSTITUYEN, y si la
        # sustitución no llegara hasta aquí la ventana se quedaría
        # con la paleta anterior.
        $ventana = New-AppWindow -Theme 'Light'
        $suelta = New-LogWindow $ventana

        $claro = [string]$suelta.TryFindResource('Bg1')
        Set-AppTheme -Window $ventana -Name 'Dark'
        $oscuro = [string]$suelta.TryFindResource('Bg1')

        Assert-NotEqual $claro $oscuro 'la ventana suelta se ha quedado con el tema viejo'

        Set-AppTheme -Window $ventana -Name 'Light'
    }

    It 'al cerrarse deja el estado limpio' {
        # Si no, el botón de la barra de título intentaría enfocar
        # una ventana muerta la próxima vez.
        Clear-LogWindowState
        Assert-False (Get-LogDetached)
        Assert-Null  (Get-LogWindow)
    }
}
