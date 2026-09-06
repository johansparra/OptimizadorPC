# ============================================================
# Componente: tarjeta de ajuste
#
# Es cada una de las filas de la pantalla de detalle. Estructura
# en 2 columnas:
#
#   [nombre + badge / descripción / etiquetas]  [indicadores + control]
#
# El control de la derecha lo decide el campo Type del ajuste,
# que New-Setting deduce solo (ver ui/Engine/CategoryRegistry.ps1):
#     Toggle    -> interruptor animado
#     Dropdown  -> desplegable
#
# Debajo pueden colgar hasta dos franjas plegables, cada una
# atada a una opción del botón "Vista":
#   - 'technical'  -> "Detalles técnicos" (ui/Components/Cards/TechnicalDetails.ps1)
#   - 'reference'  -> "Referencia"        (ui/Components/Cards/SettingReference.ps1)
# Las dos usan el mismo mecanismo (New-DisclosureSection). La
# insignia del título depende de la opción 'badges'.
#
# La descripción es el "Qué hace": -WhatItDoes si el ajuste lo
# declara, y si no la -Description de siempre.
#
# La etiqueta de debajo del nombre sale del ESTADO REAL del ajuste
# -optimizado, de fábrica o a medida- cuando lo hay: lo calcula
# core/Registry/SettingStatus.ps1 comparando lo que se acaba de leer del
# registro con lo que declara ui/Data/Categories/. Los ajustes que
# todavía no declaran claves siguen enseñando sus -Tags escritas a
# mano, que es lo único que tienen.
# ============================================================

function New-SettingCard {
    param($Window, $Setting, [switch]$Locked, [switch]$Highlight)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')

    # Se llega aquí desde un resultado de búsqueda: la sección puede
    # tener veinte filas y hay que ver CUÁL es. El borde de acento se
    # pone como valor local, que gana al disparador de IsMouseOver del
    # estilo, así que la marca no se pierde al pasar el ratón.
    if ($Highlight) {
        $card.BorderThickness = New-Object System.Windows.Thickness 1.6
        Set-BoxLine $card 'Accent'
    }

    # El relleno va en la fila, no en la tarjeta: así la línea
    # separadora del pie llega de borde a borde.
    $stack = New-Object System.Windows.Controls.StackPanel

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 20, 15, 20, 16
    Add-GridColumns $grid '*', 'Auto'

    Add-ToColumn $grid (New-SettingInfo $Window $Setting) 0

    $control = New-SettingControl $Window $Setting
    if ($Locked) {
        # IsEnabled = $false corta la entrada de todo el subárbol,
        # así que el interruptor deja de responder al ratón.
        $control.IsEnabled = $false
        $control.Opacity = 0.45
        $card.ToolTip = T 'Locked section'
    }
    Add-ToColumn $grid $control 1

    $stack.Children.Add($grid) | Out-Null

    # Franjas plegables del pie. Son de consulta, así que se enseñan
    # también en las secciones bloqueadas. "Referencia" solo tiene
    # sentido para ajustes que tocan el registro; "Detalles técnicos"
    # sale siempre (con un aviso si no hay claves).
    #
    # -Flush lo lleva la ÚLTIMA franja: si "Referencia" tiene
    # "Detalles técnicos" debajo, no es la última y no redondea el
    # pie (ver New-DisclosureSection).
    $showReference = (Get-ViewOption 'reference') -and @($Setting.Registry).Count -gt 0
    $showTechnical = [bool](Get-ViewOption 'technical')

    if ($showReference) {
        $stack.Children.Add((New-SettingReference $Window $Setting -Flush (-not $showTechnical))) | Out-Null
    }
    if ($showTechnical) {
        $stack.Children.Add((New-TechnicalDetails $Window $Setting)) | Out-Null
    }

    $card.Child = $stack
    $card
}

# Columna izquierda: nombre, descripción y etiquetas.
function New-SettingInfo {
    param($Window, $Setting)

    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = 'Center'

    $nameRow = New-Object System.Windows.Controls.StackPanel
    $nameRow.Orientation = 'Horizontal'

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = T $Setting.Name
    $name.FontFamily = $Window.FindResource('DisplayFont')
    $name.FontWeight = 'SemiBold'
    $name.FontSize = 13.5
    Set-TextFg $name 'Text'
    $nameRow.Children.Add($name) | Out-Null

    if ($Setting.Badge -and (Get-ViewOption 'badges')) {
        $nameRow.Children.Add((New-Badge $Setting.Badge)) | Out-Null
    }
    $left.Children.Add($nameRow) | Out-Null

    # La "Descripción": el contenido principal de la clave, en una
    # línea. -WhatItDoes manda si el ajuste lo declara; si no, la
    # -Description de siempre. Los valores, el gaming y el enlace NO
    # van aquí: viven en la franja "Referencia", opt-in desde el
    # menú Vista (ver New-SettingReference).
    $whatText = $Setting.WhatItDoes
    if (-not $whatText) { $whatText = $Setting.Description }

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $whatText
    $desc.FontSize = 11.5
    $desc.TextWrapping = 'Wrap'
    $desc.LineHeight = 17
    $desc.Margin = New-Object System.Windows.Thickness 0, 5, 30, 9
    Set-TextFg $desc 'TextMuted'
    $left.Children.Add($desc) | Out-Null

    # Etiquetas. Si el ajuste declara claves del registro, core/ le ha
    # dejado un Status leyendo el equipo (ver SettingStatus.ps1) y manda
    # ese: es UNO de los tres estados, y es un hecho. Las -Tags
    # declaradas a mano son la versión de mentira de lo mismo, así que
    # solo salen mientras no haya nada real que enseñar.
    $tags = New-Object System.Windows.Controls.StackPanel
    $tags.Orientation = 'Horizontal'

    if ($Setting.Status) {
        $tags.Children.Add((New-StatusTag $Setting.Status)) | Out-Null
    }
    else {
        foreach ($tag in $Setting.Tags) { $tags.Children.Add((New-Tag $tag)) | Out-Null }
    }

    $left.Children.Add($tags) | Out-Null

    $left
}

# Columna derecha: indicadores y el control que corresponda.
function New-SettingControl {
    param($Window, $Setting)

    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $right.VerticalAlignment = 'Center'

    # Indicadores: el valor actual coincide con el recomendado / el de
    # fábrica. Que es justo lo que dice el Status cuando lo hay, así
    # que ahí mandan los hechos y no las etiquetas declaradas -que
    # además solían salir las dos a la vez, lo cual era imposible-.
    if ($Setting.Status) {
        $isRecommended = $Setting.Status -eq 'optimized'
        $isFactory     = $Setting.Status -eq 'factory'
    }
    else {
        $isRecommended = $Setting.Tags -contains 'Recommended'
        $isFactory     = $Setting.Tags -contains 'Default'
    }

    if ($isRecommended) {
        $star = New-Icon 'StarFill' 13 'Success'
        $star.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
        $star.ToolTip = T 'Recommended value'
        $right.Children.Add($star) | Out-Null
    }
    if ($isFactory) {
        $grid = New-Icon 'Grid' 13 'TextFaint'
        $grid.Margin = New-Object System.Windows.Thickness 0, 0, 14, 0
        $grid.ToolTip = T 'Windows factory value'
        $right.Children.Add($grid) | Out-Null
    }

    switch ($Setting.Type) {
        'Toggle' {
            # Con clave de registro, la posición del toggle sale del
            # ESTADO REAL leído del equipo: ON solo si está optimizado;
            # de fábrica, personalizado o sin poder leer -> OFF (la
            # etiqueta de color ya dice la verdad). Sin clave, la
            # posición declarada de siempre.
            if ($Setting.Status) { $initialOn = ($Setting.Status -eq 'optimized') }
            else                 { $initialOn = [bool]$Setting.Value }

            $state = New-Object System.Windows.Controls.TextBlock
            if ($initialOn) { $state.Text = T 'On' } else { $state.Text = T 'Off' }
            $state.FontSize = 11.5
            $state.FontWeight = 'SemiBold'
            $state.Width = 24
            $state.TextAlignment = 'Right'
            $state.VerticalAlignment = 'Center'
            $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
            Set-TextFg $state 'TextMuted'
            $right.Children.Add($state) | Out-Null

            $toggle = New-ToggleSwitch -Window $Window -InitialState $initialOn -Label $state -Payload $Setting

            if (@($Setting.Registry).Count -gt 0) {
                # Ajuste con clave: pulsar ESCRIBE en el registro (ON =
                # Recommended, OFF = Default) y actualiza SOLO esta
                # tarjeta con el estado real releído. Si la escritura
                # falla, la tarjeta nueva deja el toggle donde de
                # verdad está. El ajuste viaja por el Tag y el propio
                # toggle es el emisor: nada de closures (regla 4).
                $toggle.Add_MouseLeftButtonUp({
                    param($s, $e)
                    Invoke-SettingToggle -Setting $s.Tag.Payload -Enabled $s.Tag.State -Toggle $s
                })
            }
            else {
                # Sin clave: solo recuenta el resumen de la cabecera
                # (hoy inerte; el enganche está puesto para cuando las
                # etiquetas dejen de ser estáticas).
                $toggle.Add_MouseLeftButtonUp({ param($s, $e) Update-CategorySummary })
            }

            $right.Children.Add($toggle) | Out-Null
        }
        'Dropdown' {
            $combo = New-Object System.Windows.Controls.ComboBox
            $combo.Style = $Window.FindResource('ModernComboStyle')
            $combo.Width = 262
            foreach ($opt in $Setting.Options) { $combo.Items.Add((T $opt)) | Out-Null }
            $combo.SelectedItem = T $Setting.Value
            # Enganchado DESPUÉS de fijar la selección inicial, o
            # saltaría al construir la tarjeta.
            $combo.Add_SelectionChanged({ param($s, $e) Update-CategorySummary })
            $right.Children.Add($combo) | Out-Null
        }
    }

    $right
}

# ---- reemplazar una tarjeta en el sitio -------------------
#
# Al tocar el toggle NO se repinta la sección: se cambia SOLO esta
# tarjeta (ver Update-SettingCard en ui/Views/CategoryDetailView.ps1). Estas
# dos funciones conservan qué franjas plegables tenía abiertas para
# que la tarjeta nueva no dé un salto al nacer plegada.

# Las filas cabecera de las franjas plegables de una tarjeta. Son
# hijas directas del stack de la tarjeta: una StackPanel cuyo
# Children[1] es el Border con el cuerpo en el Tag. Para recorrer
# con foreach, NO para asignar y contar.
function Get-CardDisclosureHeaders {
    param($Card)

    $out = @()
    if (-not $Card -or -not $Card.Child) { return $out }

    foreach ($child in $Card.Child.Children) {
        if ($child -is [System.Windows.Controls.StackPanel] -and $child.Children.Count -ge 2) {
            $h = $child.Children[1]
            if ($h -is [System.Windows.Controls.Border] -and $h.Tag -and
                $h.Tag.PSObject.Properties['Body']) {
                $out += $h
            }
        }
    }
    $out
}

# El texto de la etiqueta de una cabecera plegable ("Technical
# details" / "Reference"), para emparejar la vieja con la nueva.
function Get-DisclosureLabel {
    param($Header)
    foreach ($el in $Header.Child.Children) {
        if ($el -is [System.Windows.Controls.TextBlock]) { return [string]$el.Text }
    }
    ''
}

# Deja abiertas en $To las mismas franjas que estaban abiertas en $From.
function Copy-DisclosureState {
    param($From, $To)

    $openLabels = @()
    foreach ($h in (Get-CardDisclosureHeaders $From)) {
        if ($h.Tag.Body.Visibility -eq 'Visible') { $openLabels += (Get-DisclosureLabel $h) }
    }
    if ($openLabels.Count -eq 0) { return }

    foreach ($h in (Get-CardDisclosureHeaders $To)) {
        if ((Get-DisclosureLabel $h) -in $openLabels) { Open-DisclosureSection $h }
    }
}
