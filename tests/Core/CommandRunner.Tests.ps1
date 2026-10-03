# ============================================================
# Pruebas de core/Network/CommandRunner.ps1 — ejecutar los pasos de
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

Describe 'core/Network/CommandRunner.ps1 - qué se deja ejecutar' {

    It 'los ejecutables permitidos salen por su ruta completa en la carpeta de sistema' {
        $sistema = [Environment]::GetFolderPath('System')
        foreach ($exe in 'netsh.exe', 'ipconfig.exe', 'nbtstat.exe', 'arp.exe') {
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

    It 'un paso sin forma conocida no se ejecuta' {
        Assert-False (Test-CommandStepAllowed $null)
        Assert-False (Test-CommandStepAllowed ([PSCustomObject]@{ Kind = 'script'; Exe = 'netsh.exe' }))
    }
}

Describe 'core/Network/CommandRunner.ps1 - ejecutar' {

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
        $lineas = @(Get-AppLog -Source 'network')
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

    It 'detener un paso lo deja en cancelled' {
        $h = Start-CommandStep (New-TestStep)
        $r = Stop-CommandStep $h
        Assert-True ($r.State -in @('cancelled', 'disarmed')) "quedó en $($r.State)"
    }
}

Describe 'core/Network/CommandRunner.ps1 - cómo se enseña y se lee' {

    It 'la línea de comando se escribe como en el .cmd' {
        Assert-Equal 'netsh int ipv4 reset' (Format-CommandLine (New-TestStep -Arguments @('int', 'ipv4', 'reset')))
        Assert-Equal 'arp -d *' (Format-CommandLine (New-TestStep -Exe 'arp.exe' -Arguments @('-d', '*')))
        Assert-Equal 'service Dhcp' (Format-CommandLine (New-TestStep -Service 'Dhcp'))
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
