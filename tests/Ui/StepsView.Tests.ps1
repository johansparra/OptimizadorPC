# ============================================================
# Pruebas de las secciones de COMANDOS (hoy Internet):
#   ui/Views/CategoryStepsView.ps1
#   ui/Components/Cards/StepRow.ps1
#   ui/Components/Layout/StepRunPanel.ps1
#
# La ejecución está desarmada (tests/Harness/AppHost.ps1): cada paso
# acaba en 'disarmed' sin tocar la red. Y sin pausas. El temporizador
# no late sin bucle de mensajes, así que aquí se late a mano con
# Invoke-StepRunTick.
# ============================================================

function Get-InternetCategory { Get-CategoryById 'internet' }

# Corre lo que haya en marcha hasta el final, latiendo a mano.
function Complete-TestStepRun {
    $n = 0
    while ((Get-StepRunActive) -and $n -lt 500) { Invoke-StepRunTick; $n++ }
}

# Las filas de paso de la lista (sin las cabeceras de fase).
function Get-StepRows {
    param($Window)
    @($Window.FindName('StepList').Children | Where-Object { $_.Tag -and $_.Tag.PSObject.Properties['Step'] })
}

Describe 'ui/Data/Categories/Internet.ps1 - los pasos' {

    It 'la sección existe y trae los pasos del .cmd' {
        $cat = Get-InternetCategory
        Assert-NotNull $cat
        Assert-True (@($cat.Steps).Count -ge 20) 'faltan pasos'
        Assert-Equal 0 @($cat.Items).Count 'una sección de comandos no tiene ajustes'
    }

    It 'cada paso tiene un Id único' {
        $ids = @(@((Get-InternetCategory).Steps) | ForEach-Object { $_.Id })
        Assert-Equal $ids.Count @($ids | Select-Object -Unique).Count
    }

    It 'lo que borra reglas o toca el DNS viene desmarcado y con aviso' {
        foreach ($id in 'firewall-reset', 'dns-primary', 'dns-secondary', 'dns-dhcp') {
            $step = @((Get-InternetCategory).Steps) | Where-Object { $_.Id -eq $id }
            Assert-False $step.Checked "$id no debería venir marcado"
            Assert-True ([bool]$step.Warning) "$id tiene que avisar"
        }
    }

    It 'el DNS fijo de Google tiene su paso de vuelta a DHCP, detrás de ellos y antes del vaciado final' {
        # SECURITY.md §11, riesgo 8. Va en la fase 3, después de los dos
        # de Google (marcado junto a ellos los anula: de ahí el aviso) y
        # antes de 'dns-flush-final', que limpia con el DNS ya devuelto.
        $pasos = @((Get-InternetCategory).Steps)
        $ids = @($pasos | ForEach-Object { $_.Id })
        $i = [array]::IndexOf($ids, 'dns-dhcp')
        Assert-True ($i -ge 0) 'falta el paso dns-dhcp'
        $paso = $pasos[$i]

        Assert-Equal 'exe' $paso.Kind
        Assert-Equal 'netsh.exe' $paso.Exe
        Assert-Equal 'interface ip set dns name=Ethernet source=dhcp' (@($paso.Arguments) -join ' ')
        Assert-True $paso.RequiresAdmin 'cambiar el DNS del adaptador pide administrador'
        Assert-True (Test-CommandStepAllowed $paso) 'tiene que pasar la lista blanca tal como está'
        Assert-Equal $pasos[[array]::IndexOf($ids, 'dns-primary')].Group $paso.Group 'misma fase que los de Google'
        Assert-True ($i -gt [array]::IndexOf($ids, 'dns-secondary')) 'tiene que ir detrás de los de Google'
        Assert-True ($i -lt [array]::IndexOf($ids, 'dns-flush-final')) 'tiene que ir antes del vaciado final de la caché'
        Assert-Match 'Google' $paso.Warning 'el aviso tiene que decir que anula los de Google'
    }

    It 'los reset de la pila piden reiniciar' {
        foreach ($id in 'ipv4-reset', 'winsock-reset', 'ip-reset') {
            $step = @((Get-InternetCategory).Steps) | Where-Object { $_.Id -eq $id }
            Assert-True $step.RequiresRestart "$id"
        }
    }
}

Describe 'ui/Data/Categories/Cleanup.ps1 - los pasos' {

    It 'la sección existe, va justo debajo de Internet y trae los pasos del .cmd' {
        $cat = Get-CategoryById 'cleanup'
        Assert-NotNull $cat
        Assert-True (@($cat.Steps).Count -ge 10) 'faltan pasos'
        Assert-Equal 0 @($cat.Items).Count 'una sección de comandos no tiene ajustes'

        $orden = @(Get-OptimizationCategories | ForEach-Object { $_.Id })
        Assert-Equal ([array]::IndexOf($orden, 'internet') + 1) ([array]::IndexOf($orden, 'cleanup'))
    }

    It 'cada paso tiene un Id único y sus líneas del log caen en "cleanup"' {
        $pasos = @((Get-CategoryById 'cleanup').Steps)
        $ids = @($pasos | ForEach-Object { $_.Id })
        Assert-Equal $ids.Count @($ids | Select-Object -Unique).Count
        foreach ($p in $pasos) { Assert-Equal 'cleanup' $p.Source $p.Id }
    }

    It 'lo que se puede echar de menos viene desmarcado y con aviso' {
        foreach ($id in 'recycle-bin', 'recent-items', 'legacy-cookies', 'webcache-logs') {
            $step = @((Get-CategoryById 'cleanup').Steps) | Where-Object { $_.Id -eq $id }
            Assert-False $step.Checked "$id no debería venir marcado"
            Assert-True ([bool]$step.Warning) "$id tiene que avisar"
        }
    }

    It 'vaciar carpetas del perfil no pide administrador; C:\Windows\Temp, DISM, cleanmgr, fsutil y defrag, sí' {
        foreach ($step in @((Get-CategoryById 'cleanup').Steps)) {
            $esperado = $step.Kind -eq 'exe' -or $step.Id -eq 'windows-temp'
            Assert-Equal $esperado $step.RequiresAdmin "$($step.Id) ($($step.Kind))"
        }
    }

    It 'correrla desarmada pasa por todos los marcados, en orden, sin borrar nada' {
        $null = New-AppWindow -Language 'en'
        $cat = Get-CategoryById 'cleanup'
        Set-StepSelection -Category $cat -Mode 'all'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        Clear-AppLog
        Assert-True (Start-StepRun -Category $cat)
        Complete-TestStepRun

        $corridos = @(Get-AppLog -Source 'cleanup' | Where-Object { $_.Status -eq 'running' -and $_.Message -notlike 'Run started*' } | ForEach-Object { $_.Message })
        $esperados = @(@($cat.Steps) | ForEach-Object { Format-CommandLine $_ })
        Assert-Equal ($esperados -join ' | ') ($corridos -join ' | ')
        foreach ($p in @($cat.Steps)) { Assert-Equal 'disarmed' $p.Status $p.Id }
        Set-StepSelection -Category $cat -Mode 'default'
    }
}

Describe 'ui/Data/Categories/Power.ps1 - el plan Máximo rendimiento' {

    It 'Energía es una sección de comandos: añadir el plan y activarlo, en ese orden' {
        $cat = Get-CategoryById 'power'
        Assert-Equal 0 @($cat.Items).Count
        Assert-Equal 'ultimate-plan-add | ultimate-plan-activate' ((@($cat.Steps) | ForEach-Object { $_.Id }) -join ' | ')
    }

    It 'la copia va siempre al mismo GUID, se salta si ya existe y se activa ese mismo' {
        # Sin GUID de destino, cada ejecución dejaba otro plan
        # "Máximo rendimiento" en Opciones de energía.
        $pasos = @((Get-CategoryById 'power').Steps)
        $copia = @($pasos[0].Arguments)
        Assert-Equal '/duplicatescheme' $copia[0]
        Assert-Equal 'e9a42b02-d5df-448d-aa00-03f14749eb61' $copia[1] 'la plantilla oculta de Ultimate Performance'
        $destino = $copia[2]
        Assert-Match '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' $destino 'falta el GUID de destino fijo'

        Assert-Match ([regex]::Escape("PowerSchemes\$destino") + '$') $pasos[0].SkipIf.Path
        Assert-Equal 'FriendlyName' $pasos[0].SkipIf.Name
        Assert-Equal "/setactive $destino" (@($pasos[1].Arguments) -join ' ')
    }

    It 'activarlo avisa del gasto de batería' {
        Assert-True ([bool]@((Get-CategoryById 'power').Steps)[1].Warning)
    }
}

Describe 'ui/Views/CategoryStepsView.ps1 - la pantalla' {

    It 'abrir Internet pinta la lista de pasos y el marco fijo, no ajustes' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        Assert-Equal 'Show-CategoryDetailView' (Get-CurrentViewName) 'el enrutador tiene que seguir en el detalle'
        Assert-Equal @($cat.Steps).Count (Get-StepRows $ventana).Count
        $dock = $ventana.FindName('ContentDock')
        Assert-Equal 1 $dock.Children.Count 'el marco va en el hueco fijo'
        Assert-True ([object]::ReferenceEquals($dock.Children[0], $ventana.FindName('StepRunPanel')))
    }

    It 'al salir de la sección el hueco fijo se vacía' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-InternetCategory) }
        Show-View -Name 'Show-OptimizationsListView'
        Assert-Equal 0 $ventana.FindName('ContentDock').Children.Count
    }

    It 'las filas salen numeradas en el orden del archivo' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        $filas = Get-StepRows $ventana
        for ($i = 0; $i -lt $filas.Count; $i++) {
            Assert-Equal @($cat.Steps)[$i].Id $filas[$i].Tag.Step.Id "fila $i"
        }
    }

    It 'pulsar una fila la marca y la desmarca' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Set-StepSelection -Category $cat -Mode 'default'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        $fila = (Get-StepRows $ventana)[0]
        $antes = [bool]$fila.Tag.Step.Selected

        Switch-StepSelection $fila
        Assert-Equal (-not $antes) ([bool]$fila.Tag.Step.Selected)
        Switch-StepSelection $fila
        Assert-Equal $antes ([bool]$fila.Tag.Step.Selected)
    }

    It 'la tarjeta de la lista cuenta los pasos marcados' {
        $cat = Get-InternetCategory
        Set-StepSelection -Category $cat -Mode 'all'
        $texto = Get-VisualText (New-CategoryStats $cat)
        Assert-Match ('{0}/{0}' -f @($cat.Steps).Count) $texto
        Set-StepSelection -Category $cat -Mode 'default'
    }
}

Describe 'ui/Components/Layout/StepRunPanel.ps1 - ejecutar' {

    It 'sin nada marcado no arranca' {
        $null = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Set-StepSelection -Category $cat -Mode 'none'
        Assert-False (Start-StepRun -Category $cat)
        Assert-False (Get-StepRunActive)
        Set-StepSelection -Category $cat -Mode 'default'
    }

    It 'corre SOLO lo marcado y SIEMPRE en el orden del archivo' {
        $null = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        # Se marcan tres pasos "al revés": el último primero.
        Set-StepSelection -Category $cat -Mode 'none'
        $pasos = @($cat.Steps)
        foreach ($i in 20, 8, 4) { $pasos[$i].Selected = $true }

        Clear-AppLog
        Assert-True (Start-StepRun -Category $cat)
        Complete-TestStepRun

        $corridos = @(Get-AppLog -Source 'internet' | Where-Object { $_.Status -eq 'running' -and $_.Message -notlike 'Run started*' } | ForEach-Object { $_.Message })
        $esperados = @(4, 8, 20 | ForEach-Object { Format-CommandLine $pasos[$_] })
        Assert-Equal ($esperados -join ' | ') ($corridos -join ' | ')

        foreach ($i in 0..($pasos.Count - 1)) {
            if ($i -in 4, 8, 20) { Assert-Equal 'disarmed' $pasos[$i].Status "paso $i" }
            else { Assert-Null $pasos[$i].Status "el paso $i no estaba marcado" }
        }
        Assert-Equal 'done' (Get-StepRunState).Phase
        Set-StepSelection -Category $cat -Mode 'default'
    }

    It 'mientras corre no se cambia la selección' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Set-StepSelection -Category $cat -Mode 'default'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        Start-StepRun -Category $cat | Out-Null
        try {
            $fila = (Get-StepRows $ventana)[1]
            $antes = $fila.Tag.Step.Selected
            Switch-StepSelection $fila
            Assert-Equal $antes $fila.Tag.Step.Selected
            Set-StepSelection -Category $cat -Mode 'none'
            Assert-True (@($cat.Steps | Where-Object { $_.Selected }).Count -gt 0) 'la selección en bloque no puede vaciar la cola en marcha'
            Assert-False $fila.IsEnabled 'las filas se apagan mientras corre'
        }
        finally { Stop-StepRun }
    }

    It 'detener corta y deja lo pendiente como omitido' {
        $null = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Set-StepSelection -Category $cat -Mode 'all'
        Start-StepRun -Category $cat | Out-Null
        Invoke-StepRunTick
        Stop-StepRun

        Assert-False (Get-StepRunActive)
        Assert-Equal 'cancelled' (Get-StepRunState).Phase
        Assert-True (@($cat.Steps | Where-Object { $_.Status -eq 'skipped' }).Count -gt 0) 'nada quedó omitido'
        Assert-Equal 'cancelled' (@(Get-AppLog -Source 'internet')[-1].Status)
        Set-StepSelection -Category $cat -Mode 'default'
    }

    It 'el botón dice Ejecutar N parado y Detener mientras corre' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        Set-StepSelection -Category $cat -Mode 'default'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        $n = @($cat.Steps | Where-Object { $_.Selected }).Count

        Assert-Equal "Run $n" $ventana.FindName('StepRunButton').Tag.Text.Text
        Start-StepRun -Category $cat | Out-Null
        try { Assert-Equal 'Stop' $ventana.FindName('StepRunButton').Tag.Text.Text }
        finally { Stop-StepRun }
    }

    It 'una sección bloqueada no se ejecuta' {
        $null = New-AppWindow -Language 'en'
        $cat = Get-InternetCategory
        $cat.Locked = $true
        try { Assert-False (Start-StepRun -Category $cat) }
        finally { $cat.Locked = $false }
    }
}

Describe 'ui/Components/Cards/StepRow.ps1 - sin permisos de administrador' {

    It 'solo tres pasos funcionan sin administrador, y son los comprobados' {
        $libres = @(@((Get-InternetCategory).Steps) | Where-Object { -not $_.RequiresAdmin } | ForEach-Object { $_.Id })
        Assert-Equal 'dns-flush | dns-flush-final | show-interfaces' (($libres | Sort-Object) -join ' | ')
    }

    It 'sin permisos, lo que pide administrador sale desmarcado, apagado y avisando' {
        Set-AppElevationOverride $false
        try {
            $ventana = New-AppWindow -Language 'en'
            $cat = Get-InternetCategory
            Set-StepSelection -Category $cat -Mode 'all'
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

            foreach ($fila in Get-StepRows $ventana) {
                $step = $fila.Tag.Step
                if ($step.RequiresAdmin) {
                    Assert-False $fila.IsEnabled "$($step.Id) tiene que estar apagado"
                    Assert-Equal (Glyph 'CheckOff') $fila.Tag.Check.Text "$($step.Id) tiene que salir desmarcado"
                    Assert-Match 'administrator' (Get-VisualText $fila) "$($step.Id) tiene que decir por qué"
                }
                else {
                    Assert-True $fila.IsEnabled "$($step.Id) funciona sin permisos"
                }
            }
            Assert-Match 'Run 3' $ventana.FindName('StepRunButton').Tag.Text.Text
        }
        finally {
            Set-AppElevationOverride $true
            Set-StepSelection -Category (Get-InternetCategory) -Mode 'default'
        }
    }

    It 'sin permisos, pulsar un paso que pide administrador no lo marca' {
        Set-AppElevationOverride $false
        try {
            $ventana = New-AppWindow -Language 'en'
            $cat = Get-InternetCategory
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
            $fila = Get-StepRows $ventana | Where-Object { $_.Tag.Step.Id -eq 'winsock-reset' }
            Switch-StepSelection $fila
            Assert-False (Test-StepSelected $fila.Tag.Step)
        }
        finally { Set-AppElevationOverride $true }
    }

    It 'sin permisos, la cola lleva solo lo que puede correr' {
        Set-AppElevationOverride $false
        try {
            $null = New-AppWindow -Language 'en'
            $cat = Get-InternetCategory
            Set-StepSelection -Category $cat -Mode 'all'
            Start-StepRun -Category $cat | Out-Null
            Assert-Equal 3 @((Get-StepRunState).Queue).Count
            Complete-TestStepRun
            foreach ($s in @($cat.Steps)) {
                if ($s.RequiresAdmin) { Assert-Null $s.Status "$($s.Id) no debió entrar en la cola" }
            }
        }
        finally {
            Set-AppElevationOverride $true
            Set-StepSelection -Category (Get-InternetCategory) -Mode 'default'
        }
    }
}

Describe 'ui/Components/Shell/TitleBar.ps1 - la insignia de administrador' {

    It 'con permisos dice Administrador en verde' {
        $ventana = New-AppWindow -Language 'es'
        Update-TitleBarTexts $ventana
        Assert-Equal 'Administrador' $ventana.FindName('AdminBadgeText').Text
        Assert-Equal (Glyph 'Shield') $ventana.FindName('AdminBadgeIcon').Text
        Set-AppLanguage 'en'
    }

    It 'sin permisos dice Sin administrador y explica qué pasa' {
        Set-AppElevationOverride $false
        try {
            $ventana = New-AppWindow -Language 'es'
            Update-TitleBarTexts $ventana
            Assert-Equal 'Sin administrador' $ventana.FindName('AdminBadgeText').Text
            Assert-Match 'desactivadas' ([string]$ventana.FindName('AdminBadge').ToolTip)
        }
        finally {
            Set-AppElevationOverride $true
            Set-AppLanguage 'en'
        }
    }
}

Describe 'ui/Engine/CategoryRegistry.ps1 - los pasos marcados se recuerdan' {

    It 'lo que el usuario cambia se guarda y vuelve igual al arrancar' {
        $cat = Get-CategoryById 'cleanup'
        try {
            Set-StepSelection -Category $cat -Mode 'default'
            $dism = @($cat.Steps) | Where-Object { $_.Id -eq 'trim-on' }
            $temp = @($cat.Steps) | Where-Object { $_.Id -eq 'temp-user' }
            $dism.Selected = $false
            $temp.Selected = $false
            Save-StepChoices $cat
            Assert-Equal 'trim-on | temp-user' ((@(Get-AppSetting 'StepChoices.cleanup') | Sort-Object -Descending) -join ' | ')

            # "Arrancar": todo como viene de serie, y luego restaurar.
            foreach ($s in @($cat.Steps)) { $s.Selected = $s.Checked }
            Restore-StepChoices
            Assert-False $dism.Selected 'TRIM debería volver desmarcado'
            Assert-False $temp.Selected 'los temporales deberían volver desmarcados'
        }
        finally { Set-StepSelection -Category $cat -Mode 'default' }
    }

    It 'un paso con aviso nunca se restaura marcado: empieza como viene declarado' {
        # settings.json lo escribe cualquier programa del usuario sin ser
        # administrador: no puede dejar marcado el reset del firewall.
        $cat = Get-CategoryById 'internet'
        try {
            Set-AppSetting 'StepChoices.internet' @('firewall-reset')
            Restore-StepChoices
            Assert-False (@($cat.Steps) | Where-Object { $_.Id -eq 'firewall-reset' }).Selected
        }
        finally { Set-StepSelection -Category $cat -Mode 'default' }
    }

    It 'volver a DHCP tampoco se restaura marcado: no puede colarse junto a los de Google' {
        $cat = Get-CategoryById 'internet'
        try {
            Set-AppSetting 'StepChoices.internet' @('dns-primary', 'dns-secondary', 'dns-dhcp')
            Restore-StepChoices
            foreach ($id in 'dns-primary', 'dns-secondary', 'dns-dhcp') {
                Assert-False (@($cat.Steps) | Where-Object { $_.Id -eq $id }).Selected "$id no debería volver marcado"
            }
        }
        finally { Set-StepSelection -Category $cat -Mode 'default' }
    }

    It 'un paso que no se tocó sale como venga declarado' {
        $cat = Get-CategoryById 'cleanup'
        try {
            Set-AppSetting 'StepChoices.cleanup' @('recycle-bin')
            foreach ($s in @($cat.Steps)) { $s.Selected = -not $s.Checked }
            Restore-StepChoices
            $otros = @($cat.Steps | Where-Object { $_.Id -ne 'recycle-bin' -and $_.Selected -ne $_.Checked })
            Assert-Equal 0 $otros.Count 'un paso que nadie cambió no sale como venía'
        }
        finally { Set-StepSelection -Category $cat -Mode 'default' }
    }

    It 'pulsar una fila lo guarda' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-CategoryById 'power'
        try {
            Set-StepSelection -Category $cat -Mode 'default'
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
            $fila = @($ventana.FindName('StepList').Children | Where-Object { $_.Tag -and $_.Tag.PSObject.Properties['Step'] })[1]
            Switch-StepSelection $fila
            Assert-Equal 'ultimate-plan-activate' ([string]@(Get-AppSetting 'StepChoices.power')[0])
        }
        finally { Set-StepSelection -Category $cat -Mode 'default' }
    }
}
