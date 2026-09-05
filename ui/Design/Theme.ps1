# ============================================================
# Theme.ps1
# Sistema de diseño: paletas claro/oscuro, degradados, iconos
# Fluent, tipografía y helpers de animación.
# Solo apariencia, ninguna lógica de negocio.
#
# Los glifos se referencian por codepoint (no como carácter
# literal) para que el archivo no dependa de la codificación.
#
# HAY DOS FAMILIAS DE COLOR y se declaran por separado:
#
#   Get-Palette      colores planos -> un SolidColorBrush por clave.
#   $GradientTokens  degradados     -> se COMPONEN a partir de dos
#                    claves de la paleta, así que no hay ni un color
#                    escrito dos veces y el degradado cambia solo al
#                    alternar claro/oscuro.
#
# Las dos se publican en Window.Resources, así que el XAML las
# consume con {DynamicResource <clave>} y el código con
# SetResourceReference sin distinguir cuál es cuál.
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
# Cada clave se publica como SolidColorBrush en Window.Resources.
#
# Las claves terminadas en 2 son el SEGUNDO tono de cada color: casi
# nunca se usan sueltas, están para que $GradientTokens pueda
# componer el degradado. Glow1..3 llevan el alfa incluido
# (#AARRGGBB) porque son las manchas del fondo, que son
# translúcidas por definición.
function Get-Palette {
    param([string]$Name)

    if ($Name -eq 'Dark') {
        @{
            Bg0 = '#12141A'; Bg1 = '#181B22'; Bg2 = '#1E222A'; BgTint = '#0D1016'
            Surface = '#1E222A'; SurfaceHover = '#252A34'; SurfaceSunken = '#15181E'
            CardTop = '#272C36'; CardBottom = '#1C2028'
            CardHoverTop = '#2F3540'; CardHoverBottom = '#22272F'
            Stroke = '#2C323D'; StrokeHover = '#3D4552'; StrokeFocus = '#4D8DFF'
            Text = '#EDEFF3'; TextMuted = '#A3ABB9'; TextFaint = '#6E7787'
            Accent = '#4D8DFF'; AccentHover = '#6EA4FF'; AccentSoft = '#1B2C4A'; AccentText = '#FFFFFF'
            Accent2 = '#A78BFA'; Accent2Soft = '#2A2350'
            Success = '#3DD68C'; SuccessSoft = '#122A20'
            Success2 = '#2DD4BF'; Success2Soft = '#0F2A2A'
            Warn = '#F0B429'; WarnSoft = '#2E2412'
            Warn2 = '#FB923C'; Warn2Soft = '#2E1F12'
            Danger = '#FF6B81'; DangerSoft = '#331821'
            Danger2 = '#F472B6'; Danger2Soft = '#2E1826'
            Glow1 = '#4D4D8DFF'; Glow2 = '#42A78BFA'; Glow3 = '#332DD4BF'
            BgGlass = '#B316191F'; BgGlassTint = '#B30D1016'; SurfaceGlass = '#C2181B22'
            TrackOff = '#3D4552'; Knob = '#FFFFFF'
            ScrollThumb = '#3D4552'; Overlay = '#000000'
        }
    }
    else {
        @{
            Bg0 = '#F2F4F7'; Bg1 = '#FFFFFF'; Bg2 = '#F7F9FC'; BgTint = '#E8EDF6'
            Surface = '#FFFFFF'; SurfaceHover = '#FAFBFD'; SurfaceSunken = '#F0F2F6'
            CardTop = '#FFFFFF'; CardBottom = '#F6F9FD'
            CardHoverTop = '#FFFFFF'; CardHoverBottom = '#EDF3FC'
            Stroke = '#E6E9EF'; StrokeHover = '#CFD6E2'; StrokeFocus = '#2563EB'
            Text = '#15181E'; TextMuted = '#59616F'; TextFaint = '#8B93A2'
            Accent = '#2563EB'; AccentHover = '#1D4FD8'; AccentSoft = '#E9F0FE'; AccentText = '#FFFFFF'
            Accent2 = '#7C3AED'; Accent2Soft = '#F0E9FE'
            Success = '#0E9F6E'; SuccessSoft = '#E6F7F0'
            Success2 = '#0891B2'; Success2Soft = '#E3F4F9'
            Warn = '#C2680A'; WarnSoft = '#FDF3E5'
            Warn2 = '#DFA008'; Warn2Soft = '#FBF7DF'
            Danger = '#E11D48'; DangerSoft = '#FDEAEF'
            Danger2 = '#BE185D'; Danger2Soft = '#FCE7F0'
            Glow1 = '#2E2563EB'; Glow2 = '#287C3AED'; Glow3 = '#1F0E9F6E'
            BgGlass = '#BFF6F8FC'; BgGlassTint = '#BFE8EDF6'; SurfaceGlass = '#CCFFFFFF'
            TrackOff = '#CBD2DE'; Knob = '#FFFFFF'
            ScrollThumb = '#C6CDDA'; Overlay = '#0B1220'
        }
    }
}

<#
    Los degradados del tema.

    Cada uno se COMPONE a partir de dos claves de la paleta, nunca
    de colores propios: así el degradado no puede desafinar con el
    color plano del que sale, y alternar claro/oscuro lo repinta sin
    que haya que declarar nada dos veces.

        Kind   'Linear' -> de un punto a otro, en coordenadas 0..1
                           del propio elemento.
               'Radial' -> del centro hacia fuera, del color a ese
                           mismo color transparente. Son las manchas
                           del fondo.

    El nombre es la clave con la que se pide: {DynamicResource
    AccentGradient}. La convención '<Color>Gradient' la aprovecha
    Get-GradientKey para sacar el degradado de una categoría a
    partir de su clave de acento, sin saber qué categorías hay.
#>
$GradientTokens = [ordered]@{

    # Fondo de la ventana: el plano de siempre, con una caída fría.
    'BgGradient'          = @{ Kind = 'Linear'; From = 'Bg0';   To = 'BgTint'; Start = '0,0'; End = '0.35,1' }

    # El mismo fondo, translúcido. Solo se usa con Mica o Acrílico
    # puestos: si la ventana fuera opaca no se vería el material del
    # sistema (ver ui/Components/Shell/WindowMaterial.ps1).
    'BgGlassGradient'     = @{ Kind = 'Linear'; From = 'BgGlass'; To = 'BgGlassTint'; Start = '0,0'; End = '0.35,1' }

    # Tarjetas: luz arriba, sombra abajo. Es el "vidrio" de las
    # interfaces modernas, y en claro es casi imperceptible a
    # propósito: un degradado que se nota es un degradado que cansa.
    'CardGradient'        = @{ Kind = 'Linear'; From = 'CardTop';      To = 'CardBottom';      Start = '0,0'; End = '0,1' }
    'CardHoverGradient'   = @{ Kind = 'Linear'; From = 'CardHoverTop'; To = 'CardHoverBottom'; Start = '0,0'; End = '0,1' }

    # Acentos: el color de siempre y su segundo tono, en diagonal.
    'AccentGradient'      = @{ Kind = 'Linear'; From = 'Accent';      To = 'Accent2';      Start = '0,0'; End = '1,1' }
    'AccentSoftGradient'  = @{ Kind = 'Linear'; From = 'AccentSoft';  To = 'Accent2Soft';  Start = '0,0'; End = '1,1' }
    'SuccessGradient'     = @{ Kind = 'Linear'; From = 'Success';     To = 'Success2';     Start = '0,0'; End = '1,1' }
    'SuccessSoftGradient' = @{ Kind = 'Linear'; From = 'SuccessSoft'; To = 'Success2Soft'; Start = '0,0'; End = '1,1' }
    'WarnGradient'        = @{ Kind = 'Linear'; From = 'Warn';        To = 'Warn2';        Start = '0,0'; End = '1,1' }
    'WarnSoftGradient'    = @{ Kind = 'Linear'; From = 'WarnSoft';    To = 'Warn2Soft';    Start = '0,0'; End = '1,1' }
    'DangerGradient'      = @{ Kind = 'Linear'; From = 'Danger';      To = 'Danger2';      Start = '0,0'; End = '1,1' }
    'DangerSoftGradient'  = @{ Kind = 'Linear'; From = 'DangerSoft';  To = 'Danger2Soft';  Start = '0,0'; End = '1,1' }

    # Manchas del fondo (ui/Components/Shell/Backdrop.ps1). Radiales
    # para que se desvanezcan solas: así no hace falta un
    # BlurEffect, que sobre superficies grandes es lo caro de verdad.
    'Glow1Brush'          = @{ Kind = 'Radial'; From = 'Glow1' }
    'Glow2Brush'          = @{ Kind = 'Radial'; From = 'Glow2' }
    'Glow3Brush'          = @{ Kind = 'Radial'; From = 'Glow3' }
}

<#
    Todas las claves de color del tema: las planas y los degradados.

    Existe para que tests/Source/Rules.Tests.ps1 pueda comprobar que
    un Set-TextFg / Set-BoxBg pide algo que de verdad está
    publicado, sin tener que saber de qué familia es.
#>
function Get-ThemeKeys {
    @((Get-Palette 'Light').Keys) + @($GradientTokens.Keys)
}

$CurrentTheme = 'Light'

function Set-AppTheme {
    param($Window, [string]$Name)

    $palette = Get-Palette $Name
    foreach ($key in $palette.Keys) {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($palette[$key])
        Set-ThemeBrush $Window $key (New-SolidBrush $color)
    }

    # Los degradados van después: se componen a partir de los
    # colores planos, así que necesitan la paleta ya resuelta.
    foreach ($key in $GradientTokens.Keys) {
        Set-ThemeBrush $Window $key (New-GradientBrush $palette $GradientTokens[$key])
    }

    $script:CurrentTheme = $Name
}

function Get-AppTheme { $script:CurrentTheme }

<#
    Publica un pincel en el tema, mutando el que ya hubiera.

    Se muta en lugar de sustituir porque todos los consumidores
    -XAML y código- comparten la misma instancia: mutar los repinta
    a todos sin reevaluar ningún DynamicResource.

    Solo cuando el pincel está CONGELADO hay que sustituirlo. WPF
    congela al cargar el XAML los que considera compartibles, y un
    Freezable congelado no admite cambios; el de repuesto nace
    descongelado, así que a partir del segundo cambio de tema ya se
    muta como los demás.

    Al sustituir se usa Add() y NO el indexador: el indexador guarda
    el PSObject que envuelve al pincel, y WPF lo rechaza al resolver
    el DynamicResource con "no es un valor válido para Foreground".
#>
function Set-ThemeBrush {
    param($Window, [string]$Key, $Brush)

    $existing = $Window.Resources[$Key]

    if ($existing -is [System.Windows.Media.SolidColorBrush] -and
        $Brush -is [System.Windows.Media.SolidColorBrush] -and
        -not $existing.IsFrozen) {
        $existing.Color = $Brush.Color
        return
    }

    # Un degradado se muta parada a parada. Si el número de paradas
    # no coincide es que ha cambiado la definición del token: se
    # sustituye entero, que es lo único correcto.
    if ($existing -is [System.Windows.Media.GradientBrush] -and
        $Brush -is [System.Windows.Media.GradientBrush] -and
        -not $existing.IsFrozen -and
        $existing.GradientStops.Count -eq $Brush.GradientStops.Count) {
        for ($i = 0; $i -lt $Brush.GradientStops.Count; $i++) {
            $existing.GradientStops[$i].Color = $Brush.GradientStops[$i].Color
        }
        return
    }

    $Window.Resources.Remove($Key)
    $Window.Resources.Add($Key, $Brush)
}

function New-SolidBrush {
    param($Color)
    $brush = New-Object System.Windows.Media.SolidColorBrush
    $brush.Color = $Color
    $brush
}

# Construye el pincel de un token a partir de la paleta ya resuelta.
function New-GradientBrush {
    param($Palette, $Token)

    $from = [System.Windows.Media.ColorConverter]::ConvertFromString($Palette[$Token.From])

    if ($Token.Kind -eq 'Radial') {
        # Se desvanece hacia ESE MISMO color con alfa 0: hacia
        # transparente-negro dejaría un halo sucio en el tema claro.
        $edge = [System.Windows.Media.Color]::FromArgb(0, $from.R, $from.G, $from.B)
        $radial = New-Object System.Windows.Media.RadialGradientBrush
        $radial.GradientStops.Add((New-Object System.Windows.Media.GradientStop $from, 0.0))
        $radial.GradientStops.Add((New-Object System.Windows.Media.GradientStop $edge, 1.0))
        return $radial
    }

    $to = [System.Windows.Media.ColorConverter]::ConvertFromString($Palette[$Token.To])
    $linear = New-Object System.Windows.Media.LinearGradientBrush
    $linear.StartPoint = [System.Windows.Point]::Parse($Token.Start)
    $linear.EndPoint   = [System.Windows.Point]::Parse($Token.End)
    $linear.GradientStops.Add((New-Object System.Windows.Media.GradientStop $from, 0.0))
    $linear.GradientStops.Add((New-Object System.Windows.Media.GradientStop $to,   1.0))
    $linear
}

<#
    El degradado que le toca a una clave de color plana.

        Get-GradientKey 'Warn'      -> 'WarnGradient'
        Get-GradientKey 'WarnSoft'  -> 'WarnSoftGradient'
        Get-GradientKey 'TextMuted' -> 'TextMuted'   (no tiene: se
                                                      devuelve tal cual)

    Sirve para que una pieza pueda pedir "la versión en degradado de
    lo que me han pasado" sin saber qué categorías existen ni qué
    colores tienen. Lo usa New-IconTile.
#>
function Get-GradientKey {
    param([string]$Key)

    $candidate = $Key + 'Gradient'
    if ($GradientTokens.Contains($candidate)) { return $candidate }
    $Key
}

# ---- Helpers de recursos dinámicos --------------------------
# Enlazan una propiedad al recurso del tema, de modo que los
# controles creados por código también reaccionan al cambio.
function Set-TextFg  { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $Key) }
function Set-BoxBg   { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $Key) }
function Set-BoxLine { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $Key) }

# El relleno de una figura (Ellipse, Rectangle) tampoco es la
# Background de un Border: son propiedades distintas. Lo usan las
# manchas del fondo.
function Set-ShapeFill { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, $Key) }

# Y la de un panel (Grid, StackPanel) es una TERCERA. La barra de
# título es un Grid, así que con la de Border no le pasaría nada.
function Set-PanelBg { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Panel]::BackgroundProperty, $Key) }

# La Background de una ventana o de un control con plantilla NO es
# la del Border: son propiedades distintas y con la de Border no
# pasa nada. Lo usa la ventana aparte del registro de actividad.
function Set-WinBg { param($El, [string]$Key) $El.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, $Key) }

function Get-Brush { param($Window, [string]$Key) $Window.FindResource($Key) }

# ---- Animación ----------------------------------------------
<#
    Curva de aceleración.

        New-Ease                  suave y de toda la vida
        New-Ease -Kind 'Back'     se pasa de largo y vuelve
        New-Ease -Kind 'Quint'    arranque y frenada más marcados

    'Back' es lo que le da al interruptor sensación de peso: el knob
    rebasa un pelo su sitio y se asienta.
#>
function New-Ease {
    param([string]$Mode = 'EaseOut', [string]$Kind = 'Cubic', [double]$Amount = 0.5)

    if ($Kind -eq 'Back') {
        $ease = New-Object System.Windows.Media.Animation.BackEase
        $ease.Amplitude = $Amount
    }
    elseif ($Kind -eq 'Quint') {
        $ease = New-Object System.Windows.Media.Animation.QuinticEase
    }
    else {
        $ease = New-Object System.Windows.Media.Animation.CubicEase
    }

    $ease.EasingMode = $Mode
    $ease
}

<#
    Animación de un número (opacidad, ancho, desplazamiento...).

    -Delay retrasa el arranque SIN tocar el valor de partida:
    durante la espera la propiedad se queda en $From. Es lo que
    permite la entrada en cascada, porque cada tarjeta espera su
    turno invisible en vez de aparecer y luego moverse.
#>
function New-Anim {
    param([double]$From, [double]$To, [int]$Ms = 180, [int]$Delay = 0, $Ease)

    $a = New-Object System.Windows.Media.Animation.DoubleAnimation
    $a.From = $From; $a.To = $To
    $a.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms))
    if ($Delay -gt 0) { $a.BeginTime = [TimeSpan]::FromMilliseconds($Delay) }
    if ($Ease) { $a.EasingFunction = $Ease } else { $a.EasingFunction = New-Ease }
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

<#
    Entrada EN CASCADA: cada hijo del panel entra un poco después
    que el anterior.

    Es la diferencia entre "ha aparecido una lista" y "la lista se
    está montando": el ojo sigue el recorrido y la pantalla parece
    responder, aunque tarde exactamente lo mismo.

    El retardo se corta en -MaxSteps para que una sección de treinta
    ajustes no tarde tres segundos en terminar de aparecer; a partir
    de ahí todos entran a la vez.
#>
function Start-StaggeredEnter {
    param($Panel, [int]$Ms = 300, [double]$Slide = 14, [int]$StepMs = 45, [int]$MaxSteps = 9)

    $Panel.Opacity = 1
    $index = 0

    foreach ($child in $Panel.Children) {
        $steps = $index
        if ($steps -gt $MaxSteps) { $steps = $MaxSteps }
        $delay = $steps * $StepMs

        $child.Opacity = 0
        $child.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Anim 0 1 $Ms $delay))

        $target = Get-EnterTarget $child
        if ($target.RenderTransform -isnot [System.Windows.Media.TranslateTransform]) {
            $target.RenderTransform = New-Object System.Windows.Media.TranslateTransform
        }
        $target.RenderTransform.BeginAnimation(
            [System.Windows.Media.TranslateTransform]::YProperty,
            (New-Anim $Slide 0 $Ms $delay))

        $index++
    }
}

<#
    Quién se mueve en la entrada en cascada.

    Si el hijo es el envoltorio quieto de Add-HoverLift, el que se
    desplaza es la tarjeta de DENTRO: el envoltorio no se mueve
    jamás, porque en WPF mover algo mueve también su zona sensible
    al ratón y ahí empieza el bucle de la regla 21. Por eso el
    envoltorio se marca con su Uid al crearlo, en vez de adivinarlo
    mirando la forma del árbol.
#>
function Get-EnterTarget {
    param($Element)

    if ($Element.Uid -eq 'lift' -and $Element.Children.Count -gt 0) {
        return $Element.Children[0]
    }
    $Element
}

<#
    Elevación al pasar el ratón: la tarjeta sube 3px y suelta un
    halo de SU color.

    -Glow es la clave de tema del halo ('Accent', 'Warn'...). El
    color se resuelve al pasar el ratón y no al crear la tarjeta,
    para que alternar claro/oscuro no deje el halo del tema
    anterior; la clave viaja en el Tag de la tarjeta, nada de
    closures (regla 4). Sin -Glow la sombra es la neutra de siempre.

    Quien escucha al ratón NO es la tarjeta, sino un envoltorio
    transparente que ocupa su hueco y no se mueve nunca. En WPF el
    RenderTransform arrastra consigo la zona sensible al ratón: si
    escuchara la propia tarjeta, con el cursor parado sobre sus
    últimos píxeles subirla lo dejaría fuera (MouseLeave), bajarla
    lo volvería a meter dentro (MouseEnter) y el efecto no pararía
    jamás.

    Devuelve el envoltorio: es lo que hay que colgar del panel, y es
    también donde van el cursor y el clic, para que respondan en
    todo el rectángulo de la tarjeta -incluida la franja que deja
    libre al subir-.
#>
function Add-HoverLift {
    param($Border, [string]$Glow)

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 2
    $shadow.BlurRadius = 10; $shadow.Opacity = 0.05
    $Border.Effect = $shadow

    $Border.RenderTransform = New-Object System.Windows.Media.TranslateTransform
    if ($Glow) { $Border.Tag = $Glow }

    # El margen se muda al envoltorio: así su área transparente es
    # exactamente la de la tarjeta y el hueco entre tarjetas sigue
    # siendo hueco, ni se ilumina ni se puede pulsar.
    $slot = New-Object System.Windows.Controls.Grid
    $slot.Background = [System.Windows.Media.Brushes]::Transparent
    $slot.Margin = $Border.Margin
    $Border.Margin = New-Object System.Windows.Thickness 0
    $slot.Children.Add($Border) | Out-Null

    # La marca que reconoce Get-EnterTarget: este envoltorio no se
    # mueve, se mueve su hijo.
    $slot.Uid = 'lift'

    # Nada de closures (regla 4): la tarjeta es el único hijo del
    # envoltorio, así que el manejador la saca del emisor.
    $slot.Add_MouseEnter({
        param($s, $e)
        $card = $s.Children[0]
        Set-GlowColor $card
        $card.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim 0 (-3) 170))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-Anim 0.05 0.30 170))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, (New-Anim 10 26 170))
    })
    $slot.Add_MouseLeave({
        param($s, $e)
        $card = $s.Children[0]
        $card.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim (-3) 0 170))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, (New-Anim 0.30 0.05 170))
        $card.Effect.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, (New-Anim 26 10 170))
    })

    $slot
}

<#
    Tiñe la sombra de una tarjeta con el color que lleva anotado en
    su Tag.

    Sin Tag, sin ventana o con una clave que no sea un color plano
    se queda la sombra negra de siempre: un halo es un adorno y no
    puede tumbar nada.
#>
function Set-GlowColor {
    param($Card)

    $key = [string]$Card.Tag
    if (-not $key -or -not $Card.Effect) { return }

    $window = [System.Windows.Window]::GetWindow($Card)
    if (-not $window) { return }

    $brush = $window.TryFindResource($key)
    if ($brush -is [System.Windows.Media.SolidColorBrush]) {
        $Card.Effect.Color = $brush.Color
    }
}
