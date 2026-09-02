# ============================================================
# Vista: lista de optimizaciones (pantalla principal)
#
# Una vista solo ENSAMBLA, no dibuja: pide la cabecera a
# ui/Components/PageHeader.ps1 y una tarjeta por categoría a
# ui/Components/CategoryCard.ps1.
#
# Las categorías salen del registro, así que esta pantalla se
# adapta sola a las que haya en ui/Categories/.
# ============================================================

function Show-OptimizationsListView {
    param($Window)

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Optimizations') `
        -Subtitle (T 'Optimize your Windows system performance, privacy and power usage')

    $search = New-SearchBox $Window
    Add-PageAction $Window $search.Root
    Add-PageAction $Window (New-ChipButton $Window 'Quick Actions' 'Bolt' -Chevron)
    Add-PageAction $Window (New-ChipButton $Window 'View' 'Filter' -Chevron)

    # ---- 2. Cuerpo: una tarjeta por categoría ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($category in Get-OptimizationCategories) {
        $list.Children.Add((New-CategoryCard -Window $Window -Category $category)) | Out-Null
    }

    # ---- 3. Pintar con transición de entrada ----
    $Window.FindName('MainContent').Content = $list
    Start-EnterTransition $list
}
