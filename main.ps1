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

# ---- Base: sistema de diseño y componentes genéricos ----
. (Join-Path $ScriptRoot 'ui\Theme.ps1')
. (Join-Path $ScriptRoot 'ui\UiKit.ps1')

# ---- Mecanismos (sin datos) ----
. (Join-Path $ScriptRoot 'ui\Translation.ps1')
. (Join-Path $ScriptRoot 'ui\AppSettings.ps1')
. (Join-Path $ScriptRoot 'ui\Router.ps1')
. (Join-Path $ScriptRoot 'ui\CategoryRegistry.ps1')
. (Join-Path $ScriptRoot 'ui\PreferenceRegistry.ps1')

# ---- Archivos principales: qué se ve y en qué orden ----
. (Join-Path $ScriptRoot 'ui\CategoryIndex.ps1')
. (Join-Path $ScriptRoot 'ui\NavigationIndex.ps1')
. (Join-Path $ScriptRoot 'ui\LanguageIndex.ps1')

# ---- Carpetas que se cargan enteras ----
# Todo archivo .ps1 que haya dentro entra solo, por orden de nombre.
# Añadir una categoría, un componente o una vista = crear su archivo;
# quitarla = borrarlo. No hay que tocar este archivo.
# build.ps1 sustituye cada bloque por el contenido de la carpeta.

# @@EMBED_DIR:ui/Lang@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Lang') -Filter '*.ps1' | Sort-Object Name)) { . $f.FullName }
# @@ENDEMBED@@

# @@EMBED_DIR:ui/Categories@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Categories') -Filter '*.ps1' | Sort-Object Name)) { . $f.FullName }
# @@ENDEMBED@@

# @@EMBED_DIR:ui/Preferences@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Preferences') -Filter '*.ps1' | Sort-Object Name)) { . $f.FullName }
# @@ENDEMBED@@

# @@EMBED_DIR:ui/Components@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Components') -Filter '*.ps1' | Sort-Object Name)) { . $f.FullName }
# @@ENDEMBED@@

# @@EMBED_DIR:ui/Views@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Views') -Filter '*.ps1' | Sort-Object Name)) { . $f.FullName }
# @@ENDEMBED@@

# @@EMBED_XAML:ui/MainWindow.xaml@@
$xamlPath = Join-Path $ScriptRoot 'ui\MainWindow.xaml'
[xml]$xamlXml = Get-Content -Path $xamlPath -Raw
# @@ENDEMBED@@

$reader = New-Object System.Xml.XmlNodeReader $xamlXml
$Window = [System.Windows.Markup.XamlReader]::Load($reader)

Set-AppWindow $Window

# ---- Preferencias guardadas ----
# Se leen de %APPDATA%\OptimizadorPC\settings.json y se aplican
# antes de dibujar nada, para que la primera pintura ya salga con
# el tema y el idioma correctos y no haya parpadeo.
Import-AppSettings
Set-AppTheme    -Window $Window -Name (Get-AppSetting 'Theme'    -Default 'Light')
Set-AppLanguage (Get-AppSetting 'Language' -Default (Get-DefaultLanguage))

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
# Pasa por la misma preferencia que el desplegable de Settings,
# así que el cambio se guarda se haga desde donde se haga.
$Window.FindName('BtnTheme').Add_Click({
    param($s, $e)
    if ((Get-AppTheme) -eq 'Dark') { $next = 'Light' } else { $next = 'Dark' }
    & (Get-PreferenceById 'theme').Set $next
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

# ---- Menú lateral ----
# Los botones se construyen a partir de ui/NavigationIndex.ps1;
# la selección y el plegado los gestiona ui/Components/Sidebar.ps1.
Build-Sidebar -Window $Window

$Window.FindName('BtnMenu').Add_Click({
    param($s, $e)
    Switch-Sidebar ([System.Windows.Window]::GetWindow($s))
})

# ---- Textos e iconos que el XAML no puede traducir ----
Update-TitleBarTexts $Window
Sync-ThemeButton

# ---- Vista inicial ----
# Pasa por el router para que se pueda repintar al cambiar de idioma.
Show-View -Name 'Show-OptimizationsListView'

$Window.ShowDialog() | Out-Null
