# ============================================================
# Router.ps1
# Sabe qué pantalla se está viendo y cómo volver a dibujarla.
#
# Hace falta por dos motivos:
#
#   1. Cada botón del menú lateral lleva a una vista distinta
#      (campo View de ui/Index/NavigationIndex.ps1).
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
$ViewBusy = $false

function Get-ViewBusy { $script:ViewBusy }

function Show-View {
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Arguments = @{}
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Router: la vista '$Name' no existe. Revisa el campo View de ui/Index/NavigationIndex.ps1."
    }

    # NO SE NAVEGA MIENTRAS SE ESTÁ NAVEGANDO. Pintar una sección
    # lee el registro, y esa lectura cede el hilo para que la barra
    # de progreso avance (Update-UiNow, un DoEvents): en esa pausa
    # WPF entrega los clics que estuvieran esperando. La vista se
    # blinda poniendo su contenido sordo al ratón, pero un Popup
    # -el desplegable del buscador- es una VENTANA APARTE y ese
    # blindaje no le llega: pulsando ahí se entraba aquí otra vez
    # con la pantalla anterior a medio construir.
    #
    # El clic tardío se descarta, que es lo que esperaría cualquiera:
    # pulsó cuando la aplicación ya iba a otro sitio.
    if ($script:ViewBusy) { return }
    $script:ViewBusy = $true

    try {
        $script:CurrentView = @{ Name = $Name; Arguments = $Arguments }

        $all = @{ Window = $AppWindow }
        foreach ($key in $Arguments.Keys) { $all[$key] = $Arguments[$key] }
        & $Name @all
    }
    finally {
        # En el finally y no al terminar: si la vista lanza, dejar la
        # marca puesta congelaría la navegación para siempre.
        $script:ViewBusy = $false
    }

    # El menú tiene que marcar lo que se está enseñando, se haya
    # llegado pulsándolo o no: a la búsqueda se entra también con
    # Enter desde la caja de la cabecera. Lo resuelve el menú, que es
    # quien sabe de botones; aquí solo se le dice dónde estamos.
    Sync-NavSelection -Window $AppWindow -ViewName $Name

    # Navegar empieza arriba. El ScrollViewer conserva su posición
    # aunque le cambies el contenido, así que al entrar en una
    # sección te dejaría a media página. Show-CurrentView deshace
    # esto después, porque repintar no es navegar.
    if ($AppWindow) {
        $scroll = $AppWindow.FindName('MainScroll')
        if ($scroll) { $scroll.ScrollToTop() }
    }
}

<#
    Vuelve a dibujar la pantalla actual con los mismos argumentos,
    dejando el scroll donde estaba.

    Repintar NO es navegar: sigues en la misma pantalla mirando lo
    mismo, así que saltar al principio se siente como si la
    aplicación te hubiera movido de sitio. Por eso la posición se
    conserva aquí y no en Show-View, donde sí toca empezar arriba.

    La restauración se aplaza: el contenido nuevo aún no está
    medido y, mientras el alto sea 0, ScrollToVerticalOffset se
    recorta a 0 y no haría nada.
#>
$PendingScroll = 0.0

function Show-CurrentView {
    $window = Get-AppWindow
    $scroll = $null
    if ($window) { $scroll = $window.FindName('MainScroll') }
    if ($scroll) { $script:PendingScroll = $scroll.VerticalOffset }

    Show-View -Name $CurrentView.Name -Arguments $CurrentView.Arguments

    if ($scroll -and $PendingScroll -gt 0) {
        $window.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Loaded,
            [action]{
                $sv = (Get-AppWindow).FindName('MainScroll')
                # Si la pantalla ha encogido, ScrollViewer recorta
                # solo al máximo posible.
                $sv.ScrollToVerticalOffset($PendingScroll)
            }) | Out-Null
    }
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
            # El índice del buscador guarda TAMBIÉN el texto traducido
            # -quien usa la aplicación en español busca en español-,
            # así que en otro idioma ya no vale. Antes de repintar,
            # para que la pantalla de resultados se rehaga con él.
            Reset-SearchIndex

            Build-Sidebar -Window (Get-AppWindow)
            Update-TitleBarTexts (Get-AppWindow)
            Show-CurrentView

            # El cajón del log no es una vista y Show-CurrentView no
            # lo toca, así que si está abierto hay que rehacerlo
            # aparte o se quedaría en el idioma anterior. Lo mismo
            # si está sacado a su propia ventana.
            if (Get-LogPanelOpen) { Update-LogPanel (Get-AppWindow) }
            if (Get-LogDetached)  { Update-LogWindow }
        }) | Out-Null
}
