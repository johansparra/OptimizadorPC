<#
    Pinta una pieza de la interfaz a PNG SIN abrir la ventana.

    Es el "pantallazo" de break-ui: aquí no hay navegador ni
    Playwright, así que la pieza se mide, se coloca y se vuelca a
    un mapa de bits con RenderTargetBitmap. Carga el programa por
    tests/Harness/AppHost.ps1, igual que las pruebas, así que NO
    toca tus ajustes ni el registro.

        pwsh -File .claude/skills/break-ui/render.ps1 `
             -Build .\peor-caso.ps1 -Width 520,760 -Language es -Theme Dark `
             -Out <scratchpad>

    -Build es un .ps1 que recibe $Window y DEVUELVE la pieza (o
    varias, que se apilan). Ejemplo:

        param($Window)
        New-SettingCard $Window (New-Setting -Name '...' -Description '...' -Value $true)

    Sale un PNG por ancho y tema: <Out>\<nombre>-<tema>-<ancho>.png.
    Las animaciones de entrada no corren (no hay reloj sin ventana):
    lo que se ve es el estado final, que es el que importa aquí.
#>
param(
    [Parameter(Mandatory)][string]$Build,
    [string[]]$Width = @('760'),
    [string]$Language = 'es',
    [string[]]$Theme = @('Light'),
    [Parameter(Mandatory)][string]$Out,
    [double]$Scale = 1.0
)

$ErrorActionPreference = 'Stop'

# Con -File, "520,760" llega como UNA cadena: se parte aquí.
$Width = @($Width -split ',' | ForEach-Object { [int]$_ })
$Theme = @($Theme -split ',')

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
. (Join-Path $root 'tests\Harness\AppHost.ps1')

if (-not (Test-Path $Out)) { New-Item -ItemType Directory -Path $Out | Out-Null }
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($Build)

foreach ($t in $Theme) {
    foreach ($w in $Width) {
        $window = New-AppWindow -Theme $t -Language $Language

        # Con punto, no con &: un .ps1 llamado con & abre su propio
        # ámbito de script y ahí $script:Translations no existe (T falla).
        $pieces = @(. $Build $window)

        # La pieza vive dentro de la ventana para heredar recursos
        # (estilos, pinceles): sin eso FindResource y DynamicResource
        # no resuelven nada y sale todo transparente.
        $stack = New-Object System.Windows.Controls.StackPanel
        foreach ($p in $pieces) { $stack.Children.Add($p) | Out-Null }

        $frame = New-Object System.Windows.Controls.Border
        $frame.Padding = New-Object System.Windows.Thickness 16
        Set-BoxBg $frame 'Bg1'
        $frame.Child = $stack
        $window.Content = $frame
        Sync-Dispatcher

        $frame.Measure((New-Object System.Windows.Size $w, ([double]::PositiveInfinity)))
        $h = [math]::Ceiling($frame.DesiredSize.Height)
        $frame.Arrange((New-Object System.Windows.Rect 0, 0, $w, $h))
        $frame.UpdateLayout()

        $dpi = 96 * $Scale
        $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
            [int]($w * $Scale), [int]($h * $Scale), $dpi, $dpi,
            [System.Windows.Media.PixelFormats]::Pbgra32)
        $bmp.Render($frame)

        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
        $file = Join-Path $Out ('{0}-{1}-{2}.png' -f $baseName, $t.ToLower(), $w)
        $fs = [System.IO.File]::Create($file)
        try { $enc.Save($fs) } finally { $fs.Close() }

        $window.Content = $null
        $window.Close()
        $file
    }
}
