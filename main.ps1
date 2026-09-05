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

# ============================================================
# CÓMO SE CARGA TODO
#
# Cada bloque @@EMBED_DIR@@ carga una carpeta ENTERA, subcarpetas
# incluidas, por orden de ruta. Un .ps1 nuevo en cualquiera de
# ellas entra solo: no hay que tocar este archivo ni build.ps1.
#
# Lo único que se decide aquí es EL ORDEN DE LAS CAPAS, y solo
# importa por una razón: los datos se registran al cargarse, así
# que su mecanismo tiene que estar definido antes. Por ejemplo,
# ui/Data/Categories llama a Register-Category, que vive en
# ui/Engine/CategoryRegistry.ps1.
#
# Dentro de una carpeta el orden es alfabético y da igual: esos
# archivos solo definen funciones y tablas.
#
# build.ps1 sustituye cada bloque por el contenido de la carpeta,
# así que el .exe no necesita ninguna carpeta al lado.
# ============================================================

# ---- 1. Base: sistema de diseño y piezas genéricas ----
# No dependen de nadie y las usa cualquier capa, así que van primero.
# @@EMBED_DIR:ui/Design@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Design') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# ---- 2. Mecanismos: registran, traducen, guardan y enrutan ----
# @@EMBED_DIR:ui/Engine@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Engine') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# ---- 3. Índices: qué se ve, en qué orden y qué está bloqueado ----
# @@EMBED_DIR:ui/Index@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Index') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# ---- 4. Lógica de sistema ----
# Todo lo que habla con Windows vive en core/, fuera de ui/, y no
# conoce la interfaz. Solo define funciones, así que podría ir en
# cualquier punto; está aquí porque es la frontera entre lo que
# sabe de Windows y lo que sabe de la pantalla.
# @@EMBED_DIR:core@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'core') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# ---- 5. Datos: secciones, opciones e idiomas ----
# Se registran al cargarse, de ahí que vayan después del paso 2.
# Añadir una sección = crear su archivo; quitarla = borrarlo.
# @@EMBED_DIR:ui/Data@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Data') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# ---- 6. Piezas: los controles concretos ----
# @@EMBED_DIR:ui/Components@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Components') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# ---- 7. Pantallas: ensamblan las piezas ----
# @@EMBED_DIR:ui/Views@@
foreach ($f in (Get-ChildItem (Join-Path $ScriptRoot 'ui\Views') -Recurse -Filter '*.ps1' | Sort-Object FullName)) { . $f.FullName }
# @@ENDEMBED@@

# @@EMBED_XAML:ui/MainWindow.xaml@@
$xamlPath = Join-Path $ScriptRoot 'ui\MainWindow.xaml'
[xml]$xamlXml = Get-Content -Path $xamlPath -Raw
# @@ENDEMBED@@

$reader = New-Object System.Xml.XmlNodeReader $xamlXml
$Window = [System.Windows.Markup.XamlReader]::Load($reader)

Set-AppWindow $Window

# ---- Red de seguridad ----
# Antes que nada: un fallo dentro de un manejador sube al Dispatcher
# y de ahí al ShowDialog() del final, y lo que se ve entonces no es
# un error sino una ventana que ya no responde. Con esto queda
# apuntado en el registro de actividad y el programa sigue en pie.
# Ver ui/Engine/UiGuard.ps1.
Register-UiErrorGuard -Window $Window | Out-Null

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

# ---- Registro de actividad ----
# El cajón se pone encima de la pantalla actual, así que no pasa
# por el router: al cerrarlo sigues donde estabas.
$Window.FindName('BtnLog').Add_Click({
    param($s, $e)
    Switch-LogPanel ([System.Windows.Window]::GetWindow($s))
})

# Escape cierra el cajón. Es Preview para verlo antes que nadie:
# si el foco está dentro del cajón, el evento normal no llegaría
# hasta aquí.
$Window.Add_PreviewKeyDown({
    param($s, $e)
    if ($e.Key -eq 'Escape' -and (Get-LogPanelOpen)) {
        Hide-LogPanel $s
        $e.Handled = $true
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
    Move-ModeIndicator -Window $win -Animate
}

# ---- Menú lateral ----
# Los botones se construyen a partir de ui/Index/NavigationIndex.ps1;
# la selección y el plegado los gestiona ui/Components/Shell/Sidebar.ps1.
Build-Sidebar -Window $Window

$Window.FindName('BtnMenu').Add_Click({
    param($s, $e)
    Switch-Sidebar ([System.Windows.Window]::GetWindow($s))
})

# ---- Fondo vivo ----
# Las manchas de color que se mueven detrás del contenido. Va
# después del tema porque sus pinceles salen de él.
Build-Backdrop -Window $Window

# ---- Material de la ventana (Mica / Acrílico) ----
# Solo hace algo si el usuario lo ha pedido y Windows lo admite;
# en cualquier otro caso la ventana se queda con su fondo propio.
#
# En SourceInitialized y no aquí: antes de ese momento la ventana
# todavía no tiene descriptor, y sin descriptor no hay nada a lo
# que pedirle un material.
$Window.Add_SourceInitialized({
    param($s, $e)
    Sync-WindowMaterial -Window $s
})

# ---- Textos e iconos que el XAML no puede traducir ----
Update-TitleBarTexts $Window
Sync-ThemeButton

# ---- Vista inicial ----
# Pasa por el router para que se pueda repintar al cambiar de idioma.
Show-View -Name 'Show-OptimizationsListView'

$Window.ShowDialog() | Out-Null
