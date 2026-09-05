# ============================================================
# Componente: la caja de búsqueda con resultados en vivo
#
# La caja de la cabecera, más un desplegable que se abre debajo
# según se escribe. Es el mismo patrón del menú "Vista": el Popup
# TIENE que colgar del Grid que devuelve esta función, porque suelto
# quedaría fuera del árbol lógico y los colores del tema no
# resolverían.
#
# Por qué un desplegable y no navegar en cada tecla
# -------------------------------------------------
# La cabecera se rehace entera en cada pintada, así que navegar
# mientras escribes destruiría la propia caja en la que estás
# escribiendo: habría que recrearla, devolverle el texto, el foco y
# el cursor... en cada pulsación. Con el desplegable no te mueves de
# donde estás, Escape lo cierra y Enter te lleva a la página con
# todos los resultados.
#
#   escribir  ->  desplegable (los primeros resultados, agrupados)
#   Enter     ->  Show-SearchResultsView (todos, agrupados)
#   Escape    ->  cerrar y seguir donde estabas
#
# Se espera un momento desde la última tecla antes de buscar
# (antirrebote): escribir "telemetría" son diez pulsaciones y una
# sola búsqueda, no diez.
# ============================================================

$SearchBarWidth = 300.0
$SearchPopupWidth = 470.0
$SearchPopupMax = 7          # filas antes de mandar a la página
$SearchDebounceMs = 160

$SearchDebounceTimer = $null
$SearchPendingBox = $null
$SearchFocusBox = $null

function New-SearchBar {
    param($Window, [string]$Text, [switch]$Focus)

    $shell = New-Object System.Windows.Controls.Grid
    $shell.VerticalAlignment = 'Center'

    $search = New-SearchBox -Window $Window -Width $SearchBarWidth
    $shell.Children.Add($search.Root) | Out-Null

    $box = $search.Box

    # El texto se pone ANTES de enganchar los manejadores: así volver
    # a pintar la pantalla con una búsqueda en marcha no dispara otra
    # búsqueda, ni abre el desplegable solo.
    if ($Text) { $box.Text = $Text }

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.PlacementTarget = $search.Root
    $popup.Placement = 'Bottom'
    $popup.VerticalOffset = 6
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'Fade'
    $shell.Children.Add($popup) | Out-Null

    # El desplegable viaja en el Tag de la caja (regla 4: sin
    # closures). El marcador de "Search optimizations..." ya no lo
    # usa, justamente para dejarlo libre aquí.
    $box.Tag = $popup
    $box.Add_TextChanged({ param($s, $e) Start-SearchDebounce $s })
    $box.Add_PreviewKeyDown({ param($s, $e) Invoke-SearchKey $s $e })

    if ($Focus) {
        # El control todavía no está en el árbol: pedirle el foco
        # ahora no haría nada.
        $script:SearchFocusBox = $box
        $Window.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Loaded,
            [action]{ Set-SearchFocus }) | Out-Null
    }

    $shell
}

function Set-SearchFocus {
    $box = $script:SearchFocusBox
    $script:SearchFocusBox = $null
    if (-not $box) { return }

    $box.Focus() | Out-Null
    $box.CaretIndex = $box.Text.Length
}

# ---- Teclado -------------------------------------------------

function Invoke-SearchKey {
    param($Box, $EventArgs)

    switch ($EventArgs.Key) {
        ([System.Windows.Input.Key]::Enter) {
            $texto = [string]$Box.Text
            if ([string]::IsNullOrWhiteSpace($texto)) { return }

            Stop-SearchDebounce
            if ($Box.Tag) { $Box.Tag.IsOpen = $false }
            Set-SearchQuery $texto
            Show-View -Name 'Show-SearchResultsView'
            $EventArgs.Handled = $true
        }
        ([System.Windows.Input.Key]::Escape) {
            # Handled solo si había algo que cerrar: si no, Escape
            # tiene que seguir llegando al cajón del log.
            if ($Box.Tag -and $Box.Tag.IsOpen) {
                $Box.Tag.IsOpen = $false
                $EventArgs.Handled = $true
            }
        }
    }
}

# ---- Antirrebote ---------------------------------------------

function Start-SearchDebounce {
    param($Box)

    $script:SearchPendingBox = $Box

    if (-not $script:SearchDebounceTimer) {
        $script:SearchDebounceTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:SearchDebounceTimer.Interval = [TimeSpan]::FromMilliseconds($SearchDebounceMs)
        # Un DispatcherTimer no tiene Tag donde dejar la caja, así que
        # el manejador llama a la función y es ella la que mira el
        # estado del módulo.
        $script:SearchDebounceTimer.Add_Tick({ param($s, $e) Invoke-PendingSearch })
    }

    $script:SearchDebounceTimer.Stop()
    $script:SearchDebounceTimer.Start()
}

function Stop-SearchDebounce {
    if ($script:SearchDebounceTimer) { $script:SearchDebounceTimer.Stop() }
}

function Invoke-PendingSearch {
    Stop-SearchDebounce

    $box = $script:SearchPendingBox
    if (-not $box) { return }

    Update-SearchPopup $box
}

# ---- El desplegable ------------------------------------------

<#
    Rehace el contenido del desplegable con lo que haya escrito.

    Sin texto se cierra: una lista de todo no ayuda a nadie. Y si la
    pantalla actual ya es la de resultados, además se repinta, para
    que la página y el desplegable no digan cosas distintas.
#>
function Update-SearchPopup {
    param($Box)

    $popup = $Box.Tag
    if (-not $popup) { return }

    $query = [string]$Box.Text
    Set-SearchQuery $query

    if ([string]::IsNullOrWhiteSpace($query)) {
        $popup.IsOpen = $false
        if ((Get-CurrentViewName) -eq 'Show-SearchResultsView') { Update-SearchResults (Get-AppWindow) }
        return
    }

    $window = Get-AppWindow

    # ENVUELTO EN @(), como en la página de resultados. Sin paréntesis
    # PowerShell desenrolla el array vacío de "sin coincidencias" y lo
    # que llega al desplegable es un $null suelto, no una lista de
    # cero: la puerta de atrás no se abre, se agrupa una entrada
    # fantasma y la cabecera pide un icono sin nombre. Escribir algo
    # que no encaja tumbaba la ventana.
    $results = @(Get-SearchResults $query)

    $popup.Child = New-SearchPopupCard -Window $window -Popup $popup -Results $results -Query $query

    # El sitio del desplegable depende de la caja, que puede no estar
    # medida todavía (misma trampa que los indicadores, regla 25).
    if ($popup.PlacementTarget) {
        $popup.HorizontalOffset = $popup.PlacementTarget.ActualWidth - $SearchPopupWidth
    }
    $popup.IsOpen = $true

    if ((Get-CurrentViewName) -eq 'Show-SearchResultsView') { Update-SearchResults $window }
}

# La tarjeta flotante: los primeros resultados agrupados por sección
# y, si hay más, una fila que lleva a la página completa.
function New-SearchPopupCard {
    param($Window, $Popup, $Results, [string]$Query)

    # AllowsTransparency recorta lo que se salga del Popup, así que
    # la sombra necesita este margen para caber.
    $room = New-Object System.Windows.Controls.Grid
    $room.Margin = New-Object System.Windows.Thickness 12, 0, 12, 16

    $card = New-Object System.Windows.Controls.Border
    $card.Width = $SearchPopupWidth
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.BorderThickness = New-Object System.Windows.Thickness 1
    $card.Padding = New-Object System.Windows.Thickness 7, 8, 7, 8
    Set-BoxBg   $card 'Surface'
    Set-BoxLine $card 'Stroke'

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.Direction = 270; $shadow.ShadowDepth = 3
    $shadow.BlurRadius = 16; $shadow.Opacity = 0.18
    $card.Effect = $shadow

    $rows = New-Object System.Windows.Controls.StackPanel

    # Se filtran los nulos ANTES de contar: `@($null)` es una lista de
    # UNO, no de cero, así que sin esto "sin resultados" se confunde
    # con "un resultado vacío" y se pinta una fila imposible.
    $todos = @($Results | Where-Object { $null -ne $_ })
    if ($todos.Count -eq 0) {
        $rows.Children.Add((New-SearchEmptyState -Window $Window -Query $Query -Compact)) | Out-Null
        $card.Child = $rows
        $room.Children.Add($card) | Out-Null
        return $room
    }

    $mostrados = 0
    foreach ($group in (Group-SearchResults $todos)) {
        if ($mostrados -ge $SearchPopupMax) { break }

        $cabecera = New-SearchGroupHeader $Window $group.Category $group.Entries.Count
        $cabecera.Margin = New-Object System.Windows.Thickness 8, 8, 0, 4
        $rows.Children.Add($cabecera) | Out-Null

        foreach ($entry in $group.Entries.ToArray()) {
            if ($mostrados -ge $SearchPopupMax) { break }
            $rows.Children.Add((New-SearchResultRow $Window $entry $Popup)) | Out-Null
            $mostrados++
        }
    }

    if ($todos.Count -gt $mostrados) {
        $rows.Children.Add((New-SearchSeeAllRow $Window $Popup $todos.Count)) | Out-Null
    }

    $card.Child = $rows
    $room.Children.Add($card) | Out-Null
    $room
}

# "Ver los 12 resultados" — la fila del final, que lleva a la página.
function New-SearchSeeAllRow {
    param($Window, $Popup, [int]$Total)

    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 9
    $row.Padding = New-Object System.Windows.Thickness 10, 8, 10, 9
    $row.Margin = New-Object System.Windows.Thickness 0, 4, 0, 0
    $row.Cursor = 'Hand'
    $row.Background = [System.Windows.Media.Brushes]::Transparent

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = (T 'See all {0} results') -f $Total
    $text.FontSize = 11.5
    $text.FontWeight = 'SemiBold'
    Set-TextFg $text 'Accent'
    $row.Child = $text

    $row.Tag = $Popup
    $row.Add_MouseEnter({ param($s, $e) Set-BoxBg $s 'SurfaceHover' })
    $row.Add_MouseLeave({ param($s, $e) $s.Background = [System.Windows.Media.Brushes]::Transparent })
    $row.Add_MouseLeftButtonUp({
        param($s, $e)
        $s.Tag.IsOpen = $false
        Show-View -Name 'Show-SearchResultsView'
    })

    $row
}
