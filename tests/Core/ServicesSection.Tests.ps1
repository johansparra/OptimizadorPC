# ============================================================
# La sección Servicios y tareas (ui/Data/Categories/Services.ps1)
# contra el equipo de verdad, por el mismo camino que Regedit:
# core/Registry/CategoryState.ps1 lee, SettingStatus.ps1 compara y
# SettingApply.ps1 aplica.
#
# Solo se LEE. Aplicar se prueba con la escritura desarmada (el arnés)
# y con -WhatIf: ningún servicio ni tarea cambia.
# ============================================================

Describe 'Servicios y tareas - leer la sección' {

    It 'la sección existe, está en el índice tras Actualizaciones y declara objetivos' {
        $ids = @(Get-OptimizationCategories | ForEach-Object { $_.Id })
        Assert-Contains 'services' $ids
        Assert-Equal ([array]::IndexOf($ids, 'update') + 1) ([array]::IndexOf($ids, 'services')) 'va justo detrás de Actualizaciones'
        $cat = Get-CategoryById 'services'
        Assert-Equal 9 (Get-CategoryRegistryKeyCount $cat)
        Assert-Equal 'service,task' ((Get-CategoryTargetKinds $cat) -join ',')
    }

    It 'cada ajuste queda con un estado válido, y lo que no existe es de fábrica' {
        $cat = Get-CategoryById 'services'
        Update-CategoryRegistryState -Category $cat | Out-Null

        foreach ($ajuste in @($cat.Items)) {
            Assert-Contains $ajuste.Status (Get-SettingStatusNames) "el ajuste '$($ajuste.Name)'"
            foreach ($t in @(Get-SettingTargets $ajuste)) {
                if ($t.Entry.State -eq 'missing') { Assert-Equal 'factory' $t.Entry.Status "'$($t.Entry.Name)' no existe" }
                if ($t.Entry.State -eq 'read') { Assert-NotNull $t.Entry.Current }
            }
        }
    }

    It 'leer deja un [read] y un [checked] por objetivo' {
        $cat = Get-CategoryById 'services'
        Clear-AppLog
        Update-CategoryRegistryState -Category $cat | Out-Null
        $n = Get-CategoryRegistryKeyCount $cat
        $checked = @(Get-AppLog | Where-Object { $_.Status -eq 'checked' })
        Assert-Equal $n $checked.Count
        # Lectura + evaluación de cada uno, en su apartado del log.
        $lineas = @(Get-AppLog -Source 'services').Count + @(Get-AppLog -Source 'tasks').Count
        Assert-Equal (2 * $n) $lineas
    }
}

Describe 'Servicios y tareas - aplicar sin tocar nada' {

    It 'ON con la escritura desarmada no cambia nada y deja el estado releído' {
        $cat = Get-CategoryById 'services'
        $ajuste = @($cat.Items | Where-Object { @($_.Service).Count -gt 0 })[0]
        $entrada = @($ajuste.Service)[0]

        $antes = Get-ServiceStartModeRaw -Name $entrada.Name
        Clear-AppLog
        $status = Set-SettingOptimization -Setting $ajuste -Enabled $true

        Assert-Contains $status (Get-SettingStatusNames)
        Assert-Equal $antes.Value (Get-ServiceStartModeRaw -Name $entrada.Name).Value
        Assert-Equal 1 @(Get-AppLog -Source 'services' | Where-Object { $_.Status -eq 'disarmed' }).Count
    }

    It 'OFF de una tarea, desarmado, tampoco cambia nada' {
        $cat = Get-CategoryById 'services'
        $ajuste = @($cat.Items | Where-Object { @($_.ScheduledTask).Count -gt 0 })[0]
        Clear-AppLog
        $status = Set-SettingOptimization -Setting $ajuste -Enabled $false
        Assert-Contains $status (Get-SettingStatusNames)
        Assert-Equal 1 @(Get-AppLog -Source 'tasks' | Where-Object { $_.Status -eq 'disarmed' }).Count
    }

    It 'con -WhatIf no llega ni a intentarlo' {
        $cat = Get-CategoryById 'services'
        $ajuste = @($cat.Items)[0]
        Clear-AppLog
        Set-SettingOptimization -Setting $ajuste -Enabled $true -WhatIf | Out-Null
        Assert-Equal 0 @(Get-AppLog | Where-Object { $_.Status -eq 'disarmed' -or $_.Status -eq 'write attempt' }).Count
    }
}

Describe 'New-Setting - servicios y tareas mal declarados' {

    It 'un -Service sin Default, o con un tipo de inicio inventado, no se puede declarar' {
        Assert-Throws { New-Setting -Name 'x' -Description 'x' -Service @(@{ Name = 'SysMain'; Recommended = 'Disabled' }) }
        Assert-Throws { New-Setting -Name 'x' -Description 'x' -Service @(@{ Name = 'SysMain'; Recommended = 'Off'; Default = 'Automatic' }) }
    }

    It 'una -ScheduledTask sin ruta, o con un estado inventado, tampoco' {
        Assert-Throws { New-Setting -Name 'x' -Description 'x' -ScheduledTask @(@{ Name = 'Proxy'; Recommended = 'Disabled'; Default = 'Enabled' }) }
        Assert-Throws { New-Setting -Name 'x' -Description 'x' -ScheduledTask @(@{ Path = '\A\'; Name = 'B'; Recommended = 'Off'; Default = 'Enabled' }) }
    }
}
