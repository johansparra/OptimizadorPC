# ============================================================
# Componente: franja plegable del pie de una tarjeta de ajuste
#
# El mecanismo de "abrir/cerrar" que comparten "Detalles técnicos"
# (New-TechnicalDetails) y "Referencia" (New-SettingReference):
# una línea separadora, una fila que se pulsa con su chevron, y un
# cuerpo que aparece con una transición. Aquí NO hay contenido:
# cada quien pasa el suyo montado en -Body.
#
#   ---------------------------------------------
#   (icono)  Etiqueta                          v
#   ---------------------------------------------
#   (cuerpo, oculto hasta que se pulsa)
#
# -Flush dice si esta franja es la ÚLTIMA de la tarjeta, pegada a
# su base: en ese caso la fila redondea sus esquinas inferiores
# para no tapar en cuadrado las de la tarjeta al pasar el ratón
# (16 de StaticCardStyle - 1px de borde = 15). Si va otra franja
# debajo, queda en medio y no redondea. Quien apila las franjas
# (New-SettingCard) es quien lo sabe.
# ============================================================

function New-DisclosureSection {
    # -Kind es un identificador ESTABLE de qué franja es esta
    # ('reference' / 'technical'), para poder apuntar a una sola
    # desde fuera sin comparar por su etiqueta, que está traducida
    # (ver Set-CategoryDisclosures). Opcional: sin él, la franja
    # sigue funcionando igual, solo que nadie la distingue del resto.
    param($Window, [string]$Icon, [string]$Label, $Body, [bool]$Flush = $true, [string]$Kind)

    $section = New-Object System.Windows.Controls.StackPanel

    # --- línea separadora, de borde a borde de la tarjeta ---
    $rule = New-Object System.Windows.Controls.Border
    $rule.Height = 1
    Set-BoxBg $rule 'Stroke'
    $section.Children.Add($rule) | Out-Null

    # --- cuerpo plegado (se construye ya, se enseña al pulsar) ---
    $Body.Visibility = 'Collapsed'

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
    if ($Flush) {
        $header.CornerRadius = New-Object System.Windows.CornerRadius 0, 0, 15, 15
    }

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    $ic = New-Icon $Icon 13 'TextFaint'
    $ic.Margin = New-Object System.Windows.Thickness 0, 0, 9, 0
    Add-ToColumn $grid $ic 0

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = T $Label
    $lbl.FontSize = 11.5
    $lbl.VerticalAlignment = 'Center'
    Set-TextFg $lbl 'TextMuted'
    Add-ToColumn $grid $lbl 1

    $chevron = New-Icon 'ChevronDown' 10 'TextFaint'
    Add-ToColumn $grid $chevron 2

    $header.Child = $grid

    $header.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $header.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    # Cuerpo, línea, chevron y si redondea viajan en el Tag: nada de
    # closures (regla 4 de CLAUDE.md).
    $header.Tag = [PSCustomObject]@{ Body = $Body; Split = $split; Chevron = $chevron; Flush = $Flush; Kind = $Kind }
    $header.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        if ($info.Body.Visibility -eq 'Visible') {
            $info.Body.Visibility = 'Collapsed'
            $info.Split.Visibility = 'Collapsed'
            $info.Chevron.Text = Glyph 'ChevronDown'
            # Si es la última franja, vuelve a redondear el pie.
            if ($info.Flush) {
                $s.CornerRadius = New-Object System.Windows.CornerRadius 0, 0, 15, 15
            }
        }
        else {
            $info.Body.Visibility = 'Visible'
            $info.Split.Visibility = 'Visible'
            $info.Chevron.Text = Glyph 'ChevronUp'
            # Con el cuerpo abierto la fila queda en medio: sin radio.
            $s.CornerRadius = New-Object System.Windows.CornerRadius 0
            Start-EnterTransition $info.Body 170 6
        }
    })

    $section.Children.Add($header) | Out-Null
    $section.Children.Add($split)  | Out-Null
    $section.Children.Add($Body)   | Out-Null
    $section
}

<#
    Abre una franja YA construida, sin la animación de entrada.

    Lo usa Copy-DisclosureState al reemplazar una tarjeta en el
    sitio (ver Update-SettingCard): la nueva nace plegada y hay que
    dejar abiertas las que el usuario tenía abiertas, pero sin que
    "aparezcan" -ya estaban ahí-.

    Es el mismo cambio de estado que el manejador de New-DisclosureSection
    en su rama "else", menos el Start-EnterTransition.
#>
function Open-DisclosureSection {
    param($Header)

    $info = $Header.Tag
    if (-not $info -or -not $info.PSObject.Properties['Body']) { return }
    if ($info.Body.Visibility -eq 'Visible') { return }

    $info.Body.Visibility  = 'Visible'
    $info.Split.Visibility = 'Visible'
    $info.Chevron.Text     = Glyph 'ChevronUp'
    $Header.CornerRadius    = New-Object System.Windows.CornerRadius 0
}

<#
    Cierra una franja YA construida, sin animación.

    El reverso de Open-DisclosureSection: el mismo cambio de estado
    que la rama "if visible" del manejador de New-DisclosureSection.
    Lo usa el menú "Contraer" de la cabecera del detalle (ver
    Set-CategoryDisclosures), que apaga varias a la vez y no quiere
    una docena de transiciones peleándose.

    Idempotente: llamarla sobre una franja ya plegada no hace nada.
#>
function Close-DisclosureSection {
    param($Header)

    $info = $Header.Tag
    if (-not $info -or -not $info.PSObject.Properties['Body']) { return }
    if ($info.Body.Visibility -ne 'Visible') { return }

    $info.Body.Visibility  = 'Collapsed'
    $info.Split.Visibility = 'Collapsed'
    $info.Chevron.Text     = Glyph 'ChevronDown'
    # Si es la última franja, vuelve a redondear el pie de la tarjeta.
    if ($info.Flush) {
        $Header.CornerRadius = New-Object System.Windows.CornerRadius 0, 0, 15, 15
    }
}
