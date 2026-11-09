# ============================================================
# Pruebas de core/Diagnostics/SystemInfo.ps1 — sobre qué corre el
# programa.
#
# Se lee el equipo de verdad, así que no se compara con valores
# fijos: se comprueba la FORMA de cada dato y que nada lance.
# ============================================================

Describe 'core/Diagnostics/SystemInfo.ps1 - sobre qué corre' {

    It 'devuelve todos los campos y no lanza' {
        Assert-NoThrow { Get-AppRuntimeInfo }
        $r = Get-AppRuntimeInfo
        foreach ($campo in 'Windows', 'PowerShell', 'HostKind', 'Elevated', 'Architecture', 'DataFolder') {
            Assert-True ($r.PSObject.Properties.Name -contains $campo) "falta el campo '$campo'"
        }
    }

    It 'el nombre de Windows trae la compilación y no dice Windows 10 en Windows 11' {
        # ProductName dice "Windows 10" también en Windows 11; se
        # corrige mirando la compilación.
        $texto = Get-WindowsSummary
        Assert-Match '^Windows ' $texto
        if ([Environment]::OSVersion.Version.Build -ge 22000) {
            Assert-Match '\(build \d+' $texto 'tiene que llevar la compilación'
            # Solo en equipos cliente: un Windows Server de la misma
            # compilación (el runner de la CI, Server 2025 = 26100) se
            # llama "Windows Server ..." y así debe seguir.
            if ([string](Get-WindowsVersionValue 'InstallationType') -eq 'Client') {
                Assert-Match '^Windows 11' $texto 'en Windows 11 tiene que decir Windows 11'
            }
            else { Assert-False ($texto -match '^Windows 1[01]') 'un Server no se renombra' }
        }
    }

    It 'las pruebas corren como script, no como el .exe' {
        Assert-Equal 'script' (Get-AppHostKind)
    }

    It 'la arquitectura y la versión de PowerShell son las del proceso' {
        $r = Get-AppRuntimeInfo
        $esperada = if ([Environment]::Is64BitProcess) { '64-bit' } else { '32-bit' }
        Assert-Equal $esperada $r.Architecture
        Assert-Match ([regex]::Escape([string]$PSVersionTable.PSVersion)) $r.PowerShell
    }

    It 'la carpeta de datos es la de AppData, la misma que la de los ajustes' {
        $r = Get-AppRuntimeInfo
        Assert-Equal (Join-Path $env:APPDATA 'OptimizadorPC') $r.DataFolder
    }
}
