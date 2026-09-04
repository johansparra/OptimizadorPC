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

function Show-CategoryDetailView {
    param($Window, $Category)

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
    Add-PageAction $Window (New-ViewMenu $Window)

    # Fila centrada con el recuento por etiqueta.
    Set-PageSummary -Window $Window -Category $Category

    # ---- 2. Cuerpo ----
    $list = New-Object System.Windows.Controls.StackPanel

    if ($locked) { $list.Children.Add((New-LockedBanner)) | Out-Null }

    foreach ($setting in $Category.Items) {
        $list.Children.Add((New-SettingCard -Window $Window -Setting $setting -Locked:$locked)) | Out-Null
    }

    # ---- 3. Pintar con transición de entrada ----
    $Window.FindName('MainContent').Content = $list
    Start-EnterTransition $list
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
