# ============================================================
# Vista: resultados de la búsqueda
#
# Se llega desde la caja de la cabecera: Enter, o la fila "ver
# todos" del desplegable. Enseña TODO lo que encaja, agrupado por
# sección, mientras que el desplegable solo enseña las primeras
# filas.
#
# La cabecera y el cuerpo se pintan por caminos distintos, y es lo
# único que tiene de particular esta pantalla:
#
#   Show-SearchResultsView   entra: rehace cabecera Y cuerpo
#   Update-SearchResults     escribes: rehace SOLO el cuerpo
#
# El motivo es el foco. Rehacer la cabecera destruye la caja de
# texto en la que se está escribiendo, y con ella el cursor y el
# foco; a cada tecla habría que volver a crearla, devolverle el
# texto y colocar el cursor al final. Dejándola en pie no hay nada
# que restaurar. Por eso el recuento -"12 resultados"- va en el
# cuerpo y no en el subtítulo: el número cambia con cada tecla.
#
# Quien llama a Update-SearchResults es el antirrebote de
# ui/Components/Shell/SearchBar.ps1, y solo cuando esta es la
# pantalla actual: así la página y el desplegable nunca dicen
# cosas distintas.
# ============================================================

function Show-SearchResultsView {
    param($Window)

    $query = Get-SearchQuery

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Search') `
        -Subtitle (T 'Everything in the app, by name, description or registry key')

    # -Focus para poder seguir escribiendo nada más llegar: se entra
    # aquí desde el teclado, y sería raro tener que volver a pulsar
    # en la caja para corregir una letra.
    Add-PageAction $Window (New-SearchBar -Window $Window -Text $query -Focus)
    Add-PageAction $Window (New-ViewMenu $Window)

    # ---- 2. Cuerpo ----
    $body = New-SearchResultsBody -Window $Window -Query $query
    $Window.FindName('MainContent').Content = $body

    # ---- 3. Pintar con transición de entrada ----
    Start-EnterTransition $body
}

<#
    Vuelve a pintar solo la lista, sin tocar la cabecera.

    Sin transición de entrada a propósito: escribiendo, un
    desvanecido por tecla parpadea.
#>
function Update-SearchResults {
    param($Window)

    if (-not $Window) { return }
    $area = $Window.FindName('MainContent')
    if (-not $area) { return }

    $area.Content = New-SearchResultsBody -Window $Window -Query (Get-SearchQuery)
}

# El cuerpo: el recuento, y luego un grupo por sección con sus
# tarjetas. Toda la lógica -buscar y agrupar- vive en
# ui/Engine/Search.ps1; aquí solo se recorre lo que devuelve.
function New-SearchResultsBody {
    param($Window, [string]$Query)

    $list = New-Object System.Windows.Controls.StackPanel

    if ([string]::IsNullOrWhiteSpace($Query)) {
        $list.Children.Add((New-SearchPromptState -Window $Window)) | Out-Null
        return $list
    }

    $results = @(Get-SearchResults $Query)

    if ($results.Count -eq 0) {
        $list.Children.Add((New-SearchEmptyState -Window $Window -Query $Query)) | Out-Null
        return $list
    }

    $list.Children.Add((New-SearchCountLine -Window $Window -Count $results.Count -Query $Query)) | Out-Null

    foreach ($group in (Group-SearchResults $results)) {
        $list.Children.Add((New-SearchGroupHeader $Window $group.Category $group.Entries.Count)) | Out-Null
        foreach ($entry in $group.Entries.ToArray()) {
            $list.Children.Add((New-SearchResultCard $Window $entry)) | Out-Null
        }
    }

    $list
}
