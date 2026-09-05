# ============================================================
# tests/Harness/Fixtures.ps1
# Los montajes que comparten varios archivos de pruebas.
#
# Aquí y no dentro de un *.Tests.ps1 para poder lanzar un archivo
# suelto (Run-Tests.ps1 -File Core/RegistryState*) sin que le
# falte la mitad de lo que necesita.
#
# Las claves de prueba se crean en HKEY_CURRENT_USER: no hace
# falta administrador y no se toca nada del sistema. Quien las
# cree las borra al terminar.
# ============================================================

# ---- Claves de prueba en el registro ------------------------

# Una rama POR PROCESO. Las dos suites -5.1 y 7- se lanzan a la
# vez con -BothHosts, y con una ruta fija la que terminase antes
# le borraria el montaje a la otra a mitad de prueba.
function Get-TestRegPath     { 'Software\OptimizadorPC\Tests\' + $PID }
function Get-TestRegFullPath { 'HKEY_CURRENT_USER\' + (Get-TestRegPath) }

<#
    Deja una rama con un valor de cada tipo que sabe leer
    core/Registry/Reader.ps1. Los dos primeros son el caso interesante:
    -1 guardado como DWord es 0xFFFFFFFF, que es justo el valor
    que .NET devuelve con signo.
#>
function New-TestRegFixture {
    Remove-TestRegFixture

    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
    try {
        $key.SetValue('Dword',      -1,                          [Microsoft.Win32.RegistryValueKind]::DWord)
        $key.SetValue('DwordCinco', 5,                           [Microsoft.Win32.RegistryValueKind]::DWord)
        $key.SetValue('Qword',      [int64]-1,                   [Microsoft.Win32.RegistryValueKind]::QWord)
        $key.SetValue('Texto',      'hola',                      [Microsoft.Win32.RegistryValueKind]::String)
        $key.SetValue('Varias',     [string[]]@('uno', 'dos'),   [Microsoft.Win32.RegistryValueKind]::MultiString)
        $key.SetValue('Binario',    [byte[]]@(1, 2, 255),        [Microsoft.Win32.RegistryValueKind]::Binary)
        $key.SetValue('Expandible', '%SystemRoot%\notepad.exe',  [Microsoft.Win32.RegistryValueKind]::ExpandString)
    }
    finally { $key.Close() }
}

function Remove-TestRegFixture {
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree((Get-TestRegPath), $false) } catch { }
    # Y el padre, si no queda nadie dentro: DeleteSubKey se queja
    # cuando aun tiene hijos -otro proceso a medias- y ahi no hay
    # nada que hacer.
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey('Software\OptimizadorPC\Tests', $false) } catch { }
}

# ---- Categorías de mentira ----------------------------------

# Una sección con un solo ajuste, para probar el volcado sin
# depender de lo que hoy declare ui/Data/Categories/.
function New-TestCategory {
    param([hashtable[]]$Keys = @())

    [PSCustomObject]@{
        Id    = 'prueba'
        Name  = 'Prueba'
        Icon  = 'Shield'
        Items = @(
            New-Setting -Name 'Ajuste de prueba' -Description 'Solo para las pruebas' `
                        -Value $true -Registry $Keys
        )
    }
}

<#
    Una clave de las de -Registry, apuntando a la rama de prueba.

    Recommended y Default son contra lo que compara
    core/Registry/SettingStatus.ps1, así que se pueden fijar para montar
    cada estado: -Recommended '5' sobre un valor que vale 5 deja el
    ajuste en 'optimized', -Default '5' en 'factory', y ninguno de los
    dos en 'custom'.
#>
function New-TestKey {
    param(
        [string]$Name,
        [string]$Display,
        [string]$Recommended = '0',
        [string]$Default = '0'
    )

    @{
        Path = Get-TestRegFullPath
        Name = $Name
        Type = 'DWord'
        Display = $Display
        Recommended = $Recommended
        Default = $Default
    }
}

# ---- Entradas de log de mentira -----------------------------

# Deja el log con N lecturas apuntadas, como si se acabara de
# entrar en una sección.
function New-TestLogEntries {
    param([int]$Count = 3)

    Clear-AppLog
    foreach ($n in 1..$Count) {
        Write-AppLog -Source 'registry' -Level 'info' -Status 'read' `
                     -Message ('HKEY_CURRENT_USER\Software\Prueba\Valor{0}' -f $n) `
                     -Detail  ('{0} (0x{0:X8}) - DWord - 0,3 ms' -f $n)
    }
}
