# ============================================================
# Pruebas de core/Services/ServiceStartup.ps1 — el tipo de inicio de
# un servicio de Windows.
#
# LAS PRUEBAS NUNCA CAMBIAN UN SERVICIO. Se lee de verdad (un servicio
# que existe en cualquier Windows), y la escritura se prueba solo:
#   - desarmada (el arnés la deja así: tests/Harness/AppHost.ps1), o
#   - armada con -WhatIf.
# La de -WhatIf comprueba después por relectura que nada ha cambiado, y
# si cambiara (sería un fallo del mecanismo) lo devuelve a como estaba
# antes de dar la prueba por fallida.
# ============================================================

Describe 'core/Services/ServiceStartup.ps1 - la lista blanca' {

    It 'los tres servicios de la sección están permitidos' {
        foreach ($s in 'DiagTrack', 'dmwappushservice', 'SysMain') {
            Assert-True (Test-ServiceWriteAllowed $s) "'$s' debería estar en la lista blanca"
        }
        Assert-True (Test-ServiceWriteAllowed 'diagtrack') 'el nombre no distingue mayúsculas'
    }

    It 'lo que no está en la lista se rechaza' {
        foreach ($s in 'Dnscache', 'Spooler', 'lfsvc', '', 'DiagTrack2') {
            Assert-False (Test-ServiceWriteAllowed $s) "no debería permitir: '$s'"
        }
    }

    It 'un servicio protegido se rechaza aunque estuviera en la lista blanca' {
        $antes = $script:ServiceWriteAllowlist
        try {
            $script:ServiceWriteAllowlist = @($antes) + @('WinDefend', 'wuauserv', 'mpssvc', 'Spooler')
            # La lista ampliada se está usando de verdad: Spooler pasa.
            Assert-True (Test-ServiceWriteAllowed 'Spooler') 'la lista blanca ampliada no ha llegado a core/'
            foreach ($s in 'WinDefend', 'wuauserv', 'mpssvc') {
                Assert-False (Test-ServiceWriteAllowed $s) "'$s' es protegido y no debería pasar nunca"
            }
        }
        finally { $script:ServiceWriteAllowlist = $antes }
    }

    It 'un nombre con comillas, comodines o espacios no tiene forma válida' {
        foreach ($s in "Diag'Track", 'Diag*', 'Diag?', 'Diag Track', "a`nb", 'a"b', '') {
            Assert-False (Test-ServiceNameValid $s) "no debería valer: '$s'"
        }
        Assert-True (Test-ServiceNameValid 'dmwappushservice')
    }
}

Describe 'core/Services/ServiceStartup.ps1 - leer' {

    It 'lee el tipo de inicio de un servicio que existe en cualquier Windows' {
        # Winmgmt (WMI) existe siempre y es automático: sin él no
        # habría CIM con el que preguntar.
        $r = Get-ServiceStartModeRaw -Name 'Winmgmt'
        Assert-Equal 'read' $r.State
        Assert-Equal 'Automatic' $r.Value
    }

    It 'los servicios de la sección se leen sin lanzar, con un estado válido' {
        foreach ($s in 'DiagTrack', 'dmwappushservice', 'SysMain') {
            $r = Get-ServiceStartModeRaw -Name $s
            Assert-Contains $r.State @('read', 'missing', 'denied') "estado de '$s'"
            if ($r.State -eq 'read') {
                Assert-Contains $r.Value @('Automatic', 'Manual', 'Disabled') "tipo de inicio de '$s'"
            }
        }
    }

    It 'un servicio que no existe es missing, no una excepción' {
        Assert-Equal 'missing' (Get-ServiceStartModeRaw -Name 'OptimizadorPCNoExiste').State
    }

    It 'un nombre sin forma válida es badname y no llega a CIM' {
        Assert-Equal 'badname' (Get-ServiceStartModeRaw -Name "x' OR Name LIKE '%").State
    }

    It 'leer deja su línea en el log' {
        Clear-AppLog
        Read-ServiceStartMode -Name 'Winmgmt' | Out-Null
        $e = @(Get-AppLog -Source 'services')
        Assert-Equal 1 $e.Count
        Assert-Equal 'read' $e[0].Status
        Assert-Match 'Winmgmt' $e[0].Message
    }

    It 'rellena State y Current en la entrada de -Service' {
        $entrada = @{ Name = 'Winmgmt'; Recommended = 'Disabled'; Default = 'Automatic' }
        Update-ServiceEntryState $entrada | Out-Null
        Assert-Equal 'read' $entrada.State
        Assert-Equal 'Automatic' $entrada.Current
        # Y se compara con lo declarado igual que una clave del registro.
        Assert-Equal 'factory' (Get-RegistryKeyStatus $entrada)
    }
}

Describe 'core/Services/ServiceStartup.ps1 - escribir (sin tocar nada)' {

    It 'el arnés la deja desarmada' {
        Assert-False (Get-ServiceWriteArmed)
    }

    It 'desarmada devuelve disarmed y no cambia nada' {
        $antes = (Get-ServiceStartModeRaw -Name 'SysMain')
        $r = Set-ServiceStartMode -Name 'SysMain' -StartMode 'Manual' -Requested 'ON'
        Assert-Equal 'disarmed' $r.State
        Assert-Equal $antes.Value (Get-ServiceStartModeRaw -Name 'SysMain').Value
    }

    It 'nunca lanza, ni con entradas imposibles' {
        Assert-NoThrow { Set-ServiceStartMode -Name '' -StartMode '' | Out-Null }
        Assert-NoThrow { Set-ServiceStartMode -Name "a'b" -StartMode 'Disabled' | Out-Null }
    }

    It 'armada: fuera de la lista, protegido, nombre malo o tipo raro se rechazan antes de tocar nada' {
        Set-ServiceWriteArmed $true
        try {
            Assert-Equal 'blocked'     (Set-ServiceStartMode -Name 'Spooler'   -StartMode 'Disabled' -WhatIf).State
            Assert-Equal 'blocked'     (Set-ServiceStartMode -Name 'WinDefend' -StartMode 'Disabled' -WhatIf).State
            Assert-Equal 'badname'     (Set-ServiceStartMode -Name 'Diag*'     -StartMode 'Disabled' -WhatIf).State
            Assert-Equal 'unsupported' (Set-ServiceStartMode -Name 'SysMain'   -StartMode 'Boot'     -WhatIf).State
        }
        finally { Set-ServiceWriteArmed $false }
    }

    It 'armada con -WhatIf no cambia el tipo de inicio' {
        $antes = Get-ServiceStartModeRaw -Name 'SysMain'
        if ($antes.State -ne 'read') { Skip-Test "SysMain no se puede leer en este equipo ($($antes.State))" }

        # Un destino DISTINTO del actual, para que llegue hasta el -WhatIf.
        $destino = if ($antes.Value -eq 'Manual') { 'Disabled' } else { 'Manual' }

        Set-ServiceWriteArmed $true
        try {
            $r = Set-ServiceStartMode -Name 'SysMain' -StartMode $destino -Requested 'ON' -WhatIf
            $despues = Get-ServiceStartModeRaw -Name 'SysMain'
            Assert-Equal 'nochange' $r.State
            Assert-Equal $antes.Value $despues.Value '-WhatIf ha cambiado el servicio'
        }
        finally {
            Set-ServiceWriteArmed $false
            # Red de seguridad: si -WhatIf hubiera fallado, se devuelve.
            $ahora = Get-ServiceStartModeRaw -Name 'SysMain'
            if ($ahora.State -eq 'read' -and $ahora.Value -ne $antes.Value -and
                @('Automatic', 'Manual', 'Disabled') -contains $antes.Value) {
                Set-Service -Name 'SysMain' -StartupType $antes.Value -ErrorAction SilentlyContinue
            }
        }
    }

    It 'la escritura apunta una copia del estado previo antes de llegar al -WhatIf' {
        $antes = Get-ServiceStartModeRaw -Name 'SysMain'
        if ($antes.State -ne 'read') { Skip-Test "SysMain no se puede leer en este equipo ($($antes.State))" }
        $destino = if ($antes.Value -eq 'Manual') { 'Disabled' } else { 'Manual' }

        Clear-ServiceSnapshots
        Set-ServiceWriteArmed $true
        try { Set-ServiceStartMode -Name 'SysMain' -StartMode $destino -WhatIf | Out-Null }
        finally { Set-ServiceWriteArmed $false }

        $copias = @(Get-ServiceSnapshots)
        Assert-Equal 1 $copias.Count
        Assert-Equal $antes.Value $copias[0].Value
        Assert-Equal 'read' $copias[0].State
    }
}
