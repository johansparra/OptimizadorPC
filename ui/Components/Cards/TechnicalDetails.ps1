# ============================================================
# Componente: detalle técnico de un ajuste
#
# La franja plegable del pie de cada tarjeta de ajuste. Enseña
# qué claves del registro toca ese ajuste y con qué valores:
#
#   ---------------------------------------------
#   (i) Detalles técnicos                       v
#   ---------------------------------------------
#      Cambios en el registro
#      [/]  Ruta:  HKEY_LOCAL_MACHINE\...        Actual: 5
#           Valor: ConsentPromptBehaviorAdmin    Recomendado: 0
#                                                Predeterminado: 5
#
# Los datos salen del campo Registry del ajuste (ver -Registry
# en New-Setting, ui/Engine/CategoryRegistry.ps1). Un ajuste que aún no
# lo declare enseña un aviso en su lugar, para que se vea que la
# fila existe pero le falta el dato.
#
# NADA de esto lee ni escribe el registro todavía: los valores
# son los declarados en ui/Data/Categories/.
# ============================================================

function New-TechnicalDetails {
    param($Window, $Setting)

    $section = New-Object System.Windows.Controls.StackPanel

    # --- línea separadora, de borde a borde de la tarjeta ---
    $rule = New-Object System.Windows.Controls.Border
    $rule.Height = 1
    Set-BoxBg $rule 'Stroke'
    $section.Children.Add($rule) | Out-Null

    # --- cuerpo plegado (se construye ya, se enseña al pulsar) ---
    $body = New-TechnicalBody $Window $Setting
    $body.Visibility = 'Collapsed'

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

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    $icon = New-Icon 'Info' 13 'TextFaint'
    $icon.Margin = New-Object System.Windows.Thickness 0, 0, 9, 0
    Add-ToColumn $grid $icon 0

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T 'Technical details'
    $label.FontSize = 11.5
    $label.VerticalAlignment = 'Center'
    Set-TextFg $label 'TextMuted'
    Add-ToColumn $grid $label 1

    $chevron = New-Icon 'ChevronDown' 10 'TextFaint'
    Add-ToColumn $grid $chevron 2

    $header.Child = $grid

    $header.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $header.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })

    # Cuerpo, línea y chevron viajan en el Tag: nada de closures
    # (regla 4 de CLAUDE.md).
    $header.Tag = [PSCustomObject]@{ Body = $body; Split = $split; Chevron = $chevron }
    $header.Add_MouseLeftButtonUp({
        param($s, $e)
        $info = $s.Tag
        if ($info.Body.Visibility -eq 'Visible') {
            $info.Body.Visibility = 'Collapsed'
            $info.Split.Visibility = 'Collapsed'
            $info.Chevron.Text = Glyph 'ChevronDown'
        }
        else {
            $info.Body.Visibility = 'Visible'
            $info.Split.Visibility = 'Visible'
            $info.Chevron.Text = Glyph 'ChevronUp'
            Start-EnterTransition $info.Body 170 6
        }
    })

    $section.Children.Add($header) | Out-Null
    $section.Children.Add($split)  | Out-Null
    $section.Children.Add($body)   | Out-Null
    $section
}

# El bloque que se despliega: título y una fila por clave.
function New-TechnicalBody {
    param($Window, $Setting)

    $body = New-Object System.Windows.Controls.StackPanel
    $body.Margin = New-Object System.Windows.Thickness 18, 0, 18, 16

    $strip = New-Object System.Windows.Controls.Border
    $strip.CornerRadius = New-Object System.Windows.CornerRadius 8
    $strip.Padding = New-Object System.Windows.Thickness 12, 7, 12, 8
    $strip.Margin = New-Object System.Windows.Thickness 0, 0, 0, 12
    Set-BoxBg $strip 'SurfaceSunken'

    $stripText = New-Object System.Windows.Controls.TextBlock
    $stripText.Text = T 'Registry changes'
    $stripText.FontSize = 11.5
    $stripText.FontWeight = 'SemiBold'
    Set-TextFg $stripText 'TextMuted'
    $strip.Child = $stripText
    $body.Children.Add($strip) | Out-Null

    $keys = @($Setting.Registry)
    if ($keys.Count -eq 0) {
        $body.Children.Add((New-TechnicalPlaceholder)) | Out-Null
        return $body
    }

    foreach ($key in $keys) {
        $body.Children.Add((New-RegistryKeyRow $Window $key)) | Out-Null
    }
    $body
}

# Una clave: botón de abrir, ruta y valor, y los tres estados.
function New-RegistryKeyRow {
    param($Window, $Key)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 4, 0, 4, 14
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    # --- columna 0: abrir en el Editor del registro ---
    # Todavía no hace nada: la app es solo interfaz por ahora.
    $open = New-Object System.Windows.Controls.Border
    $open.Width = 28; $open.Height = 28
    $open.CornerRadius = New-Object System.Windows.CornerRadius 8
    $open.BorderThickness = New-Object System.Windows.Thickness 1
    $open.Margin = New-Object System.Windows.Thickness 0, 1, 14, 0
    $open.VerticalAlignment = 'Top'
    $open.Cursor = 'Hand'
    $open.ToolTip = T 'Open this key in Registry Editor'
    Set-BoxBg   $open 'Surface'
    Set-BoxLine $open 'Stroke'
    $open.Child = (New-Icon 'OpenIn' 12 'TextMuted')
    Add-ToColumn $grid $open 0

    # --- columna 1: ruta y valor ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.Margin = New-Object System.Windows.Thickness 0, 0, 24, 0

    $type = $null
    if ($Key.Type) { $type = "($($Key.Type))" }
    $texts.Children.Add((New-MonoLine $Window (T 'Path:')  $Key.Path)) | Out-Null
    $texts.Children.Add((New-MonoLine $Window (T 'Value:') $Key.Name $type)) | Out-Null

    Add-ToColumn $grid $texts 1

    # --- columna 2: actual / recomendado / de fábrica ---
    $states = New-Object System.Windows.Controls.StackPanel
    $states.VerticalAlignment = 'Top'
    $states.Children.Add((New-CurrentLine $Window $Key))                                          | Out-Null
    $states.Children.Add((New-StateLine $Window (T 'Recommended:') $Key.Recommended 'Success'))   | Out-Null
    $states.Children.Add((New-StateLine $Window (T 'Factory:')     $Key.Default     'TextMuted')) | Out-Null
    Add-ToColumn $grid $states 2

    $grid
}

<#
    La línea "Actual:". A diferencia de las otras dos, que son
    datos declarados, esta la rellena core/Registry/CategoryState.ps1 al
    entrar en la sección, y puede haber salido de cuatro maneras.

    Que un valor no exista NO es un fallo: quiere decir que Windows
    está usando su valor interno, y se dice con esas palabras en
    vez de con un guion, que no distinguiría "no está" de "no se
    ha mirado".
#>
function New-CurrentLine {
    param($Window, $Key)

    $label = T 'Current:'

    switch ($Key.State) {
        'read'    { return (New-StateLine $Window $label $Key.Current            'Text') }
        'missing' { return (New-StateLine $Window $label (T 'not set')           'TextFaint') }
        'denied'  { return (New-StateLine $Window $label (T 'no access')         'Danger') }
        'badpath' { return (New-StateLine $Window $label (T 'unknown root key')  'Danger') }
    }

    # Sin State: nadie ha leído todavía esta clave.
    New-StateLine $Window $label (T 'not read') 'TextFaint'
}

# "Ruta:  HKEY_LOCAL_MACHINE\..." en tipografía monoespaciada,
# con la etiqueta en negrita y el dato en color normal.
function New-MonoLine {
    param($Window, [string]$Label, [string]$Value, [string]$Suffix)

    $line = New-Object System.Windows.Controls.TextBlock
    $line.FontFamily = $Window.FindResource('MonoFont')
    $line.FontSize = 11
    $line.LineHeight = 17
    $line.TextWrapping = 'Wrap'

    $tag = New-Object System.Windows.Documents.Run ($Label + ' ')
    $tag.FontWeight = 'SemiBold'
    Set-TextFg $tag 'TextMuted'
    $line.Inlines.Add($tag)

    $data = New-Object System.Windows.Documents.Run $Value
    Set-TextFg $data 'Text'
    $line.Inlines.Add($data)

    if ($Suffix) {
        $extra = New-Object System.Windows.Documents.Run ('   ' + $Suffix)
        Set-TextFg $extra 'TextFaint'
        $line.Inlines.Add($extra)
    }

    $line
}

# "Actual: 5" alineado a la derecha.
function New-StateLine {
    param($Window, [string]$Label, [string]$Value, [string]$Fg)

    $line = New-Object System.Windows.Controls.TextBlock
    $line.FontFamily = $Window.FindResource('MonoFont')
    $line.FontSize = 11
    $line.LineHeight = 17
    $line.TextAlignment = 'Right'
    $line.HorizontalAlignment = 'Right'

    $tag = New-Object System.Windows.Documents.Run ($Label + ' ')
    Set-TextFg $tag 'TextFaint'
    $line.Inlines.Add($tag)

    $shown = $Value
    if ([string]::IsNullOrEmpty($shown)) { $shown = '-' }

    $data = New-Object System.Windows.Documents.Run $shown
    $data.FontWeight = 'SemiBold'
    Set-TextFg $data $Fg
    $line.Inlines.Add($data)

    $line
}

# Ajuste que todavía no declara sus claves.
function New-TechnicalPlaceholder {
    $note = New-Object System.Windows.Controls.TextBlock
    $note.Text = T 'No registry keys declared for this setting yet.'
    $note.FontSize = 11.5
    $note.TextWrapping = 'Wrap'
    $note.Margin = New-Object System.Windows.Thickness 4, 0, 4, 4
    Set-TextFg $note 'TextFaint'
    $note
}
