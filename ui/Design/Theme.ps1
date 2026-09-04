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
    Dock = 0xE73F
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
