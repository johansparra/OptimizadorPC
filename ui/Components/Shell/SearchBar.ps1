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
#   escribir     ->  desplegable (los primeros resultados, agrupados)
#   Enter        ->  Show-SearchResultsView (todos, agrupados)
#   Escape       ->  cerrar y seguir donde estabas
#   clic fuera   ->  se cierra solo (Popup.StaysOpen = $false)
#   clic dentro  ->  si ya hay texto, reabre con lo que encontraba
#
# La última fila es la única que no es "gratis", y tiene DOS trampas.
#
# La primera: StaysOpen cierra el Popup detectando un clic FUERA de
# él, y eso es independiente de si la caja conserva el foco de
# teclado: la mayor parte de la ventana -fondos, Grid, Border
# decorativos- no es enfocable en WPF, así que un clic ahí no le
# quita el foco a la caja. Si nunca lo perdió, un clic de vuelta
# sobre ella no dispara GotFocus -no hay transición que disparar-,
# así que hace falta ADEMÁS un manejador de clic que no dependa del
# foco en absoluto. Sin ninguno de los dos, con el texto puesto y
# sin cambiarlo no había ningún evento que reabriera nada
# -Invoke-SearchKey escucha teclas, Start-SearchDebounce escucha
# TextChanged-.
#
# La segunda: ese manejador de clic no puede abrir el Popup EN EL
# ACTO. StaysOpen instala su propio gancho de "clic fuera" al
# abrirse, y si se abre dentro del mismo evento de ratón que lo
# dispara, el Popup todavía no existía cuando ese clic empezó a
# procesarse: en cuanto se abre, ve ese mismo clic como si hubiera
# caído fuera y se cierra solo al instante -aparece y desaparece de
# golpe-. Por eso Request-SearchPopupReopen aplaza la apertura al
# Dispatcher: deja que el clic termine de repartirse antes de que
# el Popup llegue a existir.
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
$SearchFocusIsProgrammatic = $false
$SearchReopenBox = $null

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

    # Recuperar el foco con texto ya puesto vuelve a abrir el
    # desplegable: StaysOpen=$false ya lo cierra solo con el clic
    # fuera, pero sin esto había que borrar o escribir una letra
    # para que reapareciera. Sin antirrebote -es una sola apertura,
    # no diez pulsaciones- y sin tocar nada si la caja está vacía,
    # que es como arrancó siempre.
    $box.Add_GotFocus({ param($s, $e) Invoke-SearchFocusPopup $s })

    # GotFocus NO BASTA. StaysOpen cierra el Popup detectando un clic
    # FUERA de él, y eso es independiente de si la caja conserva el
    # foco de teclado: la mayor parte de la ventana -fondos, Grid,
    # Border decorativos- no es enfocable en WPF, así que un clic ahí
    # no le quita el foco a la caja. Si nunca lo perdió, un clic de
    # vuelta sobre ella no dispara GotFocus -no hay transición que
    # disparar- y el desplegable se queda cerrado para siempre. De
    # ahí que antes hiciera falta borrar o escribir una letra: eran
    # los únicos eventos enganchados. Este manejador no depende del
    # foco en absoluto, solo de que se haya pulsado sobre la caja.
    $box.Add_PreviewMouseLeftButtonDown({ param($s, $e) Request-SearchPopupReopen $s })

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

    # Este foco es NUESTRO, no de quien usa el programa: se dispara
    # al llegar a la página de resultados -tras Enter, o tras "ver
    # todos"-, donde la lista completa ya está pintada debajo. Sin
    # la bandera, GotFocus reabriría el mini-desplegable encima de
    # esa misma lista en cuanto se entra a la pantalla.
    $script:SearchFocusIsProgrammatic = $true
    $box.Focus() | Out-Null
    $box.CaretIndex = $box.Text.Length
}

<#
    Reabre el desplegable al recuperar el foco con texto ya puesto.

    Se consume la bandera una sola vez: distingue el foco que pone
    Set-SearchFocus del foco de verdad -clic o Tab del usuario-, que
    es justo el caso que faltaba (ver la cabecera del archivo).
#>
function Invoke-SearchFocusPopup {
    param($Box)

    if ($script:SearchFocusIsProgrammatic) {
        $script:SearchFocusIsProgrammatic = $false
        return
    }

    Request-SearchPopupReopen $Box
}

<#
    Pide reabrir el desplegable, pero NO ahora mismo.

    Un Popup con StaysOpen=$false instala su propio gancho de "clic
    fuera" al abrirse. Si se abre DENTRO del mismo evento de ratón
    que lo dispara -el propio clic sobre la caja-, el Popup todavía
    no existía cuando ese golpe de ratón empezó a procesarse: en
    cuanto termina de abrirse, ve ese mismo clic como si hubiera
    caído fuera de él y se cierra solo al instante. Se ve como un
    parpadeo -aparece y desaparece de golpe- y es justo lo que
    pasaba al enganchar Update-SearchPopup directamente a
    PreviewMouseLeftButtonDown.

    Aplazarlo dentro de la cola del Dispatcher deja que este golpe
    de ratón termine de repartirse ANTES de que el Popup llegue a
    existir, así que su gancho ya no tiene ningún clic en curso que
    confundir con uno de fuera. Vale también para GotFocus: un
    Tab también dispara esto dentro del mismo mensaje de teclado, y
    aplazarlo no cuesta nada -es imperceptible- y evita tener dos
    caminos distintos para el mismo problema.

    El BOX VIAJA POR $script:SearchReopenBox, NO por closure sobre
    el parámetro. Un scriptblock convertido a [action] -que es lo
    que exige BeginInvoke- NO conserva las variables locales del
    ámbito donde se definió: dentro del [action], $Box llegaría
    vacío y Update-SearchPopup no haría nada, en silencio, sin
    lanzar. Es la misma familia de trampa que la regla 4 de
    CLAUDE.md sobre los closures forzados y las funciones, mordiendo
    aquí en una variable en vez de en una función. Por eso
    Start-SearchDebounce ya guarda su caja en $script:SearchPendingBox
    en vez de cerrar sobre un parámetro: es el mismo patrón.
#>
function Request-SearchPopupReopen {
    param($Box)

    if ([string]::IsNullOrWhiteSpace($Box.Text)) { return }

    $script:SearchReopenBox = $Box
    $Box.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Input,
        [action]{ Invoke-SearchPopupReopen }) | Out-Null
}

# Lo que de verdad ejecuta el Dispatcher: sin parámetros a propósito,
# lee la caja de $script:SearchReopenBox (ver el porqué arriba).
function Invoke-SearchPopupReopen {
    $box = $script:SearchReopenBox
    $script:SearchReopenBox = $null
    if (-not $box) { return }
    Update-SearchPopup $box
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
