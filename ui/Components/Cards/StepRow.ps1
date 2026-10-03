# ============================================================
# Componente: fila de un paso (secciones de comandos)
#
#   [casilla] [nº] [nombre / qué hace / comando / avisos] [estado]
#
# La fila entera es la casilla: un clic la marca o la desmarca. El
# número es el ORDEN DE EJECUCIÓN, que es el del archivo de la
# sección, no el del clic.
#
# El estado de la derecha (en cola, en curso, correcto, falló...) lo
# pone Update-StepRow a partir de $Step.Status, que va rellenando la
# ejecución (ui/Components/Layout/StepRunPanel.ps1). La fila no sabe
# ejecutar nada: solo se pinta a partir del paso.
# ============================================================

# Estado de un paso -> icono, color y palabra (en inglés: se traduce
# al pintar). Es el único sitio donde se escriben.
$StepStatusStyles = @{
    'pending'   = @{ Icon = 'Clock';   Fg = 'TextFaint'; Word = 'queued' }
    'running'   = @{ Icon = 'Sync';    Fg = 'Accent';    Word = 'running' }
    'succeeded' = @{ Icon = 'Done';    Fg = 'Success';   Word = 'succeeded' }
    'failed'    = @{ Icon = 'Failed';  Fg = 'Danger';    Word = 'failed' }
    'timed out' = @{ Icon = 'Failed';  Fg = 'Danger';    Word = 'timed out' }
    'error'     = @{ Icon = 'Failed';  Fg = 'Danger';    Word = 'error' }
    'blocked'   = @{ Icon = 'Failed';  Fg = 'Danger';    Word = 'blocked' }
    'cancelled' = @{ Icon = 'Stop';    Fg = 'Warn';      Word = 'cancelled' }
    'skipped'   = @{ Icon = 'Stop';    Fg = 'TextFaint'; Word = 'skipped' }
    'disarmed'  = @{ Icon = 'Warning'; Fg = 'Warn';      Word = 'disarmed' }
    'waiting'   = @{ Icon = 'Clock';   Fg = 'TextMuted'; Word = 'waiting' }
}

function Get-StepStatusStyle {
    param([string]$Status)
    $style = $StepStatusStyles[$Status]
    if (-not $style) { $style = @{ Icon = 'Info'; Fg = 'TextMuted'; Word = $Status } }
    $style
}

function New-StepRow {
    param($Window, $Step, [int]$Number)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 10
    $row.BorderThickness = New-Object System.Windows.Thickness 1
    $row.Padding = New-Object System.Windows.Thickness 14, 11, 16, 12
    $row.Margin = New-Object System.Windows.Thickness 0, 0, 0, 8
    $row.Cursor = 'Hand'
    Set-BoxBg   $row 'Surface'
    Set-BoxLine $row 'Stroke'

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', 'Auto', '*', 'Auto'

    # --- columna 0: la casilla ---
    $check = New-Icon 'CheckOff' 17 'TextFaint'
    $check.VerticalAlignment = 'Top'
    $check.Margin = New-Object System.Windows.Thickness 0, 1, 12, 0
    Add-ToColumn $grid $check 0

    # --- columna 1: el orden ---
    $num = New-Object System.Windows.Controls.TextBlock
    $num.Text = '{0:00}' -f $Number
    $num.FontFamily = $Window.FindResource('MonoFont')
    $num.FontSize = 11.5
    $num.VerticalAlignment = 'Top'
    $num.Margin = New-Object System.Windows.Thickness 0, 3, 12, 0
    $num.ToolTip = T 'Run order'
    Set-TextFg $num 'TextFaint'
    Add-ToColumn $grid $num 1

    # --- columna 2: nombre, qué hace, comando y avisos ---
    $texts = New-Object System.Windows.Controls.StackPanel

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Step.Name
    $name.FontSize = 13
    $name.FontWeight = 'SemiBold'
    $name.TextWrapping = 'Wrap'
    Set-TextFg $name 'Text'
    $texts.Children.Add($name) | Out-Null

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $Step.Description
    $desc.FontSize = 11.5
    $desc.TextWrapping = 'Wrap'
    $desc.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0
    Set-TextFg $desc 'TextMuted'
    $texts.Children.Add($desc) | Out-Null

    # El comando tal cual: es lo que de verdad se ejecuta, y lo que
    # uno buscaría para saber qué hace. Texto técnico: no se traduce.
    $cmd = New-Object System.Windows.Controls.TextBlock
    $cmd.Text = Format-CommandLine $Step
    $cmd.FontFamily = $Window.FindResource('MonoFont')
    $cmd.FontSize = 11
    $cmd.TextWrapping = 'Wrap'
    $cmd.Margin = New-Object System.Windows.Thickness 0, 5, 0, 0
    Set-TextFg $cmd 'TextFaint'
    $texts.Children.Add($cmd) | Out-Null

    $notes = New-StepNotes $Step
    if ($notes.Children.Count -gt 0) { $texts.Children.Add($notes) | Out-Null }

    Add-ToColumn $grid $texts 2

    # --- columna 3: estado de la ejecución ---
    $status = New-Object System.Windows.Controls.StackPanel
    $status.Orientation = 'Horizontal'
    $status.VerticalAlignment = 'Top'
    $status.Margin = New-Object System.Windows.Thickness 14, 2, 0, 0

    $statusIcon = New-Icon 'Clock' 13 'TextFaint'
    $statusIcon.Margin = New-Object System.Windows.Thickness 0, 0, 6, 0
    $status.Children.Add($statusIcon) | Out-Null

    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.FontSize = 11.5
    $statusText.FontWeight = 'SemiBold'
    $status.Children.Add($statusText) | Out-Null
    Add-ToColumn $grid $status 3

    $row.Child = $grid

    # Todo lo que hace falta para repintarla, por el Tag (regla 4).
    $row.Tag = [PSCustomObject]@{
        Step = $Step; Check = $check; Status = $status
        StatusIcon = $statusIcon; StatusText = $statusText
    }
    $row.Add_MouseLeftButtonUp({ param($s, $e) Switch-StepSelection $s })
    $row.Add_MouseEnter({ param($s, $e) if ($s.IsEnabled) { Set-BoxLine $s 'StrokeHover' } })
    $row.Add_MouseLeave({ param($s, $e) Set-BoxLine $s 'Stroke' })

    Update-StepRow $row
    $row
}

# Los avisos bajo el comando: el de la sección (ámbar), si pide
# reiniciar y si espera después.
function New-StepNotes {
    param($Step)

    $notes = New-Object System.Windows.Controls.WrapPanel
    $notes.Margin = New-Object System.Windows.Thickness 0, 6, 0, 0

    # Sin permisos, lo primero que se lee es por qué no se puede marcar.
    if (-not (Test-StepAvailable $Step)) {
        $notes.Children.Add((New-StepNote 'Lock' (T 'Requires administrator permissions: open the program as administrator') 'Danger')) | Out-Null
    }
    if ($Step.Warning) {
        $notes.Children.Add((New-StepNote 'Warning' (T $Step.Warning) 'Warn')) | Out-Null
    }
    if ($Step.RequiresRestart) {
        $notes.Children.Add((New-StepNote 'Restart' (T 'Needs a restart') 'TextMuted')) | Out-Null
    }
    if ($Step.PauseAfter -gt 0) {
        $notes.Children.Add((New-StepNote 'Clock' ((T 'Waits {0} s afterwards') -f $Step.PauseAfter) 'TextMuted')) | Out-Null
    }
    $notes
}

function New-StepNote {
    param([string]$Icon, [string]$Text, [string]$Fg)

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $sp.Margin = New-Object System.Windows.Thickness 0, 0, 14, 2

    $i = New-Icon $Icon 11 $Fg
    $i.VerticalAlignment = 'Top'
    $i.Margin = New-Object System.Windows.Thickness 0, 2, 5, 0
    $sp.Children.Add($i) | Out-Null

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.FontSize = 11
    $t.TextWrapping = 'Wrap'
    $t.MaxWidth = 620
    Set-TextFg $t $Fg
    $sp.Children.Add($t) | Out-Null
    $sp
}

# Pinta la casilla y el estado a partir del paso. La llama la propia
# fila al crearse y Sync-StepRunPanel en cada avance.
function Update-StepRow {
    param($Row)

    $info = $Row.Tag
    if (-not $info -or -not $info.Step) { return }
    $step = $info.Step

    # La casilla enseña la selección EFECTIVA: un paso que pide
    # administrador, sin permisos, sale desmarcado aunque se hubiera
    # elegido (Test-StepSelected).
    if (Test-StepSelected $step) {
        $info.Check.Text = Glyph 'CheckOn'
        Set-TextFg $info.Check 'Accent'
    }
    else {
        $info.Check.Text = Glyph 'CheckOff'
        Set-TextFg $info.Check 'TextFaint'
    }

    if (-not $step.Status) {
        $info.Status.Visibility = 'Collapsed'
        return
    }
    $style = Get-StepStatusStyle $step.Status
    $info.StatusIcon.Text = Glyph $style.Icon
    Set-TextFg $info.StatusIcon $style.Fg
    $info.StatusText.Text = T $style.Word
    Set-TextFg $info.StatusText $style.Fg
    $info.Status.Visibility = 'Visible'
}

# Un clic en la fila: marcar o desmarcar. Mientras se ejecuta no se
# toca nada -la cola ya está decidida-.
function Switch-StepSelection {
    param($Row)

    if (Get-StepRunActive) { return }
    if (-not $Row.IsEnabled) { return }
    $step = $Row.Tag.Step
    if (-not (Test-StepAvailable $step)) { return }
    $step.Selected = -not $step.Selected
    Update-StepRow $Row
    Sync-StepRunPanel
}
