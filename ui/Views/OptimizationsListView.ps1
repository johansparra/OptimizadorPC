# ============================================================
# Vista: lista de optimizaciones (pantalla principal)
#
# Una vista solo ENSAMBLA, no dibuja: pide la cabecera a
# ui/Components/Layout/PageHeader.ps1 y una tarjeta por categoría a
# ui/Components/Cards/CategoryCard.ps1.
#
# Las categorías salen del registro, así que esta pantalla se
# adapta sola a las que haya en ui/Data/Categories/.
# ============================================================

function Show-OptimizationsListView {
    param($Window)

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Optimizations') `
        -Subtitle (T 'Optimize your Windows system performance, privacy and power usage')

    # La barra de búsqueda, no la caja pelada: trae el desplegable de
    # resultados y el Enter que lleva a la página completa.
    Add-PageAction $Window (New-SearchBar -Window $Window)
    Add-PageAction $Window (New-ChipButton $Window 'Quick Actions' 'Bolt' -Chevron)
    Add-PageAction $Window (New-ViewMenu $Window)

    # ---- 2. Cuerpo: una tarjeta por categoría ----
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($category in Get-OptimizationCategories) {
        $list.Children.Add((New-CategoryCard -Window $Window -Category $category)) | Out-Null
    }

    # ---- 3. Pintar con transición de entrada ----
    $Window.FindName('MainContent').Content = $list
    Start-EnterTransition $list
}
