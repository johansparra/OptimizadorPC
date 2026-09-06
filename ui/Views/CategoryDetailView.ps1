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
    # Se hace ANTES de construir nada, para que las tarjetas ya
    # nazcan con el valor real. Las secciones cuyos ajustes no
    # declaren claves -hoy, todas menos Regedit- no leen nada y no
    # enseñan la barra.
    #
    # Este mismo paso es el que repite el botón de refrescar: no
    # tiene camino propio, vuelve a entrar por aquí.
    if ($keys -gt 0) {
        # Update-UiNow cede el hilo para repintar la barra, y en esa
        # pausa WPF puede entregar clics de la pantalla anterior.
        # Sordo al ratón mientras dura: no se ve, y no hay forma de
        # navegar a otro sitio a mitad de la lectura.
        $Window.Content.IsHitTestVisible = $false
        Show-ProgressStrip $Window 'Reading the registry...'
        try {
            Update-CategoryRegistryState -Category $Category -OnProgress {
                param($Done, $Total)
                Set-ProgressStrip (Get-AppWindow) $Done $Total
            } | Out-Null
            $script:CategoryReadAt[[string]$Category.Id] = Get-Date

            # Acaban de aparecer Current y Status donde antes no había
            # nada, y el buscador indexa los dos. El índice guardado se
            # ha quedado viejo: se tira y se rehará al siguiente
            # tecleo. Se avisa desde aquí y no desde core/, que no sabe
            # -ni debe saber- que existe un buscador.
            Reset-SearchIndex

            # Y por el mismo motivo, el registro de actividad: la
            # lectura acaba de apuntar sus líneas y nadie las pinta
            # sola. Si el log está sacado a su ventana, ahí sigue
            # delante mientras se lee.
            Sync-LogView
        }
        finally {
            Hide-ProgressStrip $Window
            $Window.Content.IsHitTestVisible = $true
        }
    }

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageBreadcrumb -Window $Window -Category $Category

    Add-PageActionLabel $Window ((T '{0} settings') -f $Category.Items.Count)

    # La hora de la última lectura: es lo que dice si lo que hay en
    # pantalla es de ahora mismo o de hace un rato.
    $readAt = $script:CategoryReadAt[[string]$Category.Id]
    if ($readAt) {
        $stamp = (T 'Updated {0}') -f $readAt.ToString('HH:mm:ss')
        Add-PageActionLabel $Window $stamp
    }

    Add-PageAction $Window (New-RefreshButton -Window $Window -Keys $keys)

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

    try { $Window.UnregisterName('BtnRefresh') } catch { }
    $Window.RegisterName('BtnRefresh', $refresh)

    $refresh
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
