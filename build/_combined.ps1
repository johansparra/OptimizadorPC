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
# ---- inicio incluido: ui/Theme.ps1 ----
# ============================================================
# Theme.ps1
# Sistema de diseño: paletas claro/oscuro, iconos Fluent,
# tipografía y helpers de animación.
# Solo apariencia, ninguna lógica de negocio.
#
# Los glifos se referencian por codepoint (no como carácter
# literal) para que el archivo no dependa de la codificación.
# ============================================================

# ---- Catálogo de iconos: Segoe Fluent Icons (nativa de Windows 11) ----
$Glyphs = @{
    # categorías
    Shield = 0xEA18; Power = 0xE7E8; Game = 0xE7FC; Sync = 0xE895
    Bell   = 0xEA8F; Volume = 0xE767
    # navegación lateral
    Package = 0xE7B8; Gauge = 0xEC4A; Palette = 0xE790
    Wrench  = 0xE90F; Gear  = 0xE713; More    = 0xE712
    # cromo de ventana
    Menu = 0xE700; Minimize = 0xE921; Maximize = 0xE922
    Restore = 0xE923; Close = 0xE8BB
    # acciones e indicadores
    Search = 0xE721; ChevronRight = 0xE76C; ChevronDown = 0xE70D
    Back = 0xE72B; Filter = 0xE71C; StarFill = 0xE735; Star = 0xE734
    Grid = 0xE80A; Sliders = 0xE9E9; Bolt = 0xE945; Sun = 0xE706
    Moon = 0xE708; Help = 0xE897; Heart = 0xEB51; Check = 0xE73E
    Info = 0xE946; Bulb = 0xEA80
}

function Glyph {
    param([string]$Name)
    if (-not $Glyphs.ContainsKey($Name)) { throw "Glifo desconocido: $Name" }
    [string][char]$Glyphs[$Name]
}

# ---- Paletas ------------------------------------------------
# Cada clave se publica como SolidColorBrush en Window.Resources,
# asi que el XAML la consume con {DynamicResource <clave>} y el
# codigo con SetResourceReference: cambiar de tema repinta todo
# en vivo, sin reconstruir las vistas.
function Get-Palette {
    param([string]$Name)

    if ($Name -eq 'Dark') {
        @{
            Bg0 = '#12141A'; Bg1 = '#181B22'; Bg2 = '#1E222A'
            Surface = '#1E222A'; SurfaceHover = '#252A34'; SurfaceSunken = '#15181E'
            Stroke = '#2C323D'; StrokeHover = '#3D4552'; StrokeFocus = '#4D8DFF'
            Text = '#EDEFF3'; TextMuted = '#A3ABB9'; TextFaint = '#6E7787'
            Accent = '#4D8DFF'; AccentHover = '#6EA4FF'; AccentSoft = '#1B2C4A'; AccentText = '#FFFFFF'
            Success = '#3DD68C'; SuccessSoft = '#122A20'
            Warn = '#F0B429'; WarnSoft = '#2E2412'
            Danger = '#FF6B81'; DangerSoft = '#331821'
            TrackOff = '#3D4552'; Knob = '#FFFFFF'
            ScrollThumb = '#3D4552'; Overlay = '#000000'
        }
    }
    else {
        @{
            Bg0 = '#F2F4F7'; Bg1 = '#FFFFFF'; Bg2 = '#F7F9FC'
            Surface = '#FFFFFF'; SurfaceHover = '#FAFBFD'; SurfaceSunken = '#F0F2F6'
            Stroke = '#E6E9EF'; StrokeHover = '#CFD6E2'; StrokeFocus = '#2563EB'
            Text = '#15181E'; TextMuted = '#59616F'; TextFaint = '#8B93A2'
            Accent = '#2563EB'; AccentHover = '#1D4FD8'; AccentSoft = '#E9F0FE'; AccentText = '#FFFFFF'
            Success = '#0E9F6E'; SuccessSoft = '#E6F7F0'
            Warn = '#C2680A'; WarnSoft = '#FDF3E5'
            Danger = '#E11D48'; DangerSoft = '#FDEAEF'
            TrackOff = '#CBD2DE'; Knob = '#FFFFFF'
            ScrollThumb = '#C6CDDA'; Overlay = '#0B1220'
        }
    }
}

$CurrentTheme = 'Light'

function Set-AppTheme {
    param($Window, [string]$Name)

    $palette = Get-Palette $Name
    foreach ($key in $palette.Keys) {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($palette[$key])
        $existing = $Window.Resources[$key]

        # Se muta el color del pincel que ya existe en lugar de sustituirlo:
        # reemplazar un recurso referenciado por DynamicResource dispara una
        # reevaluación que WPF rechaza, y además así todos los consumidores
        # (XAML y código) se repintan solos al compartir la misma instancia.
        if ($existing -is [System.Windows.Media.SolidColorBrush] -and -not $existing.IsFrozen) {
            $existing.Color = $color
        }
        else {
            # WPF congela al cargar el XAML los pinceles que considera
            # compartibles, y un Freezable congelado no se puede mutar: hay
            # que sustituirlo por uno nuevo (que ya nace descongelado, así
            # que los cambios de tema siguientes sí lo mutan).
            # Se usa Add() y no el indexador porque el indexador guarda el
            # PSObject que envuelve al pincel, y WPF lo rechaza al resolver
            # el DynamicResource con "no es un valor válido para Foreground".
            $fresh = New-Object System.Windows.Media.SolidColorBrush
            $fresh.Color = $color
            $Window.Resources.Remove($key)
            $Window.Resources.Add($key, $fresh)
        }
    }
    $script:CurrentTheme = $Name
}

function Get-AppTheme { $script:CurrentTheme }

# ---- Helpers de recursos dinámicos --------------------------
# Enlazan una propiedad al recurso del tema, de modo que los
# controles creados por código también reaccionan al cambio.
function Set-TextFg  { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $Key) }
function Set-BoxBg   { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $Key) }
function Set-BoxLine { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $Key) }

function Get-Brush { param($Window, [string]$Key) $Window.FindResource($Key) }

# ---- Animación ----------------------------------------------
function New-Ease {
    param([string]$Mode = 'EaseOut', [double]$Amount = 3)
    $e = New-Object System.Windows.Media.Animation.CubicEase
    $e.EasingMode = $Mode
    $e
}

function New-Anim {
    param([double]$From, [double]$To, [int]$Ms = 180)
    $a = New-Object System.Windows.Media.Animation.DoubleAnimation
    $a.From = $From; $a.To = $To
    $a.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms))
    $a.EasingFunction = New-Ease
    $a
}

# Entrada de vista: desvanecido + leve deslizamiento hacia arriba.
function Start-EnterTransition {
    param($Element, [int]$Ms = 260, [double]$Slide = 14)

    $tt = New-Object System.Windows.Media.TranslateTransform
    $Element.RenderTransform = $tt
    $Element.Opacity = 0
    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim $Slide 0 $Ms))
    $Element.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Anim 0 1 $Ms))
}

# Elevación al pasar el ratón: sombra más marcada + 2px arriba.
function Add-HoverLift {
    param($Border, [double]$Lift = 2)

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 1
    $shadow.BlurRadius = 8;  $shadow.Opacity = 0.05
    $Border.Effect = $shadow

    $tt = New-Object System.Windows.Media.TranslateTransform
    $Border.RenderTransform = $tt

    $Border.Add_MouseEnter({
        param($s, $e)
        $s.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim 0 (-2) 160))
        $s.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-Anim 0.05 0.16 160))
        $s.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, (New-Anim 8 20 160))
    })
    $Border.Add_MouseLeave({
        param($s, $e)
        $s.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim (-2) 0 160))
        $s.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-Anim 0.16 0.05 160))
        $s.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, (New-Anim 20 8 160))
    })
}

# ---- fin incluido: ui/Theme.ps1 ----
# ---- inicio incluido: ui/UiKit.ps1 ----
# ============================================================
# UiKit.ps1
# Componentes visuales reutilizables construidos por código.
# Todos usan recursos dinámicos del tema (ver Theme.ps1), así
# que cambian de color solos al alternar claro/oscuro.
# ============================================================

$IconFont = New-Object System.Windows.Media.FontFamily 'Segoe Fluent Icons, Segoe MDL2 Assets'

function New-Icon {
    param([string]$Name, [double]$Size = 16, [string]$Fg = 'Text')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.FontFamily = $IconFont
    $t.Text = Glyph $Name
    $t.FontSize = $Size
    $t.VerticalAlignment = 'Center'
    $t.HorizontalAlignment = 'Center'
    Set-TextFg $t $Fg
    $t
}

# Cuadro redondeado con el icono de la categoría.
function New-IconTile {
    param([string]$Name, [string]$Fg = 'Accent', [string]$Bg = 'AccentSoft', [double]$Size = 42)
    $b = New-Object System.Windows.Controls.Border
    $b.Width = $Size; $b.Height = $Size
    $b.CornerRadius = New-Object System.Windows.CornerRadius 12
    $b.VerticalAlignment = 'Center'
    Set-BoxBg $b $Bg
    $b.Child = (New-Icon $Name ($Size * 0.44) $Fg)
    $b
}

# Píldora de estadística: icono + texto sobre fondo suave.
function New-Pill {
    param([string]$Icon, [string]$Text, [string]$Fg, [string]$Bg, [string]$Tip)
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 999
    $b.Padding = New-Object System.Windows.Thickness 9, 4, 11, 5
    $b.Margin = New-Object System.Windows.Thickness 6, 0, 0, 0
    $b.VerticalAlignment = 'Center'
    if ($Tip) { $b.ToolTip = $Tip }
    Set-BoxBg $b $Bg

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $ic = New-Icon $Icon 10.5 $Fg
    $ic.Margin = New-Object System.Windows.Thickness 0, 0, 5, 0
    $sp.Children.Add($ic) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = 11; $t.FontWeight = 'SemiBold'
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t $Fg
    $sp.Children.Add($t) | Out-Null

    $b.Child = $sp
    $b
}

# Etiqueta de clasificación (Preference / Recommended / ...).
function New-Tag {
    param([string]$Text)
    $map = @{
        'Preference'  = @{ Fg = 'Accent';    Bg = 'AccentSoft' }
        'Recommended' = @{ Fg = 'Success';   Bg = 'SuccessSoft' }
        'Default'     = @{ Fg = 'TextMuted'; Bg = 'SurfaceSunken' }
        'Custom'      = @{ Fg = 'Warn';      Bg = 'WarnSoft' }
    }
    $c = $map[$Text]
    if (-not $c) { $c = @{ Fg = 'TextMuted'; Bg = 'SurfaceSunken' } }

    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 6
    $b.Padding = New-Object System.Windows.Thickness 8, 2.5, 8, 3.5
    $b.Margin = New-Object System.Windows.Thickness 0, 0, 6, 0
    Set-BoxBg $b $c.Bg

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'
    Set-TextFg $t $c.Fg
    $b.Child = $t
    $b
}

# Distintivo rojo "NEW n".
function New-Badge {
    param([string]$Text)
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 999
    $b.Padding = New-Object System.Windows.Thickness 7, 1.5, 7, 2.5
    $b.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
    $b.VerticalAlignment = 'Center'
    Set-BoxBg $b 'Danger'

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = 9.5; $t.FontWeight = 'Bold'
    $t.Foreground = [System.Windows.Media.Brushes]::White
    $b.Child = $t
    $b
}

# ---- Interruptor animado ------------------------------------
# El estado vive en el Tag del propio control, nunca en un
# closure (ver la regla 4 de CLAUDE.md).
function New-ToggleSwitch {
    param($Window, [bool]$InitialState, $Label)

    $w = 40.0; $h = 22.0; $k = 16.0; $pad = 3.0
    $travel = $w - $k - ($pad * 2)
    $onColor  = ([System.Windows.Media.SolidColorBrush](Get-Brush $Window 'Accent')).Color
    $offColor = ([System.Windows.Media.SolidColorBrush](Get-Brush $Window 'TrackOff')).Color

    $track = New-Object System.Windows.Controls.Border
    $track.Width = $w; $track.Height = $h
    $track.CornerRadius = New-Object System.Windows.CornerRadius ($h / 2)
    $track.Cursor = 'Hand'
    $track.VerticalAlignment = 'Center'
    if ($InitialState) { $start = $onColor } else { $start = $offColor }
    $track.Background = New-Object System.Windows.Media.SolidColorBrush $start

    $knob = New-Object System.Windows.Controls.Border
    $knob.Width = $k; $knob.Height = $k
    $knob.CornerRadius = New-Object System.Windows.CornerRadius ($k / 2)
    $knob.HorizontalAlignment = 'Left'
    $knob.VerticalAlignment = 'Center'
    $knob.Margin = New-Object System.Windows.Thickness $pad, 0, 0, 0
    Set-BoxBg $knob 'Knob'

    $sh = New-Object System.Windows.Media.Effects.DropShadowEffect
    $sh.Color = [System.Windows.Media.Colors]::Black
    $sh.Direction = 270; $sh.ShadowDepth = 1; $sh.BlurRadius = 3; $sh.Opacity = 0.25
    $knob.Effect = $sh

    $tt = New-Object System.Windows.Media.TranslateTransform
    if ($InitialState) { $tt.X = $travel } else { $tt.X = 0 }
    $knob.RenderTransform = $tt
    $track.Child = $knob

    $track.Tag = [PSCustomObject]@{
        State = $InitialState; On = $onColor; Off = $offColor
        Travel = $travel; Label = $Label
    }

    $track.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        $new = -not $info.State
        $info.State = $new

        $ca = New-Object System.Windows.Media.Animation.ColorAnimation
        if ($new) { $ca.To = $info.On } else { $ca.To = $info.Off }
        $ca.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(170))
        $ca.EasingFunction = New-Ease
        $s.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty, $ca)

        if ($new) { $to = $info.Travel } else { $to = 0.0 }
        $s.Child.RenderTransform.BeginAnimation(
            [System.Windows.Media.TranslateTransform]::XProperty,
            (New-Anim $s.Child.RenderTransform.X $to 190))

        if ($info.Label) {
            if ($new) { $info.Label.Text = 'On' } else { $info.Label.Text = 'Off' }
        }
    })

    $track
}

# ---- Caja de búsqueda con icono y marcador de posición -------
function New-SearchBox {
    param($Window, [string]$Placeholder = 'Search optimizations...', [double]$Width = 260)

    $shell = New-Object System.Windows.Controls.Grid
    $shell.Width = $Width

    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Style = $Window.FindResource('SearchBoxStyle')
    $shell.Children.Add($tb) | Out-Null

    $ph = New-Object System.Windows.Controls.StackPanel
    $ph.Orientation = 'Horizontal'
    $ph.IsHitTestVisible = $false
    $ph.VerticalAlignment = 'Center'
    $ph.Margin = New-Object System.Windows.Thickness 13, 0, 0, 0

    $ic = New-Icon 'Search' 13 'TextFaint'
    $ic.Margin = New-Object System.Windows.Thickness 0, 0, 8, 0
    $ph.Children.Add($ic) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Placeholder; $t.FontSize = 12.5
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t 'TextFaint'
    $ph.Children.Add($t) | Out-Null

    $shell.Children.Add($ph) | Out-Null

    # El marcador se oculta en cuanto hay texto.
    $tb.Tag = $ph
    $tb.Add_TextChanged({
        param($s, $e)
        if ($s.Text.Length -gt 0) { $s.Tag.Visibility = 'Collapsed' } else { $s.Tag.Visibility = 'Visible' }
    })

    [PSCustomObject]@{ Root = $shell; Box = $tb }
}

# Botón secundario con icono opcional y chevron.
function New-ChipButton {
    param($Window, [string]$Text, [string]$Icon, [switch]$Chevron)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $Window.FindResource('ChipButtonStyle')

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    if ($Icon) {
        $ic = New-Icon $Icon 13 'TextMuted'
        $ic.Margin = New-Object System.Windows.Thickness 0, 0, 7, 0
        $sp.Children.Add($ic) | Out-Null
    }

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = 12.5; $t.FontWeight = 'SemiBold'
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t 'Text'
    $sp.Children.Add($t) | Out-Null

    if ($Chevron) {
        $cv = New-Icon 'ChevronDown' 10 'TextFaint'
        $cv.Margin = New-Object System.Windows.Thickness 7, 1, 0, 0
        $sp.Children.Add($cv) | Out-Null
    }

    $btn.Content = $sp
    $btn
}

# ---- fin incluido: ui/UiKit.ps1 ----
# ---- inicio incluido: ui/CategoryData.ps1 ----
# ============================================================
# CategoryData.ps1
# Datos de las categorías del menú principal y de sus ítems de
# detalle. Solo datos: la UI se construye en ui/Views/*.
# El icono de cada categoría NO vive aquí: lo asigna $CategoryLook
# en ui/Views/OptimizationsListView.ps1 (fuente Segoe Fluent Icons).
# ============================================================

function Get-OptimizationCategories {

    @(
        [PSCustomObject]@{
            Id = 'privacy'; Name = 'Privacy & Security'
            Badge = 'NEW 45'
            Description = 'Security, Content Delivery & Advertising, Lock Screen, General, ...'
            Recommended = 29; Default = 59; Custom = 0; Total = 88
            Items = @(
                [PSCustomObject]@{ Name='User Account Control Level'; Description='Controls UAC notification level and secure desktop behavior'; Tags=@('Preference','Recommended','Default','Custom'); Type='Dropdown'; Options=@('Always notify','Notify when apps try to make changes','Notify me only (no dim)','Never notify'); Value='Notify when apps try to make changes' }
                [PSCustomObject]@{ Name='Workplace Join Message Prompts'; Description="Show 'Allow my organization to manage my device' prompts throughout Windows"; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='BitLocker Auto Encryption'; Description='Controls whether Windows can automatically encrypt drives with BitLocker. Has no effect if BitLocker encryption is already active on your device'; Tags=@('Preference','Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='WiFi-Sense'; Description='Allow sharing WiFi passwords with contacts and automatically connecting to suggested open hotspots'; Tags=@('Recommended','Custom'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='Automatic Maintenance'; Description='Choose if Windows should run automatic system maintenance tasks during idle time'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Windows Error Reporting'; Description='Choose if Windows should collect and send crash reports and error information to Microsoft'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
            )
        }
        [PSCustomObject]@{
            Id = 'power'; Name = 'Power'
            Badge = $null
            Description = 'Display, Hard Disk, Internet Explorer, Desktop Background Settings, ...'
            Recommended = 18; Default = 23; Custom = 2; Total = 34
            Items = @(
                [PSCustomObject]@{ Name='High Performance Power Plan'; Description='Switch to the High Performance / Ultimate Performance power scheme'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='USB Selective Suspend'; Description='Allow Windows to power down idle USB devices to save energy'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Hibernation'; Description='Enable or disable hibernate mode and the hiberfil.sys reserved space'; Tags=@('Preference','Default'); Type='Toggle'; Value=$true }
            )
        }
        [PSCustomObject]@{
            Id = 'gaming'; Name = 'Gaming & Performance'
            Badge = 'NEW 16'
            Description = 'Processor, Graphics, Network, Security, ...'
            Recommended = 65; Default = 47; Custom = 2; Total = 112
            Items = @(
                [PSCustomObject]@{ Name='Game Mode'; Description='Optimize your PC for play by turning things off in the background'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='Enhance Pointer Precision'; Description='Adjust cursor speed based on movement velocity (mouse acceleration). Most competitive gamers disable this for consistent aiming in FPS games'; Tags=@('Preference','Recommended'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Mouse Hover Time'; Description='Controls how long you must hover over an element before it activates (in milliseconds). Lower values make tooltips, menus, and hover effects appear faster. Default is 400ms'; Tags=@('Preference','Recommended','Default','Custom'); Type='Dropdown'; Options=@('100ms','200ms','400ms (Default)','600ms'); Value='400ms (Default)'; Badge='NEW' }
                [PSCustomObject]@{ Name='Startup Delay for Apps'; Description='Delay startup applications by 10 seconds after boot to improve initial system responsiveness. Windows becomes usable faster, but your startup apps take longer to load'; Tags=@('Preference','Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Background App Permissions'; Description='Control whether apps can run in the background via Group Policy. Force Deny removes per-app background settings from Windows Settings. Use User in Control if you need apps like Teams, Zoom, or WhatsApp'; Tags=@('Preference','Recommended','Default','Custom'); Type='Dropdown'; Options=@('User in Control','Force Allow','Force Deny'); Value='Force Deny'; Badge='NEW' }
            )
        }
        [PSCustomObject]@{
            Id = 'update'; Name = 'Update'
            Badge = 'NEW 1'
            Description = 'Update Policy, Delivery & Store, Update Behavior'
            Recommended = 5; Default = 8; Custom = 1; Total = 12
            Items = @(
                [PSCustomObject]@{ Name='Delivery Optimization (P2P)'; Description='Allow Windows to download/upload updates to and from other PCs on the internet'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Auto-Restart With Active Sessions'; Description='Allow Windows Update to restart the PC automatically while you are logged in'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
            )
        }
        [PSCustomObject]@{
            Id = 'notifications'; Name = 'Notifications'
            Badge = $null
            Description = 'Additional Settings, System Notifications, Privacy Notifications, Security Notifications'
            Recommended = 7; Default = 9; Custom = 0; Total = 15
            Items = @(
                [PSCustomObject]@{ Name='Windows Tips & Suggestions'; Description='Show occasional tips, tricks, and suggestions as you use Windows'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Lock Screen Suggestions'; Description='Show fun facts, tips, and other suggestions on the lock screen'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
            )
        }
        [PSCustomObject]@{
            Id = 'sound'; Name = 'Sound'
            Badge = $null
            Description = 'System Sounds'
            Recommended = 0; Default = 7; Custom = 0; Total = 7
            Items = @(
                [PSCustomObject]@{ Name='Startup Sound'; Description='Play the Windows startup sound when signing in'; Tags=@('Default'); Type='Toggle'; Value=$true }
            )
        }
    )
}

# ---- fin incluido: ui/CategoryData.ps1 ----
# ---- inicio incluido: ui/Views/OptimizationsListView.ps1 ----
# ============================================================
# OptimizationsListView.ps1
# Pantalla principal: tarjetas de categoría con icono, badge,
# estadísticas y elevación al pasar el ratón.
# ============================================================

# Icono y color de acento por categoría.
$CategoryLook = @{
    privacy       = @{ Icon = 'Shield'; Fg = 'Accent';  Bg = 'AccentSoft' }
    power         = @{ Icon = 'Power';  Fg = 'Success'; Bg = 'SuccessSoft' }
    gaming        = @{ Icon = 'Game';   Fg = 'Warn';    Bg = 'WarnSoft' }
    update        = @{ Icon = 'Sync';   Fg = 'Accent';  Bg = 'AccentSoft' }
    notifications = @{ Icon = 'Bell';   Fg = 'Warn';    Bg = 'WarnSoft' }
    sound         = @{ Icon = 'Volume'; Fg = 'Success'; Bg = 'SuccessSoft' }
}

function New-CategoryCard {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 18, 15, 20, 15
    $card.Cursor = 'Hand'
    Add-HoverLift $card

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($width in @('Auto', '*', 'Auto', 'Auto')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = [System.Windows.GridLength]::new(1, $(if ($width -eq '*') { 'Star' } else { 'Auto' }))
        $grid.ColumnDefinitions.Add($cd)
    }

    # --- icono ---
    $look = $CategoryLook[$Category.Id]
    if (-not $look) { $look = @{ Icon = 'Sliders'; Fg = 'Accent'; Bg = 'AccentSoft' } }
    $tile = New-IconTile $look.Icon $look.Fg $look.Bg 44
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 16, 0
    [System.Windows.Controls.Grid]::SetColumn($tile, 0)
    $grid.Children.Add($tile) | Out-Null

    # --- nombre, badge y descripción ---
    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 14.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    if ($Category.Badge) { $nameRow.Children.Add((New-Badge $Category.Badge)) | Out-Null }
    $text.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Category.Description
    $desc.FontSize = 12
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 4, 24, 0
    Set-TextFg $desc 'TextMuted'
    $text.Children.Add($desc) | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    $grid.Children.Add($text) | Out-Null

    # --- píldoras de estadísticas ---
    $stats = New-Object System.Windows.Controls.StackPanel
    $stats.Orientation = 'Horizontal'
    $stats.VerticalAlignment = 'Center'

    $total = $Category.Total
    if ($Category.Recommended -gt 0) {
        $stats.Children.Add((New-Pill 'StarFill' "$($Category.Recommended)/$total" 'Success' 'SuccessSoft' "Recommended: $($Category.Recommended) de $total")) | Out-Null
    } else {
        $stats.Children.Add((New-Pill 'Star' "0/$total" 'TextFaint' 'SurfaceSunken' 'Sin ajustes recomendados')) | Out-Null
    }
    $stats.Children.Add((New-Pill 'Grid' "$($Category.Default)/$total" 'TextMuted' 'SurfaceSunken' "Default: $($Category.Default) de $total")) | Out-Null
    if ($Category.Custom -gt 0) {
        $stats.Children.Add((New-Pill 'Sliders' "$($Category.Custom)/$total" 'Warn' 'WarnSoft' "Custom: $($Category.Custom) de $total")) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetColumn($stats, 2)
    $grid.Children.Add($stats) | Out-Null

    # --- chevron ---
    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 16, 0, 2, 0
    [System.Windows.Controls.Grid]::SetColumn($chev, 3)
    $grid.Children.Add($chev) | Out-Null

    $card.Child = $grid

    # La categoría viaja en el Tag: nada de closures (regla 4 de CLAUDE.md).
    $card.Tag = $Category
    $card.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-CategoryDetailView -Window ([System.Windows.Window]::GetWindow($s)) -Category $s.Tag
    })

    $card
}

function Show-OptimizationsListView {
    param($Window)

    $categories  = Get-OptimizationCategories
    $titleArea   = $Window.FindName('HeaderTitleArea')
    $actionsArea = $Window.FindName('HeaderActionsArea')
    $mainContent = $Window.FindName('MainContent')

    # ---- Cabecera: título + subtítulo ----
    $titleArea.Children.Clear()
    $stack = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'Optimizations'
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 27
    $title.FontWeight = 'Bold'
    Set-TextFg $title 'Text'
    $stack.Children.Add($title) | Out-Null

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text = 'Optimize your Windows system performance, privacy and power usage'
    $sub.FontSize = 12.5
    $sub.Margin = New-Object System.Windows.Thickness 0, 3, 0, 0
    Set-TextFg $sub 'TextMuted'
    $stack.Children.Add($sub) | Out-Null

    $titleArea.Children.Add($stack) | Out-Null

    # ---- Cabecera: acciones ----
    $actionsArea.Children.Clear()
    $search = New-SearchBox $Window
    $actionsArea.Children.Add($search.Root) | Out-Null
    $actionsArea.Children.Add((New-ChipButton $Window 'Quick Actions' 'Bolt' -Chevron)) | Out-Null
    $actionsArea.Children.Add((New-ChipButton $Window 'View' 'Filter' -Chevron)) | Out-Null

    # ---- Contenido ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($cat in $categories) {
        $list.Children.Add((New-CategoryCard -Window $Window -Category $cat)) | Out-Null
    }

    $mainContent.Content = $list
    Start-EnterTransition $list
}

# ---- fin incluido: ui/Views/OptimizationsListView.ps1 ----
# ---- inicio incluido: ui/Views/CategoryDetailView.ps1 ----
# ============================================================
# CategoryDetailView.ps1
# Pantalla de detalle: breadcrumb + tarjetas de cada ítem con
# etiquetas, interruptor animado o desplegable.
# ============================================================

function New-ItemCard {
    param($Window, $Item)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')
    $card.Padding = New-Object System.Windows.Thickness 20, 15, 20, 16

    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::new(1, 'Star')
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c1)
    $grid.ColumnDefinitions.Add($c2)

    # ---- izquierda: nombre, descripción, etiquetas ----
    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Item.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 13.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    if ($Item.Badge) { $nameRow.Children.Add((New-Badge $Item.Badge)) | Out-Null }
    $left.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $Item.Description
    $desc.FontSize = 11.5
    $desc.TextWrapping = 'Wrap'
    $desc.LineHeight = 17
    $desc.Margin = New-Object System.Windows.Thickness 0, 5, 30, 9
    Set-TextFg $desc 'TextMuted'
    $left.Children.Add($desc) | Out-Null

    $tags = New-Object System.Windows.Controls.StackPanel
    $tags.Orientation = 'Horizontal'
    foreach ($tag in $Item.Tags) { $tags.Children.Add((New-Tag $tag)) | Out-Null }
    $left.Children.Add($tags) | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($left, 0)
    $grid.Children.Add($left) | Out-Null

    # ---- derecha: indicadores + control ----
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'

    if ($Item.Tags -contains 'Recommended') {
        $star = New-Icon 'StarFill' 13 'Success'
        $star.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        $right.Children.Add($star) | Out-Null
    }
    if ($Item.Tags -contains 'Default') {
        $gr = New-Icon 'Grid' 13 'TextFaint'
        $gr.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
        $right.Children.Add($gr) | Out-Null
    }

    if ($Item.Type -eq 'Toggle') {
        $state = New-Object System.Windows.Controls.TextBlock
        if ($Item.Value) { $state.Text = 'On' } else { $state.Text = 'Off' }
        $state.FontSize = 11.5
        $state.FontWeight = 'SemiBold'
        $state.Width = 24
        $state.TextAlignment = 'Right'
        $state.VerticalAlignment = 'Center'
        $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        Set-TextFg $state 'TextMuted'
        $right.Children.Add($state) | Out-Null
        $right.Children.Add((New-ToggleSwitch -Window $Window -InitialState $Item.Value -Label $state)) | Out-Null
    }
    elseif ($Item.Type -eq 'Dropdown') {
        $combo = New-Object System.Windows.Controls.ComboBox
        $combo.Style = $Window.FindResource('ModernComboStyle')
        $combo.Width = 262
        foreach ($opt in $Item.Options) { $combo.Items.Add($opt) | Out-Null }
        $combo.SelectedItem = $Item.Value
        $right.Children.Add($combo) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    $grid.Children.Add($right) | Out-Null

    $card.Child = $grid
    $card
}

function Show-CategoryDetailView {
    param($Window, $Category)

    $titleArea   = $Window.FindName('HeaderTitleArea')
    $actionsArea = $Window.FindName('HeaderActionsArea')
    $mainContent = $Window.FindName('MainContent')

    # ---- Breadcrumb ----
    $titleArea.Children.Clear()
    $crumb = New-Object System.Windows.Controls.StackPanel
    $crumb.Orientation = 'Horizontal'

    $back = New-Object System.Windows.Controls.Border
    $back.CornerRadius = New-Object System.Windows.CornerRadius 9
    $back.Width = 34; $back.Height = 34
    $back.Cursor = 'Hand'
    $back.BorderThickness = New-Object System.Windows.Thickness 1
    $back.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
    $back.VerticalAlignment = 'Center'
    Set-BoxBg $back 'Surface'
    Set-BoxLine $back 'Stroke'
    $back.Child = (New-Icon 'Back' 13 'TextMuted')
    $back.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-OptimizationsListView -Window ([System.Windows.Window]::GetWindow($s))
    })
    $crumb.Children.Add($back) | Out-Null

    $look = $CategoryLook[$Category.Id]
    if (-not $look) { $look = @{ Icon = 'Sliders'; Fg = 'Accent'; Bg = 'AccentSoft' } }
    $tile = New-IconTile $look.Icon $look.Fg $look.Bg 38
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 13, 0
    $crumb.Children.Add($tile) | Out-Null

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $trail = New-Object System.Windows.Controls.StackPanel
    $trail.Orientation = 'Horizontal'
    $root = New-Object System.Windows.Controls.TextBlock
    $root.Text = 'Optimizations'
    $root.FontSize = 11
    $root.Cursor = 'Hand'
    Set-TextFg $root 'TextFaint'
    $root.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-OptimizationsListView -Window ([System.Windows.Window]::GetWindow($s))
    })
    $trail.Children.Add($root) | Out-Null
    $sep = New-Icon 'ChevronRight' 8 'TextFaint'
    $sep.Margin = New-Object System.Windows.Thickness 6, 1, 6, 0
    $trail.Children.Add($sep) | Out-Null
    $leaf = New-Object System.Windows.Controls.TextBlock
    $leaf.Text = $Category.Name
    $leaf.FontSize = 11
    Set-TextFg $leaf 'TextMuted'
    $trail.Children.Add($leaf) | Out-Null
    $texts.Children.Add($trail) | Out-Null

    $curr = New-Object System.Windows.Controls.TextBlock
    $curr.Text = $Category.Name
    $curr.FontFamily = $Window.FindResource('DisplayFont')
    $curr.FontSize = 21
    $curr.FontWeight = 'Bold'
    $curr.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
    Set-TextFg $curr 'Text'
    $texts.Children.Add($curr) | Out-Null

    $crumb.Children.Add($texts) | Out-Null
    $titleArea.Children.Add($crumb) | Out-Null

    # ---- Acciones ----
    $actionsArea.Children.Clear()
    $count = New-Object System.Windows.Controls.TextBlock
    $count.Text = "$($Category.Items.Count) settings"
    $count.FontSize = 12
    $count.VerticalAlignment = 'Center'
    $count.Margin = New-Object System.Windows.Thickness 0, 0, 4, 0
    Set-TextFg $count 'TextFaint'
    $actionsArea.Children.Add($count) | Out-Null
    $actionsArea.Children.Add((New-ChipButton $Window 'Reset' 'Sync')) | Out-Null

    # ---- Lista de ítems ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($item in $Category.Items) {
        $list.Children.Add((New-ItemCard -Window $Window -Item $item)) | Out-Null
    }

    $mainContent.Content = $list
    Start-EnterTransition $list
}

# ---- fin incluido: ui/Views/CategoryDetailView.ps1 ----

$xamlString = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Optimizador PC" Height="780" Width="1320" MinHeight="560" MinWidth="960"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None" ResizeMode="CanResize"
        TextOptions.TextFormattingMode="Ideal"
        TextOptions.TextRenderingMode="ClearType"
        UseLayoutRounding="True" SnapsToDevicePixels="True"
        RenderOptions.ClearTypeHint="Enabled"
        Background="{DynamicResource Bg0}"
        FontFamily="Segoe UI Variable Text, Segoe UI">

    <!-- Bordes de redimension nativos + esquinas redondeadas de Windows 11 -->
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6"
                            GlassFrameThickness="0" CornerRadius="0"
                            UseAeroCaptionButtons="False"/>
    </shell:WindowChrome.WindowChrome>

    <Window.Resources>

        <!-- ================= PALETA (claro por defecto) =================
             Theme.ps1 sobrescribe estas claves en tiempo de ejecucion, por
             eso todo el XAML las consume con DynamicResource. -->
        <SolidColorBrush x:Key="Bg0"           Color="#F2F4F7"/>
        <SolidColorBrush x:Key="Bg1"           Color="#FFFFFF"/>
        <SolidColorBrush x:Key="Bg2"           Color="#F7F9FC"/>
        <SolidColorBrush x:Key="Surface"       Color="#FFFFFF"/>
        <SolidColorBrush x:Key="SurfaceHover"  Color="#FAFBFD"/>
        <SolidColorBrush x:Key="SurfaceSunken" Color="#F0F2F6"/>
        <SolidColorBrush x:Key="Stroke"        Color="#E6E9EF"/>
        <SolidColorBrush x:Key="StrokeHover"   Color="#CFD6E2"/>
        <SolidColorBrush x:Key="StrokeFocus"   Color="#2563EB"/>
        <SolidColorBrush x:Key="Text"          Color="#15181E"/>
        <SolidColorBrush x:Key="TextMuted"     Color="#59616F"/>
        <SolidColorBrush x:Key="TextFaint"     Color="#8B93A2"/>
        <SolidColorBrush x:Key="Accent"        Color="#2563EB"/>
        <SolidColorBrush x:Key="AccentHover"   Color="#1D4FD8"/>
        <SolidColorBrush x:Key="AccentSoft"    Color="#E9F0FE"/>
        <SolidColorBrush x:Key="AccentText"    Color="#FFFFFF"/>
        <SolidColorBrush x:Key="Success"       Color="#0E9F6E"/>
        <SolidColorBrush x:Key="SuccessSoft"   Color="#E6F7F0"/>
        <SolidColorBrush x:Key="Warn"          Color="#C2680A"/>
        <SolidColorBrush x:Key="WarnSoft"      Color="#FDF3E5"/>
        <SolidColorBrush x:Key="Danger"        Color="#E11D48"/>
        <SolidColorBrush x:Key="DangerSoft"    Color="#FDEAEF"/>
        <SolidColorBrush x:Key="TrackOff"      Color="#CBD2DE"/>
        <SolidColorBrush x:Key="Knob"          Color="#FFFFFF"/>
        <SolidColorBrush x:Key="ScrollThumb"   Color="#C6CDDA"/>
        <SolidColorBrush x:Key="Overlay"       Color="#0B1220"/>

        <FontFamily x:Key="IconFont">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
        <FontFamily x:Key="DisplayFont">Segoe UI Variable Display, Segoe UI</FontFamily>
        <FontFamily x:Key="BodyFont">Segoe UI Variable Text, Segoe UI</FontFamily>

        <!-- ================= BARRA DE DESPLAZAMIENTO FINA ================= -->
        <Style x:Key="ScrollThumbStyle" TargetType="Thumb">
            <Setter Property="IsTabStop" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border x:Name="bd" Width="6" HorizontalAlignment="Center"
                                CornerRadius="3" Background="{DynamicResource ScrollThumb}"
                                Opacity="0.75"/>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Width" Value="8"/>
                                <Setter TargetName="bd" Property="Opacity" Value="1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="InvisibleRepeat" TargetType="RepeatButton">
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="IsTabStop" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RepeatButton">
                        <Border Background="Transparent"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="12"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Style="{StaticResource InvisibleRepeat}"
                                                  Command="ScrollBar.PageUpCommand"/>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb Style="{StaticResource ScrollThumbStyle}"/>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Style="{StaticResource InvisibleRepeat}"
                                                  Command="ScrollBar.PageDownCommand"/>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= BOTONES DEL CROMO ================= -->
        <Style x:Key="WinButtonStyle" TargetType="Button">
            <Setter Property="Width" Value="46"/>
            <Setter Property="Height" Value="46"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMuted}"/>
            <Setter Property="FontFamily" Value="{StaticResource IconFont}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="Transparent">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource SurfaceSunken}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Text}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="WinCloseStyle" TargetType="Button" BasedOn="{StaticResource WinButtonStyle}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="Transparent">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#E81123"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Boton de icono redondeado (acciones del titulo) -->
        <Style x:Key="GlyphButtonStyle" TargetType="Button">
            <Setter Property="Width" Value="34"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Margin" Value="2,0,2,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMuted}"/>
            <Setter Property="FontFamily" Value="{StaticResource IconFont}"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="Transparent" CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource SurfaceSunken}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Accent}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= SELECTOR DE MODO ================= -->
        <Style x:Key="ModeButtonStyle" TargetType="Button">
            <Setter Property="Padding" Value="14,5,14,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMuted}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="Transparent" CornerRadius="7"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="{DynamicResource Text}"/>
                            </Trigger>
                            <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Tag}" Value="sel">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource Surface}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Text}"/>
                                <Setter TargetName="bd" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="Black" Direction="270" ShadowDepth="1"
                                                          BlurRadius="4" Opacity="0.14"/>
                                    </Setter.Value>
                                </Setter>
                            </DataTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= NAVEGACION LATERAL ================= -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid Margin="10,3,10,3">
                            <Border x:Name="bd" CornerRadius="12" Background="Transparent" Padding="0,11,0,10">
                                <ContentPresenter/>
                            </Border>
                            <!-- indicador de seleccion -->
                            <Border x:Name="ind" Width="3" Height="20" CornerRadius="2"
                                    HorizontalAlignment="Left" VerticalAlignment="Center"
                                    Margin="-10,0,0,0" Background="{DynamicResource Accent}"
                                    Opacity="0"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource SurfaceSunken}"/>
                            </Trigger>
                            <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Tag}" Value="sel">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource AccentSoft}"/>
                                <Setter TargetName="ind" Property="Opacity" Value="1"/>
                            </DataTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= BOTON SECUNDARIO (chip) ================= -->
        <Style x:Key="ChipButtonStyle" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Margin" Value="8,0,0,0"/>
            <Setter Property="Height" Value="38"/>
            <Setter Property="Padding" Value="14,0,14,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" CornerRadius="10"
                                Background="{DynamicResource Surface}"
                                BorderBrush="{DynamicResource Stroke}" BorderThickness="1"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource SurfaceHover}"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource StrokeHover}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= CAJA DE BUSQUEDA ================= -->
        <Style x:Key="SearchBoxStyle" TargetType="TextBox">
            <Setter Property="Height" Value="38"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Foreground" Value="{DynamicResource Text}"/>
            <Setter Property="CaretBrush" Value="{DynamicResource Accent}"/>
            <Setter Property="SelectionBrush" Value="{DynamicResource Accent}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="bd" CornerRadius="10"
                                Background="{DynamicResource Surface}"
                                BorderBrush="{DynamicResource Stroke}" BorderThickness="1"
                                Padding="34,0,12,0">
                            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource StrokeHover}"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource StrokeFocus}"/>
                                <Setter TargetName="bd" Property="BorderThickness" Value="1.6"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= DESPLEGABLE ================= -->
        <Style x:Key="ComboItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Padding" Value="10,7,10,7"/>
            <Setter Property="Foreground" Value="{DynamicResource Text}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="bd" Background="Transparent" CornerRadius="7" Margin="4,1,4,1"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource SurfaceSunken}"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource AccentSoft}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Accent}"/>
                                <Setter Property="FontWeight" Value="SemiBold"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernComboStyle" TargetType="ComboBox">
            <Setter Property="Height" Value="36"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="{DynamicResource Text}"/>
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboItemStyle}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="tgl" Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border x:Name="bd" CornerRadius="10"
                                                Background="{DynamicResource Surface}"
                                                BorderBrush="{DynamicResource Stroke}" BorderThickness="1">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="30"/>
                                                </Grid.ColumnDefinitions>
                                                <ContentPresenter Grid.Column="0" Margin="13,0,0,0"
                                                                  VerticalAlignment="Center"
                                                                  Content="{Binding SelectionBoxItem, RelativeSource={RelativeSource AncestorType=ComboBox}}"/>
                                                <TextBlock Grid.Column="1" Text="&#xE70D;"
                                                           FontFamily="{StaticResource IconFont}" FontSize="9"
                                                           Foreground="{DynamicResource TextFaint}"
                                                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource StrokeHover}"/>
                                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource SurfaceHover}"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource StrokeFocus}"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>

                            <Popup x:Name="PART_Popup" Placement="Bottom" VerticalOffset="6"
                                   AllowsTransparency="True" Focusable="False"
                                   IsOpen="{TemplateBinding IsDropDownOpen}"
                                   PopupAnimation="Fade">
                                <Border Background="{DynamicResource Surface}" CornerRadius="12"
                                        BorderBrush="{DynamicResource Stroke}" BorderThickness="1"
                                        MinWidth="{TemplateBinding ActualWidth}" Margin="6,0,6,8"
                                        Padding="0,5,0,5">
                                    <Border.Effect>
                                        <DropShadowEffect Color="Black" Direction="270" ShadowDepth="3"
                                                          BlurRadius="18" Opacity="0.18"/>
                                    </Border.Effect>
                                    <ScrollViewer MaxHeight="260">
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ================= TARJETAS ================= -->
        <Style x:Key="CardStyle" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource Surface}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Stroke}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="BorderBrush" Value="{DynamicResource StrokeHover}"/>
                    <Setter Property="Background" Value="{DynamicResource SurfaceHover}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="StaticCardStyle" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource Surface}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Stroke}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="BorderBrush" Value="{DynamicResource StrokeHover}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- ================= TOOLTIP ================= -->
        <Style TargetType="ToolTip">
            <Setter Property="Foreground" Value="{DynamicResource Text}"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="{DynamicResource Surface}"
                                BorderBrush="{DynamicResource Stroke}" BorderThickness="1"
                                CornerRadius="8" Padding="10,6,10,7">
                            <Border.Effect>
                                <DropShadowEffect Color="Black" Direction="270" ShadowDepth="2"
                                                  BlurRadius="12" Opacity="0.16"/>
                            </Border.Effect>
                            <ContentPresenter/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>

    <Border BorderBrush="{DynamicResource Stroke}" BorderThickness="1" Background="{DynamicResource Bg0}">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="46"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- ===== BARRA DE TITULO ===== -->
            <Grid x:Name="TitleBar" Grid.Row="0" Background="{DynamicResource Bg1}">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- marca -->
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                    <Border Width="26" Height="26" CornerRadius="8">
                        <Border.Background>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                <GradientStop Color="#3B82F6" Offset="0"/>
                                <GradientStop Color="#1D4ED8" Offset="1"/>
                            </LinearGradientBrush>
                        </Border.Background>
                        <TextBlock Text="&#xE945;" FontFamily="{StaticResource IconFont}" FontSize="13"
                                   Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Optimizador PC" FontFamily="{StaticResource DisplayFont}"
                               FontWeight="SemiBold" FontSize="13.5" VerticalAlignment="Center"
                               Margin="10,0,0,0" Foreground="{DynamicResource Text}"/>
                    <Border CornerRadius="6" Padding="6,1,6,2" Margin="10,1,0,0" VerticalAlignment="Center"
                            Background="{DynamicResource SurfaceSunken}">
                        <TextBlock Text="v1.0" FontSize="10" FontWeight="SemiBold"
                                   Foreground="{DynamicResource TextFaint}"/>
                    </Border>
                </StackPanel>

                <!-- selector de modo -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <Border Background="{DynamicResource SurfaceSunken}" CornerRadius="9" Padding="3">
                        <StackPanel Orientation="Horizontal">
                            <Button x:Name="BtnModeNormal"  Style="{StaticResource ModeButtonStyle}" Tag="sel" Content="Normal"/>
                            <Button x:Name="BtnModeBuilder" Style="{StaticResource ModeButtonStyle}" Content="Builder"/>
                            <Button x:Name="BtnModeConfig"  Style="{StaticResource ModeButtonStyle}" Content="Config Review"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <!-- acciones -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,10,0">
                    <Button x:Name="BtnTheme" Style="{StaticResource GlyphButtonStyle}" Content="&#xE708;" ToolTip="Cambiar tema"/>
                    <Button x:Name="BtnHelp"  Style="{StaticResource GlyphButtonStyle}" Content="&#xE897;" ToolTip="Ayuda"/>
                </StackPanel>

                <!-- cromo de ventana -->
                <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Stretch">
                    <Button x:Name="BtnMinimize" Style="{StaticResource WinButtonStyle}" Content="&#xE921;"/>
                    <Button x:Name="BtnMaximize" Style="{StaticResource WinButtonStyle}" Content="&#xE922;"/>
                    <Button x:Name="BtnClose"    Style="{StaticResource WinCloseStyle}"  Content="&#xE8BB;"/>
                </StackPanel>
            </Grid>

            <!-- ===== CABECERA DE CONTENIDO ===== -->
            <Border Grid.Row="1" Background="{DynamicResource Bg0}">
                <Grid Margin="30,18,30,16">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel x:Name="HeaderTitleArea" Grid.Column="0" VerticalAlignment="Center" Orientation="Horizontal"/>
                    <StackPanel x:Name="HeaderActionsArea" Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"/>
                </Grid>
            </Border>

            <!-- ===== CUERPO: navegacion + contenido ===== -->
            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="88"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- NAVEGACION LATERAL -->
                <Border Grid.Column="0" Background="{DynamicResource Bg1}"
                        BorderBrush="{DynamicResource Stroke}" BorderThickness="0,1,1,0"
                        CornerRadius="0,16,0,0">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,14,0,0">
                            <Button x:Name="NavSoftware" Style="{StaticResource NavButtonStyle}">
                                <StackPanel>
                                    <TextBlock Text="&#xF0E2;" FontFamily="{StaticResource IconFont}" FontSize="19"
                                               HorizontalAlignment="Center" Foreground="{DynamicResource TextMuted}"/>
                                    <TextBlock Text="Software" FontSize="9.5" HorizontalAlignment="Center"
                                               Margin="0,5,0,0" Foreground="{DynamicResource TextMuted}"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="NavOptimize" Style="{StaticResource NavButtonStyle}" Tag="sel">
                                <StackPanel>
                                    <TextBlock Text="&#xEC4A;" FontFamily="{StaticResource IconFont}" FontSize="19"
                                               HorizontalAlignment="Center" Foreground="{DynamicResource Accent}"/>
                                    <TextBlock Text="Optimize" FontSize="9.5" FontWeight="SemiBold" HorizontalAlignment="Center"
                                               Margin="0,5,0,0" Foreground="{DynamicResource Accent}"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="NavCustomize" Style="{StaticResource NavButtonStyle}">
                                <StackPanel>
                                    <TextBlock Text="&#xE790;" FontFamily="{StaticResource IconFont}" FontSize="19"
                                               HorizontalAlignment="Center" Foreground="{DynamicResource TextMuted}"/>
                                    <TextBlock Text="Customize" FontSize="9.5" HorizontalAlignment="Center"
                                               Margin="0,5,0,0" Foreground="{DynamicResource TextMuted}"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>

                        <StackPanel Grid.Row="1" Margin="0,0,0,16">
                            <Border Height="1" Background="{DynamicResource Stroke}" Margin="18,0,18,10"/>
                            <Button x:Name="NavAdvanced" Style="{StaticResource NavButtonStyle}">
                                <StackPanel>
                                    <TextBlock Text="&#xE90F;" FontFamily="{StaticResource IconFont}" FontSize="17"
                                               HorizontalAlignment="Center" Foreground="{DynamicResource TextMuted}"/>
                                    <TextBlock Text="Advanced" FontSize="9" HorizontalAlignment="Center"
                                               Margin="0,5,0,0" Foreground="{DynamicResource TextMuted}"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="NavSettings" Style="{StaticResource NavButtonStyle}">
                                <StackPanel>
                                    <TextBlock Text="&#xE713;" FontFamily="{StaticResource IconFont}" FontSize="17"
                                               HorizontalAlignment="Center" Foreground="{DynamicResource TextMuted}"/>
                                    <TextBlock Text="Settings" FontSize="9" HorizontalAlignment="Center"
                                               Margin="0,5,0,0" Foreground="{DynamicResource TextMuted}"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="NavMore" Style="{StaticResource NavButtonStyle}">
                                <StackPanel>
                                    <TextBlock Text="&#xE712;" FontFamily="{StaticResource IconFont}" FontSize="17"
                                               HorizontalAlignment="Center" Foreground="{DynamicResource TextMuted}"/>
                                    <TextBlock Text="More" FontSize="9" HorizontalAlignment="Center"
                                               Margin="0,5,0,0" Foreground="{DynamicResource TextMuted}"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- CONTENIDO PRINCIPAL -->
                <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" Padding="30,2,22,26">
                    <ContentControl x:Name="MainContent"/>
                </ScrollViewer>
            </Grid>
        </Grid>
    </Border>
</Window>

'@
[xml]$xamlXml = $xamlString

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
