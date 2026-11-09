# ============================================================
# Pruebas de core/Registry/SettingApply.ps1 — aplicar (ON) o
# deshacer (OFF) la optimización de un ajuste.
#
# Es lo que dispara el toggle de la tarjeta:
#   ON  -> escribe el Recommended de cada clave
#   OFF -> escribe el Default, o BORRA el valor si de fábrica no
#          existe (DefaultAbsent) o no existía al tocarlo
# y deja el ajuste con su Status recalculado.
#
# Contra la rama de pruebas HKCU (tests/Harness/Fixtures.ps1). El
# arnés desarma la escritura; aquí se rearma y se vuelve a
# desarmar al final.
# ============================================================

New-TestRegFixture
Set-RegistryWriteArmed $true

Describe 'core/Registry/SettingApply.ps1 - aplicar y deshacer' {

    It 'ON escribe el Recommended y deja el ajuste optimizado' {
        $key = New-TestKey 'ApplyOn' -Recommended '100' -Default '5'
        $cat = New-TestCategory @($key)
        $setting = @($cat.Items)[0]

        $status = Set-SettingOptimization -Setting $setting -Enabled $true

        Assert-Equal 'optimized' $status
        Assert-Equal 'optimized' $setting.Status
        Assert-Equal '100' $key.Current
        Assert-Equal 'read' $key.State
        Assert-Equal 100 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyOn').Value
    }

    It 'OFF escribe el Default si el valor existía, y deja el ajuste de fábrica' {
        # El valor ya estaba (con otro número) antes de que el programa
        # lo tocara: OFF vuelve al Default declarado.
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
        try { $rk.SetValue('ApplyOff', 7, [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $rk.Close() }

        $key = New-TestKey 'ApplyOff' -Recommended '100' -Default '5'
        $setting = @((New-TestCategory @($key)).Items)[0]

        Set-SettingOptimization -Setting $setting -Enabled $true  | Out-Null
        $status = Set-SettingOptimization -Setting $setting -Enabled $false

        Assert-Equal 'factory' $status
        Assert-Equal '5' $key.Current
        Assert-Equal 5 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyOff').Value
    }

    It 'OFF BORRA el valor si no existía antes de que el programa lo tocara' {
        # SECURITY.md §3.2.2: revertir lo que no existía es quitarlo,
        # no escribir el Default. Lo sabe por la primera copia de la
        # sesión (Writer.ps1).
        $key = New-TestKey 'ApplyOrigenAusente' -Recommended '100' -Default '5'
        $setting = @((New-TestCategory @($key)).Items)[0]

        Set-SettingOptimization -Setting $setting -Enabled $true | Out-Null
        Assert-Equal 100 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyOrigenAusente').Value

        $status = Set-SettingOptimization -Setting $setting -Enabled $false

        Assert-Equal 'missing' (Read-RegistryValueRaw (Get-TestRegFullPath) 'ApplyOrigenAusente').State
        Assert-Equal 'missing' $key.State
        Assert-Null $key.Current
        Assert-Equal 'factory' $status
    }

    It 'DefaultAbsent: OFF borra el valor aunque ya existiera, y ausente es de fábrica' {
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
        try { $rk.SetValue('ApplyDirectiva', 3, [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $rk.Close() }

        $key = @{ Path = Get-TestRegFullPath; Name = 'ApplyDirectiva'; Type = 'DWord'
                  Recommended = '1'; DefaultAbsent = $true }
        $setting = @((New-TestCategory @($key)).Items)[0]

        Assert-Equal 'optimized' (Set-SettingOptimization -Setting $setting -Enabled $true)
        Assert-Equal 1 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyDirectiva').Value

        Clear-AppLog
        $status = Set-SettingOptimization -Setting $setting -Enabled $false

        Assert-Equal 'factory' $status
        Assert-Equal 'missing' (Read-RegistryValueRaw (Get-TestRegFullPath) 'ApplyDirectiva').State
        Assert-Contains 'deleted' (@(Get-AppLog -Source 'registry') | ForEach-Object { $_.Status })
        # La clave sigue: se borra el valor, nunca la clave.
        Assert-True (Test-RegistryKeyExists (Get-TestRegFullPath))
    }

    It 'DefaultAbsent: OFF con -WhatIf no borra' {
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
        try { $rk.SetValue('ApplyDirectivaWhatIf', 1, [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $rk.Close() }

        $key = @{ Path = Get-TestRegFullPath; Name = 'ApplyDirectivaWhatIf'; Type = 'DWord'
                  Recommended = '1'; DefaultAbsent = $true }
        $setting = @((New-TestCategory @($key)).Items)[0]

        $status = Set-SettingOptimization -Setting $setting -Enabled $false -WhatIf
        Assert-Equal 'optimized' $status 'sin borrar, sigue aplicado'
        Assert-Equal 1 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyDirectivaWhatIf').Value
    }

    It 'DefaultAbsent: desarmada no borra' {
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
        try { $rk.SetValue('ApplyDirectivaDesarmada', 1, [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $rk.Close() }

        $key = @{ Path = Get-TestRegFullPath; Name = 'ApplyDirectivaDesarmada'; Type = 'DWord'
                  Recommended = '1'; DefaultAbsent = $true }
        $setting = @((New-TestCategory @($key)).Items)[0]

        Set-RegistryWriteArmed $false
        try { Set-SettingOptimization -Setting $setting -Enabled $false | Out-Null }
        finally { Set-RegistryWriteArmed $true }

        Assert-Equal 1 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyDirectivaDesarmada').Value
    }

    It 'OFF borra o escribe según lo declarado y la primera copia' {
        Clear-RegistrySnapshots
        $ruta = Get-TestRegFullPath

        # Declarado ausente: borra, haya copia o no.
        Assert-True  (Test-RegistryRestoreByDelete @{ Path = $ruta; Name = 'A'; DefaultAbsent = $true })
        # Sin copia y con Default: escribe.
        Assert-False (Test-RegistryRestoreByDelete @{ Path = $ruta; Name = 'B'; Default = '0' })

        # La primera copia vio el valor ausente: borra.
        Add-RegistrySnapshot -Path $ruta -Name 'C' -Existed $false -State 'missing'
        Assert-True  (Test-RegistryRestoreByDelete @{ Path = $ruta; Name = 'C'; Default = '0' })

        # Sin permiso para leerlo no se sabe si existía: escribe el Default.
        Add-RegistrySnapshot -Path $ruta -Name 'D' -Existed $false -State 'denied'
        Assert-False (Test-RegistryRestoreByDelete @{ Path = $ruta; Name = 'D'; Default = '0' })

        # Cuenta la PRIMERA: existía, aunque luego se borrara.
        Add-RegistrySnapshot -Path $ruta -Name 'E' -Existed $true -State 'read'
        Add-RegistrySnapshot -Path $ruta -Name 'E' -Existed $false -State 'missing'
        Assert-False (Test-RegistryRestoreByDelete @{ Path = $ruta; Name = 'E'; Default = '0' })

        Assert-False (Test-RegistryRestoreByDelete $null)
        Clear-RegistrySnapshots
    }

    It 'escribe TODAS las claves del ajuste' {
        $k1 = New-TestKey 'MultiA' -Recommended '11' -Default '0'
        $k2 = New-TestKey 'MultiB' -Recommended '22' -Default '0'
        $setting = @((New-TestCategory @($k1, $k2)).Items)[0]

        Set-SettingOptimization -Setting $setting -Enabled $true | Out-Null

        Assert-Equal 11 (Read-RegistryValue (Get-TestRegFullPath) 'MultiA').Value
        Assert-Equal 22 (Read-RegistryValue (Get-TestRegFullPath) 'MultiB').Value
        Assert-Equal 'optimized' $setting.Status
    }

    It 'un ajuste sin claves no hace nada y devuelve $null' {
        $setting = New-Setting -Name 'Sin claves' -Description 'x' -Value $true
        Assert-Null (Set-SettingOptimization -Setting $setting -Enabled $true)
    }

    It '-WhatIf recorre el camino sin escribir' {
        $key = New-TestKey 'ApplyWhatIf' -Recommended '77' -Default '0'
        $setting = @((New-TestCategory @($key)).Items)[0]

        Set-SettingOptimization -Setting $setting -Enabled $true -WhatIf | Out-Null

        Assert-Equal 'missing' (Read-RegistryValueRaw (Get-TestRegFullPath) 'ApplyWhatIf').State
    }

    It 'no lanza aunque la ruta esté fuera de la lista blanca' {
        $key = @{ Path = 'HKEY_CURRENT_USER\Software\Fuera'; Name = 'X'; Type = 'DWord'
                  Recommended = '1'; Default = '0' }
        $setting = @((New-TestCategory @($key)).Items)[0]
        Assert-NoThrow { Set-SettingOptimization -Setting $setting -Enabled $true }
        # No se ha escrito: bloqueada.
        Assert-Equal 'missing' (Read-RegistryValueRaw 'HKEY_CURRENT_USER\Software\Fuera' 'X').State
    }
}

Describe 'core/Registry/SettingApply.ps1 - rastro en el log' {

    It 'abre con applying, escribe, evalúa y cierra con done' {
        Clear-AppLog
        $key = New-TestKey 'LogApply' -Recommended '3' -Default '0'
        $setting = @((New-TestCategory @($key)).Items)[0]

        Set-SettingOptimization -Setting $setting -Enabled $true | Out-Null

        $todo = @(Get-AppLog -Source 'registry')
        $estados = $todo | ForEach-Object { $_.Status }

        Assert-Contains 'applying' $estados
        Assert-Contains 'applied'  $estados
        Assert-Contains 'checked'  $estados
        Assert-Contains 'done'     $estados

        $done = $todo | Where-Object { $_.Status -eq 'done' } | Select-Object -Last 1
        Assert-Match 'status=optimized' $done.Detail
    }
}

Set-RegistryWriteArmed $false
Remove-TestRegFixture
