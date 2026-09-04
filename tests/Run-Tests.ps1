# ============================================================
# tests/Run-Tests.ps1
# Lanza todas las pruebas.
#
#   powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
#   pwsh       -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
#
# Conviene pasarlas en LOS DOS hosts (regla 8 de CLAUDE.md): el
# .exe corre sobre 5.1 con las funciones en ámbito global y
# main.ps1 sobre pwsh 7 en ámbito de script, y hay fallos que
# solo salen en uno.
#
#   -Filter <patrón>   solo las pruebas o los grupos que encajen
#   -File   <patrón>   solo los archivos *.Tests.ps1 que encajen,
#                      por ruta relativa:  -File 'Core*'
#
# Devuelve 0 si todo pasa y 1 si algo falla, para poder
# encadenarlo con && en un script.
#
# Todo se carga CON PUNTO en este ámbito -el kit, la aplicación
# y cada archivo de pruebas- para que unas cosas vean a otras.
# Es a propósito: reproduce cómo se carga el programa de verdad.
# ============================================================

param(
    [string]$Filter = '',
    [string]$File   = '*',
    [switch]$BothHosts
)

# ---- -BothHosts: los dos interpretes a la vez ----------------
# La regla 8 de CLAUDE.md pide pasar la suite en 5.1 Y en 7. Son
# dos procesos independientes, asi que se lanzan en paralelo y se
# espera a los dos: una sola orden, una sola aprobacion y la
# mitad de tiempo de reloj.
#
# Cada hijo corre este mismo archivo SIN -BothHosts, de modo que
# no hay recursion. Lo que permite el paralelo es que ya no
# comparten nada: la rama del registro de tests/Harness/Fixtures.ps1
# y el script combinado de tests/Source/Rules.Tests.ps1 llevan el
# PID en el nombre.
if ($BothHosts) {
    $interpretes = @(
        @{ Nombre = 'Windows PowerShell 5.1'; Exe = 'powershell' }
        @{ Nombre = 'PowerShell 7';           Exe = 'pwsh' }
    )

    $lanzados = New-Object System.Collections.Generic.List[object]
    foreach ($interprete in $interpretes) {
        $salida = Join-Path ([System.IO.Path]::GetTempPath()) `
                            ('optimizador-pruebas-{0}.txt' -f [Guid]::NewGuid())

        $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
        if ($Filter)       { $argumentos += @('-Filter', $Filter) }
        if ($File -ne '*') { $argumentos += @('-File', $File) }

        $proceso = Start-Process -FilePath $interprete.Exe -ArgumentList $argumentos `
                                 -PassThru -NoNewWindow `
                                 -RedirectStandardOutput $salida `
                                 -RedirectStandardError ($salida + '.err')

        $lanzados.Add(@{ Nombre = $interprete.Nombre; Proceso = $proceso; Salida = $salida })
    }

    $fallidos = 0
    foreach ($lanzado in $lanzados) {
        $lanzado.Proceso.WaitForExit()

        Write-Host ''
        Write-Host ('  ==== {0} ====' -f $lanzado.Nombre) -ForegroundColor White
        Get-Content -Path $lanzado.Salida -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }

        $errores = Get-Content -Path ($lanzado.Salida + '.err') -Raw -ErrorAction SilentlyContinue
        if ($errores) { Write-Host $errores -ForegroundColor Red }

        if ($lanzado.Proceso.ExitCode -ne 0) { $fallidos++ }

        foreach ($tmp in @($lanzado.Salida, ($lanzado.Salida + '.err'))) {
            if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
    }

    Write-Host ''
    if ($fallidos -gt 0) {
        Write-Host ('  {0} de {1} hosts en rojo.' -f $fallidos, $lanzados.Count) -ForegroundColor Red
        Write-Host ''
        exit 1
    }
    Write-Host '  Los dos hosts en verde.' -ForegroundColor Green
    Write-Host ''
    exit 0
}

# WPF necesita el hilo en STA. Los dos hosts arrancan así en
# Windows, pero un runspace incrustado puede no hacerlo, y el
# fallo que da entonces ('...only be created on an STA thread')
# no se parece en nada a la causa.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Host ''
    Write-Host '  El hilo no está en STA y WPF no puede crear controles.' -ForegroundColor Red
    Write-Host '  Vuelve a lanzarlo con:  pwsh -sta -File .\tests\Run-Tests.ps1' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

$started = Get-Date

. (Join-Path $PSScriptRoot 'Harness\TestKit.ps1')
$TestState.Filter = $Filter


Write-Host ''
Write-Host ('  Optimizador PC - pruebas   ({0} {1}, {2})' -f `
    $PSVersionTable.PSEdition, $PSVersionTable.PSVersion, [System.Threading.Thread]::CurrentThread.GetApartmentState()) -ForegroundColor White
Write-Host ('  ' + ('-' * 62)) -ForegroundColor DarkGray

# La aplicación, sin abrir la ventana. Si esto falla no hay nada
# que probar, así que se deja subir el error con su mensaje.
. (Join-Path $PSScriptRoot 'Harness\AppHost.ps1')

# Los montajes compartidos van después: necesitan New-Setting y
# el resto de funciones de la aplicación.
. (Join-Path $PSScriptRoot 'Harness\Fixtures.ps1')

# Las pruebas viven en subcarpetas por área (Core, Ui, Source), así
# que -File se compara contra la RUTA relativa y no contra el nombre:
#   -File 'Core*'   ->  Core/Log.Tests.ps1, Core/Registry.Tests.ps1...
#   -File '*Log*'   ->  Core/Log.Tests.ps1 y Ui/LogPanel.Tests.ps1
$files = @(Get-ChildItem -Path $PSScriptRoot -Recurse -Filter '*.Tests.ps1' |
           ForEach-Object {
               $_ | Add-Member -NotePropertyName Rel `
                    -NotePropertyValue ($_.FullName.Substring($PSScriptRoot.Length).TrimStart('\') -replace '\\', '/') -PassThru
           } |
           Where-Object { $_.Rel -like $File -or $_.Name -like $File } |
           Sort-Object Rel)

if ($files.Count -eq 0) {
    Write-Host ''
    Write-Host "  Ningún archivo de pruebas encaja con '$File'." -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

foreach ($testFile in $files) { . $testFile.FullName }

Write-TestSummary
Write-Host ('  {0} archivo(s) en {1:N1} s' -f $files.Count, ((Get-Date) - $started).TotalSeconds) -ForegroundColor DarkGray
Write-Host ''

if ($TestState.Failed -gt 0) { exit 1 }
exit 0
