# ============================================================
# Pruebas de ui/Components/Shell/LogPanel.ps1 — el cajón del log.
#
# Aquí se comprueban las dos cosas que se pueden comprobar sin
# mirar la pantalla: que abrir y cerrar deje el estado bien -o el
# velo se quedaría comiéndose los clics del contenido de detrás-,
# y que lo apuntado en core/Diagnostics/Log.ps1 acabe convertido en filas.
# ============================================================

Describe 'ui/Components/Shell/LogPanel.ps1 - abrir y cerrar' {

    It 'arranca cerrado' {
        $ventana = New-AppWindow
        Assert-False (Get-LogPanelOpen)
        Assert-Equal 'Collapsed' ([string]$ventana.FindName('LogOverlay').Visibility)
    }

    It 'abrirlo enseña el cajón' {
        $ventana = New-AppWindow
        New-TestLogEntries 3

        Show-LogPanel $ventana
        Assert-True (Get-LogPanelOpen)
        Assert-Equal 'Visible' ([string]$ventana.FindName('LogOverlay').Visibility)
        Assert-NotNull $ventana.FindName('LogDrawer').Child

        Hide-LogPanel $ventana
    }

    It 'cerrarlo lo recoge del todo' {
        # No basta con marcarlo cerrado: mientras el velo esté
        # visible se sigue comiendo los clics de lo que hay debajo.
        #
        # El colapso lo dispara el final de la animación, y las
        # animaciones de WPF solo avanzan con una ventana
        # pintándose. Por eso se llama a Close-LogOverlay a mano:
        # es la misma función que ejecuta el manejador.
        $ventana = New-AppWindow
        New-TestLogEntries 2

        Show-LogPanel $ventana
        Hide-LogPanel $ventana
        Assert-False (Get-LogPanelOpen)

        Close-LogOverlay $ventana
        Assert-Equal 'Collapsed' ([string]$ventana.FindName('LogOverlay').Visibility)
    }

    It 'volver a abrirlo antes de que acabe de cerrarse no lo esconde' {
        # La carrera de verdad: el cierre tarda 200 ms y en ese rato
        # da tiempo a pulsar otra vez el botón. Si el final de la
        # animación colapsara sin mirar, escondería un cajón que ya
        # estaba entrando y la aplicación se quedaría sorda.
        $ventana = New-AppWindow
        New-TestLogEntries 2

        Show-LogPanel $ventana
        Hide-LogPanel $ventana
        Show-LogPanel $ventana

        Close-LogOverlay $ventana
        Assert-True (Get-LogPanelOpen)
        Assert-Equal 'Visible' ([string]$ventana.FindName('LogOverlay').Visibility)

        Hide-LogPanel $ventana
    }

    It 'el interruptor alterna' {
        $ventana = New-AppWindow
        New-TestLogEntries 1

        Switch-LogPanel $ventana
        Assert-True (Get-LogPanelOpen)
        Switch-LogPanel $ventana
        Assert-False (Get-LogPanelOpen)
    }

    It 'cerrar estando ya cerrado no hace nada' {
        $ventana = New-AppWindow
        Assert-NoThrow { Hide-LogPanel $ventana }
        Assert-False (Get-LogPanelOpen)
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - las filas' {

    It 'pinta una fila por entrada' {
        $ventana = New-AppWindow
        New-TestLogEntries 5

        Show-LogPanel $ventana
        Assert-Equal 5 $ventana.FindName('LogList').Children.Count

        Hide-LogPanel $ventana
    }

    It 'la fila enseña la hora, el estado y la clave' {
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog
        Write-AppLog -Source 'registry' -Level 'info' -Status 'read' `
                     -Message 'HKEY_LOCAL_MACHINE\SOFTWARE\Prueba\MiValor' `
                     -Detail  '5 (0x00000005) - DWord - 0,4 ms'

        Show-LogPanel $ventana
        $texto = Get-VisualText $ventana.FindName('LogList')

        Assert-Match '\d{2}:\d{2}:\d{2}\.\d{3}' $texto
        Assert-Match 'read' $texto
        Assert-Match 'MiValor' $texto
        Assert-Match '0x00000005' $texto

        Hide-LogPanel $ventana
    }

    It 'sin nada apuntado sale el aviso de vacío' {
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog

        Show-LogPanel $ventana
        Assert-Match 'Nothing logged yet' (Get-VisualText $ventana.FindName('LogList'))

        Hide-LogPanel $ventana
    }

    It 'con muchas entradas solo se pintan las últimas, y se avisa' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries ($LogPanelMaxRows + 20)

        Show-LogPanel $ventana
        # Las filas del tope más la línea de aviso.
        Assert-Equal ($LogPanelMaxRows + 1) $ventana.FindName('LogList').Children.Count
        Assert-Match 'Showing the last' (Get-VisualText $ventana.FindName('LogList'))

        Hide-LogPanel $ventana
    }

    It 'lo último apuntado sale abajo' {
        $ventana = New-AppWindow
        Clear-AppLog
        Write-AppLog -Source 'registry' -Status 'read' -Message 'PRIMERA'
        Write-AppLog -Source 'registry' -Status 'read' -Message 'ULTIMA'

        Show-LogPanel $ventana
        $filas = $ventana.FindName('LogList').Children
        Assert-Match 'PRIMERA' (Get-VisualText $filas[0])
        Assert-Match 'ULTIMA'  (Get-VisualText $filas[1])

        Hide-LogPanel $ventana
    }

    It 'vaciar el log deja el cajón vacío sin cerrarlo' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 4
        Show-LogPanel $ventana

        Clear-AppLog
        Update-LogList $ventana

        Assert-True (Get-LogPanelOpen) 'vaciar no debería cerrar el cajón'
        Assert-Match 'Nothing logged yet' (Get-VisualText $ventana.FindName('LogList'))

        Hide-LogPanel $ventana
    }

    It 'el recuento cuadra con lo apuntado' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 7
        Show-LogPanel $ventana

        Assert-Equal '7 entries' ([string]$ventana.FindName('LogCount').Text)

        Hide-LogPanel $ventana
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - idioma' {

    It 'el marco se traduce y las líneas no' {
        # Es la decisión de diseño del componente: los títulos y las
        # etiquetas van en el idioma elegido, pero una ruta del
        # registro se enseña tal cual para poder copiarla.
        $ventana = New-AppWindow -Language 'es'
        Clear-AppLog
        Write-AppLog -Source 'registry' -Level 'info' -Status 'read' `
                     -Message 'HKEY_LOCAL_MACHINE\SOFTWARE\Prueba\MiValor' -Detail '5 - DWord'

        Show-LogPanel $ventana
        $texto = Get-VisualText $ventana.FindName('LogDrawer')

        Assert-Match 'Registro de actividad' $texto 'el título va traducido'
        Assert-Match 'leído'                 $texto 'la etiqueta de estado también'
        Assert-Match 'MiValor'               $texto 'la clave se queda como está'

        Hide-LogPanel $ventana
        Set-AppLanguage 'en'
    }

    It 'las cuatro etiquetas de estado del registro están traducidas' {
        Set-AppLanguage 'es'
        foreach ($estado in @('read', 'not set', 'no access', 'unknown root key', 'reading', 'done')) {
            Assert-NotEqual $estado (T $estado) "falta la traducción de '$estado'"
        }
        Set-AppLanguage 'en'
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - guardar en archivo' {

    It 'el pie contesta con la ruta escrita' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 2
        Show-LogPanel $ventana

        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-log-{0}.txt' -f [Guid]::NewGuid())
        try {
            $ruta = Export-AppLog -Path $destino
            Set-LogFooterText $ventana ((T 'Saved to {0}') -f $ruta) 'Success'
            Assert-Match ([regex]::Escape($destino)) ([string]$ventana.FindName('LogFooterText').Text)
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
            Hide-LogPanel $ventana
        }
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - de la lectura a la pantalla' {

    It 'entrar en Regedit deja su rastro en el cajón' {
        # El recorrido entero: la vista lee el registro, core/ lo
        # apunta y el cajón lo enseña.
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog

        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
        Show-LogPanel $ventana

        $texto = Get-VisualText $ventana.FindName('LogList')
        Assert-Match 'Regedit' $texto 'debería estar la cabecera de la sección'
        Assert-Match 'NetworkThrottlingIndex' $texto 'y alguna de sus claves'

        # cabecera + una por clave + resumen
        $claves = Get-CategoryRegistryKeyCount (Get-CategoryById 'regedit')
        Assert-Equal ($claves + 2) $ventana.FindName('LogList').Children.Count

        Hide-LogPanel $ventana
    }
}
