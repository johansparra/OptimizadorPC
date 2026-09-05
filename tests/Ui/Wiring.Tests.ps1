# ============================================================
# Pruebas del cableado de main.ps1: que los botones respondan.
#
# Es el único archivo que no se puede cargar como los demás,
# porque termina en ShowDialog() y se quedaría ahí bloqueado. Y
# es justo el que esconde la trampa de la regla 4 de CLAUDE.md:
# un manejador con closure falla AL PULSAR, solo ejecutando
# main.ps1, y en el .exe no se nota.
#
# Así que se hace lo único que sirve: una copia de main.ps1 sin
# la línea del ShowDialog y con unas cuantas pulsaciones al
# final, ejecutada en otro proceso con el MISMO host que estas
# pruebas. La copia se genera desde el archivo de verdad, así
# que no puede quedarse desfasada.
#
# Todo el archivo son seis comprobaciones sobre una sola
# ejecución: levantar el proceso cuesta un par de segundos y no
# hay motivo para repetirlo.
# ============================================================

# Lo que se pulsa, una línea de salida por cosa. Se pegan al
# final de la copia de main.ps1, ya con la ventana montada y
# todos los manejadores conectados.
function Get-WiringProbe {
    @(
        ''
        '# ---- pulsaciones de prueba (las añade Ui/Wiring.Tests.ps1) ----'
        'function Push-Boton {'
        '    param($Boton)'
        '    $Boton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))'
        '}'
        ''
        '# Una sección con claves de verdad, para que el log tenga algo.'
        'Show-View -Name ''Show-CategoryDetailView'' -Arguments @{ Category = (Get-CategoryById ''regedit'') }'
        '$claves = Get-CategoryRegistryKeyCount (Get-CategoryById ''regedit'')'
        ''
        'Push-Boton $Window.FindName(''BtnLog'')'
        'Write-Host ("LOG-ABIERTO={0} FILAS={1} ESPERADAS={2}" -f (Get-LogPanelOpen), $Window.FindName(''LogList'').Children.Count, ($claves + 2))'
        ''
        'Push-Boton $Window.FindName(''BtnLog'')'
        'Write-Host ("LOG-SEGUNDO-CLIC={0}" -f (Get-LogPanelOpen))'
        ''
        'Push-Boton $Window.FindName(''BtnLog'')'
        '$tecla = New-Object System.Windows.Input.KeyEventArgs ([System.Windows.Input.Keyboard]::PrimaryDevice), (New-Object System.Windows.Interop.HwndSource 0,0,0,0,0,''probe'',([IntPtr]::Zero)), 0, ([System.Windows.Input.Key]::Escape)'
        '$tecla.RoutedEvent = [System.Windows.Input.Keyboard]::PreviewKeyDownEvent'
        '$Window.RaiseEvent($tecla)'
        'Write-Host ("LOG-ESCAPE={0}" -f (Get-LogPanelOpen))'
        ''
        '$antes = Get-AppTheme'
        'Push-Boton $Window.FindName(''BtnTheme'')'
        'Write-Host ("TEMA-ANTES={0} TEMA-DESPUES={1}" -f $antes, (Get-AppTheme))'
        ''
        'Push-Boton $Window.FindName(''BtnMenu'')'
        'Write-Host ("MENU-DESPLEGADO={0}" -f (Get-SidebarExpanded))'
        ''
        'Push-Boton $Window.FindName(''BtnModeBuilder'')'
        'Write-Host ("MODO-BUILDER={0} MODO-NORMAL={1}" -f $Window.FindName(''BtnModeBuilder'').Tag, $Window.FindName(''BtnModeNormal'').Tag)'
        ''
        ''
        '# Refrescar: la misma lectura de la entrada, otra vez.'
        'Clear-AppLog'
        'Push-Boton $Window.FindName(''BtnRefresh'')'
        '# El repintado va aplazado al Dispatcher; aquí no hay bucle'
        '# de mensajes todavía, así que hay que bombear la cola.'
        'Update-UiNow $Window'
        '$acciones = $Window.FindName(''HeaderActionsArea'')'
        'Write-Host ("REFRESCO-LINEAS={0} ESPERADAS={1} AVISO={2}" -f (Get-AppLogCount), ($claves + 2), ($acciones.Children[0] -is [System.Windows.Controls.Border]))'
        ''
        '# Sacar el log a su ventana y volver a acoplarlo. Es lo unico'
        '# que caza un closure en estos manejadores: fallan AL PULSAR.'
        '# La ventana aparece un instante en pantalla y se cierra sola'
        '# al acoplar; es el precio de pulsar botones de verdad.'
        'Show-LogPanel $Window'
        'Push-Boton $Window.FindName(''LogBtnPopOut'')'
        'Write-Host ("LOG-FUERA={0} CAJON={1}" -f (Get-LogDetached), (Get-LogPanelOpen))'
        '$vlog = Get-LogWindow'
        'Push-Boton $vlog.FindName(''LogBtnDock'')'
        'Write-Host ("LOG-DENTRO={0} CAJON-OTRA-VEZ={1}" -f (Get-LogDetached), (Get-LogPanelOpen))'
        'Hide-LogPanel $Window'
        ''
        '# El menu lateral, en el host de verdad: una entrada con'
        '# pantalla y otra sin ella. Las que no la tienen no navegan.'
        'Push-Boton $Window.FindName(''NavSettings'')'
        'Write-Host ("NAV-CON-PANTALLA={0}" -f (Get-CurrentViewName))'
        'Push-Boton $Window.FindName(''NavSoftware'')'
        'Write-Host ("NAV-SIN-PANTALLA={0} MARCA={1}" -f (Get-CurrentViewName), ($null -ne $Window.FindName(''NavSoftware'').Tag))'
        ''
        '# La busqueda, pulsando de verdad. Sus manejadores llaman a'
        '# funciones del script -Open-SearchResult, Show-View- y eso'
        '# es justo lo que un closure rompe solo aqui: en el .exe las'
        '# funciones quedan en ambito global y no se nota.'
        '#'
        '# No se abre el desplegable a proposito: un Popup con'
        '# IsOpen se crea su propia ventana y esta sonda corre sin'
        '# ninguna a la vista.'
        '#'
        '# El termino sale de los datos, no escrito a mano: asi la'
        '# sonda no se queda coja el dia que cambie un ajuste.'
        '$ajuste = @((Get-CategoryById ''regedit'').Items)[0]'
        'Set-SearchQuery $ajuste.Name'
        'Show-View -Name ''Show-SearchResultsView'''
        '$cuerpo = $Window.FindName(''MainContent'').Content'
        '$tarjetas = @($cuerpo.Children | Where-Object { $_.Tag -and $_.Tag.PSObject.Properties[''Category''] })'
        'Write-Host ("BUSQUEDA-VISTA={0} TARJETAS={1}" -f (Get-CurrentViewName), $tarjetas.Count)'
        ''
        '$clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)'
        '$clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent'
        '$tarjetas[0].RaiseEvent($clic)'
        'Write-Host ("BUSQUEDA-CLIC={0}" -f (Get-CurrentViewName))'
        ''
        'Write-Host "SONDA-COMPLETA"'
    )
}

<#
    Genera la copia, la ejecuta y devuelve todo lo que ha escrito.

    La primera línea de main.ps1 se sustituye por la ruta fija del
    proyecto: es lo único que hace falta para que la copia pueda
    vivir en la carpeta temporal y sus dot-source sigan
    encontrando ui/ y core/.

    Se lanza con el mismo host que está corriendo las pruebas, de
    modo que pasarlas en 5.1 y en 7 cubre los dos.
#>
function Invoke-WiringProbe {
    $raiz = Get-AppRoot

    # La sonda toca preferencias de verdad -pulsa el botón de tema-
    # y esto es main.ps1, no el arnés: sin redirigir, cada pasada de
    # las pruebas le cambiaría el tema al usuario en
    # %APPDATA%\OptimizadorPC\settings.json. Se le cuela la
    # redirección justo antes de que lea nada.
    $ajustes = Join-Path ([System.IO.Path]::GetTempPath()) ('optimizador-sonda-{0}.json' -f [Guid]::NewGuid())

    $lineas = New-Object System.Collections.Generic.List[string]
    foreach ($linea in (Get-Content -Path (Join-Path $raiz 'main.ps1'))) {
        if ($linea -match '^\$ScriptRoot = ') { $lineas.Add('$ScriptRoot = ''' + $raiz + '''') ; continue }
        if ($linea -match 'ShowDialog')       { continue }
        if ($linea -match '^Import-AppSettings') {
            $lineas.Add('$AppSettingsPath = ''' + $ajustes + '''')
        }
        $lineas.Add($linea)
    }
    foreach ($linea in (Get-WiringProbe)) { $lineas.Add($linea) }

    $copia = Join-Path ([System.IO.Path]::GetTempPath()) ('optimizador-sonda-{0}.ps1' -f [Guid]::NewGuid())
    $salida = Join-Path ([System.IO.Path]::GetTempPath()) ('optimizador-sonda-{0}.txt' -f [Guid]::NewGuid())

    try {
        # Con BOM, como todo lo demás: la copia lleva los acentos
        # de los comentarios de main.ps1 (regla 3).
        [System.IO.File]::WriteAllLines($copia, $lineas, (New-Object System.Text.UTF8Encoding($true)))

        $host51 = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        & $host51 -NoProfile -ExecutionPolicy Bypass -File $copia *> $salida

        Get-Content -Path $salida -Raw
    }
    finally {
        foreach ($tmp in @($copia, $salida, $ajustes)) {
            if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
    }
}

$WiringOutput = Invoke-WiringProbe

Describe 'main.ps1 - los botones responden' {

    It 'la sonda llega hasta el final' {
        # Si esto falla, lo de abajo no significa nada: es que
        # main.ps1 se ha caído por el camino.
        Assert-Match 'SONDA-COMPLETA' $WiringOutput ('salida completa: ' + $WiringOutput)
    }

    It 'el botón de log abre el cajón con lo que se acaba de leer' {
        Assert-Match 'LOG-ABIERTO=True' $WiringOutput

        # Una fila por clave, más la cabecera y el resumen.
        if ($WiringOutput -match 'FILAS=(\d+) ESPERADAS=(\d+)') {
            Assert-Equal $Matches[2] $Matches[1] 'filas pintadas'
        }
        else { throw 'la sonda no ha dicho cuántas filas hay' }
    }

    It 'volver a pulsarlo lo cierra' {
        Assert-Match 'LOG-SEGUNDO-CLIC=False' $WiringOutput
    }

    It 'Escape cierra el cajón' {
        Assert-Match 'LOG-ESCAPE=False' $WiringOutput
    }

    It 'el botón de tema alterna claro y oscuro' {
        Assert-Match 'TEMA-ANTES=Light TEMA-DESPUES=Dark|TEMA-ANTES=Dark TEMA-DESPUES=Light' $WiringOutput
    }

    It 'el botón de menú lo pliega' {
        Assert-Match 'MENU-DESPLEGADO=False' $WiringOutput
    }

    It 'el selector de modo mueve la selección' {
        Assert-Match 'MODO-BUILDER=sel MODO-NORMAL=\s*$' ($WiringOutput -split "`r?`n" | Where-Object { $_ -like 'MODO-*' })
    }

    It 'el botón de refrescar vuelve a leer el registro y avisa' {
        if ($WiringOutput -match 'REFRESCO-LINEAS=(\d+) ESPERADAS=(\d+) AVISO=(\w+)') {
            Assert-Equal $Matches[2] $Matches[1] 'líneas dejadas por la segunda lectura'
            Assert-Equal 'True' $Matches[3] 'no ha aparecido el aviso de refrescado'
        }
        else { throw 'la sonda no ha dicho nada del refresco' }
    }

    It 'el log sale a su ventana y vuelve al cajón' {
        Assert-Match 'LOG-FUERA=True CAJON=False' $WiringOutput 'sacarlo debería cerrar el cajón'
        Assert-Match 'LOG-DENTRO=False CAJON-OTRA-VEZ=True' $WiringOutput 'acoplarlo debería reabrirlo'
    }

    It 'una entrada del menú sin pantalla no lleva a ninguna parte' {
        Assert-Match 'NAV-CON-PANTALLA=Show-SettingsView' $WiringOutput 'Ajustes sí debería navegar'
        Assert-Match 'NAV-SIN-PANTALLA=Show-SettingsView MARCA=False' $WiringOutput 'Software no debía moverse de sitio ni marcarse'
    }

    It 'la búsqueda pinta resultados y pulsarlos lleva a su sección' {
        if ($WiringOutput -match 'BUSQUEDA-VISTA=(\S+) TARJETAS=(\d+)') {
            Assert-Equal 'Show-SearchResultsView' $Matches[1]
            Assert-True ([int]$Matches[2] -gt 0) 'buscar el nombre de un ajuste no ha pintado ninguna tarjeta'
        }
        else { throw 'la sonda no ha dicho nada de la búsqueda' }

        Assert-Match 'BUSQUEDA-CLIC=Show-CategoryDetailView' $WiringOutput 'pulsar un resultado no ha llevado a su sección'
    }

    It 'ningún manejador ha lanzado' {
        # El síntoma de la regla 4: "el término ... no se reconoce"
        # al pulsar, porque el scriptblock quedó atado a un módulo
        # dinámico desde el que no se ven las funciones del script.
        Assert-True ($WiringOutput -notmatch 'no se reconoce|is not recognized') 'parece un closure en un manejador'
        Assert-True ($WiringOutput -notmatch 'CategoryInfo') ('main.ps1 ha soltado un error: ' + $WiringOutput)
    }
}
