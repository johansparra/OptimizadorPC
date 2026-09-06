# ============================================================
# Pruebas de core/Registry/SettingApply.ps1 — aplicar (ON) o
# deshacer (OFF) la optimización de un ajuste.
#
# Es lo que dispara el toggle de la tarjeta:
#   ON  -> escribe el Recommended de cada clave
#   OFF -> escribe el Default
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

    It 'OFF escribe el Default y deja el ajuste de fábrica' {
        $key = New-TestKey 'ApplyOff' -Recommended '100' -Default '5'
        $setting = @((New-TestCategory @($key)).Items)[0]

        Set-SettingOptimization -Setting $setting -Enabled $true  | Out-Null
        $status = Set-SettingOptimization -Setting $setting -Enabled $false

        Assert-Equal 'factory' $status
        Assert-Equal '5' $key.Current
        Assert-Equal 5 (Read-RegistryValue (Get-TestRegFullPath) 'ApplyOff').Value
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
