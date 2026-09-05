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
# ---- inicio incluido: ui/Design/Theme.ps1 ----
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
    Info = 0xE946; Bulb = 0xEA80; Lock = 0xE72E; Apps = 0xF0E2
    ChevronUp = 0xE70E; OpenIn = 0xE8A7; Person = 0xE77B
    Dock = 0xE73F; Copy = 0xE8C8
    # registro de actividad (ui/Components/Shell/LogPanel.ps1)
    Pulse = 0xE9D9; Trash = 0xE74D; Save = 0xE74E; Alert = 0xE783
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

# La Background de una ventana o de un control con plantilla NO es
# la del Border: son propiedades distintas y con la de Border no
# pasa nada. Lo usa la ventana aparte del registro de actividad.
function Set-WinBg { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, $Key) }

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
#
# Quien escucha al ratón NO es la tarjeta, sino un envoltorio
# transparente que ocupa su hueco y no se mueve nunca. En WPF el
# RenderTransform arrastra consigo la zona sensible al ratón: si
# escuchara la propia tarjeta, con el cursor parado sobre sus últimos
# píxeles subirla lo dejaría fuera (MouseLeave), bajarla lo volvería a
# meter dentro (MouseEnter) y el efecto no pararía jamás.
#
# Devuelve el envoltorio: es lo que hay que colgar del panel, y es
# también donde van el cursor y el clic, para que respondan en todo el
# rectángulo de la tarjeta -incluida la franja que deja libre al subir-.
function Add-HoverLift {
    param($Border)

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 1
    $shadow.BlurRadius = 8;  $shadow.Opacity = 0.05
    $Border.Effect = $shadow

    $Border.RenderTransform = New-Object System.Windows.Media.TranslateTransform

    # El margen se muda al envoltorio: así su área transparente es
    # exactamente la de la tarjeta y el hueco entre tarjetas sigue
    # siendo hueco, ni se ilumina ni se puede pulsar.
    $slot = New-Object System.Windows.Controls.Grid
    $slot.Background = [System.Windows.Media.Brushes]::Transparent
    $slot.Margin = $Border.Margin
    $Border.Margin = New-Object System.Windows.Thickness 0
    $slot.Children.Add($Border) | Out-Null

    # Nada de closures (regla 4): la tarjeta es el único hijo del
    # envoltorio, así que el manejador la saca del emisor.
    $slot.Add_MouseEnter({
        param($s, $e)
        $card = $s.Children[0]
        $card.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim 0 (-2) 160))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-Anim 0.05 0.16 160))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, (New-Anim 8 20 160))
    })
    $slot.Add_MouseLeave({
        param($s, $e)
        $card = $s.Children[0]
        $card.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim (-2) 0 160))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-Anim 0.16 0.05 160))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, (New-Anim 20 8 160))
    })

    $slot
}

# ---- fin incluido: ui/Design/Theme.ps1 ----
# ---- inicio incluido: ui/Design/UiKit.ps1 ----
# ============================================================
# UiKit.ps1
# Componentes visuales reutilizables construidos por código.
# Todos usan recursos dinámicos del tema (ver Theme.ps1), así
# que cambian de color solos al alternar claro/oscuro.
# ============================================================

$IconFont = New-Object System.Windows.Media.FontFamily 'Segoe Fluent Icons, Segoe MDL2 Assets'

# ---- Ayudantes de rejilla -----------------------------------
# Declara las columnas de un Grid de una sola línea:
#     Add-GridColumns $grid 'Auto', '*', 'Auto'
# Acepta 'Auto', '*' o un ancho fijo en píxeles ('120').
function Add-GridColumns {
    param($Grid, [string[]]$Widths)
    foreach ($w in $Widths) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        if ($w -eq '*')         { $cd.Width = [System.Windows.GridLength]::new(1, 'Star') }
        elseif ($w -eq 'Auto')  { $cd.Width = [System.Windows.GridLength]::Auto }
        else                    { $cd.Width = [System.Windows.GridLength]::new([double]$w) }
        $Grid.ColumnDefinitions.Add($cd)
    }
}

# Coloca un elemento en una columna del Grid.
function Add-ToColumn {
    param($Grid, $Element, [int]$Column)
    [System.Windows.Controls.Grid]::SetColumn($Element, $Column)
    $Grid.Children.Add($Element) | Out-Null
}

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

<#
    Cómo se enseña cada estado de los que calcula
    core/Registry/SettingStatus.ps1 mirando el registro de verdad.

    Un único sitio con el nombre, el icono, los colores y el pie de
    ayuda de cada estado: lo usan la etiqueta de la tarjeta de ajuste
    y las píldoras del resumen de la sección, así que no pueden
    acabar diciendo cosas distintas. Añadir un estado es añadir una
    línea aquí y otra en core/.

    Los textos se guardan en inglés y se traducen al pintarlos
    (regla 15): aquí no se llama a T.
#>
$SettingStatusStyles = @{
    'optimized' = @{ Label = 'Optimized';           Icon = 'StarFill'; Fg = 'Success';   Bg = 'SuccessSoft'
                     Tip   = 'The registry value is the one this program recommends'
                     Count = 'Optimized: {0} of {1}' }

    'factory'   = @{ Label = 'Factory recommended'; Icon = 'Grid';     Fg = 'TextMuted'; Bg = 'SurfaceSunken'
                     Tip   = 'The registry value is the Windows factory one'
                     Count = 'Factory recommended: {0} of {1}' }

    'custom'    = @{ Label = 'Custom';              Icon = 'Sliders';  Fg = 'Warn';      Bg = 'WarnSoft'
                     Tip   = 'The registry value is neither the recommended nor the factory one'
                     Count = 'Customised: {0} of {1}' }

    'unknown'   = @{ Label = 'Unknown';             Icon = 'Help';     Fg = 'TextFaint'; Bg = 'SurfaceSunken'
                     Tip   = 'The registry value could not be read'
                     Count = 'Unknown: {0} of {1}' }
}

# Un estado que no esté en el catálogo se enseña como desconocido,
# que es exactamente lo que es: nadie sabe qué significa.
function Get-StatusStyle {
    param([string]$Status)

    $style = $SettingStatusStyles[[string]$Status]
    if (-not $style) { $style = $SettingStatusStyles['unknown'] }
    $style
}

<#
    Etiqueta del estado REAL de un ajuste: icono, nombre y un pie de
    ayuda que explica por qué está ahí.

    Sustituye a las etiquetas declaradas (New-Tag) en los ajustes que
    sí leen el registro; ver ui/Components/Cards/SettingCard.ps1.
#>
function New-StatusTag {
    param([string]$Status)

    $style = Get-StatusStyle $Status

    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 6
    $b.Padding = New-Object System.Windows.Thickness 8, 2.5, 9, 3.5
    $b.Margin = New-Object System.Windows.Thickness 0, 0, 6, 0
    $b.ToolTip = T $style.Tip
    Set-BoxBg $b $style.Bg

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $icon = New-Icon $style.Icon 10 $style.Fg
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 5, 0
    $sp.Children.Add($icon) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $style.Label
    $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t $style.Fg
    $sp.Children.Add($t) | Out-Null

    $b.Child = $sp
    $b
}

# Etiqueta de clasificación (Recommended / Default / Custom).
function New-Tag {
    param([string]$Text)
    $map = @{
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
    $t.Text = T $Text; $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'
    Set-TextFg $t $c.Fg
    $b.Child = $t
    $b
}

# Distintivo rojo "NEW n". Se traduce la PALABRA y se respeta el
# número ('NEW 45' -> 'NUEVO 45'), de modo que ui/Data/Lang/ solo
# necesita la línea de 'NEW' y no una por cada cifra.
function New-Badge {
    param([string]$Text)
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 999
    $b.Padding = New-Object System.Windows.Thickness 7, 1.5, 7, 2.5
    $b.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
    $b.VerticalAlignment = 'Center'
    Set-BoxBg $b 'Danger'

    $t = New-Object System.Windows.Controls.TextBlock
    if ($Text -match '^(.*\S)\s+(\d+)$') { $t.Text = (T $Matches[1]) + ' ' + $Matches[2] }
    else                                 { $t.Text = T $Text }
    $t.FontSize = 9.5; $t.FontWeight = 'Bold'
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
            if ($new) { $info.Label.Text = T 'On' } else { $info.Label.Text = T 'Off' }
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
    $t.Text = T $Placeholder; $t.FontSize = 12.5
    $t.VerticalAlignment = 'Center'
    Set-TextFg $t 'TextFaint'
    $ph.Children.Add($t) | Out-Null

    $shell.Children.Add($ph) | Out-Null

    # El marcador se oculta en cuanto hay texto.
    #
    # Se busca entre los hermanos y NO por el Tag de la caja, aunque
    # sería más corto: el Tag de esta caja se lo queda quien la
    # envuelve -ui/Components/Shell/SearchBar.ps1 mete ahí su
    # desplegable-, y dos dueños para el mismo hueco acaban pisándose.
    $tb.Add_TextChanged({
        param($s, $e)
        $panel = $s.Parent
        if (-not $panel) { return }
        $visible = 'Visible'
        if ($s.Text.Length -gt 0) { $visible = 'Collapsed' }
        foreach ($hermano in $panel.Children) {
            if ($hermano -is [System.Windows.Controls.StackPanel]) { $hermano.Visibility = $visible }
        }
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
    $t.Text = T $Text; $t.FontSize = 12.5; $t.FontWeight = 'SemiBold'
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

# ---- fin incluido: ui/Design/UiKit.ps1 ----

# ---- 2. Mecanismos: registran, traducen, guardan y enrutan ----
# ---- inicio incluido: ui/Engine/AppSettings.ps1 ----
# ============================================================
# AppSettings.ps1
# Preferencias guardadas entre sesiones.
#
# Se escriben en un JSON dentro del perfil del usuario:
#     %APPDATA%\OptimizadorPC\settings.json
#
# Ahí y no junto al .exe a propósito: el ejecutable es portable
# y puede acabar en una carpeta sin permisos de escritura.
#
# Guardar una preferencia nueva no requiere tocar este archivo:
#     Set-AppSetting 'MiOpcion' $valor
#     Get-AppSetting 'MiOpcion' -Default 'algo'
# ============================================================

$AppSettingsPath = Join-Path $env:APPDATA 'OptimizadorPC\settings.json'
$AppSettings = @{}

# Lee el archivo si existe. Un JSON corrupto no debe impedir que
# el programa arranque: se ignora y se usan los valores por defecto.
function Import-AppSettings {
    if (-not (Test-Path $AppSettingsPath)) { return }
    try {
        $json = Get-Content -Path $AppSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($property in $json.PSObject.Properties) {
            $script:AppSettings[$property.Name] = $property.Value
        }
    }
    catch {
        $script:AppSettings = @{}
    }
}

function Save-AppSettings {
    try {
        $folder = Split-Path -Parent $AppSettingsPath
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
        }
        $AppSettings | ConvertTo-Json | Set-Content -Path $AppSettingsPath -Encoding UTF8
        $true
    }
    catch {
        # Sin permisos o disco lleno: la sesión sigue funcionando,
        # simplemente no se recordará la preferencia.
        $false
    }
}

function Get-AppSetting {
    param([Parameter(Mandatory)][string]$Name, $Default = $null)
    if ($AppSettings.ContainsKey($Name)) { $AppSettings[$Name] } else { $Default }
}

function Set-AppSetting {
    param([Parameter(Mandatory)][string]$Name, $Value)
    $script:AppSettings[$Name] = $Value
    Save-AppSettings | Out-Null
}

function Get-AppSettingsPath { $AppSettingsPath }

# ---- fin incluido: ui/Engine/AppSettings.ps1 ----
# ---- inicio incluido: ui/Engine/CategoryRegistry.ps1 ----
# ============================================================
# CategoryRegistry.ps1
# Registro de categorías.
#
# NO contiene datos ni decide qué se ve: solo el mecanismo.
#
#   ui/Data/Categories/<Nombre>.ps1  ->  QUÉ tiene cada sección
#   ui/Index/CategoryIndex.ps1        ->  CUÁLES se ven, en qué orden
#                                   y cuáles están bloqueadas
#
#   -> Añadir una sección  = crear su archivo en ui/Data/Categories/
#                            (aparece al final) y, si quieres
#                            colocarla, añadir su línea al índice
#   -> Ocultar una sección = Visible = $false en el índice
#   -> Bloquear una sección= Locked  = $true  en el índice
#   -> Reordenar           = mover su línea en el índice
# ============================================================

# Lista donde se van acumulando las categorías al cargarse.
$CategoryList = New-Object System.Collections.Generic.List[object]

<#
    Cuenta los ajustes marcados como nuevos y devuelve el texto del
    distintivo de la categoría: 'NEW 3', o $null si no hay ninguno
    (así la tarjeta no pinta un distintivo vacío).

    Nuevo = el ajuste lleva su propio Badge, sea cual sea su texto.
#>
function Get-NewBadgeText {
    param($Items)

    $count = @($Items | Where-Object { $_.Badge }).Count
    if ($count -eq 0) { return $null }
    "NEW $count"
}

<#
    Da de alta una categoría. Campos de la definición:

    Id           (string) Identificador corto y único: 'regedit', 'power'...
                          Es la clave con la que ui/Index/CategoryIndex.ps1 la coloca.
    Name         (string) Título visible.
    Icon         (string) Nombre de glifo del catálogo de Theme.ps1 ('Shield', 'Power'...).
    Accent       (string) Clave de color del tema para el icono ('Accent', 'Success', 'Warn').
    AccentSoft   (string) Clave de color del tema para el fondo del icono.
    Badge        (string) Distintivo rojo. Si NO se declara, se calcula solo:
                          cuenta los Items que llevan su propio -Badge y sale
                          'NEW <n>', o nada si no hay ninguno. Declararlo lo
                          fija a mano ('NEW 45'); ponerlo a '' lo apaga.
    Description  (string) Línea gris bajo el título.
    Recommended / Default / Custom / Total  (int)  Contadores de las píldoras.
    Items        (array)  Ajustes, creados con New-Setting.
#>
function Register-Category {
    param([Parameter(Mandatory)][hashtable]$Definition)

    # Valores por defecto: así una categoría mínima solo necesita
    # Id, Name, Icon, Description e Items.
    # Locked lo rellena el índice; aquí solo se reserva el campo.
    $defaults = @{
        Accent = 'Accent'; AccentSoft = 'AccentSoft'
        Recommended = 0; Default = 0; Custom = 0; Total = 0
        Items = @(); Locked = $false
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Definition.ContainsKey($key)) { $Definition[$key] = $defaults[$key] }
    }

    # El distintivo se cuenta a partir de los ajustes marcados como
    # nuevos, para que el número no se quede desfasado al añadir o
    # quitar uno. Declarar Badge en la categoría lo fija a mano.
    if (-not $Definition.ContainsKey('Badge')) {
        $Definition['Badge'] = Get-NewBadgeText $Definition['Items']
    }

    foreach ($required in @('Id', 'Name', 'Icon', 'Description')) {
        if (-not $Definition[$required]) {
            throw "Register-Category: falta el campo obligatorio '$required'."
        }
    }

    $CategoryList.Add([PSCustomObject]$Definition)
}

<#
    Devuelve las categorías que debe pintar la interfaz, ya
    ordenadas y filtradas según ui/Index/CategoryIndex.ps1:

      1. Recorre el índice en orden. De cada entrada:
           - si no existe el archivo de esa Id, la salta
           - si Visible = $false, la salta
           - copia Locked a la categoría
      2. Añade al final las categorías registradas que todavía
         no aparecen en el índice (visibles y desbloqueadas),
         para que crear un archivo nuevo funcione sin tocar nada.
#>
function Get-OptimizationCategories {
    $result = New-Object System.Collections.Generic.List[object]
    $placed = @{}

    foreach ($entry in $CategoryIndex) {
        $category = $CategoryList | Where-Object { $_.Id -eq $entry.Id } | Select-Object -First 1
        if (-not $category) { continue }

        $placed[$entry.Id] = $true

        # Visible por defecto: solo se oculta si se pide explícitamente.
        if ($entry.ContainsKey('Visible') -and -not $entry.Visible) { continue }

        $category.Locked = [bool]$entry.Locked
        $result.Add($category)
    }

    foreach ($category in $CategoryList) {
        if (-not $placed.ContainsKey($category.Id)) {
            $category.Locked = $false
            $result.Add($category)
        }
    }

    $result
}

# Categorías que existen en disco pero nadie ha colocado en el
# índice. Útil para depurar por qué algo aparece al final.
function Get-UnlistedCategories {
    $listed = @{}
    foreach ($entry in $CategoryIndex) { $listed[$entry.Id] = $true }
    $CategoryList | Where-Object { -not $listed.ContainsKey($_.Id) }
}

# Busca una categoría concreta por su Id (esté visible o no).
function Get-CategoryById {
    param([string]$Id)
    $CategoryList | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

<#
    Cuenta los ajustes de una categoría por etiqueta. Es lo que
    resume la fila centrada bajo el título del detalle (ver
    ui/Components/Layout/CategorySummary.ps1).

    Se cuenta SIEMPRE sobre los Items de verdad, no sobre los
    campos Recommended/Default/Custom de la categoría: esos son
    números fijos escritos a mano para las píldoras de la lista y
    no cuadran con el contenido real del archivo.

    Al recontar se vuelve a leer el array, así que en cuanto la
    lógica real cambie las etiquetas de un ajuste el resumen se
    actualiza sin tocar nada aquí.
#>
function Get-CategoryCounts {
    param($Category)

    $items = @($Category.Items)
    $counts = [ordered]@{}
    foreach ($tag in @('Recommended', 'Default', 'Custom')) {
        $counts[$tag] = @($items | Where-Object { $_.Tags -contains $tag }).Count
    }
    $counts['Total'] = $items.Count
    [PSCustomObject]$counts
}

<#
    Lo mismo, pero por ESTADO REAL: el que core/Registry/SettingStatus.ps1
    deja en cada ajuste al leer el equipo.

        optimized / factory / custom / unknown / Total

    Devuelve $null cuando NINGÚN ajuste de la sección tiene estado,
    que es tanto como decir que ninguno declara claves del registro.
    Entonces la que vale sigue siendo Get-CategoryCounts, con las
    etiquetas escritas a mano en ui/Data/Categories/.

    Solo cuentan los ajustes que sí tienen estado: mezclar en el
    total los que no leen nada haría que los números no cuadraran
    con lo que se ve en las tarjetas.
#>
function Get-CategoryStatusCounts {
    param($Category)

    $items = @(@($Category.Items) | Where-Object { $_.Status })
    if ($items.Count -eq 0) { return $null }

    $counts = [ordered]@{}
    foreach ($status in Get-SettingStatusNames) {
        $counts[$status] = @($items | Where-Object { $_.Status -eq $status }).Count
    }
    $counts['Total'] = $items.Count
    [PSCustomObject]$counts
}

<#
    Crea un ajuste para el array Items de una categoría.

    El tipo de control se deduce solo:
      - con -Options  -> desplegable
      - sin -Options  -> interruptor (el -Value debe ser $true / $false)

    -Registry declara las claves que toca el ajuste. Son las que
    enseña el pie "Detalles técnicos" de la tarjeta (ver
    ui/Components/Cards/TechnicalDetails.ps1). Cada clave es una tabla:

        Path         Ruta completa, con la raíz sin abreviar.
        Name         Nombre del valor dentro de esa ruta.
        Type         Tipo del valor: 'DWord', 'String'...
        Display      'hex' para enseñarlo como 0xFFFFFFFF.
        Recommended  Valor que propone el programa.
        Default      Valor de fábrica de Windows.

    Current y Status NO se declaran: los rellena core/ al leer el
    equipo (ver core/Registry/CategoryState.ps1). Recommended y Default sí
    son texto escrito a mano, y son contra lo que se compara lo
    leído para saber en qué estado está el ajuste.

    Un ajuste sin -Registry sale con un aviso en su lugar, no se
    rompe: se queda sin Status y la tarjeta enseña sus -Tags.

    Ejemplos:
        New-Setting -Name 'Game Mode' -Description '...' `
                    -Tags 'Recommended','Default' -Value $true

        New-Setting -Name 'Mouse Hover Time' -Description '...' `
                    -Tags 'Custom' -Options '100ms','200ms' `
                    -Value '200ms' -Badge 'NEW' `
                    -Registry @(
                        @{ Path = 'HKEY_CURRENT_USER\Control Panel\Mouse'
                           Name = 'MouseHoverTime'; Type = 'String'
                           Recommended = '200'; Default = '400' }
                    )
#>
function New-Setting {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [string[]]$Tags = @(),
        [string[]]$Options,
        [Parameter(Mandatory)]$Value,
        [string]$Badge,
        [hashtable[]]$Registry = @()
    )

    if ($Options) { $type = 'Dropdown' } else { $type = 'Toggle' }

    [PSCustomObject]@{
        Name        = $Name
        Description = $Description
        Tags        = $Tags
        Type        = $type
        Options     = $Options
        Value       = $Value
        Badge       = $Badge
        Registry    = $Registry

        # NO se declara: lo rellena core/Registry/SettingStatus.ps1 al leer
        # el equipo, igual que el Current de cada clave. Se reserva
        # aquí el campo para poder asignarlo después.
        Status      = $null
    }
}

# ---- fin incluido: ui/Engine/CategoryRegistry.ps1 ----
# ---- inicio incluido: ui/Engine/PreferenceRegistry.ps1 ----
# ============================================================
# PreferenceRegistry.ps1
# Registro de las opciones de la pantalla Settings.
#
# NO contiene opciones: solo el mecanismo. Cada opción vive en
# su propio archivo dentro de ui/Data/Preferences/, igual que cada
# sección vive en ui/Data/Categories/.
#
#   -> Añadir una opción  = crear un archivo en ui/Data/Preferences/
#   -> Quitarla           = borrar ese archivo
#   -> Reordenar          = cambiar su campo Order
#
# La pantalla Settings se dibuja sola a partir de lo que haya
# registrado: no hay que tocar la vista para añadir opciones.
# ============================================================

$PreferenceList = New-Object System.Collections.Generic.List[object]

<#
    Da de alta una opción. Campos:

    Id           (string)   Identificador único: 'language', 'theme'...
    Order        (int)      Posición. 10, 20, 30... como las secciones.
    Group        (string)   Cabecera bajo la que se agrupa. Se traduce.
    Label        (string)   Título de la opción. Se traduce.
    Description  (string)   Explicación gris debajo. Se traduce.
    Type         (string)   'Choice'  -> desplegable
                            'Toggle'  -> interruptor
    Options      (array o scriptblock)
                            Solo para 'Choice'. Cada opción es
                            @{ Value = 'es'; Label = 'Español' }.
                            Si es un scriptblock se evalúa al pintar,
                            que es lo que permite listas dinámicas.
    TranslateOptions (bool) $false si las etiquetas de las opciones NO
                            deben traducirse. Es el caso de los nombres
                            de idioma, que van siempre en su propio
                            idioma. Por defecto $true.
    Get          (scriptblock)  Devuelve el valor actual.
    Set          (scriptblock)  param($Value) aplica el valor nuevo.
                                Es responsable de guardarlo si procede.
#>
function Register-Preference {
    param([Parameter(Mandatory)][hashtable]$Definition)

    $defaults = @{
        Order = 999; Group = 'General'; Description = ''
        Type = 'Choice'; Options = @(); TranslateOptions = $true
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Definition.ContainsKey($key)) { $Definition[$key] = $defaults[$key] }
    }

    foreach ($required in @('Id', 'Label', 'Get', 'Set')) {
        if (-not $Definition[$required]) {
            throw "Register-Preference: falta el campo obligatorio '$required'."
        }
    }

    $PreferenceList.Add([PSCustomObject]$Definition)
}

function Get-Preferences {
    $PreferenceList | Sort-Object Order
}

# Los grupos, en el orden en que aparece su primera opción.
function Get-PreferenceGroups {
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($preference in Get-Preferences) {
        if (-not $seen.Contains($preference.Group)) { $seen.Add($preference.Group) }
    }
    $seen
}

# Resuelve las opciones, ya vengan como array o como scriptblock.
function Get-PreferenceOptions {
    param($Preference)
    if ($Preference.Options -is [scriptblock]) { & $Preference.Options } else { $Preference.Options }
}

function Get-PreferenceById {
    param([string]$Id)
    $PreferenceList | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

# ---- fin incluido: ui/Engine/PreferenceRegistry.ps1 ----
# ---- inicio incluido: ui/Engine/Router.ps1 ----
# ============================================================
# Router.ps1
# Sabe qué pantalla se está viendo y cómo volver a dibujarla.
#
# Hace falta por dos motivos:
#
#   1. Cada botón del menú lateral lleva a una vista distinta
#      (campo View de ui/Index/NavigationIndex.ps1).
#   2. Al cambiar de idioma hay que repintar la pantalla actual.
#      Los colores se actualizan solos porque el XAML usa
#      DynamicResource, pero para el texto no existe equivalente:
#      hay que reconstruir la vista.
#
# Las vistas se invocan por nombre de función, así que añadir una
# pantalla es crear su archivo en ui/Views/ y apuntar a ella
# desde el índice de navegación. Nada que registrar aquí.
# ============================================================

$AppWindow = $null
$CurrentView = @{ Name = 'Show-OptimizationsListView'; Arguments = @{} }

# La ventana se guarda una vez al arrancar para que cualquier
# capa pueda repintar sin ir pasándola de mano en mano.
function Set-AppWindow {
    param($Window)
    $script:AppWindow = $Window
}

function Get-AppWindow { $script:AppWindow }

<#
    Muestra una vista y la recuerda.

        Show-View 'Show-SettingsView'
        Show-View 'Show-CategoryDetailView' @{ Category = $cat }
#>
function Show-View {
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Arguments = @{}
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Router: la vista '$Name' no existe. Revisa el campo View de ui/Index/NavigationIndex.ps1."
    }

    $script:CurrentView = @{ Name = $Name; Arguments = $Arguments }

    $all = @{ Window = $AppWindow }
    foreach ($key in $Arguments.Keys) { $all[$key] = $Arguments[$key] }
    & $Name @all

    # El menú tiene que marcar lo que se está enseñando, se haya
    # llegado pulsándolo o no: a la búsqueda se entra también con
    # Enter desde la caja de la cabecera. Lo resuelve el menú, que es
    # quien sabe de botones; aquí solo se le dice dónde estamos.
    Sync-NavSelection -Window $AppWindow -ViewName $Name

    # Navegar empieza arriba. El ScrollViewer conserva su posición
    # aunque le cambies el contenido, así que al entrar en una
    # sección te dejaría a media página. Show-CurrentView deshace
    # esto después, porque repintar no es navegar.
    if ($AppWindow) {
        $scroll = $AppWindow.FindName('MainScroll')
        if ($scroll) { $scroll.ScrollToTop() }
    }
}

<#
    Vuelve a dibujar la pantalla actual con los mismos argumentos,
    dejando el scroll donde estaba.

    Repintar NO es navegar: sigues en la misma pantalla mirando lo
    mismo, así que saltar al principio se siente como si la
    aplicación te hubiera movido de sitio. Por eso la posición se
    conserva aquí y no en Show-View, donde sí toca empezar arriba.

    La restauración se aplaza: el contenido nuevo aún no está
    medido y, mientras el alto sea 0, ScrollToVerticalOffset se
    recorta a 0 y no haría nada.
#>
$PendingScroll = 0.0

function Show-CurrentView {
    $window = Get-AppWindow
    $scroll = $null
    if ($window) { $scroll = $window.FindName('MainScroll') }
    if ($scroll) { $script:PendingScroll = $scroll.VerticalOffset }

    Show-View -Name $CurrentView.Name -Arguments $CurrentView.Arguments

    if ($scroll -and $PendingScroll -gt 0) {
        $window.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Loaded,
            [action]{
                $sv = (Get-AppWindow).FindName('MainScroll')
                # Si la pantalla ha encogido, ScrollViewer recorta
                # solo al máximo posible.
                $sv.ScrollToVerticalOffset($PendingScroll)
            }) | Out-Null
    }
}

function Get-CurrentViewName { $CurrentView.Name }

# Repinta todo tras cambiar el idioma: el menú lateral (sus
# etiquetas también se traducen) y la pantalla actual.
#
# Se aplaza al Dispatcher porque esto suele dispararse desde el
# evento de un control que está dentro de la vista que vamos a
# destruir; dejar que el evento termine primero evita sorpresas.
function Update-UiLanguage {
    $window = Get-AppWindow
    if (-not $window) { return }

    $window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{
            # El índice del buscador guarda TAMBIÉN el texto traducido
            # -quien usa la aplicación en español busca en español-,
            # así que en otro idioma ya no vale. Antes de repintar,
            # para que la pantalla de resultados se rehaga con él.
            Reset-SearchIndex

            Build-Sidebar -Window (Get-AppWindow)
            Update-TitleBarTexts (Get-AppWindow)
            Show-CurrentView

            # El cajón del log no es una vista y Show-CurrentView no
            # lo toca, así que si está abierto hay que rehacerlo
            # aparte o se quedaría en el idioma anterior. Lo mismo
            # si está sacado a su propia ventana.
            if (Get-LogPanelOpen) { Update-LogPanel (Get-AppWindow) }
            if (Get-LogDetached)  { Update-LogWindow }
        }) | Out-Null
}

# ---- fin incluido: ui/Engine/Router.ps1 ----
# ---- inicio incluido: ui/Engine/Search.ps1 ----
# ============================================================
# Search.ps1
# El buscador global. Mecanismo, no datos.
#
# No sabe qué secciones hay ni qué ajustes existen: se los pregunta
# al registro de categorías, así que una sección nueva entra en el
# buscador sola, sin tocar este archivo.
#
# Cómo funciona
# -------------
# Se arma UN índice plano con una entrada por cada cosa buscable
# -cada sección y cada ajuste-, y cada entrada trae:
#
#   Fields     los datos que se pueden buscar, con su etiqueta. Es lo
#              que permite decir POR QUÉ ha salido un resultado.
#   Haystack   todos esos datos en minúsculas y en una sola cadena.
#              Buscar es mirar si están dentro todos los términos.
#
# El índice se guarda y se reutiliza; se tira cuando cambia lo que
# hay dentro. Hoy eso pasa en dos sitios, y los dos llaman a
# Reset-SearchIndex:
#
#   - Leer el registro de una sección, que rellena Current y Status.
#   - Cambiar de idioma: el índice guarda TAMBIÉN el texto traducido,
#     porque quien usa la aplicación en español busca en español.
#
# Lo técnico -rutas, nombres de valor, números- no se traduce nunca,
# ni aquí ni en pantalla: es texto para copiar y pegar.
# ============================================================

$SearchQuery = ''
$SearchIndex = $null

# Lo que se está buscando ahora mismo. Vive aquí y no en el control
# para que la vista se pueda repintar -al cambiar de idioma, por
# ejemplo- sin que nadie tenga que ir a leer la caja de texto.
function Set-SearchQuery { param([string]$Text) $script:SearchQuery = [string]$Text }
function Get-SearchQuery { $script:SearchQuery }

function Reset-SearchIndex { $script:SearchIndex = $null }

function Get-SearchIndex {
    if ($null -eq $script:SearchIndex) { $script:SearchIndex = New-SearchIndex }
    $script:SearchIndex
}

<#
    Un campo buscable: la etiqueta con la que se enseña y su texto.

    -Translate para lo que en pantalla pasa por T (nombres,
    descripciones, etiquetas): así "Recomendado" encuentra lo mismo
    que "Recommended" y el buscador funciona en los dos idiomas. Lo
    técnico se queda tal cual.
#>
function New-SearchField {
    param([string]$Label, $Value, [switch]$Translate)

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    $shown = $text
    $extra = ''
    if ($Translate) {
        $shown = T $text
        if ($shown -ne $text) { $extra = $text }   # el original también busca
    }

    [PSCustomObject]@{ Label = $Label; Text = $shown; Also = $extra }
}

<#
    Un campo hecho de varios valores sueltos: las etiquetas de un
    ajuste, las opciones de un desplegable.

    Se traduce CADA UNO y luego se juntan. Juntarlos antes y pasar
    la frase entera por T no traduciría nada -esa frase no está en
    ningún diccionario ni tiene por qué estar- y de paso ensuciaría
    la lista de textos pendientes que enseña Get-MissingTranslations.
#>
function New-SearchListField {
    param([string]$Label, $Values)

    $items = @(@($Values) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return $null }

    $original = ($items -join ' ')
    $mostrado = (@($items | ForEach-Object { T ([string]$_) }) -join ' ')

    $extra = ''
    if ($mostrado -ne $original) { $extra = $original }

    [PSCustomObject]@{ Label = $Label; Text = $mostrado; Also = $extra }
}

# Los campos de un ajuste: lo suyo, lo de su sección y lo de cada
# clave del registro que declare.
function Get-SettingSearchFields {
    param($Category, $Setting)

    $fields = New-Object System.Collections.Generic.List[object]

    $fields.Add((New-SearchField 'Name'        $Setting.Name        -Translate))
    $fields.Add((New-SearchField 'Description' $Setting.Description -Translate))
    $fields.Add((New-SearchField 'Section'     $Category.Name       -Translate))
    $fields.Add((New-SearchListField 'Tags' $Setting.Tags))

    # El valor de un interruptor es $true/$false y no aporta nada;
    # el de un desplegable sí, y además se traduce.
    if ($Setting.Options) {
        $fields.Add((New-SearchListField 'Options' $Setting.Options))
        $fields.Add((New-SearchField     'Value'   $Setting.Value -Translate))
    }

    foreach ($key in @($Setting.Registry)) {
        $fields.Add((New-SearchField 'Registry path'  $key.Path))
        $fields.Add((New-SearchField 'Registry value' $key.Name))
        $fields.Add((New-SearchField 'Type'           $key.Type))
        $fields.Add((New-SearchField 'Current value'  $key.Current))
        $fields.Add((New-SearchField 'Recommended'    $key.Recommended))
        $fields.Add((New-SearchField 'Factory'        $key.Default))
    }

    # El estado real, si ya se ha leído el equipo: buscar "optimizado"
    # saca lo que está aplicado.
    if ($Setting.Status) {
        $fields.Add((New-SearchField 'Status' (Get-StatusStyle $Setting.Status).Label -Translate))
    }

    $fields.ToArray() | Where-Object { $_ }
}

# Una entrada del índice, con su pajar ya en minúsculas.
function New-SearchEntry {
    param([string]$Kind, $Category, $Setting, $Fields)

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($field in @($Fields)) {
        $parts.Add($field.Text)
        if ($field.Also) { $parts.Add($field.Also) }
    }

    [PSCustomObject]@{
        Kind     = $Kind
        Category = $Category
        Setting  = $Setting
        Fields   = @($Fields)
        Haystack = ($parts.ToArray() -join ' ').ToLowerInvariant()
    }
}

<#
    Arma el índice entero recorriendo las secciones visibles.

    Se indexa la sección además de sus ajustes, para que buscar
    "regedit" o "juegos" lleve a la sección aunque ningún ajuste
    concreto se llame así.
#>
function New-SearchIndex {
    $index = New-Object System.Collections.Generic.List[object]

    foreach ($category in Get-OptimizationCategories) {
        $catFields = @(
            (New-SearchField 'Section'     $category.Name        -Translate)
            (New-SearchField 'Description' $category.Description -Translate)
        ) | Where-Object { $_ }

        $index.Add((New-SearchEntry 'category' $category $null $catFields))

        foreach ($setting in @($category.Items)) {
            $index.Add((New-SearchEntry 'setting' $category $setting (Get-SettingSearchFields $category $setting)))
        }
    }

    $index.ToArray()
}

# Los términos de una consulta: en minúsculas y separados por
# espacios. Buscar "windows update" pide las dos palabras, no la
# frase exacta, que es lo que uno espera al teclear.
function Get-SearchTerms {
    param([string]$Query)

    if ([string]::IsNullOrWhiteSpace($Query)) { return @() }
    @($Query.ToLowerInvariant() -split '\s+' | Where-Object { $_ })
}

<#
    Busca. Devuelve las entradas que encajan, cada una con el campo
    por el que ha encajado (Match), para poder enseñarlo.

    Coincidencia PARCIAL y sin distinguir mayúsculas: se mira si el
    término está DENTRO del texto, así que "throttl" encuentra
    NetworkThrottlingIndex y media ruta del registro encuentra la
    clave entera.
#>
function Get-SearchResults {
    param([string]$Query)

    $terms = Get-SearchTerms $Query
    if ($terms.Count -eq 0) { return @() }

    $found = New-Object System.Collections.Generic.List[object]

    foreach ($entry in (Get-SearchIndex)) {
        $ok = $true
        foreach ($term in $terms) {
            if ($entry.Haystack.IndexOf($term, [System.StringComparison]::Ordinal) -lt 0) { $ok = $false; break }
        }
        if (-not $ok) { continue }

        $entry | Add-Member -NotePropertyName 'Match' -NotePropertyValue (Get-SearchMatchField $entry $terms) -Force
        $found.Add($entry)
    }

    $found.ToArray()
}

# El campo que explica el resultado: el primero que contenga alguno
# de los términos. Sirve para que el usuario vea que ha encajado por
# la ruta del registro y no por el nombre.
function Get-SearchMatchField {
    param($Entry, [string[]]$Terms)

    foreach ($field in @($Entry.Fields)) {
        $texto = ($field.Text + ' ' + $field.Also).ToLowerInvariant()
        foreach ($term in $Terms) {
            if ($texto.IndexOf($term, [System.StringComparison]::Ordinal) -ge 0) { return $field }
        }
    }
    $null
}

<#
    Los resultados agrupados por sección, en el orden del índice de
    categorías. Cada grupo trae la categoría y sus entradas.

    Agrupar aquí y no en la vista deja la pantalla como debe ser: un
    bucle sobre grupos y nada de lógica.
#>
function Group-SearchResults {
    param($Results)

    $groups = New-Object System.Collections.Generic.List[object]
    $byId = @{}

    foreach ($entry in @($Results)) {
        $id = [string]$entry.Category.Id
        if (-not $byId.ContainsKey($id)) {
            $group = [PSCustomObject]@{
                Category = $entry.Category
                Entries  = New-Object System.Collections.Generic.List[object]
            }
            $byId[$id] = $group
            $groups.Add($group)
        }
        $byId[$id].Entries.Add($entry)
    }

    $groups.ToArray()
}

# ---- fin incluido: ui/Engine/Search.ps1 ----
# ---- inicio incluido: ui/Engine/Translation.ps1 ----
# ============================================================
# Translation.ps1
# Mecanismo de idiomas. NO contiene textos.
#
# Se traduce POR TEXTO ORIGINAL, no por clave: el inglés es el
# idioma fuente y cada archivo de ui/Data/Lang/ es un diccionario
# "texto en inglés" -> "texto traducido".
#
# Gracias a eso los archivos de ui/Data/Categories/ no necesitan
# tocarse: siguen leyéndose en inglés claro. Y si falta una
# traducción, sale el original en vez de romperse.
#
#   -> Añadir un idioma = crear ui/Data/Lang/<código>.ps1
#                         y su línea en ui/Index/LanguageIndex.ps1
#   -> El inglés no necesita archivo: es la fuente.
# ============================================================

$Translations = @{}       # código -> tabla de textos
$CurrentLanguage = 'en'
$SeenStrings = @{}        # todo lo que ha pasado por T, para auditar

function Register-Language {
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][hashtable]$Strings
    )
    if (-not $Translations.ContainsKey($Code)) { $Translations[$Code] = @{} }
    foreach ($key in $Strings.Keys) { $Translations[$Code][$key] = $Strings[$key] }
}

function Set-AppLanguage {
    param([Parameter(Mandatory)][string]$Code)
    $script:CurrentLanguage = $Code
}

function Get-AppLanguage { $script:CurrentLanguage }

<#
    Traduce un texto al idioma activo.

        $t.Text = T 'Optimizations'
        $t.Text = (T '{0} settings') -f 6

    Si el idioma activo es el fuente, o no hay traducción para
    ese texto, devuelve el original tal cual.
#>
function T {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $script:SeenStrings[$Text] = $true

    $dict = $Translations[$script:CurrentLanguage]
    if ($dict -and $dict.ContainsKey($Text)) { return $dict[$Text] }
    $Text
}

<#
    Textos que la interfaz ha pedido traducir y que faltan en el
    idioma indicado. Sirve para saber qué queda por traducir tras
    añadir ajustes nuevos:

        Get-MissingTranslations 'es'

    Solo ve lo que se haya mostrado en esta sesión, así que
    conviene navegar por la aplicación antes de consultarlo.
#>
function Get-MissingTranslations {
    param([string]$Code = $CurrentLanguage)

    $dict = $Translations[$Code]
    if (-not $dict) { return $SeenStrings.Keys }
    $SeenStrings.Keys | Where-Object { -not $dict.ContainsKey($_) } | Sort-Object
}

<#
    Olvida lo visto hasta ahora y empieza a apuntar de cero.

    Get-MissingTranslations acumula desde que arrancó el programa,
    así que sin esto no hay forma de preguntar por una pantalla
    concreta: arrastraría todo lo que se haya pintado antes.

        Reset-TranslationAudit
        Show-View -Name 'Show-SettingsView'
        Get-MissingTranslations 'es'
#>
function Reset-TranslationAudit {
    $script:SeenStrings = @{}
}

# ---- fin incluido: ui/Engine/Translation.ps1 ----

# ---- 3. Índices: qué se ve, en qué orden y qué está bloqueado ----
# ---- inicio incluido: ui/Index/CategoryIndex.ps1 ----
# ============================================================
# CategoryIndex.ps1
#
#   *** ESTE ES EL ARCHIVO PRINCIPAL DE LAS SECCIONES ***
#
# Manda sobre qué secciones se ven, en qué orden y cuáles están
# bloqueadas. El contenido de cada una sigue viviendo en su
# propio archivo dentro de ui/Data/Categories/.
#
#   ORDEN      El de esta lista, de arriba abajo.
#              Mover una sección = mover su línea.
#
#   Visible    $true  -> se muestra
#              $false -> se oculta por completo (sigue en el
#                        disco, no se pierde nada)
#
#   Locked     $false -> normal
#              $true  -> se muestra con un candado y se puede
#                        abrir, pero sus ajustes salen en gris
#                        y no se pueden tocar
#
# Quitar una sección de la lista NO borra su archivo: si la
# comentas con # deja de aparecer, y la recuperas quitando el #.
#
# Una sección que exista en ui/Data/Categories/ pero no esté aquí se
# añade al final, visible y desbloqueada.
# ============================================================

$CategoryIndex = @(

    #  Id                    Visible          Bloqueada
    @{ Id = 'regedit';       Visible = $true;  Locked = $false }
    @{ Id = 'power';         Visible = $true;  Locked = $false }
    @{ Id = 'gaming';        Visible = $true;  Locked = $false }
    @{ Id = 'update';        Visible = $true;  Locked = $false }
    @{ Id = 'notifications'; Visible = $true;  Locked = $false }
    @{ Id = 'sound';         Visible = $true;  Locked = $false }

)

# ---- fin incluido: ui/Index/CategoryIndex.ps1 ----
# ---- inicio incluido: ui/Index/LanguageIndex.ps1 ----
# ============================================================
# LanguageIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DE LOS IDIOMAS ***
#
# Qué idiomas ofrece el programa y en qué orden salen en el
# desplegable de Settings.
#
#   Code     Código corto. Debe coincidir con el nombre del
#            archivo de ui/Data/Lang/ (es -> ui/Data/Lang/es.ps1).
#   Label    Cómo se llama el idioma EN SU PROPIO IDIOMA, que es
#            lo que espera ver quien lo busca. No se traduce.
#   Source   $true en el idioma en el que está escrito el código
#            fuente. Ese no lleva archivo en ui/Data/Lang/.
#   Default  Idioma de arranque la primera vez. Después manda lo
#            que haya guardado en %APPDATA% (ver AppSettings.ps1).
#   Visible  $false lo esconde sin borrar su archivo.
#
# Para añadir un idioma:
#   1. crear ui/Data/Lang/<código>.ps1 copiando ui/Data/Lang/es.ps1
#   2. añadir su línea aquí
# ============================================================

$LanguageIndex = @(

    @{ Code = 'en'; Label = 'English';  Visible = $true; Source = $true; Default = $true }
    @{ Code = 'es'; Label = 'Español';  Visible = $true }

)

function Get-AvailableLanguages {
    $LanguageIndex | Where-Object { -not $_.ContainsKey('Visible') -or $_.Visible }
}

function Get-DefaultLanguage {
    $default = $LanguageIndex | Where-Object { $_.Default } | Select-Object -First 1
    if ($default) { $default.Code } else { 'en' }
}

function Get-LanguageLabel {
    param([string]$Code)
    $found = $LanguageIndex | Where-Object { $_.Code -eq $Code } | Select-Object -First 1
    if ($found) { $found.Label } else { $Code }
}

# ---- fin incluido: ui/Index/LanguageIndex.ps1 ----
# ---- inicio incluido: ui/Index/NavigationIndex.ps1 ----
# ============================================================
# NavigationIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DEL MENÚ LATERAL ***
#
# Mismo planteamiento que ui/Index/CategoryIndex.ps1, pero para los
# botones de la barra de la izquierda. Antes estaban escritos a
# mano dentro de MainWindow.xaml; ahora son datos y los dibuja
# ui/Components/Shell/Sidebar.ps1.
#
#   ORDEN      El de esta lista, dentro de cada grupo.
#              Mover un botón = mover su línea.
#
#   Group      'Top'    -> arriba del todo
#              'Bottom' -> pegado abajo, tras la línea separadora
#
#   Visible    $true  -> se muestra
#              $false -> se oculta (no se pierde nada)
#
#   Locked     $false -> normal
#              $true  -> se muestra en gris con candado y no
#                        responde al clic
#
#   Default    $true en el botón que sale marcado al arrancar.
#
#   View       Nombre de la función de vista a la que lleva.
#
#              $null -> la sección todavía NO tiene pantalla. El
#                       botón se ve y se pulsa como los demás -ni
#                       gris ni con candado-, pero el clic no hace
#                       nada: ni navega, ni cambia el contenido, ni
#                       mueve la selección. Te quedas donde estabas.
#
#              Crear una pantalla es añadir su archivo a ui/Views/ y
#              escribir aquí el nombre de su función; el botón
#              empieza a funcionar solo, sin tocar nada más.
#
#   Icon       Nombre de glifo del catálogo de ui/Design/Theme.ps1.
# ============================================================

# Hoy hay pantalla para tres entradas -Search, Optimize y Settings-.
# Las otras cuatro siguen aquí a propósito: mantienen la estructura
# del menú a la vista, y activarlas será rellenar su View.
#
# 'search' va la primera porque no es una sección más: busca EN todas
# las demás. Su vista es la misma a la que lleva la caja de la
# cabecera, no una copia.
$NavigationIndex = @(

    #  Id             Icono        Etiqueta       Grupo      Visible  Bloqueado   Vista
    @{ Id = 'search';    Icon = 'Search';  Label = 'Search';    Group = 'Top';    Visible = $true; Locked = $false; View = 'Show-SearchResultsView' }
    @{ Id = 'software';  Icon = 'Apps';    Label = 'Software';  Group = 'Top';    Visible = $true; Locked = $false; View = $null }
    @{ Id = 'optimize';  Icon = 'Gauge';   Label = 'Optimize';  Group = 'Top';    Visible = $true; Locked = $false; View = 'Show-OptimizationsListView'; Default = $true }
    @{ Id = 'customize'; Icon = 'Palette'; Label = 'Customize'; Group = 'Top';    Visible = $true; Locked = $false; View = $null }

    @{ Id = 'advanced';  Icon = 'Wrench';  Label = 'Advanced';  Group = 'Bottom'; Visible = $true; Locked = $false; View = $null }
    @{ Id = 'settings';  Icon = 'Gear';    Label = 'Settings';  Group = 'Bottom'; Visible = $true; Locked = $false; View = 'Show-SettingsView' }
    @{ Id = 'more';      Icon = 'More';    Label = 'More';      Group = 'Bottom'; Visible = $true; Locked = $false; View = $null }

)

# Devuelve los botones visibles, opcionalmente los de un grupo.
function Get-NavigationItems {
    param([string]$Group)

    $items = $NavigationIndex | Where-Object {
        -not ($_.ContainsKey('Visible')) -or $_.Visible
    }
    if ($Group) { $items = $items | Where-Object { $_.Group -eq $Group } }
    $items
}

# Nombre con el que se registra cada botón en la ventana, para
# que $Window.FindName('NavSettings') siga funcionando.
function Get-NavElementName {
    param([string]$Id)
    'Nav' + $Id.Substring(0, 1).ToUpper() + $Id.Substring(1)
}

function Get-NavigationItem {
    param([string]$Id)
    $NavigationIndex | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

# ---- fin incluido: ui/Index/NavigationIndex.ps1 ----
# ---- inicio incluido: ui/Index/ViewOptionsIndex.ps1 ----
# ============================================================
# ViewOptionsIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DEL BOTÓN "VISTA" ***
#
# Mismo planteamiento que ui/Index/CategoryIndex.ps1 y que
# ui/Index/NavigationIndex.ps1, pero para las casillas que salen al
# pulsar el botón "Vista" de la cabecera. Las dibuja
# ui/Components/Shell/ViewMenu.ps1.
#
# Son opciones de VISTA: deciden qué se enseña en pantalla, no
# tocan nada del sistema ni del contenido de las categorías.
#
#   ORDEN      El de esta lista, de arriba abajo.
#
#   Id         Clave corta. Se guarda en settings.json como
#              'View.<Id>', así que cambiarla olvida lo elegido.
#
#   Label      Texto de la fila (en inglés: es el idioma fuente).
#   Hint       Línea gris debajo del texto.
#   Icon       Nombre de glifo del catálogo de ui/Design/Theme.ps1.
#   Default    Valor con el que arranca la primera vez.
#   Visible    $false -> se oculta la fila (no se pierde nada)
#
# Añadir una opción es añadir su línea aquí y consultarla con
# Get-ViewOption '<Id>' donde toque. El menú se dibuja solo.
# ============================================================

$ViewOptionsIndex = @(

    #  Id             Icono     Etiqueta              Por defecto  Visible
    @{ Id = 'technical'; Icon = 'Info'; Label = 'Technical details'
       Hint = 'Show the registry keys each setting touches'
       Default = $true;  Visible = $true }

    @{ Id = 'badges';    Icon = 'Bulb'; Label = 'New badges'
       Hint = "Show the red 'NEW' tags on sections and settings"
       Default = $true;  Visible = $true }

)

# Clave con la que se guarda cada opción en settings.json.
function Get-ViewOptionKey {
    param([Parameter(Mandatory)][string]$Id)
    "View.$Id"
}

# Devuelve las filas visibles del menú, en el orden del índice.
function Get-ViewOptions {
    $ViewOptionsIndex | Where-Object {
        -not ($_.ContainsKey('Visible')) -or $_.Visible
    }
}

function Get-ViewOptionDefinition {
    param([Parameter(Mandatory)][string]$Id)
    $ViewOptionsIndex | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

<#
    Estado actual de una opción de vista.

        if (Get-ViewOption 'badges') { ... }

    Una Id desconocida devuelve $false en lugar de fallar: así un
    componente que pregunte por una opción ya retirada del índice
    simplemente deja de enseñar esa parte.
#>
function Get-ViewOption {
    param([Parameter(Mandatory)][string]$Id)

    $definition = Get-ViewOptionDefinition $Id
    if (-not $definition) { return $false }

    [bool](Get-AppSetting (Get-ViewOptionKey $Id) -Default $definition.Default)
}

# Guarda el nuevo estado en %APPDATA%\OptimizadorPC\settings.json.
function Set-ViewOption {
    param([Parameter(Mandatory)][string]$Id, [bool]$Value)
    Set-AppSetting (Get-ViewOptionKey $Id) $Value
}

# ---- fin incluido: ui/Index/ViewOptionsIndex.ps1 ----

# ---- 4. Lógica de sistema ----
# Todo lo que habla con Windows vive en core/, fuera de ui/, y no
# conoce la interfaz. Solo define funciones, así que podría ir en
# cualquier punto; está aquí porque es la frontera entre lo que
# sabe de Windows y lo que sabe de la pantalla.
# ---- inicio incluido: core/Diagnostics/Log.ps1 ----
# ============================================================
# core/Diagnostics/Log.ps1
# Registro de actividad: qué ha hecho el programa y cuándo.
#
# Vive en core/ porque es información del sistema, no de la
# interfaz: aquí no hay ni un control de WPF. Quien quiera
# enseñarlo -hoy ui/Components/Shell/LogPanel.ps1- pide las entradas
# con Get-AppLog y las pinta como le parezca.
#
# Dos reglas de la casa, las mismas que el resto de core/:
#
#   1. NADA lanza una excepción hacia arriba. Si no se puede
#      escribir el archivo de volcado se devuelve $null; apuntar
#      lo que pasa jamás debe tumbar lo que estaba pasando.
#
#   2. Se guardan HECHOS, no frases traducidas. El campo Status
#      lleva una palabra en inglés ('read', 'no access'...) que
#      la interfaz pasa por T; así el idioma se decide al pintar
#      y el mismo registro sirve para los dos.
#
# El buffer es circular y vive en memoria: al cerrar se pierde,
# salvo que se haya volcado con Export-AppLog.
# ============================================================

# Tope de entradas guardadas. Al pasarse se van tirando las más
# viejas y se cuentan aparte, para poder decir "faltan N".
$AppLogCapacity = 1000

$AppLogEntries = New-Object System.Collections.Generic.List[object]
$AppLogDropped = 0

<#
    Apunta una línea en el registro de actividad.

        Write-AppLog -Source 'registry' -Status 'read' `
                     -Message 'HKEY_LOCAL_MACHINE\...\Valor' `
                     -Detail  '5 (0x00000005) - DWord - 0,4 ms'

    Message   La línea principal. Es TEXTO TÉCNICO -rutas, nombres
              de valor, cifras- y por eso no se traduce.
    Status    Palabra corta en inglés para la etiqueta de color.
              La interfaz la pasa por T; $null la deja sin etiqueta.
    Detail    Segunda línea gris, opcional.
    Level     'info' | 'warn' | 'error'. Decide el color.
    Source    De dónde viene: 'registry', 'app'...

    No devuelve nada: se llama desde sitios que están calculando
    otra cosa y un valor suelto se colaría en su salida.
#>
function Write-AppLog {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('info', 'warn', 'error')][string]$Level = 'info',
        [string]$Source = 'app',
        [string]$Status,
        [string]$Detail
    )

    $AppLogEntries.Add([PSCustomObject]@{
        Time    = [DateTime]::Now
        Level   = $Level
        Source  = $Source
        Status  = $Status
        Message = $Message
        Detail  = $Detail
    })

    # Buffer circular: si se pasa del tope, fuera la más vieja.
    while ($AppLogEntries.Count -gt $AppLogCapacity) {
        $AppLogEntries.RemoveAt(0)
        $script:AppLogDropped++
    }
}

<#
    Entradas guardadas, de la más vieja a la más nueva.

        Get-AppLog                       -> todas
        Get-AppLog -Source 'registry'    -> solo las del registro
        Get-AppLog -Level 'error'        -> solo los fallos
        Get-AppLog -Last 200             -> las 200 últimas

    Devuelve una copia: quien la reciba puede recorrerla con
    calma aunque entre tanto se apunte algo más.

    ENVUÉLVELO EN @(): al devolverlo, PowerShell desenrolla el
    array, así que con una sola entrada llega el objeto pelado.
    Es la misma convención que @($Category.Items) por todo el
    proyecto.
#>
function Get-AppLog {
    param([string]$Source, [string]$Level, [int]$Last = 0)

    # ToArray() y no @($AppLogEntries): una List[object] creada con
    # New-Object viene envuelta en un PSObject y el operador @()
    # revienta con "los tipos de argumentos no coinciden", en 5.1 y
    # en 7 (ver la regla 19 de CLAUDE.md).
    $items = $AppLogEntries.ToArray()
    if ($Source) { $items = @($items | Where-Object { $_.Source -eq $Source }) }
    if ($Level)  { $items = @($items | Where-Object { $_.Level  -eq $Level }) }

    if ($Last -gt 0 -and $items.Count -gt $Last) {
        $items = @($items[($items.Count - $Last)..($items.Count - 1)])
    }

    $items
}

function Get-AppLogCount { $AppLogEntries.Count }

# Cuántas se han tirado por llenarse el buffer.
function Get-AppLogDropped { $AppLogDropped }

function Clear-AppLog {
    $AppLogEntries.Clear()
    $script:AppLogDropped = 0
}

# ---- Volcado a texto ----------------------------------------

<#
    Una entrada como línea de archivo:

        2026-09-03 20:14:03.118  INFO   registry  [read] HKEY_...\Valor  |  5 - DWord - 0,4 ms

    El archivo va siempre en inglés: es para pegarlo en un
    informe, no para leerlo en pantalla.
#>
function Format-AppLogLine {
    param([Parameter(Mandatory)]$Entry)

    $line = '{0:yyyy-MM-dd HH:mm:ss.fff}  {1,-5}  {2,-9}' -f $Entry.Time, $Entry.Level.ToUpper(), $Entry.Source
    if ($Entry.Status)  { $line += '  [{0}]' -f $Entry.Status }
    if ($Entry.Message) { $line += '  {0}'   -f $Entry.Message }
    if ($Entry.Detail)  { $line += '  |  {0}' -f $Entry.Detail }
    $line
}

# Todo el registro como un único texto, con cabecera.
function Format-AppLogText {
    # El resumen se arma fuera del Add(): dentro de los paréntesis
    # de un método, la coma separa ARGUMENTOS, así que el -f se
    # quedaría solo con el primero y {1} se saldría de la lista.
    $summary = 'Entries: {0}' -f $AppLogEntries.Count
    if ($AppLogDropped -gt 0) { $summary += ' (+{0} dropped)' -f $AppLogDropped }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Optimizador PC - activity log')
    $lines.Add('Generated: {0:yyyy-MM-dd HH:mm:ss}' -f [DateTime]::Now)
    $lines.Add($summary)
    $lines.Add('')

    foreach ($entry in $AppLogEntries) { $lines.Add((Format-AppLogLine $entry)) }
    $lines -join [Environment]::NewLine
}

# Junto a settings.json, y por el mismo motivo: el .exe es
# portable y su carpeta puede no admitir escritura.
function Get-AppLogFolder {
    Join-Path $env:APPDATA 'OptimizadorPC\logs'
}

<#
    Vuelca el registro a un archivo de texto.

        $ruta = Export-AppLog             -> %APPDATA%\...\logs\log-<fecha>.txt
        $ruta = Export-AppLog -Path 'C:\x.txt'

    Devuelve la ruta escrita, o $null si no se ha podido (sin
    permisos, disco lleno...). No lanza: quien llame decide qué
    contarle al usuario.
#>
function Export-AppLog {
    param([string]$Path)

    try {
        if (-not $Path) {
            $folder = Get-AppLogFolder
            $Path = Join-Path $folder ('log-{0:yyyyMMdd-HHmmss}.txt' -f [DateTime]::Now)
        }

        $folder = Split-Path -Parent $Path
        if ($folder -and -not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
        }

        # UTF-8 con BOM, que es lo que espera el Bloc de notas de
        # Windows al abrirlo con doble clic.
        [System.IO.File]::WriteAllText($Path, (Format-AppLogText), (New-Object System.Text.UTF8Encoding($true)))
        $Path
    }
    catch {
        $null
    }
}

# ---- fin incluido: core/Diagnostics/Log.ps1 ----
# ---- inicio incluido: core/Registry/CategoryState.ps1 ----
# ============================================================
# core/Registry/CategoryState.ps1
# Vuelca en los ajustes lo que hay de verdad en el equipo.
#
# Es el puente entre core/Registry/Reader.ps1 (lee el sistema) y los
# datos de ui/Data/Categories/: recorre las claves declaradas en el
# campo -Registry de cada ajuste y rellena su Current.
#
# Sigue sin saber de interfaz. Para poder enseñar una barra de
# progreso acepta un scriptblock -OnProgress al que va avisando;
# quién lo pinte es asunto de quien llame.
#
# SOLO LECTURA: aquí no se escribe nada en el registro.
# ============================================================

<#
    Lee del equipo todas las claves de una categoría y actualiza
    en el sitio los campos de cada una:

        Current   texto ya formateado, o $null si no se pudo leer
        State     'read' | 'missing' | 'denied' | 'badpath'
        Status    'optimized' | 'factory' | 'custom' | 'unknown'

    Y, con sus claves ya leídas, deja también el Status de cada
    ajuste: en qué estado ha quedado comparando lo leído con lo
    declarado (ver core/Registry/SettingStatus.ps1).

    El Current que venga escrito en ui/Data/Categories/ se ignora: el
    valor bueno es el del equipo.

    Una categoría cuyos ajustes no declaren claves -hoy, todas
    menos Regedit- sale por la puerta de atrás sin hacer nada, así
    que se puede llamar siempre sin preguntar de cuál se trata.

        Update-CategoryRegistryState -Category $cat -OnProgress {
            param($Done, $Total) Set-ProgressStrip ...
        }

    Devuelve cuántas claves ha leído.
#>
function Update-CategoryRegistryState {
    param(
        [Parameter(Mandatory)]$Category,
        [scriptblock]$OnProgress
    )

    $total = Get-CategoryRegistryKeyCount $Category
    if ($total -eq 0) { return 0 }

    # Cabecera del bloque en el registro de actividad: sin ella,
    # las lecturas de una sección y las de la siguiente saldrían
    # seguidas y no se sabría dónde empieza cada visita.
    Write-AppLog -Source 'registry' -Level 'info' -Status 'reading' `
        -Message $Category.Name -Detail "$total keys"

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $states = @{}

    $done = 0
    if ($OnProgress) { & $OnProgress $done $total }

    # Se recorre ajuste por ajuste -y no una lista plana de claves-
    # porque en cuanto están leídas las suyas hay que decidir en qué
    # estado ha quedado ese ajuste.
    foreach ($setting in @($Category.Items)) {
        foreach ($key in @($setting.Registry)) {
            $result = Read-RegistryValue $key.Path $key.Name

            # Las claves de -Registry son hashtables, así que se
            # rellenan en el sitio y la tarjeta las lee tal cual.
            $key['State'] = $result.State
            if ($result.State -eq 'read') {
                $key['Current'] = Format-RegistryValue $result.Value $result.Kind $key.Display
            }
            else {
                $key['Current'] = $null
            }

            $states[$result.State] = 1 + [int]$states[$result.State]

            $done++
            if ($OnProgress) { & $OnProgress $done $total }
        }

        # Recomendado / de fábrica / a medida, comparando lo leído con
        # lo declarado (core/Registry/SettingStatus.ps1). Va aquí y no en la
        # interfaz para que se recalcule SIEMPRE que se lee: entrar en
        # la sección y refrescar pasan los dos por este mismo sitio.
        Update-SettingStatus $setting | Out-Null
    }

    $watch.Stop()

    # Resumen: cuántas de cada clase y cuánto ha costado. Es lo
    # que dice de un vistazo si una sección va lenta o si hay
    # claves que no se están pudiendo leer.
    $summary = ($states.Keys | Sort-Object | ForEach-Object { "$($states[$_]) $_" }) -join ' - '
    Write-AppLog -Source 'registry' -Level 'info' -Status 'done' `
        -Message $Category.Name `
        -Detail ('{0} - {1:N1} ms' -f $summary, $watch.Elapsed.TotalMilliseconds)

    $total
}

# Cuántas claves declara una categoría. La vista lo usa para saber
# si merece la pena enseñar la barra antes de ponerse a leer.
function Get-CategoryRegistryKeyCount {
    param([Parameter(Mandatory)]$Category)

    $n = 0
    foreach ($setting in @($Category.Items)) { $n += @($setting.Registry).Count }
    $n
}

# ---- fin incluido: core/Registry/CategoryState.ps1 ----
# ---- inicio incluido: core/Registry/Reader.ps1 ----
# ============================================================
# core/Registry/Reader.ps1
# Lectura del registro de Windows. SOLO LECTURA.
#
# Esta es la primera pieza fuera de ui/: aquí vive lo que habla
# con el sistema, y no sabe nada de ventanas, tarjetas ni temas.
# Si algo de este archivo necesita un control de WPF, está en el
# sitio equivocado.
#
# Dos reglas de la casa:
#
#   1. NADA lanza una excepción hacia arriba. Una clave protegida
#      o una ruta que no existe son respuestas válidas, no fallos:
#      la interfaz debe poder pintarlas, no caerse.
#
#   2. Se distingue "no está" de "no se pudo leer". La primera es
#      información -Windows usa su valor interno-, la segunda es
#      un problema de permisos. Enseñarlas igual sería mentir.
# ============================================================

$RegistryHives = @{
    'HKEY_LOCAL_MACHINE' = [Microsoft.Win32.RegistryHive]::LocalMachine
    'HKEY_CURRENT_USER'  = [Microsoft.Win32.RegistryHive]::CurrentUser
    'HKEY_CLASSES_ROOT'  = [Microsoft.Win32.RegistryHive]::ClassesRoot
    'HKEY_USERS'         = [Microsoft.Win32.RegistryHive]::Users
    'HKLM'               = [Microsoft.Win32.RegistryHive]::LocalMachine
    'HKCU'               = [Microsoft.Win32.RegistryHive]::CurrentUser
}

<#
    Lee un valor del registro y lo apunta en el registro de
    actividad (core/Diagnostics/Log.ps1), que es lo que enseña el botón de
    log de la barra de título.

        $r = Read-RegistryValue 'HKEY_LOCAL_MACHINE\SOFTWARE\...' 'MiValor'

    Devuelve siempre un objeto con:

        State   'read'     -> se leyó; Value y Kind traen el dato
                'missing'  -> la ruta o el valor no existen
                'denied'   -> existe pero no se pudo leer
                'badpath'  -> la raíz de la ruta no se reconoce
        Value   El dato en crudo, tal cual lo da .NET (ojo: un
                DWord llega como Int32 CON SIGNO).
        Kind    El RegistryValueKind, o $null.

    La lectura de verdad está en Read-RegistryValueRaw; aquí solo
    se cronometra y se apunta. Separarlas mantiene la lectura sin
    nada alrededor y deja apagar el rastro cambiando un archivo.
#>
function Read-RegistryValue {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Read-RegistryValueRaw -Path $Path -Name $Name
    $watch.Stop()

    Write-RegistryLog -Path $Path -Name $Name -Result $result -Ms $watch.Elapsed.TotalMilliseconds

    $result
}

<#
    Apunta una lectura en el registro de actividad.

    El Message es la clave consultada y el Detail lo que se
    encontró: los dos son texto técnico y no se traducen. Lo
    único traducible es el Status, y por eso viaja como palabra
    suelta en inglés (ver core/Diagnostics/Log.ps1).

    Que un valor no exista NO es un fallo -Windows está usando su
    valor interno-, así que sale como aviso y no como error. Sin
    acceso o con una raíz inventada sí lo son.
#>
function Write-RegistryLog {
    param([string]$Path, [string]$Name, $Result, [double]$Ms)

    $took = '{0:N1} ms' -f $Ms

    switch ($Result.State) {
        'read' {
            Write-AppLog -Source 'registry' -Level 'info' -Status 'read' `
                -Message "$Path\$Name" `
                -Detail ('{0} - {1} - {2}' -f (Format-LogValue $Result.Value $Result.Kind), $Result.Kind, $took)
        }
        'missing' {
            Write-AppLog -Source 'registry' -Level 'warn' -Status 'not set' `
                -Message "$Path\$Name" -Detail $took
        }
        'denied' {
            Write-AppLog -Source 'registry' -Level 'error' -Status 'no access' `
                -Message "$Path\$Name" -Detail $took
        }
        default {
            Write-AppLog -Source 'registry' -Level 'error' -Status 'unknown root key' `
                -Message "$Path\$Name" -Detail $took
        }
    }
}

<#
    El valor tal y como se apunta en el log. A diferencia de la
    tarjeta -que enseña decimal o hexadecimal según pida cada
    clave con su campo Display- aquí no hay quien lo pida, así
    que de un número se ponen las dos formas:

        5 (0x00000005)

    Los textos largos se recortan: una MultiString puede traer
    cientos de líneas y el log es para leerlo de un vistazo.
#>
function Format-LogValue {
    param($Value, $Kind)

    $text = Format-RegistryValue $Value $Kind
    if ($null -eq $text) { return '' }

    if ($Kind -eq [Microsoft.Win32.RegistryValueKind]::DWord -or
        $Kind -eq [Microsoft.Win32.RegistryValueKind]::QWord) {
        $text += ' ({0})' -f (Format-RegistryValue $Value $Kind 'hex')
    }

    if ($text.Length -gt 120) { $text = $text.Substring(0, 117) + '...' }
    $text
}

# La lectura pelada, sin cronómetro ni rastro. Todo lo que dice
# la ayuda de Read-RegistryValue sobre los cuatro estados vale
# aquí: es esta función quien los decide.
#
# AllowEmptyString porque una ruta vacía tiene que salir como
# badpath y no como un error de enlace de parámetros: eso ocurre
# ANTES de entrar aquí, así que ni siquiera lo podríamos atrapar.
function Read-RegistryValueRaw {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $parts = $Path.Split('\', 2)
    if ($parts.Count -lt 2) { return (New-RegistryResult 'badpath') }

    $hive = $RegistryHives[$parts[0].ToUpper()]
    if (-not $hive) { return (New-RegistryResult 'badpath') }

    $base = $null
    $key = $null
    try {
        # Registry64 explícito: si el .exe se compilase a 32 bits,
        # HKLM\SOFTWARE se redirigiría solo a Wow6432Node y
        # estaríamos leyendo otras claves sin enterarnos.
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey($parts[1])
        if (-not $key) { return (New-RegistryResult 'missing') }

        $value = $key.GetValue($Name, $null)
        if ($null -eq $value) { return (New-RegistryResult 'missing') }

        New-RegistryResult 'read' $value $key.GetValueKind($Name)
    }
    catch [System.Security.SecurityException] {
        New-RegistryResult 'denied'
    }
    catch [System.UnauthorizedAccessException] {
        New-RegistryResult 'denied'
    }
    catch {
        New-RegistryResult 'denied'
    }
    finally {
        if ($key)  { $key.Dispose() }
        if ($base) { $base.Dispose() }
    }
}

function New-RegistryResult {
    param([string]$State, $Value = $null, $Kind = $null)
    [PSCustomObject]@{ State = $State; Value = $Value; Kind = $Kind }
}

<#
    Convierte a texto un valor leído, para poder enseñarlo.

    El caso que importa son los DWord: .NET los devuelve como
    Int32 CON SIGNO, así que NetworkThrottlingIndex = 0xFFFFFFFF
    llega como -1. Se reinterpreta sin signo para que coincida
    con lo que enseña el Editor del registro.

        Format-RegistryValue -1 DWord 'hex'  ->  '0xFFFFFFFF'
        Format-RegistryValue -1 DWord        ->  '4294967295'

    $As = 'hex' lo pide cada clave con su campo Display.
#>
function Format-RegistryValue {
    param($Value, $Kind, [string]$As = 'dec')

    if ($null -eq $Value) { return $null }

    switch ($Kind) {

        ([Microsoft.Win32.RegistryValueKind]::DWord) {
            $u = [System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([int32]$Value), 0)
            if ($As -eq 'hex') { '0x{0:X8}' -f $u } else { [string]$u }
        }

        ([Microsoft.Win32.RegistryValueKind]::QWord) {
            $u = [System.BitConverter]::ToUInt64([System.BitConverter]::GetBytes([int64]$Value), 0)
            if ($As -eq 'hex') { '0x{0:X16}' -f $u } else { [string]$u }
        }

        ([Microsoft.Win32.RegistryValueKind]::Binary) {
            ($Value | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
        }

        ([Microsoft.Win32.RegistryValueKind]::MultiString) {
            $Value -join '; '
        }

        default { [string]$Value }
    }
}

# ---- fin incluido: core/Registry/Reader.ps1 ----
# ---- inicio incluido: core/Registry/SettingStatus.ps1 ----
# ============================================================
# core/Registry/SettingStatus.ps1
# En qué estado está un ajuste, comparando lo que hay en el equipo
# con lo que declara ui/Data/Categories/.
#
# Cada clave de -Registry trae dos valores escritos a mano:
#
#     Recommended   el que propone el programa   ->  'optimized'
#     Default       el de fábrica de Windows     ->  'factory'
#
# y core/Registry/CategoryState.ps1 le añade el que acaba de leer del
# equipo (Current). Comparar los tres da el estado del ajuste:
#
#     'optimized'   el equipo tiene el valor que propone el programa
#     'factory'     tiene el de fábrica, o no tiene ninguno y Windows
#                   está usando el suyo interno
#     'custom'      no es ninguno de los dos: alguien lo ha tocado
#     'unknown'     no se ha podido mirar -sin permiso, raíz mala o
#                   todavía sin leer-. No se afirma nada.
#
# El estado se calcula SIEMPRE que se lee (ver CategoryState.ps1), así
# que entrar en la sección y pulsar refrescar lo dejan al día solos.
#
# Como todo lo de core/: no sabe de interfaz -devuelve palabras en
# inglés, sin traducir ni colores- y no lanza nunca.
# ============================================================

# Los cuatro estados, en el orden en que se enseñan. La interfaz los
# recorre en vez de escribirlos a mano.
$SettingStatusNames = @('optimized', 'factory', 'custom', 'unknown')

function Get-SettingStatusNames { $SettingStatusNames }

<#
    Un valor de registro escrito como texto, pasado a número. Si no
    lo parece, devuelve $null.

    Hace falta porque lo declarado y lo leído no tienen por qué venir
    escritos igual: '0xFFFFFFFF' y '4294967295' son el mismo DWord, y
    '-1' es como se escribe a mano ese mismo valor.
#>
function ConvertTo-RegistryNumber {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $t = $Text.Trim()

    try {
        if ($t -match '^0[xX][0-9a-fA-F]{1,16}$') { return [System.Convert]::ToUInt64($t.Substring(2), 16) }
        if ($t -match '^[0-9]{1,20}$')            { return [System.UInt64]::Parse($t) }

        # Un negativo declarado a mano es el mismo valor que se lee
        # sin signo: -1 en un DWord es 0xFFFFFFFF. Se reinterpreta
        # por bytes, no casteando, porque [uint32](-1) revienta.
        if ($t -match '^-[0-9]{1,19}$') {
            $n = [System.Int64]::Parse($t)
            if ($n -ge [System.Int32]::MinValue) {
                return [System.UInt64][System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([System.Int32]$n), 0)
            }
            return [System.BitConverter]::ToUInt64([System.BitConverter]::GetBytes($n), 0)
        }
    }
    catch { }

    $null
}

<#
    ¿Son el mismo valor?

    Si los dos lados parecen números -decimal, 0x... o negativo-, se
    comparan como números, que es lo que evita que '0x0000000A' y
    '10' pasen por distintos. Si no, como texto: sin espacios de más
    y sin distinguir mayúsculas.
#>
function Test-RegistryValueMatch {
    param([string]$Left, [string]$Right)

    if ([string]::IsNullOrEmpty($Left) -or [string]::IsNullOrEmpty($Right)) { return $false }

    $ln = ConvertTo-RegistryNumber $Left
    $rn = ConvertTo-RegistryNumber $Right
    if ($null -ne $ln -and $null -ne $rn) { return $ln -eq $rn }

    [string]::Equals($Left.Trim(), $Right.Trim(), [System.StringComparison]::OrdinalIgnoreCase)
}

<#
    El estado de UNA clave, comparando su Current -lo que se acaba de
    leer del equipo- con lo que declara ui/Data/Categories/.
#>
function Get-RegistryKeyStatus {
    param($Key)

    if (-not $Key) { return 'unknown' }

    # Sin nada declarado con lo que comparar no se puede decir en qué
    # estado está: 'custom' sería una acusación sin pruebas.
    if ([string]::IsNullOrEmpty([string]$Key.Recommended) -and
        [string]::IsNullOrEmpty([string]$Key.Default)) { return 'unknown' }

    # El valor no está puesto: Windows usa el suyo interno, así que el
    # equipo ESTÁ como salió de fábrica para este ajuste. No se compara
    # contra el Default declarado -que es solo el número que habría
    # que escribir para volver-, porque un valor ausente no es igual a
    # ninguno escrito.
    if ($Key.State -eq 'missing') { return 'factory' }

    # Sin permiso, raíz inventada o todavía sin leer.
    if ($Key.State -ne 'read') { return 'unknown' }

    # De fábrica se mira primero: si lo recomendado ya es lo de
    # fábrica, no hay nada aplicado y lo honesto es decir eso.
    if (Test-RegistryValueMatch $Key.Current $Key.Default)     { return 'factory' }
    if (Test-RegistryValueMatch $Key.Current $Key.Recommended) { return 'optimized' }
    'custom'
}

<#
    El estado de un ajuste ENTERO, a partir de todas sus claves:

        sin claves          ->  $null       no hay nada que mirar
        alguna sin leer     ->  'unknown'   no se puede afirmar nada
        todas de acuerdo    ->  ese estado
        unas y otras        ->  'custom'    aplicado a medias

    Hoy todos los ajustes de Regedit declaran una sola clave, pero la
    regla ya vale para los que declaren varias.
#>
function Get-SettingStatus {
    param($Setting)

    if (-not $Setting) { return $null }

    $keys = @($Setting.Registry)
    if ($keys.Count -eq 0) { return $null }

    $seen = @{}
    foreach ($key in $keys) {
        $status = Get-RegistryKeyStatus $key
        # Con una sola clave que no se haya podido leer, del conjunto
        # ya no se puede decir nada.
        if ($status -eq 'unknown') { return 'unknown' }
        $seen[$status] = $true
    }

    if ($seen.Count -eq 1) { return @($seen.Keys)[0] }

    # Unas de fábrica y otras optimizadas: el ajuste está a medias,
    # que es tanto como decir que lleva una combinación a medida.
    'custom'
}

<#
    Deja el estado escrito en el sitio: cada clave se queda con su
    Status y el ajuste con el suyo. Es lo que lee la interfaz.

    Devuelve el estado del ajuste.
#>
function Update-SettingStatus {
    param($Setting)

    if (-not $Setting) { return $null }

    foreach ($key in @($Setting.Registry)) { $key['Status'] = Get-RegistryKeyStatus $key }

    $status = Get-SettingStatus $Setting

    # Los ajustes salen de New-Setting, que ya reserva el campo. Lo
    # demás es para no lanzar si algún día llega otra cosa: un
    # PSCustomObject sin la propiedad se queja al asignarla.
    if ($Setting -is [hashtable])                   { $Setting['Status'] = $status }
    elseif ($Setting.PSObject.Properties['Status']) { $Setting.Status = $status }
    else { $Setting | Add-Member -NotePropertyName 'Status' -NotePropertyValue $status -Force }

    $status
}

# ---- fin incluido: core/Registry/SettingStatus.ps1 ----

# ---- 5. Datos: secciones, opciones e idiomas ----
# Se registran al cargarse, de ahí que vayan después del paso 2.
# Añadir una sección = crear su archivo; quitarla = borrarlo.
# ---- inicio incluido: ui/Data/Categories/Gaming.ps1 ----
# ------------------------------------------------------------
# Categoría: Gaming & Performance
# ------------------------------------------------------------

Register-Category @{
    Id          = 'gaming'
    Name        = 'Gaming & Performance'
    Icon        = 'Game'
    Accent      = 'Warn'
    AccentSoft  = 'WarnSoft'
    Badge       = 'NEW 16'
    Description = 'Processor, Graphics, Network, Security, ...'

    Recommended = 65
    Default     = 47
    Custom      = 2
    Total       = 112

    Items = @(
        New-Setting -Name 'Game Mode' `
            -Description 'Optimize your PC for play by turning things off in the background' `
            -Tags 'Recommended', 'Default' `
            -Value $true

        New-Setting -Name 'Enhance Pointer Precision' `
            -Description 'Adjust cursor speed based on movement velocity (mouse acceleration). Most competitive gamers disable this for consistent aiming in FPS games' `
            -Tags 'Recommended' `
            -Value $false

        New-Setting -Name 'Mouse Hover Time' `
            -Description 'Controls how long you must hover over an element before it activates (in milliseconds). Lower values make tooltips, menus, and hover effects appear faster. Default is 400ms' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Options '100ms', '200ms', '400ms (Default)', '600ms' `
            -Value '400ms (Default)' `
            -Badge 'NEW'

        New-Setting -Name 'Startup Delay for Apps' `
            -Description 'Delay startup applications by 10 seconds after boot to improve initial system responsiveness. Windows becomes usable faster, but your startup apps take longer to load' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false

        New-Setting -Name 'Background App Permissions' `
            -Description 'Control whether apps can run in the background via Group Policy. Force Deny removes per-app background settings from Windows Settings. Use User in Control if you need apps like Teams, Zoom, or WhatsApp' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Options 'User in Control', 'Force Allow', 'Force Deny' `
            -Value 'Force Deny' `
            -Badge 'NEW'
    )
}

# ---- fin incluido: ui/Data/Categories/Gaming.ps1 ----
# ---- inicio incluido: ui/Data/Categories/Notifications.ps1 ----
# ------------------------------------------------------------
# Categoría: Notifications
# ------------------------------------------------------------

Register-Category @{
    Id          = 'notifications'
    Name        = 'Notifications'
    Icon        = 'Bell'
    Accent      = 'Warn'
    AccentSoft  = 'WarnSoft'
    Badge       = $null
    Description = 'Additional Settings, System Notifications, Privacy Notifications, Security Notifications'

    Recommended = 7
    Default     = 9
    Custom      = 0
    Total       = 15

    Items = @(
        New-Setting -Name 'Windows Tips & Suggestions' `
            -Description 'Show occasional tips, tricks, and suggestions as you use Windows' `
            -Tags 'Recommended', 'Default' `
            -Value $false

        New-Setting -Name 'Lock Screen Suggestions' `
            -Description 'Show fun facts, tips, and other suggestions on the lock screen' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false
    )
}

# ---- fin incluido: ui/Data/Categories/Notifications.ps1 ----
# ---- inicio incluido: ui/Data/Categories/Power.ps1 ----
# ------------------------------------------------------------
# Categoría: Power
# ------------------------------------------------------------

Register-Category @{
    Id          = 'power'
    Name        = 'Power'
    Icon        = 'Power'
    Accent      = 'Success'
    AccentSoft  = 'SuccessSoft'
    Badge       = $null
    Description = 'Display, Hard Disk, Internet Explorer, Desktop Background Settings, ...'

    Recommended = 18
    Default     = 23
    Custom      = 2
    Total       = 34

    Items = @(
        New-Setting -Name 'High Performance Power Plan' `
            -Description 'Switch to the High Performance / Ultimate Performance power scheme' `
            -Tags 'Recommended', 'Default' `
            -Value $true

        New-Setting -Name 'USB Selective Suspend' `
            -Description 'Allow Windows to power down idle USB devices to save energy' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false

        New-Setting -Name 'Hibernation' `
            -Description 'Enable or disable hibernate mode and the hiberfil.sys reserved space' `
            -Tags 'Default' `
            -Value $true
    )
}

# ---- fin incluido: ui/Data/Categories/Power.ps1 ----
# ---- inicio incluido: ui/Data/Categories/Regedit.ps1 ----
# ------------------------------------------------------------
# Categoría: Regedit
# Todo lo de esta sección vive aquí. Para quitarla del programa,
# borra este archivo. Ver ui/Engine/CategoryRegistry.ps1 para el formato.
#
# Cada ajuste declara en -Registry las claves que toca:
#
#   Path / Name / Type   dónde está el valor
#   Recommended          lo que propone el programa
#   Default              el valor de fábrica de Windows
#   Display = 'hex'      enseñarlo como 0xFFFFFFFF y no en decimal
#
# NO se declara Current: lo rellena core/Registry/CategoryState.ps1 leyendo
# el equipo cada vez que se entra en la sección. Escribir en el
# registro sigue sin estar implementado.
#
# TAMPOCO se declaran -Tags. El estado que sale en la tarjeta
# -Optimizado / Recomendado de fábrica / Personalizado- se calcula
# comparando lo leído contra esos dos valores declarados, así que
# escribirlo a mano solo serviría para mentir. Ver
# core/Registry/SettingStatus.ps1.
#
# De ahí que Recommended y Default sean el dato importante de cada
# clave: si están mal, el estado sale mal.
# ------------------------------------------------------------

Register-Category @{
    Id          = 'regedit'
    Name        = 'Regedit'
    Icon        = 'Shield'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    # Sin Badge: lo cuenta Register-Category a partir de los Items
    # que llevan -Badge 'NEW'. Marcar uno más sube el número solo.
    Description = 'Windows registry keys'

    Recommended = 29
    Default     = 59
    Custom      = 0
    Total       = 88

    Items = @(
        New-Setting -Name 'Network Throttling Mechanism' `
            -Description 'Limits network packet processing (NDIS) to 10 packets' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
                   Name = 'NetworkThrottlingIndex'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0xFFFFFFFF'; Default = '0x00000000' }
            )
       
    )
}

# ---- fin incluido: ui/Data/Categories/Regedit.ps1 ----
# ---- inicio incluido: ui/Data/Categories/Sound.ps1 ----
# ------------------------------------------------------------
# Categoría: Sound
# Ejemplo de categoría mínima: un solo ajuste y sin distintivo.
# ------------------------------------------------------------

Register-Category @{
    Id          = 'sound'
    Name        = 'Sound'
    Icon        = 'Volume'
    Accent      = 'Success'
    AccentSoft  = 'SuccessSoft'
    Description = 'System Sounds'

    Default     = 7
    Total       = 7

    Items = @(
        New-Setting -Name 'Startup Sound' `
            -Description 'Play the Windows startup sound when signing in' `
            -Tags 'Default' `
            -Value $true
    )
}

# ---- fin incluido: ui/Data/Categories/Sound.ps1 ----
# ---- inicio incluido: ui/Data/Categories/Update.ps1 ----
# ------------------------------------------------------------
# Categoría: Update
# ------------------------------------------------------------

Register-Category @{
    Id          = 'update'
    Name        = 'Update'
    Icon        = 'Sync'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    Badge       = 'NEW 1'
    Description = 'Update Policy, Delivery & Store, Update Behavior'

    Recommended = 5
    Default     = 8
    Custom      = 1
    Total       = 12

    Items = @(
        New-Setting -Name 'Delivery Optimization (P2P)' `
            -Description 'Allow Windows to download/upload updates to and from other PCs on the internet' `
            -Tags 'Recommended', 'Default' `
            -Value $false

        New-Setting -Name 'Auto-Restart With Active Sessions' `
            -Description 'Allow Windows Update to restart the PC automatically while you are logged in' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false
    )
}

# ---- fin incluido: ui/Data/Categories/Update.ps1 ----
# ---- inicio incluido: ui/Data/Lang/es.ps1 ----
# ------------------------------------------------------------
# Español
#
# Diccionario "texto en inglés" -> "texto en español".
# La clave es el texto tal cual aparece en el código fuente; si
# falta una entrada, se muestra el inglés en vez de fallar.
#
# Para saber qué queda por traducir, navega por la aplicación y
# después ejecuta:  Get-MissingTranslations 'es'
#
# Para crear otro idioma, copia este archivo con otro código y
# añade su línea en ui/Index/LanguageIndex.ps1.
# ------------------------------------------------------------

Register-Language 'es' @{

    # ---- Menú lateral ----
    'Software'   = 'Programas'
    'Optimize'   = 'Optimizar'
    'Customize'  = 'Personalizar'
    'Advanced'   = 'Avanzado'
    'Settings'   = 'Ajustes'
    'More'       = 'Más'

    # ---- Barra de título ----
    'Normal'         = 'Normal'
    'Builder'        = 'Constructor'
    'Config Review'  = 'Revisar configuración'
    'Change theme'   = 'Cambiar tema'
    'Help'           = 'Ayuda'
    'Hide the menu'  = 'Ocultar el menú'
    'Show the menu'  = 'Mostrar el menú'
    'Activity log'   = 'Registro de actividad'

    # ---- Registro de actividad (ui/Components/Shell/LogPanel.ps1) ----
    # Solo el marco. Las líneas del log no se traducen: son rutas
    # del registro y valores, texto técnico para copiar y pegar.
    'What the app has read from your system in this session' = 'Lo que el programa ha leído de tu sistema en esta sesión'
    'Close the log'   = 'Cerrar el registro'
    'Open the log in its own window' = 'Abrir el registro en su propia ventana'
    'Dock the log back into the main window' = 'Volver a acoplar el registro en la ventana principal'
    'Minimize'        = 'Minimizar'
    'Maximize'        = 'Maximizar'
    'Clear'           = 'Vaciar'
    'Save to file'    = 'Guardar en archivo'
    '{0} entries'     = '{0} entradas'
    'Newest at the bottom' = 'Lo más reciente, abajo'
    'Nothing logged yet'   = 'Todavía no hay nada apuntado'
    'Nothing has been read from your system yet' = 'Todavía no se ha leído nada de tu sistema'
    'Open a section and its registry keys will show up here' = 'Entra en una sección y sus claves del registro saldrán aquí'
    'Showing the last {0} of {1} entries' = 'Se enseñan las {0} últimas de {1} entradas'
    'Only the last {0} entries are kept; {1} older ones were discarded' = 'Solo se guardan las {0} últimas entradas; se han descartado {1} más antiguas'
    'Saved to {0}'    = 'Guardado en {0}'
    'The log file could not be written' = 'No se ha podido escribir el archivo del registro'

    # Etiquetas de estado de cada línea. Las cuatro primeras son
    # las mismas que usa el detalle técnico de las tarjetas.
    'read'    = 'leído'
    'reading' = 'leyendo'
    'done'    = 'hecho'
    'info'    = 'info'
    'warn'    = 'aviso'
    'error'   = 'fallo'

    # ---- Pantalla principal ----
    'Optimizations' = 'Optimizaciones'
    'Optimize your Windows system performance, privacy and power usage' = 'Ajusta el rendimiento, la privacidad y el consumo de tu sistema'
    'Search optimizations...' = 'Buscar optimizaciones...'
    'Quick Actions' = 'Acciones rápidas'
    'View'          = 'Vista'

    # ---- Menú del botón "Vista" ----
    'Show on screen'    = 'Mostrar en pantalla'
    'Technical details' = 'Detalles técnicos'
    'Show the registry keys each setting touches' = 'Enseñar las claves del registro que toca cada ajuste'
    'New badges'        = 'Insignias de nuevo'
    "Show the red 'NEW' tags on sections and settings" = "Enseñar las etiquetas rojas de 'nuevo' en secciones y ajustes"

    # ---- Insignias ----
    'NEW' = 'NUEVO'

    # ---- Detalles técnicos ----
    'Copy the registry path' = 'Copiar la ruta del registro'
    'Copy the value name'    = 'Copiar el nombre del valor'
    'Copied'                 = 'Copiado'
    'Select it or press Ctrl+C to copy it' = 'Selecciónalo o pulsa Ctrl+C para copiarlo'
    'Path:'            = 'Ruta:'
    'Value:'           = 'Valor:'
    'Current:'         = 'Actual:'
    'Recommended:'     = 'Recomendado:'
    'Factory:'         = 'Predeterminado:'
    'Open this key in Registry Editor' = 'Abrir esta clave en el Editor del registro'
    'Reading the registry...' = 'Leyendo el registro...'
    'not set'          = 'sin definir'
    'not read'         = 'sin leer'
    'no access'        = 'sin acceso'
    'unknown root key' = 'raíz desconocida'
    'No registry keys declared for this setting yet.' = 'Este ajuste todavía no declara ninguna clave del registro.'

    # ---- Pantalla de detalle ----
    '{0} settings' = '{0} ajustes'
    'Refresh'      = 'Refrescar'
    'Read the registry keys again' = 'Volver a leer las claves del registro'
    'This section does not read the registry yet' = 'Esta sección todavía no lee el registro'
    'Updated {0}'  = 'Actualizado {0}'
    'Registry values updated' = 'Valores del registro actualizados'
    'Back to the list' = 'Volver a la lista'

    # ---- Etiquetas de clasificación ----
    'Recommended' = 'Recomendado'
    'Default'     = 'De fábrica'
    'Custom'      = 'Personalizado'

    # ---- Estado real de un ajuste (core/Registry/SettingStatus.ps1) ----
    # 'Custom' sale un poco más arriba: es la misma palabra.
    'Optimized'           = 'Optimizado'
    'Factory recommended' = 'Recomendado de fábrica'
    'Unknown'             = 'Desconocido'

    'The registry value is the one this program recommends' = 'El valor del registro es el que recomienda el programa'
    'The registry value is the Windows factory one'         = 'El valor del registro es el de fábrica de Windows'
    'The registry value is neither the recommended nor the factory one' = 'El valor del registro no es ni el recomendado ni el de fábrica'
    'The registry value could not be read'                  = 'No se ha podido leer el valor del registro'

    'Optimized: {0} of {1}'           = 'Optimizados: {0} de {1}'
    'Factory recommended: {0} of {1}' = 'Recomendados de fábrica: {0} de {1}'
    'Unknown: {0} of {1}'             = 'Desconocidos: {0} de {1}'

    # ---- Indicadores ----
    'On'  = 'Sí'
    'Off' = 'No'
    'Recommended value'         = 'Valor recomendado'
    'Windows factory value'     = 'Valor de fábrica de Windows'
    'Recommended: {0} of {1}'   = 'Recomendados: {0} de {1}'
    'Factory defaults: {0} of {1}' = 'De fábrica: {0} de {1}'
    'Customised: {0} of {1}'    = 'Personalizados: {0} de {1}'
    'No recommended settings'   = 'Sin ajustes recomendados'

    # ---- Bloqueo ----
    'Locked section' = 'Sección bloqueada'
    'Its settings are shown for reference only: they cannot be changed. To unlock it, set Locked = $false in ui/Index/CategoryIndex.ps1.' = 'Sus ajustes se muestran solo como consulta: no se pueden modificar. Para desbloquearla, pon Locked = $false en ui/Index/CategoryIndex.ps1.'
    'Locked section: you can look, not change' = 'Sección bloqueada: se puede consultar, no modificar'
    '{0}: locked' = '{0}: bloqueado'

    # ---- Pantalla de Settings ----
    'Preferences for the application itself' = 'Preferencias del propio programa'
    'Saved automatically' = 'Se guarda solo'
    'General'    = 'General'
    'Appearance' = 'Apariencia'
    'Language'   = 'Idioma'
    'Language used across the whole interface' = 'Idioma de toda la interfaz'
    'Theme'      = 'Tema'
    'Light or dark colour scheme' = 'Combinación de colores clara u oscura'
    'Light'      = 'Claro'
    'Dark'       = 'Oscuro'

    # ============================================================
    # CONTENIDO: nombres y descripciones de las secciones
    # ============================================================

    'Regedit'               = 'Regedit'
    'Windows registry keys' = 'Claves de registro de Windows'

    'Power' = 'Energía'
    'Display, Hard Disk, Internet Explorer, Desktop Background Settings, ...' = 'Pantalla, disco duro, Internet Explorer, fondo de escritorio, ...'

    'Gaming & Performance' = 'Juegos y rendimiento'
    'Processor, Graphics, Network, Security, ...' = 'Procesador, gráficos, red, seguridad, ...'

    'Update' = 'Actualizaciones'
    'Update Policy, Delivery & Store, Update Behavior' = 'Directivas de actualización, distribución y Store, comportamiento'

    'Notifications' = 'Notificaciones'
    'Additional Settings, System Notifications, Privacy Notifications, Security Notifications' = 'Ajustes adicionales, notificaciones del sistema, de privacidad y de seguridad'

    'Sound' = 'Sonido'
    'System Sounds' = 'Sonidos del sistema'

    # ============================================================
    # CONTENIDO: ajustes
    # ============================================================

    # ---- Regedit ----
    'Network Throttling Mechanism' = 'Mecanismo de limitación de red'
    'Limits network packet processing (NDIS) to 10 packets' = 'Limita el procesamiento de paquetes de red (NDIS) a 10 paquetes'

    'User Account Control Level' = 'Nivel del Control de cuentas de usuario'
    'Controls UAC notification level and secure desktop behavior' = 'Controla el nivel de aviso del UAC y el comportamiento del escritorio seguro'
    'Always notify' = 'Notificar siempre'
    'Notify when apps try to make changes' = 'Notificar cuando una aplicación intente hacer cambios'
    'Notify me only (no dim)' = 'Notificar sin atenuar el escritorio'
    'Never notify' = 'No notificar nunca'

    'Workplace Join Message Prompts' = 'Avisos de unión al trabajo'
    "Show 'Allow my organization to manage my device' prompts throughout Windows" = "Mostrar los avisos de 'Permitir que mi organización administre mi dispositivo' por todo Windows"

    'BitLocker Auto Encryption' = 'Cifrado automático de BitLocker'
    'Controls whether Windows can automatically encrypt drives with BitLocker. Has no effect if BitLocker encryption is already active on your device' = 'Controla si Windows puede cifrar unidades automáticamente con BitLocker. No tiene efecto si el cifrado ya está activo en tu equipo'

    'WiFi-Sense' = 'Sensor WiFi'
    'Allow sharing WiFi passwords with contacts and automatically connecting to suggested open hotspots' = 'Permitir compartir contraseñas WiFi con tus contactos y conectarse solo a las redes abiertas sugeridas'

    'Automatic Maintenance' = 'Mantenimiento automático'
    'Choose if Windows should run automatic system maintenance tasks during idle time' = 'Elige si Windows debe ejecutar tareas de mantenimiento cuando el equipo está inactivo'

    'Windows Error Reporting' = 'Informe de errores de Windows'
    'Choose if Windows should collect and send crash reports and error information to Microsoft' = 'Elige si Windows debe recopilar y enviar a Microsoft los informes de fallos y errores'

    # ---- Power ----
    'High Performance Power Plan' = 'Plan de energía de alto rendimiento'
    'Switch to the High Performance / Ultimate Performance power scheme' = 'Cambiar al plan de energía de alto rendimiento o rendimiento máximo'

    'USB Selective Suspend' = 'Suspensión selectiva de USB'
    'Allow Windows to power down idle USB devices to save energy' = 'Permitir que Windows apague los dispositivos USB inactivos para ahorrar energía'

    'Hibernation' = 'Hibernación'
    'Enable or disable hibernate mode and the hiberfil.sys reserved space' = 'Activar o desactivar la hibernación y el espacio reservado de hiberfil.sys'

    # ---- Gaming & Performance ----
    'Game Mode' = 'Modo de juego'
    'Optimize your PC for play by turning things off in the background' = 'Optimizar el equipo para jugar desactivando procesos en segundo plano'

    'Enhance Pointer Precision' = 'Mejorar la precisión del puntero'
    'Adjust cursor speed based on movement velocity (mouse acceleration). Most competitive gamers disable this for consistent aiming in FPS games' = 'Ajusta la velocidad del cursor según la del movimiento (aceleración del ratón). La mayoría de jugadores competitivos lo desactivan para apuntar de forma constante en los FPS'

    'Mouse Hover Time' = 'Tiempo de reposo del ratón'
    'Controls how long you must hover over an element before it activates (in milliseconds). Lower values make tooltips, menus, and hover effects appear faster. Default is 400ms' = 'Controla cuánto hay que mantener el ratón encima de un elemento antes de que reaccione (en milisegundos). Valores más bajos hacen que los mensajes emergentes y los menús aparezcan antes. El valor de fábrica es 400 ms'
    '100ms' = '100 ms'
    '200ms' = '200 ms'
    '400ms (Default)' = '400 ms (de fábrica)'
    '600ms' = '600 ms'

    'Startup Delay for Apps' = 'Retraso de los programas de inicio'
    'Delay startup applications by 10 seconds after boot to improve initial system responsiveness. Windows becomes usable faster, but your startup apps take longer to load' = 'Retrasa 10 segundos los programas de inicio para que el sistema responda antes. Windows se puede usar más rápido, pero tus programas tardan más en cargar'

    'Background App Permissions' = 'Permisos de aplicaciones en segundo plano'
    'Control whether apps can run in the background via Group Policy. Force Deny removes per-app background settings from Windows Settings. Use User in Control if you need apps like Teams, Zoom, or WhatsApp' = 'Controla mediante directivas de grupo si las aplicaciones pueden ejecutarse en segundo plano. "Denegar siempre" quita esa opción por aplicación de la Configuración de Windows. Usa "Decide el usuario" si necesitas Teams, Zoom o WhatsApp'
    'User in Control' = 'Decide el usuario'
    'Force Allow' = 'Permitir siempre'
    'Force Deny' = 'Denegar siempre'

    # ---- Update ----
    'Delivery Optimization (P2P)' = 'Optimización de distribución (P2P)'
    'Allow Windows to download/upload updates to and from other PCs on the internet' = 'Permitir que Windows descargue y envíe actualizaciones desde y hacia otros equipos de internet'

    'Auto-Restart With Active Sessions' = 'Reinicio automático con sesión iniciada'
    'Allow Windows Update to restart the PC automatically while you are logged in' = 'Permitir que Windows Update reinicie el equipo automáticamente con la sesión iniciada'

    # ---- Notifications ----
    'Windows Tips & Suggestions' = 'Consejos y sugerencias de Windows'
    'Show occasional tips, tricks, and suggestions as you use Windows' = 'Mostrar de vez en cuando consejos, trucos y sugerencias mientras usas Windows'

    'Lock Screen Suggestions' = 'Sugerencias en la pantalla de bloqueo'
    'Show fun facts, tips, and other suggestions on the lock screen' = 'Mostrar curiosidades, consejos y otras sugerencias en la pantalla de bloqueo'

    # ---- Sound ----
    'Startup Sound' = 'Sonido de inicio'
    'Play the Windows startup sound when signing in' = 'Reproducir el sonido de inicio de Windows al iniciar sesión'

    # ---- Búsqueda ----
    'Search' = 'Buscar'
    'Everything in the app, by name, description or registry key' = 'Todo lo que hay en la aplicación: por nombre, descripción o clave del registro'
    'See all {0} results'   = 'Ver los {0} resultados'
    '{0} results for "{1}"' = '{0} resultados de «{1}»'
    '1 result for "{0}"'    = '1 resultado de «{0}»'
    'Nothing matches "{0}"' = 'Nada coincide con «{0}»'
    'Try another word, or part of a registry path' = 'Prueba con otra palabra, o con un trozo de una ruta del registro'
    'Type to search' = 'Escribe para buscar'
    'Sections, settings, registry keys and their values' = 'Secciones, ajustes, claves del registro y sus valores'

    # Por qué ha salido cada resultado. Son las etiquetas, no los
    # datos: la ruta y el valor se enseñan tal cual, que para eso se
    # copian y se pegan.
    'Name'           = 'Nombre'
    'Description'    = 'Descripción'
    'Section'        = 'Sección'
    'Tags'           = 'Etiquetas'
    'Options'        = 'Opciones'
    'Value'          = 'Valor'
    'Registry path'  = 'Ruta del registro'
    'Registry value' = 'Valor del registro'
    'Type'           = 'Tipo'
    'Current value'  = 'Valor actual'
    'Factory'        = 'De fábrica'
    'Status'         = 'Estado'
    # 'Recommended' ya está más arriba, con las etiquetas de
    # clasificación: es la misma palabra.

}

# ---- fin incluido: ui/Data/Lang/es.ps1 ----
# ---- inicio incluido: ui/Data/Preferences/10-Language.ps1 ----
# ------------------------------------------------------------
# Opción: idioma de la interfaz
#
# Ejemplo de opción con lista dinámica: las opciones salen de
# ui/Index/LanguageIndex.ps1, así que añadir un idioma allí lo hace
# aparecer aquí sin tocar este archivo.
# ------------------------------------------------------------

Register-Preference @{
    Order       = 10
    Id          = 'language'
    Group       = 'General'
    Label       = 'Language'
    Description = 'Language used across the whole interface'
    Type        = 'Choice'

    # Los nombres de idioma no se traducen: van siempre en el suyo.
    TranslateOptions = $false

    Options = {
        Get-AvailableLanguages | ForEach-Object {
            # La etiqueta va en su propio idioma a propósito: quien
            # busca "Español" lo reconoce aunque la app esté en inglés.
            @{ Value = $_.Code; Label = $_.Label }
        }
    }

    Get = { Get-AppLanguage }

    Set = {
        param($Value)
        Set-AppLanguage $Value
        Set-AppSetting 'Language' $Value
        Update-UiLanguage      # repinta el menú y la pantalla actual
    }
}

# ---- fin incluido: ui/Data/Preferences/10-Language.ps1 ----
# ---- inicio incluido: ui/Data/Preferences/20-Theme.ps1 ----
# ------------------------------------------------------------
# Opción: tema claro / oscuro
#
# El botón de la barra de título hace lo mismo; los dos pasan por
# Set-AppTheme y por Set-AppSetting, así que el tema se recuerda
# se cambie desde donde se cambie.
# ------------------------------------------------------------

Register-Preference @{
    Order       = 20
    Id          = 'theme'
    Group       = 'Appearance'
    Label       = 'Theme'
    Description = 'Light or dark colour scheme'
    Type        = 'Choice'

    Options = @(
        @{ Value = 'Light'; Label = 'Light' }
        @{ Value = 'Dark';  Label = 'Dark' }
    )

    Get = { Get-AppTheme }

    Set = {
        param($Value)
        Set-AppTheme -Window (Get-AppWindow) -Name $Value
        Set-AppSetting 'Theme' $Value
        Sync-ThemeButton
    }
}

# ---- fin incluido: ui/Data/Preferences/20-Theme.ps1 ----

# ---- 6. Piezas: los controles concretos ----
# ---- inicio incluido: ui/Components/Cards/CategoryCard.ps1 ----
# ============================================================
# Componente: tarjeta de categoría
#
# Es cada una de las filas de la pantalla principal. Estructura
# en 4 columnas:
#
#   [icono] [nombre + badge + descripción] [píldoras] [ >]
#
# Al hacer clic abre el detalle de esa categoría.
# ============================================================

function New-CategoryCard {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 18, 15, 20, 15

    # La tarjeta se eleva al pasar el ratón, y en WPF eso mueve también
    # su zona sensible. Por eso quien oye al ratón -y quien recibe el
    # clic- es el envoltorio quieto que la sostiene, no ella misma:
    # es lo que devuelve Add-HoverLift (ver ui/Design/Theme.ps1).
    $slot = Add-HoverLift $card
    $slot.Cursor = 'Hand'

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto', 'Auto'

    # --- columna 0: icono ---
    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 44
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 16, 0
    Add-ToColumn $grid $tile 0

    # --- columna 1: nombre, badge y descripción ---
    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 14.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    # La insignia se apaga desde el botón "Vista" de la cabecera.
    if ($Category.Badge -and (Get-ViewOption 'badges')) {
        $nameRow.Children.Add((New-Badge $Category.Badge)) | Out-Null
    }

    # Candado si la sección está bloqueada en ui/Index/CategoryIndex.ps1.
    if ($Category.Locked) {
        $lock = New-Icon 'Lock' 12 'TextFaint'
        $lock.Margin = New-Object System.Windows.Thickness 9, 1, 0, 0
        $lock.ToolTip = T 'Locked section: you can look, not change'
        $nameRow.Children.Add($lock) | Out-Null
    }

    $text.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $Category.Description
    $desc.FontSize = 12
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 4, 24, 0
    Set-TextFg $desc 'TextMuted'
    $text.Children.Add($desc) | Out-Null

    Add-ToColumn $grid $text 1

    # --- columna 2: píldoras de estadísticas ---
    Add-ToColumn $grid (New-CategoryStats $Category) 2

    # --- columna 3: chevron ---
    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 16, 0, 2, 0
    Add-ToColumn $grid $chev 3

    $card.Child = $grid

    # La categoría viaja en el Tag: nada de closures (regla 4 de CLAUDE.md).
    #
    # Se abre con Show-View, NO llamando a la vista (regla 17): si se
    # llamara directamente, el enrutador seguiría creyendo que estamos
    # en la lista y cualquier repintado -cambiar de idioma, tocar una
    # casilla del botón "Vista"- saltaría de vuelta a ella.
    $slot.Tag = $Category
    $slot.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $s.Tag }
    })

    $slot
}

# Las tres píldoras de la derecha: Recommended / Default / Custom.
function New-CategoryStats {
    param($Category)

    $stats = New-Object System.Windows.Controls.StackPanel
    $stats.Orientation = 'Horizontal'
    $stats.VerticalAlignment = 'Center'

    $total = $Category.Total

    if ($Category.Recommended -gt 0) {
        $stats.Children.Add((New-Pill 'StarFill' "$($Category.Recommended)/$total" 'Success' 'SuccessSoft' `
            ((T 'Recommended: {0} of {1}') -f $Category.Recommended, $total))) | Out-Null
    } else {
        $stats.Children.Add((New-Pill 'Star' "0/$total" 'TextFaint' 'SurfaceSunken' `
            (T 'No recommended settings'))) | Out-Null
    }

    $stats.Children.Add((New-Pill 'Grid' "$($Category.Default)/$total" 'TextMuted' 'SurfaceSunken' `
        ((T 'Factory defaults: {0} of {1}') -f $Category.Default, $total))) | Out-Null

    if ($Category.Custom -gt 0) {
        $stats.Children.Add((New-Pill 'Sliders' "$($Category.Custom)/$total" 'Warn' 'WarnSoft' `
            ((T 'Customised: {0} of {1}') -f $Category.Custom, $total))) | Out-Null
    }

    $stats
}

# ---- fin incluido: ui/Components/Cards/CategoryCard.ps1 ----
# ---- inicio incluido: ui/Components/Cards/PreferenceCard.ps1 ----
# ============================================================
# Componente: tarjeta de preferencia
#
# Dibuja una opción de ui/Data/Preferences/. Mismo aspecto que las
# tarjetas de ajuste de una categoría, pero conectada a los
# scriptblocks Get y Set de la preferencia.
# ============================================================

function New-PreferenceCard {
    param($Window, $Preference)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')
    $card.Padding = New-Object System.Windows.Thickness 20, 15, 20, 16

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid '*', 'Auto'

    # ---- izquierda: título y explicación ----
    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = 'Center'

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T $Preference.Label
    $label.FontFamily = $Window.FindResource('DisplayFont')
    $label.FontWeight = 'SemiBold'
    $label.FontSize = 13.5
    Set-TextFg $label 'Text'
    $left.Children.Add($label) | Out-Null

    if ($Preference.Description) {
        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = T $Preference.Description
        $desc.FontSize = 11.5
        $desc.TextWrapping = 'Wrap'
        $desc.LineHeight = 17
        $desc.Margin = New-Object System.Windows.Thickness 0, 5, 30, 0
        Set-TextFg $desc 'TextMuted'
        $left.Children.Add($desc) | Out-Null
    }

    Add-ToColumn $grid $left 0
    Add-ToColumn $grid (New-PreferenceControl $Window $Preference) 1

    $card.Child = $grid
    $card
}

function New-PreferenceControl {
    param($Window, $Preference)

    $holder = New-Object System.Windows.Controls.StackPanel
    $holder.Orientation = 'Horizontal'
    $holder.VerticalAlignment = 'Center'

    switch ($Preference.Type) {

        'Choice' {
            $options = @(Get-PreferenceOptions $Preference)
            $current = & $Preference.Get

            $combo = New-Object System.Windows.Controls.ComboBox
            $combo.Style = $Window.FindResource('ModernComboStyle')
            $combo.Width = 220
            foreach ($option in $options) {
                if ($Preference.TranslateOptions) { $combo.Items.Add((T $option.Label)) | Out-Null }
                else                              { $combo.Items.Add($option.Label)     | Out-Null }
            }

            $index = 0
            for ($i = 0; $i -lt $options.Count; $i++) {
                if ($options[$i].Value -eq $current) { $index = $i }
            }
            $combo.SelectedIndex = $index

            # El Tag lleva lo necesario para resolver el cambio sin
            # closures (regla 4 de CLAUDE.md).
            $combo.Tag = [PSCustomObject]@{ Preference = $Preference; Options = $options }

            # El handler se engancha DESPUÉS de fijar la selección
            # inicial, o saltaría al construir la tarjeta.
            $combo.Add_SelectionChanged({
                param($s, $e)
                $info = $s.Tag
                if ($s.SelectedIndex -lt 0) { return }
                $value = $info.Options[$s.SelectedIndex].Value
                if ($value -eq (& $info.Preference.Get)) { return }
                & $info.Preference.Set $value
            })

            $holder.Children.Add($combo) | Out-Null
        }

        'Toggle' {
            $current = [bool](& $Preference.Get)

            $state = New-Object System.Windows.Controls.TextBlock
            if ($current) { $state.Text = T 'On' } else { $state.Text = T 'Off' }
            $state.FontSize = 11.5
            $state.FontWeight = 'SemiBold'
            $state.Width = 30
            $state.TextAlignment = 'Right'
            $state.VerticalAlignment = 'Center'
            $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
            Set-TextFg $state 'TextMuted'
            $holder.Children.Add($state) | Out-Null

            $toggle = New-ToggleSwitch -Window $Window -InitialState $current -Label $state
            # Se añade la preferencia al Tag que ya usa el interruptor
            # para su propio estado.
            $toggle.Tag | Add-Member -NotePropertyName Preference -NotePropertyValue $Preference -Force
            $toggle.Add_MouseLeftButtonUp({
                param($s, $e)
                & $s.Tag.Preference.Set $s.Tag.State
            })
            $holder.Children.Add($toggle) | Out-Null
        }
    }

    $holder
}

# ---- fin incluido: ui/Components/Cards/PreferenceCard.ps1 ----
# ---- inicio incluido: ui/Components/Cards/SearchResultCard.ps1 ----
# ============================================================
# Componente: resultado de búsqueda
#
# El mismo resultado se enseña de dos maneras:
#
#   New-SearchResultRow    fila estrecha, para el desplegable que
#                          cuelga de la caja de búsqueda
#   New-SearchResultCard   tarjeta completa, para la página de
#                          resultados
#
# Las dos dicen lo mismo: dónde vive el resultado, cómo se llama y
# POR QUÉ ha salido -"Ruta del registro: HKEY_LOCAL_MACHINE\..."-,
# que es lo que evita el "¿y esto por qué me lo enseña?" cuando la
# coincidencia está en un campo que no se ve.
#
# Pulsar lleva a la sección con el ajuste resaltado. El dato viaja
# en el Tag: nada de closures (regla 4 de CLAUDE.md).
# ============================================================

# Lo que se guarda en el Tag de cualquier cosa pulsable de aquí.
function New-SearchResultTag {
    param($Entry, $Popup)
    [PSCustomObject]@{ Category = $Entry.Category; Setting = $Entry.Setting; Popup = $Popup }
}

<#
    Abre el resultado que lleva el emisor en el Tag.

    Un resultado de sección lleva a la sección; uno de ajuste lleva a
    la sección Y le dice cuál resaltar, que es lo que hace que al
    buscar una clave del registro acabes mirándola directamente.
#>
function Open-SearchResult {
    param($Element)

    $info = $Element.Tag
    if (-not $info) { return }

    if ($info.Popup) { $info.Popup.IsOpen = $false }

    $destino = @{ Category = $info.Category }
    if ($info.Setting) { $destino['Highlight'] = $info.Setting }

    Show-View -Name 'Show-CategoryDetailView' -Arguments $destino
}

# El título del resultado: el ajuste, o la sección si la coincidencia
# es de la sección entera.
function Get-SearchResultTitle {
    param($Entry)
    if ($Entry.Setting) { return (T $Entry.Setting.Name) }
    T $Entry.Category.Name
}

# "Ruta del registro: HKEY_LOCAL_MACHINE\..." — el campo por el que
# ha encajado, con su etiqueta traducida y el dato tal cual.
function New-SearchMatchLine {
    param($Window, $Entry, [double]$Size = 11)

    $line = New-Object System.Windows.Controls.TextBlock
    $line.FontFamily = $Window.FindResource('MonoFont')
    $line.FontSize = $Size
    $line.TextTrimming = 'CharacterEllipsis'
    $line.Margin = New-Object System.Windows.Thickness 0, 4, 0, 0

    if (-not $Entry.Match) {
        $line.Visibility = 'Collapsed'
        return $line
    }

    $etiqueta = New-Object System.Windows.Documents.Run ((T $Entry.Match.Label) + ': ')
    Set-TextFg $etiqueta 'TextFaint'
    $line.Inlines.Add($etiqueta)

    $dato = New-Object System.Windows.Documents.Run $Entry.Match.Text
    Set-TextFg $dato 'TextMuted'
    $line.Inlines.Add($dato)

    $line
}

# ---- Fila del desplegable -----------------------------------

function New-SearchResultRow {
    param($Window, $Entry, $Popup)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 9
    $row.Padding = New-Object System.Windows.Thickness 10, 7, 10, 8
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $texts = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = Get-SearchResultTitle $Entry
    $title.FontSize = 12
    $title.FontWeight = 'SemiBold'
    $title.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $texts.Children.Add((New-SearchMatchLine $Window $Entry 10.5)) | Out-Null

    $row.Child = $texts

    $row.Tag = New-SearchResultTag $Entry $Popup
    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $row.Add_MouseLeftButtonUp({ param($s, $e) Open-SearchResult $s })

    $row
}

# ---- Tarjeta de la página -----------------------------------

function New-SearchResultCard {
    param($Window, $Entry)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('CardStyle')
    $card.Padding = New-Object System.Windows.Thickness 16, 13, 18, 14
    $card.Cursor = 'Hand'

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    # --- icono de la sección a la que pertenece ---
    $tile = New-IconTile $Entry.Category.Icon $Entry.Category.Accent $Entry.Category.AccentSoft 34
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
    Add-ToColumn $grid $tile 0

    # --- nombre, descripción y el porqué ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = Get-SearchResultTitle $Entry
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 13
    $title.FontWeight = 'SemiBold'
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $descripcion = $Entry.Category.Description
    if ($Entry.Setting) { $descripcion = $Entry.Setting.Description }

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $descripcion
    $desc.FontSize = 11.5
    $desc.TextTrimming = 'CharacterEllipsis'
    $desc.Margin = New-Object System.Windows.Thickness 0, 3, 20, 0
    Set-TextFg $desc 'TextMuted'
    $texts.Children.Add($desc) | Out-Null

    $texts.Children.Add((New-SearchMatchLine $Window $Entry)) | Out-Null

    Add-ToColumn $grid $texts 1

    # --- a la derecha, el estado si lo tiene, y el chevron ---
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'

    if ($Entry.Setting -and $Entry.Setting.Status) {
        $right.Children.Add((New-StatusTag $Entry.Setting.Status)) | Out-Null
    }

    $chev = New-Icon 'ChevronRight' 12 'TextFaint'
    $chev.Margin = New-Object System.Windows.Thickness 8, 0, 2, 0
    $right.Children.Add($chev) | Out-Null

    Add-ToColumn $grid $right 2

    $card.Child = $grid

    $card.Tag = New-SearchResultTag $Entry $null
    $card.Add_MouseLeftButtonUp({ param($s, $e) Open-SearchResult $s })

    $card
}

# ---- fin incluido: ui/Components/Cards/SearchResultCard.ps1 ----
# ---- inicio incluido: ui/Components/Cards/SettingCard.ps1 ----
# ============================================================
# Componente: tarjeta de ajuste
#
# Es cada una de las filas de la pantalla de detalle. Estructura
# en 2 columnas:
#
#   [nombre + badge / descripción / etiquetas]  [indicadores + control]
#
# El control de la derecha lo decide el campo Type del ajuste,
# que New-Setting deduce solo (ver ui/Engine/CategoryRegistry.ps1):
#     Toggle    -> interruptor animado
#     Dropdown  -> desplegable
#
# Debajo puede colgar el pie plegable de detalles técnicos, que
# construye ui/Components/Cards/TechnicalDetails.ps1. Sale o no según
# la opción 'technical' del botón "Vista"; la insignia del título
# hace lo propio con la opción 'badges'.
#
# La etiqueta de debajo del nombre sale del ESTADO REAL del ajuste
# -optimizado, de fábrica o a medida- cuando lo hay: lo calcula
# core/Registry/SettingStatus.ps1 comparando lo que se acaba de leer del
# registro con lo que declara ui/Data/Categories/. Los ajustes que
# todavía no declaran claves siguen enseñando sus -Tags escritas a
# mano, que es lo único que tienen.
# ============================================================

function New-SettingCard {
    param($Window, $Setting, [switch]$Locked, [switch]$Highlight)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')

    # Se llega aquí desde un resultado de búsqueda: la sección puede
    # tener veinte filas y hay que ver CUÁL es. El borde de acento se
    # pone como valor local, que gana al disparador de IsMouseOver del
    # estilo, así que la marca no se pierde al pasar el ratón.
    if ($Highlight) {
        $card.BorderThickness = New-Object System.Windows.Thickness 1.6
        Set-BoxLine $card 'Accent'
    }

    # El relleno va en la fila, no en la tarjeta: así la línea
    # separadora del pie llega de borde a borde.
    $stack = New-Object System.Windows.Controls.StackPanel

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 20, 15, 20, 16
    Add-GridColumns $grid '*', 'Auto'

    Add-ToColumn $grid (New-SettingInfo $Window $Setting) 0

    $control = New-SettingControl $Window $Setting
    if ($Locked) {
        # IsEnabled = $false corta la entrada de todo el subárbol,
        # así que el interruptor deja de responder al ratón.
        $control.IsEnabled = $false
        $control.Opacity = 0.45
        $card.ToolTip = T 'Locked section'
    }
    Add-ToColumn $grid $control 1

    $stack.Children.Add($grid) | Out-Null

    # El pie es de consulta, así que se enseña también en las
    # secciones bloqueadas.
    if (Get-ViewOption 'technical') {
        $stack.Children.Add((New-TechnicalDetails $Window $Setting)) | Out-Null
    }

    $card.Child = $stack
    $card
}

# Columna izquierda: nombre, descripción y etiquetas.
function New-SettingInfo {
    param($Window, $Setting)

    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Setting.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 13.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    if ($Setting.Badge -and (Get-ViewOption 'badges')) {
        $nameRow.Children.Add((New-Badge $Setting.Badge)) | Out-Null
    }
    $left.Children.Add($nameRow) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $Setting.Description
    $desc.FontSize = 11.5
    $desc.TextWrapping = 'Wrap'
    $desc.LineHeight = 17
    $desc.Margin = New-Object System.Windows.Thickness 0, 5, 30, 9
    Set-TextFg $desc 'TextMuted'
    $left.Children.Add($desc) | Out-Null

    # Etiquetas. Si el ajuste declara claves del registro, core/ le ha
    # dejado un Status leyendo el equipo (ver SettingStatus.ps1) y manda
    # ese: es UNO de los tres estados, y es un hecho. Las -Tags
    # declaradas a mano son la versión de mentira de lo mismo, así que
    # solo salen mientras no haya nada real que enseñar.
    $tags = New-Object System.Windows.Controls.StackPanel
    $tags.Orientation = 'Horizontal'

    if ($Setting.Status) {
        $tags.Children.Add((New-StatusTag $Setting.Status)) | Out-Null
    }
    else {
        foreach ($tag in $Setting.Tags) { $tags.Children.Add((New-Tag $tag)) | Out-Null }
    }

    $left.Children.Add($tags) | Out-Null

    $left
}

# Columna derecha: indicadores y el control que corresponda.
function New-SettingControl {
    param($Window, $Setting)

    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'

    # Indicadores: el valor actual coincide con el recomendado / el de
    # fábrica. Que es justo lo que dice el Status cuando lo hay, así
    # que ahí mandan los hechos y no las etiquetas declaradas -que
    # además solían salir las dos a la vez, lo cual era imposible-.
    if ($Setting.Status) {
        $isRecommended = $Setting.Status -eq 'optimized'
        $isFactory     = $Setting.Status -eq 'factory'
    }
    else {
        $isRecommended = $Setting.Tags -contains 'Recommended'
        $isFactory     = $Setting.Tags -contains 'Default'
    }

    if ($isRecommended) {
        $star = New-Icon 'StarFill' 13 'Success'
        $star.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        $star.ToolTip = T 'Recommended value'
        $right.Children.Add($star) | Out-Null
    }
    if ($isFactory) {
        $grid = New-Icon 'Grid' 13 'TextFaint'
        $grid.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
        $grid.ToolTip = T 'Windows factory value'
        $right.Children.Add($grid) | Out-Null
    }

    switch ($Setting.Type) {
        'Toggle' {
            $state = New-Object System.Windows.Controls.TextBlock
            if ($Setting.Value) { $state.Text = T 'On' } else { $state.Text = T 'Off' }
            $state.FontSize = 11.5
            $state.FontWeight = 'SemiBold'
            $state.Width = 24
            $state.TextAlignment = 'Right'
            $state.VerticalAlignment = 'Center'
            $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
            Set-TextFg $state 'TextMuted'
            $right.Children.Add($state) | Out-Null

            $toggle = New-ToggleSwitch -Window $Window -InitialState $Setting.Value -Label $state
            # Segundo manejador, además del que anima el interruptor:
            # tocar un ajuste vuelve a contar el resumen de la cabecera.
            # Hoy los números no se mueven porque las etiquetas son
            # estáticas; el enganche ya está puesto para cuando lo sean.
            $toggle.Add_MouseLeftButtonUp({ param($s, $e) Update-CategorySummary })
            $right.Children.Add($toggle) | Out-Null
        }
        'Dropdown' {
            $combo = New-Object System.Windows.Controls.ComboBox
            $combo.Style = $Window.FindResource('ModernComboStyle')
            $combo.Width = 262
            foreach ($opt in $Setting.Options) { $combo.Items.Add((T $opt)) | Out-Null }
            $combo.SelectedItem = T $Setting.Value
            # Enganchado DESPUÉS de fijar la selección inicial, o
            # saltaría al construir la tarjeta.
            $combo.Add_SelectionChanged({ param($s, $e) Update-CategorySummary })
            $right.Children.Add($combo) | Out-Null
        }
    }

    $right
}

# ---- fin incluido: ui/Components/Cards/SettingCard.ps1 ----
# ---- inicio incluido: ui/Components/Cards/TechnicalDetails.ps1 ----
# ============================================================
# Componente: detalle técnico de un ajuste
#
# La franja plegable del pie de cada tarjeta de ajuste. Enseña
# qué claves del registro toca ese ajuste y con qué valores:
#
#   ---------------------------------------------
#   (i) Detalles técnicos                       v
#   ---------------------------------------------
#      Claves de registro de Windows
#      [/]  Ruta:  HKEY_LOCAL_MACHINE\...  [c]   Actual: 5
#           Valor: ConsentPromptBehaviorAdmin [c] Recomendado: 0
#                                                Predeterminado: 5
#
# La ruta y el valor se pueden seleccionar con el ratón y copiar con
# Ctrl+C, y cada uno tiene su botón [c] al lado (ver New-MonoField).
#
# Los datos salen del campo Registry del ajuste (ver -Registry
# en New-Setting, ui/Engine/CategoryRegistry.ps1). Un ajuste que aún no
# lo declare enseña un aviso en su lugar, para que se vea que la
# fila existe pero le falta el dato.
#
# "Actual" es lo que se acaba de leer del equipo (lo rellena
# core/Registry/CategoryState.ps1); "Recomendado" y "Predeterminado" son
# los valores declarados, y son contra los que se compara para
# decidir en qué estado está el ajuste. Escribir en el registro
# sigue sin hacerse.
# ============================================================

function New-TechnicalDetails {
    param($Window, $Setting)

    $section = New-Object System.Windows.Controls.StackPanel

    # --- línea separadora, de borde a borde de la tarjeta ---
    $rule = New-Object System.Windows.Controls.Border
    $rule.Height = 1
    Set-BoxBg $rule 'Stroke'
    $section.Children.Add($rule) | Out-Null

    # --- cuerpo plegado (se construye ya, se enseña al pulsar) ---
    $body = New-TechnicalBody $Window $Setting
    $body.Visibility = 'Collapsed'

    # Segunda línea, entre la fila y el cuerpo: solo tiene sentido
    # con el cuerpo abierto, así que va y viene con él.
    $split = New-Object System.Windows.Controls.Border
    $split.Height = 1
    $split.Margin = New-Object System.Windows.Thickness 0, 0, 0, 14
    $split.Visibility = 'Collapsed'
    Set-BoxBg $split 'Stroke'

    # --- fila que pliega y despliega ---
    $header = New-Object System.Windows.Controls.Border
    $header.Padding = New-Object System.Windows.Thickness 20, 9, 18, 10
    $header.Cursor = 'Hand'
    $header.Background = [System.Windows.Media.Brushes]::Transparent

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    $icon = New-Icon 'Info' 13 'TextFaint'
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 9, 0
    Add-ToColumn $grid $icon 0

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T 'Technical details'
    $label.FontSize = 11.5
    $label.VerticalAlignment = 'Center'
    Set-TextFg $label 'TextMuted'
    Add-ToColumn $grid $label 1

    $chevron = New-Icon 'ChevronDown' 10 'TextFaint'
    Add-ToColumn $grid $chevron 2

    $header.Child = $grid

    $header.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $header.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    # Cuerpo, línea y chevron viajan en el Tag: nada de closures
    # (regla 4 de CLAUDE.md).
    $header.Tag = [PSCustomObject]@{ Body = $body; Split = $split; Chevron = $chevron }
    $header.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        if ($info.Body.Visibility -eq 'Visible') {
            $info.Body.Visibility = 'Collapsed'
            $info.Split.Visibility = 'Collapsed'
            $info.Chevron.Text = Glyph 'ChevronDown'
        }
        else {
            $info.Body.Visibility = 'Visible'
            $info.Split.Visibility = 'Visible'
            $info.Chevron.Text = Glyph 'ChevronUp'
            Start-EnterTransition $info.Body 170 6
        }
    })

    $section.Children.Add($header) | Out-Null
    $section.Children.Add($split)  | Out-Null
    $section.Children.Add($body)   | Out-Null
    $section
}

# El bloque que se despliega: título y una fila por clave.
function New-TechnicalBody {
    param($Window, $Setting)

    $body = New-Object System.Windows.Controls.StackPanel
    $body.Margin = New-Object System.Windows.Thickness 18, 0, 18, 16

    $strip = New-Object System.Windows.Controls.Border
    $strip.CornerRadius = New-Object System.Windows.CornerRadius 8
    $strip.Padding = New-Object System.Windows.Thickness 12, 7, 12, 8
    $strip.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    Set-BoxBg $strip 'SurfaceSunken'

    $stripText = New-Object System.Windows.Controls.TextBlock
    $stripText.Text = T 'Windows registry keys'
    $stripText.FontSize = 11.5
    $stripText.FontWeight = 'SemiBold'
    Set-TextFg $stripText 'TextMuted'
    $strip.Child = $stripText
    $body.Children.Add($strip) | Out-Null

    $keys = @($Setting.Registry)
    if ($keys.Count -eq 0) {
        $body.Children.Add((New-TechnicalPlaceholder)) | Out-Null
        return $body
    }

    foreach ($key in $keys) {
        $body.Children.Add((New-RegistryKeyRow $Window $key)) | Out-Null
    }
    $body
}

# Una clave: botón de abrir, ruta y valor, y los tres estados.
function New-RegistryKeyRow {
    param($Window, $Key)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 4, 0, 4, 14
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    # --- columna 0: abrir en el Editor del registro ---
    # Todavía no hace nada: la app es solo interfaz por ahora.
    $open = New-Object System.Windows.Controls.Border
    $open.Width = 28; $open.Height = 28
    $open.CornerRadius = New-Object System.Windows.CornerRadius 8
    $open.BorderThickness = New-Object System.Windows.Thickness 1
    $open.Margin = New-Object System.Windows.Thickness 0, 1, 14, 0
    $open.VerticalAlignment = 'Top'
    $open.Cursor = 'Hand'
    $open.ToolTip = T 'Open this key in Registry Editor'
    Set-BoxBg   $open 'Surface'
    Set-BoxLine $open 'Stroke'
    $open.Child = (New-Icon 'OpenIn' 12 'TextMuted')
    Add-ToColumn $grid $open 0

    # --- columna 1: ruta y valor, seleccionables y copiables ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.Margin = New-Object System.Windows.Thickness 0, 0, 24, 0

    $type = $null
    if ($Key.Type) { $type = "($($Key.Type))" }

    $texts.Children.Add((New-MonoField -Window $Window -Label (T 'Path:') -Value $Key.Path `
        -Tip 'Copy the registry path')) | Out-Null
    $texts.Children.Add((New-MonoField -Window $Window -Label (T 'Value:') -Value $Key.Name -Suffix $type `
        -Tip 'Copy the value name')) | Out-Null

    Add-ToColumn $grid $texts 1

    # --- columna 2: actual / recomendado / de fábrica ---
    $states = New-Object System.Windows.Controls.StackPanel
    $states.VerticalAlignment = 'Top'
    $states.Children.Add((New-CurrentLine $Window $Key))                                          | Out-Null
    $states.Children.Add((New-StateLine $Window (T 'Recommended:') $Key.Recommended 'Success'))   | Out-Null
    $states.Children.Add((New-StateLine $Window (T 'Factory:')     $Key.Default     'TextMuted')) | Out-Null
    Add-ToColumn $grid $states 2

    $grid
}

<#
    La línea "Actual:". A diferencia de las otras dos, que son
    datos declarados, esta la rellena core/Registry/CategoryState.ps1 al
    entrar en la sección, y puede haber salido de cuatro maneras.

    Que un valor no exista NO es un fallo: quiere decir que Windows
    está usando su valor interno, y se dice con esas palabras en
    vez de con un guion, que no distinguiría "no está" de "no se
    ha mirado".
#>
function New-CurrentLine {
    param($Window, $Key)

    $label = T 'Current:'

    switch ($Key.State) {
        'read'    {
            # El color dice de un vistazo contra qué ha cuadrado el
            # valor: verde si es el recomendado, apagado si es el de
            # fábrica y naranja si no es ninguno. Mismo catálogo que
            # la etiqueta de la tarjeta (Get-StatusStyle), así que no
            # pueden decir cosas distintas. Sin Status -esta clave no
            # se ha comparado con nada- se queda en el color normal.
            $fg = 'Text'
            if ($Key.Status) { $fg = (Get-StatusStyle $Key.Status).Fg }
            return (New-StateLine $Window $label $Key.Current $fg)
        }
        'missing' { return (New-StateLine $Window $label (T 'not set')           'TextFaint') }
        'denied'  { return (New-StateLine $Window $label (T 'no access')         'Danger') }
        'badpath' { return (New-StateLine $Window $label (T 'unknown root key')  'Danger') }
    }

    # Sin State: nadie ha leído todavía esta clave.
    New-StateLine $Window $label (T 'not read') 'TextFaint'
}

<#
    "Ruta:  HKEY_LOCAL_MACHINE\..." en tipografía monoespaciada, con
    la etiqueta en negrita, el dato en color normal y un botón para
    copiarlo al portapapeles.

    El dato va en un TextBox de SOLO LECTURA, no en un TextBlock: en
    WPF un TextBlock no se puede seleccionar con el ratón ni copiar
    con Ctrl+C, y esto es justo lo que uno quiere pegar en el Editor
    del registro. Sin borde, sin fondo y sin cursor de escritura se ve
    igual que el texto de al lado, pero se selecciona, tiene su menú
    contextual y responde a Ctrl+C y Ctrl+A. De solo lectura quiere
    decir que no se puede escribir en él: no es un campo editable.

    Las tres columnas son etiqueta / dato / botón. El dato va en la
    columna elástica y con TextWrapping, que es lo que hace que una
    ruta larga baje de línea en vez de salirse de la tarjeta.
#>
function New-MonoField {
    param($Window, [string]$Label, [string]$Value, [string]$Suffix, [string]$Tip)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 0, 0, 0, 3
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    # --- columna 0: la etiqueta, y con ella el tipo ---
    # El tipo se pega a la etiqueta y no detrás del dato porque ahí
    # entraría en la selección y se copiaría con él.
    $tag = New-Object System.Windows.Controls.TextBlock
    $tag.FontFamily = $Window.FindResource('MonoFont')
    $tag.FontSize = 11
    $tag.VerticalAlignment = 'Top'
    $tag.Margin = New-Object System.Windows.Thickness 0, 1, 7, 0

    $name = New-Object System.Windows.Documents.Run $Label
    $name.FontWeight = 'SemiBold'
    Set-TextFg $name 'TextMuted'
    $tag.Inlines.Add($name)

    if ($Suffix) {
        $extra = New-Object System.Windows.Documents.Run (' ' + $Suffix)
        Set-TextFg $extra 'TextFaint'
        $tag.Inlines.Add($extra)
    }
    Add-ToColumn $grid $tag 0

    # --- columna 1: el dato ---
    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Value
    $box.IsReadOnly = $true
    $box.IsReadOnlyCaretVisible = $false
    $box.BorderThickness = New-Object System.Windows.Thickness 0
    $box.Background = [System.Windows.Media.Brushes]::Transparent
    $box.Padding = New-Object System.Windows.Thickness 0
    $box.Margin = New-Object System.Windows.Thickness 0
    $box.FontFamily = $Window.FindResource('MonoFont')
    $box.FontSize = 11
    $box.TextWrapping = 'Wrap'
    $box.HorizontalAlignment = 'Left'
    $box.VerticalAlignment = 'Top'
    $box.ToolTip = T 'Select it or press Ctrl+C to copy it'
    Set-TextFg $box 'Text'
    Add-ToColumn $grid $box 1

    # --- columna 2: copiar ---
    Add-ToColumn $grid (New-CopyButton $Value $Tip) 2

    $grid
}

<#
    El botón de copiar de cada campo.

    Lo que se copia viaja en el Tag junto con su propio pie de ayuda,
    para poder devolverlo a su sitio después del aviso: nada de
    closures (regla 4 de CLAUDE.md).
#>
function New-CopyButton {
    param([string]$Text, [string]$Tip)

    $button = New-Object System.Windows.Controls.Border
    $button.Name = 'BtnCopy'
    $button.Width = 24; $button.Height = 21
    $button.CornerRadius = New-Object System.Windows.CornerRadius 6
    $button.Margin = New-Object System.Windows.Thickness 10, 0, 0, 0
    $button.VerticalAlignment = 'Top'
    $button.Cursor = 'Hand'
    $button.Background = [System.Windows.Media.Brushes]::Transparent
    $button.ToolTip = T $Tip
    $button.Child = (New-Icon 'Copy' 11 'TextFaint')
    $button.Tag = [PSCustomObject]@{ Text = $Text; Tip = $Tip }

    $button.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $button.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $button.Add_MouseLeftButtonUp({ param($s, $e) Copy-TechnicalValue $s })

    $button
}

# ---- Copiar al portapapeles -------------------------------------
#
# El aviso de "copiado" lo enseña UN botón cada vez: el que se acaba
# de pulsar. Si se copia otra cosa antes de que se apague, el anterior
# vuelve a su sitio en el acto. Guardarlo aquí -y no en cada botón-
# es lo que permite que el temporizador sea uno solo y que su
# manejador no necesite saber a quién apagar.
$CopyFeedbackButton = $null
$CopyFeedbackTimer = $null
$CopyFeedbackMs = 1400

<#
    Copia al portapapeles el texto que lleva el botón en su Tag.

    El portapapeles es de todo Windows y otro programa puede tenerlo
    tomado, en cuyo caso SetText lanza. Aquí eso no puede tumbar la
    ventana: si no se ha podido copiar, no se avisa de que sí.
#>
function Copy-TechnicalValue {
    param($Button)

    $info = $Button.Tag
    if (-not $info -or [string]::IsNullOrEmpty([string]$info.Text)) { return $false }

    try { [System.Windows.Clipboard]::SetText([string]$info.Text) }
    catch { return $false }

    Show-CopyFeedback $Button
    $true
}

# El aviso: el icono se vuelve una marca verde durante algo más de un
# segundo, y el pie de ayuda dice "Copiado" por si se vuelve a pasar
# el ratón por encima.
function Show-CopyFeedback {
    param($Button)

    Reset-CopyFeedback

    $script:CopyFeedbackButton = $Button
    $Button.Child.Text = Glyph 'Check'
    Set-TextFg $Button.Child 'Success'
    $Button.ToolTip = T 'Copied'

    if (-not $script:CopyFeedbackTimer) {
        $script:CopyFeedbackTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:CopyFeedbackTimer.Interval = [TimeSpan]::FromMilliseconds($CopyFeedbackMs)
        # El manejador llama a la función y es ella la que sabe a quién
        # apagar: un DispatcherTimer no tiene Tag donde dejar el botón.
        $script:CopyFeedbackTimer.Add_Tick({ param($s, $e) Reset-CopyFeedback })
    }
    $script:CopyFeedbackTimer.Stop()
    $script:CopyFeedbackTimer.Start()
}

# Devuelve el botón que estuviera avisando a su aspecto normal.
# Llamarla sin nadie avisando no hace nada.
function Reset-CopyFeedback {
    if ($script:CopyFeedbackTimer) { $script:CopyFeedbackTimer.Stop() }

    $button = $script:CopyFeedbackButton
    $script:CopyFeedbackButton = $null
    if (-not $button) { return }

    $button.Child.Text = Glyph 'Copy'
    Set-TextFg $button.Child 'TextFaint'
    $button.ToolTip = T $button.Tag.Tip
}

# "Actual: 5" alineado a la derecha.
function New-StateLine {
    param($Window, [string]$Label, [string]$Value, [string]$Fg)

    $line = New-Object System.Windows.Controls.TextBlock
    $line.FontFamily = $Window.FindResource('MonoFont')
    $line.FontSize = 11
    $line.LineHeight = 17
    $line.TextAlignment = 'Right'
    $line.HorizontalAlignment = 'Right'

    $tag = New-Object System.Windows.Documents.Run ($Label + ' ')
    Set-TextFg $tag 'TextFaint'
    $line.Inlines.Add($tag)

    $shown = $Value
    if ([string]::IsNullOrEmpty($shown)) { $shown = '-' }

    $data = New-Object System.Windows.Documents.Run $shown
    $data.FontWeight = 'SemiBold'
    Set-TextFg $data $Fg
    $line.Inlines.Add($data)

    $line
}

# Ajuste que todavía no declara sus claves.
function New-TechnicalPlaceholder {
    $note = New-Object System.Windows.Controls.TextBlock
    $note.Text = T 'No registry keys declared for this setting yet.'
    $note.FontSize = 11.5
    $note.TextWrapping = 'Wrap'
    $note.Margin = New-Object System.Windows.Thickness 4, 0, 4, 4
    Set-TextFg $note 'TextFaint'
    $note
}

# ---- fin incluido: ui/Components/Cards/TechnicalDetails.ps1 ----
# ---- inicio incluido: ui/Components/Layout/Banner.ps1 ----
# ============================================================
# Componente: aviso
#
# Franja informativa que se coloca encima del contenido de una
# pantalla. Ahora mismo la usa el detalle para avisar de que la
# sección está bloqueada.
# ============================================================

function New-Banner {
    param(
        [string]$Icon,
        [string]$Title,
        [string]$Message,
        [string]$Fg = 'Warn',
        [string]$Bg = 'WarnSoft'
    )

    $banner = New-Object System.Windows.Controls.Border
    $banner.CornerRadius = New-Object System.Windows.CornerRadius 12
    $banner.Padding = New-Object System.Windows.Thickness 16, 13, 18, 14
    $banner.Margin = New-Object System.Windows.Thickness 0, 0, 0, 14
    Set-BoxBg $banner $Bg

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'

    $ic = New-Icon $Icon 17 $Fg
    $ic.VerticalAlignment = 'Center'
    $ic.Margin = New-Object System.Windows.Thickness 0, 0, 13, 0
    $row.Children.Add($ic) | Out-Null

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $Title
    $t.FontSize = 12.5
    $t.FontWeight = 'SemiBold'
    Set-TextFg $t $Fg
    $texts.Children.Add($t) | Out-Null

    if ($Message) {
        $m = New-Object System.Windows.Controls.TextBlock
        $m.Text = T $Message
        $m.FontSize = 11.5
        $m.TextWrapping = 'Wrap'
        $m.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
        Set-TextFg $m 'TextMuted'
        $texts.Children.Add($m) | Out-Null
    }

    $row.Children.Add($texts) | Out-Null
    $banner.Child = $row
    $banner
}

# Aviso concreto de sección bloqueada.
function New-LockedBanner {
    New-Banner -Icon 'Lock' `
        -Title 'Locked section' `
        -Message 'Its settings are shown for reference only: they cannot be changed. To unlock it, set Locked = $false in ui/Index/CategoryIndex.ps1.'
}

# ---- fin incluido: ui/Components/Layout/Banner.ps1 ----
# ---- inicio incluido: ui/Components/Layout/CategorySummary.ps1 ----
# ============================================================
# Componente: resumen de una sección
#
# La fila centrada que va bajo el título en la pantalla de
# detalle. Una píldora por etiqueta, con los mismos colores que
# las etiquetas de cada tarjeta y que las píldoras de la lista:
#
#     (estrella) Recomendado 6/6   (rejilla) De fábrica 5/6
#     (mando) Personalizado 6/6
#
# La fila se cuenta de dos maneras, y la sección decide cuál:
#
#   - Si sus ajustes leen el registro, por su ESTADO REAL
#     (Get-CategoryStatusCounts): optimizado, de fábrica o a medida,
#     lo que core/Registry/SettingStatus.ps1 acaba de sacar del equipo.
#     Es el mismo dato -y el mismo catálogo de colores- que la
#     etiqueta de cada tarjeta, así que fila y tarjetas no pueden
#     contradecirse.
#   - Si no, por las etiquetas declaradas a mano en el archivo de la
#     sección (Get-CategoryCounts). Es lo que había siempre.
#
# Update-CategorySummary vuelve a contar y repinta la fila. Está
# enganchado a los controles de ui/Components/Cards/SettingCard.ps1: el
# día que tocar un interruptor escriba en el registro, los números
# se moverán solos.
# ============================================================

# Etiqueta -> icono y colores. Mismo criterio que New-Tag (UiKit).
$SummaryStyles = @(
    @{ Tag = 'Recommended'; Icon = 'StarFill'; Fg = 'Success';   Bg = 'SuccessSoft'
       Tip = 'Recommended: {0} of {1}' }
    @{ Tag = 'Default';     Icon = 'Grid';     Fg = 'TextMuted'; Bg = 'SurfaceSunken'
       Tip = 'Factory defaults: {0} of {1}' }
    @{ Tag = 'Custom';      Icon = 'Sliders';  Fg = 'Warn';      Bg = 'WarnSoft'
       Tip = 'Customised: {0} of {1}' }
)

function New-CategorySummary {
    param($Window, $Category)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.HorizontalAlignment = 'Center'
    $row.Margin = New-Object System.Windows.Thickness 0, 14, 0, 0

    # La categoría viaja en el Tag para que Update-CategorySummary
    # pueda recontar sin closures (regla 4 de CLAUDE.md).
    $row.Tag = $Category

    # Si la sección lee el registro, sus ajustes traen un estado de
    # verdad y se cuentan por él. Si no, por las etiquetas declaradas,
    # que es todo lo que hay.
    $counts = Get-CategoryStatusCounts $Category
    if ($counts) { Add-StatusPills $row $counts } else { Add-TagPills $row (Get-CategoryCounts $Category) }

    $row
}

# Una píldora por estado real. La de 'desconocido' solo sale si hay
# alguno: en cuanto se lee todo bien, sobra de la fila.
function Add-StatusPills {
    param($Row, $Counts)

    foreach ($status in Get-SettingStatusNames) {
        $n = [int]$Counts.$status
        if ($status -eq 'unknown' -and $n -eq 0) { continue }

        $style = Get-StatusStyle $status
        $tip = (T $style.Count) -f $n, $Counts.Total
        $Row.Children.Add((New-SummaryPill $style (T $style.Label) $n $Counts.Total $tip)) | Out-Null
    }
}

# Una píldora por etiqueta declarada. Es lo de siempre, y lo que
# siguen enseñando las secciones que aún no leen nada del equipo.
function Add-TagPills {
    param($Row, $Counts)

    foreach ($style in $SummaryStyles) {
        $n = [int]$Counts.($style.Tag)
        $tip = (T $style.Tip) -f $n, $Counts.Total
        $Row.Children.Add((New-SummaryPill $style (T $style.Tag) $n $Counts.Total $tip)) | Out-Null
    }
}

# La píldora del resumen: icono, nombre y recuento, todo dentro de la
# misma cápsula. New-Pill solo trae el icono y el texto, así que el
# nombre se cuela entre los dos.
function New-SummaryPill {
    param($Style, [string]$Label, [int]$Count, [int]$Total, [string]$Tip)

    $pill = New-Pill $Style.Icon "$Count/$Total" $Style.Fg $Style.Bg $Tip
    $pill.Margin = New-Object System.Windows.Thickness 4, 0, 4, 0

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Label + '  '
    $text.FontSize = 11
    $text.FontWeight = 'SemiBold'
    $text.VerticalAlignment = 'Center'
    Set-TextFg $text $Style.Fg
    $pill.Child.Children.Insert(1, $text)

    $pill
}

<#
    Vuelve a contar y repinta la fila del resumen.

    No hace nada si la pantalla actual no la tiene (la lista y la
    de Settings no la usan), así que se puede llamar sin comprobar
    dónde estamos.
#>
function Update-CategorySummary {
    $window = Get-AppWindow
    if (-not $window) { return }

    $area = $window.FindName('HeaderSummaryArea')
    if (-not $area -or $area.Children.Count -eq 0) { return }

    $category = $area.Children[0].Tag
    if (-not $category) { return }

    $area.Children.Clear()
    $area.Children.Add((New-CategorySummary -Window $window -Category $category)) | Out-Null
}

# ---- fin incluido: ui/Components/Layout/CategorySummary.ps1 ----
# ---- inicio incluido: ui/Components/Layout/PageHeader.ps1 ----
# ============================================================
# Componente: cabecera de página
#
# La franja superior del contenido, con tres zonas definidas en
# MainWindow.xaml:
#     HeaderTitleArea    -> izquierda: título o breadcrumb
#     HeaderActionsArea  -> derecha:   buscador y botones
#     HeaderSummaryArea  -> debajo y centrado: resumen de la sección
#
# Las vistas no tocan esas zonas directamente: usan estas
# funciones. Así todas las pantallas comparten el mismo aspecto.
# ============================================================

# Vacía las tres zonas. Toda vista debe llamarla antes de pintar.
function Clear-PageHeader {
    param($Window)
    $Window.FindName('HeaderTitleArea').Children.Clear()
    $Window.FindName('HeaderActionsArea').Children.Clear()
    $Window.FindName('HeaderSummaryArea').Children.Clear()
}

# Título grande + subtítulo gris (pantalla principal).
function Set-PageTitle {
    param($Window, [string]$Title, [string]$Subtitle)

    $stack = New-Object System.Windows.Controls.StackPanel

    $big = New-Object System.Windows.Controls.TextBlock
    $big.Text = $Title
    $big.FontFamily = $Window.FindResource('DisplayFont')
    $big.FontSize = 27
    $big.FontWeight = 'Bold'
    Set-TextFg $big 'Text'
    $stack.Children.Add($big) | Out-Null

    if ($Subtitle) {
        $sub = New-Object System.Windows.Controls.TextBlock
        $sub.Text = $Subtitle
        $sub.FontSize = 12.5
        $sub.Margin = New-Object System.Windows.Thickness 0, 3, 0, 0
        Set-TextFg $sub 'TextMuted'
        $stack.Children.Add($sub) | Out-Null
    }

    $Window.FindName('HeaderTitleArea').Children.Add($stack) | Out-Null
}

# Breadcrumb de una categoría: botón atrás + icono + ruta + título.
# $OnBack es el nombre de la función a la que vuelve el botón.
function Set-PageBreadcrumb {
    param($Window, $Category, [string]$RootLabel = 'Optimizations')

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'

    # --- botón atrás ---
    $back = New-Object System.Windows.Controls.Border
    $back.Width = 34; $back.Height = 34
    $back.CornerRadius = New-Object System.Windows.CornerRadius 9
    $back.BorderThickness = New-Object System.Windows.Thickness 1
    $back.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
    $back.VerticalAlignment = 'Center'
    $back.Cursor = 'Hand'
    $back.ToolTip = T 'Back to the list'
    Set-BoxBg $back 'Surface'
    Set-BoxLine $back 'Stroke'
    $back.Child = (New-Icon 'Back' 13 'TextMuted')
    # Por Show-View, no llamando a la vista (regla 17 de CLAUDE.md).
    $back.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-View -Name 'Show-OptimizationsListView'
    })
    $row.Children.Add($back) | Out-Null

    # --- icono de la categoría ---
    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 38
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 13, 0
    $row.Children.Add($tile) | Out-Null

    # --- ruta pequeña + título ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $trail = New-Object System.Windows.Controls.StackPanel
    $trail.Orientation = 'Horizontal'

    $rootLink = New-Object System.Windows.Controls.TextBlock
    $rootLink.Text = T $RootLabel
    $rootLink.FontSize = 11
    $rootLink.Cursor = 'Hand'
    Set-TextFg $rootLink 'TextFaint'
    $rootLink.Add_MouseLeftButtonUp({
        param($s, $e)
        Show-View -Name 'Show-OptimizationsListView'
    })
    $trail.Children.Add($rootLink) | Out-Null

    $sep = New-Icon 'ChevronRight' 8 'TextFaint'
    $sep.Margin = New-Object System.Windows.Thickness 6, 1, 6, 0
    $trail.Children.Add($sep) | Out-Null

    $leaf = New-Object System.Windows.Controls.TextBlock
    $leaf.Text = T $Category.Name
    $leaf.FontSize = 11
    Set-TextFg $leaf 'TextMuted'
    $trail.Children.Add($leaf) | Out-Null

    $texts.Children.Add($trail) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T $Category.Name
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 21
    $title.FontWeight = 'Bold'
    $title.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $row.Children.Add($texts) | Out-Null
    $Window.FindName('HeaderTitleArea').Children.Add($row) | Out-Null
}

# Cabecera de un bloque dentro del contenido ("General",
# "Appearance"...). La usa la pantalla de Settings.
function New-SectionHeader {
    param($Window, [string]$Text)

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $Text
    $header.FontFamily = $Window.FindResource('DisplayFont')
    $header.FontSize = 12
    $header.FontWeight = 'SemiBold'
    $header.Margin = New-Object System.Windows.Thickness 4, 6, 0, 10
    Set-TextFg $header 'TextFaint'
    $header
}

# Añade un control a la zona de acciones (derecha).
function Add-PageAction {
    param($Window, $Element)
    $Window.FindName('HeaderActionsArea').Children.Add($Element) | Out-Null
}

# Lo mismo, pero por delante de lo que ya hubiera. Lo usa el aviso
# efímero de Toast.ps1: sale a la izquierda de los botones, que es
# donde queda sitio sin moverlos de su esquina.
function Add-PageActionFirst {
    param($Window, $Element)
    $Window.FindName('HeaderActionsArea').Children.Insert(0, $Element)
}

# Pone el resumen centrado bajo el título. Solo lo usa el detalle
# de una sección; el resto de pantallas deja la zona vacía y no
# ocupa alto.
function Set-PageSummary {
    param($Window, $Category)
    $area = $Window.FindName('HeaderSummaryArea')
    $area.Children.Clear()
    $area.Children.Add((New-CategorySummary -Window $Window -Category $Category)) | Out-Null
}

# Texto gris suelto en la zona de acciones ("6 settings").
function Add-PageActionLabel {
    param($Window, [string]$Text)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.FontSize = 12
    $t.VerticalAlignment = 'Center'
    $t.Margin = New-Object System.Windows.Thickness 0, 0, 4, 0
    Set-TextFg $t 'TextFaint'
    Add-PageAction $Window $t
}

# ---- fin incluido: ui/Components/Layout/PageHeader.ps1 ----
# ---- inicio incluido: ui/Components/Layout/SearchResults.ps1 ----
# ============================================================
# Componente: piezas de la búsqueda que no son el resultado
#
#   New-SearchGroupHeader   la cabecera de cada sección en la lista
#                           de resultados: icono, nombre y cuántos
#   New-SearchEmptyState    lo que sale cuando no hay coincidencias
#   New-SearchCountLine     "12 resultados para «telemetría»"
#
# Agrupar por sección es lo que evita que una lista larga se lea
# como un montón: primero se ve dónde está lo que buscas y luego
# qué es. Los grupos los arma ui/Engine/Search.ps1; aquí solo se
# dibujan.
# ============================================================

function New-SearchGroupHeader {
    param($Window, $Category, [int]$Count)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Margin = New-Object System.Windows.Thickness 2, 16, 0, 9

    $tile = New-IconTile $Category.Icon $Category.Accent $Category.AccentSoft 24
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 9, 0
    $row.Children.Add($tile) | Out-Null

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Category.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontSize = 12.5
    $name.FontWeight = 'SemiBold'
    $name.VerticalAlignment = 'Center'
    Set-TextFg $name 'Text'
    $row.Children.Add($name) | Out-Null

    $badge = New-Object System.Windows.Controls.TextBlock
    $badge.Text = [string]$Count
    $badge.FontSize = 11
    $badge.VerticalAlignment = 'Center'
    $badge.Margin = New-Object System.Windows.Thickness 8, 1, 0, 0
    Set-TextFg $badge 'TextFaint'
    $row.Children.Add($badge) | Out-Null

    $row
}

# "12 resultados para «telemetría»". Va en el cuerpo y no en el
# subtítulo de la cabecera a propósito: el número cambia con cada
# tecla y la cabecera no se rehace en cada tecla.
function New-SearchCountLine {
    param($Window, [int]$Count, [string]$Query)

    $texto = (T '{0} results for "{1}"') -f $Count, $Query
    if ($Count -eq 1) { $texto = (T '1 result for "{0}"') -f $Query }

    $line = New-Object System.Windows.Controls.TextBlock
    $line.Text = $texto
    $line.FontSize = 12
    $line.Margin = New-Object System.Windows.Thickness 2, 0, 0, 2
    Set-TextFg $line 'TextMuted'
    $line
}

<#
    Sin coincidencias. Ni error ni pantalla en blanco: se dice qué se
    buscó y se sugiere qué probar, que en esta aplicación suele ser
    un trozo de ruta del registro.
#>
function New-SearchEmptyState {
    param($Window, [string]$Query, [switch]$Compact)

    $box = New-Object System.Windows.Controls.StackPanel
    $box.HorizontalAlignment = 'Center'
    if ($Compact) { $box.Margin = New-Object System.Windows.Thickness 0, 14, 0, 16 }
    else          { $box.Margin = New-Object System.Windows.Thickness 0, 60, 0, 0 }

    $icon = New-Icon 'Search' 30 'TextFaint'
    if ($Compact) { $icon.FontSize = 20 }
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    $box.Children.Add($icon) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = (T 'Nothing matches "{0}"') -f $Query
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 14
    $title.FontWeight = 'SemiBold'
    $title.TextAlignment = 'Center'
    $title.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $title 'Text'
    $box.Children.Add($title) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'Try another word, or part of a registry path'
    $hint.FontSize = 11.5
    $hint.TextAlignment = 'Center'
    $hint.Margin = New-Object System.Windows.Thickness 0, 6, 0, 0
    Set-TextFg $hint 'TextMuted'
    $box.Children.Add($hint) | Out-Null

    $box
}

<#
    La página de resultados sin nada escrito -se llega borrando la
    caja-. No es lo mismo que "no hay coincidencias": ahí no se ha
    buscado nada todavía, así que decir «nada coincide con ""»
    sería mentira.
#>
function New-SearchPromptState {
    param($Window)

    $box = New-Object System.Windows.Controls.StackPanel
    $box.HorizontalAlignment = 'Center'
    $box.Margin = New-Object System.Windows.Thickness 0, 60, 0, 0

    $icon = New-Icon 'Search' 30 'TextFaint'
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    $box.Children.Add($icon) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Type to search'
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 14
    $title.FontWeight = 'SemiBold'
    $title.TextAlignment = 'Center'
    Set-TextFg $title 'Text'
    $box.Children.Add($title) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'Sections, settings, registry keys and their values'
    $hint.FontSize = 11.5
    $hint.TextAlignment = 'Center'
    $hint.Margin = New-Object System.Windows.Thickness 0, 6, 0, 0
    Set-TextFg $hint 'TextMuted'
    $box.Children.Add($hint) | Out-Null

    $box
}

# ---- fin incluido: ui/Components/Layout/SearchResults.ps1 ----
# ---- inicio incluido: ui/Components/Layout/Toast.ps1 ----
# ============================================================
# Componente: aviso efímero
#
# La pastilla que aparece un momento en la cabecera para decir
# que algo acaba de terminar -hoy, que se han vuelto a leer las
# claves del registro-.
#
# No es lo mismo que Banner.ps1: aquel se queda mientras dure la
# condición que avisa (una sección bloqueada lo está siempre),
# este cuenta un hecho que ya pasó y se va solo.
#
# Se descuelga con un DispatcherTimer y no desde el Completed de
# la animación: ese evento trae el reloj como emisor, no el
# control, y llegar hasta el control obligaría a capturarlo en el
# scriptblock (regla 4). El temporizador sí tiene Tag.
# ============================================================

<#
    Enseña la pastilla al principio de la zona de acciones y deja
    programada su marcha de una vez: se desvanece a los $Ms
    -animación aplazada con BeginTime- y se descuelga 320 ms más
    tarde, cuando ya no se ve.

        Show-PageToast -Window $w -Text 'Registry values updated'

    Sin ventana pintándose ni bucle de mensajes -las pruebas- ni
    la animación avanza ni el temporizador dispara: la pastilla se
    queda puesta, que es exactamente lo que hay que poder mirar.
#>
function Show-PageToast {
    param(
        $Window,
        [string]$Text,
        [string]$Icon = 'Check',
        [int]$Ms = 2400
    )

    $pill = New-Pill -Icon $Icon -Text (T $Text) -Fg 'Success' -Bg 'SuccessSoft'
    $pill.Margin = New-Object System.Windows.Thickness 0, 0, 8, 0
    Add-PageActionFirst $Window $pill

    # Entra deslizando desde la derecha. Se anima el
    # desplazamiento y no la opacidad porque la opacidad la tiene
    # reservada la salida: dos BeginAnimation sobre la misma
    # propiedad y el segundo se lleva por delante al primero.
    $slide = New-Object System.Windows.Media.TranslateTransform
    $pill.RenderTransform = $slide
    $slide.BeginAnimation(
        [System.Windows.Media.TranslateTransform]::XProperty, (New-Anim 12 0 220))

    $fade = New-Anim 1 0 300
    $fade.BeginTime = [TimeSpan]::FromMilliseconds($Ms)
    $pill.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($Ms + 320)
    $timer.Tag = $pill
    $timer.Add_Tick({
        param($s, $e)
        $s.Stop()
        $gone = $s.Tag
        # Puede que ya no cuelgue de nadie: repintar la pantalla
        # vacía la cabecera y se lleva la pastilla con ella.
        if ($gone -and $gone.Parent) { $gone.Parent.Children.Remove($gone) }
    })
    $timer.Start()

    $pill
}

# ---- fin incluido: ui/Components/Layout/Toast.ps1 ----
# ---- inicio incluido: ui/Components/Shell/LogPanel.ps1 ----
# ============================================================
# Componente: registro de actividad (el botón "log")
#
# Un cajón que entra por la derecha con lo que el programa le ha
# preguntado al sistema. Hoy eso es exactamente una cosa: las
# lecturas del registro de Windows.
#
#   -------------------------------------------------
#   (~) Registro de actividad                    [x]
#       Lo que la app ha leído de tu sistema
#   -------------------------------------------------
#   [Vaciar] [Guardar en archivo]        23 entradas
#   -------------------------------------------------
#   20:14:03.118  [leyendo]  Regedit
#                            9 keys
#   20:14:03.120  [leído]    HKEY_LOCAL_MACHINE\...
#                            \NetworkThrottlingIndex
#                            4294967295 (0xFFFFFFFF) - DWord
#   -------------------------------------------------
#
# La carcasa (LogOverlay / LogScrim / LogDrawer) está en
# MainWindow.xaml, igual que la de la barra de progreso; lo de
# dentro se construye aquí y se rehace cada vez que se abre, así
# que sale siempre en el idioma actual y con lo último apuntado.
#
# NO se navega para verlo: el cajón se pone ENCIMA de la pantalla
# en la que estabas y al cerrarlo sigues allí. Por eso no pasa
# por ui/Engine/Router.ps1 ni cuenta como vista.
#
# Sobre el idioma: se traduce el marco -títulos, botones y las
# etiquetas de color- pero NO las líneas. Una línea de log es una
# ruta del registro y un valor: texto técnico que se copia y se
# pega tal cual en un informe, y que traducido a medias sería
# peor. Por eso core/Diagnostics/Log.ps1 guarda hechos y solo el Status viaja
# como palabra suelta, para pasarla por T aquí.
# ============================================================

# Cuántas filas se pintan como mucho. El buffer guarda mil (ver
# core/Diagnostics/Log.ps1); dibujarlas todas de golpe se notaría al abrir, y
# nadie lee mil líneas: se enseñan las últimas y se avisa.
$LogPanelMaxRows = 400

# Cuánto oscurece el velo lo que hay detrás.
$LogScrimOpacity = 0.32

$LogPanelOpen = $false

function Get-LogPanelOpen { $script:LogPanelOpen }

# ---- Abrir y cerrar -----------------------------------------

<#
    Abre o cierra el registro, esté donde esté.

    Si está sacado a su propia ventana, el botón de la barra de
    título manda sobre ESA ventana y no sobre el cajón: sería
    absurdo abrir el cajón teniendo el log delante en una ventana.
#>
function Switch-LogPanel {
    param($Window)

    if (Get-LogFloating) {
        if (Get-LogWindow) { Close-LogWindow } else { Open-LogWindow }
        return
    }

    if ($LogPanelOpen) { Hide-LogPanel $Window } else { Show-LogPanel $Window }
}

function Show-LogPanel {
    param($Window)

    Update-LogPanel $Window

    $overlay = $Window.FindName('LogOverlay')
    $scrim   = $Window.FindName('LogScrim')
    $drawer  = $Window.FindName('LogDrawer')

    $script:LogPanelOpen = $true
    $overlay.Visibility = 'Visible'

    $scrim.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Anim 0 $LogScrimOpacity 220))
    (Get-LogSlide $drawer).BeginAnimation(
        [System.Windows.Media.TranslateTransform]::XProperty,
        (New-Anim (Get-LogDrawerWidth $drawer) 0 240))
}

function Hide-LogPanel {
    param($Window)

    if (-not $LogPanelOpen) { return }
    $script:LogPanelOpen = $false

    $scrim  = $Window.FindName('LogScrim')
    $drawer = $Window.FindName('LogDrawer')

    (Get-LogSlide $drawer).BeginAnimation(
        [System.Windows.Media.TranslateTransform]::XProperty,
        (New-Anim 0 (Get-LogDrawerWidth $drawer) 200))

    # El velo se apaga a la vez, y al terminar se colapsa todo:
    # colapsado el cajón ya no existe para el ratón y se vuelve a
    # poder pulsar lo que hay debajo.
    $fade = New-Anim $LogScrimOpacity 0 200
    $fade.Add_Completed({
        param($s, $e)
        Close-LogOverlay (Get-AppWindow)
    })
    $scrim.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
}

<#
    Retira el cajón de en medio. Es el último paso de cerrar, y
    está aparte del manejador de la animación por dos motivos:

      - Se puede llamar a mano. Las animaciones de WPF solo corren
        con una ventana pintándose, así que sin esto no habría
        forma de probar el cierre.
      - Deja explícita la única condición que importa: si en esos
        200 ms lo han vuelto a abrir, NO se colapsa. Hacerlo
        escondería un cajón que ya está entrando otra vez.
#>
function Close-LogOverlay {
    param($Window)

    if (-not $Window) { return }
    if (Get-LogPanelOpen) { return }
    $Window.FindName('LogOverlay').Visibility = 'Collapsed'
}

# El desplazamiento del cajón. Se crea por control y no en un
# Setter de estilo: un Freezable compartido no se puede animar
# (regla 11 de CLAUDE.md).
function Get-LogSlide {
    param($Drawer)

    if (-not ($Drawer.RenderTransform -is [System.Windows.Media.TranslateTransform])) {
        $Drawer.RenderTransform = New-Object System.Windows.Media.TranslateTransform
    }
    $Drawer.RenderTransform
}

# El ancho declarado en el XAML. ActualWidth todavía es 0 la
# primera vez, antes de que WPF haya medido nada.
function Get-LogDrawerWidth {
    param($Drawer)
    if ([double]::IsNaN($Drawer.Width)) { 660.0 } else { $Drawer.Width }
}

# ---- Contenido ----------------------------------------------

<#
    Arma el contenido del registro: cabecera, barra de botones,
    lista y pie.

    Es el MISMO contenido para el cajón y para la ventana aparte;
    lo único que cambia es qué botones lleva la cabecera y si esa
    cabecera arrastra la ventana. Que sea uno solo es lo que hace
    que las dos vistas no puedan quedarse desparejadas.

    Los nombres se registran en $Window, así que hay que pasarle
    la ventana que va a alojarlo, no siempre la principal.
#>
function New-LogContent {
    param($Window, [switch]$Floating)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-LogRowDef 'Auto')) | Out-Null
    $grid.RowDefinitions.Add((New-LogRowDef 'Auto')) | Out-Null
    $grid.RowDefinitions.Add((New-LogRowDef '*'))    | Out-Null
    $grid.RowDefinitions.Add((New-LogRowDef 'Auto')) | Out-Null

    Add-ToLogRow $grid (New-LogHeader  $Window -Floating:$Floating) 0
    Add-ToLogRow $grid (New-LogToolbar $Window) 1
    Add-ToLogRow $grid (New-LogScroll  $Window) 2
    Add-ToLogRow $grid (New-LogFooter  $Window) 3

    $grid
}

# Rehace el cajón entero. Se llama al abrirlo y al cambiar de
# idioma; para refrescar solo las filas está Update-LogList.
function Update-LogPanel {
    param($Window)

    $Window.FindName('LogDrawer').Child = New-LogContent $Window
    Update-LogList $Window
}

function New-LogRowDef {
    param([string]$Height)
    $rd = New-Object System.Windows.Controls.RowDefinition
    if ($Height -eq '*') { $rd.Height = [System.Windows.GridLength]::new(1, 'Star') }
    else                 { $rd.Height = [System.Windows.GridLength]::Auto }
    $rd
}

function Add-ToLogRow {
    param($Grid, $Element, [int]$Row)
    [System.Windows.Controls.Grid]::SetRow($Element, $Row)
    $Grid.Children.Add($Element) | Out-Null
}

<#
    Fila 0: el título y los botones que mandan sobre el registro.

    Es la misma cabecera acoplada y flotante; solo cambia la
    esquina derecha. Y en la ventana aparte hace además de barra
    de título: arrastra, y el doble clic maximiza. No hay otra,
    porque la ventana se crea sin cromo de Windows para que se
    parezca al resto del programa.
#>
function New-LogHeader {
    param($Window, [switch]$Floating)

    $box = New-Object System.Windows.Controls.Border
    $box.Padding = New-Object System.Windows.Thickness 18, 15, 10, 15
    $box.BorderThickness = New-Object System.Windows.Thickness 0, 0, 0, 1
    Set-BoxLine $box 'Stroke'

    if ($Floating) { Add-LogWindowDrag $box }

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    $tile = New-IconTile 'Pulse' 'Accent' 'AccentSoft' 36
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 13, 0
    $tile.VerticalAlignment = 'Top'
    Add-ToColumn $grid $tile 0

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Activity log'
    $title.FontFamily = $Window.FindResource('DisplayFont')
    $title.FontSize = 16
    $title.FontWeight = 'Bold'
    Set-TextFg $title 'Text'
    $texts.Children.Add($title) | Out-Null

    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text = T 'What the app has read from your system in this session'
    $sub.FontSize = 11.5
    $sub.TextWrapping = 'Wrap'
    $sub.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
    Set-TextFg $sub 'TextMuted'
    $texts.Children.Add($sub) | Out-Null

    Add-ToColumn $grid $texts 1
    Add-ToColumn $grid (New-LogHeaderButtons $Window -Floating:$Floating) 2

    $box.Child = $grid
    $box
}

<#
    Los botones de la esquina.

    Acoplado          sacar, cerrar
    Ventana aparte    acoplar, minimizar, maximizar, cerrar

    Se registran con nombre en la ventana que los aloja, igual que
    los del menú lateral: así los manejadores -y las pruebas- los
    encuentran con FindName sin arrastrarlos en un closure. El de
    maximizar además lo necesita el StateChanged de la ventana
    (ver LogWindow.ps1) para cambiarle el glifo a "restaurar".
#>
function New-LogHeaderButtons {
    param($Window, [switch]$Floating)

    $strip = New-Object System.Windows.Controls.StackPanel
    $strip.Orientation = 'Horizontal'
    $strip.VerticalAlignment = 'Top'

    if (-not $Floating) {
        Add-LogHeaderButton $Window $strip 'LogBtnPopOut' 'OpenIn' 'Open the log in its own window' {
            param($s, $e)
            Open-LogWindow
        }
        Add-LogHeaderButton $Window $strip 'LogBtnClose' 'Close' 'Close the log' {
            param($s, $e)
            Hide-LogPanel ([System.Windows.Window]::GetWindow($s))
        }
        return $strip
    }

    Add-LogHeaderButton $Window $strip 'LogBtnDock' 'Dock' 'Dock the log back into the main window' {
        param($s, $e)
        Join-LogPanel
    }
    Add-LogHeaderButton $Window $strip 'LogBtnMinimize' 'Minimize' 'Minimize' {
        param($s, $e)
        ([System.Windows.Window]::GetWindow($s)).WindowState = 'Minimized'
    }
    Add-LogHeaderButton $Window $strip 'LogBtnMaximize' 'Maximize' 'Maximize' {
        param($s, $e)
        Switch-LogWindowState ([System.Windows.Window]::GetWindow($s))
    }
    Add-LogHeaderButton $Window $strip 'LogBtnClose' 'Close' 'Close the log' {
        param($s, $e)
        ([System.Windows.Window]::GetWindow($s)).Close()
    }

    $strip
}

# Un botón de glifo de la cabecera: se crea, se registra y se
# cuelga. El manejador llega como scriptblock suelto -sin capturar
# nada- para que siga valiendo la regla 4: lo que necesite sale del
# emisor.
function Add-LogHeaderButton {
    param($Window, $Strip, [string]$Name, [string]$Icon, [string]$Tip, [scriptblock]$OnClick)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $Window.FindResource('GlyphButtonStyle')
    $btn.Content = Glyph $Icon
    $btn.FontSize = 12
    $btn.VerticalAlignment = 'Top'
    $btn.ToolTip = T $Tip
    $btn.Add_Click($OnClick)

    Register-LogName $Window $Name $btn
    $Strip.Children.Add($btn) | Out-Null
}

# --- fila 1: vaciar, guardar y el recuento ---
function New-LogToolbar {
    param($Window)

    $box = New-Object System.Windows.Controls.Border
    $box.Padding = New-Object System.Windows.Thickness 18, 11, 18, 12
    $box.BorderThickness = New-Object System.Windows.Thickness 0, 0, 0, 1
    Set-BoxBg   $box 'Bg2'
    Set-BoxLine $box 'Stroke'

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*'

    $buttons = New-Object System.Windows.Controls.StackPanel
    $buttons.Orientation = 'Horizontal'

    $clear = New-ChipButton $Window 'Clear' 'Trash'
    $clear.Margin = New-Object System.Windows.Thickness 0
    $clear.Height = 32
    $clear.Add_Click({
        param($s, $e)
        Clear-AppLog
        # Solo se rehacen las filas: la barra donde vive este mismo
        # botón sigue en pie, así que no hay que aplazar nada.
        Update-LogList ([System.Windows.Window]::GetWindow($s))
    })
    $buttons.Children.Add($clear) | Out-Null

    $save = New-ChipButton $Window 'Save to file' 'Save'
    $save.Height = 32
    $save.Add_Click({
        param($s, $e)
        $window = [System.Windows.Window]::GetWindow($s)
        $path = Export-AppLog
        if ($path) { Set-LogFooterText $window ((T 'Saved to {0}') -f $path) 'Success' }
        else       { Set-LogFooterText $window (T 'The log file could not be written') 'Danger' }
    })
    $buttons.Children.Add($save) | Out-Null

    Add-ToColumn $grid $buttons 0

    $count = New-Object System.Windows.Controls.TextBlock
    $count.FontSize = 11.5
    $count.HorizontalAlignment = 'Right'
    $count.VerticalAlignment = 'Center'
    Set-TextFg $count 'TextFaint'
    Add-ToColumn $grid $count 1

    Register-LogName $Window 'LogCount' $count

    $box.Child = $grid
    $box
}

# --- fila 2: las líneas ---
function New-LogScroll {
    param($Window)

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.Padding = New-Object System.Windows.Thickness 10, 8, 8, 12

    $list = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $list

    Register-LogName $Window 'LogScroll' $scroll
    Register-LogName $Window 'LogList'   $list

    $scroll
}

# --- fila 3: el pie, donde se contesta a "guardar" ---
function New-LogFooter {
    param($Window)

    $box = New-Object System.Windows.Controls.Border
    $box.Padding = New-Object System.Windows.Thickness 18, 10, 18, 12
    $box.BorderThickness = New-Object System.Windows.Thickness 0, 1, 0, 0
    Set-BoxBg   $box 'Bg2'
    Set-BoxLine $box 'Stroke'

    $text = New-Object System.Windows.Controls.TextBlock
    $text.FontSize = 11
    $text.TextWrapping = 'Wrap'
    Set-TextFg $text 'TextFaint'
    $box.Child = $text

    Register-LogName $Window 'LogFooterText' $text
    $box
}

function Set-LogFooterText {
    param($Window, [string]$Text, [string]$Fg = 'TextFaint')

    $label = $Window.FindName('LogFooterText')
    if (-not $label) { return }
    $label.Text = $Text
    Set-TextFg $label $Fg
}

# Los controles del cajón se registran con nombre, igual que los
# botones del menú lateral, para que los manejadores los busquen
# con FindName en vez de arrastrarlos en un closure (regla 4).
# Como el cajón se rehace cada vez que se abre, el nombre viejo
# hay que soltarlo antes.
function Register-LogName {
    param($Window, [string]$Name, $Element)
    try { $Window.UnregisterName($Name) } catch { }
    $Window.RegisterName($Name, $Element)
}

# ---- Las filas ----------------------------------------------

<#
    Vuelca las entradas en la lista y actualiza el recuento.

    Se llama al abrir el cajón y después de vaciarlo. Rehacer
    solo esto -y no el cajón entero- deja en pie la barra de
    botones desde la que suele llamarse.
#>
function Update-LogList {
    param($Window)

    $list = $Window.FindName('LogList')
    if (-not $list) { return }
    $list.Children.Clear()

    $total = Get-AppLogCount
    $shown = @(Get-AppLog -Last $LogPanelMaxRows)

    $count = $Window.FindName('LogCount')
    if ($count) { $count.Text = (T '{0} entries') -f $total }

    if ($total -eq 0) {
        $list.Children.Add((New-LogEmptyState)) | Out-Null
        Set-LogFooterText $Window (T 'Nothing has been read from your system yet')
        return
    }

    if ($shown.Count -lt $total) {
        $list.Children.Add((New-LogNotice ((T 'Showing the last {0} of {1} entries') -f $shown.Count, $total))) | Out-Null
    }

    foreach ($entry in $shown) {
        $list.Children.Add((New-LogRow $Window $entry)) | Out-Null
    }

    $dropped = Get-AppLogDropped
    if ($dropped -gt 0) {
        Set-LogFooterText $Window ((T 'Only the last {0} entries are kept; {1} older ones were discarded') -f $AppLogCapacity, $dropped)
    }
    else {
        Set-LogFooterText $Window (T 'Newest at the bottom')
    }

    # Al fondo, como una consola: lo último que ha pasado. Se
    # aplaza porque el contenido recién metido todavía no está
    # medido y el desplazamiento se recortaría a cero.
    $Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Loaded,
        [action]{
            $scroll = (Get-LogHostWindow).FindName('LogScroll')
            if ($scroll) { $scroll.ScrollToEnd() }
        }) | Out-Null
}

<#
    Una línea:

        20:14:03.118  [ leído ]  HKEY_LOCAL_MACHINE\...\SystemProfile
                                 \NetworkThrottlingIndex
                                 4294967295 (0xFFFFFFFF) - DWord - 0,4 ms

    La hora y el mensaje van en monoespaciada para que las rutas
    queden alineadas unas debajo de otras y se vea de un vistazo
    qué rama se estaba mirando.
#>
function New-LogRow {
    param($Window, $Entry)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 8
    $row.Padding = New-Object System.Windows.Thickness 8, 6, 8, 7
    $row.Background = [System.Windows.Media.Brushes]::Transparent
    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceSunken' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', 'Auto', '*'

    # --- columna 0: la hora ---
    $time = New-Object System.Windows.Controls.TextBlock
    $time.Text = '{0:HH:mm:ss.fff}' -f $Entry.Time
    $time.FontFamily = $Window.FindResource('MonoFont')
    $time.FontSize = 10.5
    $time.VerticalAlignment = 'Top'
    $time.Margin = New-Object System.Windows.Thickness 0, 1, 10, 0
    Set-TextFg $time 'TextFaint'
    Add-ToColumn $grid $time 0

    # --- columna 1: la etiqueta de estado ---
    Add-ToColumn $grid (New-LogPill $Entry) 1

    # --- columna 2: mensaje y detalle ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.Children.Add((New-LogMessage $Window $Entry.Message)) | Out-Null

    if ($Entry.Detail) {
        $detail = New-Object System.Windows.Controls.TextBlock
        $detail.Text = $Entry.Detail
        $detail.FontFamily = $Window.FindResource('MonoFont')
        $detail.FontSize = 10.5
        $detail.TextWrapping = 'Wrap'
        $detail.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
        Set-TextFg $detail 'TextFaint'
        $texts.Children.Add($detail) | Out-Null
    }

    Add-ToColumn $grid $texts 2

    $row.Child = $grid
    $row
}

<#
    El mensaje. Si es una clave del registro -ruta más nombre de
    valor- se parte por la última barra y el nombre sale
    destacado: la ruta se repite mucho y lo que cambia de una
    línea a otra es justo el final.

    Cualquier otro texto sale entero, sin más.
#>
function New-LogMessage {
    param($Window, [string]$Text)

    $line = New-Object System.Windows.Controls.TextBlock
    $line.FontFamily = $Window.FindResource('MonoFont')
    $line.FontSize = 11
    $line.LineHeight = 16
    $line.TextWrapping = 'Wrap'

    $cut = $Text.LastIndexOf('\')
    if ($cut -gt 0) {
        $path = New-Object System.Windows.Documents.Run $Text.Substring(0, $cut + 1)
        Set-TextFg $path 'TextMuted'
        $line.Inlines.Add($path)

        $name = New-Object System.Windows.Documents.Run $Text.Substring($cut + 1)
        $name.FontWeight = 'SemiBold'
        Set-TextFg $name 'Text'
        $line.Inlines.Add($name)
    }
    else {
        $whole = New-Object System.Windows.Documents.Run $Text
        $whole.FontWeight = 'SemiBold'
        Set-TextFg $whole 'Text'
        $line.Inlines.Add($whole)
    }

    $line
}

<#
    La etiqueta de color. El texto es el Status que trae la
    entrada -una palabra en inglés, ver core/Diagnostics/Log.ps1- y aquí se
    traduce; si no trae ninguno se usa el nivel.

    El ancho mínimo es a propósito: con todas las etiquetas igual
    de anchas, los mensajes empiezan en la misma columna.
#>
function New-LogPill {
    param($Entry)

    $colors = @{
        'read'             = @{ Fg = 'Success';   Bg = 'SuccessSoft' }
        'not set'          = @{ Fg = 'Warn';      Bg = 'WarnSoft' }
        'no access'        = @{ Fg = 'Danger';    Bg = 'DangerSoft' }
        'unknown root key' = @{ Fg = 'Danger';    Bg = 'DangerSoft' }
        'reading'          = @{ Fg = 'Accent';    Bg = 'AccentSoft' }
        'done'             = @{ Fg = 'Accent';    Bg = 'AccentSoft' }
        'error'            = @{ Fg = 'Danger';    Bg = 'DangerSoft' }
        'warn'             = @{ Fg = 'Warn';      Bg = 'WarnSoft' }
        'info'             = @{ Fg = 'TextMuted'; Bg = 'SurfaceSunken' }
    }

    $word = $Entry.Status
    if (-not $word) { $word = $Entry.Level }

    $color = $colors[$word]
    if (-not $color) { $color = $colors[$Entry.Level] }
    if (-not $color) { $color = @{ Fg = 'TextMuted'; Bg = 'SurfaceSunken' } }

    $pill = New-Object System.Windows.Controls.Border
    $pill.CornerRadius = New-Object System.Windows.CornerRadius 6
    $pill.Padding = New-Object System.Windows.Thickness 7, 1.5, 7, 2.5
    $pill.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
    $pill.MinWidth = 78
    $pill.VerticalAlignment = 'Top'
    Set-BoxBg $pill $color.Bg

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = T $word
    $text.FontSize = 10
    $text.FontWeight = 'SemiBold'
    $text.TextAlignment = 'Center'
    Set-TextFg $text $color.Fg
    $pill.Child = $text

    $pill
}

# Aviso gris entre las filas ("se enseñan las últimas 400...").
function New-LogNotice {
    param([string]$Text)

    $note = New-Object System.Windows.Controls.TextBlock
    $note.Text = $Text
    $note.FontSize = 11
    $note.TextWrapping = 'Wrap'
    $note.TextAlignment = 'Center'
    $note.Margin = New-Object System.Windows.Thickness 8, 4, 8, 10
    Set-TextFg $note 'TextFaint'
    $note
}

# Lo que se ve nada más arrancar, antes de entrar en ninguna
# sección: el log está vacío porque no se ha leído nada todavía.
function New-LogEmptyState {
    $box = New-Object System.Windows.Controls.StackPanel
    $box.Margin = New-Object System.Windows.Thickness 0, 60, 0, 0
    $box.HorizontalAlignment = 'Center'

    $icon = New-Icon 'Pulse' 30 'TextFaint'
    $box.Children.Add($icon) | Out-Null

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Nothing logged yet'
    $title.FontSize = 13
    $title.FontWeight = 'SemiBold'
    $title.HorizontalAlignment = 'Center'
    $title.Margin = New-Object System.Windows.Thickness 0, 12, 0, 0
    Set-TextFg $title 'TextMuted'
    $box.Children.Add($title) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'Open a section and its registry keys will show up here'
    $hint.FontSize = 11.5
    $hint.TextAlignment = 'Center'
    $hint.TextWrapping = 'Wrap'
    $hint.MaxWidth = 320
    $hint.Margin = New-Object System.Windows.Thickness 0, 5, 0, 0
    Set-TextFg $hint 'TextFaint'
    $box.Children.Add($hint) | Out-Null

    $box
}

# ---- fin incluido: ui/Components/Shell/LogPanel.ps1 ----
# ---- inicio incluido: ui/Components/Shell/LogWindow.ps1 ----
# ============================================================
# Componente: el registro de actividad, en su propia ventana
#
# El mismo contenido que el cajón de LogPanel.ps1, pero sacado a
# una ventana aparte que se puede mover, redimensionar, minimizar,
# maximizar y cerrar, y volver a acoplar cuando estorbe menos
# dentro. Sirve para dejar el log a la vista en otro monitor
# mientras se navega por las secciones.
#
#   cajón  --[sacar]-->  ventana  --[acoplar]-->  cajón
#
# Lo que hay que saber de esta ventana:
#
# - Se construye POR CÓDIGO, no en XAML. build.ps1 solo sabe
#   incrustar UN xaml (el de la ventana principal): un segundo
#   archivo .xaml funcionaría en desarrollo y faltaría en el .exe.
#   Es el mismo motivo por el que el menú lateral se arma a mano.
#
# - Es HIJA de la principal (Owner). Eso le da dos cosas gratis:
#   se cierra sola cuando se cierra el programa -si no, quedaría
#   una ventana viva impidiendo salir- y sigue siendo usable
#   aunque la principal se muestre con ShowDialog, que si no
#   dejaría inservible cualquier otra ventana.
#
# - COMPARTE LOS RECURSOS del tema por MergedDictionaries, así que
#   alternar claro/oscuro la repinta a la vez que a la principal
#   sin que haya que enterarse aquí.
#
# - NO TIENE CROMO de Windows (WindowStyle None + WindowChrome),
#   igual que la ventana principal: los bordes de redimensión son
#   los nativos y la barra de título es la propia cabecera del
#   registro, que ya trae los botones.
# ============================================================

# La ventana, mientras exista. $null cuando el log está acoplado
# o cerrado.
$LogWindow = $null

# Dónde se abre el log al pulsar el botón de la barra de título.
# Se recuerda dentro de la sesión: si lo sacaste y lo cerraste, la
# próxima vez vuelve a salir fuera. No se guarda en settings.json a
# propósito, para que arrancar el programa empiece siempre con el
# log recogido.
$LogFloating = $false

function Get-LogWindow   { $script:LogWindow }
function Get-LogFloating { $script:LogFloating }
function Get-LogDetached { $null -ne $script:LogWindow }

# Quién aloja ahora mismo las filas del registro. Lo usa
# Update-LogList para encontrar su ScrollViewer sin que le importe
# dónde está pintado.
function Get-LogHostWindow {
    if ($script:LogWindow) { $script:LogWindow } else { Get-AppWindow }
}

# ---- Sacar, acoplar, cerrar ---------------------------------

<#
    Saca el registro a su propia ventana.

    Si ya está fuera no crea otra: la trae al frente, que es lo
    que espera quien vuelve a pulsar el botón.
#>
function Open-LogWindow {
    if ($script:LogWindow) { Show-LogWindowFront; return }

    $main = Get-AppWindow
    if (-not $main) { return }

    # El cajón se retira sin esperar a su animación: Close-LogOverlay
    # colapsa ya, porque Hide-LogPanel deja el panel marcado como
    # cerrado antes de animar nada.
    Hide-LogPanel $main
    Close-LogOverlay $main

    $script:LogFloating = $true
    $script:LogWindow = New-LogWindow $main

    # Después de guardar la ventana, no antes: Update-LogList
    # pregunta por Get-LogHostWindow para dejar el scroll al final.
    Update-LogList $script:LogWindow

    $script:LogWindow.Show()
    $script:LogWindow.Activate() | Out-Null
}

# Devuelve el registro al cajón de la ventana principal.
function Join-LogPanel {
    $win = $script:LogWindow
    $script:LogFloating = $false

    # Al cerrarse, su manejador Closed deja $LogWindow en $null, de
    # modo que el cajón ya cuenta como alojamiento actual.
    if ($win) { $win.Close() }

    Show-LogPanel (Get-AppWindow)
}

# Cierra la ventana sin acoplar: el log queda escondido, y el botón
# de la barra de título lo volverá a sacar fuera.
function Close-LogWindow {
    if ($script:LogWindow) { $script:LogWindow.Close() }
}

# La trae al frente, restaurándola si estaba minimizada.
function Show-LogWindowFront {
    $win = $script:LogWindow
    if (-not $win) { return }
    if ($win.WindowState -eq 'Minimized') { $win.WindowState = 'Normal' }
    $win.Activate() | Out-Null
}

function Switch-LogWindowState {
    param($Window)
    if ($Window.WindowState -eq 'Maximized') { $Window.WindowState = 'Normal' }
    else                                     { $Window.WindowState = 'Maximized' }
}

# Arrastrar la ventana desde su cabecera, y doble clic para
# maximizar. Igual que la barra de título de la principal.
#
# Los botones de la cabecera no se ven afectados: un Button marca
# como tratado el MouseLeftButtonDown, así que no llega hasta aquí.
function Add-LogWindowDrag {
    param($Element)

    $Element.Add_MouseLeftButtonDown({
        param($s, $e)
        $win = [System.Windows.Window]::GetWindow($s)
        if (-not $win) { return }

        if ($e.ClickCount -eq 2) { Switch-LogWindowState $win; return }
        # DragMove lanza si el botón ya no está pulsado.
        if ($e.ButtonState -eq 'Pressed') { $win.DragMove() }
    })
}

# ---- La ventana ---------------------------------------------

<#
    Construye la ventana. No la enseña ni toca el estado: eso es de
    Open-LogWindow, para que las pruebas puedan armar el árbol sin
    que aparezca nada en pantalla.
#>
function New-LogWindow {
    param($Main)

    $win = New-Object System.Windows.Window
    $win.Title = T 'Activity log'
    $win.Width = 760
    $win.Height = 640
    $win.MinWidth = 460
    $win.MinHeight = 320
    $win.WindowStyle = 'None'
    $win.ResizeMode = 'CanResize'
    $win.ShowInTaskbar = $true
    $win.FontFamily = $Main.FontFamily
    $win.SnapsToDevicePixels = $true
    $win.UseLayoutRounding = $true

    # Una ventana creada por código no trae NameScope -el de la
    # principal lo monta el cargador de XAML-, y sin él RegisterName
    # lanza con "No se encontró ningún NameScope". Tiene que estar
    # puesto ANTES de construir nada que se registre.
    [System.Windows.NameScope]::SetNameScope($win, (New-Object System.Windows.NameScope))

    # Mismo diccionario que la principal: un cambio de tema muta
    # esos pinceles y los DynamicResource de aquí se enteran solos.
    $win.Resources.MergedDictionaries.Add($Main.Resources)
    Set-WinBg $win 'Bg1'

    # Owner solo admite una ventana que ya se haya mostrado. En las
    # pruebas no se muestra ninguna, así que ahí se queda huérfana
    # -y entonces centrarla sobre la principal tampoco tendría
    # sentido-.
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $Main
    if ($helper.Handle -ne [IntPtr]::Zero) {
        $win.Owner = $Main
        $win.WindowStartupLocation = 'CenterOwner'
    }
    else {
        $win.WindowStartupLocation = 'CenterScreen'
    }

    # Bordes de redimensión nativos sin barra de título de Windows,
    # igual que MainWindow.xaml.
    $chrome = New-Object System.Windows.Shell.WindowChrome
    $chrome.CaptionHeight = 0
    $chrome.ResizeBorderThickness = New-Object System.Windows.Thickness 6
    $chrome.GlassFrameThickness = New-Object System.Windows.Thickness 0
    $chrome.CornerRadius = New-Object System.Windows.CornerRadius 0
    $chrome.UseAeroCaptionButtons = $false
    [System.Windows.Shell.WindowChrome]::SetWindowChrome($win, $chrome)

    $root = New-Object System.Windows.Controls.Border
    $root.BorderThickness = New-Object System.Windows.Thickness 1
    Set-BoxBg   $root 'Bg1'
    Set-BoxLine $root 'Stroke'
    $root.Child = New-LogContent $win -Floating
    $win.Content = $root

    # El glifo de maximizar alterna con el de restaurar, como en la
    # ventana principal.
    $win.Add_StateChanged({
        param($s, $e)
        $btn = $s.FindName('LogBtnMaximize')
        if (-not $btn) { return }
        if ($s.WindowState -eq 'Maximized') { $btn.Content = Glyph 'Restore' }
        else                                { $btn.Content = Glyph 'Maximize' }
    })

    # Se cierre como se cierre -su botón, Alt+F4, o al salir del
    # programa por ser hija- el estado tiene que quedar limpio, o el
    # botón de la barra de título intentaría enfocar una ventana
    # muerta.
    $win.Add_Closed({
        param($s, $e)
        Clear-LogWindowState
    })

    $win
}

function Clear-LogWindowState { $script:LogWindow = $null }

# Rehace el contenido de la ventana. Lo llama el cambio de idioma,
# igual que Update-LogPanel rehace el cajón.
function Update-LogWindow {
    $win = $script:LogWindow
    if (-not $win) { return }

    $win.Title = T 'Activity log'
    $win.Content.Child = New-LogContent $win -Floating
    Update-LogList $win
}

# ---- fin incluido: ui/Components/Shell/LogWindow.ps1 ----
# ---- inicio incluido: ui/Components/Shell/ProgressStrip.ps1 ----
# ============================================================
# Componente: barra de progreso
#
# La franja del pie de la ventana, para tareas que tardan. Hoy la
# usa la lectura del registro al entrar en una sección; conforme
# haya más claves que consultar, más se notará.
#
# El contenedor está en MainWindow.xaml y arranca colapsado: sin
# alto, así que aparecer y desaparecer no mueve el contenido.
#
# Ojo con Set-ProgressStrip: obliga a WPF a repintar en mitad del
# bucle que lo llama. Ver el comentario de Update-UiNow.
# ============================================================

function Show-ProgressStrip {
    param($Window, [string]$Text)

    $Window.FindName('ProgressText').Text = T $Text
    $Window.FindName('ProgressCount').Text = ''
    Set-ProgressFill $Window 0 1
    $Window.FindName('ProgressStrip').Visibility = 'Visible'
    Update-UiNow $Window
}

# Avance de la barra. $Total = 0 se ignora en vez de dividir por cero.
function Set-ProgressStrip {
    param($Window, [int]$Done, [int]$Total)

    if ($Total -le 0) { return }

    $Window.FindName('ProgressCount').Text = "$Done/$Total"
    Set-ProgressFill $Window $Done $Total
    Update-UiNow $Window
}

function Hide-ProgressStrip {
    param($Window)
    $Window.FindName('ProgressStrip').Visibility = 'Collapsed'
}

# El relleno son dos columnas estrella que se reparten el ancho:
# hecho / lo que falta. Así no hay que medir la ventana.
function Set-ProgressFill {
    param($Window, [double]$Done, [double]$Total)

    $left = $Total - $Done
    if ($left -lt 0) { $left = 0 }

    $Window.FindName('ProgressDone').Width = [System.Windows.GridLength]::new($Done, 'Star')
    $Window.FindName('ProgressLeft').Width = [System.Windows.GridLength]::new($left, 'Star')
}

<#
    Vacía la cola del Dispatcher para que lo pintado hasta ahora
    llegue a la pantalla.

    Hace falta porque la lectura del registro es SÍNCRONA: mientras
    el bucle corre, el hilo de interfaz está ocupado y la barra no
    se redibujaría sola; se vería saltar de 0 a 100 al terminar.

    Es el equivalente del viejo DoEvents, con lo que eso implica:
    durante la pausa WPF puede entregar eventos de ratón. Por eso
    quien la usa deja la ventana bloqueada mientras dura (ver
    Show-CategoryDetailView). Si algún día la lectura se va a un
    hilo aparte, esta función sobra.
#>
function Update-UiNow {
    param($Window)

    $frame = New-Object System.Windows.Threading.DispatcherFrame
    $Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{ $frame.Continue = $false }) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

# ---- fin incluido: ui/Components/Shell/ProgressStrip.ps1 ----
# ---- inicio incluido: ui/Components/Shell/SearchBar.ps1 ----
# ============================================================
# Componente: la caja de búsqueda con resultados en vivo
#
# La caja de la cabecera, más un desplegable que se abre debajo
# según se escribe. Es el mismo patrón del menú "Vista": el Popup
# TIENE que colgar del Grid que devuelve esta función, porque suelto
# quedaría fuera del árbol lógico y los colores del tema no
# resolverían.
#
# Por qué un desplegable y no navegar en cada tecla
# -------------------------------------------------
# La cabecera se rehace entera en cada pintada, así que navegar
# mientras escribes destruiría la propia caja en la que estás
# escribiendo: habría que recrearla, devolverle el texto, el foco y
# el cursor... en cada pulsación. Con el desplegable no te mueves de
# donde estás, Escape lo cierra y Enter te lleva a la página con
# todos los resultados.
#
#   escribir  ->  desplegable (los primeros resultados, agrupados)
#   Enter     ->  Show-SearchResultsView (todos, agrupados)
#   Escape    ->  cerrar y seguir donde estabas
#
# Se espera un momento desde la última tecla antes de buscar
# (antirrebote): escribir "telemetría" son diez pulsaciones y una
# sola búsqueda, no diez.
# ============================================================

$SearchBarWidth = 300.0
$SearchPopupWidth = 470.0
$SearchPopupMax = 7          # filas antes de mandar a la página
$SearchDebounceMs = 160

$SearchDebounceTimer = $null
$SearchPendingBox = $null
$SearchFocusBox = $null

function New-SearchBar {
    param($Window, [string]$Text, [switch]$Focus)

    $shell = New-Object System.Windows.Controls.Grid
    $shell.VerticalAlignment = 'Center'

    $search = New-SearchBox -Window $Window -Width $SearchBarWidth
    $shell.Children.Add($search.Root) | Out-Null

    $box = $search.Box

    # El texto se pone ANTES de enganchar los manejadores: así volver
    # a pintar la pantalla con una búsqueda en marcha no dispara otra
    # búsqueda, ni abre el desplegable solo.
    if ($Text) { $box.Text = $Text }

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.PlacementTarget = $search.Root
    $popup.Placement = 'Bottom'
    $popup.VerticalOffset = 6
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'Fade'
    $shell.Children.Add($popup) | Out-Null

    # El desplegable viaja en el Tag de la caja (regla 4: sin
    # closures). El marcador de "Search optimizations..." ya no lo
    # usa, justamente para dejarlo libre aquí.
    $box.Tag = $popup
    $box.Add_TextChanged({ param($s, $e) Start-SearchDebounce $s })
    $box.Add_PreviewKeyDown({ param($s, $e) Invoke-SearchKey $s $e })

    if ($Focus) {
        # El control todavía no está en el árbol: pedirle el foco
        # ahora no haría nada.
        $script:SearchFocusBox = $box
        $Window.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Loaded,
            [action]{ Set-SearchFocus }) | Out-Null
    }

    $shell
}

function Set-SearchFocus {
    $box = $script:SearchFocusBox
    $script:SearchFocusBox = $null
    if (-not $box) { return }

    $box.Focus() | Out-Null
    $box.CaretIndex = $box.Text.Length
}

# ---- Teclado -------------------------------------------------

function Invoke-SearchKey {
    param($Box, $EventArgs)

    switch ($EventArgs.Key) {
        ([System.Windows.Input.Key]::Enter) {
            $texto = [string]$Box.Text
            if ([string]::IsNullOrWhiteSpace($texto)) { return }

            Stop-SearchDebounce
            if ($Box.Tag) { $Box.Tag.IsOpen = $false }
            Set-SearchQuery $texto
            Show-View -Name 'Show-SearchResultsView'
            $EventArgs.Handled = $true
        }
        ([System.Windows.Input.Key]::Escape) {
            # Handled solo si había algo que cerrar: si no, Escape
            # tiene que seguir llegando al cajón del log.
            if ($Box.Tag -and $Box.Tag.IsOpen) {
                $Box.Tag.IsOpen = $false
                $EventArgs.Handled = $true
            }
        }
    }
}

# ---- Antirrebote ---------------------------------------------

function Start-SearchDebounce {
    param($Box)

    $script:SearchPendingBox = $Box

    if (-not $script:SearchDebounceTimer) {
        $script:SearchDebounceTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:SearchDebounceTimer.Interval = [TimeSpan]::FromMilliseconds($SearchDebounceMs)
        # Un DispatcherTimer no tiene Tag donde dejar la caja, así que
        # el manejador llama a la función y es ella la que mira el
        # estado del módulo.
        $script:SearchDebounceTimer.Add_Tick({ param($s, $e) Invoke-PendingSearch })
    }

    $script:SearchDebounceTimer.Stop()
    $script:SearchDebounceTimer.Start()
}

function Stop-SearchDebounce {
    if ($script:SearchDebounceTimer) { $script:SearchDebounceTimer.Stop() }
}

function Invoke-PendingSearch {
    Stop-SearchDebounce

    $box = $script:SearchPendingBox
    if (-not $box) { return }

    Update-SearchPopup $box
}

# ---- El desplegable ------------------------------------------

<#
    Rehace el contenido del desplegable con lo que haya escrito.

    Sin texto se cierra: una lista de todo no ayuda a nadie. Y si la
    pantalla actual ya es la de resultados, además se repinta, para
    que la página y el desplegable no digan cosas distintas.
#>
function Update-SearchPopup {
    param($Box)

    $popup = $Box.Tag
    if (-not $popup) { return }

    $query = [string]$Box.Text
    Set-SearchQuery $query

    if ([string]::IsNullOrWhiteSpace($query)) {
        $popup.IsOpen = $false
        if ((Get-CurrentViewName) -eq 'Show-SearchResultsView') { Update-SearchResults (Get-AppWindow) }
        return
    }

    $window = Get-AppWindow
    $results = Get-SearchResults $query

    $popup.Child = New-SearchPopupCard -Window $window -Popup $popup -Results $results -Query $query
    $popup.HorizontalOffset = $popup.PlacementTarget.ActualWidth - $SearchPopupWidth
    $popup.IsOpen = $true

    if ((Get-CurrentViewName) -eq 'Show-SearchResultsView') { Update-SearchResults $window }
}

# La tarjeta flotante: los primeros resultados agrupados por sección
# y, si hay más, una fila que lleva a la página completa.
function New-SearchPopupCard {
    param($Window, $Popup, $Results, [string]$Query)

    # AllowsTransparency recorta lo que se salga del Popup, así que
    # la sombra necesita este margen para caber.
    $room = New-Object System.Windows.Controls.Grid
    $room.Margin = New-Object System.Windows.Thickness 12, 0, 12, 16

    $card = New-Object System.Windows.Controls.Border
    $card.Width = $SearchPopupWidth
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.BorderThickness = New-Object System.Windows.Thickness 1
    $card.Padding = New-Object System.Windows.Thickness 7, 8, 7, 8
    Set-BoxBg   $card 'Surface'
    Set-BoxLine $card 'Stroke'

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 3
    $shadow.BlurRadius = 16; $shadow.Opacity = 0.18
    $card.Effect = $shadow

    $rows = New-Object System.Windows.Controls.StackPanel

    $todos = @($Results)
    if ($todos.Count -eq 0) {
        $rows.Children.Add((New-SearchEmptyState -Window $Window -Query $Query -Compact)) | Out-Null
        $card.Child = $rows
        $room.Children.Add($card) | Out-Null
        return $room
    }

    $mostrados = 0
    foreach ($group in (Group-SearchResults $todos)) {
        if ($mostrados -ge $SearchPopupMax) { break }

        $cabecera = New-SearchGroupHeader $Window $group.Category $group.Entries.Count
        $cabecera.Margin = New-Object System.Windows.Thickness 8, 8, 0, 4
        $rows.Children.Add($cabecera) | Out-Null

        foreach ($entry in $group.Entries.ToArray()) {
            if ($mostrados -ge $SearchPopupMax) { break }
            $rows.Children.Add((New-SearchResultRow $Window $entry $Popup)) | Out-Null
            $mostrados++
        }
    }

    if ($todos.Count -gt $mostrados) {
        $rows.Children.Add((New-SearchSeeAllRow $Window $Popup $todos.Count)) | Out-Null
    }

    $card.Child = $rows
    $room.Children.Add($card) | Out-Null
    $room
}

# "Ver los 12 resultados" — la fila del final, que lleva a la página.
function New-SearchSeeAllRow {
    param($Window, $Popup, [int]$Total)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 9
    $row.Padding = New-Object System.Windows.Thickness 10, 8, 10, 9
    $row.Margin = New-Object System.Windows.Thickness 0, 4, 0, 0
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = (T 'See all {0} results') -f $Total
    $text.FontSize = 11.5
    $text.FontWeight = 'SemiBold'
    Set-TextFg $text 'Accent'
    $row.Child = $text

    $row.Tag = $Popup
    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $row.Add_MouseLeftButtonUp({
        param($s, $e)
        $s.Tag.IsOpen = $false
        Show-View -Name 'Show-SearchResultsView'
    })

    $row
}

# ---- fin incluido: ui/Components/Shell/SearchBar.ps1 ----
# ---- inicio incluido: ui/Components/Shell/Sidebar.ps1 ----
# ============================================================
# Componente: barra de navegación lateral
#
# Construye los botones a partir de ui/Index/NavigationIndex.ps1 y
# gestiona el plegado animado.
#
# El XAML solo aporta dos contenedores vacíos (NavTop y
# NavBottom) dentro del Border llamado Sidebar; todo lo demás
# se crea aquí.
# ============================================================

# Ancho del panel desplegado. Al plegarse se anima hasta 0.
$SidebarWidth = 88.0
$SidebarExpanded = $true

# ---- Construcción -------------------------------------------

function Build-Sidebar {
    param($Window)

    $top    = $Window.FindName('NavTop')
    $bottom = $Window.FindName('NavBottom')
    $top.Children.Clear()
    $bottom.Children.Clear()

    foreach ($item in Get-NavigationItems) {
        $button = New-NavButton -Window $Window -Item $item
        if ($item.Group -eq 'Bottom') {
            $bottom.Children.Add($button) | Out-Null
        } else {
            $top.Children.Add($button) | Out-Null
        }
    }

    Update-NavColors $Window
}

function New-NavButton {
    param($Window, $Item)

    $button = New-Object System.Windows.Controls.Button
    $button.Style = $Window.FindResource('NavButtonStyle')

    $stack = New-Object System.Windows.Controls.StackPanel

    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.FontFamily = $Window.FindResource('IconFont')
    $icon.Text = Glyph $Item.Icon
    $icon.FontSize = 19
    $icon.HorizontalAlignment = 'Center'
    Set-TextFg $icon 'TextMuted'
    $stack.Children.Add($icon) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T $Item.Label
    $label.FontSize = 9.5
    $label.HorizontalAlignment = 'Center'
    $label.Margin = New-Object System.Windows.Thickness 0, 5, 0, 0
    Set-TextFg $label 'TextMuted'
    $stack.Children.Add($label) | Out-Null

    $button.Content = $stack

    if ($Item.Locked) {
        $button.IsEnabled = $false
        $button.Opacity = 0.4
        $button.ToolTip = (T '{0}: locked') -f (T $Item.Label)
        $icon.Text = Glyph 'Lock'
    }
    elseif ($Item.Default) {
        $button.Tag = 'sel'
    }

    # El Uid guarda el Id de la entrada: así el handler puede
    # averiguar a qué vista lleva sin recurrir a un closure.
    $button.Uid = $Item.Id
    $button.Add_Click({ param($s, $e) Set-NavSelection $s })

    # Se registra con su nombre para que $Window.FindName siga
    # encontrándolo aunque el botón ya no exista en el XAML.
    $name = Get-NavElementName $Item.Id
    try { $Window.UnregisterName($name) } catch { }
    $Window.RegisterName($name, $button)

    $button
}

# ---- Selección ----------------------------------------------

function Set-NavSelection {
    param($Button)

    # Cada entrada declara su vista en ui/Index/NavigationIndex.ps1.
    #
    # Sin View, la sección aún no tiene pantalla y el clic se queda
    # aquí: NADA de mandar a una vista de relleno -eso deja el menú
    # marcando una cosa y la pantalla enseñando otra-. El botón se ve
    # y responde como los demás, pero no navega ni mueve la
    # selección, así que el usuario sigue exactamente donde estaba.
    $item = Get-NavigationItem $Button.Uid
    if (-not $item -or -not $item.View) { return }

    # Marcar el botón NO se hace aquí: lo hace Sync-NavSelection al
    # terminar de navegar. Así hay un solo sitio que decida qué está
    # marcado, y da igual si se ha llegado pulsando o de otra forma.
    Show-View -Name $item.View
}

<#
    Deja marcada la entrada del menú que enseña la pantalla actual.

    Hace falta porque a una vista se puede llegar SIN pulsar su
    botón: a la de búsqueda se entra también con Enter desde la caja
    de la cabecera. Sin esto el menú marcaría "Optimizar" mientras la
    pantalla enseña la búsqueda — exactamente lo que la regla 13 pide
    evitar.

    Si la pantalla actual no es la de ninguna entrada -el detalle de
    una sección, por ejemplo- NO se toca nada: se sigue marcando
    aquella desde la que se entró, que es lo que uno espera al bajar
    un nivel.
#>
function Sync-NavSelection {
    param($Window, [string]$ViewName)

    if (-not $Window -or -not $ViewName) { return }

    $item = @(Get-NavigationItems | Where-Object { $_.View -eq $ViewName })[0]
    if (-not $item) { return }

    $button = $Window.FindName((Get-NavElementName $item.Id))
    # Sin menú construido no hay nada que marcar: pasa en las pruebas,
    # que pintan vistas sobre una ventana pelada.
    if (-not $button) { return }

    foreach ($nav in Get-NavigationItems) {
        $otro = $Window.FindName((Get-NavElementName $nav.Id))
        if ($otro) { $otro.Tag = $null }
    }
    $button.Tag = 'sel'
    Update-NavColors $Window
}

# El estilo del XAML pinta el fondo del botón seleccionado; el
# color del icono y de la etiqueta se ajusta aquí.
function Update-NavColors {
    param($Window)

    foreach ($item in Get-NavigationItems) {
        $button = $Window.FindName((Get-NavElementName $item.Id))
        if (-not $button) { continue }

        if ($button.Tag -eq 'sel') { $key = 'Accent'; $weight = 'SemiBold' }
        else                       { $key = 'TextMuted'; $weight = 'Normal' }

        $icon  = $button.Content.Children[0]
        $label = $button.Content.Children[1]
        Set-TextFg $icon  $key
        Set-TextFg $label $key
        $label.FontWeight = $weight
    }
}

# ---- Plegado animado ----------------------------------------

function Set-SidebarExpanded {
    param($Window, [bool]$Expanded, [int]$Ms = 220)

    $sidebar = $Window.FindName('Sidebar')
    $button  = $Window.FindName('BtnMenu')

    if ($Expanded) { $to = $SidebarWidth } else { $to = 0.0 }

    # El borde derecho de 1px impide que el ancho llegue de verdad
    # a cero: se quita al plegar y se repone al desplegar.
    if ($Expanded) {
        $sidebar.BorderThickness = New-Object System.Windows.Thickness 0, 1, 1, 0
    } else {
        $sidebar.BorderThickness = New-Object System.Windows.Thickness 0
    }

    # Se anima el ancho del Border, no la columna del Grid: la
    # columna es Auto, así que sigue al Border sola. Animar un
    # GridLength requiere una animación propia que WPF no trae.
    $sidebar.BeginAnimation(
        [System.Windows.FrameworkElement]::WidthProperty,
        (New-Anim $sidebar.ActualWidth $to $Ms))

    # El contenido se desvanece un poco antes de terminar de
    # plegarse, para que no se vea recortado a media animación.
    if ($Expanded) { $fade = New-Anim 0 1 $Ms } else { $fade = New-Anim 1 0 ([int]($Ms * 0.6)) }
    $sidebar.Child.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)

    if ($button) {
        if ($Expanded) { $button.ToolTip = T 'Hide the menu' } else { $button.ToolTip = T 'Show the menu' }
    }

    $script:SidebarExpanded = $Expanded
}

function Switch-Sidebar {
    param($Window)
    Set-SidebarExpanded -Window $Window -Expanded (-not $SidebarExpanded)
}

function Get-SidebarExpanded { $script:SidebarExpanded }

# ---- fin incluido: ui/Components/Shell/Sidebar.ps1 ----
# ---- inicio incluido: ui/Components/Shell/TitleBar.ps1 ----
# ============================================================
# Componente: barra de título
#
# El XAML deja los textos en inglés porque no puede llamar a T;
# aquí se traducen al arrancar y cada vez que cambia el idioma.
# ============================================================

function Update-TitleBarTexts {
    param($Window)

    $Window.FindName('BtnModeNormal').Content  = T 'Normal'
    $Window.FindName('BtnModeBuilder').Content = T 'Builder'
    $Window.FindName('BtnModeConfig').Content  = T 'Config Review'

    $Window.FindName('BtnLog').ToolTip   = T 'Activity log'
    $Window.FindName('BtnTheme').ToolTip = T 'Change theme'
    $Window.FindName('BtnHelp').ToolTip  = T 'Help'

    $menu = $Window.FindName('BtnMenu')
    if (Get-SidebarExpanded) { $menu.ToolTip = T 'Hide the menu' } else { $menu.ToolTip = T 'Show the menu' }
}

# El glifo del botón de tema refleja a qué tema se cambiaría:
# con tema claro se ve una luna, con tema oscuro un sol.
function Sync-ThemeButton {
    $window = Get-AppWindow
    if (-not $window) { return }

    $button = $window.FindName('BtnTheme')
    if ((Get-AppTheme) -eq 'Dark') { $button.Content = Glyph 'Sun' } else { $button.Content = Glyph 'Moon' }
}

# ---- fin incluido: ui/Components/Shell/TitleBar.ps1 ----
# ---- inicio incluido: ui/Components/Shell/ViewMenu.ps1 ----
# ============================================================
# Componente: menú del botón "Vista"
#
# El chip "Vista" de la cabecera y el desplegable que abre. Las
# filas salen de ui/Index/ViewOptionsIndex.ps1, así que este archivo
# no sabe cuáles son ni cuántas hay.
#
# Devuelve un Grid con el botón y el Popup dentro. El Popup TIENE
# que colgar de ese Grid: si se creara suelto quedaría fuera del
# árbol lógico y los SetResourceReference del tema no resolverían.
#
# Cada fila cambia una opción de vista y repinta la pantalla
# actual, porque las insignias y los detalles técnicos se deciden
# al construir cada tarjeta.
# ============================================================

function New-ViewMenu {
    param($Window, [string]$Label = 'View')

    $shell = New-Object System.Windows.Controls.Grid
    $shell.VerticalAlignment = 'Center'

    $button = New-ChipButton $Window $Label 'Filter' -Chevron
    $shell.Children.Add($button) | Out-Null

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.PlacementTarget = $button
    $popup.Placement = 'Bottom'
    $popup.VerticalOffset = 4
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'Fade'
    $popup.Child = (New-ViewMenuCard $Window $popup)
    $shell.Children.Add($popup) | Out-Null

    # El popup viaja en el Tag del botón: nada de closures
    # (regla 4 de CLAUDE.md).
    $button.Tag = $popup
    $button.Add_Click({
        param($s, $e)
        $pop = $s.Tag
        # El desplegable se alinea por la derecha con el botón,
        # que vive pegado al borde de la ventana. El ancho real
        # solo se conoce una vez medido, de ahí que se calcule
        # aquí y no al construirlo.
        $pop.HorizontalOffset = $s.ActualWidth - $ViewMenuWidth
        $pop.IsOpen = -not $pop.IsOpen
    })

    $shell
}

# Ancho del desplegable. También lo usa el cálculo del offset.
$ViewMenuWidth = 300.0

# La tarjeta flotante: marco + una fila por opción.
function New-ViewMenuCard {
    param($Window, $Popup)

    # AllowsTransparency recorta lo que se salga del Popup, así que
    # la sombra necesita este margen para caber.
    $room = New-Object System.Windows.Controls.Grid
    $room.Margin = New-Object System.Windows.Thickness 10, 0, 10, 14

    $card = New-Object System.Windows.Controls.Border
    $card.Width = $ViewMenuWidth
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.BorderThickness = New-Object System.Windows.Thickness 1
    $card.Padding = New-Object System.Windows.Thickness 6, 7, 6, 7
    Set-BoxBg   $card 'Surface'
    Set-BoxLine $card 'Stroke'

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 3
    $shadow.BlurRadius = 16; $shadow.Opacity = 0.18
    $card.Effect = $shadow

    $rows = New-Object System.Windows.Controls.StackPanel

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Show on screen'
    $title.FontSize = 10.5
    $title.FontWeight = 'SemiBold'
    $title.Margin = New-Object System.Windows.Thickness 11, 4, 0, 7
    Set-TextFg $title 'TextFaint'
    $rows.Children.Add($title) | Out-Null

    foreach ($option in Get-ViewOptions) {
        $rows.Children.Add((New-ViewMenuRow $Window $option $Popup)) | Out-Null
    }

    $card.Child = $rows
    $room.Children.Add($card) | Out-Null
    $room
}

# Una fila con casilla: [check] [icono] [etiqueta + pista]
function New-ViewMenuRow {
    param($Window, $Option, $Popup)

    $checked = Get-ViewOption $Option.Id

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 8
    $row.Padding = New-Object System.Windows.Thickness 9, 8, 10, 9
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', 'Auto', '*'

    # --- columna 0: la marca de verificación ---
    # Los dos iconos se alinean arriba para quedar a la altura del
    # título, no del centro de la fila, que con la pista de debajo
    # los dejaría junto al texto pequeño.
    $check = New-Icon 'Check' 13 'Accent'
    $check.Width = 18
    $check.HorizontalAlignment = 'Left'
    $check.VerticalAlignment = 'Top'
    $check.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
    if ($checked) { $check.Visibility = 'Visible' } else { $check.Visibility = 'Hidden' }
    Add-ToColumn $grid $check 0

    # --- columna 1: icono de la opción ---
    $icon = New-Icon $Option.Icon 13 'TextMuted'
    $icon.Margin = New-Object System.Windows.Thickness 0, 2, 9, 0
    $icon.VerticalAlignment = 'Top'
    Add-ToColumn $grid $icon 1

    # --- columna 2: etiqueta y pista ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T $Option.Label
    $label.FontSize = 12.5
    $label.FontWeight = 'SemiBold'
    Set-TextFg $label 'Text'
    $texts.Children.Add($label) | Out-Null

    if ($Option.Hint) {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = T $Option.Hint
        $hint.FontSize = 11
        $hint.TextWrapping = 'Wrap'
        $hint.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
        Set-TextFg $hint 'TextMuted'
        $texts.Children.Add($hint) | Out-Null
    }

    Add-ToColumn $grid $texts 2
    $row.Child = $grid

    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceSunken' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    # Todo lo que hace falta al pulsar, por el Tag.
    $row.Tag = [PSCustomObject]@{ Id = $Option.Id; Check = $check; Popup = $Popup }
    $row.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        $new = -not (Get-ViewOption $info.Id)
        Set-ViewOption $info.Id $new
        if ($new) { $info.Check.Visibility = 'Visible' } else { $info.Check.Visibility = 'Hidden' }

        $info.Popup.IsOpen = $false

        # Repintar destruye la cabecera donde vive este mismo menú,
        # así que se aplaza al Dispatcher para que el evento termine
        # antes (mismo motivo que en Update-UiLanguage).
        (Get-AppWindow).Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{ Show-CurrentView }) | Out-Null
    })

    $row
}

# ---- fin incluido: ui/Components/Shell/ViewMenu.ps1 ----

# ---- 7. Pantallas: ensamblan las piezas ----
# ---- inicio incluido: ui/Views/CategoryDetailView.ps1 ----
# ============================================================
# Vista: detalle de una categoría
#
# Misma idea que la lista: solo ensambla. La cabecera la pone
# ui/Components/Layout/PageHeader.ps1 y cada fila la construye
# ui/Components/Cards/SettingCard.ps1.
#
# Sirve para cualquier categoría sin saber nada de ella: recorre
# su array Items y ya está.
#
# Si la sección está bloqueada en ui/Index/CategoryIndex.ps1, se pinta
# igual pero con un aviso arriba y los controles deshabilitados.
# ============================================================

# Cuándo se leyó por última vez el registro de cada sección, para
# poder decirlo en la cabecera. Es dato de pantalla: core/ apunta
# la lectura en el log, pero no sabe de relojes ni de cabeceras.
$CategoryReadAt = @{}

# La tarjeta que hay que traer a la vista al entrar desde un
# resultado de búsqueda. Vive fuera de la función porque quien la
# usa corre después, ya en el Dispatcher.
$CategoryHighlightCard = $null

function Show-CategoryDetailView {
    param($Window, $Category, $Highlight)

    $locked = [bool]$Category.Locked
    $keys = Get-CategoryRegistryKeyCount $Category

    # ---- 0. Preguntar al equipo qué hay en el registro ----
    # Se hace ANTES de construir nada, para que las tarjetas ya
    # nazcan con el valor real. Las secciones cuyos ajustes no
    # declaren claves -hoy, todas menos Regedit- no leen nada y no
    # enseñan la barra.
    #
    # Este mismo paso es el que repite el botón de refrescar: no
    # tiene camino propio, vuelve a entrar por aquí.
    if ($keys -gt 0) {
        # Update-UiNow cede el hilo para repintar la barra, y en esa
        # pausa WPF puede entregar clics de la pantalla anterior.
        # Sordo al ratón mientras dura: no se ve, y no hay forma de
        # navegar a otro sitio a mitad de la lectura.
        $Window.Content.IsHitTestVisible = $false
        Show-ProgressStrip $Window 'Reading the registry...'
        try {
            Update-CategoryRegistryState -Category $Category -OnProgress {
                param($Done, $Total)
                Set-ProgressStrip (Get-AppWindow) $Done $Total
            } | Out-Null
            $script:CategoryReadAt[[string]$Category.Id] = Get-Date

            # Acaban de aparecer Current y Status donde antes no había
            # nada, y el buscador indexa los dos. El índice guardado se
            # ha quedado viejo: se tira y se rehará al siguiente
            # tecleo. Se avisa desde aquí y no desde core/, que no sabe
            # -ni debe saber- que existe un buscador.
            Reset-SearchIndex
        }
        finally {
            Hide-ProgressStrip $Window
            $Window.Content.IsHitTestVisible = $true
        }
    }

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageBreadcrumb -Window $Window -Category $Category

    Add-PageActionLabel $Window ((T '{0} settings') -f $Category.Items.Count)

    # La hora de la última lectura: es lo que dice si lo que hay en
    # pantalla es de ahora mismo o de hace un rato.
    $readAt = $script:CategoryReadAt[[string]$Category.Id]
    if ($readAt) {
        $stamp = (T 'Updated {0}') -f $readAt.ToString('HH:mm:ss')
        Add-PageActionLabel $Window $stamp
    }

    Add-PageAction $Window (New-RefreshButton -Window $Window -Keys $keys)

    # El mismo menú que la pantalla principal: sus opciones son
    # globales y se guardan, así que da igual desde dónde se toquen.
    Add-PageAction $Window (New-ViewMenu $Window)

    # Fila centrada con el recuento por etiqueta.
    Set-PageSummary -Window $Window -Category $Category

    # ---- 2. Cuerpo ----
    $list = New-Object System.Windows.Controls.StackPanel

    if ($locked) { $list.Children.Add((New-LockedBanner)) | Out-Null }

    # $Highlight llega desde un resultado de búsqueda: es el ajuste
    # que hay que enseñar. Se compara por nombre y no por referencia
    # porque el ajuste puede venir del índice del buscador, que no
    # tiene por qué ser el mismo objeto.
    $buscado = ''
    if ($Highlight) { $buscado = [string]$Highlight.Name }

    $script:CategoryHighlightCard = $null

    foreach ($setting in $Category.Items) {
        $marcar = ($buscado -ne '' -and [string]$setting.Name -eq $buscado)
        $card = New-SettingCard -Window $Window -Setting $setting -Locked:$locked -Highlight:$marcar
        if ($marcar) { $script:CategoryHighlightCard = $card }
        $list.Children.Add($card) | Out-Null
    }

    # ---- 3. Pintar con transición de entrada ----
    $Window.FindName('MainContent').Content = $list
    Start-EnterTransition $list

    Show-HighlightedSetting $Window
}

<#
    Lleva a la vista el ajuste marcado, si lo hay.

    Se aplaza por dos motivos, y hacen falta los dos:

      - El contenido todavía no está medido; con alto 0 no hay
        adónde desplazarse.
      - Show-View manda el scroll arriba DESPUÉS de que esta vista
        termine, así que hacerlo aquí mismo no serviría de nada.
#>
function Show-HighlightedSetting {
    param($Window)

    if (-not $script:CategoryHighlightCard) { return }

    $Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Loaded,
        [action]{
            $card = $script:CategoryHighlightCard
            $script:CategoryHighlightCard = $null
            if ($card) { $card.BringIntoView() }
        }) | Out-Null
}

<#
    El botón de refrescar de la cabecera.

    Leer no es tocar nada, así que sigue disponible en las
    secciones bloqueadas: ahí lo único que no se puede es cambiar
    valores. Lo que sí lo apaga es que la sección no declare
    ninguna clave, porque entonces no hay nada que volver a leer.

    Se registra con nombre para que $Window.FindName('BtnRefresh')
    lo encuentre -lo usan las pruebas-, y como la cabecera se
    rehace en cada pintada hay que soltar el nombre anterior.
#>
function New-RefreshButton {
    param($Window, [int]$Keys)

    $refresh = New-ChipButton $Window 'Refresh' 'Sync'

    if ($Keys -gt 0) {
        $refresh.ToolTip = T 'Read the registry keys again'
        $refresh.Add_Click({ param($s, $e) Invoke-CategoryRefresh })
    }
    else {
        $refresh.IsEnabled = $false
        $refresh.Opacity = 0.45
        $refresh.ToolTip = T 'This section does not read the registry yet'
    }

    try { $Window.UnregisterName('BtnRefresh') } catch { }
    $Window.RegisterName('BtnRefresh', $refresh)

    $refresh
}

<#
    Refrescar = volver a entrar en la sección.

    No repite la lectura: repinta la pantalla actual, y al
    repintarse la vista pasa otra vez por su paso 0 con la misma
    barra de progreso. Así no hay dos caminos que puedan acabar
    haciendo cosas distintas.

    Se aplaza al Dispatcher por el mismo motivo que
    Update-UiLanguage: el clic sale de un botón que vive en la
    cabecera que estamos a punto de vaciar, y conviene dejar que
    el evento termine antes. El aviso va después del repintado
    porque Clear-PageHeader se lo llevaría por delante.
#>
function Invoke-CategoryRefresh {
    $window = Get-AppWindow
    if (-not $window) { return }

    $window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{
            Show-CurrentView
            Show-PageToast -Window (Get-AppWindow) -Text 'Registry values updated'
        }) | Out-Null
}

# ---- fin incluido: ui/Views/CategoryDetailView.ps1 ----
# ---- inicio incluido: ui/Views/OptimizationsListView.ps1 ----
# ============================================================
# Vista: lista de optimizaciones (pantalla principal)
#
# Una vista solo ENSAMBLA, no dibuja: pide la cabecera a
# ui/Components/Layout/PageHeader.ps1 y una tarjeta por categoría a
# ui/Components/Cards/CategoryCard.ps1.
#
# Las categorías salen del registro, así que esta pantalla se
# adapta sola a las que haya en ui/Data/Categories/.
# ============================================================

function Show-OptimizationsListView {
    param($Window)

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Optimizations') `
        -Subtitle (T 'Optimize your Windows system performance, privacy and power usage')

    # La barra de búsqueda, no la caja pelada: trae el desplegable de
    # resultados y el Enter que lleva a la página completa.
    Add-PageAction $Window (New-SearchBar -Window $Window)
    Add-PageAction $Window (New-ChipButton $Window 'Quick Actions' 'Bolt' -Chevron)
    Add-PageAction $Window (New-ViewMenu $Window)

    # ---- 2. Cuerpo: una tarjeta por categoría ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($category in Get-OptimizationCategories) {
        $list.Children.Add((New-CategoryCard -Window $Window -Category $category)) | Out-Null
    }

    # ---- 3. Pintar con transición de entrada ----
    $Window.FindName('MainContent').Content = $list
    Start-EnterTransition $list
}

# ---- fin incluido: ui/Views/OptimizationsListView.ps1 ----
# ---- inicio incluido: ui/Views/SearchResultsView.ps1 ----
# ============================================================
# Vista: resultados de la búsqueda
#
# Se llega desde la caja de la cabecera: Enter, o la fila "ver
# todos" del desplegable. Enseña TODO lo que encaja, agrupado por
# sección, mientras que el desplegable solo enseña las primeras
# filas.
#
# La cabecera y el cuerpo se pintan por caminos distintos, y es lo
# único que tiene de particular esta pantalla:
#
#   Show-SearchResultsView   entra: rehace cabecera Y cuerpo
#   Update-SearchResults     escribes: rehace SOLO el cuerpo
#
# El motivo es el foco. Rehacer la cabecera destruye la caja de
# texto en la que se está escribiendo, y con ella el cursor y el
# foco; a cada tecla habría que volver a crearla, devolverle el
# texto y colocar el cursor al final. Dejándola en pie no hay nada
# que restaurar. Por eso el recuento -"12 resultados"- va en el
# cuerpo y no en el subtítulo: el número cambia con cada tecla.
#
# Quien llama a Update-SearchResults es el antirrebote de
# ui/Components/Shell/SearchBar.ps1, y solo cuando esta es la
# pantalla actual: así la página y el desplegable nunca dicen
# cosas distintas.
# ============================================================

function Show-SearchResultsView {
    param($Window)

    $query = Get-SearchQuery

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Search') `
        -Subtitle (T 'Everything in the app, by name, description or registry key')

    # -Focus para poder seguir escribiendo nada más llegar: se entra
    # aquí desde el teclado, y sería raro tener que volver a pulsar
    # en la caja para corregir una letra.
    Add-PageAction $Window (New-SearchBar -Window $Window -Text $query -Focus)
    Add-PageAction $Window (New-ViewMenu $Window)

    # ---- 2. Cuerpo ----
    $body = New-SearchResultsBody -Window $Window -Query $query
    $Window.FindName('MainContent').Content = $body

    # ---- 3. Pintar con transición de entrada ----
    Start-EnterTransition $body
}

<#
    Vuelve a pintar solo la lista, sin tocar la cabecera.

    Sin transición de entrada a propósito: escribiendo, un
    desvanecido por tecla parpadea.
#>
function Update-SearchResults {
    param($Window)

    if (-not $Window) { return }
    $area = $Window.FindName('MainContent')
    if (-not $area) { return }

    $area.Content = New-SearchResultsBody -Window $Window -Query (Get-SearchQuery)
}

# El cuerpo: el recuento, y luego un grupo por sección con sus
# tarjetas. Toda la lógica -buscar y agrupar- vive en
# ui/Engine/Search.ps1; aquí solo se recorre lo que devuelve.
function New-SearchResultsBody {
    param($Window, [string]$Query)

    $list = New-Object System.Windows.Controls.StackPanel

    if ([string]::IsNullOrWhiteSpace($Query)) {
        $list.Children.Add((New-SearchPromptState -Window $Window)) | Out-Null
        return $list
    }

    $results = @(Get-SearchResults $Query)

    if ($results.Count -eq 0) {
        $list.Children.Add((New-SearchEmptyState -Window $Window -Query $Query)) | Out-Null
        return $list
    }

    $list.Children.Add((New-SearchCountLine -Window $Window -Count $results.Count -Query $Query)) | Out-Null

    foreach ($group in (Group-SearchResults $results)) {
        $list.Children.Add((New-SearchGroupHeader $Window $group.Category $group.Entries.Count)) | Out-Null
        foreach ($entry in $group.Entries.ToArray()) {
            $list.Children.Add((New-SearchResultCard $Window $entry)) | Out-Null
        }
    }

    $list
}

# ---- fin incluido: ui/Views/SearchResultsView.ps1 ----
# ---- inicio incluido: ui/Views/SettingsView.ps1 ----
# ============================================================
# Vista: Settings
#
# Se dibuja sola a partir de lo que haya registrado en
# ui/Data/Preferences/: recorre los grupos y, dentro de cada uno,
# sus opciones. Añadir una opción nueva NO requiere tocar este
# archivo.
# ============================================================

function Show-SettingsView {
    param($Window)

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Settings') `
        -Subtitle (T 'Preferences for the application itself')

    Add-PageActionLabel $Window (T 'Saved automatically')

    # ---- 2. Cuerpo: un bloque por grupo ----
    $list = New-Object System.Windows.Controls.StackPanel

    foreach ($group in Get-PreferenceGroups) {
        $list.Children.Add((New-SectionHeader $Window (T $group))) | Out-Null

        foreach ($preference in Get-Preferences) {
            if ($preference.Group -ne $group) { continue }
            $list.Children.Add((New-PreferenceCard -Window $Window -Preference $preference)) | Out-Null
        }
    }

    # ---- 3. Pintar con transición de entrada ----
    $Window.FindName('MainContent').Content = $list
    Start-EnterTransition $list
}

# ---- fin incluido: ui/Views/SettingsView.ps1 ----

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
        <FontFamily x:Key="MonoFont">Cascadia Mono, Consolas, Courier New</FontFamily>

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
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- ===== BARRA DE TITULO ===== -->
            <Grid x:Name="TitleBar" Grid.Row="0" Background="{DynamicResource Bg1}">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- menú + marca -->
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="8,0,0,0">
                    <Button x:Name="BtnMenu" Style="{StaticResource GlyphButtonStyle}"
                            Content="&#xE700;" FontSize="15" ToolTip="Hide the menu"
                            Margin="0,0,8,0"/>
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
                    <Button x:Name="BtnLog"   Style="{StaticResource GlyphButtonStyle}" Content="&#xE9D9;" ToolTip="Activity log"/>
                    <Button x:Name="BtnTheme" Style="{StaticResource GlyphButtonStyle}" Content="&#xE708;" ToolTip="Change theme"/>
                    <Button x:Name="BtnHelp"  Style="{StaticResource GlyphButtonStyle}" Content="&#xE897;" ToolTip="Help"/>
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
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel x:Name="HeaderTitleArea" Grid.Row="0" Grid.Column="0" VerticalAlignment="Center" Orientation="Horizontal"/>
                    <StackPanel x:Name="HeaderActionsArea" Grid.Row="0" Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"/>
                    <!-- Resumen centrado bajo el titulo. Vacio salvo en el
                         detalle de una seccion; lo llena Set-PageSummary. -->
                    <StackPanel x:Name="HeaderSummaryArea" Grid.Row="1" Grid.ColumnSpan="2"
                                Orientation="Horizontal" HorizontalAlignment="Center"/>
                </Grid>
            </Border>

            <!-- ===== CUERPO: navegacion + contenido ===== -->
            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions>
                    <!-- Auto: la columna sigue al ancho del Border, que es lo
                         que se anima al plegar (ver ui/Components/Shell/Sidebar.ps1) -->
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- NAVEGACION LATERAL
                     Solo el contenedor: los botones los construye
                     ui/Components/Shell/Sidebar.ps1 a partir de ui/Index/NavigationIndex.ps1 -->
                <Border x:Name="Sidebar" Grid.Column="0" Width="88" MinWidth="0"
                        ClipToBounds="True"
                        Background="{DynamicResource Bg1}"
                        BorderBrush="{DynamicResource Stroke}" BorderThickness="0,1,1,0"
                        CornerRadius="0,16,0,0">
                    <Grid Width="88" HorizontalAlignment="Left">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel x:Name="NavTop" Grid.Row="0" Margin="0,14,0,0"/>

                        <StackPanel Grid.Row="1" Margin="0,0,0,16">
                            <Border Height="1" Background="{DynamicResource Stroke}" Margin="18,0,18,10"/>
                            <StackPanel x:Name="NavBottom"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- CONTENIDO PRINCIPAL -->
                <!-- Con nombre porque ui/Engine/Router.ps1 guarda y restaura su
                     posicion al repintar la misma pantalla. -->
                <ScrollViewer x:Name="MainScroll" Grid.Column="1" VerticalScrollBarVisibility="Auto" Padding="30,2,22,26">
                    <ContentControl x:Name="MainContent"/>
                </ScrollViewer>
            </Grid>

            <!-- ===== BARRA DE PROGRESO =====
                 Solo el contenedor; lo mueve ui/Components/Shell/ProgressStrip.ps1.
                 Colapsada no ocupa alto, asi que la fila Auto desaparece y
                 el contenido no se mueve al aparecer y desaparecer. -->
            <Border x:Name="ProgressStrip" Grid.Row="3" Visibility="Collapsed"
                    Background="{DynamicResource Bg1}"
                    BorderBrush="{DynamicResource Stroke}" BorderThickness="0,1,0,0">
                <StackPanel Margin="30,9,30,10">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="ProgressText" Grid.Column="0" FontSize="11.5"
                                   Foreground="{DynamicResource TextMuted}"/>
                        <TextBlock x:Name="ProgressCount" Grid.Column="1" FontSize="11.5" FontWeight="SemiBold"
                                   Foreground="{DynamicResource TextFaint}"/>
                    </Grid>

                    <!-- El relleno se mide con anchos estrella, no en pixeles:
                         asi no hace falta saber el ancho real de la ventana. -->
                    <Border Height="4" CornerRadius="2" Margin="0,7,0,0"
                            Background="{DynamicResource SurfaceSunken}">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition x:Name="ProgressDone" Width="0*"/>
                                <ColumnDefinition x:Name="ProgressLeft" Width="1*"/>
                            </Grid.ColumnDefinitions>
                            <Border Grid.Column="0" CornerRadius="2" Background="{DynamicResource Accent}"/>
                        </Grid>
                    </Border>
                </StackPanel>
            </Border>

            <!-- ===== REGISTRO DE ACTIVIDAD (LOG) =====
                 Solo la carcasa: todo lo de dentro lo construye
                 ui/Components/Shell/LogPanel.ps1, que es quien sabe que hay
                 un log y como se pinta.

                 Va DESPUES que todo lo demas y con RowSpan hasta el
                 final para quedar por encima: en un Grid manda el orden
                 del documento. Cubre de la fila 1 hacia abajo, asi que
                 la barra de titulo sigue viva y su boton puede cerrarlo.

                 Colapsado no existe para el raton, de modo que con el
                 cajon cerrado no hay nada estorbando delante. -->
            <Grid x:Name="LogOverlay" Grid.Row="1" Grid.RowSpan="3" Visibility="Collapsed">
                <!-- El velo que oscurece lo de detras. Tambien se come
                     los clics: con el cajon abierto no se navega. -->
                <Border x:Name="LogScrim" Background="{DynamicResource Overlay}" Opacity="0"/>
                <Border x:Name="LogDrawer" Width="660" HorizontalAlignment="Right"
                        Background="{DynamicResource Bg1}"
                        BorderBrush="{DynamicResource Stroke}" BorderThickness="1,0,0,0"/>
            </Grid>
        </Grid>
    </Border>
</Window>

'@
[xml]$xamlXml = $xamlString

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
}

# ---- Menú lateral ----
# Los botones se construyen a partir de ui/Index/NavigationIndex.ps1;
# la selección y el plegado los gestiona ui/Components/Shell/Sidebar.ps1.
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
