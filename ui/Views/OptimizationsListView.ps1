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

    $categories = @(Get-OptimizationCategories)

    # ---- 2. Leer el registro de las secciones que lo declaran ----
    # Para que las píldoras de cada tarjeta cuenten por el ESTADO
    # REAL del equipo -optimizado / de fábrica / a medida- y no por
    # números escritos a mano en el archivo de la sección. Es el
    # mismo paso -y la misma barra- que hace el detalle al entrar;
    # aquí, para todas a la vez y solo la primera vez de la sesión
    # (sin -Force): al volver de una sección los Status ya están.
    Invoke-CategoryRegistryRead -Window $Window -Categories $categories

    # ---- 3. Cuerpo: una tarjeta por categoría ----
    # Dos formas de enseñar lo mismo, y la elige el usuario desde el
    # botón "Vista": filas anchas (lo de siempre) o baldosas en
    # cuadrícula. Las categorías salen del registro en los dos casos.
    $list = New-CategoryPanel
    foreach ($category in $categories) {
        $list.Children.Add((New-CategoryItem -Window $Window -Category $category)) | Out-Null
    }

    # ---- 4. Pintar con entrada en cascada ----
    # Una tras otra, no todas de golpe: el ojo sigue el recorrido y
    # la pantalla parece montarse en vez de aparecer.
    $Window.FindName('MainContent').Content = $list
    Start-StaggeredEnter $list
}

<#
    El panel donde van las secciones.

    En cuadrícula es un WrapPanel: pone tantas baldosas por fila
    como quepan y salta sola al estrechar la ventana, sin que haya
    que decidir columnas en ninguna parte. En lista, el StackPanel
    de siempre.
#>
function New-CategoryPanel {
    if (Get-ViewOption 'grid') {
        $panel = New-Object System.Windows.Controls.WrapPanel
        $panel.Orientation = 'Horizontal'
        return $panel
    }
    New-Object System.Windows.Controls.StackPanel
}

# La pieza que le toca al panel elegido. Las dos saben pintarse
# solas a partir de la categoría; esta vista no las conoce por
# dentro.
function New-CategoryItem {
    param($Window, $Category)

    if (Get-ViewOption 'grid') {
        return New-CategoryTile -Window $Window -Category $Category
    }
    New-CategoryCard -Window $Window -Category $Category
}
