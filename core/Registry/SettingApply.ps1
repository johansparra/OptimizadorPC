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
#             o SE BORRA el valor, si de fábrica no existe:
#               - la clave declara DefaultAbsent = $true (una
#                 directiva: su estado de fábrica es "no configurada"), o
#               - la copia de Writer.ps1 dice que, la primera vez que
#                 el programa lo tocó en esta sesión, no existía.
#             Borrar es Remove-RegistryValue: solo el valor, nunca la
#             clave, y por la misma lista blanca que escribir.
#
# Después vuelve a leer esas claves por el camino de siempre
# (deja su [read] en el log) y recalcula el Status del ajuste con
# core/Registry/SettingStatus.ps1, para que la interfaz solo tenga que
# repintar.
#
# Un ajuste con -Service o -ScheduledTask pasa por aquí igual: ON
# escribe su Recommended y OFF su Default, cada uno por su mecanismo
# (core/Services/ServiceStartup.ps1, core/ScheduledTasks/), con su
# lista blanca, desarmado, copia previa y relectura. Nunca se borran.
#
# NO lee nada al arrancar la tarjeta: eso ya lo hace
# core/Registry/CategoryState.ps1. Aquí solo se entra al pulsar ON/OFF.
#
# Como todo core/: no sabe de interfaz y no lanza nunca.
# ============================================================

<#
    ¿OFF tiene que BORRAR esta clave en vez de escribir su Default?

      - Sí si la declaración lo dice (DefaultAbsent = $true).
      - Sí si la primera copia de esta sesión la vio AUSENTE
        ('missing'). Un 'denied' no cuenta: ahí no se sabe nada y se
        escribe el Default, que es lo declarado.
      - Si no, no.
#>
function Test-RegistryRestoreByDelete {
    param($Key)

    if (-not $Key) { return $false }
    if ($Key.DefaultAbsent) { return $true }

    $origin = Get-RegistrySnapshotOrigin -Path ([string]$Key.Path) -Name ([string]$Key.Name)
    [bool]($origin -and $origin.State -eq 'missing')
}

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

    $targets = @(Get-SettingTargets $Setting)
    if ($targets.Count -eq 0) { return $null }

    $requested = if ($Enabled) { 'ON' } else { 'OFF' }
    $action    = if ($Enabled) { 'EnableOptimization' } else { 'RestoreDefault' }

    # Cabecera del bloque en el registro de actividad, como la de
    # una lectura de sección: separa un cambio del siguiente.
    Write-AppLog -Source 'registry' -Level 'info' -Status 'applying' `
        -Message $Setting.Name -Detail ('requested={0} | {1} key(s)' -f $requested, $targets.Count)

    # -WhatIf salta las escrituras; la relectura y el recálculo de
    # estado se hacen igual, para devolver el estado actual.
    if ($PSCmdlet.ShouldProcess($Setting.Name, "$action ($requested)")) {
        foreach ($t in $targets) {
            $key = $t.Entry

            # Un servicio o una tarea van por su propio mecanismo, con
            # su lista blanca. Ninguno de los dos se "borra": OFF
            # escribe siempre su Default.
            if ($t.Kind -eq 'service') {
                $mode = if ($Enabled) { [string]$key.Recommended } else { [string]$key.Default }
                Set-ServiceStartMode -Name ([string]$key.Name) -StartMode $mode `
                    -Requested $requested -Action $action | Out-Null
                continue
            }
            if ($t.Kind -eq 'task') {
                $state = if ($Enabled) { [string]$key.Recommended } else { [string]$key.Default }
                Set-ScheduledTaskEnabled -Path ([string]$key.Path) -Name ([string]$key.Name) -State $state `
                    -Requested $requested -Action $action | Out-Null
                continue
            }

            if (-not $Enabled -and (Test-RegistryRestoreByDelete $key)) {
                Remove-RegistryValue -Path $key.Path -Name $key.Name -Type $key.Type `
                    -Requested $requested -Action 'RestoreAbsent' | Out-Null
                continue
            }
            $target = if ($Enabled) { [string]$key.Recommended } else { [string]$key.Default }
            Write-RegistryValue -Path $key.Path -Name $key.Name -Type $key.Type `
                -Text $target -Requested $requested -Action $action | Out-Null
        }
    }

    # Relectura por el camino de siempre (con su [read] en el log) y
    # vuelco en la entrada: la tarjeta la lee tal cual al repintar.
    foreach ($t in $targets) { Update-SettingTargetState $t | Out-Null }

    # Recomendado / de fábrica / a medida, con lo que se acaba de
    # releer. Mismo camino que una lectura de sección.
    $status = Update-SettingStatus $Setting
    Write-SettingEvalLog $Setting

    Write-AppLog -Source 'registry' -Level 'info' -Status 'done' `
        -Message $Setting.Name -Detail ('requested={0} | status={1}' -f $requested, $status)

    $status
}
