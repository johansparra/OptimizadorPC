# ============================================================
# core/Diagnostics/SystemInfo.ps1
# Sobre qué está corriendo el programa: Windows, PowerShell,
# permisos y si es el .exe o el script.
#
# Es lo que se pone en un informe de fallo, y lo enseña el panel
# "Acerca de" del botón ?. Solo LEE: nada de aquí cambia el equipo.
#
# Como todo core/: no lanza nunca -un dato que no se puede leer se
# queda en 'unknown'- y devuelve hechos, no frases. Los valores son
# palabras en inglés (exe / script) que la interfaz traduce al
# pintarlas (regla 15).
# ============================================================

# Clave de la versión de Windows. Solo se lee.
$WindowsVersionKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

# Primera compilación de Windows 11.
$Windows11FirstBuild = 22000

# Lee un valor de la clave de versión, o $null.
function Get-WindowsVersionValue {
    param([string]$Name)
    $r = Read-RegistryValueRaw $WindowsVersionKey $Name
    if ($r.State -eq 'read') { $r.Value } else { $null }
}

<#
    El nombre de Windows tal y como lo diría el usuario:

        Windows 11 Pro 25H2 (build 26200.6584)

    ProductName dice "Windows 10" también en Windows 11 -Microsoft no
    lo cambió-, así que se corrige mirando la compilación. Si no se
    puede leer nada, se cae a lo que diga .NET.
#>
function Get-WindowsSummary {
    try {
        $product = [string](Get-WindowsVersionValue 'ProductName')
        $display = [string](Get-WindowsVersionValue 'DisplayVersion')
        $build   = [string](Get-WindowsVersionValue 'CurrentBuild')
        $ubr     = Get-WindowsVersionValue 'UBR'

        if (-not $product -or -not $build) {
            return [Environment]::OSVersion.VersionString
        }

        $number = 0
        if ([int]::TryParse($build, [ref]$number) -and $number -ge $Windows11FirstBuild) {
            $product = $product -replace '^Windows 10', 'Windows 11'
        }

        $text = $product
        if ($display) { $text += " $display" }
        $full = $build
        if ($null -ne $ubr) { $full += ".$ubr" }
        "$text (build $full)"
    }
    catch { 'unknown' }
}

<#
    ¿Es el .exe compilado o el script? El .exe de ps2exe es su propio
    proceso; el script corre dentro de powershell.exe o pwsh.exe.
#>
function Get-AppHostKind {
    try {
        $name = [System.Diagnostics.Process]::GetCurrentProcess().ProcessName
        if ($name -in @('powershell', 'pwsh', 'powershell_ise')) { 'script' } else { 'exe' }
    }
    catch { 'unknown' }
}

<#
    Todo junto, para enseñarlo o copiarlo:

        Windows       Windows 11 Pro 25H2 (build 26200.6584)
        PowerShell    5.1.26100.6584 (Desktop)
        HostKind      exe | script | unknown
        Elevated      $true | $false
        Architecture  64-bit | 32-bit
        DataFolder    C:\Users\...\AppData\Roaming\OptimizadorPC
#>
function Get-AppRuntimeInfo {
    $ps = 'unknown'
    try { $ps = '{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition } catch { $null = $_ }

    $arch = 'unknown'
    try { if ([Environment]::Is64BitProcess) { $arch = '64-bit' } else { $arch = '32-bit' } } catch { $null = $_ }

    $data = ''
    try { $data = Join-Path $env:APPDATA 'OptimizadorPC' } catch { $null = $_ }

    [PSCustomObject]@{
        Windows      = Get-WindowsSummary
        PowerShell   = $ps
        HostKind     = Get-AppHostKind
        Elevated     = [bool](Test-ProcessElevated)
        Architecture = $arch
        DataFolder   = $data
    }
}
