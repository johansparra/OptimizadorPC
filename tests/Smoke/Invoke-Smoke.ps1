<#
    tests/Smoke/Invoke-Smoke.ps1
    Prueba de humo del PROGRAMA EMPAQUETADO: lo arranca de verdad, con su
    ventana, y lo mira desde fuera con UI Automation.

        powershell -ExecutionPolicy Bypass -File .\tests\Smoke\Invoke-Smoke.ps1
        powershell -ExecutionPolicy Bypass -File .\tests\Smoke\Invoke-Smoke.ps1 -Exe

    Sin -Exe arranca build/_combined.ps1 -el mismo script que build.ps1 mete
    en el .exe- con Windows PowerShell 5.1 y SIN elevar: no pide nada y se
    puede repetir.

    Con -Exe arranca build/OptimizadorPC.exe, que lleva -requireAdmin. UAC NO
    se salta: lo que pasa es que un proceso que YA está elevado arranca otro
    que pide administrador sin que salga ningún diálogo. Así corre solo
    -en la CI (los runners de Windows de GitHub son administrador sin UAC) o
    en local desde una terminal abierta con "Ejecutar como administrador"-.
    Si este script NO está elevado, no arranca el .exe (saldría el diálogo
    de UAC y se quedaría esperando a alguien): dice SALTADO y sale con 2.

    Qué comprueba:
      - que aparece la ventana, dentro de -TimeoutSeconds;
      - que su título es el nombre del programa (ui/Data/AppInfo.ps1, el
        mismo que fija ui/MainWindow.xaml);
      - con -Exe, que el proceso corre ELEVADO (lo mira en su token);
      - que el menú lateral trae sus cuatro entradas (Buscar, Optimizar,
        Guías, Ajustes, en el idioma que tenga guardado el usuario);
      - que el proceso sigue vivo unos segundos después;
      - que se cierra limpio con su botón de cerrar. Si no, se intenta
        CloseMainWindow y, como último recurso, se mata (y cuenta como fallo).
    NO pulsa nada: arrancar no cambia el equipo (solo lee el registro), y
    así se queda.

    No es un *.Tests.ps1 a propósito: Run-Tests.ps1 no lo recoge, porque
    abre una ventana delante de lo que estés haciendo. Hay que compilar
    antes (build.ps1, o build.ps1 -CombineOnly para el script).

    Códigos de salida:
        0  todo bien
        1  algo falla
        2  SALTADO: -Exe sin estar elevado (no se ha arrancado nada)
#>
param([switch]$Exe, [int]$TimeoutSeconds = 60)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fallos = New-Object System.Collections.Generic.List[string]
function Write-Check { param([string]$Text, [bool]$Ok)
    if ($Ok) { Write-Host "  ok    $Text" -ForegroundColor Green }
    else     { Write-Host "  FALLA $Text" -ForegroundColor Red; $script:fallos.Add($Text) }
}

# El título que tiene que llevar la ventana. AppInfo.ps1 es solo
# declaraciones y build.ps1 lo lee igual, con un punto.
. (Join-Path $root 'ui\Data\AppInfo.ps1')
$expectedTitle = $AppInfo.Name

<#
    ¿Está elevado un proceso? Se mira su token: TokenElevation (lo que
    enseña el Administrador de tareas) y, por si UAC está apagado del todo
    -como en algunos runners-, si el token es de administrador con el grupo
    activo, que es lo que pregunta la aplicación (Test-ProcessElevated).
    Devuelve $true, $false o $null si no se pudo mirar.
#>
function Test-SmokeProcessElevated {
    param([System.Diagnostics.Process]$Process)
    if (-not ('OptimizadorPCSmoke.ProcessToken' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace OptimizadorPCSmoke {
    public static class ProcessToken {
        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool GetTokenInformation(IntPtr token, int infoClass, out int info, int length, out int returned);
        [DllImport("kernel32.dll")]
        public static extern bool CloseHandle(IntPtr handle);

        const uint TOKEN_QUERY = 0x0008, TOKEN_DUPLICATE = 0x0002;
        const int TokenElevation = 20;

        // Token del proceso para consultar y duplicar (WindowsIdentity lo
        // duplica). IntPtr.Zero si no se pudo abrir. Hay que cerrarlo.
        public static IntPtr Open(IntPtr process) {
            IntPtr token;
            return OpenProcessToken(process, TOKEN_QUERY | TOKEN_DUPLICATE, out token) ? token : IntPtr.Zero;
        }

        // 1 elevado, 0 no, -1 no se pudo mirar.
        public static int Elevation(IntPtr token) {
            int value, returned;
            if (!GetTokenInformation(token, TokenElevation, out value, 4, out returned)) return -1;
            return value != 0 ? 1 : 0;
        }
    }
}
'@
    }
    $token = [IntPtr]::Zero
    try {
        $token = [OptimizadorPCSmoke.ProcessToken]::Open($Process.Handle)
        if ($token -eq [IntPtr]::Zero) { return $null }
        $elevation = [OptimizadorPCSmoke.ProcessToken]::Elevation($token)
        $identity = New-Object System.Security.Principal.WindowsIdentity($token)
        $admin = (New-Object System.Security.Principal.WindowsPrincipal($identity)).IsInRole(
            [System.Security.Principal.WindowsBuiltInRole]::Administrator)
        Write-Host ("        token: TokenElevation={0}, administrador={1}" -f $elevation, $admin) -ForegroundColor DarkGray
        ($elevation -eq 1) -or $admin
    }
    catch { $null }
    finally { if ($token -ne [IntPtr]::Zero) { $null = [OptimizadorPCSmoke.ProcessToken]::CloseHandle($token) } }
}

function Test-SelfElevated {
    try {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        (New-Object System.Security.Principal.WindowsPrincipal($id)).IsInRole(
            [System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { $false }
}

if ($Exe) {
    $target = Join-Path $root 'build\OptimizadorPC.exe'
    if (-not (Test-Path $target)) { throw "No existe ${target}: compila con build.ps1" }
    if (-not (Test-SelfElevated)) {
        Write-Host 'SALTADO: este proceso no está elevado y el .exe pide administrador.' -ForegroundColor Yellow
        Write-Host '  Arrancarlo sacaría el diálogo de UAC y la prueba se quedaría esperando a alguien.' -ForegroundColor Yellow
        Write-Host '  Ejecútala desde una terminal "Ejecutar como administrador" (o en la CI, que ya lo es).' -ForegroundColor Yellow
        exit 2
    }
    $firma = Get-AuthenticodeSignature -FilePath $target
    Write-Host ("Arrancando $target (elevado, sin diálogo). Firma: {0}" -f $firma.Status)
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
    # --- la ventana: la primera de nivel superior de ESE proceso ---
    $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $proc.Id
    $window = $null
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $window -and $watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ($proc.HasExited) { break }
        $window = [System.Windows.Automation.AutomationElement]::RootElement.FindFirst('Children', $cond)
        if (-not $window) { Start-Sleep -Milliseconds 400 }
    }
    if ($proc.HasExited) { Write-Host ("  el proceso terminó solo, con código {0}" -f $proc.ExitCode) -ForegroundColor Red }
    Write-Check ('la ventana aparece ({0:N1} s)' -f $watch.Elapsed.TotalSeconds) ([bool]$window)
    if ($window) {
        $proc.Refresh()
        Write-Host ("        MainWindowHandle = 0x{0:X}" -f [int64]$proc.MainWindowHandle) -ForegroundColor DarkGray

        Write-Check ("el título es '{0}' ('{1}')" -f $expectedTitle, $window.Current.Name) ($window.Current.Name -eq $expectedTitle)

        if ($Exe) {
            Write-Check 'el proceso corre elevado' ($true -eq (Test-SmokeProcessElevated $proc))
        }

        # --- el menú lateral: sus cuatro entradas, en inglés o en español ---
        # Se espera a que estén, con tope: la ventana existe antes de que
        # main.ps1 termine de construir el menú.
        $pares = @(@('Search', 'Buscar'), @('Optimize', 'Optimizar'), @('Guides', 'Guías'), @('Settings', 'Ajustes'))
        $menuWatch = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            $texts = @($window.FindAll('Descendants', [System.Windows.Automation.Condition]::TrueCondition) |
                       ForEach-Object { $_.Current.Name } | Where-Object { $_ })
            $faltan = @($pares | Where-Object { $par = $_; -not @($texts | Where-Object { $_ -in $par }).Count })
            if ($faltan.Count -eq 0) { break }
            Start-Sleep -Milliseconds 500
        } while ($menuWatch.Elapsed.TotalSeconds -lt 15 -and -not $proc.HasExited)
        foreach ($par in $pares) {
            Write-Check ("el menú trae '{0}'" -f ($par -join "' / '")) ([bool](@($texts | Where-Object { $_ -in $par }).Count))
        }

        # --- y sigue vivo ---
        Start-Sleep -Seconds 3
        $proc.Refresh()
        Write-Check 'el proceso sigue vivo 3 s después' (-not $proc.HasExited)

        # --- cerrar: su botón; si no, CloseMainWindow; si no, se mata ---
        $como = $null
        try {
            $wp = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
            $wp.Close()
        }
        catch { Write-Host "        WindowPattern.Close: $($_.Exception.Message)" -ForegroundColor DarkGray }
        if ($proc.WaitForExit(15000)) { $como = 'botón de cerrar' }
        else {
            $null = $proc.CloseMainWindow()
            if ($proc.WaitForExit(10000)) { $como = 'CloseMainWindow' }
        }
        Write-Check ("se cierra limpio ({0})" -f $(if ($como) { $como } else { 'no: hubo que matarlo' })) ([bool]$como)
    }
}
finally {
    if (-not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        $null = $proc.WaitForExit(5000)
    }
}

Write-Host ''
if ($fallos.Count -gt 0) { Write-Host "  $($fallos.Count) fallo(s)" -ForegroundColor Red; exit 1 }
Write-Host '  Prueba de humo en verde.' -ForegroundColor Green
exit 0
