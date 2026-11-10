# ============================================================
# core/Services/ServiceStartup.ps1
# Leer y cambiar el TIPO DE INICIO de un servicio de Windows.
#
# Es el mecanismo de los ajustes que declaran -Service (ver
# New-Setting en ui/Engine/CategoryRegistry.ps1). Mismo contrato que
# core/Registry/Writer.ps1, pieza por pieza:
#
#   1. NADA lanza hacia arriba. Un servicio que no existe, sin
#      permisos o fuera de la lista blanca es una RESPUESTA (State),
#      no una excepción.
#
#   2. LISTA BLANCA por nombre exacto ($ServiceWriteAllowlist). Lo que
#      no está, no se toca. Además hay una lista de servicios
#      PROTEGIDOS ($ServiceProtectedNames: Defender, firewall, Windows
#      Update, cifrado, el núcleo del sistema) que se rechaza aunque
#      alguien lo añadiera a la blanca: es la denylist de SECURITY.md
#      §3.4 llevada a servicios. La vigila tests/Source/Security.Tests.ps1.
#
#   3. SOLO EL TIPO DE INICIO: Automatic, Manual o Disabled. No se
#      para ni se arranca nada (el servicio que ya corre sigue
#      corriendo hasta reiniciar), no se toca la cuenta, la ruta del
#      ejecutable, las dependencias ni los permisos.
#
#   4. COPIA del estado previo antes de cada escritura
#      ($ServiceSnapshots, solo en memoria, igual que el registro).
#
#   5. VERIFICACIÓN POR RELECTURA: después de escribir se vuelve a
#      leer y se comprueba que el tipo de inicio es el pedido.
#
#   6. -WhatIf (SupportsShouldProcess) y DESARMABLE: el arnés de
#      pruebas lo desarma (tests/Harness/AppHost.ps1) y entonces
#      termina en 'disarmed' sin tocar nada.
#
# Sin intérprete ni ejecutables: se lee con CIM (Win32_Service, que
# da el mismo StartMode en 5.1 y en 7) y se escribe con Set-Service.
# sc.exe no hace falta para nada de esto.
#
# Ojo con AutomaticDelayedStart: Set-Service de 5.1 no lo sabe
# escribir. Ninguno de los servicios de la lista lo usa de fábrica,
# así que ni se lee ni se escribe: 'Automatic' es automático, con o
# sin retraso (el retraso se apunta en el log, no se compara).
#
# Todos los textos aquí son palabras en inglés o comentarios: core/
# no traduce (regla 15).
# ============================================================

# ---- ¿está armada la escritura? ---------------------------------
#
# En la aplicación de verdad, siempre. El arnés la desarma para que
# la suite no cambie los servicios del equipo ni corriendo elevada
# (los ejecutores de GitHub Actions lo están).
$ServiceWriteArmed = $true

function Get-ServiceWriteArmed { [bool]$script:ServiceWriteArmed }
function Set-ServiceWriteArmed { param([bool]$On) $script:ServiceWriteArmed = $On }

# ---- lista blanca ------------------------------------------------
#
# Nombre corto del servicio (el de "sc query", no el que se enseña).
# Añadir uno es una decisión de seguridad (SECURITY.md §14).
$ServiceWriteAllowlist = @(
    'DiagTrack'          # Experiencias del usuario y telemetría asociadas
    'dmwappushservice'   # Enrutador de mensajes WAP Push (telemetría)
    'SysMain'            # Antes Superfetch
)

# ---- servicios protegidos ---------------------------------------
#
# Nunca se cambian desde aquí, estén o no en la lista blanca. Son los
# que, apagados, dejan el equipo menos seguro o sin arrancar.
$ServiceProtectedNames = @(
    # Defender y el Centro de seguridad
    'WinDefend', 'WdNisSvc', 'WdNisDrv', 'WdFilter', 'WdBoot', 'Sense', 'MDCoreSvc',
    'SecurityHealthService', 'wscsvc', 'SgrmBroker', 'webthreatdefsvc', 'webthreatdefusersvc'
    # Firewall e IPsec
    'mpssvc', 'BFE', 'IKEEXT', 'PolicyAgent'
    # Windows Update y lo que lo sostiene
    'wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'BITS', 'DoSvc', 'TrustedInstaller'
    # Cifrado, credenciales e identidad
    'BDESVC', 'CryptSvc', 'KeyIso', 'VaultSvc', 'SamSs', 'Netlogon', 'EFS', 'TBS', 'AppIDSvc'
    # Núcleo: sin ellos Windows no arranca o no se administra
    'EventLog', 'RpcSs', 'RpcEptMapper', 'DcomLaunch', 'LSM', 'Schedule', 'Winmgmt',
    'gpsvc', 'ProfSvc', 'Power', 'BrokerInfrastructure', 'SystemEventsBroker'
)

# Los tipos de inicio que se saben ESCRIBIR. Boot y System son de
# controladores: se leen, pero nunca se ponen.
$ServiceWritableStartModes = @('Automatic', 'Manual', 'Disabled')

<#
    ¿Es un nombre de servicio con forma válida? Letras, números, '_',
    '-' y '.'. Sin comillas (el nombre va dentro de un filtro de CIM),
    sin comodines (Get-Service y Set-Service los expanden) y sin
    espacios.
#>
function Test-ServiceNameValid {
    param([string]$Name)
    [bool]($Name -match '^[A-Za-z0-9_.\-]{1,80}$')
}

function Test-ServiceProtected {
    param([string]$Name)
    foreach ($p in $ServiceProtectedNames) {
        if ([string]::Equals($p, $Name, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}

<#
    ¿Se puede cambiar el tipo de inicio de este servicio? Solo si el
    nombre es válido, está en la lista blanca y NO es uno protegido.
#>
function Test-ServiceWriteAllowed {
    param([string]$Name)

    if (-not (Test-ServiceNameValid $Name)) { return $false }
    if (Test-ServiceProtected $Name) { return $false }
    foreach ($s in $ServiceWriteAllowlist) {
        if ([string]::Equals($s, $Name, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}

# ---- lectura ------------------------------------------------------

function New-ServiceReadResult {
    param([string]$State, [string]$Value = $null, [bool]$Delayed = $false, [string]$Running = '')
    [PSCustomObject]@{ State = $State; Value = $Value; Delayed = $Delayed; Running = $Running }
}

# El StartMode de Win32_Service ('Auto') con el nombre de Set-Service
# ('Automatic'), que es como se declara en ui/Data/Categories/.
function ConvertFrom-ServiceStartMode {
    param([string]$Mode)
    switch ($Mode) {
        'Auto'     { 'Automatic' }
        'Manual'   { 'Manual' }
        'Disabled' { 'Disabled' }
        'Boot'     { 'Boot' }
        'System'   { 'System' }
        default    { $Mode }
    }
}

<#
    Lee el tipo de inicio SIN apuntar nada. Devuelve siempre:

        State    'read'     -> Value trae el tipo de inicio
                 'missing'  -> no hay ningún servicio con ese nombre
                 'denied'   -> CIM no contestó (sin permiso, WMI roto)
                 'badname'  -> el nombre no tiene forma válida
        Value    'Automatic' | 'Manual' | 'Disabled' | 'Boot' | 'System'
        Delayed  inicio automático con retraso
        Running  'Running', 'Stopped'... (solo para el log)
#>
function Get-ServiceStartModeRaw {
    param([string]$Name)

    if (-not (Test-ServiceNameValid $Name)) { return (New-ServiceReadResult 'badname') }

    try {
        # El nombre ya está validado: sin comillas, no puede salirse
        # del filtro.
        $found = @(Get-CimInstance -ClassName 'Win32_Service' -Filter ("Name='{0}'" -f $Name) -ErrorAction Stop)
    }
    catch {
        return (New-ServiceReadResult 'denied')
    }

    if ($found.Count -eq 0 -or $null -eq $found[0]) { return (New-ServiceReadResult 'missing') }

    $svc = $found[0]
    New-ServiceReadResult 'read' (ConvertFrom-ServiceStartMode ([string]$svc.StartMode)) `
        ([bool]$svc.DelayedAutoStart) ([string]$svc.State)
}

<#
    Lee el tipo de inicio y lo apunta en el registro de actividad, con
    las mismas palabras que una lectura del registro: 'read',
    'not found', 'no access'.
#>
function Read-ServiceStartMode {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Name)

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Get-ServiceStartModeRaw -Name $Name
    $watch.Stop()
    $took = '{0:N1} ms' -f $watch.Elapsed.TotalMilliseconds

    $message = "service $Name"
    switch ($result.State) {
        'read' {
            $extra = ''
            if ($result.Delayed -and $result.Value -eq 'Automatic') { $extra = ' (delayed)' }
            Write-AppLog -Source 'services' -Level 'info' -Status 'read' -Message $message `
                -Detail ('{0}{1} - {2} - {3}' -f $result.Value, $extra, $result.Running, $took)
        }
        'missing' {
            Write-AppLog -Source 'services' -Level 'warn' -Status 'not found' -Message $message -Detail $took
        }
        'denied' {
            Write-AppLog -Source 'services' -Level 'error' -Status 'no access' -Message $message -Detail $took
        }
        default {
            Write-AppLog -Source 'services' -Level 'error' -Status 'invalid name' -Message $message -Detail $took
        }
    }

    $result
}

<#
    Lee el servicio de una entrada de -Service y deja en la propia
    entrada (una hashtable, la tarjeta la lee tal cual):

        State    'read' | 'missing' | 'denied' | 'badname'
        Current  el tipo de inicio, o $null si no se pudo leer

    Es el equivalente de lo que core/Registry/CategoryState.ps1 hace con
    cada clave de -Registry.
#>
function Update-ServiceEntryState {
    param($Entry)

    if (-not $Entry) { return $null }
    $r = Read-ServiceStartMode -Name ([string]$Entry.Name)
    $Entry['State'] = $r.State
    if ($r.State -eq 'read') { $Entry['Current'] = $r.Value } else { $Entry['Current'] = $null }
    $r.State
}

# ---- copia del estado previo -------------------------------------
#
# El tipo de inicio que había antes de cada escritura, en memoria.
# Como la del registro: se pierde al cerrar, y el contrato de vuelta
# es el Default declarado (SECURITY.md §4).
$ServiceSnapshots = New-Object System.Collections.Generic.List[object]

function Add-ServiceSnapshot {
    param([string]$Name, [string]$Value, [bool]$Delayed, [string]$State)
    $script:ServiceSnapshots.Add([PSCustomObject]@{
        Time    = [DateTime]::Now
        Name    = $Name
        Value   = $Value
        Delayed = $Delayed
        State   = $State
    })
}

function Get-ServiceSnapshots  { $script:ServiceSnapshots.ToArray() }
function Clear-ServiceSnapshots { $script:ServiceSnapshots.Clear() }

# ---- escritura ----------------------------------------------------

function New-ServiceWriteResult {
    param([string]$State, [string]$Old = '', [string]$New = '', [bool]$Verified = $false)
    [PSCustomObject]@{ State = $State; Old = $Old; New = $New; Verified = $Verified }
}

# Un rechazo antes de tocar nada, con su motivo. Mismas palabras de
# color que core/Registry/Writer.ps1.
function Write-ServiceWriteRejected {
    param([string]$Name, [string]$Status, [string]$Reason, [string]$Detail, [double]$Ms)

    $d = "reason=$Reason"
    if ($Detail) { $d += " | $Detail" }
    $d += ' | {0:N1} ms' -f $Ms
    $level = if ($Status -in @('disarmed', 'no change', 'not found')) { 'warn' } else { 'error' }
    Write-AppLog -Source 'services' -Level $level -Status $Status -Message "service $Name" -Detail $d
}

<#
    Cambia el tipo de inicio de UN servicio.

        $r = Set-ServiceStartMode -Name 'DiagTrack' -StartMode 'Disabled' -Requested 'ON'

    Devuelve { State; Old; New; Verified }.

        State  'written'     -> cambiado y comprobado por relectura
               'nochange'    -> ya estaba así, o -WhatIf
               'blocked'     -> fuera de la lista blanca, o protegido
               'badname'     -> el nombre no tiene forma válida
               'unsupported' -> un tipo de inicio que no se escribe
               'missing'     -> el servicio no existe en este equipo
               'denied'      -> sin permisos, o la relectura no cuadra
               'disarmed'    -> la escritura está desarmada (pruebas)

    No para ni arranca el servicio: el cambio vale desde el siguiente
    arranque de Windows.
#>
function Set-ServiceStartMode {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$StartMode,
        [ValidateSet('ON', 'OFF', '')][string]$Requested = '',
        [string]$Action = 'SetStartMode'
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $ctx = "action=$Action | requested=$Requested | target=$StartMode"

    # 0. ¿Armada?
    if (-not (Get-ServiceWriteArmed)) {
        Write-ServiceWriteRejected $Name 'disarmed' 'WRITE_DISARMED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'disarmed')
    }

    # 1. Nombre con forma de nombre.
    if (-not (Test-ServiceNameValid $Name)) {
        Write-ServiceWriteRejected $Name 'invalid name' 'INVALID_NAME' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'badname')
    }

    # 2. Lista blanca (y nunca un protegido).
    if (-not (Test-ServiceWriteAllowed $Name)) {
        Write-ServiceWriteRejected $Name 'blocked' 'SERVICE_NOT_ALLOWED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'blocked')
    }

    # 3. Un tipo de inicio que se sepa escribir.
    $mode = $null
    foreach ($m in $ServiceWritableStartModes) {
        if ([string]::Equals($m, $StartMode, [System.StringComparison]::OrdinalIgnoreCase)) { $mode = $m }
    }
    if (-not $mode) {
        Write-ServiceWriteRejected $Name 'unsupported' 'START_MODE_UNSUPPORTED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'unsupported')
    }

    # 4. Estado previo y copia.
    $before = Get-ServiceStartModeRaw -Name $Name
    Add-ServiceSnapshot -Name $Name -Value $before.Value -Delayed $before.Delayed -State $before.State
    $old = if ($before.State -eq 'read') { $before.Value } else { "($($before.State))" }
    Write-AppLog -Source 'services' -Level 'info' -Status 'snapshot' -Message "service $Name" `
        -Detail ('old={0} | delayed={1} | running={2}' -f $old, $before.Delayed, $before.Running)

    if ($before.State -eq 'missing') {
        Write-ServiceWriteRejected $Name 'not found' 'SERVICE_NOT_FOUND' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'missing' $old $mode)
    }
    if ($before.State -ne 'read') {
        # Sin saber cómo está no se escribe: tampoco se podría
        # comprobar después.
        Write-ServiceWriteRejected $Name 'no access' 'READ_FAILED' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'denied' $old $mode)
    }

    Write-AppLog -Source 'services' -Level 'info' -Status 'write attempt' -Message "service $Name" `
        -Detail ('{0} | old={1} | new={2} | elevated={3}' -f $ctx, $old, $mode, (Test-ProcessElevated))

    # 5. ¿Ya está así? No se escribe.
    if ([string]::Equals($before.Value, $mode, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-ServiceWriteRejected $Name 'no change' 'ALREADY_SET' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'nochange' $old $mode $true)
    }

    # 6. -WhatIf sale por aquí sin tocar nada.
    if (-not $PSCmdlet.ShouldProcess("service $Name", "Set start mode = $mode")) {
        Write-ServiceWriteRejected $Name 'no change' 'WHATIF' $ctx $watch.Elapsed.TotalMilliseconds
        return (New-ServiceWriteResult 'nochange' $old $mode)
    }

    # 7. Escribir.
    $err = $null
    try {
        Set-Service -Name $Name -StartupType $mode -ErrorAction Stop
    }
    catch {
        $err = $_
    }

    if ($err) {
        $ex = $err.Exception
        if ($ex.InnerException) { $ex = $ex.InnerException }
        $msg = (([string]$ex.Message) -replace '\s+', ' ').Trim()
        Write-AppLog -Source 'services' -Level 'error' -Status 'write failed' -Message "service $Name" `
            -Detail ('{0} | exception={1} | message={2} | {3:N1} ms' -f $ctx, $ex.GetType().FullName, $msg, $watch.Elapsed.TotalMilliseconds)
        return (New-ServiceWriteResult 'denied' $old $mode)
    }

    # 8. Relectura.
    $after = Get-ServiceStartModeRaw -Name $Name
    $afterText = if ($after.State -eq 'read') { $after.Value } else { "($($after.State))" }
    $verified = ($after.State -eq 'read') -and [string]::Equals($after.Value, $mode, [System.StringComparison]::OrdinalIgnoreCase)

    Write-AppLog -Source 'services' -Level $(if ($verified) { 'info' } else { 'error' }) -Status 'post write' `
        -Message "service $Name" -Detail ('expected={0} | actual={1} | result={2}' -f $mode, $afterText, $(if ($verified) { 'SUCCESS' } else { 'FAILED' }))

    if (-not $verified) {
        return (New-ServiceWriteResult 'denied' $old $afterText)
    }

    $status = if ($Requested -eq 'OFF') { 'restored' } else { 'applied' }
    Write-AppLog -Source 'services' -Level 'info' -Status $status -Message "service $Name" `
        -Detail ('{0} | old={1} | new={2} | {3:N1} ms' -f $ctx, $old, $afterText, $watch.Elapsed.TotalMilliseconds)

    New-ServiceWriteResult 'written' $old $afterText $true
}
