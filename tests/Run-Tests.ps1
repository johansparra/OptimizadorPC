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
    [string]$File   = '*'
)

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
