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

    # El diálogo NO se enseña en ninguna prueba: es modal y se
    # quedaría esperando a que alguien pulse. Por eso está partido
    # en armar / leer la respuesta / escribir, y lo único sin
    # cubrir es la línea que llama a ShowDialog.

    It 'el diálogo propone opt-<fecha>.log' {
        $dialogo = New-LogSaveDialog
        Assert-Match '^opt-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.log$' $dialogo.FileName
    }

    It 'y se abre en la carpeta que toque' {
        Set-AppSetting 'LogSaveFolder' $null
        $dialogo = New-LogSaveDialog
        Assert-Equal ([Environment]::GetFolderPath('DesktopDirectory')) ([string]$dialogo.InitialDirectory)
    }

    It 'y guarda con extensión .log aunque se escriba un nombre a secas' {
        $dialogo = New-LogSaveDialog
        Assert-Equal 'log' ([string]$dialogo.DefaultExt)
        Assert-True $dialogo.AddExtension 'sin esto, un nombre sin extensión se guardaría sin .log'
        Assert-True $dialogo.OverwritePrompt 'debería avisar antes de machacar un archivo'
    }

    It 'deja elegir cualquier carpeta y filtra por .log' {
        $dialogo = New-LogSaveDialog
        Assert-Match '\*\.log' $dialogo.Filter
        Assert-Match '\*\.\*'  $dialogo.Filter 'también debería poder verse todo'

        # Ni carpeta fija ni ruta impuesta: solo un punto de partida.
        Assert-NotNull $dialogo.Title
    }

    It 'sus rótulos están traducidos' {
        Set-AppLanguage 'es'
        try {
            $dialogo = New-LogSaveDialog
            Assert-Match 'Guardar el registro' ([string]$dialogo.Title)
            Assert-Match 'Archivos de registro' ([string]$dialogo.Filter)
        }
        finally { Set-AppLanguage 'en' }
    }

    It 'se puede abrir con dueño' {
        # La única línea que ninguna prueba ejecuta es el ShowDialog:
        # enseñar un modal dejaría la suite colgada. Al menos se
        # comprueba que la llamada existe tal como la hace
        # Get-LogSavePath, con la ventana como dueño.
        $conDuenno = [Microsoft.Win32.SaveFileDialog].GetMethod('ShowDialog', [type[]]@([System.Windows.Window]))
        Assert-NotNull $conDuenno 'no existe ShowDialog(Window)'
        Assert-NotNull ([Microsoft.Win32.SaveFileDialog].GetMethod('ShowDialog', [type[]]@())) 'ni ShowDialog()'
    }

    It 'cancelar no devuelve ruta' {
        # $false es el botón Cancelar; $null, cerrar con la X o Escape.
        $dialogo = New-LogSaveDialog
        Assert-Null (Read-LogSaveResult $false $dialogo) 'cancelar no debería guardar nada'
        Assert-Null (Read-LogSaveResult $null  $dialogo) 'cerrar el diálogo, tampoco'
        Assert-Equal $dialogo.FileName (Read-LogSaveResult $true $dialogo)
    }

    It 'guardar de verdad escribe el archivo y lo dice en el pie' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 2
        Show-LogPanel $ventana

        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-{0}.log' -f [Guid]::NewGuid())
        try {
            Assert-Equal $destino (Save-AppLogTo $ventana $destino)
            Assert-True (Test-Path $destino) 'no ha escrito el archivo'

            $contenido = Get-Content -Path $destino -Raw
            Assert-Match 'Prueba\\Valor1' $contenido 'el archivo no lleva lo que hay en el registro'
            Assert-Match ([regex]::Escape($destino)) ([string]$ventana.FindName('LogFooterText').Text)
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
            Hide-LogPanel $ventana
        }
    }

    It 'la primera vez se abre en el Escritorio' {
        # Sin nada guardado: el Escritorio, que es donde la gente
        # deja lo que va a mandar a alguien.
        Set-AppSetting 'LogSaveFolder' $null
        Assert-Equal ([Environment]::GetFolderPath('DesktopDirectory')) (Get-LogSaveFolder)
    }

    It 'la próxima vez el diálogo se abre donde se guardó, y entre sesiones' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 1
        Show-LogPanel $ventana

        $carpeta = [System.IO.Path]::GetTempPath().TrimEnd('\')
        $destino = Join-Path $carpeta ('opt-{0}.log' -f [Guid]::NewGuid())
        try {
            Save-AppLogTo $ventana $destino | Out-Null
            Assert-Equal $carpeta ((Get-LogSaveFolder).TrimEnd('\'))

            # Y no en una variable que se pierde al cerrar: queda en
            # settings.json como cualquier otra preferencia.
            Assert-Equal $carpeta ([string](Get-AppSetting 'LogSaveFolder')).TrimEnd('\')
            Assert-Match 'LogSaveFolder' (Get-Content -Path (Get-TestSettingsPath) -Raw)
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
            Hide-LogPanel $ventana
        }
    }

    It 'si la carpeta guardada ya no existe se vuelve al Escritorio' {
        # Un USB que se fue, una carpeta renombrada. Dejarle al
        # diálogo una ruta muerta es peor que empezar de cero.
        $fantasma = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-fantasma-{0}' -f [Guid]::NewGuid())
        Set-AppSetting 'LogSaveFolder' $fantasma
        try {
            Assert-Equal ([Environment]::GetFolderPath('DesktopDirectory')) (Get-LogSaveFolder)
        }
        finally { Set-AppSetting 'LogSaveFolder' $null }
    }

    It 'una ruta imposible guardada tampoco rompe nada' {
        # settings.json se puede editar a mano: Test-Path lanza con
        # caracteres que no valen en una ruta.
        Set-AppSetting 'LogSaveFolder' 'ZZ:\<no>|vale'
        try {
            Assert-NoThrow { Get-LogSaveFolder }
            Assert-Equal ([Environment]::GetFolderPath('DesktopDirectory')) (Get-LogSaveFolder)
        }
        finally { Set-AppSetting 'LogSaveFolder' $null }
    }

    It 'sin ventana no lanza' {
        # Guardar puede pedirse sin cajón pintado -y así lo hace la
        # sonda que abre el diálogo de verdad-. El aviso no tiene
        # dónde salir, pero eso no es motivo para tumbar nada.
        New-TestLogEntries 1
        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-{0}.log' -f [Guid]::NewGuid())
        try {
            Assert-NoThrow { Save-AppLogTo $null $destino }
            Assert-True (Test-Path $destino) 'debería haber escrito el archivo igualmente'
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
        }
    }

    It 'una ruta imposible avisa en el pie y no tumba nada' {
        # Unidad que no existe: Export-AppLog devuelve $null en vez
        # de lanzar (regla de core/) y aquí sale el aviso en rojo.
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 2
        Show-LogPanel $ventana

        try {
            Assert-NoThrow { Save-AppLogTo $ventana 'ZZ:\no\existe\opt.log' }
            Assert-Null (Save-AppLogTo $ventana 'ZZ:\no\existe\opt.log')
            Assert-Match 'could not be written' ([string]$ventana.FindName('LogFooterText').Text)
        }
        finally { Hide-LogPanel $ventana }
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - con el registro vacío no se guarda' {

    It 'el botón sale apagado y diciendo por qué' {
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog
        Show-LogPanel $ventana

        try {
            $boton = $ventana.FindName('LogBtnSave')
            Assert-NotNull $boton 'el botón de guardar debería tener nombre'
            Assert-False $boton.IsEnabled 'no hay nada que guardar y sigue encendido'
            Assert-Match 'Nothing to save' ([string]$boton.ToolTip)
        }
        finally { Hide-LogPanel $ventana }
    }

    It 'se enciende en cuanto se apunta algo, y se apaga al vaciar' {
        # La disponibilidad tiene que seguir a las entradas sola:
        # Update-LogList es por donde pasan todos los cambios.
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog
        Show-LogPanel $ventana

        try {
            $boton = $ventana.FindName('LogBtnSave')
            Assert-False $boton.IsEnabled

            Write-AppLog -Source 'registry' -Status 'read' -Message 'HKCU\Software\X'
            Update-LogList $ventana
            Assert-True $boton.IsEnabled 'con una entrada debería poder guardarse'
            Assert-Match 'Save the log' ([string]$boton.ToolTip)

            Clear-AppLog
            Update-LogList $ventana
            Assert-False $boton.IsEnabled 'al vaciar debería volver a apagarse'
        }
        finally { Hide-LogPanel $ventana }
    }

    It 'pedirlo a mano tampoco escribe nada: avisa en el pie' {
        # El botón está apagado, pero la acción se puede llamar de
        # todos modos. Ni diálogo ni archivo.
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog
        Show-LogPanel $ventana

        try {
            Assert-Null (Save-AppLogAs $ventana)
            Assert-Match 'Nothing to save' ([string]$ventana.FindName('LogFooterText').Text)
        }
        finally { Hide-LogPanel $ventana }
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

        # cabecera + un [read] y un [checked] por clave + resumen
        $claves = Get-CategoryRegistryKeyCount (Get-CategoryById 'regedit')
        Assert-Equal ($claves * 2 + 2) $ventana.FindName('LogList').Children.Count

        Hide-LogPanel $ventana
    }

    It 'lo apuntado con el cajón ya abierto también entra' {
        # Aquí no se nota tanto -el cajón se rehace al abrirlo-,
        # pero es el mismo aviso que salva a la ventana suelta.
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 2
        Show-LogPanel $ventana

        Write-AppLog -Source 'registry' -Status 'read' -Message 'MAS-TARDE'
        Sync-LogView

        Assert-Match 'MAS-TARDE' (Get-VisualText $ventana.FindName('LogList'))

        Hide-LogPanel $ventana
    }
}
