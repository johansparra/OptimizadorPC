# ============================================================
# Vista: detalle de una categoría
#
# Misma idea que la lista: solo ensambla. La cabecera la pone
# ui/Components/Layout/PageHeader.ps1 y cada fila la construye
# ui/Components/Cards/SettingCard.ps1.
#
# Sirve para cualquier categoría sin saber nada de ella: recorre
# su array Items y ya está.
#
# Si la sección está bloqueada en ui/Index/CategoryIndex.ps1, se pinta
# igual pero con un aviso arriba y los controles deshabilitados.
# ============================================================

# Cuándo se leyó por última vez el registro de cada sección, para
# poder decirlo en la cabecera. Es dato de pantalla: core/ apunta
# la lectura en el log, pero no sabe de relojes ni de cabeceras.
$CategoryReadAt = @{}

# La tarjeta que hay que traer a la vista al entrar desde un
# resultado de búsqueda. Vive fuera de la función porque quien la
# usa corre después, ya en el Dispatcher.
$CategoryHighlightCard = $null

function Show-CategoryDetailView {
    param($Window, $Category, $Highlight)

    $locked = [bool]$Category.Locked
    $keys = Get-CategoryRegistryKeyCount $Category

    # ---- 0. Preguntar al equipo qué hay en el registro ----
    # ANTES de construir nada, para que las tarjetas ya nazcan con el
    # valor real. -Force: entrar en una sección -o pulsar refrescar,
    # que vuelve a entrar por aquí- trae siempre el dato fresco,
    # aunque la lista ya lo hubiera leído en esta sesión.
    Invoke-CategoryRegistryRead -Window $Window -Categories @($Category) -Force

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageBreadcrumb -Window $Window -Category $Category

    Add-PageActionLabel $Window ((T '{0} settings') -f $Category.Items.Count)

    # La hora de la última lectura: es lo que dice si lo que hay en
    # pantalla es de ahora mismo o de hace un rato.
    $readAt = $script:CategoryReadAt[[string]$Category.Id]
    if ($readAt) {
        $stamp = (T 'Updated {0}') -f (Format-AppTime $readAt)
        Add-PageActionLabel $Window $stamp
    }

    Add-PageAction $Window (New-RefreshButton -Window $Window -Keys $keys)

    # Los dos menús para abrir/cerrar las franjas plegables por
    # sección (Referencia / Detalles técnicos / Todo). Misma
    # condición que "Refrescar" -que haya claves que consultar, hoy
    # solo Regedit- y además solo si alguna de esas franjas está
    # activada en el menú Vista: sin ninguna encendida no habría nada
    # que plegar.
    if ($keys -gt 0 -and ((Get-ViewOption 'technical') -or (Get-ViewOption 'reference'))) {
        $bulk = New-DisclosureBulkButtons -Window $Window
        Add-PageAction $Window $bulk.Expand
        Add-PageAction $Window $bulk.Collapse
    }

    # El mismo menú que la pantalla principal: sus opciones son
    # globales y se guardan, así que da igual desde dónde se toquen.
    # Una sección puede pedir que se le oculte alguna con
    # HideViewOptions: Regedit esconde "Grid view", que en el detalle
    # no hace nada.
    $hiddenViewOptions = @()
    if ($Category.HideViewOptions) { $hiddenViewOptions = @($Category.HideViewOptions) }
    Add-PageAction $Window (New-ViewMenu $Window -Hide $hiddenViewOptions)

    # Fila centrada con el recuento por etiqueta.
    Set-PageSummary -Window $Window -Category $Category

    # ---- 2. Cuerpo ----
    $list = New-Object System.Windows.Controls.StackPanel

    if ($locked) { $list.Children.Add((New-LockedBanner)) | Out-Null }

    # $Highlight llega desde un resultado de búsqueda: es el ajuste
    # que hay que enseñar. Se compara por nombre y no por referencia
    # porque el ajuste puede venir del índice del buscador, que no
    # tiene por qué ser el mismo objeto.
    $buscado = ''
    if ($Highlight) { $buscado = [string]$Highlight.Name }

    $script:CategoryHighlightCard = $null

    foreach ($setting in $Category.Items) {
        $marcar = ($buscado -ne '' -and [string]$setting.Name -eq $buscado)
        $card = New-SettingCard -Window $Window -Setting $setting -Locked:$locked -Highlight:$marcar
        if ($marcar) { $script:CategoryHighlightCard = $card }
        $list.Children.Add($card) | Out-Null
    }

    # ---- 3. Pintar con entrada en cascada ----
    $Window.FindName('MainContent').Content = $list
    Start-StaggeredEnter $list

    Show-HighlightedSetting $Window
}

<#
    Lleva a la vista el ajuste marcado, si lo hay.

    Se aplaza por dos motivos, y hacen falta los dos:

      - El contenido todavía no está medido; con alto 0 no hay
        adónde desplazarse.
      - Show-View manda el scroll arriba DESPUÉS de que esta vista
        termine, así que hacerlo aquí mismo no serviría de nada.
#>
function Show-HighlightedSetting {
    param($Window)

    if (-not $script:CategoryHighlightCard) { return }

    $Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Loaded,
        [action]{
            $card = $script:CategoryHighlightCard
            $script:CategoryHighlightCard = $null
            if ($card) { $card.BringIntoView() }
        }) | Out-Null
}

<#
    El "paso 0" que comparten la lista y el detalle: leer del equipo
    el registro de las secciones que declaran claves, con la barra de
    progreso puesta y la ventana sorda al ratón mientras dura.

    Aquí vive la coreografía -barra, hit-test, aviso al buscador y al
    log-. La lectura de verdad la hace core/Registry/CategoryState.ps1,
    que no sabe nada de esto.

      -Categories  las secciones candidatas. Se filtran solas las que
                   no declaran ninguna clave: se puede pasar la lista
                   entera.
      -Force       releer aunque ya se hubiera leído en esta sesión.
                   El detalle entra con -Force -entrar en una sección
                   siempre trae el dato fresco-; la lista, sin él: al
                   volver de una sección los Status siguen en su sitio
                   -incluido lo que haya cambiado un toggle- y releer
                   sería trabajo tirado.

    Update-UiNow (dentro de la barra) cede el hilo y en esa pausa WPF
    puede entregar clics de la pantalla anterior: por eso la ventana
    se queda sorda al ratón hasta el finally.
#>
function Invoke-CategoryRegistryRead {
    param(
        [Parameter(Mandatory)]$Window,
        [Parameter(Mandatory)][object[]]$Categories,
        [switch]$Force
    )

    $targets = @($Categories | Where-Object {
        (Get-CategoryRegistryKeyCount $_) -gt 0 -and
        ($Force -or -not $script:CategoryReadAt.ContainsKey([string]$_.Id))
    })
    if ($targets.Count -eq 0) { return }

    $Window.Content.IsHitTestVisible = $false
    Show-ProgressStrip $Window 'Reading the registry...'
    try {
        foreach ($category in $targets) {
            Update-CategoryRegistryState -Category $category -OnProgress {
                param($Done, $Total)
                Set-ProgressStrip (Get-AppWindow) $Done $Total
            } | Out-Null
            $script:CategoryReadAt[[string]$category.Id] = Get-Date
        }

        # Acaban de aparecer Current y Status donde antes no había
        # nada, y el buscador indexa los dos: el índice guardado se
        # queda viejo y se rehará al siguiente tecleo. Y el registro
        # de actividad tiene líneas nuevas que nadie pinta solo -si
        # está sacado a su ventana, ahí sigue delante-. Se avisa
        # desde aquí y no desde core/, que no sabe -ni debe saber-
        # que existen un buscador ni un cajón de log.
        Reset-SearchIndex
        Sync-LogView
    }
    finally {
        Hide-ProgressStrip $Window
        $Window.Content.IsHitTestVisible = $true
    }
}

<#
    El botón de refrescar de la cabecera.

    Leer no es tocar nada, así que sigue disponible en las
    secciones bloqueadas: ahí lo único que no se puede es cambiar
    valores. Lo que sí lo apaga es que la sección no declare
    ninguna clave, porque entonces no hay nada que volver a leer.

    Se registra con nombre para que $Window.FindName('BtnRefresh')
    lo encuentre -lo usan las pruebas-, y como la cabecera se
    rehace en cada pintada hay que soltar el nombre anterior.
#>
function New-RefreshButton {
    param($Window, [int]$Keys)

    $refresh = New-ChipButton $Window 'Refresh' 'Sync'

    if ($Keys -gt 0) {
        $refresh.ToolTip = T 'Read the registry keys again'
        $refresh.Add_Click({ param($s, $e) Invoke-CategoryRefresh })
    }
    else {
        $refresh.IsEnabled = $false
        $refresh.Opacity = 0.45
        $refresh.ToolTip = T 'This section does not read the registry yet'
    }

    try { $Window.UnregisterName('BtnRefresh') } catch { $null = $_ }
    $Window.RegisterName('BtnRefresh', $refresh)

    $refresh
}

<#
    Los dos menús de la cabecera que abren ("Expandir") o cierran
    ("Contraer") las franjas plegables de la sección. Cada uno es un
    chip con chevron (New-ChipMenu) que despliega tres órdenes:

        Referencia         ->  solo las franjas "Referencia"
        Detalles técnicos  ->  solo las franjas "Detalles técnicos"
        Todo               ->  las dos (el comportamiento de siempre)

    El destino se pasa a Set-CategoryDisclosures por su -Kind, que es
    el identificador estable que New-DisclosureSection deja en el Tag
    de cada fila plegable. Nada de comparar etiquetas: están
    traducidas y se romperían al cambiar de idioma.

    Si una de las dos franjas está oculta por el menú Vista, su fila
    aquí no encuentra nada que plegar y se queda en un no-op limpio;
    el chevron del chip -abajo para "expandir", arriba para
    "contraer"- recuerda de qué menú se trata.

    Cada OnClick es un scriptblock de literales, sin variables
    capturadas, que solo llama a Set-CategoryDisclosures (regla 4).
#>
function New-DisclosureBulkButtons {
    param($Window)

    $expandItems = @(
        [PSCustomObject]@{ Label = 'Reference';        Icon = 'OpenIn'
                           OnClick = { Set-CategoryDisclosures -Open $true -Kind 'reference' } }
        [PSCustomObject]@{ Label = 'Technical details'; Icon = 'Info'
                           OnClick = { Set-CategoryDisclosures -Open $true -Kind 'technical' } }
        [PSCustomObject]@{ Label = 'All';              Icon = 'Apps'
                           OnClick = { Set-CategoryDisclosures -Open $true } }
    )
    $collapseItems = @(
        [PSCustomObject]@{ Label = 'Reference';        Icon = 'OpenIn'
                           OnClick = { Set-CategoryDisclosures -Open $false -Kind 'reference' } }
        [PSCustomObject]@{ Label = 'Technical details'; Icon = 'Info'
                           OnClick = { Set-CategoryDisclosures -Open $false -Kind 'technical' } }
        [PSCustomObject]@{ Label = 'All';              Icon = 'Apps'
                           OnClick = { Set-CategoryDisclosures -Open $false } }
    )

    [PSCustomObject]@{
        Expand   = New-ChipMenu $Window 'Expand'   'ChevronDown' $expandItems
        Collapse = New-ChipMenu $Window 'Collapse' 'ChevronUp'   $collapseItems
    }
}

<#
    Abre (-Open $true) o cierra (-Open $false) franjas plegables de
    TODAS las tarjetas que hay AHORA MISMO en la pantalla de detalle.

      -Kind  'reference'  ->  solo las franjas "Referencia"
             'technical'  ->  solo las franjas "Detalles técnicos"
             (omitido)    ->  las dos (el "Todo" de siempre)

    El filtro va por el Kind que New-DisclosureSection deja en el Tag
    de cada fila, no por su etiqueta traducida.

    Trabaja sobre los controles ya construidos: ni relee el registro
    ni toca MainContent.Content, así que el ScrollViewer se queda
    donde estaba y no hay parpadeo. Si aún no hay lista de tarjetas,
    no hace nada.

    Cada franja se abre/cierra con las mismas funciones que usa el
    reemplazo de una tarjeta en el sitio (Open-/Close-DisclosureSection),
    sin la animación de entrada. Son idempotentes: repetir la misma
    orden -o encadenar varias- no descuadra ningún estado.
#>
function Set-CategoryDisclosures {
    param(
        [bool]$Open,
        [ValidateSet('reference', 'technical')][string]$Kind
    )

    $window = Get-AppWindow
    if (-not $window) { return }

    $list = $window.FindName('MainContent').Content
    if ($list -isnot [System.Windows.Controls.Panel]) { return }

    foreach ($card in $list.Children) {
        foreach ($header in (Get-CardDisclosureHeaders $card)) {
            if ($Kind -and [string]$header.Tag.Kind -ne $Kind) { continue }
            if ($Open) { Open-DisclosureSection  $header }
            else       { Close-DisclosureSection $header }
        }
    }
}

<#
    Refrescar = volver a entrar en la sección.

    No repite la lectura: repinta la pantalla actual, y al
    repintarse la vista pasa otra vez por su paso 0 con la misma
    barra de progreso. Así no hay dos caminos que puedan acabar
    haciendo cosas distintas.

    Se aplaza al Dispatcher por el mismo motivo que
    Update-UiLanguage: el clic sale de un botón que vive en la
    cabecera que estamos a punto de vaciar, y conviene dejar que
    el evento termine antes. El aviso va después del repintado
    porque Clear-PageHeader se lo llevaría por delante.
#>
function Invoke-CategoryRefresh {
    $window = Get-AppWindow
    if (-not $window) { return }

    $window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{
            Show-CurrentView
            Show-PageToast -Window (Get-AppWindow) -Text 'Registry values updated'
        }) | Out-Null
}

<#
    Aplicar (ON) o deshacer (OFF) un ajuste al pulsar su toggle.

    Escribe SÍNCRONAMENTE por core/Registry/SettingApply.ps1 -que valida
    ruta/clave/tipo/permisos, guarda copia de seguridad y confirma
    por relectura- y deja $Setting.Status y los Current de SUS claves
    al día. Luego actualiza SOLO esta tarjeta.

    NO se repinta la sección: nada de Invoke-CategoryRefresh aquí.
    Ver Update-SettingCard.
#>
function Invoke-SettingToggle {
    param($Setting, [bool]$Enabled, $Toggle)

    if (-not $Setting -or @($Setting.Registry).Count -eq 0) { return }

    Set-SettingOptimization -Setting $Setting -Enabled $Enabled | Out-Null

    # El buscador indexa Current/Status y el log tiene líneas nuevas:
    # los dos han cambiado para ESTE ajuste. Se avisa desde aquí y no
    # desde core/, que no sabe que existen.
    Reset-SearchIndex
    Sync-LogView

    Update-SettingCard -Toggle $Toggle -Setting $Setting
}

<#
    Reemplaza EN EL SITIO la tarjeta de un ajuste tras tocar su
    toggle, sin repintar la sección.

    Por qué así:
      - NO se toca MainContent.Content -> el ScrollViewer conserva
        su posición, sin saltos ni "vuelta arriba".
      - NO se relee el registro de los demás ajustes -> O(1): da
        igual que la sección tenga 5, 50 o 500 tarjetas (FASE 5).
      - Solo el resumen de la cabecera se recuenta (3 píldoras).
      - Se conservan las franjas plegables que estuvieran abiertas.

    Si no encuentra la tarjeta en su lista (no debería), cae al
    refresco de sección de siempre: mejor un repintado feo que
    quedarse sin actualizar.
#>
function Update-SettingCard {
    param($Toggle, $Setting)

    # Sube por el árbol lógico hasta la tarjeta: el Border cuyo padre
    # es la StackPanel de la lista y cuyo abuelo es el ContentControl
    # 'MainContent'.
    $card = $Toggle
    $list = $null
    while ($card) {
        $parent = $card.Parent
        if ($card -is [System.Windows.Controls.Border] -and
            $parent -is [System.Windows.Controls.StackPanel] -and
            $parent.Parent -is [System.Windows.Controls.ContentControl]) {
            $list = $parent
            break
        }
        $card = $parent
    }

    $idx = -1
    if ($list) { $idx = $list.Children.IndexOf($card) }
    if ($idx -lt 0) { Invoke-CategoryRefresh; return }

    $window = [System.Windows.Window]::GetWindow($card)
    $fresh = New-SettingCard -Window $window -Setting $Setting
    Copy-DisclosureState -From $card -To $fresh

    # Quitar y volver a insertar: el indexador de UIElementCollection
    # no reemplaza en el sitio ("el índice ya está en uso").
    $list.Children.RemoveAt($idx)
    $list.Children.Insert($idx, $fresh)
    Start-EnterTransition $fresh 140 4

    Update-CategorySummary
    Show-PageToast -Window $window -Text 'Registry values updated'
}
