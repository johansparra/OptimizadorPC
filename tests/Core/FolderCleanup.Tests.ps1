# ============================================================
# Pruebas de core/Commands/FolderCleanup.ps1 — vaciar carpetas.
#
# NADA de esto toca tus carpetas de verdad. Las reglas de la lista
# blanca se prueban resolviendo rutas, sin abrirlas; el borrado se
# prueba con New-CleanupJobAt sobre una carpeta de mentira en %TEMP%
# (con el PID en el nombre), que se crea y se tira en cada prueba.
#
# La papelera no se prueba aquí: vaciarla de verdad sería vaciar la
# tuya. Su paso se prueba desarmado, en CommandRunner.Tests.ps1.
# ============================================================

function Get-CleanupFixtureRoot {
    Join-Path ([System.IO.Path]::GetTempPath()) ('OptimizadorPC-cleanup-tests-' + $PID)
}

<#
    Una carpeta de mentira con un poco de todo:

        root\a.txt  root\x.db  root\ro.txt (solo lectura)
        root\hidden.db (oculto)
        root\sub\y.db  root\sub\deep\z.tmp
        root\link  -> unión a ..\outside (con keep.txt dentro)

    Devuelve la ruta de 'root'. 'outside' es lo que NUNCA se debe tocar.
#>
function New-CleanupFixture {
    $base = Get-CleanupFixtureRoot
    Remove-CleanupFixture
    $root = Join-Path $base 'root'
    $outside = Join-Path $base 'outside'
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'sub\deep'), $outside | Out-Null

    foreach ($f in 'a.txt', 'x.db', 'ro.txt', 'hidden.db', 'sub\y.db', 'sub\deep\z.tmp') {
        [System.IO.File]::WriteAllText((Join-Path $root $f), 'x')
    }
    (Get-Item -LiteralPath (Join-Path $root 'ro.txt')).IsReadOnly = $true
    (Get-Item -LiteralPath (Join-Path $root 'hidden.db') -Force).Attributes = 'Hidden'
    [System.IO.File]::WriteAllText((Join-Path $outside 'keep.txt'), 'keep')
    New-Item -ItemType Junction -Path (Join-Path $root 'link') -Target $outside | Out-Null
    $root
}

function Remove-CleanupFixture {
    $base = Get-CleanupFixtureRoot
    if (-not (Test-Path -LiteralPath $base)) { return }
    # Primero las uniones, para que el borrado recursivo no entre en
    # ellas (Remove-Item las sigue en 5.1).
    foreach ($d in @(Get-ChildItem -LiteralPath $base -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                     Where-Object { $_.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) })) {
        try { $d.Delete($false) } catch { $null = $_ }
    }
    Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.IsReadOnly = $false }
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-TestCleanupJob {
    param($Job)
    $n = 0
    while (-not (Step-CleanupJob $Job) -and $n -lt 10000) { $n++ }
    $n
}

Describe 'core/Commands/FolderCleanup.ps1 - qué carpetas se dejan vaciar' {

    It 'cada entrada de la lista blanca tiene forma válida y cae dentro de tu carpeta de usuario (salvo C:\Windows\Temp)' {
        $usuario = [Environment]::GetFolderPath('UserProfile').TrimEnd('\') + '\'
        $winTemp = Join-Path ([Environment]::GetFolderPath('Windows')) 'Temp'
        foreach ($t in $CleanupAllowedFolders) {
            Assert-True (Test-CleanupTargetAllowed $t) "no pasa su propia lista: $t"
            $r = Resolve-CleanupTarget $t
            Assert-Equal '' $r.Problem "$t"
            $dentro = $r.Path.StartsWith($usuario, [System.StringComparison]::OrdinalIgnoreCase) -or
                      [string]::Equals($r.Path, $winTemp, [System.StringComparison]::OrdinalIgnoreCase)
            Assert-True $dentro "$t sale de tu carpeta: $($r.Path)"
        }
    }

    It 'lo que no está tal cual en la lista se rechaza, aunque cuelgue de una entrada' {
        foreach ($t in '%LOCALAPPDATA%\Microsoft', '%LOCALAPPDATA%', '%APPDATA%', '%TEMP%\sub',
                       '%TEMP%\..\..', '%WINDIR%', '%WINDIR%\System32', '%USERPROFILE%', 'C:\Windows\Temp',
                       '%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.exe', '%LOCALAPPDATA%\Microsoft\Windows\Explorer', '') {
            Assert-False (Test-CleanupTargetAllowed $t) "debería rechazar '$t'"
            Assert-Null (Resolve-CleanupTarget $t).Path "'$t' no debería resolverse"
        }
    }

    It 'la forma: variable conocida, sin "..", y el comodín solo al final y como *.ext' {
        $p = Split-CleanupTarget '%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.db'
        Assert-Equal 'LOCALAPPDATA' $p.Root
        Assert-Equal 'Microsoft\Windows\Explorer' $p.Relative
        Assert-Equal '*.db' $p.Pattern
        Assert-False $p.Full

        $p = Split-CleanupTarget '%TEMP%'
        Assert-Equal '' $p.Relative
        Assert-Equal '*' $p.Pattern
        Assert-True $p.Full

        foreach ($mala in '%TEMP%\..', '%TEMP%\.', '%TEMP%\*', '%TEMP%\*\x', '%TEMP%\a*b', '%TEMP%\x:y',
                          '%FOO%\x', 'TEMP\x', '%TEMP%x', '%TEMP%\\x') {
            Assert-Null (Split-CleanupTarget $mala) "debería rechazar la forma '$mala'"
        }
    }

    It 'un %TEMP% que apunta fuera de tu carpeta se bloquea' {
        # Corriendo elevado, un TMP=C:\Windows vaciaría el sistema.
        $antes = $env:TMP
        $env:TMP = 'C:\Windows'
        try { $r = Resolve-CleanupTarget '%TEMP%' }
        finally { $env:TMP = $antes }
        Assert-Null $r.Path
        Assert-Match 'outside your user folder' $r.Problem
    }

    It 'una entrada bloqueada sale como trabajo ya terminado y con Blocked' {
        $job = New-CleanupJob '%LOCALAPPDATA%\Microsoft'
        Assert-True $job.Done
        Assert-True $job.Blocked
        Assert-Match 'allowlist' $job.Note
    }
}

Describe 'core/Commands/FolderCleanup.ps1 - vaciar' {

    It 'modo completo: borra todo, también ocultos y de solo lectura, y la raíz se queda' {
        $root = New-CleanupFixture
        try {
            $job = New-CleanupJobAt -Path $root
            Invoke-TestCleanupJob $job | Out-Null
            Assert-True $job.Done
            Assert-True (Test-Path -LiteralPath $root) 'la carpeta raíz se vacía, no se borra'
            Assert-Equal 0 @(Get-ChildItem -LiteralPath $root -Force).Count 'quedó algo dentro'
            Assert-Equal 6 $job.Deleted
            Assert-Equal 3 $job.Folders 'sub, deep y el enlace'
        }
        finally { Remove-CleanupFixture }
    }

    It 'una unión dentro de la carpeta se quita, pero lo que hay al otro lado no se toca' {
        $root = New-CleanupFixture
        try {
            $keep = Join-Path (Split-Path $root -Parent) 'outside\keep.txt'
            Invoke-TestCleanupJob (New-CleanupJobAt -Path $root) | Out-Null
            Assert-True (Test-Path -LiteralPath $keep) 'se ha seguido el enlace y se ha borrado lo de fuera'
            Assert-False (Test-Path -LiteralPath (Join-Path $root 'link')) 'el enlace se tendría que haber quitado'
        }
        finally { Remove-CleanupFixture }
    }

    It 'modo con patrón: solo esos archivos, en subcarpetas también, sin ocultos ni quitar carpetas' {
        $root = New-CleanupFixture
        try {
            $job = New-CleanupJobAt -Path $root -Pattern '*.db' -Full $false
            Invoke-TestCleanupJob $job | Out-Null
            Assert-False (Test-Path -LiteralPath (Join-Path $root 'x.db'))
            Assert-False (Test-Path -LiteralPath (Join-Path $root 'sub\y.db')) 'no ha bajado a las subcarpetas'
            Assert-True  (Test-Path -LiteralPath (Join-Path $root 'hidden.db')) 'el modo 1 no toca los ocultos'
            Assert-True  (Test-Path -LiteralPath (Join-Path $root 'a.txt'))
            Assert-True  (Test-Path -LiteralPath (Join-Path $root 'sub\deep')) 'el modo 1 no quita carpetas'
            Assert-Equal 2 $job.Deleted
            Assert-Equal 0 $job.Folders
        }
        finally { Remove-CleanupFixture }
    }

    It 'se hace por trozos: un trozo corto no se lo come todo, y se puede seguir' {
        $root = New-CleanupFixture
        try {
            foreach ($i in 1..400) { [System.IO.File]::WriteAllText((Join-Path $root "f$i.tmp"), 'x') }
            $job = New-CleanupJobAt -Path $root
            # Un trozo de 1 ms no da para 406 archivos: tiene que parar a
            # medias, con algo hecho, y seguir donde lo dejó.
            Assert-False (Step-CleanupJob $job 1) 'un trozo de 1 ms se lo ha comido todo'
            Assert-True ($job.Deleted -lt 406) 'no ha parado a medias'
            Invoke-TestCleanupJob $job | Out-Null
            Assert-True $job.Done
            Assert-Equal 406 $job.Deleted
        }
        finally { Remove-CleanupFixture }
    }

    It 'una carpeta que no existe no es un fallo: termina y lo dice' {
        $job = New-CleanupJobAt -Path (Join-Path (Get-CleanupFixtureRoot) 'no-existe')
        Assert-True $job.Done
        Assert-False $job.Blocked
        Assert-Match 'not found' (Format-CleanupSummary $job)
    }

    It 'si la carpeta misma es un enlace, no se entra: bloqueada' {
        $root = New-CleanupFixture
        try {
            $job = New-CleanupJobAt -Path (Join-Path $root 'link')
            Assert-True $job.Blocked
            Invoke-TestCleanupJob $job | Out-Null
            Assert-True (Test-Path -LiteralPath (Join-Path (Split-Path $root -Parent) 'outside\keep.txt'))
        }
        finally { Remove-CleanupFixture }
    }
}

Describe 'core/Commands/FolderCleanup.ps1 - el resumen' {

    It 'los tamaños se escriben con punto y su unidad, en cualquier idioma del sistema' {
        Assert-Equal '512 B' (Format-CleanupSize 512)
        Assert-Equal '2 KB' (Format-CleanupSize 2048)
        Assert-Equal '1.5 MB' (Format-CleanupSize ([long](1.5 * 1MB)))
        Assert-Equal '2.0 GB' (Format-CleanupSize ([long](2 * 1GB)))
    }

    It 'dice lo borrado, lo liberado, las carpetas y lo que estaba en uso' {
        $job = New-CleanupJobAt -Path ''
        $job.Deleted = 3; $job.Bytes = 2048; $job.Folders = 1; $job.Skipped = 2
        Assert-Equal '3 files deleted, 2 KB freed, 1 folders removed; 2 in use, skipped' (Format-CleanupSummary $job)
    }
}

Describe 'core/Commands/FolderCleanup.ps1 - el detalle de lo que hizo' {

    It 'lista lo borrado, las carpetas quitadas y lo saltado con su motivo, y lo saltado va primero' {
        $root = New-CleanupFixture
        $bloqueado = Join-Path $root 'bloqueado.tmp'
        [System.IO.File]::WriteAllText($bloqueado, 'x')
        $fs = [System.IO.File]::Open($bloqueado, 'Open', 'Read', 'None')
        try {
            $job = New-CleanupJobAt -Path $root
            Invoke-TestCleanupJob $job | Out-Null
            $items = @(Get-CleanupItems $job)
            Assert-Match '^Skipped, in use or no access \(1\):' $items[0]
            Assert-Match ('^  in use\s+' + [regex]::Escape($bloqueado) + '$') $items[1]
            $texto = $items -join "`n"
            Assert-Match 'Deleted \(6 files' $texto
            Assert-Match ([regex]::Escape((Join-Path $root 'sub\deep\z.tmp'))) $texto
            Assert-Match 'Folders removed \(3\)' $texto
            Assert-Match ([regex]::Escape((Join-Path $root 'sub'))) $texto
        }
        finally {
            $fs.Dispose()
            Remove-CleanupFixture
        }
    }

    It 'pasado el tope se sigue contando, pero ya no se apunta la ruta' {
        $root = New-CleanupFixture
        try {
            # Sombra LOCAL de la variable de core/: la ve New-CleanupJobAt por
            # ámbito dinámico y se va al salir del It. Set-Variable en vez de
            # "=" para que PSScriptAnalyzer no la tome por variable muerta.
            Set-Variable -Name CleanupListMax -Value 2
            $job = New-CleanupJobAt -Path $root
            Invoke-TestCleanupJob $job | Out-Null
            Assert-Equal 6 $job.Deleted
            Assert-Equal 2 $job.DeletedList.Count
            Assert-Match '\.\.\. and 4 more, not listed' (@(Get-CleanupItems $job) -join "`n")
        }
        finally { Remove-CleanupFixture }
    }

    It 'sin nada hecho, no hay detalle' {
        $job = New-CleanupJobAt -Path (Join-Path (Get-CleanupFixtureRoot) 'no-existe')
        Assert-Equal 0 @(Get-CleanupItems $job).Count
    }
}

Describe 'core/Commands/FolderCleanup.ps1 - %TEMP% fuera del perfil y C:\Windows\Temp' {

    It 'C:\Windows\Temp se resuelve tal cual' {
        $r = Resolve-CleanupTarget '%WINDIR%\Temp'
        Assert-Equal '' $r.Problem
        Assert-Equal (Join-Path ([Environment]::GetFolderPath('Windows')) 'Temp') $r.Path
    }

    It 'un %TEMP% movido a otro sitio vale si se llama Temp y no es del sistema' {
        $antes = $env:TMP
        try {
            foreach ($bueno in 'C:\Temp', 'R:\Tmp', 'D:\Datos\Temp') {
                $env:TMP = $bueno
                Assert-Equal '' (Resolve-CleanupTarget '%TEMP%').Problem "debería aceptar TMP=$bueno"
            }
            foreach ($malo in 'C:\', 'D:\Datos', 'C:\Program Files\Temp', 'C:\ProgramData\Temp',
                              'C:\Windows\System32\Temp', 'C:\Users\Public\Temp') {
                $env:TMP = $malo
                Assert-Null (Resolve-CleanupTarget '%TEMP%').Path "debería rechazar TMP=$malo"
            }
        }
        finally { $env:TMP = $antes }
    }
}

Describe 'core/Commands/FolderCleanup.ps1 - simulacro (-WhatIf)' {

    It 'en simulacro se cuenta y se apunta todo, pero no se borra nada' {
        $root = New-CleanupFixture
        try {
            $job = New-CleanupJobAt -Path $root -DryRun $true
            Invoke-TestCleanupJob $job | Out-Null
            Assert-Equal 6 $job.Deleted 'el simulacro tiene que contar lo que borraría'
            Assert-True (Test-Path -LiteralPath (Join-Path $root 'a.txt')) 'el simulacro ha borrado de verdad'
            Assert-True (Test-Path -LiteralPath (Join-Path $root 'sub\deep\z.tmp'))
            Assert-True (Test-Path -LiteralPath (Join-Path $root 'link')) 'el simulacro ha quitado el enlace'
            Assert-Match '^WhatIf, nothing deleted' (Format-CleanupSummary $job)
            Assert-Match 'Would delete \(6 files' (@(Get-CleanupItems $job) -join "`n")
        }
        finally { Remove-CleanupFixture }
    }

    It 'si la carpeta se cambia por un enlace entre dos latidos, no se entra' {
        $root = New-CleanupFixture
        try {
            $job = New-CleanupJobAt -Path $root
            # Se abre la raíz (apunta 'sub' como carpeta de verdad)...
            Step-CleanupJob $job 0 | Out-Null
            Open-CleanupFolder $job ([System.IO.DirectoryInfo]$root)
            # ...y antes de entrar, 'sub' pasa a ser una unión hacia fuera.
            $sub = Join-Path $root 'sub'
            $fuera = Join-Path (Split-Path $root -Parent) 'outside'
            Get-ChildItem -LiteralPath $sub -Recurse -Force | Sort-Object FullName -Descending | ForEach-Object { $_.Delete() }
            [System.IO.Directory]::Delete($sub)
            New-Item -ItemType Junction -Path $sub -Target $fuera | Out-Null
            Invoke-TestCleanupJob $job | Out-Null
            Assert-True (Test-Path -LiteralPath (Join-Path $fuera 'keep.txt')) 'ha entrado en la unión y ha borrado lo de fuera'
        }
        finally { Remove-CleanupFixture }
    }
}
