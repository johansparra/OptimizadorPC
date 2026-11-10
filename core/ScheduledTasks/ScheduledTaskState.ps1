# ============================================================
# core/ScheduledTasks/ScheduledTaskState.ps1
# Leer y cambiar si una tarea programada de Windows está HABILITADA.
#
# Es el mecanismo de los ajustes que declaran -ScheduledTask (ver
# New-Setting en ui/Engine/CategoryRegistry.ps1). Mismo contrato que
# core/Registry/Writer.ps1 y core/Services/ServiceStartup.ps1:
#
#   1. NADA lanza hacia arriba: una tarea que no existe (varias de
#      Windows 10 ya no están en 11), sin permisos o fuera de la lista
#      blanca es un State, no una excepción.
#
#   2. LISTA BLANCA por ruta Y nombre exactos
#      ($ScheduledTaskWriteAllowlist). Una carpeta entera no se abre
#      nunca. Además, las carpetas PROTEGIDAS
#      ($ScheduledTaskProtectedPaths: Windows Update, Defender,
#      BitLocker...) se rechazan aunque alguien añadiera una de sus
#      tareas a la blanca.
#
#   3. SOLO HABILITAR O DESHABILITAR. No se crean, borran, ejecutan,
#      paran ni modifican tareas: ni desencadenadores, ni acciones,
#      ni la cuenta con la que corren.
#
#   4. COPIA del estado previo antes de cada escritura
#      ($ScheduledTaskSnapshots, en memoria).
#
#   5. VERIFICACIÓN POR RELECTURA.
#
#   6. -WhatIf (SupportsShouldProcess) y DESARMABLE (el arnés de
#      pruebas lo desarma: 'disarmed', sin tocar nada).
#
# Sin intérprete ni schtasks.exe: el módulo ScheduledTasks de Windows
# (Get-ScheduledTask, Enable-/Disable-ScheduledTask), que existe en
# 5.1 y en 7. Si no se pudiera cargar, la lectura dice 'unavailable'
# y la tarjeta 'desconocido'.
#
# Get-ScheduledTask acepta COMODINES en la ruta y en el nombre: por
# eso se rechaza cualquier '*', '?', '[' o ']' antes de llamarlo.
# ============================================================

# ---- ¿está armada la escritura? ---------------------------------
$ScheduledTaskWriteArmed = $true

function Get-ScheduledTaskWriteArmed { [bool]$script:ScheduledTaskWriteArmed }
function Set-ScheduledTaskWriteArmed { param([bool]$On) $script:ScheduledTaskWriteArmed = $On }

# ---- lista blanca ------------------------------------------------
#
# Ruta de la carpeta tal cual la da el Programador de tareas (empieza
# y acaba en '\') y nombre exacto. Todas son de telemetría (CEIP y
# compatibilidad). Añadir una es una decisión de seguridad
# (SECURITY.md §14).
$ScheduledTaskWriteAllowlist = @(
    @{ Path = '\Microsoft\Windows\Application Experience\';               Name = 'Microsoft Compatibility Appraiser' }
    @{ Path = '\Microsoft\Windows\Application Experience\';               Name = 'ProgramDataUpdater' }
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' }
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' }
    @{ Path = '\Microsoft\Windows\Autochk\';                              Name = 'Proxy' }
    @{ Path = '\Microsoft\Windows\DiskDiagnostic\';                       Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
)

# ---- carpetas protegidas -----------------------------------------
#
# Nada que cuelgue de aquí se habilita ni deshabilita desde el
# programa, esté o no en la lista blanca.
$ScheduledTaskProtectedPaths = @(
    '\Microsoft\Windows\WindowsUpdate\'
    '\Microsoft\Windows\UpdateOrchestrator\'
    '\Microsoft\Windows\WaaSMedic\'
    '\Microsoft\Windows\InstallService\'
    '\Microsoft\Windows\Windows Defender\'
    '\Microsoft\Windows\ExploitGuard\'
    '\Microsoft\Windows\BitLocker\'
    '\Microsoft\Windows\AppID\'
    '\Microsoft\Windows\TPM\'
    '\Microsoft\Windows\CertificateServicesClient\'
    '\Microsoft\Windows\SystemRestore\'
)

$ScheduledTaskWritableStates = @('Enabled', 'Disabled')

<#
    ¿Tienen forma válida? La ruta empieza y acaba en '\', y ninguna de
    las dos lleva comodines, comillas ni saltos de línea.
#>
function Test-ScheduledTaskTargetValid {
    param([string]$Path, [string]$Name)

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Name)) { return $false }
    if ($Path.Length -gt 260 -or $Name.Length -gt 200) { return $false }
    if ($Path -notmatch '^\\([^\\]+\\)*$') { return $false }
    if ($Name -match '\\') { return $false }
    $bad = '[\*\?\[\]"''`\r\n\x00]'
    if ($Path -match $bad -or $Name -match $bad) { return $false }
    if ($Path -match '\\\.\.?\\') { return $false }
    $true
}

function Test-ScheduledTaskProtected {
    param([string]$Path)
    foreach ($p in $ScheduledTaskProtectedPaths) {
        if ($Path.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}

<#
    ¿Se puede habilitar o deshabilitar esta tarea? Solo si tiene forma
    válida, ruta Y nombre están en la lista blanca tal cual, y no
    cuelga de una carpeta protegida.
#>
function Test-ScheduledTaskWriteAllowed {
    param([string]$Path, [string]$Name)

    if (-not (Test-ScheduledTaskTargetValid -Path $Path -Name $Name)) { return $false }
    if (Test-ScheduledTaskProtected $Path) { return $false }
    foreach ($t in $ScheduledTaskWriteAllowlist) {
        if ([string]::Equals($t.Path, $Path, [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]::Equals($t.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}

# ---- lectura ------------------------------------------------------

function New-ScheduledTaskReadResult {
    param([string]$State, [string]$Value = $null, [string]$Raw = '')
    [PSCustomObject]@{ State = $State; Value = $Value; Raw = $Raw }
}

<#
    Lee la tarea SIN apuntar nada. Devuelve siempre:

        State   'read'         -> Value trae 'Enabled' o 'Disabled'
                'missing'      -> no existe en este equipo
                'denied'       -> existe pero no se pudo leer
                'unavailable'  -> el módulo ScheduledTasks no carga
                'badname'      -> ruta o nombre sin forma válida
        Value   'Enabled' | 'Disabled'
        Raw     el State de la tarea ('Ready', 'Running', 'Disabled'...)
#>
function Get-ScheduledTaskEnabledRaw {
    param([string]$Path, [string]$Name)

    if (-not (Test-ScheduledTaskTargetValid -Path $Path -Name $Name)) { return (New-ScheduledTaskReadResult 'badname') }

    try {
        $task = Get-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Select-Object -First 1
    }
    catch {
        if ($_.Exception -is [System.Management.Automation.CommandNotFoundException]) {
            return (New-ScheduledTaskReadResult 'unavailable')
        }
        if ([string]$_.CategoryInfo.Category -eq 'ObjectNotFound') {
            return (New-ScheduledTaskReadResult 'missing')
        }
        return (New-ScheduledTaskReadResult 'denied')
    }

    if ($null -eq $task) { return (New-ScheduledTaskReadResult 'missing') }

    $raw = [string]$task.State
    $value = if ($raw -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
    New-ScheduledTaskReadResult 'read' $value $raw
}

# El texto con el que sale una tarea en el log: la ruta completa.
function Format-ScheduledTaskName {
    param([string]$Path, [string]$Name)
    "task $Path$Name"
}

<#
    Lee la tarea y lo apunta en el registro de actividad ('read',
    'not found', 'no access', 'unavailable').
#>
function Read-ScheduledTaskEnabled {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Get-ScheduledTaskEnabledRaw -Path $Path -Name $Name
    $watch.Stop()
    $took = '{0:N1} ms' -f $watch.Elapsed.TotalMilliseconds

    $message = Format-ScheduledTaskName $Path $Name
    switch ($result.State) {
        'read' {
            Write-AppLog -Source 'tasks' -Level 'info' -Status 'read' -Message $message `
                -Detail ('{0} - {1} - {2}' -f $result.Value, $result.Raw, $took)
        }
        'missing' {
            Write-AppLog -Source 'tasks' -Level 'warn' -Status 'not found' -Message $message -Detail $took
        }
        'denied' {
            Write-AppLog -Source 'tasks' -Level 'error' -Status 'no access' -Message $message -Detail $took
        }
        'unavailable' {
            Write-AppLog -Source 'tasks' -Level 'error' -Status 'unavailable' -Message $message -Detail $took
        }
        default {
            Write-AppLog -Source 'tasks' -Level 'error' -Status 'invalid name' -Message $message -Detail $took
        }
    }

    $result
}

<#
    Lee la tarea de una entrada de -ScheduledTask y deja en la propia
    entrada State y Current, como core/Registry/CategoryState.ps1 con
    cada clave.
#>
function Update-ScheduledTaskEntryState {
    param($Entry)

    if (-not $Entry) { return $null }
    $r = Read-ScheduledTaskEnabled -Path ([string]$Entry.Path) -Name ([string]$Entry.Name)
    $Entry['State'] = $r.State
    if ($r.State -eq 'read') { $Entry['Current'] = $r.Value } else { $Entry['Current'] = $null }
    $r.State
}

# ---- copia del estado previo -------------------------------------
$ScheduledTaskSnapshots = New-Object System.Collections.Generic.List[object]

function Add-ScheduledTaskSnapshot {
    param([string]$Path, [string]$Name, [string]$Value, [string]$Raw, [string]$State)
    $script:ScheduledTaskSnapshots.Add([PSCustomObject]@{
        Time  = [DateTime]::Now
        Path  = $Path
        Name  = $Name
        Value = $Value
        Raw   = $Raw
        State = $State
    })
}

function Get-ScheduledTaskSnapshots  { $script:ScheduledTaskSnapshots.ToArray() }
function Clear-ScheduledTaskSnapshots { $script:ScheduledTaskSnapshots.Clear() }

# ---- escritura ----------------------------------------------------

function New-ScheduledTaskWriteResult {
    param([string]$State, [string]$Old = '', [string]$New = '', [bool]$Verified = $false)
    [PSCustomObject]@{ State = $State; Old = $Old; New = $New; Verified = $Verified }
}

function Write-ScheduledTaskWriteRejected {
    param([string]$Message, [string]$Status, [string]$Reason, [string]$Detail, [double]$Ms)

    $d = "reason=$Reason"
    if ($Detail) { $d += " | $Detail" }
    $d += ' | {0:N1} ms' -f $Ms
    $level = if ($Status -in @('disarmed', 'no change', 'not found')) { 'warn' } else { 'error' }
    Write-AppLog -Source 'tasks' -Level $level -Status $Status -Message $Message -Detail $d
}

<#
    Habilita o deshabilita UNA tarea programada.

        $r = Set-ScheduledTaskEnabled -Path '\Microsoft\Windows\Autochk\' -Name 'Proxy' `
                                      -State 'Disabled' -Requested 'ON'

    Devuelve { State; Old; New; Verified }, con los mismos estados que
    Set-ServiceStartMode: 'written', 'nochange' (ya estaba, o -WhatIf),
    'blocked', 'badname', 'unsupported', 'missing', 'denied',
    'disarmed'.
#>
function Set-ScheduledTaskEnabled {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$State,
        [ValidateSet('ON', 'OFF', '')][string]$Requested = '',
        [string]$Action = 'SetEnabled'
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $message = Format-ScheduledTaskName $Path $Name
    $ctx = "action=$Action | requested=$Requested | target=$State"

    # 0. ¿Armada?
    if (-not (Get-ScheduledTaskWriteArmed)) {
        Write-ScheduledTaskWriteRejected $message 'disarmed' 'WRITE_DISARMED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'disarmed')
    }

    # 1. Forma válida.
    if (-not (Test-ScheduledTaskTargetValid -Path $Path -Name $Name)) {
        Write-ScheduledTaskWriteRejected $message 'invalid name' 'INVALID_NAME' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'badname')
    }

    # 2. Lista blanca (y nunca una carpeta protegida).
    if (-not (Test-ScheduledTaskWriteAllowed -Path $Path -Name $Name)) {
        Write-ScheduledTaskWriteRejected $message 'blocked' 'TASK_NOT_ALLOWED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'blocked')
    }

    # 3. Un estado que se sepa escribir.
    $target = $null
    foreach ($s in $ScheduledTaskWritableStates) {
        if ([string]::Equals($s, $State, [System.StringComparison]::OrdinalIgnoreCase)) { $target = $s }
    }
    if (-not $target) {
        Write-ScheduledTaskWriteRejected $message 'unsupported' 'STATE_UNSUPPORTED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'unsupported')
    }

    # 4. Estado previo y copia.
    $before = Get-ScheduledTaskEnabledRaw -Path $Path -Name $Name
    Add-ScheduledTaskSnapshot -Path $Path -Name $Name -Value $before.Value -Raw $before.Raw -State $before.State
    $old = if ($before.State -eq 'read') { $before.Value } else { "($($before.State))" }
    Write-AppLog -Source 'tasks' -Level 'info' -Status 'snapshot' -Message $message `
        -Detail ('old={0} | raw={1}' -f $old, $before.Raw)

    if ($before.State -eq 'missing') {
        Write-ScheduledTaskWriteRejected $message 'not found' 'TASK_NOT_FOUND' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'missing' $old $target)
    }
    if ($before.State -ne 'read') {
        Write-ScheduledTaskWriteRejected $message 'no access' 'READ_FAILED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'denied' $old $target)
    }

    Write-AppLog -Source 'tasks' -Level 'info' -Status 'write attempt' -Message $message `
        -Detail ('{0} | old={1} | new={2} | elevated={3}' -f $ctx, $old, $target, (Test-ProcessElevated))

    # 5. ¿Ya está así?
    if ($before.Value -eq $target) {
        Write-ScheduledTaskWriteRejected $message 'no change' 'ALREADY_SET' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'nochange' $old $target $true)
    }

    # 6. -WhatIf.
    if (-not $PSCmdlet.ShouldProcess($message, "Set $target")) {
        Write-ScheduledTaskWriteRejected $message 'no change' 'WHATIF' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ScheduledTaskWriteResult 'nochange' $old $target)
    }

    # 7. Escribir.
    $err = $null
    try {
        if ($target -eq 'Disabled') {
            Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Out-Null
        }
        else {
            Enable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Out-Null
        }
    }
    catch {
        $err = $_
    }

    if ($err) {
        $ex = $err.Exception
        $msg = (([string]$ex.Message) -replace '\s+', ' ').Trim()
        Write-AppLog -Source 'tasks' -Level 'error' -Status 'write failed' -Message $message `
            -Detail ('{0} | exception={1} | message={2} | {3:N1} ms' -f $ctx, $ex.GetType().FullName, $msg, $watch.Elapsed.TotalMilliseconds)
        return (New-ScheduledTaskWriteResult 'denied' $old $target)
    }

    # 8. Relectura.
    $after = Get-ScheduledTaskEnabledRaw -Path $Path -Name $Name
    $afterText = if ($after.State -eq 'read') { $after.Value } else { "($($after.State))" }
    $verified = ($after.State -eq 'read') -and ($after.Value -eq $target)

    Write-AppLog -Source 'tasks' -Level $(if ($verified) { 'info' } else { 'error' }) -Status 'post write' `
        -Message $message -Detail ('expected={0} | actual={1} | result={2}' -f $target, $afterText, $(if ($verified) { 'SUCCESS' } else { 'FAILED' }))

    if (-not $verified) {
        return (New-ScheduledTaskWriteResult 'denied' $old $afterText)
    }

    $status = if ($Requested -eq 'OFF') { 'restored' } else { 'applied' }
    Write-AppLog -Source 'tasks' -Level 'info' -Status $status -Message $message `
        -Detail ('{0} | old={1} | new={2} | {3:N1} ms' -f $ctx, $old, $afterText, $watch.Elapsed.TotalMilliseconds)

    New-ScheduledTaskWriteResult 'written' $old $afterText $true
}
