# ============================================================
# core/Registry/Writer.ps1
# Escritura en el registro de Windows.
#
# La otra mitad de core/Registry/Reader.ps1: aquí se ESCRIBE. Sigue sin
# saber de ventanas ni tarjetas. Se llama solo cuando el usuario
# pulsa el ON/OFF de un ajuste (ver core/Registry/SettingApply.ps1); la
# fase de lectura y evaluación NO pasa por aquí.
#
# CÓMO NO ROMPER NADA
#
#   1. NADA lanza hacia arriba. Una clave protegida, una ruta
#      fuera de la lista blanca o un tipo que no cuadra son
#      RESPUESTAS -un State-, no excepciones.
#
#   2. LISTA BLANCA, sin diálogo de confirmación. Solo se escribe
#      en las ramas de $RegistryWriteAllowlist (o en algo que
#      cuelgue de ellas) o en los valores CONCRETOS de
#      $RegistryWriteAllowedValues (clave exacta + nombre). SAM,
#      SECURITY, BCD y el resto de ...\Services quedan fuera por no
#      estar en la lista. No hay denylist porque no hace falta: lo
#      que no está, no se toca.
#
#   3. RESPETA EL TIPO. El valor se escribe con el RegistryValueKind
#      que declara el ajuste (Type), nunca "a ver qué sale". Un
#      DWord se pasa como Int32 (0xFFFFFFFF -> -1); un binario se
#      parsea de pares hex a byte[]. MULTI_SZ todavía no: el modelo
#      de datos no tiene forma de declararlo, así que se rechaza.
#
#   4. LA RUTA ES UNA CLAVE, NUNCA UN VALOR. CreateSubKey asegura
#      el contenedor; el dato se pone DENTRO con SetValue(Name,...).
#
#   5. COPIA DE SEGURIDAD antes de cada escritura (valor y tipo
#      anteriores, en memoria y en el log), para poder deshacer más
#      allá del Default declarado.
#
#   6. CONFIRMACIÓN POR RELECTURA: después de escribir se vuelve a
#      leer y se comprueba que el valor es el que se pidió.
#
#   7. BORRAR ES QUITAR UN VALOR, NUNCA UNA CLAVE. Remove-RegistryValue
#      existe para volver a "no configurado" lo que de fábrica no
#      existía (una directiva, sobre todo). Pasa por la MISMA lista
#      blanca, el mismo desarmado, -WhatIf, copia previa y relectura.
#      Aquí no se borra ninguna clave: solo DeleteValue, y solo en
#      Remove-RegistryValue (lo vigila tests/Source/Security.Tests.ps1).
#
# Todos los textos aquí están en inglés o son comentarios: core/
# no traduce (regla 15).
# ============================================================

# ---- ¿está armada la escritura? ---------------------------------
#
# El arnés de pruebas la DESARMA (tests/Harness/AppHost.ps1): así la
# suite no toca el registro de verdad ni corriendo elevada, igual
# que redirige settings.json (regla 28). En la aplicación de verdad
# siempre está armada.
$RegistryWriteArmed = $true

function Get-RegistryWriteArmed { [bool]$script:RegistryWriteArmed }
function Set-RegistryWriteArmed { param([bool]$On) $script:RegistryWriteArmed = $On }

# ---- lista blanca de rutas ------------------------------------
#
# Prefijos. Una ruta candidata vale si ES uno de estos o si CUELGA
# de él. Añadir una rama es añadir una línea aquí.
$RegistryWriteAllowlist = @(
    'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft'
    'HKEY_CURRENT_USER\Software\Policies\Microsoft'
    'HKEY_CURRENT_USER\Control Panel\Desktop'
    'HKEY_CURRENT_USER\Control Panel\Mouse'
    # Rama de las pruebas (tests/Harness/Fixtures.ps1).
    'HKEY_CURRENT_USER\Software\OptimizadorPC'
)

# ---- lista blanca de VALORES -------------------------------------
#
# Lo que no se puede abrir como rama entera. Aquí la clave tiene que
# ser EXACTAMENTE esa -nada de lo que cuelga de ella- y el nombre del
# valor, uno de los de su lista. Así se puede escribir el Start de
# SysMain sin abrir ...\Services, o DisableWpbtExecution sin abrir
# Session Manager (debajo viven KnownDLLs, BootExecute, Environment).
# Añadir un valor es añadir un nombre aquí, y es una decisión de
# seguridad igual que una rama.
$RegistryWriteAllowedValues = @(
    # TCP/IP global (NO ...\Parameters\Interfaces\{GUID}).
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
       Names = @('DefaultTTL', 'Tcp1323Opts', 'TcpTimedWaitDelay', 'MaxUserPort') }
    # Servidor SMB (compartir archivos de este equipo).
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
       Names = @('autodisconnect', 'Size', 'EnableOplocks', 'IRPStackSize',
                 'SharingViolationDelay', 'SharingViolationRetries') }
    # Tipo de inicio de servicios concretos: solo Start, uno a uno.
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SysMain';      Names = @('Start') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DiagTrack';    Names = @('Start') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\lfsvc';        Names = @('Start') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MapsBroker';   Names = @('Start') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CscService';   Names = @('Start') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\StorSvc';      Names = @('Start') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess'; Names = @('Start') }
    # Session Manager y dos de sus subclaves.
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager'
       Names = @('DisableWpbtExecution') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
       Names = @('EnablePrefetcher') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
       Names = @('HibernateEnabled') }
    # Optimización de distribución (la de Configuración, no la directiva).
    @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
       Names = @('DODownloadMode', 'DownloadMode') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings'
       Names = @('DownloadMode') }
    # Privacidad.
    @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
       Names = @('AllowTelemetry') }
    @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
       Names = @('Value') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';             Names = @('Enabled') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy'
       Names = @('TailoredExperiencesWithDiagnosticDataEnabled') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy';        Names = @('HasAccepted') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Input\TIPC';                                        Names = @('Enabled') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization'
       Names = @('RestrictImplicitInkCollection', 'RestrictImplicitTextCollection') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization\TrainedDataStore';             Names = @('HarvestContacts') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Personalization\Settings';                          Names = @('AcceptedPrivacyPolicy') }
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';          Names = @('Start_TrackProgs') }
    # Barra de tareas.
    @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
       Names = @('TaskbarEndTask') }
)

# Raíz sin abreviar y en mayúsculas, sin barra final. Deja el
# resto tal cual: las claves del registro NO distinguen mayúsculas,
# de eso se encarga la comparación.
function Get-NormalizedRegistryPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $parts = $Path.Trim().TrimEnd('\').Split('\', 2)
    if ($parts.Count -lt 2) { return '' }

    $root = switch ($parts[0].ToUpperInvariant()) {
        'HKLM' { 'HKEY_LOCAL_MACHINE' }
        'HKCU' { 'HKEY_CURRENT_USER' }
        default { $parts[0].ToUpperInvariant() }
    }
    "$root\$($parts[1])"
}

# Sin -Name solo valen las ramas: la lista de valores exige saber
# QUÉ valor se va a escribir, y sin él la respuesta es no.
function Test-RegistryWriteAllowed {
    param([string]$Path, [string]$Name)

    $norm = Get-NormalizedRegistryPath $Path
    if (-not $norm) { return $false }

    foreach ($entry in $RegistryWriteAllowlist) {
        $e = Get-NormalizedRegistryPath $entry
        if (-not $e) { continue }
        if ([string]::Equals($norm, $e, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($norm.StartsWith($e + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }

    if ([string]::IsNullOrEmpty($Name)) { return $false }

    foreach ($entry in $RegistryWriteAllowedValues) {
        $e = Get-NormalizedRegistryPath $entry.Path
        if (-not [string]::Equals($norm, $e, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        foreach ($n in $entry.Names) {
            if ([string]::Equals($Name, $n, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    }
    $false
}

# ---- texto declarado -> valor tipado -------------------------

# El Type declarado ('DWord', 'String'...) o su forma REG_* al
# RegistryValueKind de .NET. Un tipo que no se reconoce es $null.
function Resolve-RegistryKind {
    param([string]$Type)

    if ([string]::IsNullOrWhiteSpace($Type)) { return $null }
    $t = ($Type.Trim().ToUpperInvariant()) -replace '^REG_', ''

    $name = switch ($t) {
        'SZ'           { 'String' }
        'STRING'       { 'String' }
        'EXPAND_SZ'    { 'ExpandString' }
        'EXPANDSTRING' { 'ExpandString' }
        'MULTI_SZ'     { 'MultiString' }
        'MULTISTRING'  { 'MultiString' }
        'DWORD'        { 'DWord' }
        'QWORD'        { 'QWord' }
        'BINARY'       { 'Binary' }
        default        { $Type.Trim() }
    }

    try { [Microsoft.Win32.RegistryValueKind]$name } catch { $null }
}

<#
    Convierte el texto declarado (Recommended / Default) al valor
    .NET que hay que escribir, según el tipo.

    Devuelve { Ok; Reason; Kind; Data }.
      Reason = 'ok'          -> Data lleva el valor tipado
               'typefail'    -> el texto no cuadra con el tipo
               'unsupported' -> tipo que todavía no se sabe escribir
#>
function ConvertTo-RegistryData {
    param([AllowEmptyString()][string]$Text, [string]$Type)

    $kind = Resolve-RegistryKind $Type
    if ($null -eq $kind) {
        return [PSCustomObject]@{ Ok = $false; Reason = 'typefail'; Kind = $null; Data = $null }
    }

    switch ($kind) {

        ([Microsoft.Win32.RegistryValueKind]::DWord) {
            $n = ConvertTo-RegistryNumber $Text
            if ($null -eq $n -or $n -gt [uint32]::MaxValue) {
                return [PSCustomObject]@{ Ok = $false; Reason = 'typefail'; Kind = $kind; Data = $null }
            }
            # .NET escribe un DWord como Int32: 0xFFFFFFFF se pasa como -1.
            $i = [System.BitConverter]::ToInt32([System.BitConverter]::GetBytes([uint32]$n), 0)
            [PSCustomObject]@{ Ok = $true; Reason = 'ok'; Kind = $kind; Data = $i }
        }

        ([Microsoft.Win32.RegistryValueKind]::QWord) {
            $n = ConvertTo-RegistryNumber $Text
            if ($null -eq $n) {
                return [PSCustomObject]@{ Ok = $false; Reason = 'typefail'; Kind = $kind; Data = $null }
            }
            $l = [System.BitConverter]::ToInt64([System.BitConverter]::GetBytes([uint64]$n), 0)
            [PSCustomObject]@{ Ok = $true; Reason = 'ok'; Kind = $kind; Data = $l }
        }

        ([Microsoft.Win32.RegistryValueKind]::Binary) {
            $hex = ($Text -replace '[\s,:\-]', '')
            if ($hex.Length -eq 0 -or ($hex.Length % 2) -ne 0 -or $hex -notmatch '^[0-9a-fA-F]+$') {
                return [PSCustomObject]@{ Ok = $false; Reason = 'typefail'; Kind = $kind; Data = $null }
            }
            $bytes = New-Object 'byte[]' ($hex.Length / 2)
            for ($i = 0; $i -lt $bytes.Length; $i++) {
                $bytes[$i] = [System.Convert]::ToByte($hex.Substring($i * 2, 2), 16)
            }
            [PSCustomObject]@{ Ok = $true; Reason = 'ok'; Kind = $kind; Data = $bytes }
        }

        ([Microsoft.Win32.RegistryValueKind]::MultiString) {
            # El modelo de -Registry declara Recommended/Default como
            # UNA cadena, así que no hay forma de expresar una lista
            # sin ambigüedad. Se rechaza en vez de adivinar.
            [PSCustomObject]@{ Ok = $false; Reason = 'unsupported'; Kind = $kind; Data = $null }
        }

        default {
            # String / ExpandString: el texto tal cual. Una ExpandString
            # se guarda SIN expandir (%VAR%\...); Windows la expande al leerla.
            [PSCustomObject]@{ Ok = $true; Reason = 'ok'; Kind = $kind; Data = [string]$Text }
        }
    }
}

# ---- copia de seguridad -------------------------------------
#
# El valor y el tipo anteriores a cada escritura, en memoria. Es
# el "deshacer" de verdad: OFF restaura el Default declarado, pero
# si el valor estaba personalizado, aquí queda lo que había.
#
# State es lo que dijo la lectura previa ('read' / 'missing' /
# 'denied'). Existed solo es $true con 'read'; para saber que el
# valor NO existía hay que mirar State -eq 'missing': un 'denied'
# también deja Existed en $false y ahí no se sabe nada.
$RegistrySnapshots = New-Object System.Collections.Generic.List[object]

function Add-RegistrySnapshot {
    param([string]$Path, [string]$Name, $Kind, $Value, [bool]$Existed, [string]$State = '')
    $script:RegistrySnapshots.Add([PSCustomObject]@{
        Time    = [DateTime]::Now
        Path    = $Path
        Name    = $Name
        Kind    = $Kind
        Value   = $Value
        Existed = $Existed
        State   = $State
    })
}

function Get-RegistrySnapshots  { $script:RegistrySnapshots.ToArray() }
function Clear-RegistrySnapshots { $script:RegistrySnapshots.Clear() }

<#
    La PRIMERA copia de un valor en esta sesión: cómo estaba antes de
    que el programa lo tocara por primera vez. $null si no lo ha
    tocado. Es lo que permite a OFF saber que un valor no existía y
    borrarlo en vez de escribir el Default (core/Registry/SettingApply.ps1).
#>
function Get-RegistrySnapshotOrigin {
    param([string]$Path, [string]$Name)

    $norm = Get-NormalizedRegistryPath $Path
    if (-not $norm) { return $null }
    foreach ($snap in $script:RegistrySnapshots) {
        if (-not [string]::Equals((Get-NormalizedRegistryPath $snap.Path), $norm, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ([string]::Equals([string]$snap.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) { return $snap }
    }
    $null
}

# ---- diagnóstico de la escritura --------------------------

# ¿Corre el proceso con privilegios de administrador? Escribir en
# HKLM sin esto SIEMPRE falla; saberlo ANTES evita adivinar.
function Test-ProcessElevated {
    try {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($id)
        [bool]$principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { $false }
}

# ¿Existe la CLAVE (el contenedor), sin crearla?
#   $true  -> está
#   $false -> no está (habría que crearla)
#   $null  -> no se pudo comprobar (sin permiso, raíz mala)
function Test-RegistryKeyExists {
    param([string]$Path)

    $parts = $Path.Split('\', 2)
    if ($parts.Count -lt 2) { return $null }
    $hive = $RegistryHives[$parts[0].ToUpper()]
    if (-not $hive) { return $null }

    $base = $null; $key = $null
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey($parts[1])
        return ($null -ne $key)
    }
    catch { return $null }
    finally {
        if ($key)  { $key.Dispose() }
        if ($base) { $base.Dispose() }
    }
}

# PowerShell envuelve la excepción de un método .NET en
# MethodInvocationException; la de verdad -UnauthorizedAccess,
# Security...- está en InnerException. Aquí se desenvuelve.
function Resolve-RegistryException {
    param($ErrorRecord)
    $ex = $ErrorRecord.Exception
    if (($ex -is [System.Management.Automation.MethodInvocationException] -or
         $ex -is [System.Management.Automation.RuntimeException]) -and $ex.InnerException) {
        return $ex.InnerException
    }
    $ex
}

# Traduce la excepción de SetValue/CreateSubKey a un motivo
# ACCIONABLE. No hay IPC: 'BACKEND_EXCEPTION' es el cajón de
# sastre para una excepción de .NET que no encaja en las demás.
function Get-RegistryWriteFailReason {
    param($Exception)

    if ($Exception -is [System.Security.SecurityException] -or
        $Exception -is [System.UnauthorizedAccessException]) {
        return 'ACCESS_DENIED'
    }
    if ($Exception -is [System.ArgumentException]) {
        # SetValue lanza ArgumentException cuando el dato no cuadra
        # con el RegistryValueKind pedido.
        return 'TYPE_MISMATCH'
    }
    if ($Exception -is [System.IO.IOException]) {
        # La clave se borró entre abrir y escribir, o está marcada
        # para borrado.
        return 'KEY_NOT_FOUND'
    }
    'BACKEND_EXCEPTION'
}

# '0x80070005' a partir del HResult de la excepción (código Win32).
# El HResult llega como Int32 con signo (0x80070005 = -2147024891);
# [uint32] de un negativo revienta en 5.1, así que se enmascara a
# 32 bits, que es lo mismo sin castear.
function Format-HResult {
    param($Exception)
    try {
        if ($null -eq $Exception -or 0 -eq $Exception.HResult) { return '' }
        '0x{0:X8}' -f ([int64]$Exception.HResult -band 0xFFFFFFFFL)
    }
    catch { '' }
}

<#
    Lee un valor SIN expandir las variables de entorno, para la
    copia de seguridad y para la comprobación posterior a la
    escritura. Read-RegistryValueRaw sí las expande (%SystemRoot%
    -> C:\Windows), así que con una ExpandString la comprobación
    "lo que escribí == lo que leo" fallaría siempre. Aquí se lee
    lo que hay ESCRITO, tal cual.

    Solo se llama con la ruta ya validada (raíz conocida). No lanza.
#>
function Get-RegistryStoredValue {
    param([string]$Path, [string]$Name)

    $parts = $Path.Split('\', 2)
    $hive = $RegistryHives[$parts[0].ToUpper()]

    $base = $null; $key = $null
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey($parts[1])
        if ($null -eq $key) { return (New-RegistryResult 'missing') }

        $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value) { return (New-RegistryResult 'missing') }

        New-RegistryResult 'read' $value $key.GetValueKind($Name)
    }
    catch { New-RegistryResult 'denied' }
    finally {
        if ($key)  { $key.Dispose() }
        if ($base) { $base.Dispose() }
    }
}

# ---- la escritura -----------------------------------------

function New-RegistryWriteResult {
    param([string]$State, [string]$Old = '', [string]$New = '', $Kind = $null,
          [bool]$Verified = $false, $RawValue = $null)
    [PSCustomObject]@{
        State = $State; Old = $Old; New = $New; Kind = $Kind
        Verified = $Verified; RawValue = $RawValue
    }
}

# Las líneas del log de una escritura. TRES bloques explícitos, con
# el Detail como texto técnico (no se traduce) y el Status como
# palabra de color (regla 15).

# Antes de escribir: qué se va a hacer y qué dice la validación previa.
function Write-RegistryWriteAttempt {
    param([hashtable]$Info)

    $d = 'action={0} | requested={1} | valuename={2} | type={3} | oldvalue={4} | newvalue={5}' -f `
        $Info.Action, $Info.Requested, $Info.Name, $Info.Type, $Info.Old, $Info.New
    $d += ' | key_exists={0} | value_exists={1} | existing_type={2} | type_match={3} | convertible={4} | elevated={5}' -f `
        $Info.KeyExists, $Info.ValueExists, $Info.ExistingType, $Info.TypeMatch, $Info.Convertible, $Info.Elevated

    Write-AppLog -Source 'registry' -Level 'info' -Status 'write attempt' `
        -Message "$($Info.Path)\$($Info.Name)" -Detail $d
}

# El fallo, CON motivo accionable, excepción, código y traza.
function Write-RegistryWriteFailure {
    param([hashtable]$Info, [string]$Reason, $ErrorRecord, [double]$Ms)

    $d = "reason=$Reason | action=$($Info.Action)"
    if ($ErrorRecord) {
        $ex = Resolve-RegistryException $ErrorRecord
        $d += ' | exception={0}' -f $ex.GetType().FullName
        $d += ' | message={0}'   -f (($ex.Message -replace '\s+', ' ').Trim())
        $hres = Format-HResult $ex
        if ($hres)              { $d += " | hresult=$hres" }
        if ($ex.InnerException) { $d += ' | inner={0}' -f $ex.InnerException.GetType().Name }
        $stack = ($ErrorRecord.ScriptStackTrace -replace '[\r\n]+', ' <- ').Trim()
        if ($stack)             { $d += " | stack=$stack" }
    }
    $d += ' | {0:N1} ms' -f $Ms

    Write-AppLog -Source 'registry' -Level 'error' -Status 'write failed' `
        -Message "$($Info.Path)\$($Info.Name)" -Detail $d
}

# El éxito, con el tiempo. La palabra de color distingue aplicar
# (ON) de restaurar (OFF).
function Write-RegistryWriteSuccess {
    param([hashtable]$Info, [double]$Ms)

    $status = if ($Info.Requested -eq 'OFF') { 'restored' } else { 'applied' }
    $d = 'action={0} | requested={1} | type={2} | old={3} | new={4} | {5:N1} ms' -f `
        $Info.Action, $Info.Requested, $Info.Type, $Info.Old, $Info.New, $Ms

    Write-AppLog -Source 'registry' -Level 'info' -Status $status `
        -Message "$($Info.Path)\$($Info.Name)" -Detail $d
}

# Después de escribir: relectura inmediata y su veredicto.
function Write-RegistryPostValidation {
    param([hashtable]$Info, [string]$Expected, [string]$Actual, [bool]$Ok)

    $result = if ($Ok) { 'SUCCESS' } else { 'FAILED' }
    Write-AppLog -Source 'registry' -Level $(if ($Ok) { 'info' } else { 'error' }) `
        -Status 'post write' -Message "$($Info.Path)\$($Info.Name)" `
        -Detail ('expected={0} | actual={1} | result={2}' -f $Expected, $Actual, $result)
}

# Un rechazo temprano (antes de tocar el registro): desarmado,
# ruta mala, bloqueado, tipo que no convierte, tipo real distinto.
function Write-RegistryWriteRejected {
    param([hashtable]$Info, [string]$Status, [string]$Reason, [double]$Ms)

    $d = "reason=$Reason | action=$($Info.Action)"
    if ($Info.Requested) { $d += " | requested=$($Info.Requested)" }
    if ($Info.Type)      { $d += " | type=$($Info.Type)" }
    $d += ' | {0:N1} ms' -f $Ms

    $level = if ($Status -in @('disarmed', 'no change')) { 'warn' } else { 'error' }
    Write-AppLog -Source 'registry' -Level $level -Status $Status `
        -Message "$($Info.Path)\$($Info.Name)" -Detail $d
}

<#
    Escribe UN valor del registro, respetando su tipo.

        $r = Write-RegistryValue -Path '...' -Name 'X' -Type 'DWord' `
                                 -Text '0xFFFFFFFF' -Requested 'ON'

    Devuelve { State; Old; New; Kind; Verified; RawValue }.

        State  'written'     -> escrito y comprobado por relectura
               'nochange'    -> ya estaba en el valor destino
               'blocked'     -> la ruta no está en la lista blanca
               'badpath'     -> la raíz no se reconoce
               'typefail'    -> el texto no cuadra con el tipo
               'unsupported' -> tipo que todavía no se sabe escribir
               'denied'      -> sin permisos, o la relectura no cuadra
               'disarmed'    -> la escritura está desarmada (pruebas)
#>
function Write-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [ValidateSet('ON', 'OFF', '')][string]$Requested = '',
        [string]$Action = 'SetValue'
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $info = @{
        Path = $Path; Name = $Name; Type = $Type; Action = $Action; Requested = $Requested
        Old = '(not read)'; New = '(not converted)'
        KeyExists = '?'; ValueExists = '?'; ExistingType = '?'; TypeMatch = '?'
        Convertible = '?'; Elevated = (Test-ProcessElevated)
    }

    # 0. ¿Armada? El arnés la desarma para no tocar el registro real.
    if (-not (Get-RegistryWriteArmed)) {
        Write-RegistryWriteRejected $info 'disarmed' 'WRITE_DISARMED' $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'disarmed')
    }

    # 1. Raíz válida.
    $parts = $Path.Split('\', 2)
    if ($parts.Count -lt 2 -or -not $RegistryHives[$parts[0].ToUpper()]) {
        Write-RegistryWriteRejected $info 'invalid path' 'INVALID_PATH' $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'badpath')
    }

    # 2. Lista blanca.
    if (-not (Test-RegistryWriteAllowed -Path $Path -Name $Name)) {
        Write-RegistryWriteRejected $info 'blocked' 'PATH_NOT_ALLOWED' $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'blocked')
    }

    # 3. Texto -> valor tipado, respetando ESTRICTAMENTE el tipo.
    $conv = ConvertTo-RegistryData -Text $Text -Type $Type
    $info.Convertible = [string][bool]$conv.Ok
    if (-not $conv.Ok) {
        $reason = if ($conv.Reason -eq 'unsupported') { 'TYPE_UNSUPPORTED' } else { 'VALUE_NOT_CONVERTIBLE' }
        Write-RegistryWriteRejected $info $conv.Reason $reason $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult $conv.Reason)
    }
    $info.New = Format-RegistryValue $conv.Data $conv.Kind

    # 4. VALIDACIÓN PREVIA: clave, valor, tipo real, permisos. Y la
    #    copia de seguridad (valor + tipo anteriores).
    $keyExists = Test-RegistryKeyExists $Path
    $info.KeyExists = if ($null -eq $keyExists) { 'unknown' } else { [string]$keyExists }

    $before = Get-RegistryStoredValue -Path $Path -Name $Name
    $info.ValueExists  = [string]($before.State -eq 'read')
    $info.Old = switch ($before.State) {
        'read'   { Format-RegistryValue $before.Value $before.Kind }
        'denied' { '(no access)' }
        default  { '(not set)' }
    }
    $info.ExistingType = if ($before.State -eq 'read') { [string]$before.Kind } else { '(none)' }
    $info.TypeMatch    = if ($before.State -ne 'read') { 'n/a' } else { [string]($before.Kind -eq $conv.Kind) }

    Add-RegistrySnapshot -Path $Path -Name $Name -Kind $before.Kind -Value $before.Value -Existed ($before.State -eq 'read') -State $before.State
    Write-AppLog -Source 'registry' -Level 'info' -Status 'snapshot' `
        -Message "$Path\$Name" -Detail ('old={0} | type={1} | existed={2}' -f $info.Old, $info.ExistingType, ($before.State -eq 'read'))

    Write-RegistryWriteAttempt $info

    # 4b. El valor EXISTE con otro tipo. No se pisa en silencio:
    #     eso es TYPE_MISMATCH y hay que verlo.
    if ($before.State -eq 'read' -and $before.Kind -ne $conv.Kind) {
        Write-RegistryWriteRejected $info 'type mismatch' 'TYPE_MISMATCH' $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'typemismatch' $info.Old $info.New $conv.Kind $false $before.Value)
    }

    # 5. ¿Ya está en el valor destino? No se escribe.
    if ($before.State -eq 'read' -and (Test-RegistryValueMatch $info.Old $info.New)) {
        Write-RegistryWriteRejected $info 'no change' 'ALREADY_SET' $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'nochange' $info.Old $info.New $conv.Kind $true $before.Value)
    }

    # 6. -WhatIf sale por aquí sin tocar nada.
    if (-not $PSCmdlet.ShouldProcess("$Path\$Name", "Set $Type = $Text")) {
        Write-RegistryWriteRejected $info 'no change' 'WHATIF' $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'nochange' $info.Old $info.New $conv.Kind $false $before.Value)
    }

    # 7. Escribir. La excepción se CAPTURA ENTERA (tipo, mensaje,
    #    HResult, traza) y se traduce a un motivo accionable.
    $base = $null; $key = $null; $err = $null
    try {
        # Registry64 explícito (regla de core/): sin él, un .exe de
        # 32 bits escribiría en Wow6432Node sin enterarse.
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHives[$parts[0].ToUpper()], [Microsoft.Win32.RegistryView]::Registry64)
        # CreateSubKey abre O CREA el contenedor. La ruta ES la clave;
        # el dato va DENTRO con SetValue.
        $key = $base.CreateSubKey($parts[1])
        if ($null -eq $key) { throw [System.IO.IOException]::new("CreateSubKey devolvio null para '$($parts[1])'") }
        $key.SetValue($Name, $conv.Data, $conv.Kind)
    }
    catch {
        $err = $_
    }
    finally {
        if ($key)  { $key.Dispose() }
        if ($base) { $base.Dispose() }
    }

    if ($err) {
        $reason = Get-RegistryWriteFailReason (Resolve-RegistryException $err)
        Write-RegistryWriteFailure $info $reason $err $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'denied' $info.Old $info.New $conv.Kind $false $before.Value)
    }

    # 8. POST_WRITE_VALIDATION: relectura inmediata (sin expandir: se
    #    comprueba lo ESCRITO, no lo que Windows devolvería expandido).
    $after     = Get-RegistryStoredValue -Path $Path -Name $Name
    $afterText = if ($after.State -eq 'read') { Format-RegistryValue $after.Value $after.Kind } else { '(not set)' }
    $verified  = ($after.State -eq 'read') -and (Test-RegistryValueMatch $afterText $info.New)

    Write-RegistryPostValidation $info $info.New $afterText $verified

    if ($verified) {
        Write-RegistryWriteSuccess $info $watch.Elapsed.TotalMilliseconds
        return (New-RegistryWriteResult 'written' $info.Old $afterText $after.Kind $true $after.Value)
    }

    # Escribió sin excepción pero la relectura no cuadra: fallo
    # silencioso, ahora visible.
    Write-RegistryWriteFailure $info 'WRITE_NOT_PERSISTED' $null $watch.Elapsed.TotalMilliseconds
    New-RegistryWriteResult 'denied' $info.Old $afterText $after.Kind $false $after.Value
}

# ---- el borrado -------------------------------------------

<#
    BORRA un valor del registro: solo ese valor, la clave se queda.

        $r = Remove-RegistryValue -Path '...' -Name 'X' -Type 'DWord' -Requested 'OFF'

    Para qué: volver a "no configurado" un valor que de fábrica NO
    existe. Escribir el Default en su lugar deja una directiva puesta
    (Configuración la enseña "administrada por tu organización") aunque
    el número sea el mismo que usa Windows.

    Mismas garantías que Write-RegistryValue, en el mismo orden:
    desarmado, raíz, lista blanca (ruta Y nombre), copia previa, tipo,
    -WhatIf, relectura. Si se da -Type y el valor existe con OTRO tipo,
    no se toca (typemismatch): no es el valor que declara el ajuste.
    Sin nombre no se borra nada: el "(Predeterminado)" de una clave no
    lo declara ningún ajuste.

    Devuelve { State; Old; New; Kind; Verified; RawValue }.

        State  'deleted'      -> borrado y comprobado por relectura
               'nochange'     -> ya no existía, o -WhatIf
               'blocked'      -> ruta fuera de la lista blanca, o sin nombre
               'badpath'      -> la raíz no se reconoce
               'typefail'     -> el -Type no es un tipo conocido
               'typemismatch' -> existe con otro tipo; no se borra
               'denied'       -> sin permisos, o la relectura lo sigue viendo
               'disarmed'     -> el borrado está desarmado (pruebas)

    No lanza nunca.
#>
function Remove-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [string]$Type = '',
        [ValidateSet('ON', 'OFF', '')][string]$Requested = '',
        [string]$Action = 'DeleteValue'
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $info = @{
        Path = $Path; Name = $Name; Type = $Type; Action = $Action; Requested = $Requested
        Old = '(not read)'; New = '(absent)'
        KeyExists = '?'; ValueExists = '?'; ExistingType = '?'; TypeMatch = '?'
        Convertible = 'n/a'; Elevated = (Test-ProcessElevated)
    }

    try {
        # 0. ¿Armada? El mismo interruptor que la escritura.
        if (-not (Get-RegistryWriteArmed)) {
            Write-RegistryWriteRejected $info 'disarmed' 'WRITE_DISARMED' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'disarmed')
        }

        # 1. Raíz válida.
        $parts = $Path.Split('\', 2)
        if ($parts.Count -lt 2 -or -not $RegistryHives[$parts[0].ToUpper()]) {
            Write-RegistryWriteRejected $info 'invalid path' 'INVALID_PATH' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'badpath')
        }

        # 2. Lista blanca, y con nombre: sin él se borraría el valor
        #    predeterminado de la clave, que ningún ajuste declara.
        if ([string]::IsNullOrEmpty($Name)) {
            Write-RegistryWriteRejected $info 'blocked' 'EMPTY_VALUE_NAME' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'blocked')
        }
        if (-not (Test-RegistryWriteAllowed -Path $Path -Name $Name)) {
            Write-RegistryWriteRejected $info 'blocked' 'PATH_NOT_ALLOWED' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'blocked')
        }

        # 3. El tipo declarado, si lo hay, tiene que ser uno conocido.
        $kind = $null
        if ($Type) {
            $kind = Resolve-RegistryKind $Type
            if ($null -eq $kind) {
                Write-RegistryWriteRejected $info 'typefail' 'TYPE_UNKNOWN' $watch.Elapsed.TotalMilliseconds
                return (New-RegistryWriteResult 'typefail')
            }
        }

        # 4. Validación previa y copia de seguridad, como al escribir.
        $keyExists = Test-RegistryKeyExists $Path
        $info.KeyExists = if ($null -eq $keyExists) { 'unknown' } else { [string]$keyExists }

        $before = Get-RegistryStoredValue -Path $Path -Name $Name
        $info.ValueExists = [string]($before.State -eq 'read')
        $info.Old = switch ($before.State) {
            'read'   { Format-RegistryValue $before.Value $before.Kind }
            'denied' { '(no access)' }
            default  { '(not set)' }
        }
        $info.ExistingType = if ($before.State -eq 'read') { [string]$before.Kind } else { '(none)' }
        $info.TypeMatch = if ($before.State -ne 'read' -or $null -eq $kind) { 'n/a' } else { [string]($before.Kind -eq $kind) }

        Add-RegistrySnapshot -Path $Path -Name $Name -Kind $before.Kind -Value $before.Value -Existed ($before.State -eq 'read') -State $before.State
        Write-AppLog -Source 'registry' -Level 'info' -Status 'snapshot' `
            -Message "$Path\$Name" -Detail ('old={0} | type={1} | existed={2}' -f $info.Old, $info.ExistingType, ($before.State -eq 'read'))

        Write-RegistryWriteAttempt $info

        if ($before.State -eq 'denied') {
            Write-RegistryWriteFailure $info 'ACCESS_DENIED' $null $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'denied' $info.Old $info.New $null $false $null)
        }

        # 5. Ya no está: nada que borrar.
        if ($before.State -ne 'read') {
            Write-RegistryWriteRejected $info 'no change' 'ALREADY_ABSENT' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'nochange' $info.Old $info.New $null $true $null)
        }

        # 5b. Existe con otro tipo: no es el valor que declara el ajuste.
        if ($null -ne $kind -and $before.Kind -ne $kind) {
            Write-RegistryWriteRejected $info 'type mismatch' 'TYPE_MISMATCH' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'typemismatch' $info.Old $info.New $before.Kind $false $before.Value)
        }

        # 6. -WhatIf sale por aquí sin tocar nada.
        if (-not $PSCmdlet.ShouldProcess("$Path\$Name", 'Delete value')) {
            Write-RegistryWriteRejected $info 'no change' 'WHATIF' $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'nochange' $info.Old $info.New $before.Kind $false $before.Value)
        }

        # 7. Borrar EL VALOR. La clave se abre (no se crea) con permiso
        #    de escritura; DeleteValue sin lanzar si ya no está.
        $base = $null; $key = $null; $err = $null
        try {
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHives[$parts[0].ToUpper()], [Microsoft.Win32.RegistryView]::Registry64)
            $key = $base.OpenSubKey($parts[1], $true)
            if ($null -eq $key) { throw [System.IO.IOException]::new("OpenSubKey devolvio null para '$($parts[1])'") }
            $key.DeleteValue($Name, $false)
        }
        catch {
            $err = $_
        }
        finally {
            if ($key)  { $key.Dispose() }
            if ($base) { $base.Dispose() }
        }

        if ($err) {
            $reason = Get-RegistryWriteFailReason (Resolve-RegistryException $err)
            Write-RegistryWriteFailure $info $reason $err $watch.Elapsed.TotalMilliseconds
            return (New-RegistryWriteResult 'denied' $info.Old $info.New $before.Kind $false $before.Value)
        }

        # 8. Relectura: tiene que haber desaparecido.
        $after     = Get-RegistryStoredValue -Path $Path -Name $Name
        $afterText = switch ($after.State) {
            'read'    { Format-RegistryValue $after.Value $after.Kind }
            'missing' { '(absent)' }
            default   { '(no access)' }
        }
        $verified = ($after.State -eq 'missing')

        Write-RegistryPostValidation $info $info.New $afterText $verified

        if ($verified) {
            $d = 'action={0} | requested={1} | type={2} | old={3} | new=(absent) | {4:N1} ms' -f `
                $info.Action, $info.Requested, $info.ExistingType, $info.Old, $watch.Elapsed.TotalMilliseconds
            Write-AppLog -Source 'registry' -Level 'info' -Status 'deleted' -Message "$Path\$Name" -Detail $d
            return (New-RegistryWriteResult 'deleted' $info.Old '(absent)' $null $true $null)
        }

        Write-RegistryWriteFailure $info 'DELETE_NOT_PERSISTED' $null $watch.Elapsed.TotalMilliseconds
        New-RegistryWriteResult 'denied' $info.Old $afterText $after.Kind $false $after.Value
    }
    catch {
        # Red de seguridad: core/ no lanza hacia arriba (CLAUDE.md).
        Write-RegistryWriteFailure $info 'BACKEND_EXCEPTION' $_ $watch.Elapsed.TotalMilliseconds
        New-RegistryWriteResult 'denied' $info.Old $info.New
    }
}
