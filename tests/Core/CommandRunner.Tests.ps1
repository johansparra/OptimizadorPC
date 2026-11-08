# ============================================================
# Pruebas de core/Commands/CommandRunner.ps1 — ejecutar los pasos de
# una sección de comandos.
#
# El arnés lo DESARMA (tests/Harness/AppHost.ps1): ninguna prueba
# resetea la red de la máquina. La única que arranca un proceso de
# verdad lo rearma un momento con el único paso de SOLO LECTURA de la
# sección Internet (netsh interface show interface).
# ============================================================

function New-TestStep {
    param([string]$Exe = 'netsh.exe', [string[]]$Arguments = @('interface', 'show', 'interface'), [string]$Service)
    if ($Service) {
        return (New-CommandStep -Id 'test-svc' -Name 'Test' -Description 'Test' -Service $Service)
    }
    New-CommandStep -Id 'test' -Name 'Test' -Description 'Test' -Exe $Exe -Arguments $Arguments
}

Describe 'core/Commands/CommandRunner.ps1 - qué se deja ejecutar' {

    It 'los ejecutables permitidos salen por su ruta completa en la carpeta de sistema' {
        $sistema = [Environment]::GetFolderPath('System')
        foreach ($exe in $CommandAllowedExecutables) {
            $ruta = Resolve-CommandExecutable $exe
            Assert-NotNull $ruta "no resuelve $exe"
            Assert-Equal $sistema (Split-Path $ruta -Parent) "$exe tiene que salir de la carpeta de sistema"
        }
    }

    It 'no hay intérpretes ni nada fuera de la lista' {
        foreach ($exe in 'cmd.exe', 'powershell.exe', 'pwsh.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'rundll32.exe', 'sc.exe', 'reg.exe', 'notepad.exe') {
            Assert-Null (Resolve-CommandExecutable $exe) "no debería permitir $exe"
        }
    }

    It 'una ruta, aunque apunte a un ejecutable permitido, no vale: solo el nombre' {
        Assert-Null (Resolve-CommandExecutable 'C:\Windows\System32\netsh.exe')
        Assert-Null (Resolve-CommandExecutable '.\netsh.exe')
        Assert-Null (Resolve-CommandExecutable '..\netsh.exe')
        Assert-Null (Resolve-CommandExecutable '')
    }

    It 'el nombre no distingue mayúsculas' {
        Assert-NotNull (Resolve-CommandExecutable 'NETSH.EXE')
    }

    It 'un argumento con comillas o saltos de línea se rechaza' {
        Assert-True  (Test-CommandStepAllowed (New-TestStep))
        Assert-False (Test-CommandStepAllowed (New-TestStep -Arguments @('interface', 'show "x"')))
        Assert-False (Test-CommandStepAllowed (New-TestStep -Arguments @("interface`nshow")))
        Assert-False (Test-CommandStepAllowed (New-TestStep -Exe 'cmd.exe' -Arguments @('/c', 'dir')))
    }

    It 'solo se arrancan los servicios de la lista' {
        Assert-True  (Test-CommandStepAllowed (New-TestStep -Service 'Dhcp'))
        Assert-True  (Test-CommandStepAllowed (New-TestStep -Service 'dnscache'))
        Assert-False (Test-CommandStepAllowed (New-TestStep -Service 'WinDefend'))
        Assert-False (Test-CommandStepAllowed (New-TestStep -Service 'mpssvc'))
    }

    It 'vaciar una carpeta solo vale con una entrada de la lista, tal cual' {
        Assert-True  (Test-CommandStepAllowed (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%TEMP%'))
        Assert-True  (Test-CommandStepAllowed (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.db'))
        Assert-False (Test-CommandStepAllowed (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%LOCALAPPDATA%\Microsoft'))
        Assert-False (Test-CommandStepAllowed (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean 'C:\Windows\Temp'))
        Assert-True  (Test-CommandStepAllowed (New-CommandStep -Id 'r' -Name 'T' -Description 'T' -EmptyRecycleBin))
    }

    It 'borrar en tu carpeta no pide administrador; un programa, sí' {
        Assert-False (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%TEMP%').RequiresAdmin
        Assert-False (New-CommandStep -Id 'r' -Name 'T' -Description 'T' -EmptyRecycleBin).RequiresAdmin
        Assert-True  (New-TestStep).RequiresAdmin
    }

    It 'un paso sin forma conocida no se ejecuta' {
        Assert-False (Test-CommandStepAllowed $null)
        Assert-False (Test-CommandStepAllowed ([PSCustomObject]@{ Kind = 'script'; Exe = 'netsh.exe' }))
    }
}

Describe 'core/Commands/CommandRunner.ps1 - ejecutar' {

    It 'desarmado no arranca nada y lo dice' {
        Assert-False (Get-CommandRunArmed) 'el arnés tendría que haberlo desarmado'
        $r = Invoke-CommandStep (New-TestStep)
        Assert-Equal 'disarmed' $r.State
    }

    It 'un paso fuera de la lista termina en blocked, sin lanzar' {
        Assert-NoThrow { Invoke-CommandStep (New-TestStep -Exe 'cmd.exe' -Arguments @('/c', 'exit')) }
        $r = Invoke-CommandStep (New-TestStep -Exe 'cmd.exe' -Arguments @('/c', 'exit'))
        Assert-Equal 'blocked' $r.State
    }

    It 'cada paso deja su línea en el registro de actividad' {
        Clear-AppLog
        Invoke-CommandStep (New-TestStep) | Out-Null
        $lineas = @(Get-AppLog -Source 'commands')
        Assert-True ($lineas.Count -ge 2) 'falta el inicio o el final'
        Assert-Equal 'running' $lineas[0].Status
        Assert-Equal 'netsh interface show interface' $lineas[0].Message
        Assert-Equal 'disarmed' $lineas[-1].Status
    }

    It 'armado ejecuta de verdad el paso de solo lectura y recoge su salida' {
        Set-CommandRunArmed $true
        try {
            $r = Invoke-CommandStep (New-TestStep)
        }
        finally { Set-CommandRunArmed $false }

        Assert-Equal 'succeeded' $r.State "netsh devolvió $($r.ExitCode): $($r.Output)"
        Assert-Equal 0 $r.ExitCode
        Assert-True ($r.Output.Length -gt 0) 'la salida llegó vacía'
    }

    It 'desarmado, ni se vacía la carpeta ni la papelera' {
        foreach ($step in (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%TEMP%'),
                          (New-CommandStep -Id 'r' -Name 'T' -Description 'T' -EmptyRecycleBin)) {
            $h = Start-CommandStep $step
            Assert-Null $h.Job "$($step.Kind): desarmado no debería preparar ningún borrado"
            Assert-Equal 'disarmed' (Complete-CommandStep $h).State
        }
    }

    It 'una carpeta fuera de la lista acaba en blocked aunque esté armado, sin borrar nada' {
        Set-CommandRunArmed $true
        try { $r = Invoke-CommandStep (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%LOCALAPPDATA%') }
        finally { Set-CommandRunArmed $false }
        Assert-Equal 'blocked' $r.State
    }

    It 'las líneas del log caen en el apartado de la sección del paso' {
        Clear-AppLog
        $step = New-TestStep
        $step.Source = 'cleanup'
        Invoke-CommandStep $step | Out-Null
        Assert-True (@(Get-AppLog -Source 'cleanup').Count -ge 2)
        Assert-Equal 0 @(Get-AppLog -Source 'commands').Count
    }

    It 'detener un paso lo deja en cancelled' {
        $h = Start-CommandStep (New-TestStep)
        $r = Stop-CommandStep $h
        Assert-True ($r.State -in @('cancelled', 'disarmed')) "quedó en $($r.State)"
    }
}

Describe 'core/Commands/CommandRunner.ps1 - cómo se enseña y se lee' {

    It 'la línea de comando se escribe como en el .cmd' {
        Assert-Equal 'netsh int ipv4 reset' (Format-CommandLine (New-TestStep -Arguments @('int', 'ipv4', 'reset')))
        Assert-Equal 'arp -d *' (Format-CommandLine (New-TestStep -Exe 'arp.exe' -Arguments @('-d', '*')))
        Assert-Equal 'service Dhcp' (Format-CommandLine (New-TestStep -Service 'Dhcp'))
        Assert-Equal 'clean %TEMP%' (Format-CommandLine (New-CommandStep -Id 'c' -Name 'T' -Description 'T' -Clean '%TEMP%'))
        Assert-Equal 'empty recycle bin' (Format-CommandLine (New-CommandStep -Id 'r' -Name 'T' -Description 'T' -EmptyRecycleBin))
        Assert-Equal 'Dism /online /Cleanup-Image /StartComponentCleanup' (Format-CommandLine (New-TestStep -Exe 'Dism.exe' -Arguments @('/online', '/Cleanup-Image', '/StartComponentCleanup')))
    }

    It 'un argumento con espacios va entre comillas; el resto, tal cual' {
        Assert-Equal 'a "b c" d' (ConvertTo-CommandArgumentString @('a', 'b c', 'd'))
    }

    It 'la salida en UTF-8 y la salida en OEM se leen las dos con sus tildes' {
        $latin1 = [System.Text.Encoding]::GetEncoding(28591)
        $texto = 'Conexi' + [char]0x00F3 + 'n de ' + [char]0x00E1 + 'rea local'

        $utf8 = $latin1.GetString([System.Text.Encoding]::UTF8.GetBytes($texto))
        Assert-Equal $texto (ConvertFrom-CommandOutput $utf8) 'desde una consola UTF-8'

        $cp = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        $oem = $latin1.GetString([System.Text.Encoding]::GetEncoding($cp).GetBytes($texto))
        Assert-Equal $texto (ConvertFrom-CommandOutput $oem) 'sin consola (el .exe)'
    }
}

Describe 'core/Commands/CommandRunner.ps1 - el detalle de un programa' {

    It 'una salida de una línea corta no da detalle: ya se ve entera en el log' {
        Assert-Equal 0 @(Get-CommandOutputItems 'Ok.').Count
        Assert-Equal 0 @(Get-CommandOutputItems '').Count
    }

    It 'una salida de varias líneas va entera al detalle, sin líneas vacías' {
        $items = @(Get-CommandOutputItems "Admin State    State`r`n`r`nEnabled        Connected   `r`nEnabled        Disconnected")
        Assert-Equal 3 $items.Count
        Assert-Equal 'Enabled        Connected' $items[1]
    }

    It 'el resultado lleva el detalle y llega al log como Items' {
        Clear-AppLog
        $r = New-CommandResult 'succeeded' 0 'ok' 1 'clean %TEMP%' @('Deleted (1 files, 1 B):', '  1 B  C:\x')
        Write-CommandResultLog $r 'cleanup'
        $e = @(Get-AppLog -Source 'cleanup')[-1]
        Assert-Equal 2 @($e.Items).Count
    }
}

Describe 'core/Commands/CommandRunner.ps1 - saltar lo que ya está hecho (-SkipIf)' {

    It 'si el valor del registro existe, el paso no se ejecuta y sale como correcto' {
        New-TestRegFixture
        Set-CommandRunArmed $true
        try {
            $paso = New-CommandStep -Id 's' -Name 'T' -Description 'T' -Exe 'netsh.exe' `
                -Arguments 'interface', 'show', 'interface' -SkipIf @{ Path = (Get-TestRegFullPath); Name = 'Texto' }
            $r = Invoke-CommandStep $paso
        }
        finally {
            Set-CommandRunArmed $false
            Remove-TestRegFixture
        }
        Assert-Equal 'succeeded' $r.State
        Assert-Match 'already in place' $r.Output
    }

    It 'si no existe, el paso corre como siempre' {
        Set-CommandRunArmed $true
        try {
            $paso = New-CommandStep -Id 's' -Name 'T' -Description 'T' -Exe 'netsh.exe' `
                -Arguments 'interface', 'show', 'interface' -SkipIf @{ Path = (Get-TestRegFullPath); Name = 'NoExiste' }
            $r = Invoke-CommandStep $paso
        }
        finally { Set-CommandRunArmed $false }
        Assert-Equal 'succeeded' $r.State
        Assert-False ($r.Output -match 'already in place') 'no debería haberse saltado'
    }

    It 'desarmado manda: aunque ya esté hecho, sale disarmed' {
        New-TestRegFixture
        try {
            $paso = New-CommandStep -Id 's' -Name 'T' -Description 'T' -Exe 'netsh.exe' `
                -Arguments 'interface', 'show', 'interface' -SkipIf @{ Path = (Get-TestRegFullPath); Name = 'Texto' }
            Assert-Equal 'disarmed' (Invoke-CommandStep $paso).State
        }
        finally { Remove-TestRegFixture }
    }

    It 'un -SkipIf a medias se rechaza al declararlo' {
        Assert-Throws { New-CommandStep -Id 's' -Name 'T' -Description 'T' -Exe 'netsh.exe' -SkipIf @{ Path = 'HKCU\x' } }
    }
}

Describe 'core/Commands/CommandRunner.ps1 - -WhatIf' {

    It 'armado y con -WhatIf, un programa no se arranca' {
        Set-CommandRunArmed $true
        try { $r = Complete-CommandStep (Start-CommandStep (New-TestStep) -WhatIf) }
        finally { Set-CommandRunArmed $false }
        Assert-Equal 'disarmed' $r.State
        Assert-Match 'WhatIf' $r.Output
    }
}
