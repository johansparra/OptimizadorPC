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
        -Message 'Its settings are shown for reference only: they cannot be changed. To unlock it, set Locked = $false in ui/CategoryIndex.ps1.'
}
