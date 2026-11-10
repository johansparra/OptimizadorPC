# ============================================================
# core/Registry/SettingStatus.ps1
# En qué estado está un ajuste, comparando lo que hay en el equipo
# con lo que declara ui/Data/Categories/.
#
# Cada clave de -Registry trae dos valores escritos a mano:
#
#     Recommended   el que propone el programa   ->  'optimized'
#     Default       el de fábrica de Windows     ->  'factory'
#
# o, en vez de Default, DefaultAbsent = $true: de fábrica el valor no
# existe (directivas). Ausente -> 'factory'; OFF lo borra.
#
# y core/Registry/CategoryState.ps1 le añade el que acaba de leer del
# equipo (Current). Comparar los tres da el estado del ajuste:
#
#     'optimized'   el equipo tiene el valor que propone el programa
#     'factory'     tiene el de fábrica, o no tiene ninguno y Windows
#                   está usando el suyo interno
#     'custom'      no es ninguno de los dos: alguien lo ha tocado
#     'unknown'     no se ha podido mirar -sin permiso, raíz mala o
#                   todavía sin leer-. No se afirma nada.
#
# El estado se calcula SIEMPRE que se lee (ver CategoryState.ps1), así
# que entrar en la sección y pulsar refrescar lo dejan al día solos.
#
# Vale igual para los servicios (-Service) y las tareas programadas
# (-ScheduledTask): sus entradas traen los mismos campos y se comparan
# con las mismas funciones. Ver Get-SettingTargets, abajo. Vive en
# core/Registry/ porque nació aquí; es el pegamento de los tres
# mecanismos, y no habla con Windows.
#
# Como todo lo de core/: no sabe de interfaz -devuelve palabras en
# inglés, sin traducir ni colores- y no lanza nunca.
# ============================================================

# Los cuatro estados, en el orden en que se enseñan. La interfaz los
# recorre en vez de escribirlos a mano.
$SettingStatusNames = @('optimized', 'factory', 'custom', 'unknown')

function Get-SettingStatusNames { $SettingStatusNames }

<#
    LOS OBJETIVOS DE UN AJUSTE: lo que toca en el equipo.

    Un ajuste puede declarar tres clases, cada una con su mecanismo en
    core/ y su lista blanca:

        -Registry       'registry'  una clave (core/Registry/Writer.ps1)
        -Service        'service'   el tipo de inicio de un servicio
                                    (core/Services/ServiceStartup.ps1)
        -ScheduledTask  'task'      si una tarea programada está
                                    habilitada (core/ScheduledTasks/)

    Las tres entradas son hashtables con el MISMO contrato para el
    estado: Recommended, Default (o DefaultAbsent, solo en el
    registro), y lo que deja la lectura -State, Current, Status-. Por
    eso el estado de una clave, de un servicio y de una tarea se
    calcula con la misma función (Get-RegistryKeyStatus): 'missing'
    es 'factory', lo que no se pudo leer es 'unknown', y lo demás se
    compara con Recommended y Default.

    Devuelve un objeto por objetivo: { Kind; Entry }. La entrada es la
    hashtable declarada: quien la rellene la rellena en el sitio.
#>
function Get-SettingTargets {
    param($Setting)

    if (-not $Setting) { return }
    foreach ($e in @($Setting.Registry))      { if ($e) { [PSCustomObject]@{ Kind = 'registry'; Entry = $e } } }
    foreach ($e in @($Setting.Service))       { if ($e) { [PSCustomObject]@{ Kind = 'service';  Entry = $e } } }
    foreach ($e in @($Setting.ScheduledTask)) { if ($e) { [PSCustomObject]@{ Kind = 'task';     Entry = $e } } }
}

# ¿Toca algo del equipo? Es lo que decide si la tarjeta lee el estado
# real y si su interruptor escribe.
function Test-SettingHasTargets {
    param($Setting)
    @(Get-SettingTargets $Setting).Count -gt 0
}

<#
    Un valor de registro escrito como texto, pasado a número. Si no
    lo parece, devuelve $null.

    Hace falta porque lo declarado y lo leído no tienen por qué venir
    escritos igual: '0xFFFFFFFF' y '4294967295' son el mismo DWord, y
    '-1' es como se escribe a mano ese mismo valor.
#>
function ConvertTo-RegistryNumber {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $t = $Text.Trim()

    try {
        if ($t -match '^0[xX][0-9a-fA-F]{1,16}$') { return [System.Convert]::ToUInt64($t.Substring(2), 16) }
        if ($t -match '^[0-9]{1,20}$')            { return [System.UInt64]::Parse($t) }

        # Un negativo declarado a mano es el mismo valor que se lee
        # sin signo: -1 en un DWord es 0xFFFFFFFF. Se reinterpreta
        # por bytes, no casteando, porque [uint32](-1) revienta.
        if ($t -match '^-[0-9]{1,19}$') {
            $n = [System.Int64]::Parse($t)
            if ($n -ge [System.Int32]::MinValue) {
                return [System.UInt64][System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([System.Int32]$n), 0)
            }
            return [System.BitConverter]::ToUInt64([System.BitConverter]::GetBytes($n), 0)
        }
    }
    catch { $null = $_ }

    $null
}

<#
    ¿Son el mismo valor?

    Si los dos lados parecen números -decimal, 0x... o negativo-, se
    comparan como números, que es lo que evita que '0x0000000A' y
    '10' pasen por distintos. Si no, como texto: sin espacios de más
    y sin distinguir mayúsculas.
#>
function Test-RegistryValueMatch {
    param([string]$Left, [string]$Right)

    if ([string]::IsNullOrEmpty($Left) -or [string]::IsNullOrEmpty($Right)) { return $false }

    $ln = ConvertTo-RegistryNumber $Left
    $rn = ConvertTo-RegistryNumber $Right
    if ($null -ne $ln -and $null -ne $rn) { return $ln -eq $rn }

    [string]::Equals($Left.Trim(), $Right.Trim(), [System.StringComparison]::OrdinalIgnoreCase)
}

<#
    El estado de UNA clave, comparando su Current -lo que se acaba de
    leer del equipo- con lo que declara ui/Data/Categories/.
#>
function Get-RegistryKeyStatus {
    param($Key)

    if (-not $Key) { return 'unknown' }

    # DefaultAbsent = $true: de fábrica el valor NO existe (una
    # directiva sin configurar). Entonces no hay Default con el que
    # comparar: ausente es 'factory' y cualquier valor puesto es el
    # recomendado o uno a medida.
    $absent = [bool]$Key.DefaultAbsent

    # Sin nada declarado con lo que comparar no se puede decir en qué
    # estado está: 'custom' sería una acusación sin pruebas.
    if ([string]::IsNullOrEmpty([string]$Key.Recommended) -and
        [string]::IsNullOrEmpty([string]$Key.Default) -and -not $absent) { return 'unknown' }

    # El valor no está puesto: Windows usa el suyo interno, así que el
    # equipo ESTÁ como salió de fábrica para este ajuste. No se compara
    # contra el Default declarado -que es solo el número que habría
    # que escribir para volver-, porque un valor ausente no es igual a
    # ninguno escrito.
    if ($Key.State -eq 'missing') { return 'factory' }

    # Sin permiso, raíz inventada o todavía sin leer.
    if ($Key.State -ne 'read') { return 'unknown' }

    # De fábrica se mira primero: si lo recomendado ya es lo de
    # fábrica, no hay nada aplicado y lo honesto es decir eso.
    if (-not $absent -and (Test-RegistryValueMatch $Key.Current $Key.Default)) { return 'factory' }
    if (Test-RegistryValueMatch $Key.Current $Key.Recommended) { return 'optimized' }
    'custom'
}

<#
    El estado de un ajuste ENTERO, a partir de todas sus claves:

        sin claves          ->  $null       no hay nada que mirar
        alguna sin leer     ->  'unknown'   no se puede afirmar nada
        todas de acuerdo    ->  ese estado
        unas y otras        ->  'custom'    aplicado a medias

    Hoy todos los ajustes declaran un solo objetivo -una clave, un
    servicio o una tarea-, pero la regla ya vale para los que declaren
    varios. Cuentan los tres (Get-SettingTargets).
#>
function Get-SettingStatus {
    param($Setting)

    if (-not $Setting) { return $null }

    $keys = @(Get-SettingTargets $Setting | ForEach-Object { $_.Entry })
    if ($keys.Count -eq 0) { return $null }

    $seen = @{}
    foreach ($key in $keys) {
        $status = Get-RegistryKeyStatus $key
        # Con una sola clave que no se haya podido leer, del conjunto
        # ya no se puede decir nada.
        if ($status -eq 'unknown') { return 'unknown' }
        $seen[$status] = $true
    }

    if ($seen.Count -eq 1) { return @($seen.Keys)[0] }

    # Unas de fábrica y otras optimizadas: el ajuste está a medias,
    # que es tanto como decir que lleva una combinación a medida.
    'custom'
}

<#
    Deja el estado escrito en el sitio: cada clave se queda con su
    Status y el ajuste con el suyo. Es lo que lee la interfaz.

    Devuelve el estado del ajuste.
#>
function Update-SettingStatus {
    param($Setting)

    if (-not $Setting) { return $null }

    foreach ($target in @(Get-SettingTargets $Setting)) { $target.Entry['Status'] = Get-RegistryKeyStatus $target.Entry }

    $status = Get-SettingStatus $Setting

    # Los ajustes salen de New-Setting, que ya reserva el campo. Lo
    # demás es para no lanzar si algún día llega otra cosa: un
    # PSCustomObject sin la propiedad se queja al asignarla.
    if ($Setting -is [hashtable])                   { $Setting['Status'] = $status }
    elseif ($Setting.PSObject.Properties['Status']) { $Setting.Status = $status }
    else { $Setting | Add-Member -NotePropertyName 'Status' -NotePropertyValue $status -Force }

    $status
}

<#
    Deja en el registro de actividad la EVALUACIÓN de cada clave del
    ajuste: tipo, valor leído, valor recomendado, valor de fábrica y
    el estado en que ha quedado. Es lo que hace auditable "¿por qué
    la tarjeta dice Optimizado?".

    Se llama SIEMPRE justo después de Update-SettingStatus: al leer
    una sección (core/Registry/CategoryState.ps1) y al aplicar un cambio
    (core/Registry/SettingApply.ps1). El Detail es técnico y no se
    traduce; 'checked' es la palabra de color (regla 15).
#>
function Write-SettingEvalLog {
    param($Setting)

    if (-not $Setting) { return }

    foreach ($target in @(Get-SettingTargets $Setting)) {
        $key = $target.Entry
        $current = if ($null -ne $key.Current) { [string]$key.Current } else { "($($key.State))" }
        $default = if ($key.DefaultAbsent) { '(absent)' } else { $key.Default }

        switch ($target.Kind) {
            'service' {
                $source  = 'services'
                $message = "service $($key.Name)"
                $type    = 'StartMode'
            }
            'task' {
                $source  = 'tasks'
                $message = "task $($key.Path)$($key.Name)"
                $type    = 'Enabled'
            }
            default {
                $source  = 'registry'
                $message = "$($key.Path)\$($key.Name)"
                $type    = $key.Type
            }
        }

        $detail = 'type={0} | current={1} | recommended={2} | default={3} | status={4}' -f `
            $type, $current, $key.Recommended, $default, $key.Status
        Write-AppLog -Source $source -Level 'info' -Status 'checked' -Message $message -Detail $detail
    }
}
