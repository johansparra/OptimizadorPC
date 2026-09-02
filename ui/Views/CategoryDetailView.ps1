# ============================================================
# Vista: detalle de una categoría
#
# Misma idea que la lista: solo ensambla. La cabecera la pone
# ui/Components/PageHeader.ps1 y cada fila la construye
# ui/Components/SettingCard.ps1.
#
# Sirve para cualquier categoría sin saber nada de ella: recorre
# su array Items y ya está.
#
# Si la sección está bloqueada en ui/CategoryIndex.ps1, se pinta
# igual pero con un aviso arriba y los controles deshabilitados.
# ============================================================

function Show-CategoryDetailView {
    param($Window, $Category)

    $locked = [bool]$Category.Locked

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageBreadcrumb -Window $Window -Category $Category

    Add-PageActionLabel $Window "$($Category.Items.Count) settings"

    $reset = New-ChipButton $Window 'Reset' 'Sync'
    if ($locked) {
        $reset.IsEnabled = $false
        $reset.Opacity = 0.45
        $reset.ToolTip = 'No disponible: la sección está bloqueada'
    }
    Add-PageAction $Window $reset

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
