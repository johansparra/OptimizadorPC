# ============================================================
# Componente: "Referencia" de un ajuste
#
# El CONTENIDO de la segunda franja plegable de la tarjeta, la
# que reúne los datos de consulta de la clave:
#
#   ---------------------------------------------
#   (>) Referencia                              v
#   ---------------------------------------------
#      Valores:  0x0000000A (10) · 1-70 · 0xFFFFFFFF
#      Óptimo para gaming:  [Sí]  quita el throttling en partida
#      Enlace:  https://learn.microsoft.com/...
#
# El mecanismo de abrir/cerrar es el mismo que "Detalles técnicos":
# New-DisclosureSection (ui/Components/Cards/Disclosure.ps1).
#
# Sale SOLO si el usuario activa la opción "Referencia" del menú
# Vista (Get-ViewOption 'reference', oculta por defecto) Y el
# ajuste toca el registro. El "Qué hace" NO está aquí: ese es el
# contenido principal y vive en la descripción de la tarjeta
# (New-SettingInfo).
#
# Los datos salen de New-Setting: -Values, -GamingOptimal,
# -GamingNote y -Link (ver ui/Engine/CategoryRegistry.ps1).
# ============================================================

function New-SettingReference {
    param($Window, $Setting, [bool]$Flush = $true)

    New-DisclosureSection -Window $Window -Icon 'OpenIn' -Label 'Reference' -Flush $Flush -Kind 'reference' `
        -Body (New-ReferenceBody $Window $Setting)
}

# El cuerpo: un bloque por dato. Mismo margen que New-TechnicalBody.
function New-ReferenceBody {
    param($Window, $Setting)

    $body = New-Object System.Windows.Controls.StackPanel
    $body.Margin = New-Object System.Windows.Thickness 18, 0, 18, 16

    # Valores: solo si el ajuste los declara.
    if ($Setting.Values) {
        $body.Children.Add((New-FactBlock -Label (T 'Values') -Text (T $Setting.Values))) | Out-Null
    }

    # Óptimo para gaming: siempre uno de los tres estados.
    $body.Children.Add((New-GamingFactBlock $Setting)) | Out-Null

    # Enlace: la URL, o "Sin enlace" si no hay.
    $body.Children.Add((New-LinkFactBlock $Setting.Link)) | Out-Null

    $body
}

<#
    Un bloque: etiqueta en negrita y, debajo, el contenido. El
    contenido puede venir como texto (-Text) o como un control ya
    montado (-Content): el enlace y la etiqueta de gaming.
#>
function New-FactBlock {
    param([string]$Label, [string]$Text, $Content)

    $block = New-Object System.Windows.Controls.StackPanel
    $block.Margin = New-Object System.Windows.Thickness 0, 0, 0, 7

    $head = New-Object System.Windows.Controls.TextBlock
    $head.Text = $Label
    $head.FontSize = 11.5
    $head.FontWeight = 'SemiBold'
    Set-TextFg $head 'Text'
    $block.Children.Add($head) | Out-Null

    if ($Content) {
        $block.Children.Add($Content) | Out-Null
    }
    else {
        $line = New-Object System.Windows.Controls.TextBlock
        $line.Text = $Text
        $line.FontSize = 11.5
        $line.TextWrapping = 'Wrap'
        $line.LineHeight = 17
        $line.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
        Set-TextFg $line 'TextMuted'
        $block.Children.Add($line) | Out-Null
    }

    $block
}

# La etiqueta Sí / No / N/A y, si la hay, una nota corta al lado.
function New-GamingFactBlock {
    param($Setting)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Margin = New-Object System.Windows.Thickness 0, 2, 0, 0

    $row.Children.Add((New-GamingTag $Setting.GamingOptimal)) | Out-Null

    if ($Setting.GamingNote) {
        $note = New-Object System.Windows.Controls.TextBlock
        $note.Text = T $Setting.GamingNote
        $note.FontSize = 11.5
        $note.TextWrapping = 'Wrap'
        $note.VerticalAlignment = 'Center'
        $note.Margin = New-Object System.Windows.Thickness 8, 0, 0, 0
        Set-TextFg $note 'TextMuted'
        $row.Children.Add($note) | Out-Null
    }

    New-FactBlock -Label (T 'Good for gaming') -Content $row
}

# Sí / No / N/A con los mismos colores que New-Tag.
function New-GamingTag {
    param([string]$State)

    $map = @{
        'yes' = @{ Text = 'Yes'; Fg = 'Success';   Bg = 'SuccessSoft' }
        'no'  = @{ Text = 'No';  Fg = 'Danger';    Bg = 'DangerSoft' }
        'na'  = @{ Text = 'N/A'; Fg = 'TextMuted'; Bg = 'SurfaceSunken' }
    }
    $c = $map[[string]$State]
    if (-not $c) { $c = $map['na'] }

    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius 6
    $b.Padding = New-Object System.Windows.Thickness 8, 2.5, 8, 3.5
    $b.VerticalAlignment = 'Center'
    Set-BoxBg $b $c.Bg

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T $c.Text
    $t.FontSize = 10.5
    $t.FontWeight = 'SemiBold'
    Set-TextFg $t $c.Fg
    $b.Child = $t
    $b
}

<#
    El enlace, o "Sin enlace" si no hay. Al pulsarlo se abre en el
    navegador por defecto (core/Shell/ExternalLink.ps1, que solo deja
    pasar http/https). La URL viaja por el Tag: nada de closures
    (regla 4).
#>
function New-LinkFactBlock {
    param([string]$Url)

    if (-not $Url) {
        return (New-FactBlock -Label (T 'Link') -Text (T 'No reference link'))
    }

    $link = New-Object System.Windows.Controls.TextBlock
    $link.Text = $Url
    $link.FontSize = 11.5
    $link.TextWrapping = 'Wrap'
    $link.LineHeight = 17
    $link.Margin = New-Object System.Windows.Thickness 0, 1, 0, 0
    $link.Cursor = 'Hand'
    $link.TextDecorations = [System.Windows.TextDecorations]::Underline
    $link.ToolTip = T 'Open the reference in your browser'
    Set-TextFg $link 'Accent'
    $link.Tag = $Url
    $link.Add_MouseLeftButtonUp({ param($s, $e) Invoke-ExternalLink $s.Tag | Out-Null })

    New-FactBlock -Label (T 'Link') -Content $link
}
