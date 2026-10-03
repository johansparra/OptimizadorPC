# ============================================================
# Componente: marco de ejecución de una sección de comandos
#
# Va fijo bajo el título (Set-PageDock), así que se ve siempre,
# aunque la lista de pasos sea larga:
#
#   [icono] Estado ahora mismo              3/12  [ Ejecutar ]
#           el comando que corre
#   ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░   barra de progreso
#   ┌ 12:01:03  correcto  netsh winsock reset ──────────────┐
#   │ ...                                                    │  registro en vivo
#   └────────────────────────────────────────────────────────┘
#
# Y es también quien EJECUTA: lleva la cola, el temporizador, las
# pausas y el estado. Cada paso lo arranca y lo cierra
# core/Network/CommandRunner.ps1, que no sabe nada de esto.
#
# CÓMO NO CONGELAR LA VENTANA
#
#   netsh tarda segundos y el .cmd original esperaba 5 s entre dos
#   pasos. Nada de eso puede pasar en el hilo de la interfaz de un
#   tirón. Un DispatcherTimer late cada 120 ms y en cada latido mira
#   UNA cosa: si el paso en curso ha terminado, si la pausa se ha
#   acabado, o arranca el siguiente. Entre latido y latido la ventana
#   está libre.
#
# EL ESTADO VIVE AQUÍ, NO EN LOS CONTROLES. $StepRun guarda la
# ejecución y Sync-StepRunPanel pinta a partir de él. Así se puede
# cambiar de idioma, salir de la sección y volver en mitad de una
# ejecución: la pantalla se rehace y enseña lo mismo.
#
# Sin bucle de mensajes (las pruebas) el temporizador no late nunca:
# las pruebas llaman a Invoke-StepRunTick a mano.
# ============================================================

$StepRun = @{
    Active     = $false
    Phase      = 'idle'        # idle | running | pausing | done | cancelled
    Category   = $null
    Queue      = @()
    Index      = -1
    Handle     = $null
    PauseUntil = [DateTime]::MinValue
    Succeeded  = 0
    Failed     = 0
    Restart    = $false
    Timer      = $null
    Lines      = (New-Object System.Collections.Generic.List[object])
}

# Las pausas del .cmd ("timeout /t 5"). Las pruebas las apagan para
# no esperar de verdad.
$StepRunPauses = $true

function Set-StepRunPauses { param([bool]$On) $script:StepRunPauses = $On }

# Tope de líneas del registro en vivo. El log de la aplicación las
# guarda todas; este marco enseña lo último.
$StepRunMaxLines = 200

function Get-StepRunActive { [bool]$StepRun.Active }
function Get-StepRunState  { $StepRun }

# Registrar con nombre una pieza del marco. La cabecera se rehace en
# cada pintada, así que hay que soltar el nombre anterior.
function Register-StepRunName {
    param($Window, [string]$Name, $Element)
    try { $Window.UnregisterName($Name) } catch { $null = $_ }
    $Window.RegisterName($Name, $Element)
}

function New-StepRunPanel {
    param($Window, $Category)

    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.BorderThickness = New-Object System.Windows.Thickness 1
    $card.Padding = New-Object System.Windows.Thickness 16, 13, 16, 14
    $card.Margin = New-Object System.Windows.Thickness 0, 0, 0, 10
    Set-BoxBg   $card 'Surface'
    Set-BoxLine $card 'Stroke'
    $card.Tag = $Category
    Register-StepRunName $Window 'StepRunPanel' $card

    $stack = New-Object System.Windows.Controls.StackPanel

    # ---- fila de estado ----
    $top = New-Object System.Windows.Controls.Grid
    Add-GridColumns $top 'Auto', '*', 'Auto', 'Auto'

    $icon = New-Icon 'Play' 18 'Accent'
    $icon.Margin = New-Object System.Windows.Thickness 2, 0, 14, 0
    Register-StepRunName $Window 'StepRunIcon' $icon
    Add-ToColumn $top $icon 0

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $title = New-Object System.Windows.Controls.TextBlock
    $title.FontSize = 13.5
    $title.FontWeight = 'SemiBold'
    $title.TextTrimming = 'CharacterEllipsis'
    Set-TextFg $title 'Text'
    Register-StepRunName $Window 'StepRunTitle' $title
    $texts.Children.Add($title) | Out-Null

    $detail = New-Object System.Windows.Controls.TextBlock
    $detail.FontSize = 11.5
    $detail.TextTrimming = 'CharacterEllipsis'
    $detail.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
    Set-TextFg $detail 'TextMuted'
    Register-StepRunName $Window 'StepRunDetail' $detail
    $texts.Children.Add($detail) | Out-Null

    # Sin permisos de administrador casi todo falla: mejor decirlo
    # antes de pulsar. El .exe siempre corre elevado; esto se ve al
    # lanzar main.ps1 a mano.
    if (-not (Test-AppElevated)) {
        $blocked = @(@($Category.Steps) | Where-Object { -not (Test-StepAvailable $_) }).Count
        $warn = New-Object System.Windows.Controls.TextBlock
        $warn.Text = (T 'Not running as administrator: {0} commands are disabled. Open the program as administrator to use them.') -f $blocked
        $warn.TextWrapping = 'Wrap'
        $warn.FontSize = 11.5
        $warn.Margin = New-Object System.Windows.Thickness 0, 3, 0, 0
        Set-TextFg $warn 'Warn'
        $texts.Children.Add($warn) | Out-Null
    }
    Add-ToColumn $top $texts 1

    $count = New-Object System.Windows.Controls.TextBlock
    $count.FontSize = 12
    $count.FontWeight = 'SemiBold'
    $count.VerticalAlignment = 'Center'
    $count.Margin = New-Object System.Windows.Thickness 12, 0, 14, 0
    Set-TextFg $count 'TextFaint'
    Register-StepRunName $Window 'StepRunCount' $count
    Add-ToColumn $top $count 2

    Add-ToColumn $top (New-StepRunButton $Window) 3
    $stack.Children.Add($top) | Out-Null

    # ---- barra de progreso ----
    # Dos columnas estrella que se reparten el ancho, como la barra del
    # pie (ProgressStrip): no hace falta medir nada.
    $track = New-Object System.Windows.Controls.Border
    $track.Height = 6
    $track.CornerRadius = New-Object System.Windows.CornerRadius 3
    $track.Margin = New-Object System.Windows.Thickness 0, 12, 0, 0
    Set-BoxBg $track 'SurfaceSunken'

    $bar = New-Object System.Windows.Controls.Grid
    $doneCol = New-Object System.Windows.Controls.ColumnDefinition
    $doneCol.Width = [System.Windows.GridLength]::new(0, 'Star')
    $leftCol = New-Object System.Windows.Controls.ColumnDefinition
    $leftCol.Width = [System.Windows.GridLength]::new(1, 'Star')
    $bar.ColumnDefinitions.Add($doneCol)
    $bar.ColumnDefinitions.Add($leftCol)
    Register-StepRunName $Window 'StepRunDoneCol' $doneCol
    Register-StepRunName $Window 'StepRunLeftCol' $leftCol

    $fill = New-Object System.Windows.Controls.Border
    $fill.CornerRadius = New-Object System.Windows.CornerRadius 3
    Set-BoxBg $fill 'AccentGradient'
    Register-StepRunName $Window 'StepRunFill' $fill
    Add-ToColumn $bar $fill 0
    $track.Child = $bar
    $stack.Children.Add($track) | Out-Null

    # ---- registro en vivo ----
    $logBox = New-Object System.Windows.Controls.Border
    $logBox.CornerRadius = New-Object System.Windows.CornerRadius 8
    $logBox.Margin = New-Object System.Windows.Thickness 0, 12, 0, 0
    $logBox.Padding = New-Object System.Windows.Thickness 10, 7, 4, 7
    $logBox.Height = 118
    Set-BoxBg $logBox 'SurfaceSunken'

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    Register-StepRunName $Window 'StepRunScroll' $scroll

    $lines = New-Object System.Windows.Controls.StackPanel
    Register-StepRunName $Window 'StepRunLines' $lines
    $scroll.Content = $lines
    $logBox.Child = $scroll
    $stack.Children.Add($logBox) | Out-Null

    $card.Child = $stack
    $card
}

# El botón grande: "Ejecutar N" o "Detener". Es UNO y cambia, para
# que no haya dos botones que se puedan pulsar a destiempo.
function New-StepRunButton {
    param($Window)

    $btn = New-Object System.Windows.Controls.Border
    $btn.CornerRadius = New-Object System.Windows.CornerRadius 9
    $btn.Padding = New-Object System.Windows.Thickness 15, 8, 17, 9
    $btn.VerticalAlignment = 'Center'
    $btn.Cursor = 'Hand'
    Set-BoxBg $btn 'AccentGradient'

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.FontFamily = $IconFont
    $icon.FontSize = 12
    $icon.VerticalAlignment = 'Center'
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 8, 0
    $icon.Foreground = [System.Windows.Media.Brushes]::White
    $sp.Children.Add($icon) | Out-Null

    $text = New-Object System.Windows.Controls.TextBlock
    $text.FontSize = 12.5
    $text.FontWeight = 'SemiBold'
    $text.VerticalAlignment = 'Center'
    $text.Foreground = [System.Windows.Media.Brushes]::White
    $sp.Children.Add($text) | Out-Null

    $btn.Child = $sp
    $btn.Tag = [PSCustomObject]@{ Icon = $icon; Text = $text }
    Register-StepRunName $Window 'StepRunButton' $btn

    $btn.Add_MouseEnter({ param($s, $e) if ($s.IsEnabled) { $s.Opacity = 0.88 } })
    $btn.Add_MouseLeave({ param($s, $e) if ($s.IsEnabled) { $s.Opacity = 1 } })
    $btn.Add_MouseLeftButtonUp({ param($s, $e) Invoke-StepRunButton })
    $btn
}

# El clic del botón: correr si está parado, detener si corre.
function Invoke-StepRunButton {
    if (Get-StepRunActive) { Stop-StepRun; return }

    $window = Get-AppWindow
    if (-not $window) { return }
    $panel = $window.FindName('StepRunPanel')
    if (-not $panel -or -not $panel.Tag) { return }
    Start-StepRun -Category $panel.Tag
}

# ---- la ejecución -------------------------------------------------

<#
    Arranca la ejecución de los pasos MARCADOS de una sección, en el
    orden del archivo. Devuelve $false si no hay nada que correr o ya
    hay una ejecución en marcha.
#>
function Start-StepRun {
    param($Category)

    if ($StepRun.Active) { return $false }
    if (-not $Category -or $Category.Locked) { return $false }

    $all = @($Category.Steps)
    # La selección EFECTIVA: sin permisos, lo que pide administrador
    # no entra en la cola aunque estuviera elegido.
    $queue = @($all | Where-Object { Test-StepSelected $_ })
    if ($queue.Count -eq 0) { return $false }

    foreach ($s in $all) { $s.Status = $null }
    foreach ($s in $queue) { $s.Status = 'pending' }

    $StepRun.Active = $true
    $StepRun.Phase = 'running'
    $StepRun.Category = $Category
    $StepRun.Queue = $queue
    $StepRun.Index = -1
    $StepRun.Handle = $null
    $StepRun.Succeeded = 0
    $StepRun.Failed = 0
    $StepRun.Restart = $false
    $StepRun.Lines.Clear()

    $msg = 'Run started: {0} of {1} commands ({2})' -f $queue.Count, $all.Count, $Category.Id
    Write-AppLog -Source 'network' -Status 'running' -Message $msg
    Add-StepRunLine 'info' ((T 'Starting: {0} commands, in order') -f $queue.Count)

    $window = Get-AppWindow
    if ($window) {
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(120)
        $timer.Add_Tick({ param($s, $e) Invoke-StepRunTick })
        $StepRun.Timer = $timer
        $timer.Start()
    }

    Invoke-StepRunTick
    $true
}

<#
    Un latido. Hace UNA cosa y devuelve el hilo: cerrar el paso que
    ha terminado, seguir esperando una pausa o arrancar el siguiente.
#>
function Invoke-StepRunTick {
    if (-not $StepRun.Active) { return }

    if ($StepRun.Phase -eq 'pausing') {
        if ([DateTime]::Now -lt $StepRun.PauseUntil) { Sync-StepRunPanel; return }
        $StepRun.Phase = 'running'
        Start-NextStep
    }
    elseif ($StepRun.Handle) {
        if (-not (Test-CommandStepFinished $StepRun.Handle)) { Sync-StepRunPanel; return }
        Complete-CurrentStep
    }
    else {
        Start-NextStep
    }

    Sync-StepRunPanel
    Sync-LogView
}

function Complete-CurrentStep {
    $handle = $StepRun.Handle
    $StepRun.Handle = $null
    $step = $handle.Step
    $result = Complete-CommandStep $handle

    $step.Status = $result.State
    if ($result.State -eq 'succeeded') {
        $StepRun.Succeeded++
        if ($step.RequiresRestart) { $StepRun.Restart = $true }
    }
    else { $StepRun.Failed++ }

    $out = Format-CommandOutput $result.Output
    Add-StepRunLine $result.State $result.CommandLine $out

    $remaining = $StepRun.Index -lt ($StepRun.Queue.Count - 1)
    if ($step.PauseAfter -gt 0 -and $remaining -and $StepRunPauses) {
        $StepRun.Phase = 'pausing'
        $StepRun.PauseUntil = [DateTime]::Now.AddSeconds($step.PauseAfter)
        Add-StepRunLine 'waiting' ((T 'Waiting {0} s before the next command') -f $step.PauseAfter)
        return
    }
    Start-NextStep
}

function Start-NextStep {
    $StepRun.Index++
    if ($StepRun.Index -ge $StepRun.Queue.Count) {
        Complete-StepRun 'done'
        return
    }
    $step = $StepRun.Queue[$StepRun.Index]
    $step.Status = 'running'
    $StepRun.Handle = Start-CommandStep $step
}

# Cierra la ejecución: para el temporizador, marca lo que quedó sin
# correr y lo apunta en el log.
function Complete-StepRun {
    param([ValidateSet('done', 'cancelled')][string]$How)

    if ($StepRun.Timer) { $StepRun.Timer.Stop(); $StepRun.Timer = $null }
    foreach ($s in @($StepRun.Queue)) {
        if ($s.Status -eq 'pending') { $s.Status = 'skipped' }
    }
    $StepRun.Active = $false
    $StepRun.Phase = $How

    $msg = 'Run {0}: {1} succeeded, {2} failed, {3} total' -f $How, $StepRun.Succeeded, $StepRun.Failed, $StepRun.Queue.Count
    $level = if ($StepRun.Failed -gt 0) { 'warn' } else { 'info' }
    Write-AppLog -Source 'network' -Level $level -Status $How -Message $msg
    if ($StepRun.Restart) {
        Write-AppLog -Source 'network' -Level 'warn' -Status 'warn' -Message 'Restart the PC so the network resets take effect'
    }

    if ($How -eq 'done') {
        Add-StepRunLine 'info' ((T 'Finished: {0} succeeded, {1} failed') -f $StepRun.Succeeded, $StepRun.Failed)
    }
    else {
        Add-StepRunLine 'cancelled' (T 'Stopped by the user')
    }
    Sync-StepRunPanel
    Sync-LogView
}

# Detener: corta el paso en curso y deja el resto sin correr.
function Stop-StepRun {
    if (-not $StepRun.Active) { return }

    if ($StepRun.Handle) {
        $result = Stop-CommandStep $StepRun.Handle
        $StepRun.Handle.Step.Status = 'cancelled'
        Add-StepRunLine 'cancelled' $result.CommandLine
        $StepRun.Handle = $null
    }
    Complete-StepRun 'cancelled'
}

function Add-StepRunLine {
    param([string]$State, [string]$Text, [string]$Detail)

    $StepRun.Lines.Add([PSCustomObject]@{
        Time = [DateTime]::Now; State = $State; Text = $Text; Detail = $Detail
    })
    while ($StepRun.Lines.Count -gt $StepRunMaxLines) { $StepRun.Lines.RemoveAt(0) }
}

# ---- pintar a partir del estado ----------------------------------

<#
    Pone el marco, la lista y la cabecera de acuerdo con $StepRun.
    Se puede llamar cuantas veces haga falta. Si la pantalla de pasos
    no está delante, lo que no encuentra lo deja estar.
#>
function Sync-StepRunPanel {
    $window = Get-AppWindow
    if (-not $window) { return }
    $panel = $window.FindName('StepRunPanel')
    if (-not $panel -or -not $panel.Tag) { return }

    $category = $panel.Tag
    $steps = @($category.Steps)
    $picked = @($steps | Where-Object { Test-StepSelected $_ }).Count
    $active = $StepRun.Active
    $mine = ($StepRun.Category -and $StepRun.Category.Id -eq $category.Id)

    $title  = $window.FindName('StepRunTitle')
    $detail = $window.FindName('StepRunDetail')
    $icon   = $window.FindName('StepRunIcon')
    $count  = $window.FindName('StepRunCount')

    $total = [Math]::Max(1, @($StepRun.Queue).Count)
    $done = 0
    if ($mine) { $done = $StepRun.Succeeded + $StepRun.Failed }
    Set-TextFg $detail 'TextMuted'

    if ($mine -and $active -and $StepRun.Phase -eq 'pausing') {
        $secs = [Math]::Max(0, [Math]::Ceiling(($StepRun.PauseUntil - [DateTime]::Now).TotalSeconds))
        $title.Text = (T 'Waiting {0} s') -f $secs
        $next = $StepRun.Queue[$StepRun.Index + 1]
        $detail.Text = (T 'Next: {0}') -f (T $next.Name)
        Set-StepRunIcon $icon 'Clock' 'TextMuted'
        $count.Text = "$done/$total"
    }
    elseif ($mine -and $active) {
        $current = $null
        if ($StepRun.Index -ge 0 -and $StepRun.Index -lt $StepRun.Queue.Count) { $current = $StepRun.Queue[$StepRun.Index] }
        if ($current) {
            $title.Text = (T 'Running: {0}') -f (T $current.Name)
            $detail.Text = Format-CommandLine $current
        }
        Set-StepRunIcon $icon 'Sync' 'Accent'
        $count.Text = "$done/$total"
    }
    elseif ($mine -and $StepRun.Phase -in @('done', 'cancelled')) {
        if ($StepRun.Phase -eq 'done') {
            $title.Text = (T 'Finished: {0} succeeded, {1} failed') -f $StepRun.Succeeded, $StepRun.Failed
        }
        else {
            $title.Text = (T 'Stopped: {0} of {1} commands ran') -f $done, @($StepRun.Queue).Count
        }
        if ($StepRun.Restart) {
            $detail.Text = T 'Restart the PC so the network resets take effect.'
            Set-TextFg $detail 'Warn'
        }
        else {
            $detail.Text = (T '{0} of {1} commands selected') -f $picked, $steps.Count
            Set-TextFg $detail 'TextMuted'
        }
        if ($StepRun.Failed -gt 0 -or $StepRun.Phase -eq 'cancelled') { Set-StepRunIcon $icon 'Warning' 'Warn' }
        else { Set-StepRunIcon $icon 'Done' 'Success' }
        $count.Text = "$done/$total"
    }
    else {
        $title.Text = T 'Ready to run'
        $detail.Text = (T '{0} of {1} commands selected · they run from top to bottom') -f $picked, $steps.Count
        Set-TextFg $detail 'TextMuted'
        Set-StepRunIcon $icon 'Play' 'Accent'
        $count.Text = ''
    }

    # Barra: lo hecho frente a lo que falta. Parada, vacía.
    $left = $total - $done
    if (-not $mine) { $done = 0; $left = 1 }
    $window.FindName('StepRunDoneCol').Width = [System.Windows.GridLength]::new($done, 'Star')
    $window.FindName('StepRunLeftCol').Width = [System.Windows.GridLength]::new([Math]::Max(0, $left), 'Star')
    $fillKey = 'AccentGradient'
    if ($mine -and -not $active -and $StepRun.Failed -gt 0) { $fillKey = 'Warn' }
    Set-BoxBg $window.FindName('StepRunFill') $fillKey

    # El botón: Detener mientras corre; Ejecutar N si no.
    $btn = $window.FindName('StepRunButton')
    if ($active) {
        $btn.Tag.Icon.Text = Glyph 'Stop'
        $btn.Tag.Text.Text = T 'Stop'
        Set-BoxBg $btn 'Danger'
        $btn.IsEnabled = $true; $btn.Opacity = 1
    }
    else {
        $btn.Tag.Icon.Text = Glyph 'Play'
        $btn.Tag.Text.Text = (T 'Run {0}') -f $picked
        Set-BoxBg $btn 'AccentGradient'
        $can = ($picked -gt 0 -and -not $category.Locked)
        $btn.IsEnabled = $can
        $btn.Opacity = if ($can) { 1 } else { 0.45 }
    }

    if ($mine) { Sync-StepRunLines $window } else { $window.FindName('StepRunLines').Children.Clear() }

    # La lista: casillas, estados y que no se toque mientras corre.
    $list = $window.FindName('StepList')
    if ($list) {
        foreach ($child in $list.Children) {
            if ($child.Tag -and $child.Tag.PSObject.Properties['Step']) {
                Update-StepRow $child
                $available = Test-StepAvailable $child.Tag.Step
                $child.IsEnabled = (-not $active) -and (-not $category.Locked) -and $available
                $child.Cursor = if ($available) { 'Hand' } else { 'No' }
                # Se atenúa el CONTENIDO, no la fila: la entrada en cascada
                # anima la opacidad de la fila y, al acabar, la deja fija
                # en 1 por encima de lo que se ponga aquí.
                $child.Child.Opacity = if (-not $available) { 0.5 } elseif ($child.IsEnabled -or $active) { 1 } else { 0.6 }
            }
        }
    }
    foreach ($name in 'StepSelectDefault', 'StepSelectAll', 'StepSelectNone') {
        $chip = $window.FindName($name)
        if ($chip) { $chip.IsEnabled = -not $active; $chip.Opacity = if ($active) { 0.45 } else { 1 } }
    }
    $label = $window.FindName('StepSelectedLabel')
    if ($label) { $label.Text = (T '{0} of {1} selected') -f $picked, $steps.Count }
}

function Set-StepRunIcon {
    param($Icon, [string]$Glyph, [string]$Fg)
    $Icon.Text = Glyph $Glyph
    Set-TextFg $Icon $Fg
}

# Las líneas del registro en vivo. Se añaden solo las nuevas (o se
# rehace si se ha vaciado), y se baja al final.
function Sync-StepRunLines {
    param($Window)

    $box = $Window.FindName('StepRunLines')
    if (-not $box) { return }
    $lines = $StepRun.Lines.ToArray()

    if ($box.Children.Count -gt $lines.Count) { $box.Children.Clear() }
    for ($i = $box.Children.Count; $i -lt $lines.Count; $i++) {
        $box.Children.Add((New-StepRunLine $Window $lines[$i])) | Out-Null
    }
    $scroll = $Window.FindName('StepRunScroll')
    if ($scroll) { $scroll.ScrollToEnd() }
}

function New-StepRunLine {
    param($Window, $Line)

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.FontSize = 11.5
    $tb.TextWrapping = 'Wrap'
    $tb.Margin = New-Object System.Windows.Thickness 0, 1, 0, 1

    $time = New-Object System.Windows.Documents.Run ('{0:HH:mm:ss}  ' -f $Line.Time)
    $time.FontFamily = $Window.FindResource('MonoFont')
    Set-TextFg $time 'TextFaint'
    $tb.Inlines.Add($time)

    if ($Line.State -ne 'info') {
        $style = Get-StepStatusStyle $Line.State
        $word = New-Object System.Windows.Documents.Run ((T $style.Word) + '  ')
        $word.FontWeight = 'SemiBold'
        Set-TextFg $word $style.Fg
        $tb.Inlines.Add($word)
    }

    $text = New-Object System.Windows.Documents.Run $Line.Text
    if ($Line.State -ne 'info' -and $Line.State -ne 'waiting') { $text.FontFamily = $Window.FindResource('MonoFont') }
    Set-TextFg $text 'Text'
    $tb.Inlines.Add($text)

    if ($Line.Detail) {
        $tb.Inlines.Add((New-Object System.Windows.Documents.LineBreak))
        $d = New-Object System.Windows.Documents.Run ('          ' + $Line.Detail)
        $d.FontFamily = $Window.FindResource('MonoFont')
        $d.FontSize = 10.5
        Set-TextFg $d 'TextMuted'
        $tb.Inlines.Add($d)
    }
    $tb
}

# ---- selección rápida ----------------------------------------------

# "5 de 27 marcados", en la cabecera. El texto lo pone Sync-StepRunPanel.
function New-StepSelectedLabel {
    param($Window)
    $label = New-Object System.Windows.Controls.TextBlock
    $label.FontSize = 12
    $label.VerticalAlignment = 'Center'
    $label.Margin = New-Object System.Windows.Thickness 0, 0, 4, 0
    Set-TextFg $label 'TextFaint'
    Register-StepRunName $Window 'StepSelectedLabel' $label
    $label
}

<#
    Marca pasos en bloque: 'default' (lo que viene marcado de serie),
    'all' o 'none'. No se toca mientras corre.
#>
function Set-StepSelection {
    param($Category, [ValidateSet('default', 'all', 'none')][string]$Mode)

    if (Get-StepRunActive) { return }
    foreach ($s in @($Category.Steps)) {
        $s.Selected = switch ($Mode) {
            'default' { [bool]$s.Checked }
            'all'     { $true }
            'none'    { $false }
        }
    }
    Sync-StepRunPanel
}
