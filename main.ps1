#requires -Version 5.1
<#
    main.ps1
    --------
    Punto de entrada. Carga el shell (ui/MainWindow.xaml), aplica
    el tema, conecta los botones del title bar y del sidebar, y
    muestra la vista inicial (lista de categorías).

    Por ahora esto SOLO muestra la interfaz — sin lógica de tweaks.
#>

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

# ---- sistema de diseño, componentes, datos y vistas ----
. (Join-Path $ScriptRoot 'ui\Theme.ps1')
. (Join-Path $ScriptRoot 'ui\UiKit.ps1')
. (Join-Path $ScriptRoot 'ui\CategoryData.ps1')
. (Join-Path $ScriptRoot 'ui\Views\OptimizationsListView.ps1')
. (Join-Path $ScriptRoot 'ui\Views\CategoryDetailView.ps1')

# @@EMBED_XAML:ui/MainWindow.xaml@@
$xamlPath = Join-Path $ScriptRoot 'ui\MainWindow.xaml'
[xml]$xamlXml = Get-Content -Path $xamlPath -Raw
# @@ENDEMBED@@

$reader = New-Object System.Xml.XmlNodeReader $xamlXml
$Window = [System.Windows.Markup.XamlReader]::Load($reader)

# ---- Tema inicial ----
Set-AppTheme -Window $Window -Name 'Light'

# ---- Title bar: arrastrar ventana ----
$titleBar = $Window.FindName('TitleBar')
$titleBar.Add_MouseLeftButtonDown({
    param($s, $e)
    $win = [System.Windows.Window]::GetWindow($s)
    if ($e.ClickCount -eq 2) {
        if ($win.WindowState -eq 'Maximized') { $win.WindowState = 'Normal' } else { $win.WindowState = 'Maximized' }
        return
    }
    if ($e.ButtonState -eq 'Pressed') { $win.DragMove() }
})

# ---- Title bar: minimizar / maximizar / cerrar ----
$Window.FindName('BtnMinimize').Add_Click({
    param($s, $e)
    ([System.Windows.Window]::GetWindow($s)).WindowState = 'Minimized'
})
$Window.FindName('BtnMaximize').Add_Click({
    param($s, $e)
    $win = [System.Windows.Window]::GetWindow($s)
    if ($win.WindowState -eq 'Maximized') { $win.WindowState = 'Normal' } else { $win.WindowState = 'Maximized' }
})
$Window.FindName('BtnClose').Add_Click({
    param($s, $e)
    ([System.Windows.Window]::GetWindow($s)).Close()
})

# El glifo de maximizar alterna con el de restaurar.
$Window.Add_StateChanged({
    param($s, $e)
    $b = $s.FindName('BtnMaximize')
    if ($s.WindowState -eq 'Maximized') { $b.Content = Glyph 'Restore' } else { $b.Content = Glyph 'Maximize' }
})

# ---- Cambio de tema claro / oscuro ----
# Los recursos son dinámicos, así que basta con reescribirlos:
# toda la interfaz ya construida se repinta sola.
$Window.FindName('BtnTheme').Add_Click({
    param($s, $e)
    $win = [System.Windows.Window]::GetWindow($s)
    if ((Get-AppTheme) -eq 'Dark') {
        Set-AppTheme -Window $win -Name 'Light'
        $s.Content = Glyph 'Moon'
    } else {
        Set-AppTheme -Window $win -Name 'Dark'
        $s.Content = Glyph 'Sun'
    }
})

# ---- Selector de modo (solo visual por ahora) ----
$Window.FindName('BtnModeNormal').Add_Click({ param($s, $e) Set-ModeSelection $s })
$Window.FindName('BtnModeBuilder').Add_Click({ param($s, $e) Set-ModeSelection $s })
$Window.FindName('BtnModeConfig').Add_Click({ param($s, $e) Set-ModeSelection $s })

function Set-ModeSelection {
    param($Button)
    $win = [System.Windows.Window]::GetWindow($Button)
    foreach ($name in @('BtnModeNormal', 'BtnModeBuilder', 'BtnModeConfig')) {
        $win.FindName($name).Tag = $null
    }
    $Button.Tag = 'sel'
}

# ---- Sidebar: por ahora todas las entradas llevan a la misma vista ----
function Set-NavSelection {
    param($Button)
    $win = [System.Windows.Window]::GetWindow($Button)
    foreach ($name in @('NavSoftware', 'NavOptimize', 'NavCustomize', 'NavAdvanced', 'NavSettings', 'NavMore')) {
        $win.FindName($name).Tag = $null
    }
    $Button.Tag = 'sel'
    Show-OptimizationsListView -Window $win
}

foreach ($name in @('NavSoftware', 'NavOptimize', 'NavCustomize', 'NavAdvanced', 'NavSettings', 'NavMore')) {
    $Window.FindName($name).Add_Click({ param($s, $e) Set-NavSelection $s })
}

# ---- Vista inicial ----
Show-OptimizationsListView -Window $Window

$Window.ShowDialog() | Out-Null
