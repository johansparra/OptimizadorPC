# ============================================================
# Componente: detalle técnico de un ajuste
#
# La franja plegable del pie de cada tarjeta de ajuste. Enseña
# qué claves del registro toca ese ajuste y con qué valores:
#
#   ---------------------------------------------
#   (i) Detalles técnicos                       v
#   ---------------------------------------------
#      Claves de registro de Windows
#      [/]  Ruta:  HKEY_LOCAL_MACHINE\...  [c]   Actual: 5
#           Valor: ConsentPromptBehaviorAdmin [c] Recomendado: 0
#                                                Predeterminado: 5
#
# La ruta y el valor se pueden seleccionar con el ratón y copiar con
# Ctrl+C, y cada uno tiene su botón [c] al lado (ver New-MonoField).
#
# Los datos salen del campo Registry del ajuste (ver -Registry
# en New-Setting, ui/Engine/CategoryRegistry.ps1). Un ajuste que aún no
# lo declare enseña un aviso en su lugar, para que se vea que la
# fila existe pero le falta el dato.
#
# "Actual" es lo que se acaba de leer del equipo (lo rellena
# core/Registry/CategoryState.ps1); "Recomendado" y "Predeterminado" son
# los valores declarados, y son contra los que se compara para
# decidir en qué estado está el ajuste. Escribir en el registro
# sigue sin hacerse.
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
    $stripText.Text = T 'Windows registry keys'
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

    # --- columna 1: ruta y valor, seleccionables y copiables ---
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.Margin = New-Object System.Windows.Thickness 0, 0, 24, 0

    $type = $null
    if ($Key.Type) { $type = "($($Key.Type))" }

    $texts.Children.Add((New-MonoField -Window $Window -Label (T 'Path:') -Value $Key.Path `
        -Tip 'Copy the registry path')) | Out-Null
    $texts.Children.Add((New-MonoField -Window $Window -Label (T 'Value:') -Value $Key.Name -Suffix $type `
        -Tip 'Copy the value name')) | Out-Null

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
        'read'    {
            # El color dice de un vistazo contra qué ha cuadrado el
            # valor: verde si es el recomendado, apagado si es el de
            # fábrica y naranja si no es ninguno. Mismo catálogo que
            # la etiqueta de la tarjeta (Get-StatusStyle), así que no
            # pueden decir cosas distintas. Sin Status -esta clave no
            # se ha comparado con nada- se queda en el color normal.
            $fg = 'Text'
            if ($Key.Status) { $fg = (Get-StatusStyle $Key.Status).Fg }
            return (New-StateLine $Window $label $Key.Current $fg)
        }
        'missing' { return (New-StateLine $Window $label (T 'not set')           'TextFaint') }
        'denied'  { return (New-StateLine $Window $label (T 'no access')         'Danger') }
        'badpath' { return (New-StateLine $Window $label (T 'unknown root key')  'Danger') }
    }

    # Sin State: nadie ha leído todavía esta clave.
    New-StateLine $Window $label (T 'not read') 'TextFaint'
}

<#
    "Ruta:  HKEY_LOCAL_MACHINE\..." en tipografía monoespaciada, con
    la etiqueta en negrita, el dato en color normal y un botón para
    copiarlo al portapapeles.

    El dato va en un TextBox de SOLO LECTURA, no en un TextBlock: en
    WPF un TextBlock no se puede seleccionar con el ratón ni copiar
    con Ctrl+C, y esto es justo lo que uno quiere pegar en el Editor
    del registro. Sin borde, sin fondo y sin cursor de escritura se ve
    igual que el texto de al lado, pero se selecciona, tiene su menú
    contextual y responde a Ctrl+C y Ctrl+A. De solo lectura quiere
    decir que no se puede escribir en él: no es un campo editable.

    Las tres columnas son etiqueta / dato / botón. El dato va en la
    columna elástica y con TextWrapping, que es lo que hace que una
    ruta larga baje de línea en vez de salirse de la tarjeta.
#>
function New-MonoField {
    param($Window, [string]$Label, [string]$Value, [string]$Suffix, [string]$Tip)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 0, 0, 0, 3
    Add-GridColumns $grid 'Auto', '*', 'Auto'

    # --- columna 0: la etiqueta, y con ella el tipo ---
    # El tipo se pega a la etiqueta y no detrás del dato porque ahí
    # entraría en la selección y se copiaría con él.
    $tag = New-Object System.Windows.Controls.TextBlock
    $tag.FontFamily = $Window.FindResource('MonoFont')
    $tag.FontSize = 11
    $tag.VerticalAlignment = 'Top'
    $tag.Margin = New-Object System.Windows.Thickness 0, 1, 7, 0

    $name = New-Object System.Windows.Documents.Run $Label
    $name.FontWeight = 'SemiBold'
    Set-TextFg $name 'TextMuted'
    $tag.Inlines.Add($name)

    if ($Suffix) {
        $extra = New-Object System.Windows.Documents.Run (' ' + $Suffix)
        Set-TextFg $extra 'TextFaint'
        $tag.Inlines.Add($extra)
    }
    Add-ToColumn $grid $tag 0

    # --- columna 1: el dato ---
    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = $Value
    $box.IsReadOnly = $true
    $box.IsReadOnlyCaretVisible = $false
    $box.BorderThickness = New-Object System.Windows.Thickness 0
    $box.Background = [System.Windows.Media.Brushes]::Transparent
    $box.Padding = New-Object System.Windows.Thickness 0
    $box.Margin = New-Object System.Windows.Thickness 0
    $box.FontFamily = $Window.FindResource('MonoFont')
    $box.FontSize = 11
    $box.TextWrapping = 'Wrap'
    $box.HorizontalAlignment = 'Left'
    $box.VerticalAlignment = 'Top'
    $box.ToolTip = T 'Select it or press Ctrl+C to copy it'
    Set-TextFg $box 'Text'
    Add-ToColumn $grid $box 1

    # --- columna 2: copiar ---
    Add-ToColumn $grid (New-CopyButton $Value $Tip) 2

    $grid
}

<#
    El botón de copiar de cada campo.

    Lo que se copia viaja en el Tag junto con su propio pie de ayuda,
    para poder devolverlo a su sitio después del aviso: nada de
    closures (regla 4 de CLAUDE.md).
#>
function New-CopyButton {
    param([string]$Text, [string]$Tip)

    $button = New-Object System.Windows.Controls.Border
    $button.Name = 'BtnCopy'
    $button.Width = 24; $button.Height = 21
    $button.CornerRadius = New-Object System.Windows.CornerRadius 6
    $button.Margin = New-Object System.Windows.Thickness 10, 0, 0, 0
    $button.VerticalAlignment = 'Top'
    $button.Cursor = 'Hand'
    $button.Background = [System.Windows.Media.Brushes]::Transparent
    $button.ToolTip = T $Tip
    $button.Child = (New-Icon 'Copy' 11 'TextFaint')
    $button.Tag = [PSCustomObject]@{ Text = $Text; Tip = $Tip }

    $button.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $button.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $button.Add_MouseLeftButtonUp({ param($s, $e) Copy-TechnicalValue $s })

    $button
}

# ---- Copiar al portapapeles -------------------------------------
#
# El aviso de "copiado" lo enseña UN botón cada vez: el que se acaba
# de pulsar. Si se copia otra cosa antes de que se apague, el anterior
# vuelve a su sitio en el acto. Guardarlo aquí -y no en cada botón-
# es lo que permite que el temporizador sea uno solo y que su
# manejador no necesite saber a quién apagar.
$CopyFeedbackButton = $null
$CopyFeedbackTimer = $null
$CopyFeedbackMs = 1400

<#
    Copia al portapapeles el texto que lleva el botón en su Tag.

    El portapapeles es de todo Windows y otro programa puede tenerlo
    tomado, en cuyo caso SetText lanza. Aquí eso no puede tumbar la
    ventana: si no se ha podido copiar, no se avisa de que sí.
#>
function Copy-TechnicalValue {
    param($Button)

    $info = $Button.Tag
    if (-not $info -or [string]::IsNullOrEmpty([string]$info.Text)) { return $false }

    try { [System.Windows.Clipboard]::SetText([string]$info.Text) }
    catch { return $false }

    Show-CopyFeedback $Button
    $true
}

# El aviso: el icono se vuelve una marca verde durante algo más de un
# segundo, y el pie de ayuda dice "Copiado" por si se vuelve a pasar
# el ratón por encima.
function Show-CopyFeedback {
    param($Button)

    Reset-CopyFeedback

    $script:CopyFeedbackButton = $Button
    $Button.Child.Text = Glyph 'Check'
    Set-TextFg $Button.Child 'Success'
    $Button.ToolTip = T 'Copied'

    if (-not $script:CopyFeedbackTimer) {
        $script:CopyFeedbackTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:CopyFeedbackTimer.Interval = [TimeSpan]::FromMilliseconds($CopyFeedbackMs)
        # El manejador llama a la función y es ella la que sabe a quién
        # apagar: un DispatcherTimer no tiene Tag donde dejar el botón.
        $script:CopyFeedbackTimer.Add_Tick({ param($s, $e) Reset-CopyFeedback })
    }
    $script:CopyFeedbackTimer.Stop()
    $script:CopyFeedbackTimer.Start()
}

# Devuelve el botón que estuviera avisando a su aspecto normal.
# Llamarla sin nadie avisando no hace nada.
function Reset-CopyFeedback {
    if ($script:CopyFeedbackTimer) { $script:CopyFeedbackTimer.Stop() }

    $button = $script:CopyFeedbackButton
    $script:CopyFeedbackButton = $null
    if (-not $button) { return }

    $button.Child.Text = Glyph 'Copy'
    Set-TextFg $button.Child 'TextFaint'
    $button.ToolTip = T $button.Tag.Tip
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
