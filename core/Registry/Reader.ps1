# ============================================================
# core/Registry/Reader.ps1
# Lectura del registro de Windows. SOLO LECTURA.
#
# Esta es la primera pieza fuera de ui/: aquí vive lo que habla
# con el sistema, y no sabe nada de ventanas, tarjetas ni temas.
# Si algo de este archivo necesita un control de WPF, está en el
# sitio equivocado.
#
# Dos reglas de la casa:
#
#   1. NADA lanza una excepción hacia arriba. Una clave protegida
#      o una ruta que no existe son respuestas válidas, no fallos:
#      la interfaz debe poder pintarlas, no caerse.
#
#   2. Se distingue "no está" de "no se pudo leer". La primera es
#      información -Windows usa su valor interno-, la segunda es
#      un problema de permisos. Enseñarlas igual sería mentir.
# ============================================================

$RegistryHives = @{
    'HKEY_LOCAL_MACHINE' = [Microsoft.Win32.RegistryHive]::LocalMachine
    'HKEY_CURRENT_USER'  = [Microsoft.Win32.RegistryHive]::CurrentUser
    'HKEY_CLASSES_ROOT'  = [Microsoft.Win32.RegistryHive]::ClassesRoot
    'HKEY_USERS'         = [Microsoft.Win32.RegistryHive]::Users
    'HKLM'               = [Microsoft.Win32.RegistryHive]::LocalMachine
    'HKCU'               = [Microsoft.Win32.RegistryHive]::CurrentUser
}

<#
    Lee un valor del registro y lo apunta en el registro de
    actividad (core/Diagnostics/Log.ps1), que es lo que enseña el botón de
    log de la barra de título.

        $r = Read-RegistryValue 'HKEY_LOCAL_MACHINE\SOFTWARE\...' 'MiValor'

    Devuelve siempre un objeto con:

        State   'read'     -> se leyó; Value y Kind traen el dato
                'missing'  -> la ruta o el valor no existen
                'denied'   -> existe pero no se pudo leer
                'badpath'  -> la raíz de la ruta no se reconoce
        Value   El dato en crudo, tal cual lo da .NET (ojo: un
                DWord llega como Int32 CON SIGNO).
        Kind    El RegistryValueKind, o $null.

    La lectura de verdad está en Read-RegistryValueRaw; aquí solo
    se cronometra y se apunta. Separarlas mantiene la lectura sin
    nada alrededor y deja apagar el rastro cambiando un archivo.
#>
function Read-RegistryValue {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Read-RegistryValueRaw -Path $Path -Name $Name
    $watch.Stop()

    Write-RegistryLog -Path $Path -Name $Name -Result $result -Ms $watch.Elapsed.TotalMilliseconds

    $result
}

<#
    Apunta una lectura en el registro de actividad.

    El Message es la clave consultada y el Detail lo que se
    encontró: los dos son texto técnico y no se traducen. Lo
    único traducible es el Status, y por eso viaja como palabra
    suelta en inglés (ver core/Diagnostics/Log.ps1).

    Que un valor no exista NO es un fallo -Windows está usando su
    valor interno-, así que sale como aviso y no como error. Sin
    acceso o con una raíz inventada sí lo son.
#>
function Write-RegistryLog {
    param([string]$Path, [string]$Name, $Result, [double]$Ms)

    $took = '{0:N1} ms' -f $Ms

    switch ($Result.State) {
        'read' {
            Write-AppLog -Source 'registry' -Level 'info' -Status 'read' `
                -Message "$Path\$Name" `
                -Detail ('{0} - {1} - {2}' -f (Format-LogValue $Result.Value $Result.Kind), $Result.Kind, $took)
        }
        'missing' {
            Write-AppLog -Source 'registry' -Level 'warn' -Status 'not set' `
                -Message "$Path\$Name" -Detail $took
        }
        'denied' {
            Write-AppLog -Source 'registry' -Level 'error' -Status 'no access' `
                -Message "$Path\$Name" -Detail $took
        }
        default {
            Write-AppLog -Source 'registry' -Level 'error' -Status 'unknown root key' `
                -Message "$Path\$Name" -Detail $took
        }
    }
}

<#
    El valor tal y como se apunta en el log. A diferencia de la
    tarjeta -que enseña decimal o hexadecimal según pida cada
    clave con su campo Display- aquí no hay quien lo pida, así
    que de un número se ponen las dos formas:

        5 (0x00000005)

    Los textos largos se recortan: una MultiString puede traer
    cientos de líneas y el log es para leerlo de un vistazo.
#>
function Format-LogValue {
    param($Value, $Kind)

    $text = Format-RegistryValue $Value $Kind
    if ($null -eq $text) { return '' }

    if ($Kind -eq [Microsoft.Win32.RegistryValueKind]::DWord -or
        $Kind -eq [Microsoft.Win32.RegistryValueKind]::QWord) {
        $text += ' ({0})' -f (Format-RegistryValue $Value $Kind 'hex')
    }

    if ($text.Length -gt 120) { $text = $text.Substring(0, 117) + '...' }
    $text
}

# La lectura pelada, sin cronómetro ni rastro. Todo lo que dice
# la ayuda de Read-RegistryValue sobre los cuatro estados vale
# aquí: es esta función quien los decide.
#
# AllowEmptyString porque una ruta vacía tiene que salir como
# badpath y no como un error de enlace de parámetros: eso ocurre
# ANTES de entrar aquí, así que ni siquiera lo podríamos atrapar.
function Read-RegistryValueRaw {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $parts = $Path.Split('\', 2)
    if ($parts.Count -lt 2) { return (New-RegistryResult 'badpath') }

    $hive = $RegistryHives[$parts[0].ToUpper()]
    if (-not $hive) { return (New-RegistryResult 'badpath') }

    $base = $null
    $key = $null
    try {
        # Registry64 explícito: si el .exe se compilase a 32 bits,
        # HKLM\SOFTWARE se redirigiría solo a Wow6432Node y
        # estaríamos leyendo otras claves sin enterarnos.
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey($parts[1])
        if (-not $key) { return (New-RegistryResult 'missing') }

        $value = $key.GetValue($Name, $null)
        if ($null -eq $value) { return (New-RegistryResult 'missing') }

        New-RegistryResult 'read' $value $key.GetValueKind($Name)
    }
    catch [System.Security.SecurityException] {
        New-RegistryResult 'denied'
    }
    catch [System.UnauthorizedAccessException] {
        New-RegistryResult 'denied'
    }
    catch {
        New-RegistryResult 'denied'
    }
    finally {
        if ($key)  { $key.Dispose() }
        if ($base) { $base.Dispose() }
    }
}

function New-RegistryResult {
    param([string]$State, $Value = $null, $Kind = $null)
    [PSCustomObject]@{ State = $State; Value = $Value; Kind = $Kind }
}

<#
    Convierte a texto un valor leído, para poder enseñarlo.

    El caso que importa son los DWord: .NET los devuelve como
    Int32 CON SIGNO, así que NetworkThrottlingIndex = 0xFFFFFFFF
    llega como -1. Se reinterpreta sin signo para que coincida
    con lo que enseña el Editor del registro.

        Format-RegistryValue -1 DWord 'hex'  ->  '0xFFFFFFFF'
        Format-RegistryValue -1 DWord        ->  '4294967295'

    $As = 'hex' lo pide cada clave con su campo Display.
#>
function Format-RegistryValue {
    param($Value, $Kind, [string]$As = 'dec')

    if ($null -eq $Value) { return $null }

    switch ($Kind) {

        ([Microsoft.Win32.RegistryValueKind]::DWord) {
            $u = [System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([int32]$Value), 0)
            if ($As -eq 'hex') { '0x{0:X8}' -f $u } else { [string]$u }
        }

        ([Microsoft.Win32.RegistryValueKind]::QWord) {
            $u = [System.BitConverter]::ToUInt64([System.BitConverter]::GetBytes([int64]$Value), 0)
            if ($As -eq 'hex') { '0x{0:X16}' -f $u } else { [string]$u }
        }

        ([Microsoft.Win32.RegistryValueKind]::Binary) {
            ($Value | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
        }

        ([Microsoft.Win32.RegistryValueKind]::MultiString) {
            $Value -join '; '
        }

        default { [string]$Value }
    }
}
