# ============================================================
# Pruebas de la opción "Formato de hora":
#
#   - ui/Engine/TimeFormat.ps1        (Format-AppTime, Get-/Set-AppTimeFormat)
#   - ui/Data/Preferences/40-TimeFormat.ps1  (la opción en Ajustes)
#   - ui/Views/CategoryDetailView.ps1 (la etiqueta "Actualizado" del panel Regedit)
#
# Los dos estilos llevan segundos: 24h -> "18:45:33", 12h -> "6:45:33 PM".
#
# TimeFormat vive en settings.json y el arnes redirige ese archivo
# a un temporal con el PID (regla 28), asi que estas pruebas no
# tocan la preferencia del usuario. Aun asi cada prueba que cambia
# el valor lo devuelve a '24' en un finally, porque la tabla en
# memoria si dura toda la corrida y otras pruebas leen esa etiqueta.
# ============================================================

# El valor por defecto, para restaurar. Es el que deja la interfaz
# como estaba antes de existir la opción.
$TF_DEFAULT = '24'
$TF_STAMP   = [datetime]'2024-03-04 18:45:33'

Describe 'ui/Engine/TimeFormat.ps1 - Format-AppTime' {

    It '24h: "18:45:33", con segundos' {
        Assert-Equal '18:45:33' (Format-AppTime $TF_STAMP -Format '24')
    }

    It '12h: "6:45:33 PM", con segundos' {
        Assert-Equal '6:45:33 PM' (Format-AppTime $TF_STAMP -Format '12')
    }

    It '12h resuelve bien medianoche y mediodia' {
        Assert-Equal '12:05:00 AM' (Format-AppTime ([datetime]'2024-03-04 00:05:00') -Format '12')
        Assert-Equal '12:00:00 PM' (Format-AppTime ([datetime]'2024-03-04 12:00:00') -Format '12')
    }

    It 'el "PM" es literal, no depende de la cultura del equipo' {
        # Format-AppTime formatea con InvariantCulture: en un Windows
        # en espanol un "h:mm:ss tt" a pelo daria "6:45:33 p. m.".
        Assert-Equal '6:45:33 PM' (Format-AppTime $TF_STAMP -Format '12')
    }

    It 'sin -Format usa la preferencia guardada' {
        Assert-Match '^\d\d:\d\d:\d\d$' (Format-AppTime $TF_STAMP)   # por defecto, 24h

        Set-AppSetting 'TimeFormat' '12'
        try   { Assert-Equal '6:45:33 PM' (Format-AppTime $TF_STAMP) }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }

    It 'un valor desconocido en settings.json cae a 24h en vez de romper' {
        Set-AppSetting 'TimeFormat' 'no-es-un-formato'
        try {
            Assert-Equal '24' (Get-AppTimeFormat)
            Assert-Equal '18:45:33' (Format-AppTime $TF_STAMP)
        }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }
}

Describe 'ui/Data/Preferences/40-TimeFormat.ps1 - la opción en Ajustes' {

    It 'aparece registrada como desplegable' {
        $p = Get-PreferenceById 'timeformat'
        Assert-NotNull $p 'la opción "Formato de hora" no está registrada'
        Assert-Equal 'Choice' $p.Type
        Assert-Equal 'Time format' $p.Label
    }

    It 'ofrece exactamente 24h y 12h, en ese orden' {
        $p = Get-PreferenceById 'timeformat'
        $valores = @((Get-PreferenceOptions $p) | ForEach-Object { $_.Value })
        Assert-Equal @('24', '12') $valores
    }

    It 'sale en Ajustes como desplegable con 24h y 12h' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-SettingsView'
        $content = $ventana.FindName('MainContent').Content

        Assert-Match 'Time format' (Get-VisualText $content) 'no se ve la etiqueta de la opción'

        # Las opciones viven en los Items del ComboBox, no en el texto
        # visible (igual que Claro/Oscuro en el de tema).
        $combo = (Find-Visuals $content {
            param($el)
            $el -is [System.Windows.Controls.ComboBox] -and (@($el.Items) -contains '24-hour (18:45:03)')
        })[0]
        Assert-NotNull $combo 'no se ha encontrado el desplegable de formato de hora'
        Assert-Contains '12-hour (6:45:03 PM)' @($combo.Items)
        Assert-Equal 0 $combo.SelectedIndex 'por defecto debería estar 24h seleccionado'
    }

    It 'Get devuelve el estilo actual y Set lo guarda por el mecanismo de siempre' {
        $p = Get-PreferenceById 'timeformat'
        Assert-Equal (Get-AppTimeFormat) (& $p.Get)

        & $p.Set '12'
        try {
            Assert-Equal '12' (Get-AppSetting 'TimeFormat')   # persistido
            Assert-Equal '12' (& $p.Get)
        }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }

    It 'la preferencia se escribe en settings.json (sobrevive a reiniciar)' {
        Set-AppSetting 'TimeFormat' '12'
        try {
            $ruta = Get-AppSettingsPath
            Assert-True (Test-Path $ruta) 'no se ha escrito settings.json'
            $json = Get-Content -Path $ruta -Raw | ConvertFrom-Json
            Assert-Equal '12' ([string]$json.TimeFormat)
        }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }
}

Describe 'ui/Views/CategoryDetailView.ps1 - la etiqueta "Actualizado" respeta el formato' {

    function Get-HeaderText {
        param($Window)
        Get-VisualText $Window.FindName('HeaderActionsArea')
    }

    It 'por defecto va en 24h (18:45:33), sin AM/PM' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
        $texto = Get-HeaderText $ventana

        Assert-Match 'Updated \d\d:\d\d:\d\d' $texto 'falta la hora de la última lectura'
        # El AM/PM se busca pegado a la hora: "gaming" (en una pista del
        # menú Vista) lleva un "am" que un /(AM|PM)/ suelto cazaría.
        Assert-False ($texto -match 'Updated \d?\d:\d\d:\d\d (AM|PM)') 'no debería llevar AM/PM en 24h'
    }

    It 'con la opción en 12h la etiqueta cambia a "6:45:33 PM"' {
        Set-AppSetting 'TimeFormat' '12'
        try {
            $ventana = New-AppWindow -Language 'en'
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            Assert-Match 'Updated \d?\d:\d\d:\d\d (AM|PM)' (Get-HeaderText $ventana)
        }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }

    It 'cambiar la preferencia repinta la pantalla actual (aplicación dinámica)' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
        Assert-False ((Get-HeaderText $ventana) -match 'Updated \d?\d:\d\d:\d\d (AM|PM)') 'arranca en 24h'

        try {
            Set-AppTimeFormat '12'
            Sync-Dispatcher 'Background'   # el repintado va aplazado, como el de idioma
            Assert-Match 'Updated \d?\d:\d\d:\d\d (AM|PM)' (Get-HeaderText $ventana) 'la etiqueta no se ha actualizado en el sitio'
        }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }
}

Describe 'ui/Engine/TimeFormat.ps1 - sin regresiones en el resto de horas' {

    It 'el volcado del registro de actividad sigue en 24h con segundos' {
        # core/Diagnostics/Log.ps1 NO pasa por Format-AppTime: su hora
        # es texto tecnico para copiar y pegar y va siempre igual.
        $entry = [PSCustomObject]@{
            Time = [datetime]'2024-03-04 18:45:33'; Level = 'info'; Source = 'test'
            Status = $null; Message = 'x'; Detail = $null
        }
        Set-AppSetting 'TimeFormat' '12'
        try {
            Assert-Match '\[2024-03-04 18:45:33\]' (Format-AppLogLine $entry)
        }
        finally { Set-AppSetting 'TimeFormat' $TF_DEFAULT }
    }
}
