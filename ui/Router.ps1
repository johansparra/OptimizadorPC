# ============================================================
# Router.ps1
# Sabe qué pantalla se está viendo y cómo volver a dibujarla.
#
# Hace falta por dos motivos:
#
#   1. Cada botón del menú lateral lleva a una vista distinta
#      (campo View de ui/NavigationIndex.ps1).
#   2. Al cambiar de idioma hay que repintar la pantalla actual.
#      Los colores se actualizan solos porque el XAML usa
#      DynamicResource, pero para el texto no existe equivalente:
#      hay que reconstruir la vista.
#
# Las vistas se invocan por nombre de función, así que añadir una
# pantalla es crear su archivo en ui/Views/ y apuntar a ella
# desde el índice de navegación. Nada que registrar aquí.
# ============================================================

$AppWindow = $null
$CurrentView = @{ Name = 'Show-OptimizationsListView'; Arguments = @{} }

# La ventana se guarda una vez al arrancar para que cualquier
# capa pueda repintar sin ir pasándola de mano en mano.
function Set-AppWindow {
    param($Window)
    $script:AppWindow = $Window
}

function Get-AppWindow { $script:AppWindow }

<#
    Muestra una vista y la recuerda.

        Show-View 'Show-SettingsView'
        Show-View 'Show-CategoryDetailView' @{ Category = $cat }
#>
function Show-View {
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Arguments = @{}
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Router: la vista '$Name' no existe. Revisa el campo View de ui/NavigationIndex.ps1."
    }

    $script:CurrentView = @{ Name = $Name; Arguments = $Arguments }

    $all = @{ Window = $AppWindow }
    foreach ($key in $Arguments.Keys) { $all[$key] = $Arguments[$key] }
    & $Name @all
}

# Vuelve a dibujar la pantalla actual con los mismos argumentos.
function Show-CurrentView {
    Show-View -Name $CurrentView.Name -Arguments $CurrentView.Arguments
}

function Get-CurrentViewName { $CurrentView.Name }

# Repinta todo tras cambiar el idioma: el menú lateral (sus
# etiquetas también se traducen) y la pantalla actual.
#
# Se aplaza al Dispatcher porque esto suele dispararse desde el
# evento de un control que está dentro de la vista que vamos a
# destruir; dejar que el evento termine primero evita sorpresas.
function Update-UiLanguage {
    $window = Get-AppWindow
    if (-not $window) { return }

    $window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{
            Build-Sidebar -Window (Get-AppWindow)
            Update-TitleBarTexts (Get-AppWindow)
            Show-CurrentView
        }) | Out-Null
}
