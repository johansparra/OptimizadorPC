# ============================================================
# Pruebas de core/ScheduledTasks/ScheduledTaskState.ps1 — si una
# tarea programada está habilitada.
#
# LAS PRUEBAS NUNCA CAMBIAN UNA TAREA. Se lee de verdad, y la
# escritura se prueba desarmada (el arnés) o armada con -WhatIf, con
# la misma red de seguridad que tests/Core/ServiceStartup.Tests.ps1.
#
# Para leer una tarea que exista en cualquier Windows 10/11 se usa
# \Microsoft\Windows\Autochk\Proxy, que además es de la lista blanca.
# ============================================================

$TaskTestPath = '\Microsoft\Windows\Autochk\'
$TaskTestName = 'Proxy'

Describe 'core/ScheduledTasks/ScheduledTaskState.ps1 - la lista blanca' {

    It 'las seis tareas de la sección están permitidas, por ruta y nombre exactos' {
        Assert-Equal 6 @($ScheduledTaskWriteAllowlist).Count
        foreach ($t in $ScheduledTaskWriteAllowlist) {
            Assert-True (Test-ScheduledTaskWriteAllowed -Path $t.Path -Name $t.Name) "$($t.Path)$($t.Name)"
        }
    }

    It 'otra tarea de la misma carpeta, o el nombre en otra carpeta, no' {
        Assert-False (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\Autochk\' -Name 'Otra')
        Assert-False (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\' -Name 'Proxy')
        Assert-False (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\Autochk\Sub\' -Name 'Proxy')
        Assert-False (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\Application Experience\' -Name 'Microsoft Compatibility Appraiser Exp')
    }

    It 'los comodines no pasan: Get-ScheduledTask los expandiría' {
        foreach ($par in @(
                @('\Microsoft\Windows\Autochk\', '*'),
                @('\Microsoft\Windows\Autochk\', 'Pro?y'),
                @('\Microsoft\Windows\*\', 'Proxy'),
                @('\Microsoft\Windows\Autochk\', '[P]roxy'),
                @('Microsoft\Windows\Autochk\', 'Proxy'),
                @('\Microsoft\Windows\Autochk', 'Proxy'),
                @('\Microsoft\..\Autochk\', 'Proxy'),
                @('', 'Proxy'))) {
            Assert-False (Test-ScheduledTaskTargetValid -Path $par[0] -Name $par[1]) "no debería valer: '$($par[0])$($par[1])'"
        }
    }

    It 'una carpeta protegida se rechaza aunque estuviera en la lista blanca' {
        $antes = $script:ScheduledTaskWriteAllowlist
        try {
            $script:ScheduledTaskWriteAllowlist = @($antes) + @(
                @{ Path = '\Microsoft\Windows\WindowsUpdate\'; Name = 'Scheduled Start' }
                @{ Path = '\Microsoft\Windows\Windows Defender\'; Name = 'Windows Defender Scheduled Scan' }
                @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'OtraDePrueba' })
            # La lista ampliada se está usando de verdad.
            Assert-True (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\Autochk\' -Name 'OtraDePrueba') 'la lista blanca ampliada no ha llegado a core/'
            Assert-False (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\WindowsUpdate\' -Name 'Scheduled Start')
            Assert-False (Test-ScheduledTaskWriteAllowed -Path '\Microsoft\Windows\Windows Defender\' -Name 'Windows Defender Scheduled Scan')
        }
        finally { $script:ScheduledTaskWriteAllowlist = $antes }
    }
}

Describe 'core/ScheduledTasks/ScheduledTaskState.ps1 - leer' {

    It 'lee una tarea que existe' {
        $r = Get-ScheduledTaskEnabledRaw -Path $TaskTestPath -Name $TaskTestName
        if ($r.State -eq 'unavailable') { Skip-Test 'el módulo ScheduledTasks no carga en este host' }
        Assert-Contains $r.State @('read', 'denied')
        if ($r.State -eq 'read') { Assert-Contains $r.Value @('Enabled', 'Disabled') }
    }

    It 'una tarea que no existe es missing, no una excepción' {
        $r = Get-ScheduledTaskEnabledRaw -Path '\Microsoft\Windows\Autochk\' -Name 'OptimizadorPCNoExiste'
        if ($r.State -eq 'unavailable') { Skip-Test 'el módulo ScheduledTasks no carga en este host' }
        Assert-Equal 'missing' $r.State
    }

    It 'las seis de la sección se leen sin lanzar, con un estado válido' {
        foreach ($t in $ScheduledTaskWriteAllowlist) {
            $r = Get-ScheduledTaskEnabledRaw -Path $t.Path -Name $t.Name
            Assert-Contains $r.State @('read', 'missing', 'denied', 'unavailable') "$($t.Path)$($t.Name)"
        }
    }

    It 'una ruta sin forma válida es badname' {
        Assert-Equal 'badname' (Get-ScheduledTaskEnabledRaw -Path '\Microsoft\*\' -Name 'Proxy').State
    }

    It 'rellena State y Current en la entrada, y el estado sale igual que en el registro' {
        $entrada = @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'OptimizadorPCNoExiste'; Recommended = 'Disabled'; Default = 'Enabled' }
        Update-ScheduledTaskEntryState $entrada | Out-Null
        if ($entrada.State -eq 'unavailable') { Skip-Test 'el módulo ScheduledTasks no carga en este host' }
        Assert-Equal 'missing' $entrada.State
        Assert-Null $entrada.Current
        # Ausente cuenta como de fábrica, como un valor del registro.
        Assert-Equal 'factory' (Get-RegistryKeyStatus $entrada)
    }

    It 'leer deja su línea en el log' {
        Clear-AppLog
        Read-ScheduledTaskEnabled -Path $TaskTestPath -Name $TaskTestName | Out-Null
        $e = @(Get-AppLog -Source 'tasks')
        Assert-Equal 1 $e.Count
        Assert-Match 'Autochk' $e[0].Message
    }
}

Describe 'core/ScheduledTasks/ScheduledTaskState.ps1 - escribir (sin tocar nada)' {

    It 'el arnés la deja desarmada' {
        Assert-False (Get-ScheduledTaskWriteArmed)
    }

    It 'desarmada devuelve disarmed' {
        $r = Set-ScheduledTaskEnabled -Path $TaskTestPath -Name $TaskTestName -State 'Disabled' -Requested 'ON'
        Assert-Equal 'disarmed' $r.State
    }

    It 'nunca lanza, ni con entradas imposibles' {
        Assert-NoThrow { Set-ScheduledTaskEnabled -Path '' -Name '' -State '' | Out-Null }
    }

    It 'armada: fuera de la lista, protegida, comodín o estado raro se rechazan antes de tocar nada' {
        Set-ScheduledTaskWriteArmed $true
        try {
            Assert-Equal 'blocked'     (Set-ScheduledTaskEnabled -Path '\Microsoft\Windows\WindowsUpdate\' -Name 'Scheduled Start' -State 'Disabled' -WhatIf).State
            Assert-Equal 'badname'     (Set-ScheduledTaskEnabled -Path $TaskTestPath -Name '*' -State 'Disabled' -WhatIf).State
            Assert-Equal 'unsupported' (Set-ScheduledTaskEnabled -Path $TaskTestPath -Name $TaskTestName -State 'Running' -WhatIf).State
        }
        finally { Set-ScheduledTaskWriteArmed $false }
    }

    It 'armada con -WhatIf no cambia la tarea' {
        $antes = Get-ScheduledTaskEnabledRaw -Path $TaskTestPath -Name $TaskTestName
        if ($antes.State -ne 'read') { Skip-Test "la tarea no se puede leer en este equipo ($($antes.State))" }
        $destino = if ($antes.Value -eq 'Enabled') { 'Disabled' } else { 'Enabled' }

        Set-ScheduledTaskWriteArmed $true
        try {
            $r = Set-ScheduledTaskEnabled -Path $TaskTestPath -Name $TaskTestName -State $destino -WhatIf
            Assert-Equal 'nochange' $r.State
            Assert-Equal $antes.Value (Get-ScheduledTaskEnabledRaw -Path $TaskTestPath -Name $TaskTestName).Value '-WhatIf ha cambiado la tarea'
        }
        finally {
            Set-ScheduledTaskWriteArmed $false
            $ahora = Get-ScheduledTaskEnabledRaw -Path $TaskTestPath -Name $TaskTestName
            if ($ahora.State -eq 'read' -and $ahora.Value -ne $antes.Value) {
                if ($antes.Value -eq 'Enabled') { Enable-ScheduledTask -TaskPath $TaskTestPath -TaskName $TaskTestName -ErrorAction SilentlyContinue | Out-Null }
                else { Disable-ScheduledTask -TaskPath $TaskTestPath -TaskName $TaskTestName -ErrorAction SilentlyContinue | Out-Null }
            }
        }
    }
}
