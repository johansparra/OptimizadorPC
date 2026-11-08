<#
    tests/Smoke/Invoke-Smoke.ps1
    Prueba de humo del PROGRAMA EMPAQUETADO: lo arranca de verdad, con su
    ventana, y lo mira desde fuera con UI Automation.

        powershell -ExecutionPolicy Bypass -File .\tests\Smoke\Invoke-Smoke.ps1
        powershell -ExecutionPolicy Bypass -File .\tests\Smoke\Invoke-Smoke.ps1 -Exe

    Sin -Exe arranca build/_combined.ps1 -el mismo script que build.ps1 mete
    en el .exe- con Windows PowerShell 5.1 y SIN elevar: no pide nada y se
    puede repetir. Con -Exe arranca build/OptimizadorPC.exe, que pide UAC:
    alguien tiene que aceptarlo, así que no corre solo.

    Qué comprueba: que aparece la ventana, que el menú lateral trae sus
    cuatro entradas (Buscar, Optimizar, Guías, Ajustes, en el idioma que
    tenga guardado el usuario) y que el proceso sigue vivo unos segundos
    después. Luego la cierra. NO pulsa nada: arrancar no cambia el equipo
    (solo lee el registro), y así se queda.

    No es un *.Tests.ps1 a propósito: Run-Tests.ps1 no lo recoge, porque
    abre una ventana delante de lo que estés haciendo. Hay que compilar
    antes (build.ps1, o build.ps1 -CombineOnly para el script).

    Devuelve 0 si todo va bien y 1 si algo falla.
#>
param([switch]$Exe, [int]$TimeoutSeconds = 45)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fallos = New-Object System.Collections.Generic.List[string]
function Write-Check { param([string]$Text, [bool]$Ok)
    if ($Ok) { Write-Host "  ok    $Text" -ForegroundColor Green }
    else     { Write-Host "  FALLA $Text" -ForegroundColor Red; $script:fallos.Add($Text) }
}

if ($Exe) {
    $target = Join-Path $root 'build\OptimizadorPC.exe'
    if (-not (Test-Path $target)) { throw "No existe ${target}: compila con build.ps1" }
    Write-Host "Arrancando $target (pedirá UAC)..."
    $proc = Start-Process -FilePath $target -PassThru
}
else {
    $target = Join-Path $root 'build\_combined.ps1'
    if (-not (Test-Path $target)) { throw "No existe ${target}: compila con build.ps1 o build.ps1 -CombineOnly" }
    Write-Host "Arrancando $target con Windows PowerShell 5.1..."
    $proc = Start-Process -FilePath 'powershell.exe' -PassThru -WindowStyle Hidden `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$target`""
}

try {
    # --- la ventana ---
    $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $proc.Id
    $window = $null
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $window -and $watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ($proc.HasExited) { break }
        $window = [System.Windows.Automation.AutomationElement]::RootElement.FindFirst('Children', $cond)
        if (-not $window) { Start-Sleep -Milliseconds 400 }
    }
    Write-Check ('la ventana aparece ({0:N1} s)' -f $watch.Elapsed.TotalSeconds) ([bool]$window)
    if ($window) {

    Write-Check ("el título es el del programa ('{0}')" -f $window.Current.Name) ($window.Current.Name -match 'Optimizador')

    # --- el menú lateral: sus cuatro entradas, en inglés o en español ---
    Start-Sleep -Seconds 2
    $texts = @($window.FindAll('Descendants', [System.Windows.Automation.Condition]::TrueCondition) |
               ForEach-Object { $_.Current.Name } | Where-Object { $_ })
    foreach ($par in @(@('Search', 'Buscar'), @('Optimize', 'Optimizar'), @('Guides', 'Guías'), @('Settings', 'Ajustes'))) {
        Write-Check ("el menú trae '{0}'" -f ($par -join "' / '")) ([bool](@($texts | Where-Object { $_ -in $par }).Count))
    }

    # --- y sigue vivo ---
    Start-Sleep -Seconds 3
    $proc.Refresh()
    Write-Check 'el proceso sigue vivo 5 s después' (-not $proc.HasExited)

    # --- cerrar ---
    try {
        $wp = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        $wp.Close()
    }
    catch { $null = $_ }
    $cerrado = $proc.WaitForExit(10000)
    Write-Check 'se cierra con su botón de cerrar' $cerrado
    }
}
finally {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($fallos.Count -gt 0) { Write-Host "  $($fallos.Count) fallo(s)" -ForegroundColor Red; exit 1 }
Write-Host '  Prueba de humo en verde.' -ForegroundColor Green
exit 0
