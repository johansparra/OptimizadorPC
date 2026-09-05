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
# Debajo puede colgar el pie plegable de detalles técnicos, que
# construye ui/Components/Cards/TechnicalDetails.ps1. Sale o no según
# la opción 'technical' del botón "Vista"; la insignia del título
# hace lo propio con la opción 'badges'.
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

    # El pie es de consulta, así que se enseña también en las
    # secciones bloqueadas.
    if (Get-ViewOption 'technical') {
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

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = T $Setting.Description
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
            $state = New-Object System.Windows.Controls.TextBlock
            if ($Setting.Value) { $state.Text = T 'On' } else { $state.Text = T 'Off' }
            $state.FontSize = 11.5
            $state.FontWeight = 'SemiBold'
            $state.Width = 24
            $state.TextAlignment = 'Right'
            $state.VerticalAlignment = 'Center'
            $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
            Set-TextFg $state 'TextMuted'
            $right.Children.Add($state) | Out-Null

            $toggle = New-ToggleSwitch -Window $Window -InitialState $Setting.Value -Label $state
            # Segundo manejador, además del que anima el interruptor:
            # tocar un ajuste vuelve a contar el resumen de la cabecera.
            # Hoy los números no se mueven porque las etiquetas son
            # estáticas; el enganche ya está puesto para cuando lo sean.
            $toggle.Add_MouseLeftButtonUp({ param($s, $e) Update-CategorySummary })
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
