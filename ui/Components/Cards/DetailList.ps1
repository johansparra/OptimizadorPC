# ============================================================
# Componente: detalle desplegable ("qué hizo exactamente")
#
#   > Show details (4255 lines)                    <- se pulsa
#   +--------------------------------------------------+
#   | Skipped, in use or no access (36):               |
#   |   in use     C:\Users\...\Temp\e0fb7f80-....tmp  |  se selecciona
#   | Deleted (3256 files, 406.6 MB):                  |  y se copia
#   |   12 KB      C:\Users\...\Temp\setup.log         |
#   +--------------------------------------------------+
#
# Lo enseñan el registro de actividad (bajo la entrada) y la fila de
# un paso ya ejecutado (bajo su comando). Las líneas son las Items
# que dejó el paso: vienen de core/ en inglés y NO se traducen, igual
# que el resto del log (rutas y salida técnica que se copian tal
# cual). Se traduce el rótulo.
#
# EL ESTADO VIVE FUERA DEL CONTROL, en $DetailListOpen y por la clave
# que da quien la usa ('log:<Id>', 'step:<sección>:<paso>'). El log se
# rehace entero cada vez que cambia: si "abierto" viviera en el
# control, la lista se cerraría sola en mitad de una ejecución.
#
# EL CUERPO SE CONSTRUYE AL ABRIR, no al pintar la fila: vaciar %TEMP%
# deja miles de líneas y casi ninguna fila se abre nunca.
#
# Es un TextBox de solo lectura y no un TextBlock (regla 22): así la
# lista se selecciona con el ratón y se copia con Ctrl+C.
# ============================================================

$DetailListOpen = @{}

# Alto máximo de la lista abierta; más allá, se desplaza dentro.
$DetailListMaxHeight = 260

function Test-DetailListOpen {
    param([string]$Key)
    [bool]$DetailListOpen[$Key]
}

function Set-DetailListOpen {
    param([string]$Key, [bool]$Open)
    if (-not $Key) { return }
    if ($Open) { $DetailListOpen[$Key] = $true } else { $DetailListOpen.Remove($Key) }
}

<#
    El rótulo y el cuerpo (plegado o abierto según la clave). Devuelve
    un StackPanel listo para colgar debajo del texto de la fila.
#>
function New-DetailList {
    param($Window, [string[]]$Items, [string]$Key)

    $box = New-Object System.Windows.Controls.StackPanel
    $box.Margin = New-Object System.Windows.Thickness 0, 4, 0, 0

    # --- el rótulo que se pulsa ---
    $toggle = New-Object System.Windows.Controls.Border
    $toggle.Cursor = 'Hand'
    $toggle.HorizontalAlignment = 'Left'
    $toggle.CornerRadius = New-Object System.Windows.CornerRadius 5
    $toggle.Padding = New-Object System.Windows.Thickness 4, 1, 7, 2
    $toggle.Margin = New-Object System.Windows.Thickness -4, 0, 0, 0
    $toggle.Background = [System.Windows.Media.Brushes]::Transparent

    $line = New-Object System.Windows.Controls.StackPanel
    $line.Orientation = 'Horizontal'

    $chevron = New-Icon 'ChevronRight' 9 'Accent'
    $chevron.VerticalAlignment = 'Center'
    $chevron.Margin = New-Object System.Windows.Thickness 0, 1, 6, 0
    $line.Children.Add($chevron) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.FontSize = 11
    $label.FontWeight = 'SemiBold'
    Set-TextFg $label 'Accent'
    $line.Children.Add($label) | Out-Null
    $toggle.Child = $line

    # --- el cuerpo: vacío hasta que se abra ---
    $body = New-Object System.Windows.Controls.Border
    $body.CornerRadius = New-Object System.Windows.CornerRadius 6
    $body.Padding = New-Object System.Windows.Thickness 8, 6, 4, 6
    $body.Margin = New-Object System.Windows.Thickness 0, 4, 0, 2
    $body.Visibility = 'Collapsed'
    Set-BoxBg $body 'SurfaceSunken'
    # Seleccionar texto dentro no puede llegar a la fila de debajo: en
    # un paso, un clic en la fila lo marca o lo desmarca.
    $body.Add_MouseLeftButtonUp({ param($s, $e) $e.Handled = $true })

    # Todo lo que hace falta, por el Tag (regla 4).
    $toggle.Tag = [PSCustomObject]@{
        Key = $Key; Items = @($Items); Body = $body
        Chevron = $chevron; Label = $label; Window = $Window
    }
    $toggle.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceSunken' })
    $toggle.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $toggle.Add_MouseLeftButtonUp({
        param($s, $e)
        $e.Handled = $true
        Switch-DetailList $s
    })

    $box.Children.Add($toggle) | Out-Null
    $box.Children.Add($body) | Out-Null

    Sync-DetailList $toggle
    $box
}

function Switch-DetailList {
    param($Toggle)
    $info = $Toggle.Tag
    Set-DetailListOpen $info.Key (-not (Test-DetailListOpen $info.Key))
    Sync-DetailList $Toggle
}

# Pone rótulo, chevron y cuerpo de acuerdo con el estado guardado.
function Sync-DetailList {
    param($Toggle)

    $info = $Toggle.Tag
    $open = Test-DetailListOpen $info.Key
    if ($open) {
        if (-not $info.Body.Child) { $info.Body.Child = New-DetailListText $info.Window $info.Items }
        $info.Body.Visibility = 'Visible'
        $info.Chevron.Text = Glyph 'ChevronDown'
        $info.Label.Text = T 'Hide details'
    }
    else {
        $info.Body.Visibility = 'Collapsed'
        $info.Chevron.Text = Glyph 'ChevronRight'
        $info.Label.Text = (T 'Show details ({0} lines)') -f @($info.Items).Count
    }
}

# Las líneas, en un TextBox de solo lectura que se ve como texto.
function New-DetailListText {
    param($Window, [string[]]$Items)

    $tb = New-Object System.Windows.Controls.TextBox
    $tb.IsReadOnly = $true
    $tb.IsReadOnlyCaretVisible = $false
    $tb.BorderThickness = New-Object System.Windows.Thickness 0
    $tb.Background = [System.Windows.Media.Brushes]::Transparent
    $tb.Padding = New-Object System.Windows.Thickness 0
    $mono = $null
    if ($Window) { try { $mono = $Window.FindResource('MonoFont') } catch { $null = $_ } }
    if (-not $mono) { $mono = New-Object System.Windows.Media.FontFamily 'Cascadia Mono, Consolas' }
    $tb.FontFamily = $mono
    $tb.FontSize = 10.5
    $tb.TextWrapping = 'NoWrap'
    $tb.MaxHeight = $DetailListMaxHeight
    $tb.VerticalScrollBarVisibility = 'Auto'
    $tb.HorizontalScrollBarVisibility = 'Auto'
    $tb.Text = (@($Items) -join [Environment]::NewLine)
    Set-TextFg $tb 'TextMuted'
    $tb
}
