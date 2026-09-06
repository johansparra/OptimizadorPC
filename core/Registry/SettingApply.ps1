# ============================================================
# core/Registry/SettingApply.ps1
# Aplicar (o deshacer) la optimización de un ajuste.
#
# Es el pegamento entre el toggle de la tarjeta y core/Registry/Writer.ps1:
# recibe un ajuste y si el usuario lo quiere ON u OFF, y escribe
# TODAS sus claves con el valor que toca.
#
#     ON   -> cada clave = su Recommended  (el que propone el programa)
#     OFF  -> cada clave = su Default      (el de fábrica de Windows)
#
# Después vuelve a leer esas claves por el camino de siempre
# (deja su [read] en el log) y recalcula el Status del ajuste con
# core/Registry/SettingStatus.ps1, para que la interfaz solo tenga que
# repintar.
#
# NO lee nada al arrancar la tarjeta: eso ya lo hace
# core/Registry/CategoryState.ps1. Aquí solo se entra al pulsar ON/OFF.
#
# Como todo core/: no sabe de interfaz y no lanza nunca.
# ============================================================

<#
    Escribe todas las claves de un ajuste según el estado pedido y
    devuelve el Status en que ha quedado ('optimized' / 'factory' /
    'custom' / 'unknown'), o $null si el ajuste no declara claves.

        $status = Set-SettingOptimization -Setting $ajuste -Enabled $true

    -WhatIf recorre el camino sin escribir (lo hereda de
    Write-RegistryValue).
#>
function Set-SettingOptimization {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]$Setting,
        [Parameter(Mandatory)][bool]$Enabled
    )

    $keys = @($Setting.Registry)
    if ($keys.Count -eq 0) { return $null }

    $requested = if ($Enabled) { 'ON' } else { 'OFF' }
    $action    = if ($Enabled) { 'EnableOptimization' } else { 'RestoreDefault' }

    # Cabecera del bloque en el registro de actividad, como la de
    # una lectura de sección: separa un cambio del siguiente.
    Write-AppLog -Source 'registry' -Level 'info' -Status 'applying' `
        -Message $Setting.Name -Detail ('requested={0} | {1} key(s)' -f $requested, $keys.Count)

    # -WhatIf salta las escrituras; la relectura y el recálculo de
    # estado se hacen igual, para devolver el estado actual.
    if ($PSCmdlet.ShouldProcess($Setting.Name, "$action ($requested)")) {
        foreach ($key in $keys) {
            $target = if ($Enabled) { [string]$key.Recommended } else { [string]$key.Default }
            Write-RegistryValue -Path $key.Path -Name $key.Name -Type $key.Type `
                -Text $target -Requested $requested -Action $action | Out-Null
        }
    }

    foreach ($key in $keys) {
        # Relectura por Read-RegistryValue (con su [read] en el log) y
        # vuelco en la clave: la tarjeta la lee tal cual al repintar.
        $r = Read-RegistryValue $key.Path $key.Name
        $key['State'] = $r.State
        if ($r.State -eq 'read') {
            $key['Current'] = Format-RegistryValue $r.Value $r.Kind $key.Display
        }
        else {
            $key['Current'] = $null
        }
    }

    # Recomendado / de fábrica / a medida, con lo que se acaba de
    # releer. Mismo camino que una lectura de sección.
    $status = Update-SettingStatus $Setting
    Write-SettingEvalLog $Setting

    Write-AppLog -Source 'registry' -Level 'info' -Status 'done' `
        -Message $Setting.Name -Detail ('requested={0} | status={1}' -f $requested, $status)

    $status
}
