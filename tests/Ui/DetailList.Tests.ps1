# ============================================================
# Pruebas del detalle desplegable ("qué hizo exactamente"):
#   ui/Components/Cards/DetailList.ps1
# y de los tres sitios donde sale: el registro de actividad
# (LogPanel.ps1), la fila de un paso ya ejecutado (StepRow.ps1) y el
# archivo guardado "con detalle".
# ============================================================

function New-TestDetailEntry {
    param([int]$Lines = 3, [string]$Message = 'clean %TEMP%')
    $items = @(1..$Lines | ForEach-Object { '  12 KB      C:\Users\x\AppData\Local\Temp\f{0}.tmp' -f $_ })
    Write-AppLog -Source 'cleanup' -Status 'succeeded' -Message $Message -Detail 'exit=0' -Items $items
}

# Los rótulos que despliegan: llevan Key y Body en el Tag.
function Get-DetailToggles {
    param($Root)
    @(Find-Visuals $Root {
        param($el)
        $el -is [System.Windows.Controls.Border] -and $el.Tag -and
        $el.Tag.PSObject.Properties['Key'] -and $el.Tag.PSObject.Properties['Body']
    })
}

Describe 'ui/Components/Cards/DetailList.ps1 - la pieza' {

    It 'nace plegada, dice cuántas líneas trae y no construye la lista hasta abrirla' {
        $ventana = New-AppWindow -Language 'en'
        $pieza = New-DetailList $ventana @('a', 'b', 'c') 'test:plegada'
        $toggle = $pieza.Children[0]
        Assert-Equal 'Collapsed' $toggle.Tag.Body.Visibility
        Assert-Null $toggle.Tag.Body.Child 'la lista no se construye hasta que se abre'
        Assert-Match '3 lines' $toggle.Tag.Label.Text
    }

    It 'al pulsar se abre con las líneas en un TextBox de solo lectura, y se vuelve a cerrar' {
        $ventana = New-AppWindow -Language 'en'
        $pieza = New-DetailList $ventana @('linea uno', 'linea dos') 'test:abrir'
        $toggle = $pieza.Children[0]

        Switch-DetailList $toggle
        Assert-Equal 'Visible' $toggle.Tag.Body.Visibility
        $tb = $toggle.Tag.Body.Child
        Assert-True ($tb -is [System.Windows.Controls.TextBox]) 'se tiene que poder seleccionar y copiar (regla 22)'
        Assert-True $tb.IsReadOnly
        Assert-Match 'linea uno' $tb.Text
        Assert-Match 'linea dos' $tb.Text

        Switch-DetailList $toggle
        Assert-Equal 'Collapsed' $toggle.Tag.Body.Visibility
        Assert-False (Test-DetailListOpen 'test:abrir')
    }

    It 'el estado abierto vive fuera del control: una pieza nueva con la misma clave nace abierta' {
        $ventana = New-AppWindow -Language 'en'
        Set-DetailListOpen 'test:recuerda' $true
        try {
            $toggle = (New-DetailList $ventana @('x') 'test:recuerda').Children[0]
            Assert-Equal 'Visible' $toggle.Tag.Body.Visibility
        }
        finally { Set-DetailListOpen 'test:recuerda' $false }
    }

    It 'el rótulo se traduce y las líneas no' {
        $ventana = New-AppWindow -Language 'es'
        try {
            $toggle = (New-DetailList $ventana @('Deleted (1 files, 1 B):') 'test:idioma').Children[0]
            Assert-Match 'Ver detalle \(1 l' $toggle.Tag.Label.Text
            Switch-DetailList $toggle
            Assert-Equal 'Ocultar detalle' $toggle.Tag.Label.Text
            Assert-Match 'Deleted \(1 files' $toggle.Tag.Body.Child.Text
        }
        finally {
            Set-DetailListOpen 'test:idioma' $false
            Set-AppLanguage 'en'
        }
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - el detalle de una entrada' {

    It 'una entrada con detalle trae su desplegable; una sin detalle, no' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 2
        New-TestDetailEntry 4
        Show-LogPanel $ventana
        try {
            $toggles = Get-DetailToggles $ventana.FindName('LogList')
            Assert-Equal 1 $toggles.Count
            Assert-Match '4 lines' $toggles[0].Tag.Label.Text
        }
        finally { Hide-LogPanel $ventana }
    }

    It 'abierto, sigue abierto aunque la lista se rehaga' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 1
        New-TestDetailEntry 2
        Show-LogPanel $ventana
        try {
            Switch-DetailList (Get-DetailToggles $ventana.FindName('LogList'))[0]
            Write-AppLog -Source 'registry' -Status 'read' -Message 'OTRA'
            Sync-LogView
            $toggle = (Get-DetailToggles $ventana.FindName('LogList'))[0]
            Assert-Equal 'Visible' $toggle.Tag.Body.Visibility 'se ha cerrado sola al rehacer la lista'
        }
        finally {
            Set-DetailListOpen $toggle.Tag.Key $false
            Hide-LogPanel $ventana
        }
    }

    It 'sin entradas nuevas, poner al día no rehace la lista' {
        # Durante una ejecución se llama en cada latido: rehacerla
        # movería la lista abierta que se está leyendo.
        $ventana = New-AppWindow -Language 'en'
        New-TestDetailEntry 2
        Show-LogPanel $ventana
        try {
            $antes = $ventana.FindName('LogList').Children[0]
            Sync-LogView
            Assert-True ([object]::ReferenceEquals($antes, $ventana.FindName('LogList').Children[0])) 'se ha rehecho sin nada nuevo'

            Write-AppLog -Source 'registry' -Status 'read' -Message 'NUEVA'
            Sync-LogView
            Assert-Match 'NUEVA' (Get-VisualText $ventana.FindName('LogList'))
        }
        finally { Hide-LogPanel $ventana }
    }
}

Describe 'ui/Components/Shell/LogPanel.ps1 - guardar con detalle' {

    It 'la casilla "Con detalle" solo aparece si alguna entrada trae detalle' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 2
        Show-LogPanel $ventana
        try {
            Assert-Equal 'Collapsed' $ventana.FindName('LogBtnDetails').Visibility
            New-TestDetailEntry 1
            Update-LogList $ventana
            Assert-Equal 'Visible' $ventana.FindName('LogBtnDetails').Visibility
        }
        finally { Hide-LogPanel $ventana }
    }

    It 'con la casilla puesta, el archivo lleva el detalle y el pie lo dice' {
        $ventana = New-AppWindow -Language 'en'
        New-TestLogEntries 1
        New-TestDetailEntry 2
        Show-LogPanel $ventana
        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-{0}.log' -f [Guid]::NewGuid())
        try {
            Set-LogExportDetails $true
            Save-AppLogTo $ventana $destino | Out-Null
            $contenido = Get-Content -Path $destino -Raw
            Assert-Match 'Details: included' $contenido
            Assert-Match '(?m)^    \s+12 KB\s+C:\\Users\\x\\AppData\\Local\\Temp\\f2\.tmp' $contenido 'falta el detalle, sangrado bajo su entrada'
            Assert-Match 'with details' ([string]$ventana.FindName('LogFooterText').Text)
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
            Hide-LogPanel $ventana
        }
    }

    It 'sin la casilla, el archivo no lo lleva pero avisa de que existe' {
        $ventana = New-AppWindow -Language 'en'
        Clear-AppLog
        New-TestDetailEntry 2
        Show-LogPanel $ventana
        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-{0}.log' -f [Guid]::NewGuid())
        try {
            Set-LogExportDetails $false
            Save-AppLogTo $ventana $destino | Out-Null
            $contenido = Get-Content -Path $destino -Raw
            Assert-Match 'Details: not included \(1 entries' $contenido
            Assert-False ($contenido -match 'f2\.tmp') 'el detalle no debería ir dentro'
        }
        finally {
            Set-LogExportDetails $true
            if (Test-Path $destino) { Remove-Item $destino -Force }
            Hide-LogPanel $ventana
        }
    }

    It 'pulsar la casilla la alterna y se recuerda entre sesiones' {
        $ventana = New-AppWindow -Language 'en'
        New-TestDetailEntry 1
        Show-LogPanel $ventana
        try {
            Set-LogExportDetails $true
            $chip = $ventana.FindName('LogBtnDetails')
            $chip.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
            Assert-False (Get-LogExportDetails)
            Assert-Match 'LogExportDetails' (Get-Content -Path (Get-TestSettingsPath) -Raw)
        }
        finally {
            Set-LogExportDetails $true
            Hide-LogPanel $ventana
        }
    }
}

Describe 'ui/Components/Cards/StepRow.ps1 - el detalle de un paso ejecutado' {

    It 'antes de correr no hay detalle; con Items, la fila lo trae plegado' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-CategoryById 'cleanup'
        $paso = @($cat.Steps)[0]
        $paso.Items = $null
        $fila = New-StepRow -Window $ventana -Step $paso -Number 1
        Assert-Equal 0 (Get-DetailToggles $fila).Count

        $paso.Items = @('Deleted (2 files, 2 B):', '  1 B        C:\x\a.tmp', '  1 B        C:\x\b.tmp')
        try {
            Update-StepRow $fila
            $toggles = Get-DetailToggles $fila
            Assert-Equal 1 $toggles.Count
            Assert-Match '3 lines' $toggles[0].Tag.Label.Text

            # Otro latido sin cambios no lo rehace.
            Update-StepRow $fila
            Assert-True ([object]::ReferenceEquals($toggles[0], (Get-DetailToggles $fila)[0]))
        }
        finally { $paso.Items = $null }
    }

    It 'pulsar el detalle no marca ni desmarca el paso' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-CategoryById 'cleanup'
        $paso = @($cat.Steps)[0]
        $paso.Items = @('x')
        try {
            $fila = New-StepRow -Window $ventana -Step $paso -Number 1
            $antes = $paso.Selected
            $toggle = (Get-DetailToggles $fila)[0]
            $clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
            $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
            $toggle.RaiseEvent($clic)
            Assert-Equal $antes $paso.Selected 'el clic en el detalle ha llegado a la fila'
            Assert-Equal 'Visible' $toggle.Tag.Body.Visibility
        }
        finally {
            Set-DetailListOpen ('step:cleanup:{0}' -f $paso.Id) $false
            $paso.Items = $null
        }
    }

    It 'una ejecución nueva borra el detalle de la anterior' {
        $null = New-AppWindow -Language 'en'
        $cat = Get-CategoryById 'cleanup'
        Set-StepSelection -Category $cat -Mode 'none'
        $pasos = @($cat.Steps)
        $pasos[1].Items = @('viejo')
        $pasos[0].Selected = $true
        try {
            Start-StepRun -Category $cat | Out-Null
            Assert-Null $pasos[1].Items 'el detalle de la ejecución anterior sigue ahí'
            Stop-StepRun
        }
        finally { Set-StepSelection -Category $cat -Mode 'default' }
    }
}
