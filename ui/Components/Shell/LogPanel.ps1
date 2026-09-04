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

function Switch-LogPanel {
    param($Window)
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

# Rehace el cajón entero. Se llama al abrirlo y al cambiar de
# idioma; para refrescar solo las filas está Update-LogList.
function Update-LogPanel {
    param($Window)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-LogRowDef 'Auto')) | Out-Null
    $grid.RowDefinitions.Add((New-LogRowDef 'Auto')) | Out-Null
    $grid.RowDefinitions.Add((New-LogRowDef '*'))    | Out-Null
    $grid.RowDefinitions.Add((New-LogRowDef 'Auto')) | Out-Null

    Add-ToLogRow $grid (New-LogHeader  $Window) 0
    Add-ToLogRow $grid (New-LogToolbar $Window) 1
    Add-ToLogRow $grid (New-LogScroll  $Window) 2
    Add-ToLogRow $grid (New-LogFooter  $Window) 3

    $Window.FindName('LogDrawer').Child = $grid
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

# --- fila 0: título y botón de cerrar ---
function New-LogHeader {
    param($Window)

    $box = New-Object System.Windows.Controls.Border
    $box.Padding = New-Object System.Windows.Thickness 18, 15, 10, 15
    $box.BorderThickness = New-Object System.Windows.Thickness 0, 0, 0, 1
    Set-BoxLine $box 'Stroke'

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

    $close = New-Object System.Windows.Controls.Button
    $close.Style = $Window.FindResource('GlyphButtonStyle')
    $close.Content = Glyph 'Close'
    $close.FontSize = 12
    $close.VerticalAlignment = 'Top'
    $close.ToolTip = T 'Close the log'
    $close.Add_Click({
        param($s, $e)
        Hide-LogPanel ([System.Windows.Window]::GetWindow($s))
    })
    Add-ToColumn $grid $close 2

    $box.Child = $grid
    $box
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
            $scroll = (Get-AppWindow).FindName('LogScroll')
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
