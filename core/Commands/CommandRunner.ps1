# ============================================================
# core/Commands/CommandRunner.ps1
# Ejecutar, uno a uno, los pasos de una sección de comandos (hoy
# Internet y Limpieza). Cuatro tipos de paso:
#
#   exe         un programa de Windows de la lista blanca, sin shell
#   service     arrancar un servicio de la lista si está parado
#   clean       vaciar una carpeta de la lista (FolderCleanup.ps1)
#   recyclebin  vaciar la papelera (FolderCleanup.ps1)
#
# Como todo core/: no sabe que existe una ventana. Recibe un paso
# (lo crea New-CommandStep en ui/Data/Categories/) y devuelve un
# resultado. Quien decide el orden, las pausas y qué se pinta es la
# interfaz (ui/Components/Layout/StepRunPanel.ps1).
#
# CÓMO NO ABRIR UN AGUJERO -la aplicación corre ELEVADA-
#
#   1. NUNCA un intérprete. Ni cmd.exe, ni powershell.exe, ni texto
#      convertido en código: se arranca el ejecutable DIRECTAMENTE, con
#      UseShellExecute = $false. Sin shell no hay ni tuberías, ni
#      redirecciones, ni "&&": un argumento es un argumento.
#
#   2. LISTA BLANCA DE EJECUTABLES. Solo los de $CommandAllowedExecutables,
#      y siempre por su RUTA COMPLETA en la carpeta de sistema
#      (C:\Windows\System32\netsh.exe), nunca por el PATH: un
#      netsh.exe plantado en la carpeta de trabajo se ejecutaría
#      con permisos de administrador.
#
#   3. ARGUMENTOS LITERALES. Vienen escritos en el repositorio
#      (ui/Data/Categories/), no del usuario ni del sistema, y se
#      rechaza cualquiera con comillas o saltos de línea.
#
#   4. SERVICIOS, solo los de $CommandAllowedServices, y solo para
#      ARRANCARLOS si están parados. Nunca pararlos ni cambiar su
#      tipo de inicio.
#
#   5. CARPETAS, solo las de $CleanupAllowedFolders y siempre dentro
#      de la carpeta del usuario. Las reglas del borrado están en
#      core/Commands/FolderCleanup.ps1.
#
#   6. NADA LANZA. Un paso que no se puede ejecutar es un resultado
#      ('blocked', 'error'...), no una excepción.
#
#   7. DESARMABLE. Las pruebas lo desarman (tests/Harness/AppHost.ps1)
#      para no resetear la red ni borrar nada de verdad; desarmado, todo paso
#      termina en 'disarmed' sin arrancar nada.
#
# Añadir un ejecutable, un servicio o una carpeta a las listas es una decisión de
# seguridad, igual que una rama de la lista blanca del registro. Ver
# SECURITY.md §12.
#
# Todos los textos de este archivo están en inglés o son
# comentarios: core/ no traduce (regla 15).
# ============================================================

# ---- ¿está armada la ejecución? -------------------------------
$CommandRunArmed = $true

function Get-CommandRunArmed { [bool]$script:CommandRunArmed }
function Set-CommandRunArmed { param([bool]$On) $script:CommandRunArmed = $On }

# ---- listas blancas ---------------------------------------------
#
# Solo el NOMBRE del archivo: la carpeta la pone siempre
# Resolve-CommandExecutable (la de sistema).
$CommandAllowedExecutables = @(
    # Internet
    'netsh.exe', 'ipconfig.exe', 'nbtstat.exe', 'arp.exe'
    # Limpieza
    'Dism.exe', 'cleanmgr.exe', 'fsutil.exe', 'defrag.exe'
    # Energía
    'powercfg.exe'
)

# Servicios que un paso puede ARRANCAR si están parados.
$CommandAllowedServices = @('Dhcp', 'Dnscache')

# Lo que un paso puede tardar antes de darlo por colgado.
$CommandDefaultTimeoutSeconds = 60

# Lo mismo para un -Clean entero (FolderCleanup.ps1): %TEMP% con decenas de
# miles de archivos tarda más que cualquier netsh. Vive aquí, que es quien
# lo usa, y no junto al borrado: el analizador mira archivo por archivo.
$CleanupTimeoutSeconds = 600

# Recorte de la salida que se apunta en el log.
$CommandLogOutputMax = 240

<#
    La ruta COMPLETA de un ejecutable permitido, o $null.

    Solo el nombre (sin carpetas) y solo si está en la lista. La
    carpeta es la de sistema; si el archivo no existe ahí, $null.
#>
function Resolve-CommandExecutable {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    if ($Name -match '[\\/:]') { return $null }

    $allowed = $false
    foreach ($exe in $CommandAllowedExecutables) {
        if ([string]::Equals($Name, $exe, [System.StringComparison]::OrdinalIgnoreCase)) { $allowed = $true; break }
    }
    if (-not $allowed) { return $null }

    try {
        $path = Join-Path ([Environment]::GetFolderPath('System')) $Name
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    catch { $null = $_ }
    $null
}

# ¿Un argumento es aceptable? Texto, sin comillas ni saltos ni NUL.
function Test-CommandArgument {
    param($Value)
    if ($Value -isnot [string]) { return $false }
    -not ($Value -match '["\r\n\x00]')
}

<#
    ¿Se puede ejecutar este paso? Comprueba la forma completa:
    tipo, ejecutable o servicio de la lista y argumentos limpios.
    No mira si está armado: eso es otra cosa.
#>
function Test-CommandStepAllowed {
    param($Step)

    if (-not $Step) { return $false }
    switch ([string]$Step.Kind) {
        'exe' {
            if (-not (Resolve-CommandExecutable $Step.Exe)) { return $false }
            foreach ($a in @($Step.Arguments)) {
                if (-not (Test-CommandArgument $a)) { return $false }
            }
            return $true
        }
        'service' {
            foreach ($svc in $CommandAllowedServices) {
                if ([string]::Equals([string]$Step.Service, $svc, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
            }
            return $false
        }
        'clean'      { return (Test-CleanupTargetAllowed ([string]$Step.Clean)) }
        'recyclebin' { return $true }
        default { return $false }
    }
}

# Los argumentos como una sola cadena, con comillas solo donde haga
# falta (un espacio). Las comillas internas ya están prohibidas.
function ConvertTo-CommandArgumentString {
    param([string[]]$Arguments)

    $parts = foreach ($a in @($Arguments)) {
        if ($a -eq '')          { '""' }
        elseif ($a -match '\s') { '"' + $a + '"' }
        else                    { $a }
    }
    ($parts -join ' ')
}

# Cómo se enseña el paso: 'netsh int ipv4 reset', 'service Dhcp',
# 'clean %TEMP%' o 'empty recycle bin'.
function Format-CommandLine {
    param($Step)

    if (-not $Step) { return '' }
    switch ([string]$Step.Kind) {
        'service'    { return 'service {0}' -f $Step.Service }
        'clean'      { return 'clean {0}' -f $Step.Clean }
        'recyclebin' { return 'empty recycle bin' }
    }

    $exe = ([string]$Step.Exe) -replace '\.exe$', ''
    $argText = ConvertTo-CommandArgumentString @($Step.Arguments)
    if ($argText) { "$exe $argText" } else { $exe }
}

<#
    LA SALIDA SE LEE COMO BYTES y se decide después cómo decodificarla.

    netsh e ipconfig escriben en la página de códigos de SU consola, y
    esa depende de quién los arranque: desde una terminal en UTF-8
    (65001) sale UTF-8; desde el .exe -sin consola- sale la OEM (850 en
    español). Fijar una de las dos deja las tildes rotas en la otra.

    Por eso se lee en Latin-1, que es un byte por carácter y no pierde
    nada, y luego ConvertFrom-CommandOutput prueba UTF-8 estricto: si
    los bytes no son UTF-8 válido, son OEM.
#>
function Get-CommandOutputEncoding {
    [System.Text.Encoding]::GetEncoding(28591)
}

function ConvertFrom-CommandOutput {
    param([string]$Raw)

    if ([string]::IsNullOrEmpty($Raw)) { return '' }
    $bytes = [System.Text.Encoding]::GetEncoding(28591).GetBytes($Raw)
    try {
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        return $strict.GetString($bytes)
    }
    catch { $null = $_ }
    try {
        $cp = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        return [System.Text.Encoding]::GetEncoding($cp).GetString($bytes)
    }
    catch { return $Raw }
}

# La salida en una línea, recortada, para el log.
function Format-CommandOutput {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $one = ($Text -replace '\s+', ' ').Trim()
    if ($one.Length -gt $CommandLogOutputMax) { $one = $one.Substring(0, $CommandLogOutputMax - 3) + '...' }
    $one
}

function New-CommandResult {
    param([string]$State, [int]$ExitCode = -1, [string]$Output = '', [double]$Ms = 0, [string]$Line = '', [string[]]$Items = @())
    [PSCustomObject]@{
        State       = $State      # succeeded | failed | timed out | cancelled | blocked | disarmed | error
        ExitCode    = $ExitCode
        Output      = $Output
        Ms          = $Ms
        CommandLine = $Line
        # El detalle de lo que hizo, línea a línea: los archivos que
        # borró una limpieza o la salida entera de un programa. Va al
        # log como Items y a la fila del paso (ver StepRunPanel).
        Items       = @($Items | Where-Object { $null -ne $_ })
    }
}

<#
    La salida de un programa, línea a línea, para el detalle. Solo si
    hay más de lo que cabe en el resumen del log (Format-CommandOutput
    la deja en una línea de $CommandLogOutputMax): una salida de una
    línea corta ya se ve entera.
#>
function Get-CommandOutputItems {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $lines = @($Text -split '\r?\n' | ForEach-Object { $_.TrimEnd() } | Where-Object { $_.Trim() })
    $oneLine = ($Text -replace '\s+', ' ').Trim()
    if ($lines.Count -lt 2 -and $oneLine.Length -le $CommandLogOutputMax) { return @() }
    $lines
}

# En qué apartado del log cae un paso: el Id de su sección (lo pone
# Register-Category), o 'commands' si es un paso suelto.
function Get-CommandLogSource {
    param($Step)
    if ($Step -and $Step.PSObject.Properties['Source'] -and $Step.Source) { return [string]$Step.Source }
    'commands'
}

# Lo que se apunta en el log al terminar un paso.
function Write-CommandResultLog {
    param($Result, [string]$Source = 'commands')

    $level = switch ($Result.State) {
        'succeeded' { 'info' }
        'disarmed'  { 'warn' }
        'cancelled' { 'warn' }
        default     { 'error' }
    }
    $detail = 'exit={0} | {1:N0} ms' -f $Result.ExitCode, $Result.Ms
    $out = Format-CommandOutput $Result.Output
    if ($out) { $detail += " | $out" }

    $items = @()
    if ($Result.PSObject.Properties['Items'] -and $Result.Items) { $items = @($Result.Items) }
    Write-AppLog -Source $Source -Level $level -Status $Result.State `
        -Message $Result.CommandLine -Detail $detail -Items $items
}

<#
    Arranca un paso y devuelve en el acto un "manejador":

        $h = Start-CommandStep $step
        while (-not (Test-CommandStepFinished $h)) { ... }
        $r = Complete-CommandStep $h

    No espera a que termine: así la interfaz sigue viva mientras
    netsh trabaja. Lo que no necesita proceso -un servicio, la
    papelera, un paso bloqueado, la ejecución desarmada- sale ya
    resuelto, con Result puesto. Vaciar una carpeta tampoco arranca
    proceso: deja un trabajo en Job y avanza un trozo en cada
    Test-CommandStepFinished.
#>
function Start-CommandStep {
    # -WhatIf: no se ejecuta nada. Un -Clean se recorre en simulacro y
    # dice lo que borraría; la papelera dice cuánto tiene; el resto sale
    # 'disarmed' con "WhatIf".
    [CmdletBinding(SupportsShouldProcess)]
    param($Step)

    $line = Format-CommandLine $Step
    $source = Get-CommandLogSource $Step
    $handle = [PSCustomObject]@{
        Step = $Step; Line = $line; Source = $source; Process = $null
        OutTask = $null; ErrTask = $null; Job = $null
        Watch = [System.Diagnostics.Stopwatch]::StartNew()
        Timeout = $CommandDefaultTimeoutSeconds
        Result = $null
    }
    if ($Step -and [string]$Step.Kind -eq 'clean') { $handle.Timeout = $CleanupTimeoutSeconds }
    if ($Step -and $Step.TimeoutSeconds -gt 0) { $handle.Timeout = [int]$Step.TimeoutSeconds }

    if (-not (Test-CommandStepAllowed $Step)) {
        $handle.Result = New-CommandResult 'blocked' -Line $line
        return $handle
    }

    Write-AppLog -Source $source -Status 'running' -Message $line

    if (-not (Get-CommandRunArmed)) {
        $handle.Result = New-CommandResult 'disarmed' -Line $line
        return $handle
    }

    $dry = -not $PSCmdlet.ShouldProcess($line, 'Run')

    if ($dry -and [string]$Step.Kind -notin @('clean', 'recyclebin')) {
        $handle.Result = New-CommandResult 'disarmed' -Output 'WhatIf: not run' -Line $line
        return $handle
    }

    if (Test-CommandStepAlreadyDone $Step) {
        $handle.Result = New-CommandResult 'succeeded' 0 'already in place: skipped' $handle.Watch.Elapsed.TotalMilliseconds $line
        return $handle
    }

    if ([string]$Step.Kind -eq 'service') {
        $handle.Result = Invoke-ServiceStep $Step $line $handle.Watch
        return $handle
    }

    if ([string]$Step.Kind -eq 'recyclebin') {
        $bin = Clear-CleanupRecycleBin -WhatIf:$dry
        $state = if ($bin.Ok) { 'succeeded' } else { 'failed' }
        $code = if ($bin.Ok) { 0 } else { 1 }
        $handle.Result = New-CommandResult $state $code $bin.Note $handle.Watch.Elapsed.TotalMilliseconds $line @($bin.Items)
        return $handle
    }

    if ([string]$Step.Kind -eq 'clean') {
        $handle.Job = New-CleanupJob ([string]$Step.Clean) -DryRun $dry
        if ($handle.Job.Blocked) {
            $handle.Result = New-CommandResult 'blocked' -Output $handle.Job.Note -Ms $handle.Watch.Elapsed.TotalMilliseconds -Line $line
        }
        return $handle
    }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = Resolve-CommandExecutable $Step.Exe
        $psi.Arguments = ConvertTo-CommandArgumentString @($Step.Arguments)
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $encoding = Get-CommandOutputEncoding
        $psi.StandardOutputEncoding = $encoding
        $psi.StandardErrorEncoding = $encoding

        $handle.Process = [System.Diagnostics.Process]::Start($psi)
        # Lectura asíncrona de las dos salidas: si se leyera una
        # después de la otra y el proceso llenara el búfer de la
        # segunda, los dos se quedarían esperándose para siempre.
        $handle.OutTask = $handle.Process.StandardOutput.ReadToEndAsync()
        $handle.ErrTask = $handle.Process.StandardError.ReadToEndAsync()
    }
    catch {
        $msg = ($_.Exception.Message -replace '\s+', ' ').Trim()
        $handle.Result = New-CommandResult 'error' -Output $msg -Ms $handle.Watch.Elapsed.TotalMilliseconds -Line $line
    }
    $handle
}

<#
    ¿El paso ya está hecho? Si declara -SkipIf (un valor del registro) y
    ese valor existe, no se ejecuta. Solo LEE (Read-RegistryValueRaw,
    que no apunta nada en el log): mirar no cambia el equipo.

    Es lo que hace repetible un comando que no lo es. "powercfg
    /duplicatescheme" sobre un plan que ya existe devuelve 1, el mismo
    código que cualquier otro error: sin esto, la segunda ejecución
    saldría como "falló" sin haber fallado nada.
#>
function Test-CommandStepAlreadyDone {
    param($Step)

    if (-not $Step -or -not $Step.PSObject.Properties['SkipIf'] -or -not $Step.SkipIf) { return $false }
    try {
        $r = Read-RegistryValueRaw -Path ([string]$Step.SkipIf.Path) -Name ([string]$Step.SkipIf.Name)
        return ($r.State -eq 'read')
    }
    catch { return $false }
}

# Un servicio: si ya está en marcha, nada; si no, se arranca.
function Invoke-ServiceStep {
    param($Step, [string]$Line, $Watch)

    try {
        $svc = Get-Service -Name $Step.Service -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            return (New-CommandResult 'succeeded' 0 'already running' $Watch.Elapsed.TotalMilliseconds $Line)
        }
        Start-Service -Name $Step.Service -ErrorAction Stop
        $svc.Refresh()
        if ($svc.Status -eq 'Running') {
            return (New-CommandResult 'succeeded' 0 'started' $Watch.Elapsed.TotalMilliseconds $Line)
        }
        New-CommandResult 'failed' 1 ('status: {0}' -f $svc.Status) $Watch.Elapsed.TotalMilliseconds $Line
    }
    catch {
        $msg = ($_.Exception.Message -replace '\s+', ' ').Trim()
        New-CommandResult 'failed' 1 $msg $Watch.Elapsed.TotalMilliseconds $Line
    }
}

<#
    ¿Ha terminado (o se ha pasado de tiempo)?

    Con un vaciado de carpeta en marcha, preguntar es también AVANZAR:
    cada llamada borra un trozo (Step-CleanupJob). Quien pregunta es el
    latido de StepRunPanel, así que el borrado va al ritmo del
    temporizador y la ventana respira entre trozo y trozo.
#>
function Test-CommandStepFinished {
    param($Handle)

    if (-not $Handle) { return $true }
    if ($Handle.Result) { return $true }
    if ($Handle.Watch.Elapsed.TotalSeconds -ge $Handle.Timeout) { return $true }
    if ($Handle.Job) { return (Step-CleanupJob $Handle.Job) }
    if (-not $Handle.Process) { return $true }
    try {
        $Handle.Process.HasExited -and $Handle.OutTask.IsCompleted -and $Handle.ErrTask.IsCompleted
    }
    catch { $true }
}

<#
    Cierra un paso terminado: recoge código de salida y salida,
    lo apunta en el log y devuelve el resultado. Si se pasó de
    tiempo, mata el proceso.
#>
function Complete-CommandStep {
    param($Handle)

    if (-not $Handle) { return (New-CommandResult 'error') }

    if (-not $Handle.Result -and $Handle.Job) {
        $ms = $Handle.Watch.Elapsed.TotalMilliseconds
        $state = if ($Handle.Job.Done) { 'succeeded' } else { 'timed out' }
        $code = if ($Handle.Job.Done) { 0 } else { -1 }
        $Handle.Result = New-CommandResult $state $code (Format-CleanupSummary $Handle.Job) $ms $Handle.Line (Get-CleanupItems $Handle.Job)
    }

    if (-not $Handle.Result) {
        $ms = $Handle.Watch.Elapsed.TotalMilliseconds
        try {
            $p = $Handle.Process
            if (-not $p.HasExited) {
                try { $p.Kill() } catch { $null = $_ }
                $Handle.Result = New-CommandResult 'timed out' -1 '' $ms $Handle.Line
            }
            else {
                $out = ''
                if ($Handle.OutTask.IsCompleted) { $out = ConvertFrom-CommandOutput ([string]$Handle.OutTask.Result) }
                if ($Handle.ErrTask.IsCompleted) {
                    $err = ConvertFrom-CommandOutput ([string]$Handle.ErrTask.Result)
                    if ($err.Trim()) { $out = ($out + ' ' + $err).Trim() }
                }
                $code = $p.ExitCode
                $state = if ($code -eq 0) { 'succeeded' } else { 'failed' }
                $Handle.Result = New-CommandResult $state $code $out.Trim() $ms $Handle.Line (Get-CommandOutputItems $out)
            }
        }
        catch {
            $msg = ($_.Exception.Message -replace '\s+', ' ').Trim()
            $Handle.Result = New-CommandResult 'error' -1 $msg $ms $Handle.Line
        }
        finally {
            if ($Handle.Process) { try { $Handle.Process.Dispose() } catch { $null = $_ } }
        }
    }

    Write-CommandResultLog $Handle.Result $Handle.Source
    $Handle.Result
}

# Corta un paso en marcha. Devuelve el resultado 'cancelled'.
function Stop-CommandStep {
    param($Handle)

    if (-not $Handle) { return $null }
    if (-not $Handle.Result -and $Handle.Job) {
        # Lo borrado, borrado está: el resumen dice hasta dónde llegó.
        $Handle.Result = New-CommandResult 'cancelled' -1 (Format-CleanupSummary $Handle.Job) $Handle.Watch.Elapsed.TotalMilliseconds $Handle.Line (Get-CleanupItems $Handle.Job)
    }
    elseif (-not $Handle.Result -and $Handle.Process) {
        try { if (-not $Handle.Process.HasExited) { $Handle.Process.Kill() } } catch { $null = $_ }
        try { $Handle.Process.Dispose() } catch { $null = $_ }
        $Handle.Result = New-CommandResult 'cancelled' -1 '' $Handle.Watch.Elapsed.TotalMilliseconds $Handle.Line
    }
    elseif (-not $Handle.Result) {
        $Handle.Result = New-CommandResult 'cancelled' -Line $Handle.Line
    }
    Write-CommandResultLog $Handle.Result $Handle.Source
    $Handle.Result
}

# Cómo va un paso en curso, para el marco de ejecución. Hoy solo lo
# sabe un vaciado de carpeta ('1234 files deleted, 456.7 MB freed').
function Get-CommandStepProgress {
    param($Handle)
    if (-not $Handle -or $Handle.Result -or -not $Handle.Job) { return '' }
    if ($Handle.Job.Deleted -eq 0 -and $Handle.Job.Skipped -eq 0) { return '' }
    Format-CleanupSummary $Handle.Job
}

<#
    Lo mismo, de una vez y esperando: para las pruebas y para quien
    no tenga una interfaz que mantener viva.
#>
function Invoke-CommandStep {
    param($Step)

    $h = Start-CommandStep $Step
    while (-not (Test-CommandStepFinished $h)) { Start-Sleep -Milliseconds 40 }
    Complete-CommandStep $h
}
