# ============================================================
# core/Commands/FolderCleanup.ps1
# Vaciar carpetas de temporales y la papelera: los pasos -Clean y
# -EmptyRecycleBin de las secciones de comandos (hoy Limpieza).
#
# El .cmd original lo hacía con "del /s" y "rd /s", que son órdenes
# INTERNAS de cmd.exe: no hay un del.exe que arrancar, y abrir un
# intérprete está prohibido (SECURITY.md §12). Así que se borra aquí,
# con .NET, y con más freno que el del:
#
#   1. LISTA BLANCA DE CARPETAS ($CleanupAllowedFolders), escritas
#      igual que en el .cmd. El paso tiene que nombrar una TAL CUAL:
#      ni una subcarpeta ni otro patrón. Añadir una es una decisión de
#      seguridad, como un ejecutable.
#   2. LAS VARIABLES LAS RESUELVE LA APP. Solo %TEMP%, %LOCALAPPDATA%,
#      %APPDATA% y %WINDIR%, y las tres últimas salen de GetFolderPath,
#      no del entorno.
#   3. DENTRO DE TU CARPETA DE USUARIO, con dos excepciones contadas
#      (Get-CleanupPathProblem): C:\Windows\Temp tal cual, y un %TEMP%
#      movido a otro sitio SI la carpeta se llama Temp o Tmp y no cuelga
#      de Windows, Archivos de programa, ProgramData ni de otro perfil
#      (un disco RAM, R:\Temp). Un TMP=C:\Windows se bloquea: corriendo
#      elevado, vaciarlo sería borrar el sistema.
#   4. LOS ENLACES NO SE SIGUEN. Una unión o un enlace simbólico de
#      dentro se quita (el enlace, nunca su destino) o se deja; jamás
#      se entra. Si la carpeta misma es un enlace, se bloquea.
#   5. SE VACÍA, NO SE BORRA: la carpeta raíz se queda. Lo que está en
#      uso se salta y se cuenta, como hacía "del /q" en silencio.
#   6. SIMULABLE. Con -WhatIf (o $Job.DryRun) se recorre igual y se
#      apunta lo que se BORRARÍA, sin borrar nada.
#
#   7. POR TROZOS. %TEMP% puede tener decenas de miles de archivos: se
#      borra $CleanupSliceMs en cada latido (Step-CleanupJob) y la
#      ventana no se congela.
#   8. NADA LANZA. El desarme lo comprueba CommandRunner antes de
#      llamar aquí.
#
# Dos modos, los del ":DelMode" del .cmd, y los decide la propia
# entrada de la lista:
#
#   '%TEMP%'                         TODO: archivos -también ocultos y
#                                    de sistema- y subcarpetas (modo 2)
#   '%LOCALAPPDATA%\...\Explorer\*.db'  solo esos archivos, en la carpeta
#                                    y sus subcarpetas, sin ocultos ni de
#                                    sistema y sin quitar carpetas (modo 1)
#
# Los textos que salen de aquí van al log, en inglés: core/ no traduce.
# ============================================================

# ---- lista blanca ---------------------------------------------------
$CleanupAllowedFolders = @(
    '%TEMP%'
    '%LOCALAPPDATA%\CrashDumps'
    '%LOCALAPPDATA%\Microsoft\Windows\WER\ReportQueue'
    '%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.db'
    '%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache'
    '%LOCALAPPDATA%\Microsoft\Windows\InetCache'
    '%LOCALAPPDATA%\Microsoft\Windows\History'
    '%LOCALAPPDATA%\Microsoft\Windows\WebCache\*.log'
    '%APPDATA%\Microsoft\Windows\Cookies'
    '%APPDATA%\Microsoft\Windows\Recent'
    '%WINDIR%\Temp'
)

# Las únicas variables que se entienden.
$CleanupRoots = @('TEMP', 'LOCALAPPDATA', 'APPDATA', 'WINDIR')

# Lo que se borra en cada latido antes de devolver el hilo a la
# ventana. El temporizador de StepRunPanel late cada 120 ms.
$CleanupSliceMs = 80

# Cuántas rutas se apuntan, como mucho, en cada lista del detalle
# (borrados, saltados, carpetas). Pasado el tope se sigue CONTANDO,
# pero ya no se apunta la ruta: un %TEMP% abandonado puede tener
# cientos de miles de archivos y el detalle vive en memoria.
$CleanupListMax = 5000

# La carpeta de cada variable. %TEMP% no tiene carpeta conocida (es la
# variable TMP/TEMP del usuario): la frena la regla 3, no esto.
function Get-CleanupRootPath {
    param([string]$Name)
    try {
        switch ($Name.ToUpperInvariant()) {
            'TEMP'         { return [System.IO.Path]::GetTempPath() }
            'LOCALAPPDATA' { return [Environment]::GetFolderPath('LocalApplicationData') }
            'APPDATA'      { return [Environment]::GetFolderPath('ApplicationData') }
            'WINDIR'       { return [Environment]::GetFolderPath('Windows') }
        }
    }
    catch { $null = $_ }
    $null
}

<#
    Separa '%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.db' en sus
    partes, o $null si no tiene una forma permitida:

        Root      'LOCALAPPDATA'
        Relative  'Microsoft\Windows\Explorer'
        Pattern   '*.db'   ('*' si es la carpeta entera)
        Full      $false   ($true si es la carpeta entera)

    Solo mira la forma: ni la lista blanca ni el disco.
#>
function Split-CleanupTarget {
    param([string]$Target)

    if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
    if ($Target -notmatch '^%([A-Za-z]+)%(?:\\(.+))?$') { return $null }
    $root = $Matches[1].ToUpperInvariant()
    $rest = [string]$Matches[2]
    if ($CleanupRoots -notcontains $root) { return $null }

    $parts = New-Object System.Collections.Generic.List[string]
    if ($rest) { foreach ($p in ($rest -split '\\')) { $parts.Add($p) } }

    $pattern = '*'
    $full = $true
    if ($parts.Count -gt 0 -and $parts[$parts.Count - 1].Contains('*')) {
        $pattern = $parts[$parts.Count - 1]
        if ($pattern -notmatch '^\*\.[A-Za-z0-9]{1,8}$') { return $null }
        $parts.RemoveAt($parts.Count - 1)
        $full = $false
    }
    foreach ($p in $parts) {
        if ($p -notmatch '^[^\\/:*?"<>|%\x00-\x1F]+$') { return $null }
        if ($p -match '^\.+$') { return $null }
    }

    [PSCustomObject]@{
        Root     = $root
        Relative = ($parts.ToArray() -join '\')
        Pattern  = $pattern
        Full     = $full
    }
}

# ¿Es una entrada de la lista blanca, y con forma válida?
function Test-CleanupTargetAllowed {
    param([string]$Target)

    if (-not (Split-CleanupTarget $Target)) { return $false }
    foreach ($allowed in $CleanupAllowedFolders) {
        if ([string]::Equals($Target, $allowed, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}

<#
    La carpeta de verdad de una entrada. Devuelve siempre un objeto;
    si no se puede usar, Problem dice por qué y Path es $null.
#>
function Resolve-CleanupTarget {
    param([string]$Target)

    $r = [PSCustomObject]@{ Path = $null; Pattern = '*'; Full = $true; Problem = '' }
    if (-not (Test-CleanupTargetAllowed $Target)) {
        $r.Problem = 'not in the cleanup allowlist'
        return $r
    }
    $parts = Split-CleanupTarget $Target
    $r.Pattern = $parts.Pattern
    $r.Full = $parts.Full

    try {
        $base = Get-CleanupRootPath $parts.Root
        $userDir = [Environment]::GetFolderPath('UserProfile')
        if (-not $base -or -not $userDir) {
            $r.Problem = 'cannot resolve the folder'
            return $r
        }
        $path = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($base, $parts.Relative)).TrimEnd('\')
        $why = Get-CleanupPathProblem -Path $path -Root $parts.Root -UserDir $userDir
        if ($why) {
            $r.Problem = $why
            return $r
        }
        $r.Path = $path
    }
    catch {
        $r.Problem = ($_.Exception.Message -replace '\s+', ' ').Trim()
    }
    $r
}

<#
    Por qué NO se puede vaciar una carpeta ya resuelta ('' si se puede).
    Es la regla 3 de la cabecera:

      - Dentro del perfil del usuario: sí.
      - C:\Windows\Temp exacto: sí (la carpeta, no lo que cuelgue de Windows).
      - Un %TEMP% fuera del perfil: solo si la carpeta se llama Temp o Tmp,
        no es la raíz de un disco y no está dentro de Windows, Archivos de
        programa, ProgramData ni de la carpeta de perfiles (otro usuario).
      - Todo lo demás: no.
#>
function Get-CleanupPathProblem {
    param([string]$Path, [string]$Root, [string]$UserDir)

    $ic = [System.StringComparison]::OrdinalIgnoreCase
    $inside = $UserDir.TrimEnd('\') + '\'
    if ($Path.StartsWith($inside, $ic)) { return '' }

    $winTemp = [System.IO.Path]::Combine([Environment]::GetFolderPath('Windows'), 'Temp').TrimEnd('\')
    if ([string]::Equals($Path, $winTemp, $ic)) { return '' }

    if ($Root -eq 'TEMP') {
        $leaf = [System.IO.Path]::GetFileName($Path)
        if ($leaf -match '^(temp|tmp)$' -and [System.IO.Path]::GetDirectoryName($Path)) {
            $forbidden = @(
                [Environment]::GetFolderPath('Windows')
                [Environment]::GetFolderPath('ProgramFiles')
                [Environment]::GetFolderPath('ProgramFilesX86')
                [Environment]::GetFolderPath('CommonApplicationData')
                [System.IO.Path]::GetDirectoryName($UserDir.TrimEnd('\'))
            ) | Where-Object { $_ }
            foreach ($f in $forbidden) {
                $fp = $f.TrimEnd('\')
                if ([string]::Equals($Path, $fp, $ic) -or $Path.StartsWith($fp + '\', $ic)) {
                    return 'inside a system folder: ' + $Path
                }
            }
            return ''
        }
    }
    'outside your user folder: ' + $Path
}

# ---- el borrado, por trozos ----------------------------------------

<#
    Prepara el vaciado de una entrada de la lista blanca. Es lo que
    usa CommandRunner. Si la entrada no vale, el trabajo sale ya
    terminado y con Blocked.
#>
function New-CleanupJob {
    param([string]$Target, [bool]$DryRun = $false)

    $t = Resolve-CleanupTarget $Target
    if ($t.Problem) {
        $job = New-CleanupJobAt -Path ''
        $job.Blocked = $true
        $job.Note = $t.Problem
        return $job
    }
    New-CleanupJobAt -Path $t.Path -Pattern $t.Pattern -Full $t.Full -DryRun $DryRun
}

<#
    El mismo trabajo sobre una carpeta ya resuelta, sin lista blanca.
    Solo para New-CleanupJob y para las pruebas, que lo apuntan a una
    carpeta de mentira.

        $job = New-CleanupJobAt -Path $carpeta
        while (-not (Step-CleanupJob $job)) { ... }
        Format-CleanupSummary $job
#>
function New-CleanupJobAt {
    param([string]$Path, [string]$Pattern = '*', [bool]$Full = $true, [bool]$DryRun = $false)

    $job = [PSCustomObject]@{
        Path    = $Path
        Pattern = $Pattern
        Full    = $Full
        Dirs    = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
        Seen    = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
        Files   = $null      # el enumerador de la carpeta en curso
        Phase   = 'scan'     # scan -> folders (solo modo completo)
        Next    = -1         # la siguiente carpeta a quitar, de la última a la primera
        Deleted = 0
        Bytes   = [long]0
        Folders = 0
        Skipped = 0
        # El detalle: qué se borró y qué no, ruta a ruta (ver
        # Get-CleanupItems). Hasta $CleanupListMax por lista.
        DeletedList = [System.Collections.Generic.List[string]]::new()
        SkippedList = [System.Collections.Generic.List[string]]::new()
        FolderList  = [System.Collections.Generic.List[string]]::new()
        DryRun  = $DryRun    # -WhatIf: se recorre y se cuenta, no se borra
        Done    = $false
        Blocked = $false
        Note    = ''
    }
    if (-not $Path) { $job.Done = $true; return $job }

    try {
        $root = New-Object System.IO.DirectoryInfo $Path
        if (-not $root.Exists) {
            $job.Done = $true
            $job.Note = 'folder not found: nothing to clean'
        }
        elseif ($root.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            $job.Done = $true
            $job.Blocked = $true
            $job.Note = 'the folder is a link: not followed'
        }
        else {
            # La raíz se recorre pero no entra en Seen: se vacía, no se borra.
            $job.Dirs.Push($root)
        }
    }
    catch {
        $job.Done = $true
        $job.Blocked = $true
        $job.Note = ($_.Exception.Message -replace '\s+', ' ').Trim()
    }
    $job
}

<#
    Un trozo de trabajo: borra durante $SliceMs y devuelve si ha
    terminado. Recorre en profundidad con una pila (sin recursión: se
    puede parar y seguir en cualquier punto) y, en modo completo, al
    final quita las subcarpetas de la última a la primera, que es de
    dentro hacia fuera.
#>
function Step-CleanupJob {
    param($Job, [int]$SliceMs = $CleanupSliceMs)

    if (-not $Job -or $Job.Done) { return $true }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while (-not $Job.Done -and $watch.ElapsedMilliseconds -lt $SliceMs) {
            if ($Job.Files) {
                $file = $null
                try { if ($Job.Files.MoveNext()) { $file = $Job.Files.Current } }
                catch { $null = $_ }
                if ($file) { Remove-CleanupFile $Job $file } else { $Job.Files = $null }
            }
            elseif ($Job.Dirs.Count -gt 0) {
                Open-CleanupFolder $Job $Job.Dirs.Pop()
            }
            elseif ($Job.Full -and $Job.Next -ge 0) {
                Remove-CleanupFolder $Job $Job.Seen[$Job.Next]
                $Job.Next--
            }
            elseif ($Job.Full -and $Job.Phase -eq 'scan') {
                $Job.Phase = 'folders'
                $Job.Next = $Job.Seen.Count - 1
            }
            else {
                $Job.Done = $true
            }
        }
    }
    catch {
        $Job.Done = $true
        $Job.Note = ($_.Exception.Message -replace '\s+', ' ').Trim()
    }
    $Job.Done
}

# Apunta las subcarpetas (sin entrar en enlaces) y deja listo el
# enumerador de sus archivos.
function Open-CleanupFolder {
    param($Job, [System.IO.DirectoryInfo]$Dir)

    # Se miró que no era un enlace al apuntarla, pero entre aquel latido
    # y este alguien pudo cambiarla por una unión. Se vuelve a mirar justo
    # antes de entrar: estrecha la carrera, aunque no la cierra del todo
    # (ver SECURITY.md §11).
    try {
        $Dir.Refresh()
        if ($Dir.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) { return }
    }
    catch { return }

    try {
        foreach ($sub in $Dir.EnumerateDirectories()) {
            if ($sub.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
                if ($Job.Full) { Remove-CleanupFolder $Job $sub }
                continue
            }
            $Job.Dirs.Push($sub)
            $Job.Seen.Add($sub)
        }
    }
    catch { $null = $_ }

    try { $Job.Files = $Dir.EnumerateFiles($Job.Pattern).GetEnumerator() }
    catch { $Job.Files = $null }
}

function Remove-CleanupFile {
    [CmdletBinding(SupportsShouldProcess)]
    param($Job, [System.IO.FileInfo]$File)

    try {
        $attrs = $File.Attributes
        # Modo 1 = "del" sin /A: ni ocultos ni de sistema.
        if (-not $Job.Full -and ($attrs.HasFlag([System.IO.FileAttributes]::Hidden) -or $attrs.HasFlag([System.IO.FileAttributes]::System))) {
            return
        }
        $size = [long]$File.Length
        if (-not $Job.DryRun -and $PSCmdlet.ShouldProcess($File.FullName, 'Delete')) {
            if ($File.IsReadOnly) { $File.IsReadOnly = $false }
            $File.Delete()
        }
        $Job.Deleted++
        $Job.Bytes += $size
        if ($Job.DeletedList.Count -lt $CleanupListMax) {
            $line = '{0,-10} {1}' -f (Format-CleanupSize $size), $File.FullName
            $Job.DeletedList.Add($line)
        }
    }
    catch {
        $Job.Skipped++
        if ($Job.SkippedList.Count -lt $CleanupListMax) {
            $line = '{0,-10} {1}' -f (Get-CleanupSkipReason $_.Exception), $File.FullName
            $Job.SkippedList.Add($line)
        }
    }
}

# Por qué no se pudo borrar, en una palabra. Abierto por otro programa
# es un IOException; sin permiso, UnauthorizedAccessException.
# PowerShell envuelve la excepción del método .NET: se mira la de dentro.
function Get-CleanupSkipReason {
    param($Exception)
    $ex = $Exception
    if ($ex -is [System.Management.Automation.MethodInvocationException] -and $ex.InnerException) { $ex = $ex.InnerException }
    if ($ex -is [System.UnauthorizedAccessException]) { return 'no access' }
    if ($ex -is [System.IO.IOException]) { return 'in use' }
    'error'
}

# Sin recursión: si dentro quedó algo en uso, falla y la carpeta se
# queda. Sobre un enlace quita el enlace, nunca lo del otro lado.
function Remove-CleanupFolder {
    [CmdletBinding(SupportsShouldProcess)]
    param($Job, [System.IO.DirectoryInfo]$Dir)
    try {
        if (-not $Job.DryRun -and $PSCmdlet.ShouldProcess($Dir.FullName, 'Remove folder')) { $Dir.Delete($false) }
        $Job.Folders++
        if ($Job.FolderList.Count -lt $CleanupListMax) { $Job.FolderList.Add($Dir.FullName) }
    }
    catch { $null = $_ }
}

# ---- lo que se enseña ----------------------------------------------

function Format-CleanupSize {
    param([long]$Bytes)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Bytes -ge 1GB) { return [string]::Format($inv, '{0:0.0} GB', $Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return [string]::Format($inv, '{0:0.0} MB', $Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return [string]::Format($inv, '{0:0} KB', $Bytes / 1KB) }
    [string]::Format($inv, '{0} B', $Bytes)
}

# '1234 files deleted, 456.7 MB freed, 12 folders removed; 3 in use, skipped'
function Format-CleanupSummary {
    param($Job)

    if (-not $Job) { return '' }
    if ($Job.Note -and $Job.Deleted -eq 0 -and $Job.Skipped -eq 0) { return $Job.Note }

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $text = [string]::Format($inv, '{0} files deleted, {1} freed', $Job.Deleted, (Format-CleanupSize $Job.Bytes))
    if ($Job.Folders -gt 0) { $text += [string]::Format($inv, ', {0} folders removed', $Job.Folders) }
    if ($Job.Skipped -gt 0) { $text += [string]::Format($inv, '; {0} in use, skipped', $Job.Skipped) }
    if ($Job.Note) { $text += '; ' + $Job.Note }
    if ($Job.DryRun) { $text = 'WhatIf, nothing deleted: ' + $text }
    $text
}

<#
    El detalle de un vaciado, para el log (Write-AppLog -Items). Lo
    saltado va PRIMERO: es lo corto y es lo que explica por qué
    "todavía quedan archivos".

        Skipped, in use or no access (36):
          in use     C:\Users\...\Temp\e0fb7f80-....tmp
        Deleted (3256 files, 406.6 MB):
          12 KB      C:\Users\...\Temp\setup.log
          ... and 120 more, not listed
        Folders removed (962):
          C:\Users\...\Temp\abc

    Vacío si no se hizo nada.
#>
function Get-CleanupItems {
    param($Job)

    $items = New-Object System.Collections.Generic.List[string]
    if (-not $Job) { return $items.ToArray() }

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $groups = @(
        @{ Count = $Job.Skipped; List = $Job.SkippedList
           Title = [string]::Format($inv, 'Skipped, in use or no access ({0}):', $Job.Skipped) }
        @{ Count = $Job.Deleted; List = $Job.DeletedList
           Title = [string]::Format($inv, $(if ($Job.DryRun) { 'Would delete ({0} files, {1}):' } else { 'Deleted ({0} files, {1}):' }), $Job.Deleted, (Format-CleanupSize $Job.Bytes)) }
        @{ Count = $Job.Folders; List = $Job.FolderList
           Title = [string]::Format($inv, 'Folders removed ({0}):', $Job.Folders) }
    )
    foreach ($g in $groups) {
        if ($g.Count -le 0) { continue }
        $items.Add($g.Title)
        foreach ($line in $g.List) { $items.Add('  ' + $line) }
        $missing = $g.Count - $g.List.Count
        if ($missing -gt 0) {
            $more = [string]::Format($inv, '  ... and {0} more, not listed', $missing)
            $items.Add($more)
        }
    }
    $items.ToArray()
}

# ---- la papelera ------------------------------------------------------

<#
    Vacía la papelera de TU usuario en todas las unidades. Devuelve
    { Ok; Note; Items }. Antes cuenta lo que hay (10 = la carpeta
    virtual de la papelera): Clear-RecycleBin con la papelera ya vacía
    da error en algunas versiones, y "ya estaba vacía" es una
    respuesta, no un fallo.

    Items es lo que había, con su carpeta de origen, apuntado ANTES de
    vaciar: después ya no hay a quién preguntar.
#>
function Clear-CleanupRecycleBin {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    try {
        $shell = New-Object -ComObject Shell.Application
        $bin = $shell.NameSpace(10)
        $count = [int]$bin.Items().Count
        if ($count -eq 0) {
            return [PSCustomObject]@{ Ok = $true; Note = 'already empty'; Items = @() }
        }
        $items = Get-CleanupRecycleBinItems $bin $count
        if (-not $PSCmdlet.ShouldProcess('Recycle Bin', 'Empty')) {
            return [PSCustomObject]@{ Ok = $true; Note = ('WhatIf, nothing deleted: {0} items would be deleted' -f $count); Items = $items }
        }
        Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
        [PSCustomObject]@{ Ok = $true; Note = ('{0} items deleted' -f $count); Items = $items }
    }
    catch {
        [PSCustomObject]@{ Ok = $false; Note = (($_.Exception.Message -replace '\s+', ' ').Trim()); Items = @() }
    }
}

# Lo que hay en la papelera, una línea por elemento:
#   '12 KB      C:\Users\...\Documents\informe.docx'
# Si Windows no da la carpeta de origen, sale el nombre a secas.
function Get-CleanupRecycleBinItems {
    param($Bin, [int]$Count)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(('Deleted from the Recycle Bin ({0}):' -f $Count))
    try {
        foreach ($item in $Bin.Items()) {
            if ($lines.Count -gt $CleanupListMax) { break }
            $from = ''
            try { $from = [string]$item.ExtendedProperty('System.Recycle.DeletedFrom') } catch { $null = $_ }
            $path = if ($from) { Join-Path $from $item.Name } else { [string]$item.Name }
            $size = 0
            try { $size = [long]$item.Size } catch { $null = $_ }
            $line = '  {0,-10} {1}' -f (Format-CleanupSize $size), $path
            $lines.Add($line)
        }
    }
    catch { $null = $_ }
    if ($Count -gt ($lines.Count - 1)) {
        $more = '  ... and {0} more, not listed' -f ($Count - ($lines.Count - 1))
        $lines.Add($more)
    }
    $lines.ToArray()
}
