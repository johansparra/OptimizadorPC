# ============================================================
# core/Diagnostics/Log.ps1
# Registro de actividad: qué ha hecho el programa y cuándo.
#
# Vive en core/ porque es información del sistema, no de la
# interfaz: aquí no hay ni un control de WPF. Quien quiera
# enseñarlo -hoy ui/Components/Shell/LogPanel.ps1- pide las entradas
# con Get-AppLog y las pinta como le parezca.
#
# Dos reglas de la casa, las mismas que el resto de core/:
#
#   1. NADA lanza una excepción hacia arriba. Si no se puede
#      escribir el archivo de volcado se devuelve $null; apuntar
#      lo que pasa jamás debe tumbar lo que estaba pasando.
#
#   2. Se guardan HECHOS, no frases traducidas. El campo Status
#      lleva una palabra en inglés ('read', 'no access'...) que
#      la interfaz pasa por T; así el idioma se decide al pintar
#      y el mismo registro sirve para los dos.
#
# El buffer es circular y vive en memoria: al cerrar se pierde,
# salvo que se haya volcado con Export-AppLog.
# ============================================================

# Tope de entradas guardadas. Al pasarse se van tirando las más
# viejas y se cuentan aparte, para poder decir "faltan N".
$AppLogCapacity = 1000

$AppLogEntries = New-Object System.Collections.Generic.List[object]
$AppLogDropped = 0

<#
    Apunta una línea en el registro de actividad.

        Write-AppLog -Source 'registry' -Status 'read' `
                     -Message 'HKEY_LOCAL_MACHINE\...\Valor' `
                     -Detail  '5 (0x00000005) - DWord - 0,4 ms'

    Message   La línea principal. Es TEXTO TÉCNICO -rutas, nombres
              de valor, cifras- y por eso no se traduce.
    Status    Palabra corta en inglés para la etiqueta de color.
              La interfaz la pasa por T; $null la deja sin etiqueta.
    Detail    Segunda línea gris, opcional.
    Level     'info' | 'warn' | 'error'. Decide el color.
    Source    De dónde viene: 'registry', 'app'...

    No devuelve nada: se llama desde sitios que están calculando
    otra cosa y un valor suelto se colaría en su salida.
#>
function Write-AppLog {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('info', 'warn', 'error')][string]$Level = 'info',
        [string]$Source = 'app',
        [string]$Status,
        [string]$Detail
    )

    $AppLogEntries.Add([PSCustomObject]@{
        Time    = [DateTime]::Now
        Level   = $Level
        Source  = $Source
        Status  = $Status
        Message = $Message
        Detail  = $Detail
    })

    # Buffer circular: si se pasa del tope, fuera la más vieja.
    while ($AppLogEntries.Count -gt $AppLogCapacity) {
        $AppLogEntries.RemoveAt(0)
        $script:AppLogDropped++
    }
}

<#
    Entradas guardadas, de la más vieja a la más nueva.

        Get-AppLog                       -> todas
        Get-AppLog -Source 'registry'    -> solo las del registro
        Get-AppLog -Level 'error'        -> solo los fallos
        Get-AppLog -Last 200             -> las 200 últimas

    Devuelve una copia: quien la reciba puede recorrerla con
    calma aunque entre tanto se apunte algo más.

    ENVUÉLVELO EN @(): al devolverlo, PowerShell desenrolla el
    array, así que con una sola entrada llega el objeto pelado.
    Es la misma convención que @($Category.Items) por todo el
    proyecto.
#>
function Get-AppLog {
    param([string]$Source, [string]$Level, [int]$Last = 0)

    # ToArray() y no @($AppLogEntries): una List[object] creada con
    # New-Object viene envuelta en un PSObject y el operador @()
    # revienta con "los tipos de argumentos no coinciden", en 5.1 y
    # en 7 (ver la regla 19 de CLAUDE.md).
    $items = $AppLogEntries.ToArray()
    if ($Source) { $items = @($items | Where-Object { $_.Source -eq $Source }) }
    if ($Level)  { $items = @($items | Where-Object { $_.Level  -eq $Level }) }

    if ($Last -gt 0 -and $items.Count -gt $Last) {
        $items = @($items[($items.Count - $Last)..($items.Count - 1)])
    }

    $items
}

function Get-AppLogCount { $AppLogEntries.Count }

# Cuántas se han tirado por llenarse el buffer.
function Get-AppLogDropped { $AppLogDropped }

function Clear-AppLog {
    $AppLogEntries.Clear()
    $script:AppLogDropped = 0
}

# ---- Volcado a texto ----------------------------------------

<#
    Una entrada como línea de archivo:

        2026-09-03 20:14:03.118  INFO   registry  [read] HKEY_...\Valor  |  5 - DWord - 0,4 ms

    El archivo va siempre en inglés: es para pegarlo en un
    informe, no para leerlo en pantalla.
#>
function Format-AppLogLine {
    param([Parameter(Mandatory)]$Entry)

    $line = '{0:yyyy-MM-dd HH:mm:ss.fff}  {1,-5}  {2,-9}' -f $Entry.Time, $Entry.Level.ToUpper(), $Entry.Source
    if ($Entry.Status)  { $line += '  [{0}]' -f $Entry.Status }
    if ($Entry.Message) { $line += '  {0}'   -f $Entry.Message }
    if ($Entry.Detail)  { $line += '  |  {0}' -f $Entry.Detail }
    $line
}

# Todo el registro como un único texto, con cabecera.
function Format-AppLogText {
    # El resumen se arma fuera del Add(): dentro de los paréntesis
    # de un método, la coma separa ARGUMENTOS, así que el -f se
    # quedaría solo con el primero y {1} se saldría de la lista.
    $summary = 'Entries: {0}' -f $AppLogEntries.Count
    if ($AppLogDropped -gt 0) { $summary += ' (+{0} dropped)' -f $AppLogDropped }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Optimizador PC - activity log')
    $lines.Add('Generated: {0:yyyy-MM-dd HH:mm:ss}' -f [DateTime]::Now)
    $lines.Add($summary)
    $lines.Add('')

    foreach ($entry in $AppLogEntries) { $lines.Add((Format-AppLogLine $entry)) }
    $lines -join [Environment]::NewLine
}

# Junto a settings.json, y por el mismo motivo: el .exe es
# portable y su carpeta puede no admitir escritura.
function Get-AppLogFolder {
    Join-Path $env:APPDATA 'OptimizadorPC\logs'
}

<#
    Vuelca el registro a un archivo de texto.

        $ruta = Export-AppLog             -> %APPDATA%\...\logs\log-<fecha>.txt
        $ruta = Export-AppLog -Path 'C:\x.txt'

    Devuelve la ruta escrita, o $null si no se ha podido (sin
    permisos, disco lleno...). No lanza: quien llame decide qué
    contarle al usuario.
#>
function Export-AppLog {
    param([string]$Path)

    try {
        if (-not $Path) {
            $folder = Get-AppLogFolder
            $Path = Join-Path $folder ('log-{0:yyyyMMdd-HHmmss}.txt' -f [DateTime]::Now)
        }

        $folder = Split-Path -Parent $Path
        if ($folder -and -not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }

        # UTF-8 con BOM, que es lo que espera el Bloc de notas de
        # Windows al abrirlo con doble clic.
        [System.IO.File]::WriteAllText($Path, (Format-AppLogText), (New-Object System.Text.UTF8Encoding($true)))
        $Path
    }
    catch {
        $null
    }
}
