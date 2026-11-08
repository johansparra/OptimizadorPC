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

# Número de la última entrada apuntada. Nunca baja, ni al vaciar: es
# el Id de cada entrada y lo que mira la interfaz para saber si hay
# algo nuevo que pintar (Sync-LogView).
$AppLogSequence = 0

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
    Items     El DETALLE, opcional: líneas que no caben en Detail y
              que no se enseñan hasta que se piden. Hoy, los archivos
              que borró una limpieza o la salida entera de un
              programa. Mismo texto técnico que Message: no se traduce.
    Level     'info' | 'warn' | 'error'. Decide el color.
    Source    De dónde viene: 'registry', 'app'...

    Cada entrada lleva además un Id que no se repite nunca.

    No devuelve nada: se llama desde sitios que están calculando
    otra cosa y un valor suelto se colaría en su salida.
#>
function Write-AppLog {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('info', 'warn', 'error')][string]$Level = 'info',
        [string]$Source = 'app',
        [string]$Status,
        [string]$Detail,
        [string[]]$Items
    )

    $script:AppLogSequence++
    $list = $null
    if ($Items -and $Items.Count -gt 0) { $list = [string[]]$Items }

    $AppLogEntries.Add([PSCustomObject]@{
        Id      = $script:AppLogSequence
        Time    = [DateTime]::Now
        Level   = $Level
        Source  = $Source
        Status  = $Status
        Message = $Message
        Detail  = $Detail
        Items   = $list
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

# El Id de la última entrada apuntada (0 si nunca se apuntó nada).
function Get-AppLogSequence { $script:AppLogSequence }

# Cuántas entradas guardadas traen detalle (Items).
function Get-AppLogDetailCount {
    @($AppLogEntries.ToArray() | Where-Object { $_.Items }).Count
}

# Cuántas se han tirado por llenarse el buffer.
function Get-AppLogDropped { $AppLogDropped }

function Clear-AppLog {
    $AppLogEntries.Clear()
    $script:AppLogDropped = 0
}

# ---- Volcado a texto ----------------------------------------

<#
    Una entrada como línea de archivo:

        [2026-09-03 20:14:03] [INFO] [REGISTRY] [read] HKEY_...\Valor | 5 - DWord - 0,4 ms

    CADA CAMPO FIJO ENTRE CORCHETES, y siempre los mismos tres por
    delante: cuándo, con qué gravedad y de dónde viene. Antes iban
    sueltos y alineados a columnas, que se lee bien pero obliga a
    contar espacios para separarlos; así cada campo se delimita
    solo y una línea se parte con una expresión regular de una
    línea, aunque el mensaje lleve espacios o barras.

    El estado -cuando lo hay- va como cuarto corchete, y el
    detalle detrás de una barra. Los dos son opcionales: sin ellos
    no queda ningún corchete vacío ni ninguna barra suelta.

    El archivo va siempre en inglés y en mayúsculas para nivel y
    origen: es para pegarlo en un informe, no para leerlo en
    pantalla. La interfaz no pasa por aquí -pinta los campos uno a
    uno-, así que este formato es solo el del volcado.
#>
function Format-AppLogLine {
    param([Parameter(Mandatory)]$Entry)

    $line = '[{0:yyyy-MM-dd HH:mm:ss}] [{1}] [{2}]' -f `
        $Entry.Time, ([string]$Entry.Level).ToUpper(), ([string]$Entry.Source).ToUpper()

    if ($Entry.Status)  { $line += ' [{0}]' -f $Entry.Status }
    if ($Entry.Message) { $line += ' {0}'   -f $Entry.Message }
    if ($Entry.Detail)  { $line += ' | {0}' -f $Entry.Detail }
    $line
}

<#
    Todo el registro como un único texto, con cabecera.

    -Detailed es la VISTA EXTENDIDA: debajo de cada entrada que traiga
    detalle (Items) van sus líneas, sangradas con cuatro espacios.
    Sin él, la cabecera dice cuántas entradas lo traían y que no va
    dentro, para que quien lea el archivo sepa que existe:

        [2026-11-08 14:56:25] [INFO] [CLEANUP] [succeeded] clean %TEMP% | exit=0 | ...
            Skipped, in use or no access (36):
              in use     C:\Users\...\Temp\e0fb7f80-....tmp
            Deleted (3256 files, 406.6 MB):
              12 KB      C:\Users\...\Temp\setup.log

    La sangría es lo que separa el detalle de las entradas: toda
    entrada empieza con '[' en la primera columna, y ninguna línea de
    detalle.
#>
function Format-AppLogText {
    param([switch]$Detailed)

    # El resumen se arma fuera del Add(): dentro de los paréntesis
    # de un método, la coma separa ARGUMENTOS, así que el -f se
    # quedaría solo con el primero y {1} se saldría de la lista.
    $summary = 'Entries: {0}' -f $AppLogEntries.Count
    if ($AppLogDropped -gt 0) { $summary += ' (+{0} dropped)' -f $AppLogDropped }

    $withDetail = Get-AppLogDetailCount
    $detailLine = $null
    if ($withDetail -gt 0) {
        $detailLine = if ($Detailed) { 'Details: included ({0} entries have them)' -f $withDetail }
                      else { 'Details: not included ({0} entries have them; save with details to get them)' -f $withDetail }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Optimizador PC - activity log')
    $lines.Add('Generated: {0:yyyy-MM-dd HH:mm:ss}' -f [DateTime]::Now)
    $lines.Add($summary)
    if ($detailLine) { $lines.Add($detailLine) }
    $lines.Add('')

    foreach ($entry in $AppLogEntries) {
        $lines.Add((Format-AppLogLine $entry))
        if ($Detailed -and $entry.Items) {
            foreach ($item in $entry.Items) { $lines.Add('    ' + $item) }
        }
    }
    $lines -join [Environment]::NewLine
}

# Junto a settings.json, y por el mismo motivo: el .exe es
# portable y su carpeta puede no admitir escritura.
function Get-AppLogFolder {
    Join-Path $env:APPDATA 'OptimizadorPC\logs'
}

<#
    El nombre que se propone al guardar:

        opt-2026-09-05_20-14-03.log

    Se lee igual que la fecha de dentro del archivo, pero con
    guiones donde iría lo que Windows no admite en un nombre. Los
    DOS PUNTOS de la hora son la trampa -ni : \ / * ? " < > |- y
    son justo lo que dejaría un formato descuidado: el archivo no
    se escribiría y no habría forma de saber por qué.
#>
function Get-AppLogFileName {
    'opt-{0:yyyy-MM-dd_HH-mm-ss}.log' -f [DateTime]::Now
}

<#
    Vuelca el registro a un archivo de texto.

        $ruta = Export-AppLog             -> %APPDATA%\...\logs\opt-<fecha>.log
        $ruta = Export-AppLog -Path 'D:\Informes\opt.log'

    Escribe el registro ENTERO -lo que quepa en el buffer, no las
    filas que haya pintadas-, así que el archivo puede llevar más
    de lo que se ve en pantalla.

    La ruta la elige quien llama: la interfaz la pide con el
    diálogo de Windows (ver ui/Components/Shell/LogPanel.ps1). Sin
    ruta se cae a la carpeta de APPDATA, que es el único sitio
    donde se puede escribir seguro.

    Con el registro VACÍO no escribe nada y devuelve $null: un
    archivo con la cabecera y ninguna línea no le sirve a nadie, y
    borrarlo después sería cosa del usuario. La interfaz además
    apaga el botón, pero la garantía está aquí, que es por donde
    pasa todo el que quiera guardar.

    Devuelve la ruta escrita, o $null si no se ha podido (sin
    permisos, disco lleno, ruta inválida...). No lanza: quien
    llame decide qué contarle al usuario.

    -Detailed escribe también el detalle de cada entrada (ver
    Format-AppLogText).
#>
function Export-AppLog {
    param([string]$Path, [switch]$Detailed)

    if ($AppLogEntries.Count -eq 0) { return $null }

    try {
        if (-not $Path) {
            $folder = Get-AppLogFolder
            $Path = Join-Path $folder (Get-AppLogFileName)
        }

        $folder = Split-Path -Parent $Path
        if ($folder -and -not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
        }

        # UTF-8 con BOM, que es lo que espera el Bloc de notas de
        # Windows al abrirlo con doble clic.
        [System.IO.File]::WriteAllText($Path, (Format-AppLogText -Detailed:$Detailed), (New-Object System.Text.UTF8Encoding($true)))
        $Path
    }
    catch {
        $null
    }
}
