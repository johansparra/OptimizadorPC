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

function Show-CategoryDetailView {
    param($Window, $Category)

    $locked = [bool]$Category.Locked

    # ---- 0. Preguntar al equipo qué hay en el registro ----
    # Se hace ANTES de construir nada, para que las tarjetas ya
    # nazcan con el valor real. Las secciones cuyos ajustes no
    # declaren claves -hoy, todas menos Regedit- no leen nada y no
    # enseñan la barra.
    if ((Get-CategoryRegistryKeyCount $Category) -gt 0) {
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

    $reset = New-ChipButton $Window 'Reset' 'Sync'
    if ($locked) {
        $reset.IsEnabled = $false
        $reset.Opacity = 0.45
        $reset.ToolTip = T 'Not available: the section is locked'
    }
    Add-PageAction $Window $reset

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
