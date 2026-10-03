# ============================================================
# Componente: panel "Acerca de" del botón ? de la barra de título
#
# Lo que suele llevar un "Acerca de":
#   - nombre, versión y una línea de qué hace el programa
#   - sobre qué está corriendo: .exe o script, permisos, Windows,
#     PowerShell, arquitectura y dónde guarda sus datos
#   - un botón para copiarlo todo, que es lo que se pega en un
#     informe de fallo
#   - el enlace al repositorio
#
# Los datos de la aplicación salen de ui/Data/AppInfo.ps1 y los del
# equipo de core/Diagnostics/SystemInfo.ps1. Aquí solo se pintan.
#
# El Popup cuelga del mismo panel que el botón (un Popup suelto
# quedaría fuera del árbol lógico y el tema no le llegaría, ver
# ui/Components/Shell/ViewMenu.ps1). El contenido se rehace CADA
# VEZ que se abre: así sale en el idioma y el tema del momento y con
# los datos al día, sin tener que avisarle de nada.
# ============================================================

# Ancho de la tarjeta. También lo usa el cálculo del offset.
$AboutMenuWidth = 340.0

# Engancha el botón ? de la barra de título. Se llama una vez, desde
# main.ps1; el Popup se registra como 'AboutPopup' para encontrarlo.
function Initialize-AboutMenu {
    param($Window)

    $button = $Window.FindName('BtnHelp')
    if (-not $button) { return }

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.PlacementTarget = $button
    $popup.Placement = 'Bottom'
    $popup.VerticalOffset = 4
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'Fade'
    $button.Parent.Children.Add($popup) | Out-Null

    try { $Window.UnregisterName('AboutPopup') } catch { $null = $_ }
    $Window.RegisterName('AboutPopup', $popup)

    # El popup viaja en el Tag: nada de closures (regla 4).
    $button.Tag = $popup
    $button.Add_Click({ param($s, $e) Switch-AboutMenu $s })
}

# Abre o cierra el panel. Separado del manejador para poder probarlo.
function Switch-AboutMenu {
    param($Button)

    $popup = $Button.Tag
    if (-not $popup) { return }

    if ($popup.IsOpen) { $popup.IsOpen = $false; return }

    $window = [System.Windows.Window]::GetWindow($Button)
    $popup.Child = New-AboutCard $window $popup

    # Alineado por la derecha con el botón: el panel se abre hacia la
    # izquierda en vez de salirse de la ventana. El margen de 10 es el
    # que deja New-AboutCard para la sombra.
    $popup.HorizontalOffset = $Button.ActualWidth - $AboutMenuWidth - 10
    $popup.IsOpen = $true
}

# El texto que se copia: lo mismo que se ve, una línea por dato.
function Get-AboutText {
    param($Info, $Runtime)

    $lines = @(
        '{0} {1}' -f $Info.Name, $Info.Version
        '{0}: {1}' -f (T 'Running as'), (Get-AboutHostLabel $Runtime.HostKind)
        '{0}: {1}' -f (T 'Permissions'), (Get-AboutElevationLabel $Runtime.Elevated)
        '{0}: {1}' -f 'Windows', $Runtime.Windows
        '{0}: {1}' -f 'PowerShell', $Runtime.PowerShell
        '{0}: {1}' -f (T 'Architecture'), $Runtime.Architecture
        '{0}: {1}' -f (T 'Data folder'), $Runtime.DataFolder
    )
    $lines -join [Environment]::NewLine
}

function Get-AboutHostLabel {
    param([string]$Kind)
    switch ($Kind) {
        'exe'    { T 'Compiled program (.exe)' }
        'script' { T 'Script (development)' }
        default  { T 'Unknown' }
    }
}

function Get-AboutElevationLabel {
    param([bool]$Elevated)
    if ($Elevated) { T 'Administrator' } else { T 'Standard user' }
}

# La tarjeta flotante entera.
function New-AboutCard {
    param($Window, $Popup)

    $info    = Get-AppInfo
    $runtime = Get-AppRuntimeInfo

    # AllowsTransparency recorta lo que se salga del Popup, así que
    # la sombra necesita este margen para caber.
    $room = New-Object System.Windows.Controls.Grid
    $room.Margin = New-Object System.Windows.Thickness 10, 0, 10, 14

    $card = New-Object System.Windows.Controls.Border
    $card.Width = $AboutMenuWidth
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.BorderThickness = New-Object System.Windows.Thickness 1
    $card.Padding = New-Object System.Windows.Thickness 16, 16, 16, 14
    Set-BoxBg   $card 'Surface'
    Set-BoxLine $card 'Stroke'

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 3
    $shadow.BlurRadius = 16; $shadow.Opacity = 0.18
    $card.Effect = $shadow

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Children.Add((New-AboutHeader $info)) | Out-Null

    $about = New-Object System.Windows.Controls.TextBlock
    $about.Text = T $info.Description
    $about.FontSize = 12
    $about.TextWrapping = 'Wrap'
    $about.LineHeight = 17
    $about.Margin = New-Object System.Windows.Thickness 0, 12, 0, 0
    Set-TextFg $about 'TextMuted'
    $stack.Children.Add($about) | Out-Null

    $stack.Children.Add((New-AboutDivider)) | Out-Null
    $stack.Children.Add((New-AboutDetails $info $runtime)) | Out-Null
    $stack.Children.Add((New-AboutDivider)) | Out-Null
    $stack.Children.Add((New-AboutRepoLink $info $Popup)) | Out-Null

    $card.Child = $stack
    $room.Children.Add($card) | Out-Null
    $room
}

# Icono, nombre y versión.
function New-AboutHeader {
    param($Info)

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*'

    $tile = New-IconTile 'Bolt' 'Accent' 'AccentSoft' 40
    $tile.Margin = New-Object System.Windows.Thickness 0, 0, 12, 0
    Add-ToColumn $grid $tile 0

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Info.Name
    $name.FontSize = 15
    $name.FontWeight = 'SemiBold'
    Set-TextFg $name 'Text'
    $texts.Children.Add($name) | Out-Null

    $version = New-Object System.Windows.Controls.TextBlock
    $version.Name = 'AboutVersion'
    $version.Text = '{0} {1}' -f (T 'Version'), $Info.Version
    $version.FontSize = 11.5
    $version.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
    Set-TextFg $version 'TextMuted'
    $texts.Children.Add($version) | Out-Null

    Add-ToColumn $grid $texts 1
    $grid
}

function New-AboutDivider {
    $line = New-Object System.Windows.Controls.Border
    $line.Height = 1
    $line.Margin = New-Object System.Windows.Thickness 0, 12, 0, 12
    Set-BoxBg $line 'Stroke'
    $line
}

# Título "Detalles" con su botón de copiar, y una fila por dato.
function New-AboutDetails {
    param($Info, $Runtime)

    $stack = New-Object System.Windows.Controls.StackPanel

    $head = New-Object System.Windows.Controls.Grid
    $head.Margin = New-Object System.Windows.Thickness 0, 0, 0, 6
    Add-GridColumns $head '*', 'Auto'

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = T 'Details'
    $title.FontSize = 10.5
    $title.FontWeight = 'SemiBold'
    $title.VerticalAlignment = 'Center'
    Set-TextFg $title 'TextFaint'
    Add-ToColumn $head $title 0

    # El mismo botón (y el mismo aviso de "copiado") que los
    # detalles técnicos de cada ajuste.
    $copy = New-CopyButton (Get-AboutText $Info $Runtime) 'Copy these details'
    $copy.Name = 'AboutCopy'
    Add-ToColumn $head $copy 1
    $stack.Children.Add($head) | Out-Null

    # Objetos y no pares @('a','b'): dentro de @( ... ) los
    # subarreglos puestos uno por línea se aplanan en una sola lista.
    $rows = @(
        [PSCustomObject]@{ Label = T 'Running as';   Value = Get-AboutHostLabel $Runtime.HostKind }
        [PSCustomObject]@{ Label = T 'Permissions';  Value = Get-AboutElevationLabel $Runtime.Elevated }
        [PSCustomObject]@{ Label = 'Windows';        Value = $Runtime.Windows }
        [PSCustomObject]@{ Label = 'PowerShell';     Value = $Runtime.PowerShell }
        [PSCustomObject]@{ Label = T 'Architecture'; Value = $Runtime.Architecture }
        [PSCustomObject]@{ Label = T 'Data folder';  Value = $Runtime.DataFolder }
    )
    foreach ($row in $rows) {
        $stack.Children.Add((New-AboutRow $row.Label $row.Value)) | Out-Null
    }
    $stack
}

# Etiqueta a la izquierda, dato a la derecha. El dato baja de línea
# si no cabe (la carpeta de datos es larga).
function New-AboutRow {
    param([string]$Label, [string]$Value)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 0, 3, 0, 3
    $col = New-Object System.Windows.Controls.ColumnDefinition
    $col.Width = New-Object System.Windows.GridLength 104
    $grid.ColumnDefinitions.Add($col)
    Add-GridColumns $grid '*'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Label
    $name.FontSize = 11.5
    $name.VerticalAlignment = 'Top'
    Set-TextFg $name 'TextMuted'
    Add-ToColumn $grid $name 0

    $data = New-Object System.Windows.Controls.TextBlock
    $data.Text = $Value
    $data.FontSize = 11.5
    $data.TextWrapping = 'Wrap'
    Set-TextFg $data 'Text'
    Add-ToColumn $grid $data 1

    $grid
}

# El enlace al repositorio. Se abre por core/Shell/ExternalLink.ps1,
# que solo deja pasar http/https. La URL viaja por el Tag (regla 4).
function New-AboutRepoLink {
    param($Info, $Popup)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent
    $row.ToolTip = $Info.Repository

    $icon = New-Icon 'OpenIn' 12 'Accent'
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 7, 0
    $row.Children.Add($icon) | Out-Null

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = T 'View the project on GitHub'
    $text.FontSize = 12
    $text.FontWeight = 'SemiBold'
    Set-TextFg $text 'Accent'
    $row.Children.Add($text) | Out-Null

    $row.Tag = [PSCustomObject]@{ Url = $Info.Repository; Popup = $Popup }
    $row.Add_MouseLeftButtonUp({
        param($s, $e)
        Invoke-ExternalLink $s.Tag.Url | Out-Null
        $s.Tag.Popup.IsOpen = $false
    })
    $row
}
